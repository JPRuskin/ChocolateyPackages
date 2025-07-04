$PackageArgs = @{
    PackageName    = $env:ChocolateyPackageName
    SoftwareName   = "mouseless*"
    FileType       = "EXE"
    SilentArgs     = @(
        #"/SILENT"
        "/VERYSILENT"
        "/SUPPRESSMSGBOXES"
        "/NOREBOOT"
        "/SP-"
        "/LOG=$($PSScriptRoot)\mouseless-uninstall-log-$(Get-Date -Format FileDateTimeUniversal).log"
    ) -join ' '
    ValidExitCodes = @(0, 3010, 1605, 1614, 1641)
}

if (Get-Process mouseless -ErrorAction SilentlyContinue) {
    Stop-Process mouseless -Force
}

[array]$UninstallKey = Get-UninstallRegistryKey -SoftwareName $PackageArgs.SoftwareName

if ($UninstallKey.Count -eq 1) {
    $UninstallKey | ForEach-Object {
        $PackageArgs['file'] = "$($_.UninstallString)"
        # if ($_.QuietUninstallString) {
        #     $PackageArgs.SilentArgs = $($_.QuietUninstallString -replace "^$([Regex]::Escape($_.UninstallString))").Trim()
        # }
  
        Uninstall-ChocolateyPackage @PackageArgs
    }
} elseif ($UninstallKey.Count -eq 0) {
    Write-Warning "$packageName has already been uninstalled by other means."
} elseif ($UninstallKey.Count -gt 1) {
    Write-Warning "$($UninstallKey.Count) matches found!"
    Write-Warning "To prevent accidental data loss, no programs will be uninstalled."
    Write-Warning "Please alert package maintainer the following keys were matched:"
    $UninstallKey | ForEach-Object {Write-Warning "- $($_.DisplayName)"}
}