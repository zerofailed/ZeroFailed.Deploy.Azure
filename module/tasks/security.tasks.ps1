# <copyright file="security.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/security.properties.ps1

$_TEMP_NET_ACCESS_FLAG_NAME = '__TEMPORARY_NETWORK_ACCESS_RULES__'

# Synopsis: Derive the current user's ObjectId (aka PrincipalId) using the current Azure PowerShell context.
task getDeploymentIdentity -If { !$SkipGetDeploymentIdentity } -After InitCore {

    # Lookup the ObjectId for the current user/principle
    $signedInPrincipalInfo = (Get-AzContext).Account
    if ($signedInPrincipalInfo.Type -in @("ServicePrincipal","ClientAssertion")) {
        $deploymentPrincipalApplicationId = $signedInPrincipalInfo.Id
        $script:currentUserObjectId = (Get-AzAdServicePrincipal -ApplicationId $deploymentPrincipalApplicationId).Id
    }
    else {
        $userPrincipalName = $signedInPrincipalInfo.Id
        $tenantUser = Get-AzAdUser -UserPrincipalName $userPrincipalName
        if ($tenantUser) {
            $script:currentUserObjectId = $tenantUser.Id
        }
        else {
            # Guest users are cannot be searched by their home tenant UPN in guest tenants
            # We will attempt to derive the objectId from the homeAccountId
            $script:currentUserObjectId = $signedInPrincipalInfo.ExtendedProperties.HomeAccountId.Split(".")[0]
        }
    }
}

# Synopsis: Apply temporary network access rules to the configured Azure resources.
task enableTemporaryNetworkAccess -If {$EnableTemporaryNetworkAccess} -Before PreDeploy {
    # support deferred evaluation for certain properties in 'TemporaryNetworkAccessRequiredResources'
    for ($i=0; $i -lt $TemporaryNetworkAccessRequiredResources.Count; $i++) {
        $script:TemporaryNetworkAccessRequiredResources[$i].ResourceGroupName = Resolve-Value $TemporaryNetworkAccessRequiredResources[$i].ResourceGroupName
        $script:TemporaryNetworkAccessRequiredResources[$i].Name = Resolve-Value $TemporaryNetworkAccessRequiredResources[$i].Name
    }

    Set-Variable -Name $_TEMP_NET_ACCESS_FLAG_NAME -Value $true -Scope Script
    Assert-TemporaryNetworkAccessRules -RequiredResources $TemporaryNetworkAccessRequiredResources
}

# Use the 'OnExitActions' convention provided by the ZF process to ensure that any temporary 
# network access rules are removed from the configured Azure resources, even if the process
# has encountered an terminating error.
$_cleanupTemporaryNetworkAccess = {
    if ($EnableTemporaryNetworkAccess -and (Test-Path variable:/__TEMPORARY_NETWORK_ACCESS_RULES__)) {
        Write-Build White "Removing temporary network access rules..."
        Assert-TemporaryNetworkAccessRules -RequiredResources $TemporaryNetworkAccessRequiredResources -Revoke
        Remove-Variable -Name $_TEMP_NET_ACCESS_FLAG_NAME -Scope Script -Force
    }
}
$script:OnExitActions.Add($_cleanupTemporaryNetworkAccess)

# Synopsis: Configures up the Azure PowerShell and/or Azure CLI connection context for the deployment
task connectAzure -If { !$SkipConnectAzure } -After InitCore readConfiguration,{
    Connect-CorvusAzure `
        -SubscriptionId $script:DeploymentConfig.azureSubscriptionId `
        -AadTenantId $script:DeploymentConfig.AzureTenantId `
        -SkipAzPowerShell:$SkipConnectAzurePowerShell `
        -SkipAzureCli:$SkipConnectAzureCli
}