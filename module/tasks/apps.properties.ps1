# <copyright file="apps.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Deploys the specified ZIP packages to Azure App Service.
# This should be an array of hashtables, each specifying an App Service to deploy to.
# Each hashtable must contain:
# - appServiceName: The name of the App Service to deploy to.
# - resourceGroupName: The name of the resource group containing the App Service.
# - zipPackagePath: The path to the ZIP package to deploy.
# The ZIP package should be a valid deployment package for the App Service.
# Supports deferred evaluation of each hashtable within the array, but not the array itself.
$AppServiceAppsToDeploy = @()

# Synopsis: When true, any configured App Service deployments will be skipped.
$SkipAppServiceAppDeployment = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_APP_SERVICE_DEPLOYMENT $false))

$AppServiceRequiresTemporaryNetworkAccess = [Convert]::ToBoolean((property ZF_DEPLOY_APP_SERVICE_TEMP_NETWORK_ACCESS $false))