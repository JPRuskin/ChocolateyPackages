function GetPrefixValuePath {
    [CmdletBinding()]
    param()
    $thisDir = Split-Path $PSCmdlet.MyInvocation.PSCommandPath -Parent
    Join-Path (Convert-Path $thisDir\..\hook) "prefixvalue.txt"
}

function Get-PrefixValue {
    if (Test-Path (GetPrefixValuePath)) {
        Get-Content -Path (GetPrefixValuePath)
    }
}

function Set-PrefixValue {
    param($Value)
    Set-Content -Path (GetPrefixValuePath) -Value $Value
}

function Get-JenkinsInstallPath {
    $RegistryPath = "HKLM:\SOFTWARE\Jenkins\InstalledProducts\Jenkins"

    if (Test-Path $RegistryPath) {
        Get-ItemPropertyValue -Path $RegistryPath -Name "InstallLocation"
    } else {
        Write-Warning "Jenkins registry keys at '$($RegistryPath)' could not be found."
        "C:\Program Files\Jenkins\"
    }
}