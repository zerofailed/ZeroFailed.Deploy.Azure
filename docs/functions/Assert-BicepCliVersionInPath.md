---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.Azure
ms.date: 11/17/2025
PlatyPS schema version: 2024-05-01
title: Assert-BicepCliVersionInPath
---

# Assert-BicepCliVersionInPath

## SYNOPSIS

Checks that the specified version of the Bicep CLI is available via the PATH.

## SYNTAX

### requiredVersion (Default)

```
Assert-BicepCliVersionInPath [-RequiredBicepVersion <string>] [<CommonParameters>]
```

### minimumVersion

```
Assert-BicepCliVersionInPath -MinimumBicepVersion <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Checks that the specified version of the Bicep CLI is available via the PATH (as required when using Az.PowerShell to deploy Bicep templates).

When not found also checks whether a suitable version if available via Azure CLI.  If so, the PATH is updated to make it available; otherwise a suitable version is installed via the Azure CLI.

## EXAMPLES

### Example 1 - Ensure any version is available

Assert-BicepCliVersionInPath

### Example 2 - Ensure the latest version is available

Assert-BicepCliVersionInPath -RequiredBicepVersion 'latest'

### Example 3 - Ensure a minimum version is available

Assert-BicepCliVersionInPath -MinimumBicepVersion '0.38.33'

## PARAMETERS

### -AllowInstallOrUpgrade

When true, a suitable version of Bicep CLI will be installed via Azure CLI when not already available.

```yaml
Type: System.Boolean
DefaultValue: $true
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

### -MinimumBicepVersion

Specifies that a minimum version of the Bicep CLI is available, if not, then the latest version is installed via Azure CLI.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: minimumVersion
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RequiredBicepVersion

Specifies that a particular version of the Bicep CLI is available, if not, then that version is installed via Azure CLI.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: requiredVersion
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

This function requires the Azure CLI to be available.

## RELATED LINKS

- []()
