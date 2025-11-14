---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.Azure
ms.date: 11/14/2025
PlatyPS schema version: 2024-05-01
title: Set-TemporaryAzureResourceNetworkAccess
---

# Set-TemporaryAzureResourceNetworkAccess

## SYNOPSIS

Manages the addition and removal of temporary network access rules for different Azure resource types.

## SYNTAX

### __AllParameterSets

```
Set-TemporaryAzureResourceNetworkAccess [-ResourceType] <string> [-ResourceGroupName] <string>
 [-ResourceName] <string> [-Revoke] [-Wait] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Each resource type implements its own handler for performing the addition and removal operations.

## EXAMPLES

## PARAMETERS

### -ResourceGroupName

The resource group of the resource to be managed.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
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

### -ResourceName

The name of the resource to be managed.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ResourceType

The type of Azure resource to be managed.

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

### -Revoke

When true, any existing temporary network access rules for the specified resource will be removed.
No
rules will be added.
When true, any existing temporary network access rules for the specified resource will be removed.
No
rules will be added.

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

### -Wait

When true, processing will wait for a time period implemented by the handler to allow the changes to take effect.

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

## RELATED LINKS

- []()
