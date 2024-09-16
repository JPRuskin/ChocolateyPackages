[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf)
)

$LatestRelease = (Invoke-RestMethod "https://api.github.com/repos/microsoft/WSL/releases").Where({-not $_.Prerelease}, 1)
$LatestVersion = $LatestRelease.tag_name.TrimStart('v')

$AvailablePackages = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId'))&includePrerelease=true"

if ($LatestVersion -in $AvailablePackages.properties.version) {
    Write-Host "No update required for '$($PackageId)'"
    return
} elseif (Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId' and Version eq '$LatestVersion'))&includePrerelease=true") {
    Write-Host "$PackageId $LatestVersion has not yet been approved."
    return
}

# Update the install script
$InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1
$Replacements = @{
    "url64" = $LatestRelease.assets.Where{$_.name.EndsWith('.x64.msi')}.browser_download_url
}

$Replacements.checksum64 = (Get-FileHash -Algorithm SHA256 -InputStream (
    [System.IO.MemoryStream]::New(
        (Invoke-WebRequest $Replacements.url64).Content
    )
)).Hash

$Replacements.GetEnumerator().ForEach{
    if ($InstallPs1 -match "^(\s*[`$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']") {
        $InstallPs1 = $InstallPs1 -replace "(\s*[`$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']", "`$1'$($_.Value)'"
    } else {
        Write-Error -Message "$PackageId`: Could not find replacement for '$($_.Key)' in chocolateyInstall.ps1" -ErrorAction Stop
    }
}
$InstallPs1 | Set-Content $PSScriptRoot\tools\chocolateyInstall.ps1

# Package the updated files
choco pack "$($PSScriptRoot)\$($PackageId).nuspec" --version $LatestVersion