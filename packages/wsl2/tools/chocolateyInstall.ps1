$ErrorActionPreference = 'Stop'

$wslVersion = 2
$retryInstall = $false

$pp = Get-PackageParameters
if ([int]$pp.Version -in (1, 2)) { $wslVersion = $pp.Version }
if ($pp.Retry -eq $true) { $retryInstall = $true }

$packageArgs = @{
    packageName    = 'wsl2'
    softwareName   = 'Windows Subsystem for Linux'
    Version        = $wslVersion
    Retry          = $retryInstall
    checksum64     = '4d09c776c8d45f70a202281d18e19be1118f53159b0c217a5274a31ce18525fe'
    checksumType   = 'sha256'
    url64          = 'https://github.com/microsoft/WSL/releases/download/$($env:ChocolateyPackageVersion)/wsl.$($env:ChocolateyPackageVersion).0.x64.msi'
    fileType       = 'msi'
    silentArgs     = '/quiet /qn /norestart'
    validExitCodes = @(0, 3010, 1641)
}

# https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem?redirectedfrom=MSDN
enum OSType {
    WorkStation = 1
    DomainController = 2
    Server = 3
}

$OSVersionInfo = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion")
$OSMajorVersion = $OSVersionInfo.CurrentMajorVersionNumber
$OSMajorBuildNumber = $OSVersionInfo.CurrentBuildNumber
$OSMinorBuildNumber = $OSVersionInfo.UBR
$OSReleaseId = $OSVersionInfo.ReleaseId
$OSProductType = (Get-CimInstance -Class Win32_OperatingSystem).ProductType

function Enable-WSL() {
    & dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
}

function Write-NotSupportedError() {
    Write-Error "WSL is not supported on windows $OSMajorVersion release $OSReleaseId build $OSMajorBuildNumber.$OSMinorBuildNumber.
See https://docs.microsoft.com/en-us/windows/wsl/ for more info."
    exit 1
}

if ($OSMajorVersion -ne 10) { Write-NotSupportedError }

# https://docs.microsoft.com/en-us/windows/wsl/install-win10
if ($packageArgs.Version -eq 1 ) {
    if (($OSProductType -eq [OSType]::WorkStation -and $OSMajorBuildNumber -ge 14393) -or
        ($OSProductType -eq [OSType]::Server -and $OSMajorBuildNumber -ge 16299)) {

        Enable-WSL
        Write-Host 'Reboot to finish installing WSL'
    } else {
        Write-NotSupportedError
    }
} elseif ($packageArgs.Version -eq 2 -and
($OSProductType -eq [OSType]::WorkStation -and
    (($OSMajorBuildNumber -in (18362, 18363) -and $OSMinorBuildNumber -ge 1049) -or
        ($OSMajorBuildNumber -ge 19041))) -or
($OSProductType -eq [OSType]::Server -and
    (($OSMajorBuildNumber -eq 20348 -and $OSMinorBuildNumber -ge 768) -or
        ($OSMajorBuildNumber -ge 20348)))) {
    # https://docs.microsoft.com/en-us/windows/wsl/install-win10#update-to-wsl-2
    # https://devblogs.microsoft.com/commandline/wsl-2-support-is-coming-to-windows-10-versions-1903-and-1909/
    # https://devblogs.microsoft.com/commandline/wsl-2-distros-are-now-supported-on-windows-server/
    Enable-WSL
    $null = & dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

    $wslInstalled = $false
    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        $wslInstalled = $true
    }

    if (!$wslInstalled) {
        if ($packageArgs.Retry) {
            & schtasks.exe /create /f /tn WSL2RestartTask /sc ONLOGON /rl HIGHEST /tr "powershell.exe -NoExit -Command 'choco install wsl2 -y -f; schtasks.exe /delete /f /tn WSL2RestartTask'"
            return
        } else {
            Write-Warning 'WSL not detected! Reboot PC then install this package again to enable WSL 2'
            return
        }
    }

    Install-ChocolateyPackage @packageArgs
    & wsl.exe --set-default-version 2
} else {
    Write-NotSupportedError
}