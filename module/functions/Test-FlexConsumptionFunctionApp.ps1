# <copyright file="Test-FlexConsumptionFunctionApp.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Test-FlexConsumptionFunctionApp {
    <#
    .SYNOPSIS
    Checks whether a Function App runs on the Flex Consumption plan.

    .DESCRIPTION
    The function reads the `properties.sku` value of the app's site resource from Azure Resource Manager.
    It returns `$true` when the value is `FlexConsumption`, which is the check that the Azure CLI uses.
    For apps on other plans, and for App Service apps, it returns `$false`.

    .PARAMETER ResourceGroupName
    The resource group of the app.

    .PARAMETER Name
    The name of the app.

    .EXAMPLE
    ```powershell
    Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app'
    ```

    Returns `$true` if `my-func-app` is a Function App on the Flex Consumption plan.

    .NOTES
    This function requires the Az.Accounts module and an active Azure PowerShell connection.
    The identity needs permission to read the app's site resource, which the Reader role includes.
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
