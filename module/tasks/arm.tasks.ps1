# <copyright file="arm.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/arm.properties.ps1

# Synopsis: Runs the specified ARM deployments.
task deployArmTemplates -If { !$SkipArmDeployments -and $null -ne $RequiredArmDeployments -and $RequiredArmDeployments.Count -ge 1 } `
                        -After ProvisionCore `
                        -Jobs readConfiguration,connectAzure,ensureBicepVersion,{

    foreach ($armDeployment in $RequiredArmDeployments) {

        $deploymentResult = Invoke-ArmDeployment -ArmDeployment $armDeployment `
                                                 -DeploymentConfig $script:DeploymentConfig `
                                                 -WhatIfMode:$ArmWhatIfMode `
                                                 -ContinueOnWhatIfError:$ArmWhatIfContinueOnError

        if ($ArmWhatIfMode) {
            # What-if does not produce a deployment result, so there are no outputs to process
            continue
        }

        Write-Build White ($deploymentResult | Out-String)

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

    # A '.bicepparam' file also needs the Bicep CLI. Resolve the path first, because it can be a scriptblock.
    $deploymentRequiresBicep = $RequiredArmDeployments | Where-Object { (Resolve-Value $_.templatePath) -match '\.bicep(param)?$' }

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
