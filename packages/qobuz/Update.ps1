[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf)
)

$DownloadPage = Invoke-WebRequest -UseBasicParsing -Uri 'https://www.qobuz.com/gb-en/discover/apps-qobuz'
$URL64 = $DownloadPage.Links.Where({$_.href.EndsWith('Qobuz_Installer.exe')}, 1).href

$DisplayVersion = $URL64 -replace '^(?:.+\/)(?<Version>[A-z0-9\-\.]+)(?:\/Qobuz_Installer\.exe$)', '${Version}'
$LatestVersion = $DisplayVersion -replace "-.+$"

# This may not be accurate over time. If there are multiple revisions found (and we care), we should change this.

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
    "Url64bit"       = $URL64
    "DisplayVersion" = $DisplayVersion
}

$ProgressPreference = "SilentlyContinue"

$Replacements.Checksum64 = (Get-FileHash -Algorithm SHA256 -InputStream (
        [System.IO.MemoryStream]::New(
        (Invoke-WebRequest $Replacements.url64bit).Content
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