using System;
using System.Collections;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation.Runspaces;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace PackageParams
{
    public static class PackageParameter
    {
        private const string MachineEnvironmentRegistryKeyName = @"SYSTEM\CurrentControlSet\Control\Session Manager\Environment\";
        private const string UserEnvironmentRegistryKeyName = "Environment";

        private const string PackageParameterPattern = @"(?:^|\s+)\/(?<ItemKey>[^\:\=\s)]+)(?:(?:\:|=){1}(?:\'|\""){0,1}(?<ItemValue>.*?)(?:\'|\""){0,1}(?:(?=\s+\/)|$))?";
        private static readonly Regex PackageParameterRegex = new Regex(PackageParameterPattern, RegexOptions.Compiled);

        private static RegistryKey GetEnvironmentKey(EnvironmentVariableTarget scope, bool writable = false)
        {
            switch (scope)
            {
                case EnvironmentVariableTarget.User:
                    return Registry.CurrentUser.OpenSubKey(UserEnvironmentRegistryKeyName, writable);
                case EnvironmentVariableTarget.Machine:
                    return Registry.LocalMachine.OpenSubKey(MachineEnvironmentRegistryKeyName, writable);
                default:
                    throw new NotSupportedException($"The environment variable scope value '{scope}' is not supported.");
            }
        }

        public static string GetVariable(PSCmdlet cmdlet, string name, EnvironmentVariableTarget scope)
        {
            return GetVariable(cmdlet, name, scope, preserveVariables: false);
        }

        public static string GetVariable(PSCmdlet cmdlet, string name, EnvironmentVariableTarget scope, bool preserveVariables)
        {
            if (scope == EnvironmentVariableTarget.Process)
            {
                return Environment.GetEnvironmentVariable(name, scope);
            }

            var value = string.Empty;

            try
            {
                using (var registryKey = GetEnvironmentKey(scope))
                {
                    var options = preserveVariables ? RegistryValueOptions.DoNotExpandEnvironmentNames : RegistryValueOptions.None;
                    if (!(registryKey is null))
                    {
                        value = (string)registryKey.GetValue(name, string.Empty, options);
                    }
                }
            }
            catch (Exception error)
            {
                cmdlet.WriteDebug($"Unable to retrieve the {name} environment variable. Details: {error.Message}");
            }

            if (string.IsNullOrEmpty(value))
            {
                value = Environment.GetEnvironmentVariable(name, scope);
            }

            return value ?? string.Empty;
        }

        private static Hashtable GetParameters(PSCmdlet cmdlet, string parameters)
        {
            var paramStrings = new List<string>();
            var logParams = true;

            if (!string.IsNullOrEmpty(parameters))
            {
                paramStrings.Add(parameters);
            }
            else
            {
                var packageParameters = PackageParameter.GetVariable(
                    cmdlet,
                    "ChocolateyPackageParameters",
                    EnvironmentVariableTarget.Process);
                if (!string.IsNullOrEmpty(packageParameters))
                {
                    paramStrings.Add(packageParameters);
                }

                // This should possibly only be implemented in the CLE codebase
                var sensitivePackageParameters = PackageParameter.GetVariable(
                    cmdlet,
                    "ChocolateyPackageParametersSensitive",
                    EnvironmentVariableTarget.Process);
                if (!string.IsNullOrEmpty(sensitivePackageParameters))
                {
                    logParams = false;
                    paramStrings.Add(sensitivePackageParameters);
                }
            }

            var paramHash = new Hashtable(StringComparer.OrdinalIgnoreCase);

            foreach (var param in paramStrings)
            {
                foreach (Match match in PackageParameterRegex.Matches(param))
                {
                    var name = match.Groups["ItemKey"].Value.Trim();
                    var valueGroup = match.Groups["ItemValue"];

                    object value;
                    if (valueGroup.Success)
                    {
                        value = valueGroup.Value.Trim();
                    }
                    else
                    {
                        value = (object)true;
                    }

                    if (logParams)
                    {
                        cmdlet.WriteVerbose($"Adding package param '{name}'='{value}'");
                    }

                    paramHash[name] = value;
                }
            }

            return paramHash;
        }

        internal static IDictionary<string, PSVariable> GetVariableTableAtScope(string scopeID)
        {
            var result = new Dictionary<string, PSVariable>(StringComparer.OrdinalIgnoreCase);
            GetScopeVariableTable(GetScopeByID(scopeID), result, includePrivate: true);
            return result;
        }

        private static void GetScopeVariableTable(SessionStateScope scope, Dictionary<string, PSVariable> result, bool includePrivate)
        {
            foreach (KeyValuePair<string, PSVariable> entry in scope.Variables)
            {
                if (!result.ContainsKey(entry.Key))
                {
                    // Also check to ensure that the variable isn't private
                    // and in a different scope

                    PSVariable var = entry.Value;

                    if (!var.IsPrivate || includePrivate)
                    {
                        result.Add(entry.Key, var);
                    }
                }
            }

            foreach (var dottedScope in scope.DottedScopes)
            {
                dottedScope.GetVariableTable(result, includePrivate);
            }

            scope.LocalsTuple?.GetVariableTable(result, includePrivate);
        }

        private static List<String> GetScriptParameters(PSCmdlet cmdlet, string Path)
        {
            // Check what parameters the script has
            Token[] tokensRef = null;
            ParseError[] errorsRef = null;
            var parsedAst = Parser.ParseFile(Path, out tokensRef, out errorsRef);
            var scriptParameters = parsedAst.ParamBlock != null ? parsedAst.ParamBlock.Parameters.Select(p => p.Name.VariablePath.UserPath.ToString()).ToList() : new List<string>();
            cmdlet.WriteVerbose($"Found {scriptParameters.Count()} parameter(s) in '{Path}'");

            return scriptParameters;
        }

        private static Hashtable GetPackageScriptParameters(Hashtable PackageParameters, List<String> ScriptParameters)
        {
            var splatHash = new Hashtable(StringComparer.OrdinalIgnoreCase);

            // For each of those in PackageParameters, add it to the splat
            foreach (var parameter in ScriptParameters)
            {
                if (PackageParameters.ContainsKey(parameter))
                {
                    splatHash.Add(parameter, PackageParameters[parameter]);
                }
            }

            return splatHash;
        }

        [Cmdlet(VerbsCommon.Get, "PackageScriptParameters")]
        [OutputType(typeof(Hashtable))]
        public class GetPackageScriptParametersCommand : PSCmdlet
        {
            [Parameter(
                Mandatory = true,
                Position = 0)]
            public string ScriptPath;

            [Parameter(
                Mandatory = false,
                Position = 1)]
            public string Parameters = string.Empty;

            protected override void EndProcessing()
            {
                this.WriteVerbose(string.Format("Using Parameters '{0}'", Parameters));
                this.WriteVerbose(string.Format("Using ScriptPath '{0}'", ScriptPath));
                // Return the splat
                WriteObject(PackageParameter.GetPackageScriptParameters(
                    PackageParameter.GetParameters(this, Parameters),
                    PackageParameter.GetScriptParameters(this, ScriptPath)
                ));
            }
        }

        private static uint GetPatternLineNumberOrDefault(string File, string Pattern, uint Default)
        {
            
            return Default;
        }

        [Cmdlet(VerbsCommon.Get, "ScriptRunnerParameter")]
        [OutputType(typeof(string))]
        public class GetScriptRunnerParameterCommand : PSCmdlet {
            [Parameter(
                Mandatory = true,
                Position = 0)]
            public string Name;

            [Parameter(
                Mandatory = false,
                Position = 1)]
            public int Scope = 1;

            protected override void EndProcessing()
            {
                var chocolateyInstall = Environment.GetEnvironmentVariable("ChocolateyInstall", EnvironmentVariableTarget.Machine) ?? @"C:\ProgramData\chocolatey";
                this.WriteVerbose($"Using '{chocolateyInstall}' as ChocolateyInstall");
                this.WriteVerbose($"This should result in: '{Path.Combine(chocolateyInstall, @"helpers\chocolateyScriptRunner.ps1")}'");

                Token[] tokensRef = null;
                ParseError[] errorsRef = null;

                // Invocation = blah
                var Line = @"[System.Threading.Thread]::CurrentThread.CurrentCulture = '';[System.Threading.Thread]::CurrentThread.CurrentUICulture = '';[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::SystemDefault; & import-module -name 'C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1'; & 'C:\ProgramData\chocolatey\helpers\chocolateyScriptRunner.ps1' -packageScript 'C:\ProgramData\chocolatey\lib\visualstudio-installer\tools\ChocolateyInstall.ps1' -installArguments '' -packageParameters '' -preRunHookScripts $null -postRunHookScripts $null";
                var par = Parser.ParseInput(
                    Line, out tokensRef, out errorsRef
                )
                .EndBlock
                .Statements
                .Where(
                    statement => Regex.Match(
                        statement.ToString(),
                        $"^& '{Regex.Escape(Path.Combine(chocolateyInstall, @"helpers\chocolateyScriptRunner.ps1"))}'"
                    ).Success
                )
                .Select(x => (x as PipelineAst)?.PipelineElements)
                .FirstOrDefault()
                .Select(x => (x as CommandAst).CommandElements)
                .FirstOrDefault()
                .SkipWhile(
                    element =>
                    {
                        var e = element as CommandParameterAst;
                        if (e is null)
                        {
                            return true;
                        }
                        return e.ParameterName != Name;
                    }
                )
                // // .SkipWhile(
                // //     element => !string.IsNullOrEmpty(element.ParameterName)
                // // )
                .Skip(1)
                // // .TakeWhile(
                // //     element => element.GetType() != typeof(CommandParameterAst)
                // // )
                .Take(1)
                .FirstOrDefault()
                .SafeGetValue()
                ;

                WriteObject(par);
            }
        }

        public static void AddScriptRunnerBreakpoint(string ChocolateyScriptRunner)
        {
            var debugger = Runspace.DefaultRunspace.Debugger;
            var scriptBlock = @"Write-Host 'Hello'";

            // Get the line of the ChocolateyScriptRunner we're looking to override
            var line = GetPatternLineNumberOrDefault(ChocolateyScriptRunner, @"if \(\$packageScript\)|& ""\$packageScript""", 61);

            // IEnumerable<Breakpoint> breakpoint = new Breakpoint(ChocolateyScriptRunner, line, scriptBlock);
            // debugger.SetBreakpoints(
            //     new List<Breakpoint>(
            //         breakpoint
            //     )
            // );
        }
    }

    public class LogicInjection : IModuleAssemblyInitializer
    {
        private static string _chocolateyParamsReleaseVersion = "3.0";  // Hopeful, but who knows if it'll ever actually be accepted.
        private static string _chocolateyScriptRunner = Path.Combine(
            Environment.GetEnvironmentVariable("ChocolateyInstall") ?? throw new InvalidOperationException(@"Cannot find the Chocolatey Installation."),
            @"helpers\chocolateyScriptRunner.ps1"
        );

        public void OnImport()
        {
            var chocolateyVersion = Environment.GetEnvironmentVariable("CHOCOLATEY_VERSION") ?? string.Empty;

            if (string.IsNullOrEmpty(chocolateyVersion))
            {
                Console.WriteLine("Not loading from inside Chocolatey, skipping code injection.");
                return;
            }

            var parametersPassed = !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ChocolateyPackageParameters")) || !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ChocolateyPackageParametersSensitive"));
            if (Version.Parse(chocolateyVersion) < new Version(_chocolateyParamsReleaseVersion) && parametersPassed)
            {
                Console.WriteLine($"Version is '{chocolateyVersion}' - injecting parameter handling into '{_chocolateyScriptRunner}'!");
                PackageParameter.AddScriptRunnerBreakpoint(_chocolateyScriptRunner);
            }
            else
            {
                Console.WriteLine($"Version is '{chocolateyVersion}' - we don't need to do anything.");
            }
        }
    }
}