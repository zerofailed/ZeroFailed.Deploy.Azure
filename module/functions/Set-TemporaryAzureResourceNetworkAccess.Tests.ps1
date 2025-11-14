# <copyright file="Set-TemporaryAzureResourceNetworkAccess.Handlers.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeDiscovery {
    # Find all the handler implementations
    $here = Split-Path -Parent $PSCommandPath
    $handlers = Get-ChildItem -Path (Join-Path (Split-Path -Parent $PSCommandPath) '..' '_azureResourceNetworkAccessHandlers') -Filter '_*.ps1'
}

BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    # Used to enable mocking the handlers which are dynamically loaded
    $IsRunningInPester = $true

    Mock Write-Host {}
    Mock Invoke-RestMethod { '1.1.1.1' }
}

AfterAll {
    Remove-Item variable:/IsRunningInPester
}

Describe "Set-TemporaryAzureResourceNetworkAccess Tests" {

    Context "Test handler <_>" -ForEach $handlers {

        BeforeAll {
            $handlerName = (Split-Path -LeafBase $_.FullName).TrimStart("_")

            # Make private handler functions available for mocking
            New-Item function:/_addTempRule_$handlerName -Value {}
            New-Item function:/_removeExistingTempRules_$handlerName -Value {}
            New-Item function:/_waitForRule_$handlerName -Value {}

            Mock _addTempRule_$handlerName {}
            Mock _removeExistingTempRules_$handlerName {}
            Mock _waitForRule_$handlerName {}
        }

        AfterAll {
            Remove-Item function:/_addTempRule_$handlerName
            Remove-Item function:/_removeExistingTempRules_$handlerName
            Remove-Item function:/_waitForRule_$handlerName
        }
        
        Context "When adding a temporary firewall rule without waiting" {
            BeforeAll {
                $splat = @{
                    ResourceType = $handlerName
                    ResourceGroupName = 'mock-rg'
                    ResourceName = 'mock-resource'
                }
            }
            It "should remove any existing temporary firewall rules" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _removeExistingTempRules_$handlerName -Times 1
            }
            It "should add a temporary firewall rule" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _addTempRule_$handlerName -Times 1
            }
            It "should not wait for the firewall change to complete" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Not -Invoke _waitForRule_$handlerName
            }
        }

        Context "When adding a temporary firewall rule and waiting for completion" {
            BeforeAll {
                $splat = @{
                    ResourceType = $handlerName
                    ResourceGroupName = 'mock-rg'
                    ResourceName = 'mock-resource'
                    Wait = $true
                }
            }
            It "should remove any existing temporary firewall rules" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _removeExistingTempRules_$handlerName -Times 1
            }
            It "should add a temporary firewall rule" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _addTempRule_$handlerName -Times 1
            }
            It "should wait for the firewall change to complete" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _waitForRule_$handlerName -Times 1
            }
        }

        Context "When revoking a temporary firewall rule without waiting" {
            BeforeAll {
                $splat = @{
                    ResourceType = $handlerName
                    ResourceGroupName = 'mock-rg'
                    ResourceName = 'mock-resource'
                    Revoke = $true
                }
            }
            It "should remove any existing temporary firewall rules" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _removeExistingTempRules_$handlerName -Times 1
            }
            It "should not add a temporary firewall rule" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Not -Invoke _addTempRule_$handlerName
            }
            It "should not wait for the firewall change to complete" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Not -Invoke _waitForRule_$handlerName
            }
        }

        Context "When revoking a temporary firewall rule and waiting for completion" {
            BeforeAll {
                $splat = @{
                    ResourceType = $handlerName
                    ResourceGroupName = 'mock-rg'
                    ResourceName = 'mock-resource'
                    Revoke = $true
                    Wait = $true
                }
            }
            It "should remove any existing temporary firewall rules" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _removeExistingTempRules_$handlerName -Times 1
            }
            It "should not add a temporary firewall rule" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Not -Invoke _addTempRule_$handlerName
            }
            It "should wait for the firewall change to complete" {
                Set-TemporaryAzureResourceNetworkAccess @splat
                Should -Invoke _waitForRule_$handlerName -Times 1
            }
        }
    }
}