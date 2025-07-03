param(
    # A specific Chocolatey version that provides PackageParam functionality
    $OverrideParamsBeforeVersion = "2.5"
)

$ScriptRunnerFile = Join-Path $env:ChocolateyInstall 'helpers\chocolateyScriptRunner.ps1'
if (
    # If our version of Chocolatey supports Package Params
    [version]$env:CHOCOLATEY_VERSION -lt $OverrideParamsBeforeVersion -or
    # and the command doesn't already exist in this runspace
    (Get-Command Get-PackageScriptParameters -Module chocolateyInstaller -CommandType Cmdlet) -and
    # and some parameters have been passed...
    -not [string]::IsNullOrWhiteSpace(@("$env:ChocolateyPackageParameters", "$env:ChocolateyPackageParametersSensitive"))
) {
    # This function is roughly replicated from the Chocolatey Helpers.
    # We don't want to override it unless we need to, in case of updates.
    function Get-PackageScriptParameters {
        <#
            .SYNOPSIS
            Returns a splattable hashtable of arguments for a script,
            from current package parameters.
            .DESCRIPTION
            This parses a script file for the existing params available and then
            compares them to the package parameters provided.
            If it finds matching names, it outputs them in a splattable hashtable
            for use by the script.
            .NOTES
            Currently, this function ignores parameter aliases.
            .OUTPUTS
            [HashTable]
            .PARAMETER ScriptPath
            The path to the script to parse.
            .PARAMETER Parameters
            OPTIONAL - A parameter string to pass to Get-PackageParameters.
            .PARAMETER IgnoredArguments
            Allows splatting with arguments that do not apply and future expansion.
            Do not use directly.
            .EXAMPLE
            >
            # The default way of calling, uses the parameter environment variables
            # if available.
            $scriptParameters = Get-ScriptParameters -ScriptPath $packageScript
            .LINK
            Get-PackageParameters
        #>
        [OutputType([HashTable])]
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$ScriptPath,
    
            [Parameter()]
            [string]$Parameters = '',
    
            [parameter(ValueFromRemainingArguments = $true)][Object[]] $IgnoredArguments
        )
        Write-FunctionCallLogMessage -Invocation $MyInvocation -Parameters $PSBoundParameters
    
        $packageParameters = Get-PackageParameters -Parameters $Parameters
        $splatHash = @{}
    
        # Check what parameters the script has
        $script = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
        $scriptParameters = $Script.ParamBlock.Parameters.Name.VariablePath.UserPath

        # For each of those in PackageParameters, add it to the splat
        foreach ($parameter in $scriptParameters) {
            if ($packageParameters.ContainsKey($parameter)) {
                $splatHash[$parameter] = $packageParameters[$parameter]
            }
        }
    
        # Return the splat
        $splatHash
    }

    function Get-PatternLineNumberOrDefault($File, $Pattern, $Default) {
        $m = Select-String -Path $File -Pattern $Pattern
        if ($m.Count) {
            $m = $m | Select-Object -First 1
            $m.LineNumber
        } else {
            $Default
        }
    }

    function Get-ScriptRunnerParameter {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Name,
            $Scope = 1
        )
        $Invocation = Get-Variable MyInvocation -Scope $Scope -ValueOnly
        [System.Management.Automation.Language.Parser]::ParseInput(
            $Invocation.Line, [ref]$null, [ref]$null
        ).EndBlock.Statements.Where{
            "$_" -match "^& '$([regex]::Escape($env:ChocolateyInstall))\\helpers\\chocolateyScriptRunner\.ps1'"
        }.PipelineElements.CommandElements.Where(
            {$_.ParameterName -eq $Name},
            'SkipUntil'
        ).Where(
            {$_.ParameterName -and $_.ParameterName -ne $Name},
            'Until'
        ).Where(
            {-not $_.ParameterName},
            'SkipUntil'
        ).Value -join ''
    }

    function Out-RethrownError {
        <#
            .SYNOPSIS
                Results in $? -eq $false and outputs the stored exception
            .DESCRIPTION
                We need the last result to be correctly evaluated in the script runner.
                This results in that "error".
        #>
        throw $script:rethrownError
    }

    $Breakpoint = @{
        Script = $ScriptRunnerFile
        Line   = Get-PatternLineNumberOrDefault -File $ScriptRunnerFile -Pattern @('if \(\$packageScript\)', '& "\$packageScript"') -Default 61
        Action = {
            Write-Debug "PackageParams Breakpoint hit: $_"
            if (-not $packageScript) {$packageScript = Get-ScriptRunnerParameter -Name 'packageScript'}
            if ($packageScript) {
                Write-Debug "Finding Parameters for package script '$packageScript'"
                $scriptParameters = Get-PackageScriptParameters -Script $packageScript -PackageParameters (Get-ScriptRunnerParameter 'packageParameters')

                Write-Debug "Running package script '$packageScript' with $($scriptParameters.Keys.Count) matching package parameters"
                try {
                    & "$packageScript" @scriptParameters
                    Set-Alias -Name $packageScript -Value "Out-Null" -Scope Global
                } catch {
                    $script:rethrownError = $_
                    Set-Alias -Name $packageScript -Value "Out-RethrownError" -Scope Global
                }
            }
        }
    }

    Set-PSBreakpoint @Breakpoint
} else {
    Write-Debug "PackageParams is supported by Chocolatey $($env:CHOCOLATEY_VERSION)."
}