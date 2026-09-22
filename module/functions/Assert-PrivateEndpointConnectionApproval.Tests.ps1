# <copyright file="Assert-PrivateEndpointConnectionApproval.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # Make the Az.Network cmdlets available for mocking, without requiring the module to be installed
    function Get-AzPrivateEndpointConnection {
        [CmdletBinding()]
        param ([string] $PrivateLinkResourceId, [string] $ResourceId)
    }
    function Approve-AzPrivateEndpointConnection {
        [CmdletBinding()]
        param ([string] $ResourceId, [string] $Description)
    }

    Set-StrictMode -Version Latest

    $script:targetId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sales-dev/providers/Microsoft.KeyVault/vaults/kv-sales-dev'

    function New-TestConnection {
        param ([string] $PrivateEndpointName, [string] $Status, [string] $Name = "conn-$PrivateEndpointName")
        [pscustomobject]@{
            Id              = "$script:targetId/privateEndpointConnections/$Name"
            Name            = $Name
            PrivateEndpoint = if ($PrivateEndpointName) {
                [pscustomobject]@{ Id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/managed-rg/providers/Microsoft.Network/privateEndpoints/$PrivateEndpointName" }
            } else { $null }
            PrivateLinkServiceConnectionState = [pscustomobject]@{ Status = $Status; Description = 'Fabric access from sales-ETL [DEV]' }
        }
    }
}

Describe 'Assert-PrivateEndpointConnectionApproval' {

    BeforeEach {
        Mock Start-Sleep {}
        Mock Write-Warning {}
    }

    Context 'Pending connection' {

        BeforeEach {
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $PrivateLinkResourceId } {
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Pending'
                New-TestConnection -PrivateEndpointName 'other-endpoint' -Status 'Pending'
            }
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $ResourceId } {
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Approved'
            }
            Mock Approve-AzPrivateEndpointConnection {}
        }

        It 'approves only the connection whose private endpoint name matches the pattern' {
            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault'

            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 1 -ParameterFilter {
                $ResourceId -eq "$script:targetId/privateEndpointConnections/conn-ws-1.kv-sales-dev.vault"
            }
            $result.Action         | Should -Be 'Approved'
            $result.PreviousStatus | Should -Be 'Pending'
            $result.Status         | Should -Be 'Approved'
        }

        It 'returns a report describing the connection' {
            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault'

            $result.PrivateLinkResourceId | Should -Be $script:targetId
            $result.PrivateEndpointName   | Should -Be 'ws-1.kv-sales-dev.vault'
            $result.ConnectionName        | Should -Be 'conn-ws-1.kv-sales-dev.vault'
            $result.ConnectionId          | Should -Be "$script:targetId/privateEndpointConnections/conn-ws-1.kv-sales-dev.vault"
        }

        It 'uses the default approval description' {
            Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' | Out-Null

            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 1 -ParameterFilter {
                $Description -eq 'Approved by the ZeroFailed deployment process'
            }
        }

        It 'passes a custom approval description' {
            Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' -Description 'Approved for sales-ETL' | Out-Null

            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 1 -ParameterFilter { $Description -eq 'Approved for sales-ETL' }
        }

        It 'does not approve the connection when -WhatIf is set' {
            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' -WhatIf

            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 0
            $result.Action | Should -Be 'WhatIf'
            $result.Status | Should -Be 'Pending'
        }

        It 'propagates an error from the approval, such as missing permissions' {
            Mock Approve-AzPrivateEndpointConnection { throw "The client does not have authorization to perform action 'Microsoft.KeyVault/vaults/privateEndpointConnectionsApproval/action'" }

            { Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' } |
                Should -Throw '*does not have authorization*'
        }
    }

    Context 'Approval that takes time to take effect' {

        BeforeEach {
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $PrivateLinkResourceId } {
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Pending'
            }
            Mock Approve-AzPrivateEndpointConnection {}
        }

        It 'waits until the connection shows as approved' {
            $script:statusChecks = 0
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $ResourceId } {
                $script:statusChecks++
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status $(if ($script:statusChecks -ge 3) { 'Approved' } else { 'Pending' })
            }

            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' -PollIntervalSeconds 5

            $result.Status | Should -Be 'Approved'
            Should -Invoke Start-Sleep -Exactly 2 -ParameterFilter { $Seconds -eq 5 }
        }

        It 'warns when the approval has not taken effect before the timeout' {
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $ResourceId } {
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Pending'
            }

            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' -TimeoutSeconds 30 -PollIntervalSeconds 10

            $result.Action | Should -Be 'Approved'
            $result.Status | Should -Be 'Pending'
            Should -Invoke Start-Sleep -Exactly 3
            Should -Invoke Write-Warning -Exactly 1 -ParameterFilter { $Message -like "*still 'Pending'*" }
        }
    }

    Context 'Already approved connection' {

        BeforeEach {
            Mock Get-AzPrivateEndpointConnection {
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Approved'
            }
            Mock Approve-AzPrivateEndpointConnection {}
        }

        It 'skips the approval' {
            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault'

            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 0
            $result.Action         | Should -Be 'Skipped'
            $result.PreviousStatus | Should -Be 'Approved'
            $result.Status         | Should -Be 'Approved'
        }
    }

    Context 'Rejected or disconnected connection' {

        BeforeEach {
            Mock Approve-AzPrivateEndpointConnection {}
        }

        It 'leaves a <_> connection alone and warns' -ForEach @('Rejected', 'Disconnected') {
            $status = $_
            Mock Get-AzPrivateEndpointConnection { New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status $status }

            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault'

            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 0
            $result.Action | Should -Be 'None'
            $result.Status | Should -Be $status
            Should -Invoke Write-Warning -Exactly 1 -ParameterFilter { $Message -like "*has status '$status'*" }
        }
    }

    Context 'Connection that is not visible yet' {

        BeforeEach {
            Mock Approve-AzPrivateEndpointConnection {}
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $ResourceId } {
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Approved'
            }
        }

        It 'waits for the connection to appear and then approves it' {
            $script:listCalls = 0
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $PrivateLinkResourceId } {
                $script:listCalls++
                if ($script:listCalls -ge 2) { New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Pending' }
            }

            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault'

            $result.Action | Should -Be 'Approved'
            Should -Invoke Start-Sleep -Exactly 1
            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 1
        }

        It 'reports NotFound and warns when the connection does not appear before the timeout' {
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $PrivateLinkResourceId } {
                New-TestConnection -PrivateEndpointName 'other-endpoint' -Status 'Pending'
            }

            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' -TimeoutSeconds 60 -PollIntervalSeconds 20

            $result.Action         | Should -Be 'None'
            $result.Status         | Should -Be 'NotFound'
            $result.ConnectionName | Should -BeNullOrEmpty
            Should -Invoke Start-Sleep -Exactly 3
            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 0
            Should -Invoke Write-Warning -Exactly 1 -ParameterFilter { $Message -like '*No private endpoint connection matching*' }
        }

        It 'looks only once when the timeout is zero' {
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $PrivateLinkResourceId } {}

            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' -TimeoutSeconds 0

            $result.Status | Should -Be 'NotFound'
            Should -Invoke Get-AzPrivateEndpointConnection -Exactly 1 -ParameterFilter { $PrivateLinkResourceId }
            Should -Invoke Start-Sleep -Exactly 0
        }

        It 'ignores connections that have no private endpoint' {
            Mock Get-AzPrivateEndpointConnection -ParameterFilter { $PrivateLinkResourceId } {
                New-TestConnection -PrivateEndpointName $null -Status 'Pending' -Name 'orphaned'
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Pending'
            }

            $result = Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault'

            $result.ConnectionName | Should -Be 'conn-ws-1.kv-sales-dev.vault'
        }
    }

    Context 'Ambiguous pattern' {

        It 'throws when more than one connection matches' {
            Mock Get-AzPrivateEndpointConnection {
                New-TestConnection -PrivateEndpointName 'ws-1.kv-sales-dev.vault' -Status 'Pending'
                New-TestConnection -PrivateEndpointName 'ws-2.kv-sales-dev.vault' -Status 'Pending'
            }
            Mock Approve-AzPrivateEndpointConnection {}

            { Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $script:targetId -PrivateEndpointNameLike '*kv-sales-dev.vault' } |
                Should -Throw "*More than one*'ws-1.kv-sales-dev.vault', 'ws-2.kv-sales-dev.vault'*"
            Should -Invoke Approve-AzPrivateEndpointConnection -Exactly 0
        }
    }

    Context 'Unsupported resource type' {

        It 'propagates the error from Az.Network' {
            Mock Get-AzPrivateEndpointConnection { throw "Invalid parameter 'PrivateLinkResourceType'. The resource type 'Microsoft.Kusto/clusters' is not supported." }

            { Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId '/subscriptions/0/resourceGroups/rg/providers/Microsoft.Kusto/clusters/adx' -PrivateEndpointNameLike '*adx*' } |
                Should -Throw '*not supported*'
        }
    }
}
