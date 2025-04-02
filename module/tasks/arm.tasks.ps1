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
        Write-Host "ARM template parameters:"
        $script:parametersWithValues = @{}
        $script:DeploymentConfig.Keys |
            Where-Object {
                !([string]::IsNullOrEmpty($script:DeploymentConfig[$_])) -and $_ -notin $armDeployment.configKeysToIgnore
            } |
            ForEach-Object {
                $script:parametersWithValues += @{ $_ = $script:DeploymentConfig[$_]
            }
        }
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
            Write-Warning "ARM Deployment failed, outputs will not be available."
        }
    }
    Write-Build White "ARM Deployment Outputs: $($script:ZF_ArmDeploymentOutputs | ConvertTo-Json -Depth 10)"
}
