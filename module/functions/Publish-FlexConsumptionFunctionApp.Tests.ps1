# <copyright file="Publish-FlexConsumptionFunctionApp.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # Make private functions available for mocking
    function _getWebAppSiteResource { param ($ResourceGroupName, $Name) }

    # Mock external dependencies
    Import-Module Az.Accounts

    $scmHostName = 'my-func-app-abc123.scm.uksouth-01.azurewebsites.net'
    $publishUri = "https://$scmHostName/api/publish"
    $deploymentUri = "https://$scmHostName/api/deployments/dep-123"
    $archivePath = Join-Path $TestDrive 'app.zip'
    Set-Content -Path $archivePath -Value 'not a real package'

    $splat = @{
        ResourceGroupName = 'my-rg'
        Name = 'my-func-app'
        ArchivePath = $archivePath
    }

    function New-MockSite {
        param (
            [string] $Sku = 'FlexConsumption',
            [object[]] $HostNameSslStates = @(
                @{ name = 'my-func-app-abc123.uksouth-01.azurewebsites.net'; hostType = 'Standard' }
                @{ name = $scmHostName; hostType = 'Repository' }
            )
        )
        [pscustomobject]@{
            properties = [pscustomobject]@{
                sku = $Sku
                hostNameSslStates = $HostNameSslStates | ForEach-Object { [pscustomobject]$_ }
            }
        }
    }

    function New-MockResponse {
        param (
            [int] $StatusCode,
            [string] $Content
        )
        [pscustomobject]@{
            StatusCode = $StatusCode
            Content = $Content
        }
    }

    function New-StatusResponse {
        param (
            [int] $Status,
            [int] $StatusCode = 200,
            [string] $StatusText = '',
            [string] $Progress = ''
        )
        $body = @{
            id = 'dep-123'
            status = $Status
            status_text = $StatusText
            progress = $Progress
            log_url = "$deploymentUri/log"
        }
        New-MockResponse -StatusCode $StatusCode -Content ($body | ConvertTo-Json)
    }

    # The status endpoint returns these responses in order. The last one repeats.
    function Set-StatusResponses {
        param (
            [object[]] $Responses
        )
        $script:statusResponses = [System.Collections.Generic.Queue[object]]::new()
        $Responses | ForEach-Object { $script:statusResponses.Enqueue($_) }
    }

    # The upload endpoint returns these responses in order. The last one repeats.
    function Set-UploadResponses {
        param (
            [object[]] $Responses
        )
        $script:uploadResponses = [System.Collections.Generic.Queue[object]]::new()
        $Responses | ForEach-Object { $script:uploadResponses.Enqueue($_) }
    }
}

Describe 'Publish-FlexConsumptionFunctionApp' {

    BeforeEach {
        # A simulated clock, so that tests do not wait and timeouts are predictable
        $script:now = [datetime]::new(2026, 1, 1)
        Mock Get-Date { $script:now }
        Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }

        Mock Write-Host {}
        Mock _getWebAppSiteResource { New-MockSite }
        Mock Get-AzAccessToken {
            [pscustomobject]@{ Token = (ConvertTo-SecureString -String 'mock-token' -AsPlainText -Force) }
        }
        Mock Invoke-WebRequest {
            if ($script:uploadResponses.Count -gt 1) { $script:uploadResponses.Dequeue() } else { $script:uploadResponses.Peek() }
        } -ParameterFilter { $Method -eq 'Post' }
        Mock Invoke-WebRequest {
            if ($script:statusResponses.Count -gt 1) { $script:statusResponses.Dequeue() } else { $script:statusResponses.Peek() }
        } -ParameterFilter { $Method -eq 'Get' }

        Set-UploadResponses @(New-MockResponse -StatusCode 202 -Content '"dep-123"')
        Set-StatusResponses @(New-StatusResponse -Status 4)
    }

    Context 'When the app is not on the Flex Consumption plan' {
        It 'should throw an error and not upload the package' {
            Mock _getWebAppSiteResource { New-MockSite -Sku 'Dynamic' }

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*'my-func-app' is not on the Flex Consumption plan*'Dynamic'*Publish-AzWebApp*"

            Should -Not -Invoke Invoke-WebRequest
        }
    }

    Context 'When the app has no SCM host name' {
        It 'should throw an error and not upload the package' {
            Mock _getWebAppSiteResource {
                New-MockSite -HostNameSslStates @(@{ name = 'my-func-app.azurewebsites.net'; hostType = 'Standard' })
            }

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*'my-func-app' has no source control manager (SCM) host name*"

            Should -Not -Invoke Invoke-WebRequest
        }
    }

    Context 'When uploading the package' {
        It 'should post the package to the SCM site of the app' {
            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and
                $Uri -eq $publishUri -and
                $InFile -eq $archivePath -and
                $ContentType -eq 'application/zip' -and
                $Authentication -eq 'Bearer' -and
                $Token -is [securestring]
            }
        }

        It 'should request a remote build when RemoteBuild is set' {
            Publish-FlexConsumptionFunctionApp @splat -RemoteBuild

            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and $Uri -eq "$($publishUri)?RemoteBuild=true"
            }
        }

        It 'should throw an error when the upload returns HTTP <StatusCode>' -ForEach @(
            @{ StatusCode = 200 }
            @{ StatusCode = 401 }
            @{ StatusCode = 500 }
        ) {
            Mock Invoke-WebRequest { New-MockResponse -StatusCode $StatusCode -Content 'upload error' } -ParameterFilter { $Method -eq 'Post' }

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*upload to '$publishUri' failed with HTTP $StatusCode*upload error*"

            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Post' }
            Should -Not -Invoke Invoke-WebRequest -ParameterFilter { $Method -eq 'Get' }
        }

        It "should throw an error when the upload response has no deployment ID: '<Content>'" -ForEach @(
            @{ Content = '' }
            @{ Content = 'not json' }
            @{ Content = '""' }
            @{ Content = '{"id":"dep-123"}' }
        ) {
            Mock Invoke-WebRequest { New-MockResponse -StatusCode 202 -Content $Content } -ParameterFilter { $Method -eq 'Post' }

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*upload to '$publishUri' returned no deployment ID*"

            Should -Not -Invoke Invoke-WebRequest -ParameterFilter { $Method -eq 'Get' }
        }
    }

    Context 'When the deployment succeeds' {
        It 'should return as soon as the status is Success' {
            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' -and $Uri -eq $deploymentUri }
            Should -Not -Invoke Start-Sleep
        }

        It 'should wait while the deployment is pending, building and deploying' {
            Set-StatusResponses @(
                New-StatusResponse -Status 0
                New-StatusResponse -Status 1
                New-StatusResponse -Status 2
                New-StatusResponse -Status 4
            )

            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Invoke-WebRequest -Exactly -Times 4 -ParameterFilter { $Method -eq 'Get' -and $Uri -eq $deploymentUri }
            Should -Invoke Start-Sleep -Exactly -Times 3 -ParameterFilter { $Seconds -eq 1 }
        }

        It 'should read the status from the body, whatever the HTTP status code' {
            Set-StatusResponses @(
                New-StatusResponse -Status 1 -StatusCode 202
                New-StatusResponse -Status 1 -StatusCode 500
                New-StatusResponse -Status 4 -StatusCode 200
            )

            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Invoke-WebRequest -Exactly -Times 3 -ParameterFilter { $Method -eq 'Get' }
        }

        It 'should log each status change once' {
            Set-StatusResponses @(
                New-StatusResponse -Status 1
                New-StatusResponse -Status 1
                New-StatusResponse -Status 1
                New-StatusResponse -Status 2 -Progress 'Copying files'
                New-StatusResponse -Status 4
            )

            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Write-Host -Exactly -Times 1 -ParameterFilter { $Object -eq "Deployment 'dep-123' status: Building" }
            Should -Invoke Write-Host -Exactly -Times 1 -ParameterFilter { $Object -eq "Deployment 'dep-123' status: Deploying (Copying files)" }
            Should -Invoke Write-Host -Exactly -Times 1 -ParameterFilter { $Object -eq "Deployment 'dep-123' succeeded" }
        }
    }

    Context 'When the deployment does not succeed' {
        It "should throw an error when the status is '<StatusName>' (<Status>)" -ForEach @(
            @{ Status = -1; StatusName = 'Cancelled' }
            @{ Status = 3; StatusName = 'Failed' }
            @{ Status = 5; StatusName = 'Conflict' }
            @{ Status = 6; StatusName = 'PartialSuccess' }
            @{ Status = 7; StatusName = 'Unknown' }
        ) {
            Set-StatusResponses @(
                New-StatusResponse -Status 1
                New-StatusResponse -Status $Status -StatusText 'Something went wrong'
            )

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "Deployment 'dep-123' to the Function App 'my-func-app' ended with the status '$StatusName' ($Status). Status text: 'Something went wrong'. Deployment log: $deploymentUri/log"
        }

        It 'should use the status from the body when the HTTP status code is 202' {
            Set-StatusResponses @(New-StatusResponse -Status 3 -StatusCode 202)

            { Publish-FlexConsumptionFunctionApp @splat } | Should -Throw "*ended with the status 'Failed' (3)*"
        }

        It 'should throw an error when a response has no deployment status' {
            Set-StatusResponses @(New-MockResponse -StatusCode 500 -Content 'Internal Server Error')

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*'$deploymentUri' returned HTTP 500 with no deployment status*Internal Server Error*"
        }

        It 'should throw an error when the deployment does not finish within the timeout' {
            Set-StatusResponses @(New-StatusResponse -Status 1 -StatusText 'Building the app')

            { Publish-FlexConsumptionFunctionApp @splat -TimeoutSeconds 5 } |
                Should -Throw "Deployment 'dep-123' to the Function App 'my-func-app' did not finish within 5 seconds. Its last status was 'Building'. Status text: 'Building the app'. To wait longer, increase the timeout."

            # Polls at 0, 1, 2, 3 and 4 seconds on the simulated clock
            Should -Invoke Invoke-WebRequest -Exactly -Times 5 -ParameterFilter { $Method -eq 'Get' }
        }

        It 'should limit each status request to the time that remains before the timeout' {
            Set-StatusResponses @(
                New-StatusResponse -Status 1
                New-StatusResponse -Status 1
                New-StatusResponse -Status 4
            )

            Publish-FlexConsumptionFunctionApp @splat -TimeoutSeconds 5

            Should -Invoke Invoke-WebRequest -Exactly -Times 3 -ParameterFilter { $Method -eq 'Get' }
            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' -and $TimeoutSec -eq 5 }
            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' -and $TimeoutSec -eq 4 }
            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' -and $TimeoutSec -eq 3 }

            # Invoke-WebRequest has the OperationTimeoutSeconds parameter only in PowerShell 7.4 and later
            if ($PSVersionTable.PSVersion -ge [version]'7.4') {
                Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' -and $OperationTimeoutSeconds -eq 5 }
                Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' -and $OperationTimeoutSeconds -eq 4 }
                Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' -and $OperationTimeoutSeconds -eq 3 }
            }
        }

        # Invoke-WebRequest throws a TaskCanceledException when it gets no response headers in time,
        # and a TimeoutException when it cannot read the response body in time
        It 'should throw an error when a status request gets no response before the timeout (<ExceptionType>)' -ForEach @(
            @{ ExceptionType = [System.Threading.Tasks.TaskCanceledException] }
            @{ ExceptionType = [System.TimeoutException] }
        ) {
            $script:statusRequestCount = 0
            Mock Invoke-WebRequest {
                $script:statusRequestCount++
                if ($script:statusRequestCount -eq 1) {
                    return New-StatusResponse -Status 1 -StatusText 'Building the app'
                }
                # The request waits until its timeout ends, at the deadline
                $script:now = $script:now.AddSeconds(4)
                throw $ExceptionType::new('No response')
            } -ParameterFilter { $Method -eq 'Get' }

            { Publish-FlexConsumptionFunctionApp @splat -TimeoutSeconds 5 } |
                Should -Throw "Deployment 'dep-123' to the Function App 'my-func-app' did not finish within 5 seconds. Its last status was 'Building'. Status text: 'Building the app'. To wait longer, increase the timeout."

            Should -Invoke Invoke-WebRequest -Exactly -Times 2 -ParameterFilter { $Method -eq 'Get' }
            Should -Invoke Write-Host -Exactly -Times 1 -ParameterFilter { $Object -eq "The status endpoint '$deploymentUri' did not respond within 4 seconds" }
        }
    }

    Context 'When the status endpoint returns HTTP 404' {
        It 'should retry while the deployment record is created' {
            Set-StatusResponses @(
                New-MockResponse -StatusCode 404
                New-MockResponse -StatusCode 404
                New-StatusResponse -Status 4
            )

            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Invoke-WebRequest -Exactly -Times 3 -ParameterFilter { $Method -eq 'Get' }
        }

        It 'should throw an error after more than 10 HTTP 404 responses in a row at the start' {
            Set-StatusResponses @(New-MockResponse -StatusCode 404)

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*'$deploymentUri' returned HTTP 404 11 times in a row*"

            Should -Invoke Invoke-WebRequest -Exactly -Times 11 -ParameterFilter { $Method -eq 'Get' }
        }

        It 'should treat HTTP 404 after an in-progress status as success' {
            Set-StatusResponses @(
                New-StatusResponse -Status 2
                New-MockResponse -StatusCode 404
            )

            { Publish-FlexConsumptionFunctionApp @splat } | Should -Not -Throw

            Should -Invoke Invoke-WebRequest -Exactly -Times 2 -ParameterFilter { $Method -eq 'Get' }
            Should -Invoke Write-Host -Exactly -Times 1 -ParameterFilter { $Object -like "Deployment 'dep-123' finished.*" }
        }
    }

    # After a change to the access restrictions of the SCM site, the SCM site can block some requests and allow others
    Context 'When the SCM site returns HTTP 403' {
        It 'should retry the upload every 5 seconds' {
            Set-UploadResponses @(
                New-MockResponse -StatusCode 403 -Content 'blocked'
                New-MockResponse -StatusCode 403 -Content 'blocked'
                New-MockResponse -StatusCode 202 -Content '"dep-123"'
            )

            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Invoke-WebRequest -Exactly -Times 3 -ParameterFilter { $Method -eq 'Post' }
            Should -Invoke Start-Sleep -Exactly -Times 2 -ParameterFilter { $Seconds -eq 5 }
            Should -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' }
            Should -Invoke Write-Host -Exactly -Times 1 -ParameterFilter { $Object -like 'The upload returned HTTP 403*' }
        }

        It 'should throw an error when the upload returns HTTP 403 for 60 seconds' {
            Set-UploadResponses @(New-MockResponse -StatusCode 403 -Content 'blocked')

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*upload to '$publishUri' failed with HTTP 403 for 60 seconds*access restrictions*blocked*"

            # Uploads at 0, 5, 10 ... 60 seconds on the simulated clock
            Should -Invoke Invoke-WebRequest -Exactly -Times 13 -ParameterFilter { $Method -eq 'Post' }
            Should -Not -Invoke Invoke-WebRequest -ParameterFilter { $Method -eq 'Get' }
        }

        It 'should keep checking the status of the deployment' {
            Set-StatusResponses @(
                New-StatusResponse -Status 1
                New-MockResponse -StatusCode 403 -Content 'blocked'
                New-MockResponse -StatusCode 403 -Content 'blocked'
                New-StatusResponse -Status 4
            )

            Publish-FlexConsumptionFunctionApp @splat

            Should -Invoke Invoke-WebRequest -Exactly -Times 4 -ParameterFilter { $Method -eq 'Get' }
        }

        It 'should throw an error when the status endpoint returns HTTP 403 for 60 seconds' {
            Set-StatusResponses @(
                New-StatusResponse -Status 1
                New-MockResponse -StatusCode 403 -Content 'blocked'
            )

            { Publish-FlexConsumptionFunctionApp @splat } |
                Should -Throw "*'$deploymentUri' returned HTTP 403 for 60 seconds*access restrictions*"

            # The first HTTP 403 is at 1 second on the simulated clock, and the last is at 61 seconds
            Should -Invoke Invoke-WebRequest -Exactly -Times 62 -ParameterFilter { $Method -eq 'Get' }
        }

        It 'should measure the 60 seconds from the start of each run of HTTP 403 responses' {
            Set-StatusResponses @(
                (1..50 | ForEach-Object { New-MockResponse -StatusCode 403 -Content 'blocked' })
                New-StatusResponse -Status 1
                (1..50 | ForEach-Object { New-MockResponse -StatusCode 403 -Content 'blocked' })
                New-StatusResponse -Status 4
            )

            { Publish-FlexConsumptionFunctionApp @splat } | Should -Not -Throw

            Should -Invoke Invoke-WebRequest -Exactly -Times 102 -ParameterFilter { $Method -eq 'Get' }
        }
    }
}
