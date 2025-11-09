[CmdletBinding()]
param(
    $PackageId = 'filezilla',

    [ValidateSet('chrome', 'firefox', 'edge')]
    $Browser = 'firefox',

    $ReleasePage = 'https://filezilla-project.org/download.php?show_all=1'
)
begin {
    # choco upgrade @{
    #     "chrome"  = "googlechrome"
    #     "firefox" = "firefox"
    #     "edge"    = "microsoft-edge"
    # }.$Browser --confirm
    if (-not (Get-Module Selenium -ListAvailable | Where-Object Version -ge 4.0.0)) {
        & ([scriptblock]::Create((Invoke-WebRequest 'bit.ly/modulefast'))) -Specification Selenium! -NoProfileUpdate
    }
}
end {
    $Driver = Start-SeDriver -Browser $Browser -StartURL $ReleasePage -State Headless -DefaultDownloadPath $PSScriptRoot\tools
    $Url64 = ($E64 = Get-SeElement -By PartialLinkText "_win64-setup.exe").GetAttribute("href")
    $Url32 = ($E32 = Get-SeElement -By PartialLinkText "_win32-setup.exe").GetAttribute("href")

    if (-not (($LatestVersion = ([uri]$Url32).LocalPath.Split('_')[-2]) -as [version])) {
        throw "$($PackageId): Could not parse latest version from URL: $($Url32)"
    }

    $AvailablePackages = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages()?`$filter=((Id eq '$PackageId'))&includePrerelease=true"

    if ($LatestVersion -in $AvailablePackages.properties.version) {
        Write-Host "No update required for '$($PackageId)'"
        return
    } elseif (
        $(try {($SpecificResult = Invoke-RestMethod "https://community.chocolatey.org/api/v2/Packages(Id='$PackageId',Version='$LatestVersion')")} catch {}) -and
        $SpecificResult.entry.properties.PackageStatus -ne 'Approved'
    ) {
        Write-Host "$($PackageId) $($LatestVersion) has been submitted but not yet been approved."
        # TODO: Consider outputting review comments here.
        return
    }

    $Latest32Path = "$PSScriptRoot\tools\FileZilla_$($LatestVersion)_win32-setup.exe"
    $Latest64Path = "$PSScriptRoot\tools\FileZilla_$($LatestVersion)_win64-setup.exe"

    # Download the latest installers
    Remove-Item $PSScriptRoot\tools\FileZilla_*.exe -ErrorAction SilentlyContinue
    if (-not (Test-Path $Latest32Path)) {
        $E32.Click()  # Set-SeUrl -Url $Url32  # Invoke-WebRequest -Uri $Url32 -OutFile "$PSScriptRoot\tools\FileZilla_$($LatestVersion)_x32.exe"
    }
    if (-not (Test-Path $Latest64Path)) {
        $E64.Click()  # Set-SeUrl -Url $Url64  # Invoke-WebRequest -Uri $Url64 -OutFile "$PSScriptRoot\tools\FileZilla_$($LatestVersion)_x64.exe"
    }

    # Update the verification file
    $VerificationFile = Get-Content $PSScriptRoot\legal\VERIFICATION.txt
    @{
        "x32"        = $Url32
        "x64"        = $Url64
        "checksum32" = (Get-FileHash -Algorithm SHA512 -Path $Latest32Path).Hash
        "checksum64" = (Get-FileHash -Algorithm SHA512 -Path $Latest64Path).Hash
    }.GetEnumerator().ForEach{
        if ($VerificationFile -match "^(\s*[`$`"']?$($_.Key)[`"']?\s*:\s*)[`"']?.*[`"']?") {
            $VerificationFile = $VerificationFile -replace "(\s*[`$`"']?$($_.Key)[`"']?\s*:\s*)[`"']?.*[`"']?", "`$1$($_.Value)"
        } else {
            Write-Error -Message "$PackageId`: Could not find replacement for '$($_.Key)' in VERIFICATION.txt" -ErrorAction Stop
        }
    }
    $VerificationFile | Set-Content $PSScriptRoot\legal\VERIFICATION.txt

    choco pack "$($PSScriptRoot)\$($PackageId).nuspec" --version $LatestVersion
}
clean {
    $Driver.Quit()
    $Driver.Dispose()
}