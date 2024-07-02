$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

$downloadArgs = @{
    packageName    = $env:ChocolateyPackageName
    FileFullPath   = Join-Path $toolsDir "neonmodem.tar.gz"

    url            = "https://github.com/mrusme/neonmodem/releases/download/v$($env:ChocolateyPackageVersion)/neonmodem_$($env:ChocolateyPackageVersion)_windows_386.tar.gz"
    url64bit       = "https://github.com/mrusme/neonmodem/releases/download/v$($env:ChocolateyPackageVersion)/neonmodem_$($env:ChocolateyPackageVersion)_windows_amd64.tar.gz"

    checksum       = '17c6cf342d8d6551d05fc3349730d4173c59e838661d4a5fec8d0879326cc5ec'
    checksumType   = 'sha256'
    checksum64     = '07270d4b79e564cababa9555c16dbabf21eae4865ccb8f228779d6cc52258385'
    checksumType64 = 'sha256'
}

# Download the file, if necessary
Get-ChocolateyWebFile @downloadArgs

# Extract the tar.gz
Get-ChocolateyUnzip @downloadArgs -Destination $toolsDir
Get-ChocolateyUnzip -File $toolsDir\neonmodem.tar -Destination $toolsDir

# Tidy up archives
Get-ChildItem -Path $toolsDir -Filter "neonmodem.tar*" | Remove-Item
