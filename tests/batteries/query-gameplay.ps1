param(
    [Parameter(Mandatory=$true)][string]$SessionJson,
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [ValidateSet('status','prepare','join','run','charge','discharge','cut','examine')][string]$Action='status',
    [ValidateSet(1,2,4,8)][int]$Direction=1
)
$ErrorActionPreference='Stop'
$session=Get-Content -LiteralPath $SessionJson -Raw | ConvertFrom-Json
$run=Join-Path $session.run ('query-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run | Out-Null
$topic='battery-evidence='+$session.nonce+'&action='+$Action+'&direction='+$Direction
$source=@"
/world
    maxx = 1
    maxy = 1
/world/New()
    var/response = world.Export("127.0.0.1:$($session.port)#$topic")
    text2file("[response]", "result.json")
    del(world)
    return
"@
$dm=Join-Path $run 'query.dm'
[IO.File]::WriteAllText($dm,$source)
$build=& (Join-Path $ByondBin 'dm.exe') $dm 2>&1
$build | Set-Content -LiteralPath (Join-Path $run 'build.log')
if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Query compilation failed' }
$process=Start-Process -FilePath (Join-Path $ByondBin 'dreamdaemon.exe') -ArgumentList @((Join-Path $run 'query.dmb'),'-invisible','-trusted','-logself','-close') -WorkingDirectory $run -WindowStyle Hidden -PassThru
if (!$process.WaitForExit(15000)) { Stop-Process -Id $process.Id; throw "Query timeout: $run" }
$result=Join-Path $run 'result.json'
if (!(Test-Path -LiteralPath $result)) { throw "Missing query result: $run" }
$raw = Get-Content -LiteralPath $result -Raw
if ([string]::IsNullOrWhiteSpace($raw)) { throw "Empty query result: $run" }
try { $reply = $raw | ConvertFrom-Json } catch { throw "Non-JSON query result: $run" }
if ($reply.commit -ne $session.commit) { throw "Evidence commit mismatch: $run" }
$raw
Write-Output "QUERY_RESULT=$result"
