# <copyright file="monitoring.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, an App Insights release annotation will not be created.
$SkipCreateAppInsightsReleaseAnnotation = [Convert]::ToBoolean((property ZF_DEPLOY_SKIP_CREATE_APP_INSIGHTS_RELEASE_ANNOTATION $false))

# Synopsis: Configures the App Insights release annotation to be created.
# This should be a hashtable with the following properties:
# - Name: The name of the release annotation.
# - Properties: A hashtable of properties to include in the annotation.
# - WorkspaceResourceId: The ARM resource ID of the App Insights workspace where the annotation will be created.
# The properties should be a hashtable with key-value pairs representing the properties to include in the annotation.
$AppInsightsReleaseAnnotationDetails = @{
    Name = ''
    Properties = @{}
    WorkspaceResourceId = ''
}
