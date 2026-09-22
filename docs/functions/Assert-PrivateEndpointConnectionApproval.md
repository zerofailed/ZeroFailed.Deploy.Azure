---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.Azure
ms.date: 09/22/2026
PlatyPS schema version: 2024-05-01
title: Assert-PrivateEndpointConnectionApproval
---

# Assert-PrivateEndpointConnectionApproval

## SYNOPSIS

Ensures that a private endpoint connection to an Azure resource is approved.

## SYNTAX

### __AllParameterSets

```
Assert-PrivateEndpointConnectionApproval [-PrivateLinkResourceId] <string>
 [-PrivateEndpointNameLike] <string> [[-Description] <string>] [[-TimeoutSeconds] <int>]
 [[-PollIntervalSeconds] <int>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

When a service such as Microsoft Fabric, Azure Synapse or Azure Data Factory creates a managed private endpoint
to an Azure resource, it sends a private endpoint connection request to that resource. The connection cannot
be used until the owner of the resource approves it. This function finds the connection on the target resource
and approves it, so that the approval can be automated as part of a deployment process.

The connection is identified by the name of its private endpoint, matched against the `-PrivateEndpointNameLike`
wildcard pattern. Services name the private endpoint after the managed private endpoint, typically with a prefix
identifying the requesting workspace, so a pattern such as `*.my-endpoint-name` is usually sufficient.

The connection only appears on the target resource once the requesting service has finished provisioning its
private endpoint, so the function polls for it until `-TimeoutSeconds` has elapsed. It then acts on the
connection's status:

| Status                     | Action                                                                                      |
| -------------------------- | ------------------------------------------------------------------------------------------- |
| `Pending`                  | Approves the connection, then waits for the approval to take effect (`Action = 'Approved'`) |
| `Approved`                 | Nothing to do (`Action = 'Skipped'`)                                                        |
| `Rejected`, `Disconnected` | Writes a warning and leaves the connection alone (`Action = 'None'`)                        |
| Not found before timeout   | Writes a warning (`Status = 'NotFound'`, `Action = 'None'`)                                 |

Rejected connections are never approved automatically, as rejecting a connection is a decision made by the owner
of the resource. If more than one connection matches the pattern, the function throws rather than guessing.

Errors raised when listing or approving connections, such as the deploying identity lacking permission to approve
connections on the resource, are not caught, so that the caller can decide how to handle them.

## EXAMPLES

### EXAMPLE 1 - Approve a Fabric workspace's managed private endpoint to a Key Vault

```powershell
Assert-PrivateEndpointConnectionApproval `
    -PrivateLinkResourceId '/subscriptions/{id}/resourceGroups/rg-sales-dev/providers/Microsoft.KeyVault/vaults/kv-sales-dev' `
    -PrivateEndpointNameLike '*kv-sales-dev.vault'
```

### EXAMPLE 2 - Approve a Synapse workspace's managed private endpoint to a storage account, with a custom message

```powershell
Assert-PrivateEndpointConnectionApproval `
    -PrivateLinkResourceId '/subscriptions/{id}/resourceGroups/rg-data/providers/Microsoft.Storage/storageAccounts/stdatalake' `
    -PrivateEndpointNameLike '*mysynapse.datalake-dfs' `
    -Description 'Approved by the data platform deployment'
```

### EXAMPLE 3 - Check what would be approved, without approving anything

```powershell
Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $resourceId -PrivateEndpointNameLike '*kv-sales-dev.vault' -WhatIf
```

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
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

### -Description

The message recorded against the connection when it is approved.

```yaml
Type: System.String
DefaultValue: Approved by the ZeroFailed deployment process
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PollIntervalSeconds

How long to wait between checks, both for the connection to appear and for the approval to take effect.
Between 1 and 300.

```yaml
Type: System.Int32
DefaultValue: 15
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PrivateEndpointNameLike

A wildcard pattern matched against the name of each connection's private endpoint, identifying the connection
to approve.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: true
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PrivateLinkResourceId

The Azure resource ID of the resource that is the target of the private endpoint connection, for example a Key
Vault or storage account.

```yaml
Type: System.String
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

### -TimeoutSeconds

How long to wait, both for the connection to appear on the resource and for the approval to take effect.
Between 0 and 3600; 0 checks once without waiting.

```yaml
Type: System.Int32
DefaultValue: 300
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
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

### System.Collections.Hashtable

A report describing the outcome, with the keys `PrivateLinkResourceId`, `PrivateEndpointName`, `ConnectionName`,
`ConnectionId`, `PreviousStatus`, `Status` and `Action` (`Approved`, `Skipped`, `WhatIf` or `None`).

## NOTES

This function requires the Az.Network module and an active Azure PowerShell connection. The deploying identity
needs permission to approve private endpoint connections on the target resource
(`Microsoft.<provider>/<resourceType>/privateEndpointConnectionsApproval/action`), which is included in the
Owner and Contributor roles.

Connections are managed with the Az.Network `Get-AzPrivateEndpointConnection` and
`Approve-AzPrivateEndpointConnection` cmdlets, so only the resource types those cmdlets support can be used.
These include Key Vault, Storage, Azure SQL, Cosmos DB, Event Hubs, AI Search and Synapse, but not Azure Data
Explorer.

## RELATED LINKS

- [Manage Azure private endpoints](https://learn.microsoft.com/en-us/azure/private-link/manage-private-endpoint)
