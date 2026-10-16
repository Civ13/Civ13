param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [string]$TaskName = 'Civ13 Nomads TEST1714 lifecycle'
)
$ErrorActionPreference = 'Stop'
$resolvedConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Get-Content -LiteralPath $resolvedConfig -Raw | ConvertFrom-Json
if ($config.port -ne 1714) { throw 'Only authorized TEST1714 is supported.' }
if (-not (Test-Path -LiteralPath $config.python -PathType Leaf)) { throw 'Configured Python is missing.' }
$source = Join-Path $PSScriptRoot 'supervisor.py'
if ($resolvedConfig.Contains('"') -or $source.Contains('"')) { throw 'Unsupported quoted path.' }
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute $config.python -Argument ('"{0}" --config "{1}"' -f $source, $resolvedConfig) -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { throw 'Task already exists; inspect it before replacing.' }
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Serialized TEST1714 updates; failure latch prevents retry storms.' | Out-Null
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName,State,Actions,Triggers,Settings
