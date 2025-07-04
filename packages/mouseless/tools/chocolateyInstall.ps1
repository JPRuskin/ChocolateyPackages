[CmdletBinding()]
param(
    # Chooses to install the application system-wide or at a user level.
    [Parameter()]
    [ValidateSet("AllUsers", "CurrentUser")]
    [string]$InstallTo = "AllUsers"
)

$packageArgs = @{
    packageName  = $env:ChocolateyPackageName
    fileType     = "exe"
    url          = "$PSScriptRoot/mouseless-installer_v0.4.0-windows_beta.2.exe" #"https://github.com/croian/mouseless/releases/download/v0.4.0-windows_beta.2/mouseless-installer_v0.4.0-windows_beta.2.exe"
    checksum     = "4A74EBB7D658B6B6CECC2776F25B1A58133BF47C4D6805E0692AD0D20C5722DB"
    checksumType = "SHA256"
    silentArgs   = @(  # For further instructions, run mouseless-installer.exe /help
        "/VERYSILENT"  # Instructs Setup to be very silent.
        "/$($InstallTo)"  # Instructs Setup to install in administrative/non-administrative install mode.
        "/SUPPRESSMSGBOXES"  # Instructs Setup to suppress message boxes.
        "/FORCECLOSEAPPLICATIONS"  # Instructs Setup to close applications using files that need to be updated.
        "/RESTARTAPPLICATIONS"  # Instructs Setup to restart applications.
        "/NORESTART"  # Prevents Setup from restarting the system following a successful installation, or after a Preparing to Install failure that requests a restart.
        "/RESTARTEXITCODE=3010"  # Specifies a custom exit code that Setup is to return when the system needs to be restarted.
        "/LOG=$($PSScriptRoot)\mouseless-install-log-$(Get-Date -Format FileDateTimeUniversal).log"
    ) -join ' '
}

try {
    Install-ChocolateyPackage @packageArgs
} finally {
    Write-Verbose "A log was written to $($packageArgs.silentArgs[-1])"
}