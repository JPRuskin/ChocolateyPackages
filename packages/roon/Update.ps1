[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf)
)
$URL64 = "https://download.roonlabs.net/builds/RoonInstaller64.exe"
$LastUpdated = [DateTime]::Parse((Invoke-WebRequest -Uri $URL64 -Method HEAD).Headers.'Last-Modified')

$AvailablePackages = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId'))&includePrerelease=true"
$PackageUpdates = $AvailablePackages | ForEach-Object {[DateTime]::Parse($_.updated)}

if ($PackageUpdates -gt $LastUpdated) {
    Write-Host "No update required for '$($PackageId)'"
    return
} <#elseif (Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId' and Version eq '$LatestVersion'))&includePrerelease=true") {
    Write-Host "$PackageId $LatestVersion has not yet been approved."
    return
}#>

# Update the install script
$InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1
$Replacements = @{
    "Url64bit" = $URL64
}

$ProgressPreference = "SilentlyContinue"
$Zip = (Invoke-WebRequest $Replacements.Url64bit).Content

$Replacements.Checksum64 = (Get-FileHash -Algorithm SHA256 -InputStream (
        [System.IO.MemoryStream]::New(
            $Zip
        )
    )).Hash

$LatestVersion = 

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