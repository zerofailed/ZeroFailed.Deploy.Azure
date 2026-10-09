# <copyright file="Invoke-ArmDeployment.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Invoke-ArmDeployment
{
    <#
    .SYNOPSIS
    Runs a single ARM deployment, or its what-if, at the scope that the deployment entry specifies.

    .DESCRIPTION
    Runs one entry of the 'RequiredArmDeployments' configuration at resource group, subscription, management group or tenant scope.

    A '.bicep' or '.json' template receives its parameters from the environment configuration, merged with any 'additionalParameters'.

    A '.bicepparam' file is passed via '-TemplateParameterFile', and its 'using' statement names the template. The environment configuration is not passed as template parameters, and 'additionalParameters' are not supported.

    When the entry has a 'subscriptionId', the Az context is switched to that subscription for the deployment and restored afterwards.

    .PARAMETER ArmDeployment
    The deployment entry. Supported keys: 'templatePath', 'location', 'scope' ('resourceGroup' (the default), 'subscription', 'managementGroup' or 'tenant'), 'resourceGroupName', 'managementGroupId', 'subscriptionId', 'additionalParameters' and 'configKeysToIgnore'.

    .PARAMETER DeploymentConfig
    The environment configuration, whose non-empty values become template parameters for a '.bicep' or '.json' template.

    .PARAMETER WhatIfMode
    When specified, runs the ARM what-if operation instead of a deployment. No resource group is created.

    .PARAMETER ContinueOnWhatIfError
    When specified with 'WhatIfMode', a failed what-if operation is reported as a warning instead of an error.

    .OUTPUTS
    The deployment result, or $null for a what-if run or a skipped deployment.

    .EXAMPLE
    ```powershell
    Invoke-ArmDeployment -ArmDeployment @{ scope = 'subscription'; templatePath = './main.bicepparam'; location = 'uksouth'; subscriptionId = '<id>' } -DeploymentConfig @{}
    ```

    Deploys a Bicep parameters file at subscription scope, to the specified subscription.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable] $ArmDeployment,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.IDictionary] $DeploymentConfig,

        # Deliberately not 'SupportsShouldProcess', so that '$WhatIfPreference' cannot stop the Az context switch.
        [switch] $WhatIfMode,

        [switch] $ContinueOnWhatIfError
    )

    # InvokeBuild sets 'Stop' in task scope, which a module function does not inherit.
    $ErrorActionPreference = 'Stop'

    # Determine the deployment scope (defaults to resource group for backwards-compatibility)
    $validScopes = @('resourceGroup', 'subscription', 'managementGroup', 'tenant')
    $requestedScope = if ($ArmDeployment.ContainsKey('scope') -and $ArmDeployment.scope) { Resolve-Value $ArmDeployment.scope } else { 'resourceGroup' }
    $scope = $validScopes | Where-Object { $_ -eq $requestedScope }      # case-insensitive match, normalised to canonical casing
    if (!$scope) {
        throw "Unable to process 'RequiredArmDeployments' configuration due to unsupported scope '$requestedScope'. Supported scopes: $($validScopes -join ', ')"
    }

    # Validate required properties
    $requiredProps = @('templatePath', 'location')
    switch ($scope) {
        'resourceGroup'   { $requiredProps += 'resourceGroupName' }
        'managementGroup' { $requiredProps += 'managementGroupId' }
    }
    $missingRequiredProps = $requiredProps | Where-Object { $_ -notin $ArmDeployment.Keys }
    if ($missingRequiredProps) {
        throw "Unable to process 'RequiredArmDeployments' configuration for scope '$scope' due to missing required properties: $($missingRequiredProps -join ', ')"
    }

    $subscriptionId = if ($ArmDeployment.ContainsKey('subscriptionId') -and $ArmDeployment.subscriptionId) { Resolve-Value $ArmDeployment.subscriptionId } else { $null }
    if ($subscriptionId -and $scope -notin @('resourceGroup', 'subscription')) {
        throw "Unable to process 'RequiredArmDeployments' configuration for scope '$scope': 'subscriptionId' is only supported at 'resourceGroup' and 'subscription' scope"
    }

    # Support deferred evaluation of ARM deployment configuration values
    $templatePath = Resolve-Value $ArmDeployment.templatePath
    $location = Resolve-Value $ArmDeployment.location
    $isBicepParamFile = $templatePath.EndsWith('.bicepparam', [StringComparison]::OrdinalIgnoreCase)

    $name = Split-Path -LeafBase $templatePath
    $deploymentParams = @{
        Name = ("$name-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
        Verbose = $true
    }
    # New-AzResourceGroupDeployment has no 'Location' parameter; the resource group sets it
    if ($scope -ne 'resourceGroup') {
        $deploymentParams.Location = $location
    }

    if ($isBicepParamFile) {
        if ($ArmDeployment.ContainsKey('additionalParameters') -and $ArmDeployment.additionalParameters) {
            # Az only accepts overrides beside a '.bicepparam' file as dynamic named parameters, which can silently bind to the cmdlet's own parameters (e.g. 'Location')
            throw "Unable to process 'RequiredArmDeployments' configuration for '$templatePath': 'additionalParameters' are not supported with a '.bicepparam' file - set the values in the '.bicepparam' file instead"
        }
        # The 'using' statement in the '.bicepparam' file names the template
        $deploymentParams.TemplateParameterFile = $templatePath
        Write-Host "ARM template parameters: from '$templatePath'"
    }
    else {
        $configKeysToIgnore = if ($ArmDeployment.ContainsKey('configKeysToIgnore')) { $ArmDeployment.configKeysToIgnore } else { @() }

        # Prepare parameters for ARM deployment
        # 1. Infer parameters from environment configuration settings
        $parametersWithValues = @{}
        $DeploymentConfig.Keys |
            Where-Object {
                !([string]::IsNullOrEmpty($DeploymentConfig[$_])) -and $_ -notin $configKeysToIgnore
            } |
            ForEach-Object {
                $parametersWithValues += @{ $_ = $DeploymentConfig[$_] }
            }
        # 2. Process any explicitly-defined additional parameters
        if ($ArmDeployment.ContainsKey('additionalParameters') -and $ArmDeployment.additionalParameters) {
            $ArmDeployment.additionalParameters.Keys |
            Where-Object { $_ -notin $configKeysToIgnore } |
            ForEach-Object {
                if ($parametersWithValues.ContainsKey($_)) {
                    Write-Verbose "Overriding environment config parameter '$_' via additionalParameters"
                    $parametersWithValues[$_] = Resolve-Value $ArmDeployment.additionalParameters[$_]
                }
                else {
                    Write-Verbose "Setting additional parameter '$_'"
                    $parametersWithValues += @{ $_ = Resolve-Value $ArmDeployment.additionalParameters[$_] }
                }
            }
        }

        Write-Host "ARM template parameters:"
        Write-Host ($parametersWithValues | Format-Table | Out-String)

        $deploymentParams.TemplateFile = $templatePath
        $deploymentParams.TemplateParameterObject = $parametersWithValues
    }

    if ($WhatIfMode) {
        Write-Host "Running ARM what-if for template: $name (scope: $scope) - no changes will be deployed"
        $deploymentParams.WhatIf = $true
    }
    else {
        Write-Host "Deploying ARM template: $name (scope: $scope)"
    }

    $savedContext = $null
    try {
        if ($subscriptionId) {
            # The Az context is process-wide, so it is restored in the 'finally' block
            $savedContext = Get-AzContext
            Write-Host "Switching Az context to subscription: $subscriptionId"
            Set-AzContext -Subscription $subscriptionId | Out-Null
        }

        if ($scope -eq 'resourceGroup') {
            $resourceGroupName = Resolve-Value $ArmDeployment.resourceGroupName
            $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
            if (!$rg) {
                if ($WhatIfMode) {
                    # Creating the resource group is a real change, and what-if cannot run against a missing resource group
                    Write-Warning "Resource group '$resourceGroupName' does not exist - skipping what-if for '$name'. It would be created by a real deployment."
                    return $null
                }
                New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
            }
        }

        try {
            # An assignment rather than 'Tee-Object', so that the function returns the result only once
            $deploymentResult = switch ($scope) {
                'resourceGroup'   { New-AzResourceGroupDeployment @deploymentParams -ResourceGroupName $resourceGroupName }
                'subscription'    { New-AzSubscriptionDeployment @deploymentParams }
                'managementGroup' { New-AzManagementGroupDeployment @deploymentParams -ManagementGroupId (Resolve-Value $ArmDeployment.managementGroupId) }
                'tenant'          { New-AzTenantDeployment @deploymentParams }
            }
        }
        catch {
            if ($WhatIfMode -and $ContinueOnWhatIfError) {
                Write-Warning "ARM what-if failed for '$name' (scope: $scope): $($_.Exception.Message)"
                return $null
            }
            throw
        }

        if ($WhatIfMode) {
            # What-if does not produce a deployment result, so there are no outputs to process
            return $null
        }
        return $deploymentResult
    }
    finally {
        if ($savedContext) {
            Write-Host "Restoring the previous Az context"
            Set-AzContext -Context $savedContext | Out-Null
        }
    }
}
