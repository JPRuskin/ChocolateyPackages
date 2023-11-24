$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path $MyInvocation.MyCommand.Definition -Parent

$FontDirectory = (New-Object -ComObject Shell.Application).namespace(0x14).self.path
$FontRegistry = @{
    Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
}

# Remove the fonts
foreach ($Font in Get-ChildItem -Path "$toolsDir/fonts" -Include ('*.otf', '*.ttf') -Recurse) {
    if (Test-Path "$($FontDirectory)\$($Font.Name)") {
        Remove-Item "$($FontDirectory)\$($Font.Name)"
    }
    if (Get-ItemProperty @FontRegistry -Name $Font.BaseName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty @FontRegistry -Name $Font.BaseName
    }
}