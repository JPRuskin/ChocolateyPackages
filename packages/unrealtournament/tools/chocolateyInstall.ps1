$ToolsDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
$PackageParameters = Get-PackageParameters

$InstallDir = if ($PackageParameters.InstallDir) {
    $PackageParameters.InstallDir
} else {
    Join-Path $ToolsDir "UnrealTournament"
}

if (-not (Test-Path $InstallDir -PathType Container)) {
    $null = New-Item $InstallDir -ItemType Directory -Force
}

$CD1Arguments = @{
    packageName = "Unreal Tournament"
    url = 'https://archive.org/download/ut-goty/UT_GOTY_CD1.iso'
    checksum = 'E184984CA88F001C5DDD52035D76CD64E266E26C74975161B5ED72366C74704F'
    checksumType = 'SHA256'
    fileFullPath = "$ToolsDir\UT_GOTY_CD1.iso"
}

Get-ChocolateyWebFile @CD1Arguments
Get-ChocolateyUnzip -packageName $CD1Arguments.packageName -fileFullPath $CD1Arguments.fileFullPath -destination $ToolsDir\CD1

foreach ($Folder in @(
    "Help"
    "Maps"
    "Music"
    "Sounds"
    "System"
    "Textures"
    "Web"
)) {
    Move-Item $ToolsDir\CD1\$Folder -Destination $InstallDir
}

if (-not $PackageParameters.SkipHiResTextures) {
    $CD2Arguments = @{
        packageName = "Unreal Tournament"
        url = 'https://archive.org/download/ut-goty/UT_GOTY_CD2.iso'
        checksum = 'D95D8EE1CF95562EE023FD54035EC8813D4275F63D1847423220986EDC8D00D8'
        checksumType = 'SHA256'
        fileFullPath = "$ToolsDir\UT_GOTY_CD2.iso"
    }

    Get-ChocolateyWebFile @CD2Arguments
    Get-ChocolateyUnzip -packageName $CD2Arguments.packageName -fileFullPath $CD2Arguments.fileFullPath -destination $ToolsDir\CD2

    $ChaosUTFiles = @(
        "Textures\chaostex*.utx"
        "Textures\snowdog.utx"
        "Maps\*-CUT_*.unr.uz"
        "System\ChaosUT*"
        "System\UTChaosMap.u"
        "Sounds\chaossounds*.uax"
        "Help\chaosut\*"
    ) | ForEach-Object {
        Convert-Path $ToolsDir\CD2\$_
    }

    $RocketArenaUTFiles = @(
        "Textures\Jezztex*.utx"
        "RA-*.unr.uz"
        "System\RocketArena*"
    ) | ForEach-Object {
        Convert-Path $ToolsDir\CD2\$_
    }

    # Install High Resolution Textures
    Convert-Path $ToolsDir\CD2\Textures\* | Where-Object {
        $_ -notin $ChaosUTFiles + $RocketArenaUTFiles
    } | Move-Item -Destination $InstallDir\Textures -Force
}

# Prevent shimgen creating shims for non-essential EXEs
Get-ChildItem -Path $InstallDir -File -Filter *.exe -Recurse | Where-Object {
    $_.BaseName -notin @("UnrealTournament", "UnrealEd")
} | ForEach-Object {
    $null = New-Item -Path "$($_.FullName).ignore" -ItemType File
}

# Cleanup CD1, CD2, ISOs
Remove-Item $ToolsDir\CD* -Recurse
Remove-Item $ToolsDir\*.iso

####### OldUnreal Upgrade
$OldUnrealPatch = @{
    packageName = "Unreal Tournament (OldUnreal)"
    url = if ($WindowsXP) {
        "https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469e-rc7/OldUnreal-UTPatch469e-WindowsXP-x86.zip"
    } else {
        "https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469e-rc7/OldUnreal-UTPatch469e-Windows-x86.zip"
    }
    checksum = "1BBF2CE385A2810EADFF21543BC983101EBCE1E0FBC41048AD2873B6A42DB533"
    checksumType = "SHA256"
    unzipLocation = Join-Path $ToolsDir "OldUnrealTournament"
}
Install-ChocolateyZipPackage @OldUnrealPatch

# Symlink all remaining files
Set-Location $InstallDir  # UnrealTournament installdir, that is.
foreach ($File in Get-ChildItem -Recurse -File) {
    $RelativePath = Resolve-Path -Path "$([WildcardPattern]::Escape($File.FullName))" -Relative
    $ClonePath = Join-Path "$toolsDir/OldUnrealTournament" $RelativePath
    if (-not (Test-Path ($ParentDirectory = Split-Path $ClonePath -Parent) -PathType Container)) {
        $null = New-Item -Path $ParentDirectory -ItemType Directory -Force
    }
    if (-not (Test-Path $ClonePath)) {
        $null = New-Item -Path $ClonePath -ItemType HardLink -Value "$([WildcardPattern]::Escape($File.FullName))"
    }
}