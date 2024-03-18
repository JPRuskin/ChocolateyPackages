[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf)
)

$LatestRelease = Invoke-RestMethod "https://api.github.com/repos/flipperdevices/qFlipper/releases/latest"
$LatestVersion = $LatestRelease.tag_name.TrimStart('v')

$AvailablePackages = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId'))&includePrerelease=true"

if ($LatestVersion -in $AvailablePackages.properties.version) {
    Write-Host "No update required for '$($PackageId)'"
    return
}

# Grab the filehash for the latest file
$ProgressPreference = "SilentlyContinue"
$File = Invoke-WebRequest -Uri "https://update.flipperzero.one/builds/qFlipper/$($LatestVersion)/qFlipperSetup-64bit-$($LatestVersion).exe"
$Hash = (Get-FileHash -InputStream $File.RawContentStream -Algorithm SHA256).Hash

# Update the install script
$InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1
@{
    "checksum64" = $Hash
}.GetEnumerator().ForEach{
    if ($InstallPs1 -match "^(\s*[`$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']") {
        $InstallPs1 = $InstallPs1 -replace "(\s*[`$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']", "`$1'$($_.Value)'"
    } else {
        Write-Error -Message "$PackageId`: Could not find replacement for '$($_.Key)' in chocolateyInstall.ps1" -ErrorAction Stop
    }
}
$InstallPs1 | Set-Content $PSScriptRoot\tools\chocolateyInstall.ps1

# Package the updated files
choco pack "$($PSScriptRoot)\$($PackageId).nuspec" --version $LatestVersion
