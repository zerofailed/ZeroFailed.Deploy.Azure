# <copyright file="Set-TemporaryAzureResourceNetworkAccess.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Set-TemporaryAzureResourceNetworkAccess {
    <#
    .SYNOPSIS
    Manages the addition and removal of temporary network access rules for different Azure resource types.

    .DESCRIPTION
    Each resource type implements its own handler for performing the addition and removal operations.

    .PARAMETER ResourceType
    The type of Azure resource to be managed.

    .PARAMETER ResourceGroupName
    The resource group of the resource to be managed.

    .PARAMETER ResourceName
    The name of the resource to be managed.

    .PARAMETER Revoke
    When true, any existing temporary network access rules for the specified resource will be removed. No
    rules will be added.

    .PARAMETER Wait
    When true, processing will wait for a time period implemented by the handler to allow the changes to take effect.

    .EXAMPLE
    ```powershell
    Set-TemporaryAzureResourceNetworkAccess -ResourceType KeyVault -ResourceGroupName 'my-resource-group' -ResourceName 'my-key-vault' -Wait
    ```

    Grants the current public IP address temporary access to a Key Vault, waiting for the rule to take effect.

    .EXAMPLE
    ```powershell
    Set-TemporaryAzureResourceNetworkAccess -ResourceType KeyVault -ResourceGroupName 'my-resource-group' -ResourceName 'my-key-vault' -Revoke
    ```

    Removes any temporary network access rules previously added to the Key Vault.
    #>
    [CmdletBinding()]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("AiSearch","KeyVault","SqlServer","StorageAccount","WebApp","WebAppScm")]
        [string] $ResourceType,

        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceName,

        [switch] $Revoke,

        [switch] $Wait
    )

    # Set optional values used by some handler implementations
    $script:ruleName = "temp-cicd-rule"
    $script:ruleDescription = "Temporary rule added by 'Set-TemporaryAzureResourceNetworkAccess'"
    $script:currentPublicIpAddress = (Invoke-RestMethod https://ifconfig.io).Trim()
    Write-Host "currentPublicIpAddress: $currentPublicIpAddress"

    # Configure handler settings for the given resource type
    $removeHandlerName = "_removeExistingTempRules_$ResourceType"
    $addHandlerName = "_addTempRule_$ResourceType"
    $waitHandlerName = "_waitForRule_$ResourceType"
    $handlerSplat = @{
        ResourceGroupName = $ResourceGroupName
        ResourceName = $ResourceName
    }

    # Load the handler, but not if running in Pester scenarios that need to mock them
    if (!(Test-Path variable:/IsRunningInPester) -or !$IsRunningInPester) {
        Write-Verbose "Importing handler: $ResourceType"
        . (Join-Path (Split-Path -Parent $PSCommandPath) '../_azureResourceNetworkAccessHandlers' "_$ResourceType.ps1")
    }

    $logSuffix = "[ResourceType=$ResourceType][ResourceGroupName=$ResourceGroupName][ResourceName=$ResourceName]"

    Write-Host "Purging existing temporary network access rules $logSuffix"
    & $removeHandlerName @handlerSplat | Out-Null
    
    if (!$Revoke) {
        Write-Host "Granting temporary network access to '$currentPublicIpAddress' $logSuffix"
        & $addHandlerName @handlerSplat | Out-String | Write-Host
    }

    if ($Wait) {
        & $waitHandlerName | Out-String | Write-Host
    }
}