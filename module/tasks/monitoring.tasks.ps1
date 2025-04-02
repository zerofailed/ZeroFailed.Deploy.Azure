# <copyright file="monitoring.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/monitoring.properties.ps1

# Synopsis: Create an App Insights release annotation
task createAppInsightsReleaseAnnotation -If { !$SkipCreateAppInsightsReleaseAnnotation } `
                                        -After DeployCore `
                                        -Before PostDeploy {

    # Required configuration object:
    # @{
    #     Name = ''
    #     Properties = @{}
    #     WorkspaceResourceId = ''
    # }
    $configIsValid = $AppInsightsReleaseAnnotationDetails.Name -and $AppInsightsReleaseAnnotationDetails.WorkspaceResourceId

    if ($configIsValid) {
        Write-Build Green "Creating App Insights release annotation..."
    
        $annotation = @{         
            Id             = [Guid]::NewGuid()
            AnnotationName = $AppInsightsReleaseAnnotationDetails.Name
            EventTime      = (Get-Date).ToUniversalTime().GetDateTimeFormats("s")[0]
            Category       = "Deployment"
            Properties     = ConvertTo-Json $AppInsightsReleaseAnnotationDetails.Properties -Compress
        }        
        $annotation = ConvertTo-Json $annotation -Compress
        $annotation = Convert-UnicodeToEscapeHex -JsonString $annotation
        $uri = "https://management.azure.com{0}/Annotations?api-version=2020-02-02" -f $AppInsightsReleaseAnnotationDetails.WorkspaceResourceId
    
        Invoke-AzRestMethod -Method PUT -Uri $uri -Payload $annotation | Out-Null
    }
    else {
        Write-Warning "Skipping App Insights release annotation, due to invalid configuration. 'AppInsightsReleaseAnnotationDetails' must contain at least the 'Name' and 'WorkspaceResourceId' properties."
    }
}
