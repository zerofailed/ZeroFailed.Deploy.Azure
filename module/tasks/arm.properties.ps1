# <copyright file="arm.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, skips any configured ARM deployments. Defaults to false.
$SkipArmDeployments = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_ARM_DEPLOYMENTS $false))

# Synopsis: Details the ARM deployments that need to be run for the deployment process.
$RequiredArmDeployments = @()

# Synopsis: When using Bicep templates, ensures that the specified Bicep CLI version is used; installing via Azure CLI if it is missing. When blank any version is considered acceptable. Use 'latest' to ensure the most current release.
$RequiredBicepVersion = property ZF_DEPLOY_REQUIRED_BICEP_VERSION ''

# Synopsis: When using Bicep templates, ensures that the specified Bicep CLI version or later is used; installing the latest version via Azure CLI if it is missing.
$MinimumBicepVersion = property ZF_DEPLOY_MINIMUM_BICEP_VERSION ''

# Synopsis: When true, the available Bicep CLI version will not be checked.
$SkipEnsureBicepVersion = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_ENSURE_BICEP_VERSION $false))

# Synopsis: When true, the available Bicep CLI version will always be checked even when no Bicep-based deployments are found.
$ForceBicepVersionCheck = [Convert]::ToBoolean((property ZF_DEPLOY_FORCE_BICEP_VERSION_CHECK $false))

# Synopsis: A script-scoped variable containing the outputs from any ARM deployments that will be available to the rest of the deployment process. Available for overriding as part of niche testing scenarios.
$script:ZF_ArmDeploymentOutputs = property ZF_DEPLOY_ARM_DEPLOYMENT_OUTPUTS @{}
