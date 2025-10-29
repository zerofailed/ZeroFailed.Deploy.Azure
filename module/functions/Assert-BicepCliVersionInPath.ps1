# <copyright file="Assert-BicepCliVersionInPath.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Assert-BicepCliVersionInPath
{
    [CmdletBinding(DefaultParameterSetName='requiredVersion')]
    [OutputType([System.Void])]
    param (
        # '' means any version
        # 'latest' mean the latest version
        # '0.38.33' means the specific version
        [Parameter(ParameterSetName='requiredVersion')]
        [string] $RequiredBicepVersion = '',

        [Parameter(Mandatory, ParameterSetName='minimumVersion')]
        [string] $MinimumBicepVersion,

        [Parameter()]
        [bool] $AllowInstallOrUpgrade = $true
    )

    # Setup wrapper functions to ease mocking of az-cli
    function _getBicepVersion {
        [CmdletBinding()]
        param ()
        & bicep --version
    }
    function _getAzBicepVersion {
        [CmdletBinding()]
        param ()
        & az bicep --version
    }
    function _installAzBicep {
        [CmdletBinding()]
        param (
            [string] $Version
        )
        $PSNativeCommandUseErrorActionPreference = $true
        & az bicep install --version $Version
    }

    Write-Verbose "Bicep version specification: [RequiredVersion='$RequiredBicepVersion'] [MinimumVersion='$MinimumBicepVersion']"

    # Az.PowerShell expects to find the Bicep CLI via the PATH environment variable
    $existingBicepCommand = Get-Command bicep -ErrorAction Ignore
    if ($existingBicepCommand) {
        # Check the version currently installed
        if ($IsWindows) {
            $existingBicepCommandVersion = "{0}.{1}.{2}" -f $existingBicepCommand.Version.Major,
                                                            $existingBicepCommand.Version.Minor,
                                                            $existingBicepCommand.Version.Build
        }
        else {
            $bicepCliVersionOutput = _getBicepVersion
            if ($bicepCliVersionOutput -match "Bicep CLI version (\d+\.\d+\.\d+)") {
                $existingBicepCommandVersion = $matches[1]
            }
        }
        Write-Verbose "Existing installation of Bicep is v$existingBicepCommandVersion"
    }
    
    # Check to see whether we should be using the latest version available
    $latestBicepVersion = (Invoke-RestMethod -Uri https://aka.ms/BicepLatestRelease | Select-Object -ExpandProperty tag_name).TrimStart('v')
    if ($RequiredBicepVersion -eq 'latest') {
        $RequiredBicepVersion = $latestBicepVersion
    }
    
    $requiresInstallOrUpdate = $false
    # Determine if installation or update is needed based on parameter set
    if (-not $existingBicepCommandVersion) {
        # No existing version found - installation required
        $requiresInstallOrUpdate = $true
        if ($PSCmdlet.ParameterSetName -eq 'minimumVersion' -or !$RequiredBicepVersion) {
            $RequiredBicepVersion = $latestBicepVersion
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'requiredVersion') {
        # Check if specific version requirement is met
        if ($RequiredBicepVersion -and $existingBicepCommandVersion -ne $RequiredBicepVersion) {
            $requiresInstallOrUpdate = $true
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'minimumVersion') {
        # Check if minimum version requirement is met
        if ([version]$existingBicepCommandVersion -lt [version]$MinimumBicepVersion) {
            $requiresInstallOrUpdate = $true
            $RequiredBicepVersion = $latestBicepVersion
        }
    }

    if ($requiresInstallOrUpdate) {
        # If the installed version is not what we need, then we:
        #   1) fallback to using the mechanism in the Azure CLI to install Bicep
        #   2) insert that path to the front the PATH environment variable, so it is used ahead of any existing version

        # Check whether Azure CLI has previously installed the required version
        $existingAzCliBicepVersion = _getAzBicepVersion
        Write-Verbose "az bicep version: $existingAzCliBicepVersion"
        if (!$existingAzCliBicepVersion -or $existingAzCliBicepVersion.IndexOf("Bicep CLI version $RequiredBicepVersion") -lt 0) {
            Write-Verbose "Installing Bicep CLI tool via Azure CLI"
            _installAzBicep -Version "v$RequiredBicepVersion" | Out-String | Write-Verbose
            _getAzBicepVersion | Out-String | Write-Verbose
        }

        # Update the PATH to ensure the Azure CLI copy of Bicep CLI is used by Az.PowerShell
        $bicepPath = [IO.Path]::Join($HOME, ".azure", "bin")
        Set-Item -Path env:/PATH -Value (@($bicepPath, $env:PATH) -join [IO.Path]::PathSeparator)
        
        # Verify the install
        Get-Command bicep | Select-Object -ExpandProperty Path | Out-String | Write-Verbose
    }
}