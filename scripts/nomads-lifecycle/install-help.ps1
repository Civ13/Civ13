param(
    [Parameter(Mandatory=$true)][string]$RuntimeRoot,
    [Parameter(Mandatory=$true)][string]$PythonPath,
    [Parameter(Mandatory=$true)][string]$BridgePath,
    [Parameter(Mandatory=$true)][string]$HelpConfig,
    [string]$TaskName = 'Civ13 Nomads optional help'
)
$ErrorActionPreference = 'Stop'
$runtime = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$python = (Resolve-Path -LiteralPath $PythonPath).Path
$bridge = (Resolve-Path -LiteralPath $BridgePath).Path
$config = (Resolve-Path -LiteralPath $HelpConfig).Path
$source = Join-Path $PSScriptRoot 'help_manager.py'
foreach ($path in @($runtime, $python, $bridge, $config, $source)) {
    if ($path.Contains('"')) { throw 'Unsupported quoted path.' }
}
if (-not (Test-Path -LiteralPath (Join-Path $runtime 'state.json') -PathType Leaf)) { throw 'Existing runtime state required.' }
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { throw 'Task already exists; inspect before replacing.' }
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$arguments = '"{0}" --root "{1}" --python "{2}" --bridge "{3}" --config "{4}"' -f $source, $runtime, $python, $bridge, $config
$action = New-ScheduledTaskAction -Execute $python -Argument $arguments -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Optional help observer; never controls the game or updater.' | Out-Null
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName,State,Actions,Triggers,Settings
