# <copyright file="_AiSearch.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _removeExistingTempRules_AiSearch {
    <#
    .SYNOPSIS
    Implements the handler for removing temporary network access rule(s) for Azure AI Search.

    .DESCRIPTION
    Implements the handler for removing temporary network access rule(s) for Azure AI Search.

    .PARAMETER ResourceGroupName
    The resource group of the AI Search instance being updated.

    .PARAMETER ResourceName
    The name of the AI Search instance being updated.

    .NOTES
    Handlers expect the following script-level variables to have been defined by their caller, which of them are
    consumed by a given handler is implementation-specific.

        - $script:currentPublicIpAddress
        - $script:ruleName
        - $script:ruleDescription
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceName
    )

    $searchService = Get-AzSearchService `
                        -ResourceGroupName $ResourceGroupName `
                        -Name $ResourceName

    if ($searchService.NetworkRuleSet -and $searchService.NetworkRuleSet.IpRules) {
        # AI Search stores IP addresses without CIDR notation for single IPs
        $currentAllowedIPs = $searchService.NetworkRuleSet.IpRules | ForEach-Object { $_.Value }

        # Filter out our current IP address from the existing rules
        $updatedAllowedIPs = @( ($currentAllowedIPs | Where-Object { $_ -ne $script:currentPublicIpAddress }) )

        $searchService | ConvertTo-Json -depth 10
        $payload = @{
            properties = @{
                networkRuleSet = @{
                    ipRules = @( ($updatedAllowedIPs ? ($updatedAllowedIPs | ForEach-Object { @{ value = $_}}) : @()) )
                }
            }
        }
        $resp = Invoke-AzRestMethod -Method PATCH -Uri "https://management.azure.com$($searchService.Id)?api-version=2025-05-01" -Payload ($payload | ConvertTo-Json -Depth 10)
        if ($resp.StatusCode -ge 400) {
            throw $_.Exception.Message
        }
    }
}

function _addTempRule_AiSearch {
    <#
    .SYNOPSIS
    Implements the handler for adding temporary network access rule for Azure AI Search.

    .DESCRIPTION
    Implements the handler for adding temporary network access rule for Azure AI Search.

    .PARAMETER ResourceGroupName
    The resource group of the AI Search instance being updated.

    .PARAMETER ResourceName
    The name of the AI Search instance being updated.

    .NOTES
    Handlers expect the following script-level variables to have been defined by their caller, which of them are
    consumed by a given handler is implementation-specific.

        - $script:currentPublicIpAddress
        - $script:ruleName
        - $script:ruleDescription
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceName
    )

    $searchService = Get-AzSearchService `
                        -ResourceGroupName $ResourceGroupName `
                        -Name $ResourceName

    $currentAllowedIPs = @()
    if ($searchService.NetworkRuleSet -and $searchService.NetworkRuleSet.IpRules) {
        $currentAllowedIPs = @( ($searchService.NetworkRuleSet.IpRules | ForEach-Object { $_.Value }) )
    }

    # Add our IP if it's not already present
    if ($script:currentPublicIpAddress -notin $currentAllowedIPs) {
        $updatedAllowedIPs = $currentAllowedIPs + $script:currentPublicIpAddress
        
        $payload = @{
            properties = @{
                networkRuleSet = @{
                    ipRules = @( ($updatedAllowedIPs ? ($updatedAllowedIPs | ForEach-Object { @{ value = $_}}) : @()) )
                }
            }
        }
        $resp = Invoke-AzRestMethod -Method PATCH -Uri "https://management.azure.com$($searchService.Id)?api-version=2025-05-01" -Payload ($payload | ConvertTo-Json -Depth 10)
        if ($resp.StatusCode -ge 400) {
            throw $resp.Content
        }
    }
}

function _waitForRule_AiSearch {
    <#
    .SYNOPSIS
    Implements the typical delay required before network access rules take effect for this resource type.

    .DESCRIPTION
    Implements the typical delay required before network access rules take effect for this resource type.
    #>

    [CmdletBinding()]
    param ()
    
    Write-Host "Waiting for AI Search rule changes to take effect..."
    do {
       Start-Sleep -Seconds 10
    }
    until ((Get-AzSearchService -ResourceGroupName $ResourceGroupName -Name $ResourceName).Status -eq 'Running')
}