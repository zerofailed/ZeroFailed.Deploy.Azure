# <copyright file="Invoke-ArmDeployment.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeDiscovery {
    # Needed at discovery time to build the '-ForEach' test cases
    $discoveryCmdlets = @{
        resourceGroup   = 'New-AzResourceGroupDeployment'
        subscription    = 'New-AzSubscriptionDeployment'
        managementGroup = 'New-AzManagementGroupDeployment'
        tenant          = 'New-AzTenantDeployment'
    }
}

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # Stubs for the external commands, so they can be mocked without Az.Resources or ZeroFailed.
    # Their parameters mirror the real cmdlets, so an unsupported parameter (e.g. 'Location' at
    # resource group scope) fails here as it would in a real deployment.
    function New-AzResourceGroupDeployment {
        [CmdletBinding()]
        param ($Name, $ResourceGroupName, $TemplateFile, $TemplateParameterFile, [hashtable] $TemplateParameterObject, [switch] $WhatIf)
    }
    function New-AzSubscriptionDeployment {
        [CmdletBinding()]
        param ($Name, $Location, $TemplateFile, $TemplateParameterFile, [hashtable] $TemplateParameterObject, [switch] $WhatIf)
    }
    function New-AzManagementGroupDeployment {
        [CmdletBinding()]
        param ($Name, $ManagementGroupId, $Location, $TemplateFile, $TemplateParameterFile, [hashtable] $TemplateParameterObject, [switch] $WhatIf)
    }
    function New-AzTenantDeployment {
        [CmdletBinding()]
        param ($Name, $Location, $TemplateFile, $TemplateParameterFile, [hashtable] $TemplateParameterObject, [switch] $WhatIf)
    }
    function Get-AzResourceGroup { [CmdletBinding()] param ($Name) }
    function New-AzResourceGroup { [CmdletBinding()] param ($Name, $Location) }
    function Get-AzContext { [CmdletBinding()] param () }
    function Set-AzContext { [CmdletBinding()] param ($Subscription, $Context) }
    # Provided by the ZeroFailed module at runtime
    function Resolve-Value { param ($Value) if ($Value -is [scriptblock]) { & $Value } else { $Value } }

    $script:deploymentCmdlets = @{
        resourceGroup   = 'New-AzResourceGroupDeployment'
        subscription    = 'New-AzSubscriptionDeployment'
        managementGroup = 'New-AzManagementGroupDeployment'
        tenant          = 'New-AzTenantDeployment'
    }

    function New-TestDeployment {
        param ([string] $Scope, [string] $Extension = '.bicep')
        $entry = @{ scope = $Scope; templatePath = "main$Extension"; location = 'uksouth' }
        switch ($Scope) {
            'resourceGroup'   { $entry.resourceGroupName = 'rg-test' }
            'managementGroup' { $entry.managementGroupId = 'mg-test' }
        }
        return $entry
    }

    Set-StrictMode -Version Latest
}

Describe 'Invoke-ArmDeployment' {

    BeforeEach {
        $script:calls = [System.Collections.Generic.List[string]]::new()
        $successResult = [PSCustomObject]@{ ProvisioningState = 'Succeeded'; Outputs = @{ out1 = @{ Value = 'a' } } }

        # Not '$cmdlet': variable names are case-insensitive, and the test cases define '$Cmdlet'
        foreach ($deploymentCmdlet in $script:deploymentCmdlets.Values) {
            Mock $deploymentCmdlet { $script:calls.Add('deploy'); $successResult }
        }
        Mock Get-AzResourceGroup { $script:calls.Add('getResourceGroup'); [PSCustomObject]@{ ResourceGroupName = $Name } }
        Mock New-AzResourceGroup { [PSCustomObject]@{ ResourceGroupName = $Name } }
        Mock Get-AzContext { [PSCustomObject]@{ Name = 'original' } }
        Mock Set-AzContext { $script:calls.Add('setContext') }
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    Context 'Scope routing' {

        It '<Scope> scope with a <Extension> file in <Mode> mode calls <Cmdlet>' -ForEach @(
            foreach ($scope in 'resourceGroup', 'subscription', 'managementGroup', 'tenant') {
                foreach ($extension in '.bicep', '.bicepparam') {
                    foreach ($mode in 'deploy', 'what-if') {
                        @{ Scope = $scope; Extension = $extension; Mode = $mode; Cmdlet = $discoveryCmdlets[$scope] }
                    }
                }
            }
        ) {
            $isWhatIf = $Mode -eq 'what-if'
            $entry = New-TestDeployment -Scope $Scope -Extension $Extension

            $result = Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{ p1 = 'v1' } -WhatIfMode:$isWhatIf

            Should -Invoke $Cmdlet -Times 1 -Exactly -ParameterFilter {
                # An unbound switch is $null in a parameter filter
                [bool] $WhatIf -eq $isWhatIf -and
                $(if ($Extension -eq '.bicepparam') {
                    $TemplateParameterFile -eq 'main.bicepparam' -and !$TemplateFile -and !$TemplateParameterObject
                } else {
                    $TemplateFile -eq 'main.bicep' -and $TemplateParameterObject.p1 -eq 'v1' -and !$TemplateParameterFile
                })
            }
            foreach ($other in ($script:deploymentCmdlets.Values | Where-Object { $_ -ne $Cmdlet })) {
                Should -Not -Invoke $other
            }
            if ($isWhatIf) {
                $result | Should -BeNullOrEmpty
            }
            else {
                @($result).Count | Should -Be 1
                $result.ProvisioningState | Should -Be 'Succeeded'
                $result.Outputs.out1.Value | Should -Be 'a'
            }
        }

        It 'Passes the management group id at management group scope' {
            Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope managementGroup) -DeploymentConfig @{}

            Should -Invoke New-AzManagementGroupDeployment -Times 1 -ParameterFilter { $ManagementGroupId -eq 'mg-test' -and $Location -eq 'uksouth' }
        }

        It 'Does not pass a location at resource group scope' {
            # The stub, like the real cmdlet, has no 'Location' parameter, so passing one would throw
            { Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope resourceGroup) -DeploymentConfig @{} } | Should -Not -Throw

            Should -Invoke New-AzResourceGroupDeployment -Times 1 -ParameterFilter { $ResourceGroupName -eq 'rg-test' }
        }

        It 'Defaults to resource group scope when no scope is given' {
            $entry = New-TestDeployment -Scope resourceGroup
            $entry.Remove('scope')

            Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{}

            Should -Invoke New-AzResourceGroupDeployment -Times 1
        }
    }

    Context 'Validation' {

        It 'Throws for an unknown scope' {
            $entry = New-TestDeployment -Scope resourceGroup
            $entry.scope = 'galaxy'

            { Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{} } | Should -Throw "*unsupported scope 'galaxy'*"
        }

        It 'Throws when <Missing> is missing at <Scope> scope' -ForEach @(
            @{ Scope = 'resourceGroup'; Missing = 'resourceGroupName' }
            @{ Scope = 'managementGroup'; Missing = 'managementGroupId' }
            @{ Scope = 'subscription'; Missing = 'templatePath' }
            @{ Scope = 'tenant'; Missing = 'location' }
        ) {
            $entry = New-TestDeployment -Scope $Scope
            $entry.Remove($Missing)

            { Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{} } | Should -Throw "*missing required properties: $Missing*"
        }

        It 'Throws for a subscriptionId at <Scope> scope' -ForEach @(
            @{ Scope = 'managementGroup' }
            @{ Scope = 'tenant' }
        ) {
            $entry = New-TestDeployment -Scope $Scope
            $entry.subscriptionId = '11111111-1111-1111-1111-111111111111'

            { Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{} } | Should -Throw "*'subscriptionId' is only supported*"
            Should -Not -Invoke Set-AzContext
        }
    }

    Context 'Template parameters' {

        It 'Merges the environment config with additionalParameters, and skips empty and ignored keys' {
            $entry = New-TestDeployment -Scope subscription
            $entry.additionalParameters = @{ p1 = 'override'; p3 = { 'deferred' } }
            $entry.configKeysToIgnore = @('ignored')

            Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{ p1 = 'v1'; p2 = 'v2'; empty = ''; ignored = 'x' }

            Should -Invoke New-AzSubscriptionDeployment -Times 1 -ParameterFilter {
                $TemplateParameterObject.p1 -eq 'override' -and
                $TemplateParameterObject.p2 -eq 'v2' -and
                $TemplateParameterObject.p3 -eq 'deferred' -and
                !$TemplateParameterObject.ContainsKey('empty') -and
                !$TemplateParameterObject.ContainsKey('ignored')
            }
        }

        It 'Keeps the parameters of two deployments separate' {
            $script:parameterSets = [System.Collections.Generic.List[hashtable]]::new()
            Mock New-AzSubscriptionDeployment { $script:parameterSets.Add($TemplateParameterObject); [PSCustomObject]@{ ProvisioningState = 'Succeeded' } }
            $first = New-TestDeployment -Scope subscription
            $first.additionalParameters = @{ onlyFirst = 'x' }

            Invoke-ArmDeployment -ArmDeployment $first -DeploymentConfig @{ p1 = 'v1' }
            Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope subscription) -DeploymentConfig @{ p1 = 'v1' }

            $script:parameterSets[0].ContainsKey('onlyFirst') | Should -BeTrue
            $script:parameterSets[1].ContainsKey('onlyFirst') | Should -BeFalse
        }

        It 'Throws for additionalParameters with a .bicepparam file' {
            $entry = New-TestDeployment -Scope subscription -Extension '.bicepparam'
            $entry.additionalParameters = @{ p1 = 'x' }

            { Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{} } | Should -Throw "*'additionalParameters' are not supported with a '.bicepparam' file*"
            Should -Not -Invoke New-AzSubscriptionDeployment
        }
    }

    Context 'Missing resource group' {

        BeforeEach {
            Mock Get-AzResourceGroup { $null }
        }

        It 'Skips the what-if and creates nothing' {
            $result = Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope resourceGroup) -DeploymentConfig @{} -WhatIfMode

            $result | Should -BeNullOrEmpty
            Should -Not -Invoke New-AzResourceGroup
            Should -Not -Invoke New-AzResourceGroupDeployment
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like "*'rg-test' does not exist*" }
        }

        It 'Creates the resource group in a real run, and returns only the deployment result' {
            $result = Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope resourceGroup) -DeploymentConfig @{}

            Should -Invoke New-AzResourceGroup -Times 1 -ParameterFilter { $Name -eq 'rg-test' -and $Location -eq 'uksouth' }
            @($result).Count | Should -Be 1
            $result.ProvisioningState | Should -Be 'Succeeded'
        }
    }

    Context 'Subscription selection' {

        It 'Switches subscription before the resource group check at <Scope> scope, in <Mode> mode' -ForEach @(
            @{ Scope = 'resourceGroup'; Mode = 'deploy' }
            @{ Scope = 'resourceGroup'; Mode = 'what-if' }
            @{ Scope = 'subscription'; Mode = 'deploy' }
            @{ Scope = 'subscription'; Mode = 'what-if' }
        ) {
            $entry = New-TestDeployment -Scope $Scope
            $entry.subscriptionId = '11111111-1111-1111-1111-111111111111'

            Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{} -WhatIfMode:($Mode -eq 'what-if')

            Should -Invoke Set-AzContext -Times 1 -Exactly -ParameterFilter { $Subscription -eq '11111111-1111-1111-1111-111111111111' }
            $script:calls[0] | Should -Be 'setContext'
            Should -Invoke Set-AzContext -Times 1 -Exactly -ParameterFilter { $Context.Name -eq 'original' }
        }

        It 'Makes no context switch without a subscriptionId' {
            Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope subscription) -DeploymentConfig @{}

            Should -Not -Invoke Get-AzContext
            Should -Not -Invoke Set-AzContext
        }

        It 'Leaves a later deployment without a subscriptionId in the original context' {
            $first = New-TestDeployment -Scope subscription
            $first.subscriptionId = '11111111-1111-1111-1111-111111111111'

            Invoke-ArmDeployment -ArmDeployment $first -DeploymentConfig @{}
            Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope subscription) -DeploymentConfig @{}

            # Only the switch and the restore of the first deployment
            Should -Invoke Set-AzContext -Times 2 -Exactly
            $script:calls | Select-Object -Last 1 | Should -Be 'deploy'
        }

        It 'Restores the context when the deployment fails' {
            Mock New-AzSubscriptionDeployment { throw 'Deployment failed' }
            $entry = New-TestDeployment -Scope subscription
            $entry.subscriptionId = '11111111-1111-1111-1111-111111111111'

            { Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{} } | Should -Throw '*Deployment failed*'

            Should -Invoke Set-AzContext -Times 1 -Exactly -ParameterFilter { $Context.Name -eq 'original' }
        }
    }

    Context 'What-if errors' {

        BeforeEach {
            Mock New-AzSubscriptionDeployment { throw 'What-if failed' }
        }

        It 'Reports a what-if error as a warning with ContinueOnWhatIfError' {
            $result = Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope subscription) -DeploymentConfig @{} -WhatIfMode -ContinueOnWhatIfError

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like '*ARM what-if failed*What-if failed*' }
        }

        It 'Throws a what-if error without ContinueOnWhatIfError' {
            { Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope subscription) -DeploymentConfig @{} -WhatIfMode } | Should -Throw '*What-if failed*'
        }

        It 'Throws a deployment error even with ContinueOnWhatIfError' {
            { Invoke-ArmDeployment -ArmDeployment (New-TestDeployment -Scope subscription) -DeploymentConfig @{} -ContinueOnWhatIfError } | Should -Throw '*What-if failed*'
        }

        It 'Throws a configuration error even with ContinueOnWhatIfError' {
            $entry = New-TestDeployment -Scope subscription
            $entry.scope = 'galaxy'

            { Invoke-ArmDeployment -ArmDeployment $entry -DeploymentConfig @{} -WhatIfMode -ContinueOnWhatIfError } | Should -Throw '*unsupported scope*'
        }
    }
}

Describe 'Module wiring' {

    BeforeAll {
        $moduleRoot = Split-Path -Parent $PSScriptRoot
        $module = Import-Module (Join-Path $moduleRoot 'ZeroFailed.Deploy.Azure.psd1') -Force -PassThru
        $armTasks = Get-Content -Raw (Join-Path $moduleRoot 'tasks' 'arm.tasks.ps1')
    }

    AfterAll {
        # The module's copy cannot see the stubs above, so never leave it loaded for later tests
        Remove-Module $module -Force
    }

    It 'Exports Invoke-ArmDeployment, so that the task can call it' {
        $module.ExportedFunctions.Keys | Should -Contain 'Invoke-ArmDeployment'
    }

    It 'Calls Invoke-ArmDeployment from the deployArmTemplates task' {
        $armTasks | Should -Match 'Invoke-ArmDeployment\s+-ArmDeployment'
    }

    It 'Treats <Path> as a Bicep deployment in ensureBicepVersion: <Expected>' -ForEach @(
        @{ Path = 'main.bicep'; Expected = $true }
        @{ Path = 'main.bicepparam'; Expected = $true }
        @{ Path = 'main.json'; Expected = $false }
    ) {
        # Capture the pattern first, because 'Should' resets '$Matches'
        $found = $armTasks -match "templatePath -match '(?<pattern>[^']+)'"
        $pattern = $Matches.pattern
        $found | Should -BeTrue
        ($Path -match $pattern) | Should -Be $Expected
    }
}
