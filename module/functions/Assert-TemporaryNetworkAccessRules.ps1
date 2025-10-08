# <copyright file="Assert-TemporaryNetworkAccessRules.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Assert-TemporaryNetworkAccessRules {
    [CmdletBinding()]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $RequiredResources,

        [Parameter()]
        [switch] $Revoke
    )

    foreach ($requiredResource in $RequiredResources) {

        if ($requiredResource.Keys -notcontains 'ResourceType' -or $requiredResource.Keys -notcontains 'ResourceGroupName' -or $requiredResource.Keys -notcontains 'Name') {
            Write-Warning "Invalid resource configuration, missing 1 or more properties: ResourceType, ResourceGroupName, Name"
            continue
        }
        
        Set-CorvusTemporaryAzureResourceNetworkAccess `
            -ResourceType $requiredResource.ResourceType `
            -ResourceGroupName $requiredResource.ResourceGroupName `
            -ResourceName $requiredResource.Name `
            -Revoke:$Revoke `
            -Wait:(!$Revoke)
    }
}