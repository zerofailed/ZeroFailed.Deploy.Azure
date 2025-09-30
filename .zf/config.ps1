# Extensions setup
$zerofailedExtensions = @(
    @{
        Name = "ZeroFailed.Build.PowerShell"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.PowerShell.git"
        GitRef = "main"
    }
)

# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

# Set the required build options
$PesterTestsDir = "$here/module"
$PesterCodeCoveragePaths = @("$PesterTestsDir/functions")
$PowerShellModulesToPublish = @(
    @{
        ModulePath = "$here/module/ZeroFailed.Deploy.Azure.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @()
    }
)
$PSMarkdownDocsOutputPath = 'docs/functions'
$PSMarkdownDocsFlattenOutputPath = $true
$PSMarkdownDocsIncludeModulePage = $false

# Customise the build process
task . FullBuild

#
# Build Process Extensibility Points - uncomment and implement as required
#

# task RunFirst {}
# task PreInit {}
# task PostInit {}
# task PreVersion {}
# task PostVersion {}
# task PreBuild {}
# task PostBuild {}
# task PreTest {}
# task PostTest {}
# task PreTestReport {}
# task PostTestReport {}
# task PreAnalysis {}
# task PostAnalysis {}
# task PrePackage {}
# task PostPackage {}
# task PrePublish {}
# task PostPublish {}
# task RunLast {}
