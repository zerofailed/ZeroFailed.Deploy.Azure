# <copyright file="apps.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/apps.properties.ps1

# Synopsis: Deploy Azure App Service ZIP packages
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
        # }
        
        # Support deferred evaluation of configuration values & related properties
        $resolvedApp = Resolve-Value $app
        $tempNetAccessRequired = Resolve-Value $AppServiceRequiresTemporaryNetworkAccess

        if ($tempNetAccessRequired) {
            $tempNetAccessSplat = @{
                ResourceType = 'WebAppScm'
                ResourceGroupName = $resolvedApp.resourceGroupName
                ResourceName       = $resolvedApp.appServiceName
            }
            
            Set-TemporaryAzureResourceNetworkAccess @tempNetAccessSplat -Wait
        }
    
        try {
            Write-Build Green "Deploying AppService ZIP package to '$($resolvedApp.appServiceName)': $($resolvedApp.zipPackagePath)"
            Publish-AzWebApp `
                -ResourceGroupName $resolvedApp.resourceGroupName `
                -Name $resolvedApp.appServiceName `
                -ArchivePath $resolvedApp.zipPackagePath `
                -Verbose `
                -Force | Format-List | Out-String | Write-Verbose
        }
        finally {
            if ($tempNetAccessRequired) {
                Set-TemporaryAzureResourceNetworkAccess @tempNetAccessSplat -Revoke
            }
        }
    }
}
