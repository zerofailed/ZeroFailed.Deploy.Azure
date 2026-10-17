---
document type: cmdlet
external help file: ZeroFailed.Deploy.Azure-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ZeroFailed.Deploy.Azure
ms.date: 10/17/2026
PlatyPS schema version: 2024-05-01
title: Publish-FlexConsumptionFunctionApp
---

# Publish-FlexConsumptionFunctionApp

## SYNOPSIS

Deploys a ZIP package to a Function App on the Flex Consumption plan, and waits for the deployment to finish.

## SYNTAX

### __AllParameterSets

```
Publish-FlexConsumptionFunctionApp [-ResourceGroupName] <string> [-Name] <string>
 [-ArchivePath] <string> [[-TimeoutSeconds] <int>] [-RemoteBuild] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

The function uploads the package to the OneDeploy endpoint (`/api/publish`) of the app's source control manager (SCM) site.
Then it checks the status of the deployment about once a second, until the deployment finishes.

The function reads the status from the response body, not from the HTTP status code.
The Flex Consumption plan returns HTTP 200 while a deployment runs, and also after a deployment fails.

The function retries requests that the SCM site blocks with HTTP 403, for up to 60 seconds.
Changes to the SCM site's access restrictions, such as a temporary rule for this machine, can take more than 30 seconds to apply.

The function fails in these cases:

- The deployment fails, is cancelled, conflicts with another deployment or only partly succeeds.
- The deployment does not finish within `-TimeoutSeconds`.
- The SCM site blocks the requests of the function for 60 seconds.

The error message contains the status text of the deployment and a link to its log.

## EXAMPLES

### EXAMPLE 1 - Deploy a package that is ready to run

```powershell
Publish-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app' -ArchivePath './app.zip'
```

Deploys a package that is ready to run, such as a .NET app.

### EXAMPLE 2 - Deploy a Python app with a remote build

```powershell
Publish-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-python-app' -ArchivePath './app.zip' -RemoteBuild -TimeoutSeconds 1200
```

Deploys a Python app, which the platform builds after the upload, and waits up to 20 minutes for the deployment to finish.

## PARAMETERS

### -ArchivePath

The path to the ZIP package to deploy.

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

### -Name

The name of the Function App.

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

### -RemoteBuild

When set, the platform builds the package after the upload, for example to install the packages of a Python app.
Do not set it for packages that are ready to run, such as .NET apps.

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

### -ResourceGroupName

The resource group of the Function App.

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

The maximum time, in seconds, to wait for the deployment to finish.
The default is 600.

```yaml
Type: System.Int32
DefaultValue: 600
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

This function requires the Az.Accounts module and an active Azure PowerShell connection.
It signs in to the SCM site with an Azure Resource Manager token for the current connection.
The deploying identity needs permission to deploy to the app (`Microsoft.Web/sites/publish/Action`), which the Website Contributor, Contributor and Owner roles include.

## RELATED LINKS

- [Test-FlexConsumptionFunctionApp](Test-FlexConsumptionFunctionApp.md)
- [Flex Consumption plan hosting](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
- [Deployment technologies in Azure Functions](https://learn.microsoft.com/azure/azure-functions/functions-deployment-technologies)
