# <copyright file="Publish-FlexConsumptionFunctionApp.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Publish-FlexConsumptionFunctionApp {
    <#
    .SYNOPSIS
    Deploys a ZIP package to a Function App on the Flex Consumption plan, and waits for the deployment to finish.

    .DESCRIPTION
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

    .PARAMETER ResourceGroupName
    The resource group of the Function App.

    .PARAMETER Name
    The name of the Function App.

    .PARAMETER ArchivePath
    The path to the ZIP package to deploy.

    .PARAMETER RemoteBuild
    When set, the platform builds the package after the upload, for example to install the packages of a Python app.
    Do not set it for packages that are ready to run, such as .NET apps.

    .PARAMETER TimeoutSeconds
    The maximum time, in seconds, to wait for the deployment to finish.
    The default is 600.

    .EXAMPLE
    ```powershell
    Publish-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-func-app' -ArchivePath './app.zip'
    ```

    Deploys a package that is ready to run, such as a .NET app.

    .EXAMPLE
    ```powershell
    Publish-FlexConsumptionFunctionApp -ResourceGroupName 'my-rg' -Name 'my-python-app' -ArchivePath './app.zip' -RemoteBuild -TimeoutSeconds 1200
    ```

    Deploys a Python app, which the platform builds after the upload, and waits up to 20 minutes for the deployment to finish.

    .NOTES
    This function requires the Az.Accounts module and an active Azure PowerShell connection.
    It signs in to the SCM site with an Azure Resource Manager token for the current connection.
    The deploying identity needs permission to deploy to the app (`Microsoft.Web/sites/publish/Action`), which the Website Contributor, Contributor and Owner roles include.
    #>
    [CmdletBinding()]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string] $ArchivePath,

        [Parameter()]
        [switch] $RemoteBuild,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $TimeoutSeconds = 600
    )

    # The values of the 'status' field that the deployment status endpoint returns
    $statusNames = @{
        -1 = 'Cancelled'
        0 = 'Pending'
        1 = 'Building'
        2 = 'Deploying'
        3 = 'Failed'
        4 = 'Success'
        5 = 'Conflict'
        6 = 'PartialSuccess'
    }
    $inProgressStatuses = @(0, 1, 2)
    $successStatus = 4

    # The status endpoint can return HTTP 404 while it creates the deployment record
    $maxInitialNotFoundResponses = 10

    # The SCM site returns HTTP 403 when its access restrictions block a request. A change to the access restrictions,
    # such as a temporary rule for this machine, can take more than 30 seconds to apply. During that time, the SCM site
    # can block some requests and allow others. So the function retries these requests for up to 60 seconds.
    $forbiddenRetrySeconds = 60
    $uploadRetryIntervalSeconds = 5

    # Before PowerShell 7.4, Invoke-WebRequest can limit the time to receive the response headers, but not the time to read the response body
    $responseReadTimeoutSupported = $PSVersionTable.PSVersion -ge [version]'7.4'

    $site = _getWebAppSiteResource -ResourceGroupName $ResourceGroupName -Name $Name
    if ($site.properties.sku -ne 'FlexConsumption') {
        throw "The Function App '$Name' is not on the Flex Consumption plan. Its SKU is '$($site.properties.sku)'. Use Publish-AzWebApp to deploy apps on other plans."
    }

    # Newer apps have unique default host names, so read the SCM host name instead of building it from the app name
    $scmHostName = $site.properties.hostNameSslStates |
                        Where-Object { $_.hostType -eq 'Repository' } |
                        Select-Object -First 1 -ExpandProperty name
    if (!$scmHostName) {
        throw "The Function App '$Name' has no source control manager (SCM) host name. Its 'hostNameSslStates' property has no entry whose 'hostType' is 'Repository'."
    }

    $authSplat = @{
        Authentication = 'Bearer'
        Token = (Get-AzAccessToken -AsSecureString).Token
    }

    # Upload the package
    $publishUri = "https://$scmHostName/api/publish"
    if ($RemoteBuild) {
        $publishUri += '?RemoteBuild=true'
    }
    Write-Host "Uploading the package '$ArchivePath' to '$publishUri'"
    $uploadStart = Get-Date
    $uploadRetried = $false
    while ($true) {
        $uploadResponse = Invoke-WebRequest -Method Post `
                                            -Uri $publishUri `
                                            -InFile $ArchivePath `
                                            -ContentType 'application/zip' `
                                            -SkipHttpErrorCheck `
                                            @authSplat
        if ($uploadResponse.StatusCode -ne 403) {
            break
        }
        if (((Get-Date) - $uploadStart).TotalSeconds -ge $forbiddenRetrySeconds) {
            throw "The upload to '$publishUri' failed with HTTP 403 for $forbiddenRetrySeconds seconds. Check that the SCM site's access restrictions allow this machine. Check that the deploying identity can deploy to the app. Response: $($uploadResponse.Content)"
        }
        if (!$uploadRetried) {
            Write-Host "The upload returned HTTP 403, so the function retries every $uploadRetryIntervalSeconds seconds for up to $forbiddenRetrySeconds seconds. Changes to the SCM site's access restrictions can take more than 30 seconds to apply."
            $uploadRetried = $true
        }
        else {
            Write-Verbose "The upload returned HTTP 403 again. The function retries in $uploadRetryIntervalSeconds seconds."
        }
        Start-Sleep -Seconds $uploadRetryIntervalSeconds
    }
    if ($uploadResponse.StatusCode -ne 202) {
        throw "The upload to '$publishUri' failed with HTTP $($uploadResponse.StatusCode). Response: $($uploadResponse.Content)"
    }

    # The response body is the deployment ID, as a JSON string
    $deploymentId = $null
    try {
        $deploymentId = $uploadResponse.Content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {}
    if ($deploymentId -isnot [string] -or [string]::IsNullOrWhiteSpace($deploymentId)) {
        throw "The upload to '$publishUri' returned no deployment ID. Response: $($uploadResponse.Content)"
    }

    # Wait for the deployment to finish
    $deploymentUri = "https://$scmHostName/api/deployments/$deploymentId"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $notFoundCount = 0
    $forbiddenSince = $null
    $inProgressSeen = $false
    $lastStatus = $null
    $lastStatusText = $null
    $lastProgress = $null

    Write-Host "Waiting up to $TimeoutSeconds seconds for deployment '$deploymentId' to finish"
    while ($true) {
        # Limit each request to the time that remains, so that a request that gets no response cannot block the function indefinitely.
        # TimeoutSec limits the wait for the response headers, and OperationTimeoutSeconds limits each read of the body, not the whole request.
        # A slow response can therefore make the function finish after the timeout. This is unlikely, because the status response is small.
        $statusResponse = $null
        $remainingSeconds = [int][Math]::Ceiling(($deadline - (Get-Date)).TotalSeconds)
        if ($remainingSeconds -gt 0) {
            $timeoutSplat = @{ TimeoutSec = $remainingSeconds }
            if ($responseReadTimeoutSupported) {
                $timeoutSplat.OperationTimeoutSeconds = $remainingSeconds
            }
            try {
                $statusResponse = Invoke-WebRequest -Method Get -Uri $deploymentUri -SkipHttpErrorCheck @timeoutSplat @authSplat
            }
            catch [System.OperationCanceledException], [System.TimeoutException] {
                Write-Host "The status endpoint '$deploymentUri' did not respond within $remainingSeconds seconds"
            }
        }

        if ($null -eq $statusResponse) {
            $lastStatusName = $null -eq $lastStatus ? 'unknown' : $statusNames[$lastStatus]
            $message = "Deployment '$deploymentId' to the Function App '$Name' did not finish within $TimeoutSeconds seconds. Its last status was '$lastStatusName'."
            if ($lastStatusText) {
                $message += " Status text: '$lastStatusText'."
            }
            $message += " To wait longer, increase the timeout."
            throw $message
        }

        if ($statusResponse.StatusCode -eq 403) {
            if ($null -eq $forbiddenSince) {
                $forbiddenSince = Get-Date
                Write-Host "The status endpoint returned HTTP 403, so the function keeps checking for up to $forbiddenRetrySeconds seconds. Changes to the SCM site's access restrictions can take more than 30 seconds to apply."
            }
            elseif (((Get-Date) - $forbiddenSince).TotalSeconds -ge $forbiddenRetrySeconds) {
                throw "The status endpoint '$deploymentUri' returned HTTP 403 for $forbiddenRetrySeconds seconds. Check that the SCM site's access restrictions allow this machine. Response: $($statusResponse.Content)"
            }
        }
        elseif ($statusResponse.StatusCode -eq 404) {
            $forbiddenSince = $null
            if ($inProgressSeen) {
                # After a deployment finishes, the status endpoint can return HTTP 404 (Azure/azure-dev#3658).
                # The Azure CLI and the Azure Developer CLI treat this as success, so do the same.
                Write-Host "Deployment '$deploymentId' finished. Its status record is no longer available, which can happen after a successful deployment."
                return
            }

            $notFoundCount++
            if ($notFoundCount -gt $maxInitialNotFoundResponses) {
                throw "The status endpoint '$deploymentUri' returned HTTP 404 $notFoundCount times in a row. Check the deployment history of the Function App '$Name'."
            }
            Write-Verbose "Deployment '$deploymentId' has no status record yet ($notFoundCount of $maxInitialNotFoundResponses attempts)"
        }
        else {
            $forbiddenSince = $null
            $deployment = $null
            try {
                $deployment = $statusResponse.Content | ConvertFrom-Json -ErrorAction Stop
            }
            catch {}
            if ($null -eq $deployment -or $null -eq $deployment.status) {
                throw "The status endpoint '$deploymentUri' returned HTTP $($statusResponse.StatusCode) with no deployment status. Response: $($statusResponse.Content)"
            }

            $status = [int]$deployment.status
            $statusName = $statusNames[$status] ?? 'Unknown'
            $statusText = $deployment.status_text
            $progress = $deployment.progress

            if ($status -eq $successStatus) {
                Write-Host "Deployment '$deploymentId' succeeded"
                $deployment | Format-List | Out-String | Write-Verbose
                return
            }
            elseif ($status -in $inProgressStatuses) {
                $inProgressSeen = $true
                if ($status -ne $lastStatus -or $progress -ne $lastProgress) {
                    $message = "Deployment '$deploymentId' status: $statusName"
                    if ($progress) {
                        $message += " ($progress)"
                    }
                    Write-Host $message
                }
            }
            else {
                $message = "Deployment '$deploymentId' to the Function App '$Name' ended with the status '$statusName' ($status)."
                if ($statusText) {
                    $message += " Status text: '$statusText'."
                }
                if ($deployment.log_url) {
                    $message += " Deployment log: $($deployment.log_url)"
                }
                throw $message
            }

            $lastStatus = $status
            $lastStatusText = $statusText
            $lastProgress = $progress
        }

        Start-Sleep -Seconds 1
    }
}
