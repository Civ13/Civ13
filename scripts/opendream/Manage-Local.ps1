[CmdletBinding()]
param(
    [ValidateSet('Nomads','TDM')][string]$Mode = 'Nomads',
    [ValidateSet('Play','Start','Client','Stop','Status','Restart','MapSwap')][string]$Action = 'Play',
    [string]$MapId,
    [string]$InstallationRoot,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
if (!$InstallationRoot) {$InstallationRoot = $PSScriptRoot}
$settings = Get-Content -LiteralPath (Join-Path $InstallationRoot 'launcher.json') -Raw | ConvertFrom-Json
$profile = Join-Path $InstallationRoot $Mode
$controlProfile = Join-Path $profile 'control-profile.json'
$controller = Join-Path $InstallationRoot 'control.py'
$configuration = Get-Content -LiteralPath $controlProfile -Raw | ConvertFrom-Json
$trial = $settings.trial
$statePath = Join-Path $profile 'processes.json'
$state = if (Test-Path -LiteralPath $statePath) {Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json} else {[pscustomobject]@{server=$null;client=$null}}
if ($state.server) {throw 'Legacy server record exists. Stop it using the old launcher before migrating.'}
function Get-OwnedClient {
    if (!$state.client) {return $null}
    $process = Get-Process -Id $state.client.id -ErrorAction SilentlyContinue
    if (!$process) {return $null}
    if ($process.Path -ne $state.client.path -or [math]::Abs(($process.StartTime.ToUniversalTime() - ([datetime]$state.client.startedUtc).ToUniversalTime()).TotalMilliseconds) -gt 1) {
        throw 'Client identity changed; refusing to operate an unknown process.'
    }
    return $process
}
function Invoke-Control([string]$operation, [string]$map) {
    $arguments = @($controller,'--profile',$controlProfile,$operation)
    if ($map) {$arguments += $map}
    $output = & $settings.python @arguments
    if ($LASTEXITCODE -ne 0) {throw "OpenDream control rejected: $output"}
    $result = $output | ConvertFrom-Json
    if (!$result.ok) {throw "OpenDream control rejected: $output"}
    return $result
}
if ($DryRun) {
    foreach ($path in @($settings.python,$controller,$configuration.server_command[0],$configuration.compiler,
        "$profile/source/civ13.json","$trial/sdk/dotnet.exe","$trial/RobustToolbox/bin/Client/Robust.Client.dll",
        "$trial/server/OpenDreamServer_win-x64/Content.Client.zip",
        "$trial/RobustToolbox/Robust.Client.WebView/bin/Release/net10.0/Robust.Client.WebView.dll")) {
        if (!(Test-Path -LiteralPath $path)) {throw "Missing installed dependency: $path"}
    }
    Write-Output "Validated $Mode OpenDream controls; no process started."
    return
}
if ($Action -eq 'Status') {
    $result = Invoke-Control 'status'
    $result | Add-Member -NotePropertyName ClientRunning -NotePropertyValue ([bool](Get-OwnedClient))
    $result
    return
}
if ($Action -eq 'Stop') {
    $client = Get-OwnedClient
    if ($client) {
        & "$env:SystemRoot/System32/taskkill.exe" /PID $client.Id /T /F | Out-Null
        if ($LASTEXITCODE -ne 0 -or !$client.WaitForExit(10000)) {throw 'Could not stop owned client.'}
    }
    $state.client = $null
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath
    if (Test-Path -LiteralPath (Join-Path $configuration.runtime_dir 'SQL/opendream-control/supervisor.lock')) {
        Invoke-Control 'stop'
    }
    return
}
if ($Action -in @('Play','Start','Restart','MapSwap')) {
    if ($Action -eq 'Restart') {Invoke-Control 'restart' | Out-Null}
    elseif ($Action -eq 'MapSwap') {
        if (!$MapId) {throw 'MapSwap requires -MapId from the profile allowlist.'}
        Invoke-Control 'mapswap' $MapId | Out-Null
    }
    else {Invoke-Control 'start' | Out-Null}
    $deadline = (Get-Date).AddSeconds(60)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        if (!(Invoke-Control 'status').running) {throw 'Owned server exited; inspect SQL/opendream-control/server.log.'}
        try {
            $info = Invoke-RestMethod -Uri "http://127.0.0.1:$($configuration.game_port)/info" -TimeoutSec 2
            if ($info) {$ready=$true; break}
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    if (!$ready) {throw 'Startup timed out; server remains owned. Inspect logs and use Stop.'}
    Write-Output "$Mode OpenDream server ready on localhost:$($configuration.game_port)"
}
if ($Action -in @('Play','Client')) {
    if (!(Invoke-Control 'status').running) {throw 'Start this local server before connecting.'}
    if (!(Get-OwnedClient)) {
        $oldDotnetRoot = $env:DOTNET_ROOT
        $oldWebview = $env:ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW
        try {
            $env:DOTNET_ROOT = "$trial/sdk"
            $env:ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW = "$trial/RobustToolbox/Robust.Client.WebView/bin/Release/net10.0"
            # The native-aware client reads this address into its menu and obtains
            # the account/CID from BYOND before connecting. Never supply a username.
            $arguments = "`"$trial/RobustToolbox/bin/Client/Robust.Client.dll`" --self-contained --mount-zip `"$trial/server/OpenDreamServer_win-x64/Content.Client.zip`" --connect-address udp://127.0.0.1:$($configuration.game_port)"
            $client = Start-Process -FilePath "$trial/sdk/dotnet.exe" -ArgumentList $arguments -WorkingDirectory "$trial/RobustToolbox/bin/Client" -WindowStyle Hidden -RedirectStandardOutput "$profile/client.stdout.log" -RedirectStandardError "$profile/client.stderr.log" -PassThru
            $state.client = @{id=$client.Id;path=$client.Path;startedUtc=$client.StartTime.ToUniversalTime().ToString('o')}
            $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath
        } finally {
            $env:DOTNET_ROOT = $oldDotnetRoot
            $env:ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW = $oldWebview
        }
    }
}
