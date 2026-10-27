# <copyright file="Publish-FlexConsumptionFunctionApp.Integration.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    $functionsDir = Split-Path -Parent $PSCommandPath
    . (Join-Path $functionsDir '_getWebAppSiteResource.ps1')
    . (Join-Path $functionsDir 'Test-FlexConsumptionFunctionApp.ps1')
    . (Join-Path $functionsDir 'Publish-FlexConsumptionFunctionApp.ps1')
    . (Join-Path $functionsDir 'Set-TemporaryAzureResourceNetworkAccess.ps1')
}

# These tests create a Function App on the Flex Consumption plan in a new resource group, and delete the resource group
# afterwards. The signed-in identity needs the Owner role (or Contributor and User Access Administrator) on the
# subscription, because the template assigns a storage role to the app's managed identity.
Describe "Publish-FlexConsumptionFunctionApp Integration Tests" -Tag Integration {
    BeforeAll {
        $currentUser = Get-AzADUser -SignedIn
        # Generate stable user-specific naming conventions that will work for users and service principals
        $suffix = ($currentUser.Id -replace "-","").SubString(0,20)
        $rg = "pester-flexdeploy-$($currentUser.Id)"
        $location = "uksouth"
        $appName = "flex-$suffix"

        New-AzResourceGroup -ResourceGroupName $rg -Location $location -Tag @{Environment = "Pester"} -Force | Out-Null

        # An ARM template, rather than Bicep, so that the tests do not need the Bicep CLI
        $template = @{
            '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
            contentVersion = '1.0.0.0'
            parameters = @{
                appName = @{ type = 'string' }
                storageAccountName = @{ type = 'string' }
                location = @{ type = 'string' }
            }
            variables = @{
                deploymentContainerName = 'app-package'
                storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
            }
            resources = @(
                @{
                    type = 'Microsoft.Storage/storageAccounts'
                    apiVersion = '2023-05-01'
                    name = "[parameters('storageAccountName')]"
                    location = "[parameters('location')]"
                    kind = 'StorageV2'
                    sku = @{ name = 'Standard_LRS' }
                    tags = @{ Environment = 'Pester' }
                    properties = @{
                        allowSharedKeyAccess = $false
                        allowBlobPublicAccess = $false
                        minimumTlsVersion = 'TLS1_2'
                        supportsHttpsTrafficOnly = $true
                    }
                }
                @{
                    type = 'Microsoft.Storage/storageAccounts/blobServices/containers'
                    apiVersion = '2023-05-01'
                    name = "[format('{0}/default/{1}', parameters('storageAccountName'), variables('deploymentContainerName'))]"
                    dependsOn = @("[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]")
                }
                @{
                    type = 'Microsoft.Web/serverfarms'
                    apiVersion = '2024-04-01'
                    name = "[parameters('appName')]"
                    location = "[parameters('location')]"
                    kind = 'functionapp'
                    sku = @{ tier = 'FlexConsumption'; name = 'FC1' }
                    tags = @{ Environment = 'Pester' }
                    properties = @{ reserved = $true }
                }
                @{
                    type = 'Microsoft.Web/sites'
                    apiVersion = '2024-04-01'
                    name = "[parameters('appName')]"
                    location = "[parameters('location')]"
                    kind = 'functionapp,linux'
                    tags = @{ Environment = 'Pester' }
                    identity = @{ type = 'SystemAssigned' }
                    dependsOn = @(
                        "[resourceId('Microsoft.Web/serverfarms', parameters('appName'))]"
                        "[resourceId('Microsoft.Storage/storageAccounts/blobServices/containers', parameters('storageAccountName'), 'default', variables('deploymentContainerName'))]"
                    )
                    properties = @{
                        serverFarmId = "[resourceId('Microsoft.Web/serverfarms', parameters('appName'))]"
                        httpsOnly = $true
                        siteConfig = @{
                            minTlsVersion = '1.2'
                            appSettings = @(
                                @{ name = 'AzureWebJobsStorage__accountName'; value = "[parameters('storageAccountName')]" }
                            )
                        }
                        functionAppConfig = @{
                            deployment = @{
                                storage = @{
                                    type = 'blobContainer'
                                    value = "[format('{0}{1}', reference(resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName')), '2023-05-01').primaryEndpoints.blob, variables('deploymentContainerName'))]"
                                    authentication = @{ type = 'SystemAssignedIdentity' }
                                }
                            }
                            scaleAndConcurrency = @{ maximumInstanceCount = 40; instanceMemoryMB = 2048 }
                            runtime = @{ name = 'powershell'; version = '7.4' }
                        }
                    }
                }
                @{
                    type = 'Microsoft.Authorization/roleAssignments'
                    apiVersion = '2022-04-01'
                    scope = "[format('Microsoft.Storage/storageAccounts/{0}', parameters('storageAccountName'))]"
                    name = "[guid(resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName')), parameters('appName'), variables('storageBlobDataOwnerRoleId'))]"
                    dependsOn = @("[resourceId('Microsoft.Web/sites', parameters('appName'))]")
                    properties = @{
                        roleDefinitionId = "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', variables('storageBlobDataOwnerRoleId'))]"
                        principalId = "[reference(resourceId('Microsoft.Web/sites', parameters('appName')), '2024-04-01', 'full').identity.principalId]"
                        principalType = 'ServicePrincipal'
                    }
                }
            )
            outputs = @{
                defaultHostName = @{
                    type = 'string'
                    value = "[reference(resourceId('Microsoft.Web/sites', parameters('appName')), '2024-04-01').defaultHostName]"
                }
            }
        }

        Write-Host "Creating the Flex Consumption Function App '$appName' - this will take a few minutes..."
        $deploymentParams = @{
            ResourceGroupName = $rg
            Name = "pester-flexdeploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            TemplateObject = $template
            TemplateParameterObject = @{
                appName = $appName
                storageAccountName = $suffix
                location = $location
            }
        }
        $deployment = New-AzResourceGroupDeployment @deploymentParams -ErrorAction Stop
        $defaultHostName = $deployment.Outputs.defaultHostName.Value
        $scmHostName = (_getWebAppSiteResource -ResourceGroupName $rg -Name $appName).properties.hostNameSslStates |
                            Where-Object { $_.hostType -eq 'Repository' } |
                            Select-Object -First 1 -ExpandProperty name

        # A change to the SCM site's access restrictions can take more than 30 seconds to apply. During that time, the
        # SCM site can block some requests and allow others. So wait until 5 requests in a row get the expected result.
        $waitForScmAccess = {
            param ([bool] $Blocked)
            Write-Host "Waiting for the SCM site access restrictions to update..."
            $token = (Get-AzAccessToken -AsSecureString).Token
            $deadline = (Get-Date).AddMinutes(5)
            $consecutiveCount = 0
            while ($consecutiveCount -lt 5) {
                if ((Get-Date) -gt $deadline) {
                    throw "The SCM site's access restrictions did not update within 5 minutes."
                }
                $statusCode = (Invoke-WebRequest -Uri "https://$scmHostName/api/deployments" -Authentication Bearer -Token $token -SkipHttpErrorCheck).StatusCode
                $consecutiveCount = (($statusCode -eq 403) -eq $Blocked) ? $consecutiveCount + 1 : 0
                Start-Sleep -Seconds 3
            }
        }

        # Ensure an existing app is in the correct initial state, with no restrictions on the SCM site
        $webConfigUri = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$rg/providers/Microsoft.Web/sites/$appName/config/web?api-version=2024-04-01"
        $setScmDefaultAction = {
            param ([string] $Action)
            $payload = @{ properties = @{ scmIpSecurityRestrictionsDefaultAction = $Action; scmIpSecurityRestrictionsUseMain = $false } }
            $resp = Invoke-AzRestMethod -Method PATCH -Path $webConfigUri -Payload ($payload | ConvertTo-Json -Depth 10)
            if ($resp.StatusCode -ge 400) {
                throw "Unable to set the SCM site's default access action to '$Action': $($resp.Content)"
            }
        }
        & $setScmDefaultAction 'Allow'
        Set-TemporaryAzureResourceNetworkAccess -ResourceType WebAppScm -ResourceGroupName $rg -ResourceName $appName -Revoke -ErrorAction Stop

        # Wait for the app's identity to be able to use the deployment storage container
        Write-Host "Waiting for the storage role assignment to take effect..."
        Start-Sleep -Seconds 60

        # Build a small PowerShell Function App package with one anonymous HTTP function
        $packageDir = Join-Path $TestDrive 'package'
        New-Item -ItemType Directory -Path (Join-Path $packageDir 'ping') -Force | Out-Null
        @{
            version = '2.0'
            managedDependency = @{ enabled = $false }
            extensionBundle = @{ id = 'Microsoft.Azure.Functions.ExtensionBundle'; version = '[4.*, 5.0.0)' }
        } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packageDir 'host.json')
        @{
            bindings = @(
                @{ authLevel = 'anonymous'; type = 'httpTrigger'; direction = 'in'; name = 'Request'; methods = @('get') }
                @{ type = 'http'; direction = 'out'; name = 'Response' }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $packageDir 'ping' 'function.json')
        @(
            'using namespace System.Net'
            'param($Request, $TriggerMetadata)'
            'Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = "pong" })'
        ) | Set-Content (Join-Path $packageDir 'ping' 'run.ps1')
        $packagePath = Join-Path $TestDrive 'app.zip'
        Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $packagePath -Force

        $invalidPackagePath = Join-Path $TestDrive 'invalid.zip'
        Set-Content -Path $invalidPackagePath -Value 'This file is not a ZIP package'
    }

    AfterAll {
        Write-Host "`n`nCleaning-up Azure test resources..."
        Remove-AzResourceGroup -ResourceGroupName $rg -Force | Out-Null
    }

    It "should detect that the app is on the Flex Consumption plan" {
        Test-FlexConsumptionFunctionApp -ResourceGroupName $rg -Name $appName | Should -BeTrue
    }

    It "should deploy the package and wait for the deployment to finish" {
        { Publish-FlexConsumptionFunctionApp -ResourceGroupName $rg -Name $appName -ArchivePath $packagePath } |
            Should -Not -Throw

        # The new function can take a short time to start
        $resp = $null
        for ($i = 0; $i -lt 18 -and $resp.StatusCode -ne 200; $i++) {
            Start-Sleep -Seconds 10
            $resp = Invoke-WebRequest -Uri "https://$defaultHostName/api/ping" -SkipHttpErrorCheck
        }
        $resp.StatusCode | Should -Be 200
        $resp.Content | Should -Be 'pong'
    }

    It "should throw an error when the deployment fails" {
        { Publish-FlexConsumptionFunctionApp -ResourceGroupName $rg -Name $appName -ArchivePath $invalidPackagePath } |
            Should -Throw "*ended with the status*"
    }

    Context "When the SCM site denies access by default" {
        BeforeAll {
            & $setScmDefaultAction 'Deny'
            & $waitForScmAccess -Blocked $true
        }

        AfterAll {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType WebAppScm -ResourceGroupName $rg -ResourceName $appName -Revoke
        }

        It "should not be able to upload the package without temporary network access" {
            { Publish-FlexConsumptionFunctionApp -ResourceGroupName $rg -Name $appName -ArchivePath $packagePath } |
                Should -Throw "*failed with HTTP 403*"
        }

        It "should deploy the package with temporary network access to the SCM site" {
            # This does not wait for the access restrictions to update, because the function retries blocked requests
            Set-TemporaryAzureResourceNetworkAccess -ResourceType WebAppScm -ResourceGroupName $rg -ResourceName $appName -Wait -ErrorAction Stop

            { Publish-FlexConsumptionFunctionApp -ResourceGroupName $rg -Name $appName -ArchivePath $packagePath } |
                Should -Not -Throw
        }

        It "should not be able to upload the package after the temporary network access is revoked" {
            Set-TemporaryAzureResourceNetworkAccess -ResourceType WebAppScm -ResourceGroupName $rg -ResourceName $appName -Revoke -Wait -ErrorAction Stop
            & $waitForScmAccess -Blocked $true

            { Publish-FlexConsumptionFunctionApp -ResourceGroupName $rg -Name $appName -ArchivePath $packagePath } |
                Should -Throw "*failed with HTTP 403*"
        }
    }
}
