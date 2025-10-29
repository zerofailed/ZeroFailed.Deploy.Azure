# <copyright file="Assert-BicepCliVersionInPath.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    
    # Make private functions available for mocking
    function _getBicepVersion {}
    function _getAzBicepVersion { param ([switch]$Before, [switch]$After)}
    function _installAzBicep { param ($Version) }
    
    # Mock external dependencies
    Mock Get-Command {}
    Mock Invoke-RestMethod { @{ tag_name = 'v0.40.0' } }
    Mock Write-Verbose {}
    Mock Write-Host {}
    Mock Set-Item {}
    Mock _installAzBicep {}
}

Describe 'Assert-BicepCliVersionInPath' {
    
    Context 'When no Bicep CLI is installed' {
        BeforeEach {
            Mock Get-Command {} -ParameterFilter { $Name -eq 'bicep' }
            Mock _getAzBicepVersion {} -ParameterFilter { $Before -eq $true }
            Mock _getBicepVersion {}
        }
        
        It 'Should install latest version when RequiredBicepVersion is empty' {
            Mock _getAzBicepVersion { '0.40.0' } -ParameterFilter { $After -eq $true }

            Assert-BicepCliVersionInPath -RequiredBicepVersion ''
            
            Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.40.0' }
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
        
        It 'Should install specific version when RequiredBicepVersion is specified' {
            Mock _getAzBicepVersion { '0.38.33' } -ParameterFilter { $After -eq $true }

            Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
            
            Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.38.33' }
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
        
        It 'Should install latest version when using minimum version parameter set' {
            Mock _getAzBicepVersion { '0.40.0' } -ParameterFilter { $After -eq $true }

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
                Mock _getBicepVersion { $mockCommand.Version }
                Mock _getAzBicepVersion { $mockCommand.Version } -ParameterFilter { $Before -eq $true }
            }
            
            It 'Should not require installation when required version matches installed version available in the PATH' {
                Mock _getAzBicepVersion {} -ParameterFilter { $Before -eq $true }
    
                Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
                
                Should -Not -Invoke _getAzBicepVersion
                Should -Not -Invoke _installAzBicep
                Should -Not -Invoke Set-Item
            }
            
            It 'Should require installation when required version differs from installed version available in the PATH and via Azure CLI' {
                Mock _getAzBicepVersion { '0.39.0' } -ParameterFilter { $After -eq $true }
                
                Assert-BicepCliVersionInPath -RequiredBicepVersion '0.39.0'
                
                Should -Invoke _getAzBicepVersion -Times 2
                Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.39.0' }
                Should -Invoke Set-Item -Times 1 -ParameterFilter {
                    $Path -eq 'env:/PATH' -and 
                    $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
                }
            }
            
            It 'Should upgrade to latest version when installed version available in the PATH and via Azure CLI is below minimum version' {
                Mock _getAzBicepVersion { '0.38.33' } -ParameterFilter { $Before -eq $true }
                Mock _getAzBicepVersion { '0.40.0' } -ParameterFilter { $After -eq $true }
                
                Assert-BicepCliVersionInPath -MinimumBicepVersion '0.39.0'
                
                Should -Invoke _getAzBicepVersion -Times 2
                Should -Invoke _installAzBicep -Times 1 -ParameterFilter { $Version -eq 'v0.40.0' }
                Should -Invoke Set-Item -Times 1 -ParameterFilter {
                    $Path -eq 'env:/PATH' -and 
                    $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
                }
            }
            
            It 'Should not upgrade when installed version available in the PATH meets minimum version' {
                Mock _getAzBicepVersion {}
                
                Assert-BicepCliVersionInPath -MinimumBicepVersion '0.38.0'
                
                Should -Not -Invoke _getAzBicepVersion
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
                Mock _getBicepVersion { '0.38.33' }
                Mock _getAzBicepVersion {}
                Mock _installAzBicep {}
            }
            
            It 'Should parse version from bicep --version output correctly' {
                Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
                
                Should -Invoke _getBicepVersion -Times 1
                Should -Not -Invoke _getAzBicepVersion
                Should -Not -Invoke _installAzBicep
                Should -Not -Invoke Set-Item
            }
        }
    }
    
    Context 'When RequiredBicepVersion is "latest"' {
        BeforeEach {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'bicep' }
            Mock _getBicepVersion {}
            Mock _getAzBicepVersion {} -ParameterFilter { $Before -eq $true }
            Mock _getAzBicepVersion { '0.40.0' } -ParameterFilter { $After -eq $true }
        }
        
        It 'Should resolve "latest" to actual latest version from GitHub API' {
            Assert-BicepCliVersionInPath -RequiredBicepVersion 'latest'
            
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -eq 'https://aka.ms/BicepLatestRelease' }
            Should -Invoke _getAzBicepVersion -Times 2
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
            Mock _getAzBicepVersion { '0.38.33' } -ParameterFilter { $Before -eq $true }
        }
        
        It 'Should skip installation if Azure CLI already has the required version and update the PATH' {
            Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
            
            Should -Invoke _getAzBicepVersion -Times 1
            Should -Not -Invoke _installAzBicep
            Should -Invoke Set-Item -Times 1 -ParameterFilter {
                $Path -eq 'env:/PATH' -and 
                $Value -eq (@([IO.Path]::Join($HOME, '.azure', 'bin'), $env:PATH -join [IO.Path]::PathSeparator))
            }
        }
    }

    Context 'When Azure CLI installation does not work as expected' {
        BeforeEach {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'bicep' }
            Mock _getBicepVersion {}
            # Simulate the installation not updating the available version
            Mock _getAzBicepVersion { '0.38.33' }
        }
        
        It 'Should throw an exception reporting the installation did not work as expected' {
            { Assert-BicepCliVersionInPath -RequiredBicepVersion '0.40.0' } | Should -Throw "Unexpected Bicep version found. Expected '0.40.0', found '0.38.33'"
            
            Should -Invoke _getAzBicepVersion -Times 2
            Should -Invoke _installAzBicep -Times 1
            Should -Not -Invoke Set-Item
        }
    }
    
    Context 'Error handling' {
        BeforeEach {
            Mock Get-Command {} -ParameterFilter { $Name -eq 'bicep' }
            Mock _getBicepVersion {}
            Mock _getAzBicepVersion {}
            Mock _installAzBicep {}
        }

        It 'Should handle network failures when checking latest version' {
            Mock Invoke-RestMethod { throw 'Network error' } -ParameterFilter { $Uri -eq 'https://aka.ms/BicepLatestRelease' }
            
            { Assert-BicepCliVersionInPath -RequiredBicepVersion 'latest' } | Should -Throw

            Should -Not -Invoke _getAzBicepVersion
            Should -Not -Invoke _installAzBicep
            Should -Not -Invoke Set-Item
        }
        
        It 'Should handle Azure CLI installation failures gracefully' {
            # Simulate a native command returning an error
            Mock _installAzBicep { & ./doesnotexist }

            {
                $ErrorActionPreference = 'Stop'
                $PSNativeCommandUseErrorActionPreference = $true
                Assert-BicepCliVersionInPath -RequiredBicepVersion '0.38.33'
            } | Should -Throw

            Should -Invoke _getAzBicepVersion -Times 1
            Should -Invoke _installAzBicep -Times 1
            Should -Not -Invoke Set-Item
        }
    }
}