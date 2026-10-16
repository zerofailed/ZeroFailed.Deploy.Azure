# <copyright file="Test-FlexConsumptionFunctionApp.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Test-FlexConsumptionFunctionApp {
    <#
    .SYNOPSIS
    Checks whether a Function App runs on the Flex Consumption plan.

    .DESCRIPTION
    Reads the site's 'properties.sku' value from Azure Resource Manager. The function returns $true when the value is
    'FlexConsumption', which is the same check that the Azure CLI uses. For apps on other plans, and for App Service
    apps, the function returns $false.

    .PARAMETER ResourceGroupName
    The resource group of the app.

    .PARAMETER Name
    The name of the app.

    .EXAMPLE
    Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $site = _getWebAppSiteResource -ResourceGroupName $ResourceGroupName -Name $Name
    $sku = $site.properties.sku
    Write-Verbose "The site '$Name' has the SKU '$sku'"

    return ($sku -eq 'FlexConsumption')
}
