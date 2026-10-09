ZeroFailed.Deploy.Azure - Reference Sheet

<!-- START_GENERATED_HELP -->

## Application Deployments

This group contains functionality for deploying applications to Azure App Service and integrates with the environment-specific configuration management features.

### Properties

| Name                                       | Default Value | ENV Override                                | Description                                                                                                                  |
| ------------------------------------------ | ------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `AppServiceAppsToDeploy`                   | @()           |                                             | Deploys the specified ZIP packages to Azure App Service. See [note below](#appserviceappstodeploy) for configuration syntax. |
| `SkipAppServiceAppDeployment`              | $false        | `ZF_DEPLOY_SKIP_APP_SERVICE_DEPLOYMENT`     | When true, any configured App Service deployments will be skipped.                                                           |
| `AppServiceRequiresTemporaryNetworkAccess` | $false        | `ZF_DEPLOY_APP_SERVICE_TEMP_NETWORK_ACCESS` | When true, a temporary AppService firewall rule will be created to give the deployment process access to the App Service.    |

#### AppServiceAppsToDeploy

This property is configured using the following structure:

```powershell
$AppServiceAppsToDeploy = @(
    @{
        appServiceName = { $deploymentConfig.frontEndAppServiceName }   # Using the scripblock syntax enables lazy-evaluation
        resourceGroupName = { $deploymentConfig.resourceGroupName }
        zipPackagePath = $frontEndZipPackagePath                        # This variable will be evaluation on initialisation (e.g. a parameter on the entrypoint script)
    }
    @{
        appServiceName = { $deploymentConfig.backEndAppServiceName }
        resourceGroupName = { $deploymentConfig.resourceGroupName }
        zipPackagePath = $backEndZipPackagePath
    }
)
```

***NOTE**: The ZIP package should be a valid deployment package for Azure App Service.*

### Tasks

| Name                          | Description                           |
| ----------------------------- | ------------------------------------- |
| `deployAppServiceZipPackages` | Deploy Azure App Service ZIP packages |

## ARM Deployments

This group contains features for managing Azure Resource Manager deployments (using Bicep or JSON templates) and integrates with the environment-specific configuration management features.

### Properties

| Name                      | Default Value | ENV Override                          | Description                                                                                                                                                                                         |
| ------------------------- | ------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ArmWhatIfMode`           | $false        | `ZF_DEPLOY_ARM_WHATIF_MODE`           | When true, ARM deployments are run in 'what-if' mode, which reports the changes that would be made without deploying anything. Applies to all configured ARM deployments. See [note below](#armwhatifmode). |
| `ArmWhatIfContinueOnError` | $false       | `ZF_DEPLOY_ARM_WHATIF_CONTINUE_ON_ERROR` | When true, and `ArmWhatIfMode` is true, a failed what-if operation is reported as a warning and the remaining deployments continue. Configuration errors still fail the build. |
| `ForceBicepVersionCheck`  |               | `ZF_DEPLOY_FORCE_BICEP_VERSION_CHECK` | When true, the available Bicep CLI version will be checked, even if the ARM deployment does not reference a Bicep template.                                                                         |
| `MinimumBicepVersion`     |               | `ZF_DEPLOY_MINIMUM_BICEP_VERSION`     | Specifies the minimum version of the Bicep CLI that should be available. If not found, the latest version will be installed.                                                                        |
| `RequiredArmDeployments`  | @()           |                                       | Details the ARM deployments that need to be run for the deployment process. See [note below](#requiredarmdeployments) for configuration syntax.                                                     |
| `RequiredBicepVersion`    |               | `ZF_DEPLOY_REQUIRED_BICEP_VERSION`    | Ensures a specific version of the Bicep CLI is available. If not found, the required version will be installed. The latest release is only looked up (via the GitHub API) for `latest`, a minimum version, or a missing installation, so a pinned version that is already installed needs no network access. |
| `SkipArmDeployments`      | $false        | `ZF_DEPLOY_SKIP_ARM_DEPLOYMENTS`      | When true, skips any configured ARM deployments.                                                                                                                                                    |
| `SkipEnsureBicepVersion`  | $false        | `ZF_DEPLOY_SKIP_ENSURE_BICEP_VERSION` | When true, the available Bicep CLI version will not be validated, or installed if missing.                                                                                                                     |
| `ZF_ArmDeploymentOutputs` | @{}           | `ZF_DEPLOY_ARM_DEPLOYMENT_OUTPUTS`    | A script-scoped variable containing the outputs from any ARM deployments that will be available to the rest of the deployment process. Available for overriding as part of niche testing scenarios. |

#### ArmWhatIfMode

Set this property in your build configuration to make what-if the default for all ARM deployments, or override it at runtime via the `ZF_DEPLOY_ARM_WHATIF_MODE` environment variable (e.g. `ZF_DEPLOY_ARM_WHATIF_MODE=true`) or a build parameter.

When enabled:
- Each deployment is run with `-WhatIf`, so the predicted changes are written to the build log and nothing is deployed.
- Resource groups are not created. If a resource group does not exist, a warning is shown and what-if is skipped for that deployment.
- ARM deployment outputs are not produced, so `ZF_ArmDeploymentOutputs` is not populated. Later tasks that depend on those outputs may fail or need to be skipped.
- A failed what-if operation fails the build, unless `ArmWhatIfContinueOnError` is true.
- Only the ARM deployments run in what-if mode. Other tasks still make real changes. For example, `enableTemporaryNetworkAccess` still adds its firewall rules when `EnableTemporaryNetworkAccess` is true, so set that property to false for a what-if run that must change nothing.

#### RequiredArmDeployments

This property is configured using the following structure:

```powershell
$RequiredArmDeployments = @(
    @{
        templatePath = 'my-template.bicep'
        resourceGroupName = { $deploymentConfig.resourceGroupName }     # Using the scripblock syntax enables lazy-evaluation
        location = 'uksouth'
        # This extension uses a convention whereby configuration settings are assumed to match ARM deployment parameters.
        # This value overrides this behaviour by removing any config settings not required for ARM deployment, or that
        # have an empty value so the template parameter's default value can be used.
        configKeysToIgnore = @(
            "RequiredConfiguration"
            "azureLocation"
            "azureSubscriptionId"
            "azureTenantId"
            "resourceGroupName"
        )
        additionalParameters = @{
            someParameter = 'foo'               # a static value
            anotherParameter = { Get-Date }     # a dynamic value that will be evaluated at runtime
        }
    }
)
```

The optional `scope` setting controls the ARM deployment scope. When omitted it defaults to `resourceGroup`. Supported values (case-insensitive) and the settings each requires are:

| `scope`           | Required settings                                | Deployment cmdlet                                            |
| ----------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `resourceGroup`   | `templatePath`, `resourceGroupName`, `location`  | `New-AzResourceGroupDeployment` (creates the resource group if it does not exist) |
| `subscription`    | `templatePath`, `location`                       | `New-AzSubscriptionDeployment` (targets the current Azure context's subscription, or `subscriptionId`) |
| `managementGroup` | `templatePath`, `location`, `managementGroupId`  | `New-AzManagementGroupDeployment`                            |
| `tenant`          | `templatePath`, `location`                       | `New-AzTenantDeployment`                                     |

For all scopes other than `resourceGroup`, `location` is where the deployment metadata is stored. At `resourceGroup` scope, `location` is used only when the resource group is created. The `scope`, `managementGroupId` and `subscriptionId` settings support the scriptblock syntax for lazy-evaluation.

The optional `subscriptionId` setting, at `resourceGroup` and `subscription` scope, runs that deployment in the specified subscription. The Azure context is switched before anything else for that deployment, and the previous context is restored afterwards, also when the deployment fails. Without it, the deployment uses the current Azure context.

A `templatePath` that ends `.bicepparam` is a [Bicep parameters file](https://learn.microsoft.com/azure/azure-resource-manager/bicep/parameter-files). It is passed via `-TemplateParameterFile`, and its `using` statement names the template. The environment configuration settings are not passed as template parameters, and `additionalParameters` are not supported: set the values in the `.bicepparam` file instead. This requires Azure PowerShell 10.4.0 or later and Bicep CLI 0.22 or later.

For example:

```powershell
$RequiredArmDeployments = @(
    @{
        scope = 'subscription'
        templatePath = 'my-subscription-template.bicep'     # must declare: targetScope = 'subscription'
        location = 'uksouth'
    }
    @{
        scope = 'managementGroup'
        templatePath = 'my-mg-template.bicep'               # must declare: targetScope = 'managementGroup'
        managementGroupId = { $deploymentConfig.managementGroupId }
        location = 'uksouth'
    }
    @{
        scope = 'subscription'
        templatePath = 'main.dev.bicepparam'                # 'using' names the template
        subscriptionId = { $deploymentConfig.devSubscriptionId }
        location = 'uksouth'
    }
)
```

### Tasks

| Name                 | Description                                                                                                                  |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `deployArmTemplates` | Runs the specified ARM deployments.                                                                                          |
| `ensureBicepVersion` | Checks that a suitable version of Bicep CLI is available, installing it via Azure CLI when missing or the incorrect version. Runs when a deployment uses a `.bicep` or `.bicepparam` file. |

## Monitoring

This group contains functionality for monitoring-related deployment tasks.

### Properties

| Name                                     | Default Value | ENV Override                                            | Description                                                        |
| ---------------------------------------- | ------------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| `SkipCreateAppInsightsReleaseAnnotation` | $false        | `ZF_DEPLOY_SKIP_CREATE_APP_INSIGHTS_RELEASE_ANNOTATION` | When true, an App Insights release annotation will not be created. |

### Tasks

| Name                                 | Description                               |
| ------------------------------------ | ----------------------------------------- |
| `createAppInsightsReleaseAnnotation` | Create an App Insights release annotation |

## Security

This group contains features for security-related deployment tasks.

### Properties

| Name                                      | Default Value | ENV Override                                | Description                                                                                                                                                                                                                                          |
| ----------------------------------------- | ------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnableTemporaryNetworkAccess`            | $false        | `ZF_DEPLOY_ENABLE_TEMPORARY_NETWORK_ACCESS` | When true, enables the functionality for applying temporary network access rules for Azure resources.                                                                                                                                                |
| `SkipConnectAzure`                        | $false        | `ZF_DEPLOY_SKIP_CONNECTAZURE`               | When true, configuring the Azure connection context will be skipped.                                                                                                                                                                                 |
| `SkipConnectAzureCli`                     | $true         | `ZF_DEPLOY_SKIP_CONNECTAZURE_CLI`           | When set to true, configuring the Azure CLI connection context will be skipped.                                                                                                                                                                      |
| `SkipConnectAzurePowerShell`              | $false        | `ZF_DEPLOY_SKIP_CONNECTAZURE_PS`            | When set to true, configuring the Azure PowerShell connection context will be skipped.                                                                                                                                                               |
| `SkipGetDeploymentIdentity`               | $true         | `ZF_DEPLOY_SKIP_GET_DEPLOYMENT_IDENTITY`    | When true, skips the lookup for the PrincipalId of the current Azure PowerShell identity context.                                                                                                                                                    |
| `TemporaryNetworkAccessRequiredResources` | @()           |                                             | Defines the resources that require temporary network access rules. This is a list of Azure resources that require temporary network access rules to be applied. See [note below](#temporarynetworkaccessrequiredresources) for configuration syntax. |

#### TemporaryNetworkAccessRequiredResources

This property is configured using the following structure:

```powershell
$TemporaryNetworkAccessRequiredResources = @(
    @{
        ResourceType = '<resource-type>'                                # See below for support resource types
        ResourceGroupName = { $deploymentConfig.resourceGroupName }     # Using the scriptblock syntax enables lazy-evaluation
        Name = { $deploymentConfig.keyVaultName }
    }
)
```

Supported resource types are:
- AiSearch
- KeyVault
- SqlServer
- StorageAccount
- WebApp
- WebAppScm

***NOTE**: More information about developing additional handlers is available [here](./module/_azureResourceNetworkAccessHandlers/README.md).*


### Tasks

| Name                           | Description                                                                                      |
| ------------------------------ | ------------------------------------------------------------------------------------------------ |
| `connectAzure`                 | Configures up the Azure PowerShell and/or Azure CLI connection context for the deployment        |
| `enableTemporaryNetworkAccess` | Apply temporary network access rules to the configured Azure resources.                          |
| `getDeploymentIdentity`        | Derive the current user's ObjectId (aka PrincipalId) using the current Azure PowerShell context. |
| `removeTemporaryNetworkAccess` | Remove temporary network access rules from the configured Azure resources. Uses the 'OnExitActions' extensibility point provided by [ZeroFailed.DevOps.Common](https://github.com/zerofailed/ZeroFailed.DevOps.Common/blob/main/HELP.md#properties-1) to ensure temporary rules are removed even in the event of errors. |


<!-- END_GENERATED_HELP -->
