$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path $MyInvocation.MyCommand.Definition -Parent

$packageArgs = @{
    PackageName    = $env:ChocolateyPackageName
    FileFullPath   = Join-Path $toolsDir "monaspace.zip"
    Destination    = "$toolsDir/fonts"
    Checksum       = '3E08376FD0AECA1F851FDE0C08E18CA2D797F6A4C7A449670BF4D1270303C8F6'
    ChecksumType   = 'sha256'
}

Get-ChocolateyUnzip @packageArgs

$FontDirectory = (New-Object -ComObject Shell.Application).namespace(0x14).self.path

foreach ($Font in Get-ChildItem -Path "$toolsDir/fonts" -Include ('*.otf', '*.ttf') -Recurse) {
    Write-Verbose "Installing Font - $($Font.BaseName)"
    Copy-Item -Path $Font.FullName -Destination $FontDirectory

    # Register font for all users
    $FontRegistryEntry = @{
        Name         = $Font.BaseName
        Path         = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        PropertyType = "String"
        Value        = $Font.Name
    }
    if (-not (Get-ItemProperty -Path $FontRegistryEntry.Path -Name $FontRegistryEntry.Name -ErrorAction SilentlyContinue)) {
        $null = New-ItemProperty @FontRegistryEntry
    }
}
