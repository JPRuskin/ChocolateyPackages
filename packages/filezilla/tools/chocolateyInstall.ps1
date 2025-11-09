$ErrorActionPreference = 'Stop'

$packageArgs = @{
  packageName    = 'filezilla'
  fileType       = $fileType
  file           = Get-Item "$PSScriptRoot\FileZilla_*_win32-setup.exe"
  file64         = Get-Item "$PSScriptRoot\FileZilla_*_win64-setup.exe"
  silentArgs     = '/S'
  validExitCodes = @(0, 1223)
  softwareName   = 'FileZilla 3*'
}
Install-ChocolateyInstallPackage @packageArgs

Get-ChildItem $PSScriptRoot\*.exe | ForEach-Object {
  Remove-Item $_ -ErrorAction SilentlyContinue
  if (Test-Path $_) {
    Set-Content -Value "" -Path "$_.ignore"
  }
}