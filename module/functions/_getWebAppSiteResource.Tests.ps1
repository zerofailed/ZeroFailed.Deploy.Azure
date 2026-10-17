# <copyright file="_getWebAppSiteResource.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # Mock external dependencies
    Import-Module Az.Accounts
}

Describe '_getWebAppSiteResource' {

    Context 'When the site exists' {
        BeforeAll {
            Mock Invoke-AzRestMethod {
                [pscustomobject]@{
                    StatusCode = 200
                    Content = '{"name":"my-func-app","properties":{"sku":"FlexConsumption","hostNameSslStates":[{"name":"my-func-app.scm.azurewebsites.net","hostType":"Repository"}]}}'
                }
            }
        }

        It 'should return the parsed site resource' {
            $result = _getWebAppSiteResource -ResourceGroupName 'my-rg' -Name 'my-func-app'

            $result.name | Should -Be 'my-func-app'
            $result.properties.sku | Should -Be 'FlexConsumption'
            $result.properties.hostNameSslStates[0].hostType | Should -Be 'Repository'
        }

        It 'should request the site resource with a recent API version' {
            _getWebAppSiteResource -ResourceGroupName 'my-rg' -Name 'my-func-app'

            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter {
                $Method -eq 'GET' -and
                $ResourceGroupName -eq 'my-rg' -and
                $ResourceProviderName -eq 'Microsoft.Web' -and
                $ResourceType -eq 'sites' -and
                $Name -eq 'my-func-app' -and
                $ApiVersion -eq '2024-04-01'
            }
        }
    }

    Context 'When Azure Resource Manager returns an error' {
        It 'should throw an error that contains HTTP <StatusCode> and the response' -ForEach @(
            @{ StatusCode = 403; Content = '{"error":{"code":"AuthorizationFailed"}}' }
            @{ StatusCode = 404; Content = '{"error":{"code":"ResourceNotFound"}}' }
        ) {
            Mock Invoke-AzRestMethod {
                [pscustomobject]@{
                    StatusCode = $StatusCode
                    Content = $Content
                }
            }

            { _getWebAppSiteResource -ResourceGroupName 'my-rg' -Name 'my-func-app' } |
                Should -Throw "*HTTP $StatusCode*'my-func-app'*'my-rg'*$Content*"
        }
    }
}
