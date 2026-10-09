# <copyright file="arm.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/arm.properties.ps1

# Synopsis: Runs the specified ARM deployments.
task deployArmTemplates -If { !$SkipArmDeployments -and $null -ne $RequiredArmDeployments -and $RequiredArmDeployments.Count -ge 1 } `
                        -After ProvisionCore `
                        -Jobs readConfiguration,connectAzure,ensureBicepVersion,{
    
    :nextArmDeployment foreach ($armDeployment in $RequiredArmDeployments) {

        # Determine the deployment scope (defaults to resource group for backwards-compatibility)
        $validScopes = @('resourceGroup', 'subscription', 'managementGroup', 'tenant')
        $requestedScope = if ($armDeployment.ContainsKey('scope') -and $armDeployment.scope) { Resolve-Value $armDeployment.scope } else { 'resourceGroup' }
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
        $missingRequiredProps = $requiredProps | Where-Object { $_ -notin $armDeployment.Keys }
        if ($missingRequiredProps) {
            throw "Unable to process 'RequiredArmDeployments' configuration for scope '$scope' due to missing required properties: $($missingRequiredProps -join ', ')"
        }

        # Validate optional properties
        if (!$armDeployment.ContainsKey('configKeysToIgnore')) {
            $armDeployment += @{ configKeysToIgnore = @() }
        }

        # Prepare parameters for ARM deployment
        # 1. Infer parameters from environment configuration settings
        $parametersWithValues = @{}
        $script:DeploymentConfig.Keys |
            Where-Object {
                !([string]::IsNullOrEmpty($script:DeploymentConfig[$_])) -and $_ -notin $armDeployment.configKeysToIgnore
            } |
            ForEach-Object {
                $parametersWithValues += @{ $_ = $script:DeploymentConfig[$_]
            }
        }
        # 2. Process any explicitly-defined additional parameters
        if ($armDeployment.ContainsKey('additionalParameters') -and $armDeployment.additionalParameters) {
            $armDeployment.additionalParameters.Keys |
            Where-Object { $_ -notin $armDeployment.configKeysToIgnore } |
            ForEach-Object {
                if ($parametersWithValues.ContainsKey($_)) {
                    Write-Verbose "Overriding environment config parameter '$_' via additionalParameters"
                    $parametersWithValues[$_] = Resolve-Value $armDeployment.additionalParameters[$_]
                }
                else {
                    Write-Verbose "Setting additional parameter '$_'"
                    $parametersWithValues += @{ $_ = Resolve-Value $armDeployment.additionalParameters[$_] }
                }
            }
        }

        Write-Build White "ARM template parameters:"
        Write-Build White ($parametersWithValues | Format-Table | Out-String)

        # Support deferred evaluation of ARM deployment configuration values
        $templatePath = Resolve-Value $armDeployment.templatePath
        $location = Resolve-Value $armDeployment.location

        $name = Split-Path -LeafBase $templatePath
        $deploymentParams = @{
            Name = ("$name-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
            TemplateFile = $templatePath
            TemplateParameterObject = $parametersWithValues
            Location = $location
            Verbose = $true
        }

        if ($ArmWhatIfMode) {
            Write-Build Yellow "Running ARM what-if for template: $name (scope: $scope) - no changes will be deployed"
            $deploymentParams.WhatIf = $true
        }
        else {
            Write-Build Green "Deploying ARM template: $name (scope: $scope)"
        }

        switch ($scope) {
            'resourceGroup' {
                $resourceGroupName = Resolve-Value $armDeployment.resourceGroupName
                $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
                if (!$rg) {
                    if ($ArmWhatIfMode) {
                        # Creating the resource group is a real change, and what-if cannot run against a missing resource group
                        Write-Warning "Resource group '$resourceGroupName' does not exist - skipping what-if for '$name'. It would be created by a real deployment."
                        continue nextArmDeployment      # a plain 'continue' would only exit the enclosing switch
                    }
                    New-AzResourceGroup -Name $resourceGroupName -Location $location
                }
                New-AzResourceGroupDeployment @deploymentParams -ResourceGroupName $resourceGroupName |
                    Tee-Object -Variable deploymentResult
            }
            'subscription' {
                New-AzSubscriptionDeployment @deploymentParams |
                    Tee-Object -Variable deploymentResult
            }
            'managementGroup' {
                $managementGroupId = Resolve-Value $armDeployment.managementGroupId
                New-AzManagementGroupDeployment @deploymentParams -ManagementGroupId $managementGroupId |
                    Tee-Object -Variable deploymentResult
            }
            'tenant' {
                New-AzTenantDeployment @deploymentParams |
                    Tee-Object -Variable deploymentResult
            }
        }

        if ($ArmWhatIfMode) {
            # What-if does not produce a deployment result, so there are no outputs to process
            continue
        }

        if ($deploymentResult.ProvisioningState -eq 'Succeeded') {
            if ($deploymentResult.Outputs) {
                # Make ARM deployment outputs available to rest of deployment process
                $deploymentResult.Outputs.Keys |
                ForEach-Object {
                    # Roundtrip the value via JSON so it is no longer a Newtonsoft-based object with non-standard IEnumerable behaviour
                    $reserializedValue = $deploymentResult.Outputs[$_].Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100

                    if ($script:ZF_ArmDeploymentOutputs.ContainsKey($_)) {
                        Write-Warning "The ARM deployment output '$_' from an earlier deployment has been overwritten - when running multiple ARM deployments ensure any outputs used later in the process are unique"
                        $script:ZF_ArmDeploymentOutputs[$_] = $reserializedValue
                    }
                    else {
                        $script:ZF_ArmDeploymentOutputs.Add($_, $reserializedValue)
                    }
                }
            }
            else {
                Write-Build White "ARM Deployment succeeded but no outputs were defined."
            }
        }
        else {
            Write-Warning "ARM Deployment failed, outputs will not be available."
        }
    }
    Write-Build White "ARM Deployment Outputs: $($script:ZF_ArmDeploymentOutputs | ConvertTo-Json -Depth 10)"
}

# Synopsis: Checks that a suitable version of Bicep CLI is available, installing it via Azure CLI when missing.
task ensureBicepVersion -If { !$SkipEnsureBicepVersion } {

    $deploymentRequiresBicep = $RequiredArmDeployments | Where-Object { $_.templatePath.EndsWith('.bicep')}

    if ($deploymentRequiresBicep -or $ForceBicepVersionCheck) {
        if ($MinimumBicepVersion) {
            Write-Build White "Checking for minimum version of Bicep CLI: $MinimumBicepVersion"
            Assert-BicepCliVersionInPath -MinimumBicepVersion $MinimumBicepVersion
        }
        else {
            Write-Build White "Checking for required version of Bicep CLI: $RequiredBicepVersion"
            Assert-BicepCliVersionInPath -RequiredBicepVersion $RequiredBicepVersion
        }
    }
    else {
        Write-Build White "Skipping Bicep CLI checks - no Bicep-based deployments found. Use 'ForceBicepVersionCheck' to override this behaviour."
    }
}
