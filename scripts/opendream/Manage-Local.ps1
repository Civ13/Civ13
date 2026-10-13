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
$packageVerifier = Join-Path $PSScriptRoot 'verify-client-package.py'
function Test-ClientPackage([switch]$StageRuntime) {
    foreach ($name in @('client_package','native_byond_bin','native_observer_directory')) {
        $value = [string]$settings.$name
        if (!$value -or $value.Contains('"') -or $value.Contains("`r") -or $value.Contains("`n") -or !$([IO.Path]::IsPathRooted($value))) {
            throw "Configure an absolute trusted launcher path: $name"
        }
    }
    $validationArguments = @('-B',$packageVerifier,'--package',$settings.client_package,
        '--byond-bin',$settings.native_byond_bin,'--observer',$settings.native_observer_directory)
    if ($StageRuntime) {$validationArguments += @('--stage-parent',(Join-Path $profile 'client-runtime'))}
    $output = & $settings.python @validationArguments
    if ($LASTEXITCODE -ne 0) {throw 'Coherent client package or native observer verification failed.'}
    return ($output | ConvertFrom-Json)
}
function Remove-OwnedClientRuntime {
    if (!$state.client -or !$state.client.runtime) {return}
    $parent = [IO.Path]::GetFullPath((Join-Path $profile 'client-runtime')).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $target = [IO.Path]::GetFullPath([string]$state.client.runtime)
    if ([IO.Path]::GetDirectoryName($target) -ne $parent -or [IO.Path]::GetFileName($target) -notmatch '^[0-9a-f]{32}$') {
        throw 'Refusing client runtime cleanup outside its owned staging directory.'
    }
    Assert-UnlinkedClientPath $target
    if (!(Test-Path -LiteralPath $target)) {return}
    $resolvedParent = (Resolve-Path -LiteralPath $parent).ProviderPath.TrimEnd([IO.Path]::DirectorySeparatorChar)
    $resolvedTarget = (Resolve-Path -LiteralPath $target).ProviderPath
    if ([IO.Path]::GetDirectoryName($resolvedTarget) -ne $resolvedParent) {throw 'Resolved client runtime escaped its parent.'}
    # Walk without following links. Reject linked descendants as well as ancestors.
    $directories = New-Object 'System.Collections.Generic.Queue[string]'
    $directories.Enqueue($target)
    while ($directories.Count) {
        $directory = $directories.Dequeue()
        Assert-UnlinkedClientPath $directory
        foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Linked client runtime descendant rejected.'}
            if ($entry.PSIsContainer) {$directories.Enqueue($entry.FullName)}
        }
    }
    Assert-UnlinkedClientPath $target
    Remove-Item -LiteralPath $target -Recurse -Force
}
function Assert-UnlinkedClientPath([string]$path) {
    $current = [IO.Path]::GetFullPath($path)
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Linked client runtime ancestor rejected.'
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}
function Save-ClientState {
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath
}
function Start-ClientProcess([string]$arguments, [string]$workingDirectory) {
    Start-Process -FilePath "$trial/sdk/dotnet.exe" -ArgumentList $arguments -WorkingDirectory $workingDirectory -WindowStyle Hidden -RedirectStandardOutput "$profile/client.stdout.log" -RedirectStandardError "$profile/client.stderr.log" -PassThru
}
function Stop-ClientProcessTree($process) {
    & "$env:SystemRoot/System32/taskkill.exe" /PID $process.Id /T /F | Out-Null
    if ($LASTEXITCODE -ne 0) {throw 'Could not terminate the exact owned client tree.'}
}
function Stop-LaunchedClient($process) {
    if (!$process.HasExited) {Stop-ClientProcessTree $process}
    if (!$process.WaitForExit(10000)) {throw 'Owned client did not exit; runtime retained.'}
}
function Start-VerifiedClient($verified) {
    $oldEnvironment = @{}
    foreach ($entry in Get-ChildItem Env:) {
        if ($entry.Name -eq 'ROBUST_DISABLE_SANDBOX' -or $entry.Name -like 'ROBUST_AUTH_*' -or $entry.Name -like 'ROBUST_CVAR_*' -or $entry.Name -like 'ROBUST_MODULE_*') {
            $oldEnvironment[$entry.Name] = $entry.Value
            Remove-Item -LiteralPath "Env:$($entry.Name)"
        }
    }
    $oldDotnetRoot = $env:DOTNET_ROOT
    $oldWebview = $env:ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW
    $client = $null
    try {
        $env:DOTNET_ROOT = "$trial/sdk"
        $env:ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW = $verified.webview
        # Operator paths are frozen by the trusted host before sandboxed content loads.
        # Open the menu at an explicit address. Account and CID come from native BYOND.
        $arguments = "`"$($verified.loader)`" --self-contained --connect-address udp://127.0.0.1:$($configuration.game_port) --cvar `"opendream.native_byond_bin=$($settings.native_byond_bin)`" --cvar `"opendream.native_observer_directory=$($settings.native_observer_directory)`""
        $client = Start-ClientProcess $arguments $verified.root
        $state.client = @{id=$client.Id;path=$client.Path;startedUtc=$client.StartTime.ToUniversalTime().ToString('o');runtime=$verified.staging_root}
        Save-ClientState
    } catch {
        $startFailure = $_
        # A returned Process is this launch's handle, even if metadata or the
        # durable state write fails. Stop it before deleting its runtime.
        if ($client) {Stop-LaunchedClient $client}
        $state.client = @{runtime=$verified.staging_root}
        Remove-OwnedClientRuntime
        $state.client = $null
        Save-ClientState
        throw $startFailure
    } finally {
        $env:DOTNET_ROOT = $oldDotnetRoot
        $env:ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW = $oldWebview
        foreach ($name in $oldEnvironment.Keys) {Set-Item -LiteralPath "Env:$name" -Value $oldEnvironment[$name]}
    }
}
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
        "$profile/source/civ13.json","$trial/sdk/dotnet.exe",$packageVerifier)) {
        if (!(Test-Path -LiteralPath $path)) {throw "Missing installed dependency: $path"}
    }
    Test-ClientPackage | Out-Null
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
        Stop-LaunchedClient $client
    }
    Remove-OwnedClientRuntime
    $state.client = $null
    Save-ClientState
    if (Test-Path -LiteralPath (Join-Path $configuration.runtime_dir 'SQL/opendream-control/supervisor.lock')) {
        Invoke-Control 'stop'
    }
    return
}
if ($Action -in @('Play','Client')) {Test-ClientPackage | Out-Null}
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
        Remove-OwnedClientRuntime
        $state.client = $null
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath
        $verified = Test-ClientPackage -StageRuntime
        Start-VerifiedClient $verified
    }
}
