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

| Name                      | Default Value | ENV Override                       | Description                                                                                                                                                                                         |
| ------------------------- | ------------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RequiredArmDeployments`  | @()           |                                    | Details the ARM deployments that need to be run for the deployment process. See [note below](#requiredarmdeployments) for configuration syntax.                                                     |
| `SkipArmDeployments`      | $false        | `ZF_DEPLOY_SKIP_ARM_DEPLOYMENTS`   | When true, skips any configured ARM deployments.                                                                                                                                                    |
| `ZF_ArmDeploymentOutputs` | @{}           | `ZF_DEPLOY_ARM_DEPLOYMENT_OUTPUTS` | A script-scoped variable containing the outputs from any ARM deployments that will be available to the rest of the deployment process. Available for overriding as part of niche testing scenarios. |

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

| Name                 | Description                         |
| -------------------- | ----------------------------------- |
| `deployArmTemplates` | Runs the specified ARM deployments. |

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


### Tasks

| Name                           | Description                                                                                      |
| ------------------------------ | ------------------------------------------------------------------------------------------------ |
| `connectAzure`                 | Configures up the Azure PowerShell and/or Azure CLI connection context for the deployment        |
| `enableTemporaryNetworkAccess` | Apply temporary network access rules to the configured Azure resources.                          |
| `getDeploymentIdentity`        | Derive the current user's ObjectId (aka PrincipalId) using the current Azure PowerShell context. |
| `removeTemporaryNetworkAccess` | Remove temporary network access rules from the configured Azure resources. Uses the 'OnExitActions' extensibility point provided by [ZeroFailed.DevOps.Common](https://github.com/zerofailed/ZeroFailed.DevOps.Common/blob/main/HELP.md#properties-1) to ensure temporary rules are removed even in the event of errors. |


<!-- END_GENERATED_HELP -->
