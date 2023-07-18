function Test-DebugRequest {
    # We need to use $env:ChocolateyPackageParameters because Get-PackageParameters is not available here
    [bool]($env:ChocoPackageDebug) -or $env:ChocolateyPackageParameters -match '/Debug[:=]?["'']?(?<Value>.+)?["'']?\b'
    if ($Matches.Value) {$env:ChocoPackageDebug = $Matches.Value}
}

if (Test-DebugRequest) {
    $Breakpoint = switch -Regex ($env:ChocoPackageDebug) {
        "^(Line[:=]?)?\d+$" { @{Line = $env:ChocoPackageDebug -replace '^(Line[:=]?)?'} }
        "^Prehook$" { @{Line = 54} }  # This waits before evaluating Prehook scripts
        "^Package$" { @{Line = 61} }  # This waits before evaluating Package scripts
        "^Posthook$" { @{Line = 89} }  # This waits before evaluating Posthook scripts
        default { @{Line = 63} }  # This waits at the start of Package scripts
        "^Debug$" {
            @{Line = 1}  # This is for debugging the extension.
            Wait-Debugger
        }
    }

    Set-PSBreakpoint -Script $env:ChocolateyInstall\helpers\chocolateyScriptRunner.ps1 @Breakpoint -Action {
        Write-Host "Now waiting for debug connection..."
        Write-Host "This is PID '$($PID)', in runspace '$([System.Management.Automation.Runspaces.Runspace]::DefaultRunSpace.Id)'"

        Wait-Debugger
    }
}