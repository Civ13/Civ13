$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($env:REVIEWED_COMMIT -cnotmatch '^[0-9a-f]{40}$' -or $env:REVIEWED_COMMIT -cne $env:GITHUB_SHA) { throw 'reviewed_commit_mismatch' }
if ($env:ImageOS -cne 'win22' -or $env:ImageVersion -notmatch '^[0-9.]+$' -or $env:GITHUB_RUN_ID -notmatch '^[0-9]+$' -or $env:GITHUB_RUN_ATTEMPT -notmatch '^[0-9]+$') { throw 'hosted_image_identity_unavailable' }
$temp=[IO.Path]::GetFullPath($env:RUNNER_TEMP)
$root=Join-Path $temp 'civ13-custody'
if (Test-Path -LiteralPath $root) { throw 'root_already_exists' }
$src=Join-Path $env:GITHUB_WORKSPACE 'tools\custody-fixture'
Copy-Item -LiteralPath $src -Destination $root -Recurse
. (Join-Path $root 'runtime-checks.ps1')
$env:DOTNET_CLI_HOME=$root
$env:DOTNET_NOLOGO='1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'
$python='C:\hostedtoolcache\windows\Python\3.12.10\x64\python.exe'
$pythonDll='C:\hostedtoolcache\windows\Python\3.12.10\x64\python312.dll'
$pythonShim='C:\hostedtoolcache\windows\Python\3.12.10\x64\python3.dll'
$dotnet='C:\Program Files\dotnet\dotnet.exe'
$records=@((Get-VerifiedRuntimeFile $python 'python'),(Get-VerifiedRuntimeFile $pythonDll 'python'),(Get-VerifiedRuntimeFile $pythonShim 'python'),(Get-VerifiedRuntimeFile $dotnet 'dotnet'))
if ($records[0].file_version -notlike '3.12.10*') { throw 'python_version_mismatch' }
Push-Location $root
try {
    foreach($record in $records) { Assert-RuntimeMatches $record }
    $sdk=@(& $dotnet --version)
    if ($LASTEXITCODE -ne 0 -or $sdk.Count -ne 1 -or $sdk[0] -cne '8.0.427') { throw 'dotnet_sdk_mismatch' }
    foreach($record in $records) { Assert-RuntimeMatches $record }
    $runtimes=@(& $dotnet --list-runtimes)
    if ($LASTEXITCODE -ne 0 -or $runtimes.Count -gt 64 -or (($runtimes -join "`n").Length -gt 8192)) { throw 'dotnet_runtime_inventory_unavailable' }
    $runtime=[ordered]@{
        schema=1;python=$python;python_sha256=$records[0].sha256;python_dll=$pythonDll;python_dll_sha256=$records[1].sha256
        python_shim=$pythonShim;python_shim_sha256=$records[2].sha256;dotnet=$dotnet;dotnet_sha256=$records[3].sha256
        files=$records;dotnet_sdk=$sdk[0];dotnet_runtimes=$runtimes;image_os=$env:ImageOS;image_version=$env:ImageVersion
        run_id=$env:GITHUB_RUN_ID;run_attempt=$env:GITHUB_RUN_ATTEMPT;commit=$env:GITHUB_SHA
    }
    $runtimeFile=Join-Path $root 'runtime.json'
    $bytes=[Text.Encoding]::UTF8.GetBytes(($runtime | ConvertTo-Json -Depth 6 -Compress))
    if($bytes.Length -gt 16384){throw 'runtime_manifest_oversized'}
    [IO.File]::WriteAllBytes($runtimeFile,$bytes)
    $runtimeHash=(Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $env:CUSTODY_RUNTIME_SHA256=$runtimeHash
    Add-Content -LiteralPath $env:GITHUB_ENV -Value "CUSTODY_RUNTIME_SHA256=$runtimeHash"
    New-Item -ItemType Directory -Path (Join-Path $root 'evidence') -ErrorAction Stop | Out-Null
    Copy-Item -LiteralPath $runtimeFile -Destination (Join-Path $root 'evidence')
    $config=Join-Path $root 'NuGet.Config'
    foreach($name in @('watchdog','outer')) {
        $project=if($name -eq 'watchdog'){'CustodyWatchdog.csproj'}else{'Outer.csproj'}
        $proj=Join-Path (Join-Path $root $name) $project
        foreach($record in $records) { Assert-RuntimeMatches $record }
        & $dotnet restore $proj --configfile $config --disable-build-servers -nodeReuse:false
        if ($LASTEXITCODE -ne 0) { throw 'offline_restore_failed' }
        foreach($record in $records) { Assert-RuntimeMatches $record }
        & $dotnet build $proj --no-restore --configuration Release --disable-build-servers -nodeReuse:false -p:UseSharedCompilation=false
        if ($LASTEXITCODE -ne 0) { throw 'watchdog_build_failed' }
    }
    $outer=Join-Path $root 'outer\bin\Release\net8.0\Outer.dll'
    $inner=Join-Path $root 'watchdog\bin\Release\net8.0\CustodyWatchdog.dll'
    $manifest=Join-Path $root 'snapshot\manifest.json'
    $build=[ordered]@{schema=1;outer_sha256=(Get-FileHash -LiteralPath $outer -Algorithm SHA256).Hash.ToLowerInvariant();inner_sha256=(Get-FileHash -LiteralPath $inner -Algorithm SHA256).Hash.ToLowerInvariant();snapshot_manifest_sha256=(Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash.ToLowerInvariant();runtime_manifest_sha256=$runtimeHash}
    [IO.File]::WriteAllText((Join-Path $root 'build.json'),($build | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $root 'build.json') -Destination (Join-Path $root 'evidence')
} finally { Pop-Location }
