param(
    $PackageId = (Split-Path $PSScriptRoot -Leaf),

    $DownloadPage = "https://ui.com/download/app/wifiman-desktop"
)

$Result = Invoke-WebRequest $DownloadPage -UseBasicParsing
$URL64 = $Result.Links.Where{$_.href.EndsWith("amd64.exe")}

$LatestVersion = if ($URL64 -and $URL64 -match "wifiman-desktop-(?<Version>[\d\.]+)-amd64\.exe$") {
    $Matches.Version
} else {
    Write-Error "Could not find version from url '$($URL64)' on '$($DownloadPage)'" -ErrorAction Stop
}

# Update the install script
$InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1
$Replacements = @{
    "Url64bit" = $URL64
}

$ProgressPreference = "SilentlyContinue"

$Replacements.Checksum64 = (Get-FileHash -Algorithm SHA256 -InputStream (
        [System.IO.MemoryStream]::New(
        (Invoke-WebRequest $Replacements.Url64bit).Content
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