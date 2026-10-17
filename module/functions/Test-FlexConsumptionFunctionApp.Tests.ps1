# <copyright file="Test-FlexConsumptionFunctionApp.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # Make private functions available for mocking
    function _getWebAppSiteResource { param ($ResourceGroupName, $Name) }
}

Describe 'Test-FlexConsumptionFunctionApp' {

    Context 'When the app is on the Flex Consumption plan' {
        It "should return true when the SKU is '<_>'" -ForEach @('FlexConsumption', 'flexconsumption', 'FLEXCONSUMPTION') {
            $sku = $_
            Mock _getWebAppSiteResource { [pscustomobject]@{ properties = [pscustomobject]@{ sku = $sku } } }

            Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app' | Should -BeTrue
        }

        It 'should look up the specified site' {
            Mock _getWebAppSiteResource { [pscustomobject]@{ properties = [pscustomobject]@{ sku = 'FlexConsumption' } } }

            Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app'

            Should -Invoke _getWebAppSiteResource -Exactly -Times 1 -ParameterFilter {
                $ResourceGroupName -eq 'my-rg' -and $Name -eq 'my-func-app'
            }
        }
    }

    Context 'When the app is not on the Flex Consumption plan' {
        It "should return false when the SKU is '<_>'" -ForEach @('Dynamic', 'Standard', 'ElasticPremium', 'Free') {
            $sku = $_
            Mock _getWebAppSiteResource { [pscustomobject]@{ properties = [pscustomobject]@{ sku = $sku } } }

            Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app' | Should -BeFalse
        }

        It 'should return false when the site has no SKU' {
            Mock _getWebAppSiteResource { [pscustomobject]@{ properties = [pscustomobject]@{} } }

            Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app' | Should -BeFalse
        }
    }

    Context 'When the site cannot be read' {
        It 'should not catch the error' {
            Mock _getWebAppSiteResource { throw 'Azure Resource Manager returned HTTP 404' }

            { Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app' } |
                Should -Throw '*HTTP 404*'
        }
    }
}
