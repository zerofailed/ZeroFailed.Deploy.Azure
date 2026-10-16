# <copyright file="apps.tasks.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Stand-in for the InvokeBuild 'task' command, which records each task's condition and jobs
    $script:tasks = @{}
    function Add-TestTask {
        param (
            [Parameter(Position = 0)] [string] $Name,
            [Parameter(Position = 1)] [object[]] $Jobs,
            [scriptblock] $If,
            [string[]] $After
        )
        $script:tasks[$Name] = @{ If = $If; Jobs = $Jobs }
    }

    # Stand-in for the InvokeBuild 'property' command
    function Get-TestProperty {
        param ($Name, $Default)
        $Default
    }

    # InvokeBuild defines 'task' and 'property' as aliases when these tests run as part of a build.
    # Aliases take precedence over functions, so use local aliases to replace them.
    Set-Alias -Name task -Value Add-TestTask -Scope Local
    Set-Alias -Name property -Value Get-TestProperty -Scope Local

    function Write-Build { param ($Color, $Text) }

    # Stand-in for the ZeroFailed.DevOps.Common 'Resolve-Value' function
    function Resolve-Value {
        param ($Value)
        if ($Value -is [scriptblock]) { $Value.Invoke() } else { $Value }
    }

    # Make other functions available for mocking
    function Test-FlexConsumptionFunctionApp { param ($ResourceGroupName, $Name) }
    function Publish-FlexConsumptionFunctionApp { param ($ResourceGroupName, $Name, $ArchivePath, [switch] $RemoteBuild, $TimeoutSeconds) }
    function Publish-AzWebApp { [CmdletBinding()] param ($ResourceGroupName, $Name, $ArchivePath, [switch] $Force) }
    function Set-TemporaryAzureResourceNetworkAccess { param ($ResourceType, $ResourceGroupName, $ResourceName, [switch] $Revoke, [switch] $Wait) }

    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    $taskCondition = $script:tasks['deployAppServiceZipPackages'].If
    $taskAction = $script:tasks['deployAppServiceZipPackages'].Jobs | Where-Object { $_ -is [scriptblock] }
}

Describe 'deployAppServiceZipPackages' {

    BeforeEach {
        Mock Test-FlexConsumptionFunctionApp { $false }
        Mock Publish-FlexConsumptionFunctionApp {}
        Mock Publish-AzWebApp {}
        Mock Set-TemporaryAzureResourceNetworkAccess {}
        Mock Write-Warning {}

        $deploymentConfig = @{
            appServiceName = 'my-app'
            resourceGroupName = 'my-rg'
        }
        $AppServiceRequiresTemporaryNetworkAccess = $false
        $AppServiceFlexDeploymentTimeoutSeconds = 600
    }

    Context 'Task condition' {
        It 'should run when apps are configured' {
            $SkipAppServiceAppDeployment = $false
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip' })

            & $taskCondition | Should -BeTrue
        }

        It 'should not run when no apps are configured' {
            $SkipAppServiceAppDeployment = $false
            $AppServiceAppsToDeploy = @()

            & $taskCondition | Should -BeFalse
        }

        It 'should not run when SkipAppServiceAppDeployment is true' {
            $SkipAppServiceAppDeployment = $true
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip' })

            & $taskCondition | Should -BeFalse
        }
    }

    Context 'When the app is a Function App on the Flex Consumption plan' {
        BeforeEach {
            Mock Test-FlexConsumptionFunctionApp { $true }
        }

        It 'should deploy with Publish-FlexConsumptionFunctionApp and without a remote build by default' {
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip' })

            & $taskAction

            Should -Invoke Test-FlexConsumptionFunctionApp -Times 1 -ParameterFilter { $ResourceGroupName -eq 'my-rg' -and $Name -eq 'my-app' }
            Should -Invoke Publish-FlexConsumptionFunctionApp -Times 1 -ParameterFilter {
                $ResourceGroupName -eq 'my-rg' -and
                $Name -eq 'my-app' -and
                $ArchivePath -eq 'app.zip' -and
                $RemoteBuild -eq $false -and
                $TimeoutSeconds -eq 600
            }
            Should -Not -Invoke Publish-AzWebApp
        }

        It "should request a remote build when 'remoteBuild' is <_>" -ForEach @(
            $true
            'true'
            { $true }
        ) {
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip'; remoteBuild = $_ })

            & $taskAction

            Should -Invoke Publish-FlexConsumptionFunctionApp -Times 1 -ParameterFilter { $RemoteBuild -eq $true }
        }

        It "should not request a remote build when 'remoteBuild' is <_>" -ForEach @(
            $false
            'false'
        ) {
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip'; remoteBuild = $_ })

            & $taskAction

            Should -Invoke Publish-FlexConsumptionFunctionApp -Times 1 -ParameterFilter { $RemoteBuild -eq $false }
        }

        It 'should pass the configured timeout' {
            $AppServiceFlexDeploymentTimeoutSeconds = 1200
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip' })

            & $taskAction

            Should -Invoke Publish-FlexConsumptionFunctionApp -Times 1 -ParameterFilter { $TimeoutSeconds -eq 1200 }
        }
    }

    Context 'When the app is not on the Flex Consumption plan' {
        It 'should deploy with Publish-AzWebApp' {
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip' })

            & $taskAction

            Should -Invoke Publish-AzWebApp -Times 1 -ParameterFilter {
                $ResourceGroupName -eq 'my-rg' -and $Name -eq 'my-app' -and $ArchivePath -eq 'app.zip'
            }
            Should -Not -Invoke Publish-FlexConsumptionFunctionApp
            Should -Not -Invoke Write-Warning
        }

        It "should write a warning when 'remoteBuild' is set" {
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip'; remoteBuild = $true })

            & $taskAction

            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like "*'my-app'*ignores its 'remoteBuild' setting*" }
            Should -Invoke Publish-AzWebApp -Times 1
        }
    }

    Context 'When configuration values are scriptblocks' {
        It 'should resolve each value before it deploys a Flex Consumption app' {
            Mock Test-FlexConsumptionFunctionApp { $true }
            $AppServiceAppsToDeploy = @(@{
                appServiceName = { $deploymentConfig.appServiceName }
                resourceGroupName = { $deploymentConfig.resourceGroupName }
                zipPackagePath = { 'lazy.zip' }
            })

            & $taskAction

            Should -Invoke Test-FlexConsumptionFunctionApp -Times 1 -ParameterFilter { $ResourceGroupName -eq 'my-rg' -and $Name -eq 'my-app' }
            Should -Invoke Publish-FlexConsumptionFunctionApp -Times 1 -ParameterFilter {
                $ResourceGroupName -eq 'my-rg' -and $Name -eq 'my-app' -and $ArchivePath -eq 'lazy.zip'
            }
        }

        It 'should resolve each value before it deploys another app' {
            $AppServiceAppsToDeploy = @(@{
                appServiceName = { $deploymentConfig.appServiceName }
                resourceGroupName = { $deploymentConfig.resourceGroupName }
                zipPackagePath = { 'lazy.zip' }
            })

            & $taskAction

            Should -Invoke Publish-AzWebApp -Times 1 -ParameterFilter {
                $ResourceGroupName -eq 'my-rg' -and $Name -eq 'my-app' -and $ArchivePath -eq 'lazy.zip'
            }
        }
    }

    Context 'When several apps are configured' {
        It 'should detect the plan of each app separately' {
            Mock Test-FlexConsumptionFunctionApp { $true } -ParameterFilter { $Name -eq 'flex-app' }
            $AppServiceAppsToDeploy = @(
                @{ appServiceName = 'flex-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'flex.zip' }
                @{ appServiceName = 'web-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'web.zip' }
            )

            & $taskAction

            Should -Invoke Publish-FlexConsumptionFunctionApp -Times 1 -ParameterFilter { $Name -eq 'flex-app' -and $ArchivePath -eq 'flex.zip' }
            Should -Invoke Publish-AzWebApp -Times 1 -ParameterFilter { $Name -eq 'web-app' -and $ArchivePath -eq 'web.zip' }
        }
    }

    Context 'When the app requires temporary network access' {
        BeforeEach {
            $AppServiceRequiresTemporaryNetworkAccess = $true
            $AppServiceAppsToDeploy = @(@{ appServiceName = 'my-app'; resourceGroupName = 'my-rg'; zipPackagePath = 'app.zip' })
        }

        It 'should grant access to the SCM site before a Flex Consumption deployment, and revoke it afterwards' {
            Mock Test-FlexConsumptionFunctionApp { $true }

            & $taskAction

            Should -Invoke Set-TemporaryAzureResourceNetworkAccess -Times 1 -ParameterFilter {
                $ResourceType -eq 'WebAppScm' -and $ResourceGroupName -eq 'my-rg' -and $ResourceName -eq 'my-app' -and $Wait
            }
            Should -Invoke Set-TemporaryAzureResourceNetworkAccess -Times 1 -ParameterFilter {
                $ResourceType -eq 'WebAppScm' -and $ResourceGroupName -eq 'my-rg' -and $ResourceName -eq 'my-app' -and $Revoke
            }
        }

        It 'should revoke access when the deployment fails' {
            Mock Test-FlexConsumptionFunctionApp { $true }
            Mock Publish-FlexConsumptionFunctionApp { throw 'Deployment failed' }

            { & $taskAction } | Should -Throw 'Deployment failed'

            Should -Invoke Set-TemporaryAzureResourceNetworkAccess -Times 1 -ParameterFilter { $Revoke }
        }
    }
}
