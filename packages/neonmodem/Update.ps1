[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf)
)

# We're going to need to use the Nuget Versioning to find the normalized version
Add-Type -AssemblyName $env:ChocolateyInstall\choco.exe

$LatestRelease = Invoke-RestMethod "https://api.github.com/repos/mrusme/neonmodem/releases/latest"
$LatestVersion = [Chocolatey.NugetVersionExtensions]::ToNormalizedStringChecked($LatestRelease.tag_name.TrimStart('v'))

$AvailablePackages = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId'))&includePrerelease=true"

if ($LatestVersion -in $AvailablePackages.properties.version) {
    Write-Host "No update required for '$($PackageId)'"
    return
} elseif (Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId' and Version eq '$LatestVersion'))&includePrerelease=true") {
    Write-Host "$PackageId $LatestVersion has not yet been approved."
    return
}

$ProgressPreference = "SilentlyContinue"
$File = "$PSScriptRoot\tools\neonmodem.tar.gz"
if (-not (Test-Path $File)) {
    Invoke-WebRequest -Uri $LatestRelease.assets.Where{$_.name -eq "neonmodem_$($LatestRelease.tag_name.TrimStart('v'))_windows_amd64.tar.gz"}.browser_download_url -OutFile $File
}

$Replacements = @{}

# Get the file hash for the files
$Checksums = -join[char[]](Invoke-WebRequest -Uri $LatestRelease.assets.Where{$_.name -eq "neonmodem_$($LatestRelease.tag_name.TrimStart('v'))_checksums.txt"}.browser_download_url).Content
$Replacements.checksum = ($Checksums -split "`n" -match '_windows_386.tar.gz$' -split ' ')[0]
$Replacements.checksum64 = ($Checksums -split "`n" -match '_windows_amd64.tar.gz$' -split ' ')[0]

# Update the install script
$InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1

# Handle replacements
$Replacements.GetEnumerator().ForEach{
    if ($InstallPs1 -match "^(\s*[`$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']") {
        $InstallPs1 = $InstallPs1 -replace "(\s*[`$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']", "`$1'$($_.Value)'"
    } else {
        Write-Error -Message "$PackageId`: Could not find replacement for '$($_.Key)' in chocolateyInstall.ps1" -ErrorAction Stop
    }
}
$InstallPs1 | Set-Content $PSScriptRoot\tools\chocolateyInstall.ps1

# Update the verification file
$Verification = Get-Content $PSScriptRoot\legal\VERIFICATION

# Handle replacements
$Replacements.GetEnumerator().ForEach{
    if ($Verification -match "^(\s*[`$`"']?$($_.Key)[`"']?\s*:\s*)[`"']?.*[`"']?") {
        $Verification = $Verification -replace "(\s*[`$`"']?$($_.Key)[`"']?\s*:\s*)[`"']?.*[`"']?", "`$1'$($_.Value)'"
    } else {
        Write-Error -Message "$PackageId`: Could not find replacement for '$($_.Key)' in VERIFICATION" -ErrorAction Stop
    }
}
$Verification | Set-Content $PSScriptRoot\legal\VERIFICATION

# Package the updated files
choco pack "$($PSScriptRoot)\$($PackageId).nuspec" --version $LatestVersion