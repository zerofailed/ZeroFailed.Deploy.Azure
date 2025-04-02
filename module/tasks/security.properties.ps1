# <copyright file="security.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, skips the lookup for the PrincipalId of the current Azure PowerShell identity context. Default is false.
$SkipGetDeploymentIdentity = property ZF_DEPLOY_SKIP_GET_DEPLOYMENT_IDENTITY $false

# Synopsis: When true, enables the functionality for applying temporary network access rules for Azure resources. Default is false.
$EnableTemporaryNetworkAccess = $false

# Synopsis: Defines the resources that require temporary network access rules. This is a list of Azure resources that require temporary network access rules to be applied. Default is an empty list.
$TemporaryNetworkAccessRequiredResources = property ZF_DEPLOY_TEMPORARY_NETWORK_ACCESS_REQUIRED_RESOURCES @()
