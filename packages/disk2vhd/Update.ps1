[CmdletBinding()]
param(
    [string]$PackageId = (Split-Path $PSScriptRoot -Leaf),

    [string]$Url = "https://download.sysinternals.com/files/Disk2vhd.zip"
)

try {
    $LatestZipPath = Join-Path $env:TEMP "disk2vhd.zip"
    $ExtractionPath = Join-Path $env:TEMP "$(New-Guid)"
    Invoke-WebRequest -Uri $Url -OutFile $LatestZipPath
    Expand-Archive -Path $LatestZipPath -DestinationPath $ExtractionPath

    $LatestVersion = Get-ItemPropertyValue -Path $ExtractionPath/disk2vhd.exe -Name VersionInfo | Select-Object -ExpandProperty ProductVersion
} finally {
    Remove-Item -Path $ExtractionPath -Recurse
}

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
@{
    "url"        = $Url
    "checksum"   = (Get-FileHash -Algorithm SHA256 -Path $LatestZipPath).Hash
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