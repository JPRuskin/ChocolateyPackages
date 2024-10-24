$ErrorActionPreference = 'Stop'

$packageArgs = @{
  PackageName    = $env:ChocolateyPackageName
  SoftwareName   = "WiFiman Desktop"
  SilentArgs     = "/S"
  FileType       = "EXE"
  ValidExitCodes = @(0)
  Url64bit       = ""
  Checksum64     = ""
  ChecksumType64 = "sha256"
}

# Check if the installed version matches the product version
if (
    ($Installed = Get-UninstallRegistryKey -softwareName $packageArgs.SoftwareName -WarningAction SilentlyContinue) -and
    $Installed.DisplayVersion -eq $env:ChocolateyPackageVersion
) {
  Write-Host "Version '$($Installed.DisplayVersion)' is already installed in '$(Split-Path $Installed.InstallLocation)'. No action required."
  return
}

Install-ChocolateyPackage @packageArgs
