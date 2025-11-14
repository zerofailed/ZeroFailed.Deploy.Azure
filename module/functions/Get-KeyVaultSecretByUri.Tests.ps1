# <copyright file="Get-KeyVaultSecretByUri.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    
    # Mock external dependencies
    Mock Import-Module {}
    
    Import-Module Az.KeyVault
    Mock Get-AzKeyVaultSecret {
        # Return a mock SecureString
        ConvertTo-SecureString -String "mock-secret-value" -AsPlainText -Force
    }
}

Describe 'Get-KeyVaultSecretByUri' {
    
    Context 'When using Az.KeyVault module version 6.3.0 or higher' {
        
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{
                    Name = 'Az.KeyVault'
                    Version = [Version]'6.3.0'
                }
            }
        }
        
        It 'should call Get-AzKeyVaultSecret with -Id parameter for version 6.3.0' {
            $testUri = 'https://myvault.vault.azure.net/secrets/mysecret/abc123'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $Id -eq $testUri
            }
        }
        
        It 'should call Get-AzKeyVaultSecret with -Id parameter for version 6.4.0' {
            Mock Get-Module {
                [PSCustomObject]@{
                    Name = 'Az.KeyVault'
                    Version = [Version]'6.4.0'
                }
            }
            
            $testUri = 'https://myvault.vault.azure.net/secrets/mysecret'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $Id -eq $testUri
            }
        }
        
        It 'should call Get-AzKeyVaultSecret with -Id parameter for version 7.0.0' {
            Mock Get-Module {
                [PSCustomObject]@{
                    Name = 'Az.KeyVault'
                    Version = [Version]'7.0.0'
                }
            }
            
            $testUri = 'https://myvault.vault.azure.net/secrets/mysecret/version123'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $Id -eq $testUri
            }
        }
        
        It 'should return a SecureString' {
            $testUri = 'https://myvault.vault.azure.net/secrets/mysecret'
            
            $result = Get-KeyVaultSecretByUri -SecretUri $testUri
            
            $result | Should -BeOfType [securestring]
        }
    }
    
    Context 'When using Az.KeyVault module version below 6.3.0 without secret version' {
        
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{
                    Name = 'Az.KeyVault'
                    Version = [Version]'6.2.9'
                }
            }
        }
        
        It 'should parse the URI and call Get-AzKeyVaultSecret with vaultName and secretName for version 6.2.9' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $vaultName -eq 'kvname' -and
                $secretName -eq 'secretname' -and
                $null -eq $secretVersion
            }
        }
        
        It 'should parse the URI and call Get-AzKeyVaultSecret with vaultName and secretName for version 5.0.0' {
            Mock Get-Module {
                [PSCustomObject]@{
                    Name = 'Az.KeyVault'
                    Version = [Version]'5.0.0'
                }
            }
            
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $vaultName -eq 'kvname' -and
                $secretName -eq 'secretname' -and
                $null -eq $secretVersion
            }
        }
        
        It 'should handle URI with trailing slash on secret name' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname/'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $vaultName -eq 'kvname' -and
                $secretName -eq 'secretname' -and
                $null -eq $secretVersion
            }
        }
        
        It 'should write verbose message about parsing Secret URI' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname'
            
            $verboseOutput = Get-KeyVaultSecretByUri -SecretUri $testUri -Verbose 4>&1
            
            $verboseOutput | Where-Object { $_ -match 'Parsing Secret URI for older version' } | Should -Not -BeNullOrEmpty
        }
        
        It 'should write verbose message with parsed arguments' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname'
            
            $verboseOutput = Get-KeyVaultSecretByUri -SecretUri $testUri -Verbose 4>&1
            
            $verboseOutput | Where-Object { $_ -match 'Args:.*vaultName.*secretName' } | Should -Not -BeNullOrEmpty
        }
        
        It 'should return a SecureString' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname'
            
            $result = Get-KeyVaultSecretByUri -SecretUri $testUri
            
            $result | Should -BeOfType [securestring]
        }
    }
    
    Context 'When using Az.KeyVault module version below 6.3.0 with secret version' {
        
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{
                    Name = 'Az.KeyVault'
                    Version = [Version]'6.2.9'
                }
            }
        }
        
        It 'should parse the URI and call Get-AzKeyVaultSecret with vaultName, secretName, and secretVersion' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname/abc123'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $vaultName -eq 'kvname' -and
                $secretName -eq 'secretname' -and
                $secretVersion -eq 'abc123'
            }
        }
        
        It 'should handle URI with trailing slash on version' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname/abc123/'
            
            Get-KeyVaultSecretByUri -SecretUri $testUri
            
            Should -Invoke Get-AzKeyVaultSecret -Exactly 1 -ParameterFilter {
                $vaultName -eq 'kvname' -and
                $secretName -eq 'secretname' -and
                $secretVersion -eq 'abc123'
            }
        }
        
        It 'should write verbose message about parsing Secret URI' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname/version123'
            
            $verboseOutput = Get-KeyVaultSecretByUri -SecretUri $testUri -Verbose 4>&1
            
            $verboseOutput | Where-Object { $_ -match 'Parsing Secret URI for older version' } | Should -Not -BeNullOrEmpty
        }
        
        It 'should write verbose message with parsed arguments including version' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname/version123'
            
            $verboseOutput = Get-KeyVaultSecretByUri -SecretUri $testUri -Verbose 4>&1
            
            $verboseOutput | Where-Object { $_ -match 'Args:.*secretVersion' } | Should -Not -BeNullOrEmpty
        }
        
        It 'should return a SecureString' {
            $testUri = 'https://kvname.vault.azure.net/secrets/secretname/version123'
            
            $result = Get-KeyVaultSecretByUri -SecretUri $testUri
            
            $result | Should -BeOfType [securestring]
        }
    }
    
    Context 'Error handling' {
        
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{
                    Name = 'Az.KeyVault'
                    Version = [Version]'6.3.0'
                }
            }
        }
        
        It 'should propagate Forbidden errors from Get-AzKeyVaultSecret' {
            Mock Get-AzKeyVaultSecret {
                throw "Operation returned an invalid status code 'Forbidden'"
            }
            
            $testUri = 'https://myvault.vault.azure.net/secrets/mysecret'
            
            { Get-KeyVaultSecretByUri -SecretUri $testUri -ErrorAction Stop } | 
                Should -Throw "*Forbidden*"
        }
        
        It 'should propagate NotFound errors from Get-AzKeyVaultSecret' {
            Mock Get-AzKeyVaultSecret {
                throw "Secret not found: mysecret"
            }
            
            $testUri = 'https://myvault.vault.azure.net/secrets/mysecret'
            
            { Get-KeyVaultSecretByUri -SecretUri $testUri -ErrorAction Stop } | 
                Should -Throw "*not found*"
        }
        
        It 'should propagate generic errors from Get-AzKeyVaultSecret' {
            Mock Get-AzKeyVaultSecret {
                throw "An unexpected error occurred"
            }
            
            $testUri = 'https://myvault.vault.azure.net/secrets/mysecret'
            
            { Get-KeyVaultSecretByUri -SecretUri $testUri -ErrorAction Stop } | 
                Should -Throw "*unexpected error*"
        }
    }
}
