# <copyright file="Assert-TemporaryNetworkAccessRules.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # Make other functions available for mocking
    function Set-TemporaryAzureResourceNetworkAccess {}

    Set-StrictMode -Version Latest
}

Describe 'Assert-TemporaryNetworkAccessRules' {
    
    Context 'Valid resource configuration' {
        BeforeAll {
            Mock Set-TemporaryAzureResourceNetworkAccess {}
            Mock Write-Warning {}
        }

        It 'should log a warning and continue when incorrect configuration is provided' {
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
            
            $result = Assert-TemporaryNetworkAccessRules -RequiredResources $resources -Revoke -ErrorAction SilentlyContinue
            
            $result | Should -Invoke Set-TemporaryAzureResourceNetworkAccess -Exactly 2
            $result | Should -Invoke Write-Warning -Exactly 0
        }
    }

    Context 'Partial invalid resource configuration' {
        BeforeAll {
            Mock Set-TemporaryAzureResourceNetworkAccess {}
            Mock Write-Warning {}
        }

        It 'should log a warning and continue when incorrect configuration is provided' {
            $resources = @(
                @{
                    ResourceType = 'StorageAccount'
                    ResourceGroupName = 'my-resource-group'
                    Name = 'mystorageaccount'
                },
                @{
                    ResourceType = 'KeyVault'
                    ResourceGroupName = 'my-resource-group'
                }
            )
            
            $result = Assert-TemporaryNetworkAccessRules -RequiredResources $resources -Revoke -ErrorAction SilentlyContinue
            
            $result | Should -Invoke Set-TemporaryAzureResourceNetworkAccess -Exactly 1
            $result | Should -Invoke Write-Warning -Exactly 1
        }
    }
    
}