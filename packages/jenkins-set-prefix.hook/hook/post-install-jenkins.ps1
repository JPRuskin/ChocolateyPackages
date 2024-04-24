$HookDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
Import-Module $HookDir\functions.psm1

$Prefix = Get-PrefixValue

# Get the path to the XML config file
$XmlPath = Join-Path (Get-JenkinsInstallPath) "Jenkins.xml"

# If it's missing or different, add the prefix to the config arguments
if (Test-Path $XmlPath) {
    [xml]$JenkinsXml = Get-Content $XmlPath

    if ($JenkinsXml.SelectSingleNode("/service/arguments")."#text" -notmatch "--prefix=/$Prefix") {
        $JenkinsXml.SelectSingleNode("/service/arguments")."#text" = $JenkinsXml.SelectSingleNode("/service/arguments")."#text" -replace "\s*--prefix=/.+?\b", ""
        $JenkinsXml.SelectSingleNode("/service/arguments")."#text" += " --prefix=/$Prefix"
        $JenkinsXml.Save($XmlPath)
    }
} else {
    Write-Error "Could not find '$XmlPath'"
}

Restart-Service Jenkins