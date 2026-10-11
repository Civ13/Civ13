param([Parameter(Mandatory=$true)][string]$ByondBin,[string]$Revision,[switch]$RequireReleasedSnapshot)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$sourcePath = 'code/modules/1713/machinery/conveyor2.dm'
if ($Revision) {
    $source = (& git -C $repo show "${Revision}:$sourcePath") -join "`n"
    if ($LASTEXITCODE) { throw 'Cannot read revision' }
    $commit = (& git -C $repo rev-parse $Revision)
} else {
    $source = Get-Content -LiteralPath (Join-Path $repo $sourcePath) -Raw
    $commit = (& git -C $repo rev-parse HEAD)
}
# Compile the actual production proc verbatim, with a minimal world and cargo.
$match = [regex]::Match($source, '(?ms)^/obj/machinery/conveyor/process\(\).*?(?=^// attack with item)')
if (!$match.Success) { throw 'Production process boundary not found' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-conveyor-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
$fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Raw
[IO.File]::WriteAllText((Join-Path $temp 'probe.dme'), $fixture + "`n" + $match.Value)
& (Join-Path $ByondBin 'dm.exe') (Join-Path $temp 'probe.dme') 2>&1 | Tee-Object -FilePath (Join-Path $temp 'compile.log')
if ($LASTEXITCODE -or !(Select-String -LiteralPath (Join-Path $temp 'compile.log') -Pattern '0 errors, 0 warnings' -Quiet)) { throw 'Fixture compilation failed' }
$process = $null
$samples = [Collections.Generic.List[object]]::new()
try {
    $process = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $temp 'probe.dmb'),'-invisible','-trusted','-log','runtime.log') -WorkingDirectory $temp -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    while (!$process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        $process.Refresh()
        if (!$process.HasExited) {
            $phase = 'startup'
            $phasePath = Join-Path $temp 'phase.txt'
            if (Test-Path -LiteralPath $phasePath) { $phase = Get-Content -LiteralPath $phasePath -Tail 1 }
            $samples.Add([pscustomobject]@{
                phase=$phase; utc=[DateTime]::UtcNow.ToString('o')
                private_bytes=$process.PrivateMemorySize64; working_set=$process.WorkingSet64
                cpu_ms=$process.TotalProcessorTime.TotalMilliseconds
            })
        }
        Start-Sleep -Milliseconds 200
    }
    if (!$process.HasExited) { throw 'Fixture timed out' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    $samples | Export-Csv -LiteralPath (Join-Path $temp 'memory.csv') -NoTypeInformation
}
$log = Get-Content -LiteralPath (Join-Path $temp 'runtime.log') -Raw
$summary = [ordered]@{commit=$commit;revision=$Revision;process_id=$process.Id;runtime=((Get-Content -LiteralPath (Join-Path $temp 'compile.log') -First 1).Trim());dirty_diff=(& git -C $repo diff --stat | Out-String).Trim();map="synthetic 32x32x1";source_sha256=(Get-FileHash -LiteralPath (Join-Path $temp 'probe.dme')).Hash;directory=$temp;peak_private_bytes=($samples | Measure-Object private_bytes -Maximum).Maximum;final_cpu_ms=($samples | Select-Object -Last 1).cpu_ms}
$summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'metadata.json')
$log | Write-Output
$summary | ConvertTo-Json | Write-Output
if ($log -match 'FAIL:|runtime error' -or $log -notmatch 'PHASE complete') { throw 'Runtime assertions failed or incomplete' }
if ($RequireReleasedSnapshot -and $log -notmatch 'retained_entries=0 ') { throw 'Snapshot references retained' }
