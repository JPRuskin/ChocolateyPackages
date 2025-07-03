$ErrorActionPreference = 'Stop'

$InstallParameters = @{
  PackageName    = $env:ChocolateyPackageName
  SoftwareName   = "Roon*"
  SilentArgs     = "/S"
  FileType       = "EXE"
  ValidExitCodes = @(0)
  Url64bit       = "https://download.roonlabs.net/builds/RoonInstaller64.exe"
  Checksum64     = "909B1E2C12D3D5AA160CD8C29E8A3086B91F7B6394E0DA4DF47DC34A0B9F8AF1"
  ChecksumType64 = "sha256"
}

Install-ChocolateyPackage @InstallParameters