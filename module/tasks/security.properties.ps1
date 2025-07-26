# <copyright file="security.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, skips the lookup for the PrincipalId of the current Azure PowerShell identity context.
$SkipGetDeploymentIdentity = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_GET_DEPLOYMENT_IDENTITY $true))

# Synopsis: When true, enables the functionality for applying temporary network access rules for Azure resources.
$EnableTemporaryNetworkAccess = [Convert]::ToBoolean((property ZF_DEPLOY_ENABLE_TEMPORARY_NETWORK_ACCESS $false))

# Synopsis: Defines the resources that require temporary network access rules. This is a list of Azure resources that require temporary network access rules to be applied.
$TemporaryNetworkAccessRequiredResources = @()

# Synopsis: When true, configuring the Azure connection context will be skipped.
$SkipConnectAzure = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_CONNECTAZURE $false))

# Synopsis: When set to true, configuring the Azure PowerShell connection context will be skipped.
$SkipConnectAzurePowerShell = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_CONNECTAZURE_PS $false))

# Synopsis: When set to true, configuring the Azure CLI connection context will be skipped.
$SkipConnectAzureCli = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_CONNECTAZURE_CLI $true))