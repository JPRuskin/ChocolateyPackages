$ErrorActionPreference = 'Stop'

# Tools directory
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# Stop the cloudflared service if it is running
$serviceName = 'cloudflared'
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -eq 'Running') {
        Write-Output "Stopping service '$serviceName'"
        Stop-Service -Name $serviceName
    }
}

# Package parameters
$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    FileFullPath   = Join-Path $toolsDir "cloudflared.exe"

    url            = 'https://github.com/cloudflare/cloudflared/releases/download/$version$/cloudflared-windows-386.exe'
    url64bit       = 'https://github.com/cloudflare/cloudflared/releases/download/$version$/cloudflared-windows-amd64.exe'

    checksum       = '6dba2c4b43af7302cfdbae791a47e885dbbb366f01842e5aea13a24fbdb5f552'
    checksumType   = 'sha256'
    checksum64     = '3cf5585fb3b00e6b01d562c86fb63bac96ae003eed610aacb8ca1bebc1390969'
    checksumType64 = 'sha256'
}

# Download cloudflared.exe
Get-ChocolateyWebFile @packageArgs

# If the service was previously running, start it again
if ($service) {
    if ($service.Status -eq 'Running') {
        Write-Output "Starting service '$serviceName'"
        Start-Service -Name $serviceName
    }
}