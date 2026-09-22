# <copyright file="Assert-PrivateEndpointConnectionApproval.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Assert-PrivateEndpointConnectionApproval {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [string] $PrivateLinkResourceId,

        [Parameter(Mandatory)]
        [string] $PrivateEndpointNameLike,

        [Parameter()]
        [string] $Description = 'Approved by the ZeroFailed deployment process',

        [Parameter()]
        [ValidateRange(0, 3600)]
        [int] $TimeoutSeconds = 300,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int] $PollIntervalSeconds = 15
    )

    # The private endpoint name is the last segment of the connection's private endpoint resource ID.
    function _getPrivateEndpointName($connection) {
        $privateEndpoint = $connection.PrivateEndpoint
        if ($privateEndpoint -and $privateEndpoint.Id) {
            return ($privateEndpoint.Id -split '/')[-1]
        }
        return $null
    }

    function _getStatus($connection) {
        $state = $connection.PrivateLinkServiceConnectionState
        if ($state) { return $state.Status }
        return $null
    }

    function _newReport($connection, $previousStatus, $status, $action) {
        @{
            PrivateLinkResourceId = $PrivateLinkResourceId
            PrivateEndpointName   = if ($connection) { _getPrivateEndpointName $connection } else { $null }
            ConnectionName        = if ($connection) { $connection.Name } else { $null }
            ConnectionId          = if ($connection) { $connection.Id } else { $null }
            PreviousStatus        = $previousStatus
            Status                = $status
            Action                = $action
        }
    }

    # A connection only appears on the target resource once the requesting service has finished
    # provisioning its private endpoint, so poll for it until the timeout.
    $maxAttempts = [Math]::Max(1, [Math]::Ceiling($TimeoutSeconds / $PollIntervalSeconds) + 1)
    $matchingConnections = @()
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $matchingConnections = @(
            Get-AzPrivateEndpointConnection -PrivateLinkResourceId $PrivateLinkResourceId -ErrorAction Stop |
                Where-Object { (_getPrivateEndpointName $_) -like $PrivateEndpointNameLike }
        )
        if ($matchingConnections.Count -gt 0 -or $attempt -eq $maxAttempts) { break }

        Write-Verbose "Waiting for a private endpoint connection matching '$PrivateEndpointNameLike' to appear on '$PrivateLinkResourceId'..."
        Start-Sleep -Seconds $PollIntervalSeconds
    }

    if ($matchingConnections.Count -eq 0) {
        Write-Warning "No private endpoint connection matching '$PrivateEndpointNameLike' was found on '$PrivateLinkResourceId' after $TimeoutSeconds seconds."
        return (_newReport $null $null 'NotFound' 'None')
    }
    if ($matchingConnections.Count -gt 1) {
        $names = ($matchingConnections | ForEach-Object { _getPrivateEndpointName $_ }) -join "', '"
        throw "More than one private endpoint connection on '$PrivateLinkResourceId' matches '$PrivateEndpointNameLike': '$names'. Use a more specific pattern."
    }

    $connection     = $matchingConnections[0]
    $previousStatus = _getStatus $connection

    switch ($previousStatus) {
        'Approved' {
            Write-Verbose "Private endpoint connection '$($connection.Name)' on '$PrivateLinkResourceId' is already approved."
            return (_newReport $connection $previousStatus $previousStatus 'Skipped')
        }

        'Pending' {
            if (-not $PSCmdlet.ShouldProcess("$PrivateLinkResourceId ($($connection.Name))", 'Approve private endpoint connection')) {
                return (_newReport $connection $previousStatus $previousStatus 'WhatIf')
            }

            Write-Verbose "Approving private endpoint connection '$($connection.Name)' on '$PrivateLinkResourceId'..."
            Approve-AzPrivateEndpointConnection -ResourceId $connection.Id -Description $Description -ErrorAction Stop | Out-Null

            # Approval can take a short while to be reflected on the connection.
            $status = $previousStatus
            for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                $status = _getStatus (Get-AzPrivateEndpointConnection -ResourceId $connection.Id -ErrorAction Stop)
                if ($status -eq 'Approved' -or $attempt -eq $maxAttempts) { break }

                Write-Verbose "Waiting for the approval of private endpoint connection '$($connection.Name)' to take effect..."
                Start-Sleep -Seconds $PollIntervalSeconds
            }

            if ($status -ne 'Approved') {
                Write-Warning "Private endpoint connection '$($connection.Name)' on '$PrivateLinkResourceId' was approved, but its status is still '$status' after $TimeoutSeconds seconds."
            }
            return (_newReport $connection $previousStatus $status 'Approved')
        }

        default {
            # Rejected or Disconnected connections are left alone: rejecting a connection is a decision
            # made by the resource owner, and a disconnected one needs its private endpoint re-created.
            Write-Warning "Private endpoint connection '$($connection.Name)' on '$PrivateLinkResourceId' has status '$previousStatus' and will not be approved automatically."
            return (_newReport $connection $previousStatus $previousStatus 'None')
        }
    }
}
