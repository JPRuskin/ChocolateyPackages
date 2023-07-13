$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  FileFullPath  = Join-Path $toolsDir "cloudflared.exe"

  url           = 'https://github.com/cloudflare/cloudflared/releases/download/2023.7.0/cloudflared-windows-386.exe'
  url64bit      = 'https://github.com/cloudflare/cloudflared/releases/download/2023.7.0/cloudflared-windows-amd64.exe'

  checksum      = '6dba2c4b43af7302cfdbae791a47e885dbbb366f01842e5aea13a24fbdb5f552'
  checksumType  = 'sha256'
  checksum64    = '3cf5585fb3b00e6b01d562c86fb63bac96ae003eed610aacb8ca1bebc1390969'
  checksumType64= 'sha256'
}

Get-ChocolateyWebFile @packageArgs