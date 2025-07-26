# <copyright file="apps.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Deploys the specified ZIP packages to Azure App Service.
$AppServiceAppsToDeploy = @()

# Synopsis: When true, any configured App Service deployments will be skipped.
$SkipAppServiceAppDeployment = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_APP_SERVICE_DEPLOYMENT $false))

#Synopsis: When true, a temporary AppService firewall rule will be created to give the deployment process access to the App Service.
$AppServiceRequiresTemporaryNetworkAccess = [Convert]::ToBoolean((property ZF_DEPLOY_APP_SERVICE_TEMP_NETWORK_ACCESS $false))