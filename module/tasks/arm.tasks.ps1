# <copyright file="arm.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/arm.properties.ps1

# Synopsis: Runs the specified ARM deployments.
task deployArmTemplates -If { !$SkipArmDeployments -and $null -ne $RequiredArmDeployments -and $RequiredArmDeployments.Count -ge 1 } `
                        -After ProvisionCore `
                        -Jobs readConfiguration,connectAzure,ensureBicepVersion,{
    
    foreach ($armDeployment in $RequiredArmDeployments) {

        # Validate required properties
        $requiredProps = @('templatePath', 'resourceGroupName', 'location')
        $missingRequiredProps = $requiredProps | Where-Object { $_ -notin $armDeployment.Keys }
        if ($missingRequiredProps) {
            throw "Unable to process 'RequiredArmDeployments' configuration due to missing required properties: $($missingRequiredProps -join ', ')"
        }

        # Validate optional properties
        if (!$armDeployment.ContainsKey('configKeysToIgnore')) {
            $armDeployment += @{ $configKeysToIgnore = @() }
        }

        # Prepare parameters for ARM deployment
        # 1. Infer parameters from environment configuration settings
        $script:parametersWithValues = @{}
        $script:DeploymentConfig.Keys |
            Where-Object {
                !([string]::IsNullOrEmpty($script:DeploymentConfig[$_])) -and $_ -notin $armDeployment.configKeysToIgnore
            } |
            ForEach-Object {
                $script:parametersWithValues += @{ $_ = $script:DeploymentConfig[$_]
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
        Write-Build White ($script:parametersWithValues | Format-Table | Out-String)

        # Support deferred evaluation of ARM deployment configuration values
        $templatePath = Resolve-Value $armDeployment.templatePath
        $resourceGroupName = Resolve-Value $armDeployment.resourceGroupName
        $location = Resolve-Value $armDeployment.location

        $name = Split-Path -LeafBase $templatePath
        Write-Build Green "Deploying ARM template: $name"
    
        $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
        if (!$rg) {
            New-AzResourceGroup -Name $resourceGroupName -Location $location
        }
        New-AzResourceGroupDeployment -Name ("$name-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")) `
                                        -ResourceGroupName $resourceGroupName `
                                        -TemplateFile $templatePath `
                                        -TemplateParameterObject $parametersWithValues `
                                        -Location $location `
                                        -Verbose |
            Tee-Object -Variable deploymentResult
    
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
            Assert-BicepCliVersionInPath -MinimumBicepVersion $MinimumBicepVersion
        }
        else {
            Assert-BicepCliVersionInPath -RequiredBicepVersion $RequiredBicepVersion
        }
    }
    else {
        Write-Build White "Skipping Bicep CLI checks - no Bicep-based deployments found. Use 'ForceBicepVersionCheck' to override this behaviour."
    }
}
