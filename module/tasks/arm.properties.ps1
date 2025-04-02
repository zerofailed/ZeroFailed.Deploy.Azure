# <copyright file="arm.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, skips any configured ARM deployments. Defaults to false.
$SkipArmDeployments = property ZF_DEPLOY_SKIP_ARM_DEPLOYMENTS $false

# Synopsis: Details the ARM deployments that need to be run for the deployment process. **TODO: CONFIG docs**
$RequiredArmDeployments = property ZF_DEPLOY_REQUIRED_ARM_DEPLOYMENTS @()

# Synopsis: A script-scoped variable containing the outputs from any ARM deployments that will be available to the rest of the deployment process. Available for overriding as part of niche testing scenarios.
$script:ZF_ArmDeploymentOutputs = property ZF_DEPLOY_ARM_DEPLOYMENT_OUTPUTS @()
