---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed.Deploy.Azure
ms.date: 10/08/2025
PlatyPS schema version: 2024-05-01
title: Convert-UnicodeToEscapeHex
---

# Convert-UnicodeToEscapeHex

## SYNOPSIS

Converts Unicode characters in a JSON string to their escaped hexadecimal representation, useful when passing
unicode strings to REST APIs.

## SYNTAX

### __AllParameterSets

```
Convert-UnicodeToEscapeHex [-JsonString] <string> [-Compress] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

The `Convert-UnicodeToEscapeHex` function takes a JSON string as input, parses it into a PowerShell object,
and processes each property.  If a property value is a string, it converts any Unicode characters (with a
decimal value greater than 127) into their escaped hexadecimal representation (e.g., `\u00E9` for "é").

The modified JSON object is then converted back to a JSON string and returned.

## EXAMPLES

### EXAMPLE 1

```powershell
PS:> $json = '{"Name": "Café", "Description": "A place to enjoy coffee ☕"}'
PS:> Convert-UnicodeToEscapeHex -JsonString $json
{"Name":"Caf\u00e9","Description":"A place to enjoy coffee \u2615"}
```

This example demonstrates how the function converts Unicode characters in the input JSON string to their escaped hexadecimal form.

## PARAMETERS

### -Compress

A switch parameter that, when specified, compresses the output JSON string.
If not specified, the output will be pretty-printed.

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

### -JsonString

A JSON-formatted string to be processed.
This parameter is mandatory.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### String

The function accepts a JSON string as input.

## OUTPUTS

### System.String

The function returns a JSON string with Unicode characters converted to their escaped hexadecimal representation.

## NOTES

- This function uses `ConvertFrom-Json` and `ConvertTo-Json` cmdlets to parse and serialize JSON data.
- Unicode characters with decimal values less than or equal to 127 are not modified.
- The function processes only string values within the JSON object.

## RELATED LINKS

- []()
