param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [switch]$City, [switch]$VehicleWorldSave, [string]$ResumeRunDirectory, [switch]$ValidateRestartOnly, [ValidateRange(1024,65535)][int]$Port=18342, [ValidateRange(60,900)][int]$TimeoutSeconds=600)
$ErrorActionPreference = 'Stop'
if ($VehicleWorldSave -and ($Visual -or $City)) { throw 'VehicleWorldSave requires the nonvisual Industrial disposable fixture' }
if (![IO.Path]::IsPathRooted($ByondBin)) { throw 'ByondBin must be an absolute path to a trusted BYOND installation' }
$ByondBin = (Resolve-Path -LiteralPath $ByondBin).Path
foreach ($binary in @('dm.exe','dd.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $ByondBin $binary) -PathType Leaf)) { throw "Missing BYOND binary: $binary" }
}
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sourceInventory = @(& git -C $repo status --porcelain --untracked-files=normal)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory tested source' }
if ($ValidateRestartOnly -and !$ResumeRunDirectory) { throw 'ValidateRestartOnly requires ResumeRunDirectory' }
$commit = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify tested commit' }
$nonce = [guid]::NewGuid().ToString('N')
$source = Join-Path $repo ('.extraction-area-' + $nonce + '.dme')
$run = Join-Path ([IO.Path]::GetTempPath()) ('civ13-extraction-area-' + $nonce)
$owned = $null
if ($ResumeRunDirectory) {
    if (!$Visual -or $VehicleWorldSave) { throw 'Restart requires Visual and excludes VehicleWorldSave' }
    $run = (Resolve-Path -LiteralPath $ResumeRunDirectory).Path
    $runItem = Get-Item -LiteralPath $run
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if (!$runItem.PSIsContainer -or $runItem.Parent.FullName -ine $tempRoot -or $runItem.Name -notmatch '^civ13-extraction-area-[a-f0-9]{32}$' -or ($runItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Restart target must be an original direct disposable temporary directory' }
    $manifest = Get-Content -LiteralPath (Join-Path $run 'invocation.json') -Raw | ConvertFrom-Json
    if ($manifest.commit -cne $commit -or $manifest.dirty -or $sourceInventory.Count -or !$manifest.visual -or [bool]$manifest.city -ne [bool]$City -or $manifest.vehicle_world_save -or $manifest.byond_bin -ine $ByondBin) { throw 'Restart provenance must match the clean current commit, pinned runtime and map' }
    foreach ($artifact in @('area.dmb','area.rsc')) {
        $artifactPath = Join-Path $run $artifact
        $expectedHash = $manifest.artifacts.$artifact
        if (!$expectedHash -or (Get-Item -LiteralPath $artifactPath).Attributes -band [IO.FileAttributes]::ReparsePoint -or (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash -cne $expectedHash) { throw "Restart artifact changed: $artifact" }
    }
    foreach ($directory in @('data','config','UI','SQL')) {
        $directoryItem = Get-Item -LiteralPath (Join-Path $run $directory)
        if (!$directoryItem.PSIsContainer -or ($directoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Invalid disposable directory: $directory" }
    }
    if ($ValidateRestartOnly) { Write-Output "PASS: restart provenance and artifacts verified; storage=$run; no process launched"; return }
    $nativeProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'dd.exe'")
    if ($nativeProcesses.Count) { throw 'Restart requires the native queue to be free of existing daemons; no process will be reused or stopped' }
} else {
New-Item -ItemType Directory -Path $run | Out-Null
}
try {
    if (!$ResumeRunDirectory) {
    $mapDefine = '#define EXTRACTION_SURVIVAL_MAP'
    if ($City) { $mapDefine = '#define EXTRACTION_MODERN_CITY_MAP' }
    [IO.File]::WriteAllText($source, $mapDefine + "`n" + '#include "civ13.dme"' + "`n" + '#include "tests/extraction/full_game_vehicle_save.dm"' + "`n" + '#include "tests/extraction/playable_area.dm"' + "`n")
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $source 2>&1
    $build | Set-Content -LiteralPath (Join-Path $run 'build.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '516.1681' -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Pinned test-area compilation failed' }
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($source,'dmb')) -Destination (Join-Path $run 'area.dmb')
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($source,'rsc')) -Destination (Join-Path $run 'area.rsc')
    Copy-Item -LiteralPath (Join-Path $repo 'config'),(Join-Path $repo 'UI') -Destination $run -Recurse
    New-Item -ItemType Directory -Path (Join-Path $run 'SQL') | Out-Null
    $configPath = Join-Path $run 'config/config.txt'
    $config = Get-Content -Raw -LiteralPath $configPath
    $config = [regex]::Replace($config,'(?m)^(HUB|GUEST_BAN|USE_JOB_WHITELIST)\s*\r?$','#$1')
    $config = [regex]::Replace($config,'(?m)^HUB_BANNER_URL[^\r\n]*','#HUB_BANNER_URL')
    [IO.File]::WriteAllText($configPath,$config)
    $commit = (& git -C $repo rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify tested commit' }
    $patch = & git -C $repo diff HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot preserve tested patch' }
    $patch | Set-Content -LiteralPath (Join-Path $run 'tested.patch')
    @{ commit=$commit; dirty=($sourceInventory.Count -gt 0); source_changes=$sourceInventory; city=[bool]$City; visual=[bool]$Visual; vehicle_world_save=[bool]$VehicleWorldSave; artifacts=@{ 'area.dmb'=(Get-FileHash -LiteralPath (Join-Path $run 'area.dmb') -Algorithm SHA256).Hash; 'area.rsc'=(Get-FileHash -LiteralPath (Join-Path $run 'area.rsc') -Algorithm SHA256).Hash }; vehicle_probe_sha256=(Get-FileHash -LiteralPath (Join-Path $repo 'tests/extraction/full_game_vehicle_save.dm') -Algorithm SHA256).Hash; byond_bin=$ByondBin; duration_seconds=$TimeoutSeconds; storage='disposable run directory'; adapter_sha256=(Get-FileHash -LiteralPath (Join-Path $repo 'tests/extraction/playable_area.dm') -Algorithm SHA256).Hash } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'invocation.json')
    } else {
        $episode = 'restart-' + $nonce
        foreach ($file in @('extraction-area-ready.json','startup.log')) {
            $oldFile = Join-Path $run $file
            if (Test-Path -LiteralPath $oldFile) { Move-Item -LiteralPath $oldFile -Destination (Join-Path $run ($episode + '-' + $file)) }
        }
        @{ commit=$commit; run_directory=$run; artifacts=$manifest.artifacts; duration_seconds=$TimeoutSeconds; port=$Port } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run ($episode + '.json'))
    }
    $parameters = 'tested_commit=' + $commit
    if ($VehicleWorldSave) { $parameters += '&vehicle_world_save=1' }
    if ($Visual) { $parameters += '&visual=1' }
    $daemonArguments = @('area.dmb',"$Port",'-invisible','-trusted','-params',$parameters,'-log','startup.log')
    if (!$Visual) { $daemonArguments = @('area.dmb','0','-close','-invisible','-trusted','-params',$parameters,'-log','startup.log') }
    $owned = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList $daemonArguments -WorkingDirectory $run -WindowStyle Hidden -PassThru
    Write-Output "RUN_DIRECTORY=$run; OWNED_PID=$($owned.Id)"
    if ($Visual) { Write-Output "LOCAL_CONNECT=byond://127.0.0.1:$Port; use two real accounts and close manually launched clients after testing" }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $readyPath = Join-Path $run 'extraction-area-ready.json'
    $reportedReady = $false
    while (!$owned.WaitForExit(200)) {
        if ($Visual -and !$reportedReady -and (Test-Path -LiteralPath $readyPath)) {
            Get-Content -LiteralPath $readyPath
            $reportedReady = $true
        }
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            if ($Visual -and $reportedReady) { break }
            throw 'Test-area startup timed out'
        }
    }
    if ($Visual -and $owned.HasExited) { throw "Visual daemon exited before the bounded test period ended; inspect $run" }
    if (!(Test-Path -LiteralPath $readyPath)) { throw "Area did not become ready; inspect $run" }
    if (!$reportedReady) { Get-Content -LiteralPath $readyPath }
    if ($VehicleWorldSave) {
        $vehicleResult = Get-Content -Raw -LiteralPath (Join-Path $run 'vehicle-world-save-result.txt')
        Write-Output $vehicleResult
        if ($vehicleResult -notmatch '^PASS:') { throw "Vehicle whole-world save regression failed; inspect $run" }
    }
    $runtimeFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'data/logs/runtime') -File -ErrorAction SilentlyContinue)
    foreach ($log in $runtimeFiles) {
        if (Select-String -LiteralPath $log.FullName -Pattern 'runtime error:|Bad ref|## ERROR|Cannot execute' -Quiet) { throw "Runtime error invalidates test-area evidence: $($log.FullName)" }
    }
} finally {
    if ($owned -and !$owned.HasExited) { Stop-Process -Id $owned.Id; $owned.WaitForExit() }
    foreach ($path in @($source,[IO.Path]::ChangeExtension($source,'dmb'),[IO.Path]::ChangeExtension($source,'rsc'))) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    Write-Output "Retained disposable evidence: $run"
}
