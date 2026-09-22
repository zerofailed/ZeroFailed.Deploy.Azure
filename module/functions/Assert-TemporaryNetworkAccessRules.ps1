# <copyright file="Assert-TemporaryNetworkAccessRules.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Assert-TemporaryNetworkAccessRules {
    <#
    .SYNOPSIS
    Manages temporary firewall access rules for Azure resources.

    .DESCRIPTION
    This function wraps functionality provided by the [Corvus.Deployment](https://github.com/corvus-dotnet/Corvus.Deployment/) module to allow processes to define
    a set of Azure resources that require temporary firewall rules to allow the public IP address associated with the current process to access them.

    Supported resource types:

    | ResourceType     | Description                                         |
    | ---------------- | --------------------------------------------------- |
    | `KeyVault`       | Key Vaults                                          |
    | `StorageAccount` | Storage Accounts                                    |
    | `SQLServer`      | Azure SQL Database instances                        |
    | `WebApp`         | App Service main web site                           |
    | `WebAppScm`      | App Service SCM web site (for kudu operations)      |

    .PARAMETER RequiredResources
    An array of hashtables, each specifying an Azure resource that requires temporary network access.
    Each hashtable must contain:
    - ResourceType: A supported Azure resource (e.g., 'Storage', 'KeyVault')
    - ResourceGroupName: The name of the resource group containing the resource
    - Name: The name of the resource

    .PARAMETER Revoke
    If specified, removes the temporary network access rules instead of creating them.
    When omitted, the function adds temporary access rules.

    .EXAMPLE
    ```powershell
    $resources = @(
        @{
            ResourceType = 'StorageAccount'
            ResourceGroupName = 'my-resource-group'
            Name = 'mystorageaccount'
        },
        @{
            ResourceType = 'KeyVault'
            ResourceGroupName = 'my-resource-group'
            Name = 'my-key-vault'
        }
    )
    Assert-TemporaryNetworkAccessRules -RequiredResources $resources
    ```

    Adds temporary network access to a storage account and key vault.

    .EXAMPLE
    ```powershell
    Assert-TemporaryNetworkAccessRules -RequiredResources $resources -Revoke
    ```

    Revokes temporary network access rules previously created.

    .NOTES
    This function requires the Azure PowerShell & [Corvus.Deployment](https://www.powershellgallery.com/packages/Corvus.Deployment) modules to be installed and an active connection
    to an Azure subscription.
    #>
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
        
        Set-TemporaryAzureResourceNetworkAccess `
            -ResourceType $requiredResource.ResourceType `
            -ResourceGroupName $requiredResource.ResourceGroupName `
            -ResourceName $requiredResource.Name `
            -Revoke:$Revoke `
            -Wait:(!$Revoke)
    }
}