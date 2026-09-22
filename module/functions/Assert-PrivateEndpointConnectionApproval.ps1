# <copyright file="Assert-PrivateEndpointConnectionApproval.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Assert-PrivateEndpointConnectionApproval {
    <#
    .SYNOPSIS
    Ensures that a private endpoint connection to an Azure resource is approved.

    .DESCRIPTION
    When a service such as Microsoft Fabric, Azure Synapse or Azure Data Factory creates a managed private endpoint
    to an Azure resource, it sends a private endpoint connection request to that resource. The connection cannot
    be used until the owner of the resource approves it. This function finds the connection on the target resource
    and approves it, so that the approval can be automated as part of a deployment process.

    The connection is identified by the name of its private endpoint, matched against the `-PrivateEndpointNameLike`
    wildcard pattern. Services name the private endpoint after the managed private endpoint, typically with a prefix
    identifying the requesting workspace, so a pattern such as `*.my-endpoint-name` is usually sufficient.

    The connection only appears on the target resource once the requesting service has finished provisioning its
    private endpoint, so the function polls for it until `-TimeoutSeconds` has elapsed. It then acts on the
    connection's status:

    | Status                     | Action                                                                                      |
    | -------------------------- | ------------------------------------------------------------------------------------------- |
    | `Pending`                  | Approves the connection, then waits for the approval to take effect (`Action = 'Approved'`) |
    | `Approved`                 | Nothing to do (`Action = 'Skipped'`)                                                        |
    | `Rejected`, `Disconnected` | Writes a warning and leaves the connection alone (`Action = 'None'`)                        |
    | Not found before timeout   | Writes a warning (`Status = 'NotFound'`, `Action = 'None'`)                                 |

    Rejected connections are never approved automatically, as rejecting a connection is a decision made by the owner
    of the resource. If more than one connection matches the pattern, the function throws rather than guessing.

    Errors raised when listing or approving connections, such as the deploying identity lacking permission to approve
    connections on the resource, are not caught, so that the caller can decide how to handle them.

    .PARAMETER PrivateLinkResourceId
    The Azure resource ID of the resource that is the target of the private endpoint connection, for example a Key
    Vault or storage account.

    .PARAMETER PrivateEndpointNameLike
    A wildcard pattern matched against the name of each connection's private endpoint, identifying the connection
    to approve.

    .PARAMETER Description
    The message recorded against the connection when it is approved.

    .PARAMETER TimeoutSeconds
    How long to wait, both for the connection to appear on the resource and for the approval to take effect.
    Between 0 and 3600; 0 checks once without waiting.

    .PARAMETER PollIntervalSeconds
    How long to wait between checks, both for the connection to appear and for the approval to take effect.
    Between 1 and 300.

    .EXAMPLE
    ```powershell
    Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId '/subscriptions/{id}/resourceGroups/rg-sales-dev/providers/Microsoft.KeyVault/vaults/kv-sales-dev' -PrivateEndpointNameLike '*kv-sales-dev.vault'
    ```

    Approves a Fabric workspace's managed private endpoint to a Key Vault.

    .EXAMPLE
    ```powershell
    Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId '/subscriptions/{id}/resourceGroups/rg-data/providers/Microsoft.Storage/storageAccounts/stdatalake' -PrivateEndpointNameLike '*mysynapse.datalake-dfs' -Description 'Approved by the data platform deployment'
    ```

    Approves a Synapse workspace's managed private endpoint to a storage account, with a custom message.

    .EXAMPLE
    ```powershell
    Assert-PrivateEndpointConnectionApproval -PrivateLinkResourceId $resourceId -PrivateEndpointNameLike '*kv-sales-dev.vault' -WhatIf
    ```

    Shows what would be approved, without approving anything.

    .NOTES
    This function requires the Az.Network module and an active Azure PowerShell connection. The deploying identity
    needs permission to approve private endpoint connections on the target resource
    (`Microsoft.<provider>/<resourceType>/privateEndpointConnectionsApproval/action`), which is included in the
    Owner and Contributor roles.

    Connections are managed with the Az.Network `Get-AzPrivateEndpointConnection` and
    `Approve-AzPrivateEndpointConnection` cmdlets, so only the resource types those cmdlets support can be used.
    These include Key Vault, Storage, Azure SQL, Cosmos DB, Event Hubs, AI Search and Synapse, but not Azure Data
    Explorer.

    .LINK
    https://learn.microsoft.com/en-us/azure/private-link/manage-private-endpoint
    #>
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
