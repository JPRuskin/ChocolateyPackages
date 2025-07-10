$ErrorActionPreference = 'Stop'

$packageArgs = @{
  PackageName    = $env:ChocolateyPackageName
  SoftwareName   = "Qobuz*"
  SilentArgs     = "-s"
  FileType       = "EXE"
  ValidExitCodes = @(0)
  Url64bit       = ""
  Checksum64     = ""
  ChecksumType64 = "sha256"
}

# Check if the installed version matches the product version
$DisplayVersion = ""
if (($Installed = Get-UninstallRegistryKey -softwareName 'Qobuz*' -WarningAction SilentlyContinue) -and $Installed.DisplayVersion -eq $DisplayVersion) {
  Write-Host "Version '$($Installed.DisplayVersion)' is already installed in '$(Split-Path $Installed.DisplayIcon)'. No action required."
  return
}

Install-ChocolateyPackage @packageArgs
