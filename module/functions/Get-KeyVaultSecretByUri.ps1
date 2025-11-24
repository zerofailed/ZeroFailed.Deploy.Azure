# <copyright file="Get-KeyVaultSecretByUri.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Get-KeyVaultSecretByUri {
    [CmdletBinding()]
    [OutputType([securestring])]
    param (
        [Parameter(Mandatory)]
        [uri] $SecretUri
    )

    # Lookup the KV secret based on the available version of the module
    Import-Module Az.KeyVault
    if ((Get-Module Az.KeyVault | Select-Object -ExpandProperty Version) -ge [Version]'6.3.0') {
        $secretValue = Get-AzKeyVaultSecret -Id $SecretUri
    }
    else {
        Write-Verbose 'Parsing Secret URI for older version of Az.KeyVault module...'
        $secretUri = [uri]$SecretUri
        $splat = @{
            vaultName = $secretUri.Host.Split('.') | Select-Object -First 1
            secretName = $secretUri.Segments[2].TrimEnd('/')
        }
        if ($secretUri.Segments.Count -gt 3) {
            $splat += @{
                secretVersion = $secretUri.Segments[3].TrimEnd('/')
            }
        }
        Write-Verbose "Args: $($splat | ConvertTo-Json -compress)"
        $secretValue = Get-AzKeyVaultSecret @splat
    }

    return $secretValue
}