---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ZeroFailed.Deploy.Azure
ms.date: 10/09/2026
PlatyPS schema version: 2024-05-01
title: Invoke-ArmDeployment
---

# Invoke-ArmDeployment

## SYNOPSIS

Runs a single ARM deployment, or its what-if, at the scope that the deployment entry specifies.

## SYNTAX

### __AllParameterSets

```
Invoke-ArmDeployment [-ArmDeployment] <hashtable> [-DeploymentConfig] <IDictionary> [-WhatIfMode]
 [-ContinueOnWhatIfError] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Runs one entry of the 'RequiredArmDeployments' configuration at resource group, subscription, management group or tenant scope.

A '.bicep' or '.json' template receives its parameters from the environment configuration, merged with any 'additionalParameters'.

A '.bicepparam' file is passed via '-TemplateParameterFile', and its 'using' statement names the template.
The environment configuration is not passed as template parameters, and 'additionalParameters' are not supported.

When the entry has a 'subscriptionId', the Az context of the current process is switched to that subscription before any other value is evaluated, and restored afterwards.

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-ArmDeployment -ArmDeployment @{ scope = 'subscription'; templatePath = './main.bicepparam'; location = 'uksouth'; subscriptionId = '<id>' } -DeploymentConfig @{}
```

Deploys a Bicep parameters file at subscription scope, to the specified subscription.

## PARAMETERS

### -ArmDeployment

The deployment entry.
Supported keys: 'templatePath', 'location', 'scope' ('resourceGroup' (the default), 'subscription', 'managementGroup' or 'tenant'), 'resourceGroupName', 'managementGroupId', 'subscriptionId', 'additionalParameters' and 'configKeysToIgnore'.

```yaml
Type: System.Collections.Hashtable
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

### -ContinueOnWhatIfError

When specified with 'WhatIfMode', an error from the what-if operation, including a template build or validation error, is reported as a warning instead of an error.

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

### -DeploymentConfig

The environment configuration, whose non-empty values become template parameters for a '.bicep' or '.json' template.

```yaml
Type: System.Collections.IDictionary
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

### -WhatIfMode

When specified, runs the ARM what-if operation instead of a deployment.
No resource group is created.

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

### Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment

The deployment result at resource group scope.

### Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment

The deployment result at subscription, management group or tenant scope.

The function returns $null for a what-if run or a skipped deployment.

### The deployment result

The deployment result at subscription, management group or tenant scope.

The function returns $null for a what-if run or a skipped deployment.

## NOTES

## RELATED LINKS

- [Bicep parameters files](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files)
- [ARM deployment what-if operation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-what-if)
