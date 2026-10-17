param(
    [Parameter(Mandatory)][string]$ByondBin,
    [string]$OutputRoot = [IO.Path]::GetTempPath(),
    [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$ByondBin = (Resolve-Path -LiteralPath $ByondBin).Path
$run = Join-Path $OutputRoot ('cid-comparison-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run | Out-Null
$expected = & 'C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'get-cid.ps1') -ByondBin $ByondBin
if ($LASTEXITCODE -ne 0 -or "$expected" -notmatch '^\d+$') { throw 'CID acquisition failed' }
$supplied = if ($NegativeControl) { '0' } else { "$expected" }
if ($NegativeControl -and "$expected" -eq $supplied) { throw 'Negative control would equal the acquired CID' }
Copy-Item -LiteralPath (Join-Path $root 'probe.dme') -Destination $run
$build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 (Join-Path $run 'probe.dme') 2>&1
$build | Set-Content -LiteralPath (Join-Path $run 'compile.log')
if ($LASTEXITCODE -ne 0 -or "$build" -notmatch '0 errors, 0 warnings') { throw 'Compilation failed' }
$portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$port = $portProbe.LocalEndpoint.Port
$portProbe.Stop()
$server = $null
$client = $null
try {
    $server = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @('probe.dmb', "$port", '-invisible', '-trusted', '-params', "expected=$supplied", '-log', 'runtime.log') -WorkingDirectory $run -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (!(Test-Path -LiteralPath (Join-Path $run 'ready.txt'))) {
        if ($server.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Server not ready' }
        Start-Sleep -Milliseconds 100
    }
    $client = Start-Process -FilePath (Join-Path $ByondBin 'dreamseeker.exe') -ArgumentList @("byond://127.0.0.1:$port") -WorkingDirectory $run -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(35)
    while (!(Test-Path -LiteralPath (Join-Path $run 'result.json'))) {
        if ($server.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'No client CID receipt' }
        Start-Sleep -Milliseconds 200
    }
    $result = Get-Content -LiteralPath (Join-Path $run 'result.json') -Raw | ConvertFrom-Json
    if ($result.expected -cne $supplied -or $result.observed -cne "$expected" -or $result.version -ne 516 -or $result.build -ne 1681) { throw 'Unexpected CID receipt or client version' }
    if ($NegativeControl) {
        if ($result.match) { throw 'Incorrect expected CID was accepted' }
    } elseif (!$result.match) { throw 'CID mismatch' }
    $runtimeLog = Get-Content -LiteralPath (Join-Path $run 'runtime.log') -Raw
    if ($runtimeLog -match 'runtime error:|Bad ref|fatal error') { throw 'Runtime diagnostics invalidate the comparison' }
    @{negative_control=[bool]$NegativeControl; acquired="$expected"; server=$result; source_hashes=@{reader=(Get-FileHash -LiteralPath (Join-Path $root 'get-cid.ps1')).Hash; fixture=(Get-FileHash -LiteralPath (Join-Path $run 'probe.dme')).Hash; runner=(Get-FileHash -LiteralPath $PSCommandPath).Hash}} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $run 'verification.json')
    $result | ConvertTo-Json -Compress
    Write-Output "Evidence: $run"
} finally {
    foreach ($process in @($client, $server)) {
        if ($process -and !$process.HasExited) {
            Stop-Process -Id $process.Id
            $process.WaitForExit(5000) | Out-Null
        }
    }
    @{server_pid=if($server){$server.Id}else{$null}; client_pid=if($client){$client.Id}else{$null}; server_exited=(!$server -or $server.HasExited); client_exited=(!$client -or $client.HasExited)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'cleanup.json')
}
