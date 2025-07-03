$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path $MyInvocation.MyCommand.Definition -Parent

$packageArgs = @{
    PackageName  = $env:ChocolateyPackageName
    Url          = ""
    Destination  = "$toolsDir/fonts"
    Checksum     = ""
    ChecksumType = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

$FontDirectory = (New-Object -ComObject Shell.Application).namespace(0x14).self.path

foreach ($Font in Get-ChildItem -Path "$toolsDir/fonts" -Include ('*.otf', '*.ttf') -Recurse) {
    Write-Verbose "Installing Font - $($Font.BaseName)"
    Copy-Item -Path $Font.FullName -Destination $FontDirectory

    # Register font for all users
    $FontRegistryEntry = @{
        Name         = $Font.BaseName
        Path         = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts\"
        Value        = $Font.Name
    }
    $null = Set-ItemProperty @FontRegistryEntry

    # We leave the installed fonts in the tools directory so we can clean up later, but don't need the file content
    Set-Content -LiteralPath $Font.PSPath -Value $null
}

# Cleanup Unrequired Files
Get-Item $toolsDir/fonts/monaspace-*/docs | Remove-Item -Recurse
Get-Item $toolsDir/fonts/monaspace-*/fonts/webfonts | Remove-Item -Recurse