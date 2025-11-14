---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.Azure
ms.date: 11/14/2025
PlatyPS schema version: 2024-05-01
title: Get-KeyVaultSecretByUri
---

# Get-KeyVaultSecretByUri

## SYNOPSIS

Enables querying a Key Vault Secret via its URI when using all versions of the Az.KeyVault module.

## SYNTAX

### __AllParameterSets

```
Get-KeyVaultSecretByUri [-SecretUri] <uri> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Support for query a Key Vault Secret via its URI was added in Az.KeyVault v6.3.0 with the addition of the `-Id` parameter to `Get-AzKeyVaultSecret`. In automation scenarios exerting direct control over the version of a single
Az PowerShell module can cause assembly loading conflicts due to multiple versions of the Az.Accounts module
being referenced.

This function checks the available version of Az.KeyVault and performs the query in appropriate manner:

- If using v6.3.0 or greater, using the `-Id` parameter
- Otherwise, extracts the Key Vault Name, Secret Name and optionally Secret Version from the URI and uses the older parameter set

## EXAMPLES

### Example 1 - Latest version of a secret

Get-KeyVaultSecretByUri -SecretUri https://kvname.vault.azure.net/secrets/secretname

### Example 2 - Specific version of a secret

Get-KeyVaultSecretByUri -SecretUri https://kvname.vault.azure.net/secrets/secretname/version

## PARAMETERS

### -SecretUri

The URI of the secret to be queried

```yaml
Type: System.Uri
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Security.SecureString

Returns the Key Vault Secret as a secure string.

## NOTES

## RELATED LINKS

- [Az.PowerShell Release v13.0.0](https://github.com/Azure/azure-powershell/releases/tag/v13.0.0-November2024)
- [Az.KeyVault Feature](https://github.com/Azure/azure-powershell/issues/23053)
