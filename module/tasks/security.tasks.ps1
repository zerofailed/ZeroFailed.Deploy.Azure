# <copyright file="security.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/security.properties.ps1

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
    $script:__TEMPORARY_NETWORK_ACCESS_RULES__ = $true
    Assert-TemporaryNetworkAccessRules -RequiredResources $TemporaryNetworkAccessRequiredResources
}

# Synopsis: Remove temporary network access rules from the configured Azure resources
task removeTemporaryNetworkAccess -If {$EnableTemporaryNetworkAccess} -After PostDeploy{
    Assert-TemporaryNetworkAccessRules -RequiredResources $TemporaryNetworkAccessRequiredResources -Revoke
    Remove-Item variable:/__TEMPORARY_NETWORK_ACCESS_RULES__ -Force -ErrorAction Ignore
}