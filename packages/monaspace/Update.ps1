[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf)
)

# We're going to need to use the Nuget Versioning to find the normalized version
Add-Type -AssemblyName $env:ChocolateyInstall\choco.exe

$LatestRelease = Invoke-RestMethod "https://api.github.com/repos/githubnext/monaspace/releases/latest"
$LatestVersion = [Chocolatey.NugetVersionExtensions]::ToNormalizedStringChecked($LatestRelease.tag_name.TrimStart('v'))

$AvailablePackages = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId'))&includePrerelease=true"

if ($LatestVersion -in $AvailablePackages.properties.version) {
    Write-Host "No update required for '$($PackageId)'"
    return
}

$ProgressPreference = "SilentlyContinue"
$InstallFile = "$PSScriptRoot\tools\monaspace.zip"
if (-not (Test-Path $InstallFile)) {
    Invoke-WebRequest -Uri $LatestRelease.assets.Where{$_.name -eq "monaspace-v$($LatestVersion).zip"}.browser_download_url -OutFile $InstallFile
}

# Update the install script
$InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1
$Replacements = @{}

# Get the file hash for the zip
$Replacements.checksum = (Get-FileHash $InstallFile -Algorithm SHA256).Hash

# Handle replacements
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