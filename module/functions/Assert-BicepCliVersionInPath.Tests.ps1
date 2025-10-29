# <copyright file="Assert-BicepCliVersionInPath.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    
    # Make private functions available for mocking
    function _getBicepVersion {}
    function _getAzBicepVersion {}
    function _installAzBicep { param ($Version) }
    
    # Mock external dependencies
    Mock Get-Command {}
    Mock Invoke-RestMethod { @{ tag_name = 'v0.40.0' } }
    Mock Write-Verbose {}
    Mock Set-Item {}
    Mock _installAzBicep {}
}

Describe 'Assert-BicepCliVersionInPath' {
    
    Context 'When no Bicep CLI is installed' {
        BeforeEach {
            Mock Get-Command {} -ParameterFilter { $Name -eq 'bicep' }
            Mock _getAzBicepVersion {}
            Mock _getBicepVersion {}
        }
        
        It 'Should install latest version when RequiredBicepVersion is empty' {
            Assert-BicepCliVersionInPath -RequiredBicepVersion ''
            
            Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.40.0' }
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
        
        It 'Should install specific version when RequiredBicepVersion is specified' {
            Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
            
            Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.38.33' }
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
        
        It 'Should install latest version when using minimum version parameter set' {
            Assert-BicepCliVersionInPath -MinimumBicepVersion '0.35.0'
            
            Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.40.0' }
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
    }
    
    if ($IsWindows) {
        Context 'When Bicep CLI is installed on Windows' {
            BeforeEach {
                $mockCommand = [PSCustomObject]@{
                    Version = [System.Version]::new(0, 38, 33)
                    Path = 'C:\Program Files\bicep.exe'
                }
                Mock Get-Command { $mockCommand } -ParameterFilter { $Name -eq 'bicep' }
                Mock _getBicepVersion { "Bicep CLI version $($mockCommand.Version) (def456)" }
            }
            
            It 'Should not require installation when required version matches installed version available in the PATH' {
                Mock _getAzBicepVersion {}
    
                Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
                
                Should -Not -Invoke _installAzBicep
                Should -Not -Invoke Set-Item
            }
            
            It 'Should require installation when required version differs from installed version available in the PATH and via Azure CLI' {
                Mock _getAzBicepVersion { 'Bicep CLI version 0.38.33 (def456)' }
                
                Assert-BicepCliVersionInPath -RequiredBicepVersion '0.39.0'
                
                Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.39.0' }
                Should -Invoke Set-Item -Times 1 -ParameterFilter {
                    $Path -eq 'env:/PATH' -and 
                    $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
                }
            }
            
            It 'Should upgrade when installed version version available in the PATH and via Azure CLI is below minimum version' {
                Mock _getAzBicepVersion { 'Bicep CLI version 0.38.33 (def456)' }
                
                Assert-BicepCliVersionInPath -MinimumBicepVersion '0.39.0'
                
                Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.40.0' }
                Should -Invoke Set-Item -Times 1 -ParameterFilter {
                    $Path -eq 'env:/PATH' -and 
                    $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
                }
            }
            
            It 'Should not upgrade when installed version available in the PATH meets minimum version' {
                Mock _getAzBicepVersion {}
                
                Assert-BicepCliVersionInPath -MinimumBicepVersion '0.38.0'
                
                Should -Not -Invoke _installAzBicep
                Should -Not -Invoke Set-Item
            }
        }
    }
    
    if (!$IsWindows) {
        Context 'When Bicep CLI is installed on non-Windows' {
            BeforeEach {
                $mockCommand = [PSCustomObject]@{
                    Path = '/usr/local/bin/bicep'
                }
                Mock Get-Command { $mockCommand } -ParameterFilter { $Name -eq 'bicep' }
                Mock _getBicepVersion { 'Bicep CLI version 0.38.33 (abc123)' }
            }
            
            It 'Should parse version from bicep --version output correctly' {
                Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
                
                Should -Invoke _getBicepVersion -Times 1
                Should -Not -Invoke az -ParameterFilter { $Args[0] -eq 'bicep' -and $Args[1] -eq 'install' }
            }
        }
    }
    
    Context 'When RequiredBicepVersion is "latest"' {
        BeforeEach {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'bicep' }
            Mock _getBicepVersion {}
            Mock _getAzBicepVersion {}
        }
        
        It 'Should resolve "latest" to actual latest version from GitHub API' {
            Assert-BicepCliVersionInPath -RequiredBicepVersion 'latest'
            
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -eq 'https://aka.ms/BicepLatestRelease' }
            Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.40.0' }
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
    }
    
    Context 'When Azure CLI already has the required version' {
        BeforeEach {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'bicep' }
            Mock _getBicepVersion {}
            Mock _getAzBicepVersion { 'Bicep CLI version 0.38.33 (def456)' }
        }
        
        It 'Should skip installation if Azure CLI already has the required version and update the PATH' {
            Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
            
            Should -Not -Invoke _installAzBicep
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
    }
    
    Context 'Error handling' {
        It 'Should handle network failures when checking latest version' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'bicep' }
            Mock Invoke-RestMethod { throw 'Network error' } -ParameterFilter { $Uri -eq 'https://aka.ms/BicepLatestRelease' }
            
            { Assert-BicepCliVersionInPath -RequiredBicepVersion 'latest' } | Should -Throw
        }
        
        It 'Should handle Azure CLI installation failures gracefully' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'bicep' }
            Mock _installAzBicep { exit 1 }
            $PSNativeCommandUseErrorActionPreference = $true
            
            { Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33' } | Should -Throw
        }
    }
}