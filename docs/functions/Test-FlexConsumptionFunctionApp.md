---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ZeroFailed.Deploy.Azure
ms.date: 10/17/2026
PlatyPS schema version: 2024-05-01
title: Test-FlexConsumptionFunctionApp
---

# Test-FlexConsumptionFunctionApp

## SYNOPSIS

Checks whether a Function App runs on the Flex Consumption plan.

## SYNTAX

### __AllParameterSets

```
Test-FlexConsumptionFunctionApp [-ResourceGroupName] <string> [-Name] <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

The function reads the `properties.sku` value of the app's site resource from Azure Resource Manager.
It returns `$true` when the value is `FlexConsumption`, which is the check that the Azure CLI uses.
For apps on other plans, and for App Service apps, it returns `$false`.

## EXAMPLES

### EXAMPLE 1 - Check the plan of a Function App

```powershell
Test-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app'
```

Returns `$true` if `my-func-app` is a Function App on the Flex Consumption plan.

## PARAMETERS

### -Name

The name of the app.

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

### -ResourceGroupName

The resource group of the app.

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

## OUTPUTS

### System.Boolean

`$true` if the app is a Function App on the Flex Consumption plan, otherwise `$false`.

## NOTES

This function requires the Az.Accounts module and an active Azure PowerShell connection.
The identity needs permission to read the app's site resource, which the Reader role includes.

## RELATED LINKS

- [Publish-FlexConsumptionFunctionApp](Publish-FlexConsumptionFunctionApp.md)
- [Flex Consumption plan hosting](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
