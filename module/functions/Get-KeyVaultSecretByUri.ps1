# <copyright file="Get-KeyVaultSecretByUri.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Get-KeyVaultSecretByUri {
    <#
    .SYNOPSIS
    Enables querying a Key Vault Secret via its URI when using all versions of the Az.KeyVault module.

    .DESCRIPTION
    Support for query a Key Vault Secret via its URI was added in Az.KeyVault v6.3.0 with the addition of the `-Id`
    parameter to `Get-AzKeyVaultSecret`. In automation scenarios exerting direct control over the version of a single
    Az PowerShell module can cause assembly loading conflicts due to multiple versions of the Az.Accounts module
    being referenced.

    This function checks the available version of Az.KeyVault and performs the query in appropriate manner:

    - If using v6.3.0 or greater, using the `-Id` parameter
    - Otherwise, extracts the Key Vault Name, Secret Name and optionally Secret Version from the URI and uses the older parameter set

    .PARAMETER SecretUri
    The URI of the secret to be queried

    .EXAMPLE
    ```powershell
    Get-KeyVaultSecretByUri -SecretUri https://kvname.vault.azure.net/secrets/secretname
    ```

    Gets the latest version of a secret.

    .EXAMPLE
    ```powershell
    Get-KeyVaultSecretByUri -SecretUri https://kvname.vault.azure.net/secrets/secretname/version
    ```

    Gets a specific version of a secret.
    #>
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