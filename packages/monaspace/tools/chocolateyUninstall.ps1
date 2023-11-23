$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path $MyInvocation.MyCommand.Definition -Parent

$FontRegistry = @{
    Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
}

# Remove the fonts
foreach ($Font in Get-ChildItem -Path "$toolsDir/fonts" -Include ('*.otf', '*.ttf') -Recurse) {
    if (Test-Path "C:\Windows\Fonts\$($Font.Name)") {
        Remove-Item "C:\Windows\Fonts\$($Font.Name)"
    }
    if (Get-ItemProperty @FontRegistry -Name $Font.BaseName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty @FontRegistry -Name $Font.BaseName
    }
}