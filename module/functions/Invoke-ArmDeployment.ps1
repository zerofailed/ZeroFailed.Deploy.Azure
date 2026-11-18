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

    When the entry has a 'subscriptionId', the Az context of the current process is switched to that subscription before any other value is evaluated, and restored afterwards. If the restore fails, the function throws, so that a later deployment cannot run in the wrong subscription. If the deployment has already failed, the function keeps the deployment error and reports the restore error as a warning.

    .PARAMETER ArmDeployment
    The deployment entry. Supported keys: 'templatePath', 'location', 'scope' ('resourceGroup' (the default), 'subscription', 'managementGroup' or 'tenant'), 'resourceGroupName', 'managementGroupId', 'subscriptionId', 'additionalParameters' and 'configKeysToIgnore'.

    .PARAMETER DeploymentConfig
    The environment configuration, whose non-empty values become template parameters for a '.bicep' or '.json' template.

    .PARAMETER WhatIfMode
    When specified, runs the ARM what-if operation instead of a deployment. No resource group is created.

    .PARAMETER ContinueOnWhatIfError
    When specified with 'WhatIfMode', an error from the what-if operation, including a template build or validation error, is reported as a warning instead of an error.

    .PARAMETER RetryErrorPatterns
    Regular expressions that identify transient errors. When the deployment or what-if fails and its error text matches any of the patterns, the operation is run again, up to 'RetryMaxAttempts' attempts in total. Each pattern is tested against the text of all the reported errors, ignoring case. An entry that is an array matches only when all of its patterns match. Any other error fails immediately. When empty (the default), a failure is never retried.

    .PARAMETER RetryMaxAttempts
    The maximum number of attempts, including the first, when an error matches 'RetryErrorPatterns'. Defaults to 3.

    .PARAMETER RetryDelaySeconds
    The delay before the first retry. Each later retry waits this delay multiplied by the number of failed attempts so far. Defaults to 15.

    .NOTES
    Az.Resources cannot serialize a SecureString inside '-TemplateParameterObject'. A template parameter whose value is a SecureString is converted to plain text immediately before the deployment cmdlet runs, after the parameters are written to the log. Keep secret values as SecureString in the configuration so the log shows the type name instead of the value; the template's '@secure()' parameters accept the plain text, and ARM does not log them.

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

        [switch] $ContinueOnWhatIfError,

        [AllowEmptyCollection()]
        [object[]] $RetryErrorPatterns = @(),

        [ValidateRange(1, 100)]
        [int] $RetryMaxAttempts = 3,

        [ValidateRange(0, 3600)]
        [int] $RetryDelaySeconds = 15
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

    $savedContext = $null
    $isPropagatingError = $false
    try {
        if ($subscriptionId) {
            # Switch first, so that every deferred value below is evaluated in the target subscription.
            # The Az context is process-wide, so it is restored in the 'finally' block.
            $savedContext = Get-AzContext
            Write-Host "Switching Az context to subscription: $subscriptionId"
            Set-AzContext -Subscription $subscriptionId -Scope Process | Out-Null
        }

        # Support deferred evaluation of ARM deployment configuration values
        $templatePath = Resolve-Value $ArmDeployment.templatePath
        $location = Resolve-Value $ArmDeployment.location
        $resourceGroupName = if ($scope -eq 'resourceGroup') { Resolve-Value $ArmDeployment.resourceGroupName } else { $null }
        $managementGroupId = if ($scope -eq 'managementGroup') { Resolve-Value $ArmDeployment.managementGroupId } else { $null }
        $isBicepParamFile = $templatePath.EndsWith('.bicepparam', [StringComparison]::OrdinalIgnoreCase)

        $name = Split-Path -LeafBase $templatePath
        $deploymentParams = @{
            Name = ("$name-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
            Verbose = $true
        }
        switch ($scope) {
            # New-AzResourceGroupDeployment has no 'Location' parameter; the resource group sets it
            'resourceGroup'   { $deploymentParams.ResourceGroupName = $resourceGroupName }
            'subscription'    { $deploymentParams.Location = $location }
            'managementGroup' { $deploymentParams.Location = $location; $deploymentParams.ManagementGroupId = $managementGroupId }
            'tenant'          { $deploymentParams.Location = $location }
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

            # Az.Resources cannot serialize a SecureString inside '-TemplateParameterObject' ("Unable to
            # serialize secure string value"). Convert them only now, after the parameters are written to
            # the log (where a SecureString shows as its type name), and in a copy, so that the caller's
            # configuration keeps the SecureString. Assign inside each branch: an 'if' expression would
            # enumerate an array value, turning '@('x')' into 'x' and '@()' into $null.
            $templateParameterObject = @{}
            foreach ($key in $parametersWithValues.Keys) {
                $value = $parametersWithValues[$key]
                if ($value -is [System.Security.SecureString]) {
                    $templateParameterObject[$key] = ConvertFrom-SecureString -SecureString $value -AsPlainText
                }
                else {
                    $templateParameterObject[$key] = $value
                }
            }

            $deploymentParams.TemplateFile = $templatePath
            $deploymentParams.TemplateParameterObject = $templateParameterObject
        }

        if ($WhatIfMode) {
            Write-Host "Running ARM what-if for template: $name (scope: $scope) - no changes will be deployed"
            $deploymentParams.WhatIf = $true
        }
        else {
            Write-Host "Deploying ARM template: $name (scope: $scope)"
        }

        if ($scope -eq 'resourceGroup') {
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

        # Az.Resources reports a failed validation as one non-terminating error for each error and for
        # each of its inner errors, and then throws. With 'Stop', the first of these errors ends the
        # cmdlet, so the inner errors, which describe the actual problem, are never written.
        # Collect all of the errors instead, and report them together.
        $deploymentParams.ErrorAction = 'SilentlyContinue'
        $deploymentParams.ErrorVariable = 'armErrors'
        $operation = if ($WhatIfMode) { 'ARM what-if' } else { 'ARM deployment' }
        $attempt = 0
        while ($true) {
            $attempt++
            $armErrors = $null
            $terminatingError = $null
            $deploymentResult = $null
            try {
                # An assignment rather than 'Tee-Object', so that the function returns the result only once
                $deploymentResult = switch ($scope) {
                    'resourceGroup'   { New-AzResourceGroupDeployment @deploymentParams }
                    'subscription'    { New-AzSubscriptionDeployment @deploymentParams }
                    'managementGroup' { New-AzManagementGroupDeployment @deploymentParams }
                    'tenant'          { New-AzTenantDeployment @deploymentParams }
                }
            }
            catch {
                $terminatingError = $_
            }

            # Also covers a failed deployment, which Az reports as a non-terminating error beside a 'Failed' result.
            # The error variable can also hold the terminating error, so remove duplicate messages.
            $errorMessages = @(
                @($armErrors) + @($terminatingError) |
                    Where-Object { $_ } |
                    ForEach-Object { $_.ToString().Trim() } |
                    Where-Object { $_ } |
                    Select-Object -Unique
            )
            if ($errorMessages.Count -eq 0 -or $attempt -ge $RetryMaxAttempts) {
                break
            }

            # Retry only an error that a pattern identifies as transient; an array entry requires all of its patterns
            $errorText = $errorMessages -join "`n"
            $matchedPattern = $RetryErrorPatterns |
                Where-Object { $_ } |
                Where-Object { $patterns = @($_); @($patterns | Where-Object { $errorText -notmatch $_ }).Count -eq 0 } |
                Select-Object -First 1
            if (!$matchedPattern) {
                break
            }

            $delaySeconds = $RetryDelaySeconds * $attempt
            Write-Warning ("{0} attempt {1} of {2} failed for '{3}' with an error that matches the retry pattern '{4}' - retrying in {5}s. Errors:`n  {6}" -f `
                $operation, $attempt, $RetryMaxAttempts, $name, (@($matchedPattern) -join "' and '"), $delaySeconds, ($errorMessages -join "`n  "))
            Start-Sleep -Seconds $delaySeconds
        }

        if ($errorMessages.Count -gt 0) {
            $message = "$operation failed for '$name' (scope: $scope, deployment name: $($deploymentParams.Name)):`n  $($errorMessages -join "`n  ")"
            if ($WhatIfMode -and $ContinueOnWhatIfError) {
                Write-Warning $message
                return $null
            }
            $innerException = if ($terminatingError) { $terminatingError.Exception } else { $null }
            throw [System.Management.Automation.RuntimeException]::new($message, $innerException)
        }

        if ($WhatIfMode) {
            # What-if does not produce a deployment result, so there are no outputs to process
            return $null
        }
        return $deploymentResult
    }
    catch {
        $isPropagatingError = $true
        throw
    }
    finally {
        if ($savedContext) {
            Write-Host "Restoring the previous Az context"
            try {
                Set-AzContext -Context $savedContext -Scope Process | Out-Null
            }
            catch {
                $restoreError = "Unable to restore the previous Az context '$($savedContext.Name)': $($_.Exception.Message)"
                if ($isPropagatingError) {
                    # Never replace the deployment's own error with a restore error
                    Write-Warning $restoreError
                }
                else {
                    # Otherwise a later deployment without a 'subscriptionId' would run in the wrong subscription
                    throw $restoreError
                }
            }
        }
    }
}
