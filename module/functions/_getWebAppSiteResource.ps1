# <copyright file="_getWebAppSiteResource.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getWebAppSiteResource {
    <#
    .SYNOPSIS
    Gets the Azure Resource Manager resource for an App Service or Function App site.

    .DESCRIPTION
    Gets the site resource with a recent Azure Resource Manager API version. The response includes properties that
    the Az.Websites cmdlets might not return, such as 'properties.sku' and 'properties.hostNameSslStates'.

    .PARAMETER ResourceGroupName
    The resource group of the site.

    .PARAMETER Name
    The name of the site.

    .EXAMPLE
    _getWebAppSiteResource -ResourceGroupName 'my-rg' -Name 'my-func-app'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $splat = @{
        Method = 'GET'
        ResourceGroupName = $ResourceGroupName
        ResourceProviderName = 'Microsoft.Web'
        ResourceType = 'sites'
        Name = $Name
        ApiVersion = '2024-04-01'
    }
    $response = Invoke-AzRestMethod @splat

    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        throw "Azure Resource Manager returned HTTP $($response.StatusCode) for the site '$Name' in the resource group '$ResourceGroupName'. Check that the site exists and that you can read it. Response: $($response.Content)"
    }

    $response.Content | ConvertFrom-Json -Depth 100
}
