$ErrorActionPreference = "Stop"

$HookDir = Convert-Path (Join-Path (Split-Path $MyInvocation.MyCommand.Definition -Parent) "..\hook\")
Import-Module $HookDir\functions.psm1

# If a parameter is provided, set a file to ensure we don't lose the prefix we intend to use
$Params = Get-PackageParameters

$Prefix = if ($Params.ContainsKey("Prefix")) {
    $Params["Prefix"]
} elseif ($Existing = Get-PrefixValue) {
    $Existing
} else {
    "jenkins"
}

Set-PrefixValue -Value $Prefix.TrimStart("/")

if (-not $Params.InstallOnly) {
    try {
        . $HookDir\post-install-jenkins.ps1
    } catch {
        # We may be installing this package before Jenkins is installed
    }
}