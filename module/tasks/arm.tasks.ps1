# <copyright file="arm.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/arm.properties.ps1

# Synopsis: Runs the specified ARM deployments.
task deployArmTemplates -If { !$SkipArmDeployments -and $null -ne $RequiredArmDeployments -and $RequiredArmDeployments.Count -ge 1 } `
               -After ProvisionCore `
               readConfiguration,connectAzure,{
    
    foreach ($armDeployment in $RequiredArmDeployments) {

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
                $script:ZF_ArmDeploymentOutputs = @{}
                # Make ARM deployment outputs available to rest of deployment process
                $deployOutputs = @{}
                $deploymentResult.Outputs.Keys |
                ForEach-Object {
                    $deployOutputs += @{ $_ = $deploymentResult.Outputs[$_].Value }
                }
                $script:ZF_ArmDeploymentOutputs += $deployOutputs
            }
            else {
                Write-Warning "ARM Deployment succeeded but no outputs were defined."
            }
        }
        else {
            Write-Warning "ARM Deployment failed, outputs will not be available."
        }
    }
    Write-Build White "ARM Deployment Outputs: $($script:ZF_ArmDeploymentOutputs | ConvertTo-Json -Depth 10)"
}
