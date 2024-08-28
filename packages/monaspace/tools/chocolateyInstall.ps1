$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path $MyInvocation.MyCommand.Definition -Parent

$packageArgs = @{
    PackageName    = $env:ChocolateyPackageName
    FileFullPath   = Join-Path $toolsDir "monaspace.zip"
    Destination    = "$toolsDir/fonts"
    Checksum       = '7FF2317C7BDAED8E81DCBE1314E6AB12AD9641B7DDF921E996A227FF4EC7752F'
    ChecksumType   = 'sha256'
}

Get-ChocolateyUnzip @packageArgs

$FontDirectory = (New-Object -ComObject Shell.Application).namespace(0x14).self.path
$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts\'
$RegisteredFonts = Get-ItemProperty -path $RegistryPath

foreach ($Font in Get-ChildItem -Path "$toolsDir/fonts" -Include ('*.otf', '*.ttf') -Recurse) {
    Write-Verbose "Installing Font - $($Font.BaseName)"
    Copy-Item -Path $Font.FullName -Destination $FontDirectory

    # Register font for all users
    $FontRegistryEntry = @{
        Name         = $Font.BaseName
        Path         = $RegistryPath
        PropertyType = "String"
        Value        = $Font.Name
    }
    if (-not (Get-Member -InputObject $RegisteredFonts | ? Name -eq $FontRegistryEntry.Name)) {
        Write-Host $FontRegistryEntry.Name
        Get-Member -InputObject $RegisteredFonts | ? Name -eq $FontRegistryEntry.Name
        Get-ItemProperty -Path $FontRegistryEntry.Path -Name $FontRegistryEntry.Name -ErrorAction SilentlyContinue
        $null = New-ItemProperty @FontRegistryEntry
    }
}
