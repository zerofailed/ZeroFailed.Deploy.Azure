ZeroFailed.Deploy.Azure - Reference Sheet

<!-- START_GENERATED_HELP -->

## Application Deployments

This group contains functionality for deploying applications to Azure App Service and integrates with the environment-specific configuration management features. It also deploys Function Apps, including Function Apps on the Flex Consumption plan.

### Properties

| Name                                       | Default Value | ENV Override                                            | Description                                                                                                                  |
| ------------------------------------------ | ------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `AppServiceAppsToDeploy`                   | @()           |                                                         | Deploys the specified ZIP packages to Azure App Service. See [note below](#appserviceappstodeploy) for configuration syntax. |
| `SkipAppServiceAppDeployment`              | $false        | `ZF_DEPLOY_SKIP_APP_SERVICE_DEPLOYMENT`                 | When true, any configured App Service deployments will be skipped.                                                           |
| `AppServiceRequiresTemporaryNetworkAccess` | $false        | `ZF_DEPLOY_APP_SERVICE_TEMP_NETWORK_ACCESS`             | When true, a temporary AppService firewall rule will be created to give the deployment process access to the App Service.    |
| `AppServiceFlexDeploymentTimeoutSeconds`   | 600           | `ZF_DEPLOY_APP_SERVICE_FLEX_DEPLOYMENT_TIMEOUT_SECONDS` | The maximum time, in seconds, to wait for a deployment to a Function App on the Flex Consumption plan to finish.             |

#### AppServiceAppsToDeploy

This property is configured using the following structure:

```powershell
$AppServiceAppsToDeploy = @(
    @{
        appServiceName = { $deploymentConfig.frontEndAppServiceName }   # Using the scriptblock syntax enables lazy-evaluation
        resourceGroupName = { $deploymentConfig.resourceGroupName }
        zipPackagePath = $frontEndZipPackagePath                        # This variable is evaluated on initialisation (for example, a parameter on the entrypoint script)
    }
    @{
        appServiceName = { $deploymentConfig.functionAppName }
        resourceGroupName = { $deploymentConfig.resourceGroupName }
        zipPackagePath = $functionAppZipPackagePath
        remoteBuild = $false                                            # Optional. See the Flex Consumption plan section below.
    }
)
```

***NOTE**: The ZIP package should be a valid deployment package for Azure App Service.*

#### Function Apps on the Flex Consumption plan

The `deployAppServiceZipPackages` task checks the plan of each app before it deploys the app. For a Function App on the [Flex Consumption plan](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan), the task uses `Publish-FlexConsumptionFunctionApp` instead of `Publish-AzWebApp`. Existing configuration works without changes.

`Publish-AzWebApp` cannot report the result of a Flex Consumption deployment. It can report success before the deployment finishes, and it does not detect a failed deployment.

[`Publish-FlexConsumptionFunctionApp`](docs/functions/Publish-FlexConsumptionFunctionApp.md) uploads the package to the OneDeploy endpoint (`/api/publish`) of the app. Then it checks the status of the deployment about once a second. The task fails in these cases:

- The deployment fails, is cancelled, conflicts with another deployment or only partly succeeds.
- The deployment does not finish within `AppServiceFlexDeploymentTimeoutSeconds`. The default is 600 seconds.

The error message contains the status text of the deployment and a link to its log.

If the platform must build the package after the upload, set `remoteBuild = $true`. For example, a Python app needs a remote build to install its packages. Do not set `remoteBuild` for packages that are ready to run, such as .NET apps. For apps on other plans, the task ignores `remoteBuild` and writes a warning.

`AppServiceRequiresTemporaryNetworkAccess` works for Flex Consumption apps in the same way as for other apps.

To provision a Flex Consumption app, use `deployArmTemplates` as usual. The plan and the app are ordinary Bicep or ARM resources, so provisioning needs no extra configuration.

### Tasks

| Name                          | Description                                                                                                      |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `deployAppServiceZipPackages` | Deploy ZIP packages to Azure App Service and Function Apps, including Function Apps on the Flex Consumption plan |

## ARM Deployments

This group contains features for managing Azure Resource Manager deployments (using Bicep or JSON templates) and integrates with the environment-specific configuration management features.

### Properties

| Name                      | Default Value | ENV Override                          | Description                                                                                                                                                                                         |
| ------------------------- | ------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ForceBicepVersionCheck`  |               | `ZF_DEPLOY_FORCE_BICEP_VERSION_CHECK` | When true, the available Bicep CLI version will be checked, even if the ARM deployment does not reference a Bicep template.                                                                         |
| `MinimumBicepVersion`     |               | `ZF_DEPLOY_MINIMUM_BICEP_VERSION`     | Specifies the minimum version of the Bicep CLI that should be available. If not found, the latest version will be installed.                                                                        |
| `RequiredArmDeployments`  | @()           |                                       | Details the ARM deployments that need to be run for the deployment process. See [note below](#requiredarmdeployments) for configuration syntax.                                                     |
| `RequiredBicepVersion`    |               | `ZF_DEPLOY_REQUIRED_BICEP_VERSION`    | Ensures a specific version of the Bicep CLI is available. If not found, the required version will be installed.                                                                        |
| `SkipArmDeployments`      | $false        | `ZF_DEPLOY_SKIP_ARM_DEPLOYMENTS`      | When true, skips any configured ARM deployments.                                                                                                                                                    |
| `SkipEnsureBicepVersion`  | $false        | `ZF_DEPLOY_SKIP_ENSURE_BICEP_VERSION` | When true, the available Bicep CLI version will not be validated, or installed if missing.                                                                                                                     |
| `ZF_ArmDeploymentOutputs` | @{}           | `ZF_DEPLOY_ARM_DEPLOYMENT_OUTPUTS`    | A script-scoped variable containing the outputs from any ARM deployments that will be available to the rest of the deployment process. Available for overriding as part of niche testing scenarios. |

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

### Tasks

| Name                 | Description                                                                                                                  |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `deployArmTemplates` | Runs the specified ARM deployments.                                                                                          |
| `ensureBicepVersion` | Checks that a suitable version of Bicep CLI is available, installing it via Azure CLI when missing or the incorrect version. |

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
