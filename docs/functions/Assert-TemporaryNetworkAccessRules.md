---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.Azure
ms.date: 11/14/2025
PlatyPS schema version: 2024-05-01
title: Assert-TemporaryNetworkAccessRules
---

# Assert-TemporaryNetworkAccessRules

## SYNOPSIS

Manages temporary firewall access rules for Azure resources.

## SYNTAX

### __AllParameterSets

```
Assert-TemporaryNetworkAccessRules [-RequiredResources] <hashtable[]> [-Revoke] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function wraps functionality provided by the [Corvus.Deployment](https://github.com/corvus-dotnet/Corvus.Deployment/) module to allow processes to define
a set of Azure resources that require temporary firewall rules to allow the public IP address associated with the current process to access them.

Supported resource types:

| ResourceType     | Description                                         |
| ---------------- | --------------------------------------------------- |
| `KeyVault`       | Key Vaults                                          |
| `StorageAccount` | Storage Accounts                                    |
| `SQLServer`      | Azure SQL Database instances                        |
| `WebApp`         | App Service main web site                           |
| `WebAppScm`      | App Service SCM web site (e.g. for kudu operations) |

## EXAMPLES

### EXAMPLE 1 - Add temporary network access to a storage account and key vault

```powershell
$resources = @(
    @{
        ResourceType = 'StorageAccount'
        ResourceGroupName = 'my-resource-group'
        Name = 'mystorageaccount'
    },
    @{
        ResourceType = 'KeyVault'
        ResourceGroupName = 'my-resource-group'
        Name = 'my-key-vault'
    }
)
Assert-TemporaryNetworkAccessRules -RequiredResources $resources
```

### EXAMPLE 2 - Revoke temporary network access rules previously created

```powershell
Assert-TemporaryNetworkAccessRules -RequiredResources $resources -Revoke
```

## PARAMETERS

### -RequiredResources

An array of hashtables, each specifying an Azure resource that requires temporary network access.
Each hashtable must contain:
- ResourceType: A supported Azure resource (e.g., 'Storage', 'KeyVault')
- ResourceGroupName: The name of the resource group containing the resource
- Name: The name of the resource

```yaml
Type: System.Collections.Hashtable[]
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

### -Revoke

If specified, removes the temporary network access rules instead of creating them.
When omitted, the function adds temporary access rules.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
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

### System.Void

This function has no outputs.

## NOTES

This function requires the Azure PowerShell & [Corvus.Deployment](https://www.powershellgallery.com/packages/Corvus.Deployment) modules to be installed and an active connection
to an Azure subscription.

## RELATED LINKS

- []()
