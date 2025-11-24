# <copyright file="Set-TemporaryAzureResourceNetworkAccess.Handlers.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeDiscovery {
    # Find all the handler implementations
    $here = Split-Path -Parent $PSCommandPath
    $handlers = Get-ChildItem -Path (Join-Path (Split-Path -Parent $PSCommandPath) '..' '_azureResourceNetworkAccessHandlers') -Filter '_*.ps1'
}

Describe "Handler Validation Tests" {

    Context "Test handler <_>" -ForEach $handlers {

        BeforeAll {
            $handlerName = (Split-Path -LeafBase $_.FullName).TrimStart("_")

            . $_.FullName
        }
        
        It "should implement the 'addRule' function" {
            Get-Command "_addTempRule_$handlerName" | Should -Not -BeNullOrEmpty
        }
        It "should implement the 'removeRules' function" {
            Get-Command "_removeExistingTempRules_$handlerName" | Should -Not -BeNullOrEmpty
        }
        It "should implement the 'waitForRule' function" {
            Get-Command "_waitForRule_$handlerName" | Should -Not -BeNullOrEmpty
        }
    }
}