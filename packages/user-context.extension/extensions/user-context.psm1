function Invoke-ImmediateUserScript {
    <#
        .Synopsis
            Runs a PowerShell ScriptBlock in a logged-in user context

        .Description
            Uses scheduled tasks to create, run, and remove a task with
            PowerShell and a given script.
            Waits until the task has finished before returning.

        .Example
            Invoke-ImmediateUserScript {& "C:\Path\to\userinstaller.exe"}

        .Example
            Invoke-ImmediateUserScript {& $Location\userinstaller.exe}.GetNewClosure()
    #>
    [CmdletBinding()]
    param(
        # The scriptblock to run.
        [Parameter(Mandatory, Position=0)]
        [scriptblock]$ScriptBlock
    )
    $TaskId = "$(New-Guid)"
    
    $ScriptPath = Join-Path "C:\Temp" "$($TaskId).ps1"
    $ScriptBlock.ToString() | Set-Content $ScriptPath

    $Task = @{
        Path = (Get-Command powershell).Source
        Arguments = "-ExecutionPolicy Unrestricted -Command ""& $ScriptPath"" -NoProfile -NoProfileLoadTime -NonInteractive -NoLogo -WindowStyle Hidden -NoNewWindow"
    }
    try {
        Invoke-ImmediateUsersTaskExecution @Task
    } finally {
        Remove-Item $ScriptPath
    }
}

function Invoke-ImmediateUsersTaskExecution {
    <#
        .Synopsis
            Runs a task in a logged-in user context

        .Description
            Uses scheduled tasks to create, run, and remove a task with
            any given application.
            Waits until the task has finished before returning.

        .Example
            Invoke-ImmediateUsersTaskExecution -
    #>
    [CmdletBinding(DefaultParameterSetName="AllUsers")]
    param(
        # Path to the application to trigger.
        [Parameter(Mandatory, Position=0)]
        [string]$Path,

        # Arguments to pass to the application.
        [Parameter(ValueFromRemainingArguments)]
        [string]$Arguments,

        # UserName to run under, using the LOGON_INTERACTIVE_TOKEN.
        [Parameter(Mandatory, ParameterSetName='SingleUser')]
        [string]$UserName  # = $env:USER_CONTEXT
    )
    $UserID, $LogonType = if ($PSCmdlet.ParameterSetName -eq 'UsersGroups') {
        'Users'
        4  # TASK_LOGON_GROUP
    } elseif ($UserName) {
        $UserName
        3  # TASK_LOGON_INTERACTIVE_TOKEN
    }

    try {
        $ShedService = New-Object -ComObject 'Schedule.Service'
        $ShedService.Connect()

        $Task = $ShedService.NewTask(0)
        $Task.Settings.Enabled = $true
        $Task.Settings.AllowDemandStart = $true

        $Action = $Task.Actions.Create(0)
        $Action.Path = $Path
        $Action.Arguments = $Arguments

        $TaskFolder = $ShedService.GetFolder("\")
        $ActualTask = $TaskFolder.RegisterTaskDefinition(
            "$TaskId",  # Task Path
            $Task,      # Task Definition
            6,          # Task Flags (6 -> TASK_CREATE_OR_UPDATE)
            $UserID,    # UserID
            $null,      # Password
            $LogonType  # LogonType
        )

        $null = $ActualTask.Run($null)

        while ($ActualTask.LastTaskResult.ToString() -in @("267011", "267009")) {
            # The task has not yet run. (0x41303), and is not currently running (0x41301)
            Start-Sleep -Seconds 3
        }
    } finally {
        $TaskFolder.DeleteTask($ActualTask.Path, 0)
    }
}