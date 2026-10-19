# <copyright file="apps.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/apps.properties.ps1

# Synopsis: Deploy ZIP packages to Azure App Service and Function Apps, including Function Apps on the Flex Consumption plan
task deployAppServiceZipPackages -If { !$SkipAppServiceAppDeployment -and $null -ne $AppServiceAppsToDeploy -and $AppServiceAppsToDeploy.Count -ge 1 } `
                -After DeployCore `
                readConfiguration,{

    # Deploy each of the configured Apps
    foreach ($app in $AppServiceAppsToDeploy) {

        # Required configuration object:
        # @{
        #     appServiceName = ''
        #     resourceGroupName = ''
        #     zipPackagePath = ''
        #     remoteBuild = $false      # Optional, only used for Function Apps on the Flex Consumption plan
        # }

        # Support deferred evaluation of the configuration object, its values & related properties
        $resolvedApp = Resolve-Value $app
        $appServiceName = Resolve-Value $resolvedApp.appServiceName
        $resourceGroupName = Resolve-Value $resolvedApp.resourceGroupName
        $zipPackagePath = Resolve-Value $resolvedApp.zipPackagePath
        $remoteBuild = [Convert]::ToBoolean((Resolve-Value $resolvedApp.remoteBuild))
        $tempNetAccessRequired = Resolve-Value $AppServiceRequiresTemporaryNetworkAccess

        if ($tempNetAccessRequired) {
            $tempNetAccessSplat = @{
                ResourceType = 'WebAppScm'
                ResourceGroupName = $resourceGroupName
                ResourceName       = $appServiceName
            }

            Set-TemporaryAzureResourceNetworkAccess @tempNetAccessSplat -Wait
        }

        try {
            if (Test-FlexConsumptionFunctionApp -ResourceGroupName $resourceGroupName -Name $appServiceName) {
                Write-Build Green "Deploying ZIP package to Flex Consumption Function App '$appServiceName': $zipPackagePath"
                Publish-FlexConsumptionFunctionApp `
                    -ResourceGroupName $resourceGroupName `
                    -Name $appServiceName `
                    -ArchivePath $zipPackagePath `
                    -RemoteBuild:$remoteBuild `
                    -TimeoutSeconds $AppServiceFlexDeploymentTimeoutSeconds
            }
            else {
                if ($remoteBuild) {
                    Write-Warning "The app '$appServiceName' is not a Function App on the Flex Consumption plan, so the task ignores its 'remoteBuild' setting."
                }
                Write-Build Green "Deploying AppService ZIP package to '$appServiceName': $zipPackagePath"
                Publish-AzWebApp `
                    -ResourceGroupName $resourceGroupName `
                    -Name $appServiceName `
                    -ArchivePath $zipPackagePath `
                    -Verbose `
                    -Force | Format-List | Out-String | Write-Verbose
            }
        }
        finally {
            if ($tempNetAccessRequired) {
                Set-TemporaryAzureResourceNetworkAccess @tempNetAccessSplat -Revoke
            }
        }
    }
}
