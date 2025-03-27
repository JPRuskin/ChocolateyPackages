[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf)
)

# We're going to need to use the Nuget Versioning to find the normalized version
Add-Type -AssemblyName $env:ChocolateyInstall\choco.exe

$LatestRelease = Invoke-RestMethod "https://api.github.com/repos/githubnext/monaspace/releases/latest"
$LatestVersion = [Chocolatey.NugetVersionExtensions]::ToNormalizedStringChecked($LatestRelease.tag_name.TrimStart('v'))
$LatestUrl = $LatestRelease.assets.Where{$_.name -eq "monaspace-v$($LatestRelease.tag_name.TrimStart('v')).zip"}.browser_download_url

$AvailablePackages = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId'))&includePrerelease=true"

if ($LatestVersion -in $AvailablePackages.properties.version) {
    Write-Host "No update required for '$($PackageId)'"
    return
} elseif (Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId' and Version eq '$LatestVersion'))&includePrerelease=true") {
    Write-Host "$PackageId $LatestVersion has not yet been approved."
    return
}

$ProgressPreference = "SilentlyContinue"

$SizeOfPackage = [int]"$((Invoke-WebRequest -Uri $LatestUrl -METHOD Head).Headers."Content-Length")"
if ($SizeOfPackage -gt 200MB) {
    # Update the install script
    $InstallPs1 = Get-Content $PSScriptRoot\chocolateyInstallDownload.ps1
    $Replacements = @{
        Url = $LatestUrl
    }

    # Get the file hash for the zip
    $Replacements.checksum = (Get-FileHash -Algorithm SHA256 -InputStream (
        [System.IO.MemoryStream]::New(
        (Invoke-WebRequest $Replacements.Url).Content
        )
    )).Hash

    Remove-Item $PSScriptRoot\tools\LICENSE.txt
    Remove-Item $PSScriptRoot\tools\VERIFICATION.txt
} else {
    # Update the install script
    $InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1

    $Replacements = @{}

    $InstallFile = "$PSScriptRoot\tools\monaspace.zip"
    if (-not (Test-Path $InstallFile)) {
        Invoke-WebRequest -Uri $LatestUrl -OutFile $InstallFile
    }

    $Replacements.checksum = (Get-FileHash $InstallFile -Algorithm SHA256).Hash
}

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