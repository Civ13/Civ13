$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'gameplay-evidence-common.ps1')
$root = Join-Path ([IO.Path]::GetTempPath()) ('civ13-evidence-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$sha = 'a' * 40
$result = Join-Path $root 'result.json'
$script:checks = 0
function Assert-Rejected([scriptblock]$Action, [string]$Message) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    if (!$rejected) { throw "Expected rejection: $Message" }
    $script:checks++
}
foreach ($text in @('', ' ', 'LOCAL ONLY', 'null', '{"commit":"wrong","passed":1}')) {
    [IO.File]::WriteAllText($result,$text)
    Assert-Rejected { Read-EvidenceQueryResult $result $sha 'status' } 'empty, invalid or wrong-world response'
}
foreach ($outcome in @('false','0','null')) {
    [IO.File]::WriteAllText($result,('{"commit":"' + $sha + '","passed":' + $outcome + '}'))
    Assert-Rejected { Read-EvidenceQueryResult $result $sha 'run' } 'failed run'
}
[IO.File]::WriteAllText($result,('{"commit":"' + $sha + '","client":0}'))
Assert-Rejected { Read-EvidenceQueryResult $result $sha 'run' } 'missing run outcome'
foreach ($suffix in @('"passed":1','"passed":true','"season":"SPRING"')) {
    [IO.File]::WriteAllText($result,('{"commit":"' + $sha + '",' + $suffix + '}'))
    $null = Read-EvidenceQueryResult $result $sha 'run'
    $script:checks++
}
# Inject only the native Git adapter so status failure cannot look like a clean checkout.
function git {
    param([Parameter(ValueFromRemainingArguments=$true)]$Arguments)
    if ($Arguments -contains 'status') { $global:LASTEXITCODE = 128; return }
    $global:LASTEXITCODE = 0
    return ('a' * 40)
}
Assert-Rejected { Get-EvidenceCheckoutCommit $root } 'failed native status'
Remove-Item Function:git
$environment = Join-Path $root ('.memory-evidence-' + [guid]::NewGuid().ToString('N') + '.dme')
$sentinel = Join-Path $root 'unrelated.dmb'
[IO.File]::WriteAllText($sentinel,'preserve')
try {
    foreach ($ext in @('dme','dmb','rsc')) { [IO.File]::WriteAllText([IO.Path]::ChangeExtension($environment,$ext),'generated') }
    throw 'Simulated second-copy failure'
}
catch {}
finally { Remove-EvidenceBuildOutputs $environment $root }
foreach ($ext in @('dme','dmb','rsc')) {
    if (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($environment,$ext))) { throw 'Generated build output retained after failure' }
}
if (!(Test-Path -LiteralPath $sentinel)) { throw 'Unrelated file removed' }
$script:checks++
Assert-Rejected { Remove-EvidenceBuildOutputs $sentinel $root } 'unsafe cleanup target'
$process = [pscustomobject]@{HasExited=$false;ExitCode=1}
$process | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
$script:attempts = 0
$query = {
    $script:attempts++
    if ($script:attempts -eq 1) { throw 'Not yet ready' }
    [pscustomobject]@{commit=$sha;map='fixture';dimensions=@(1,1,1);state=1}
}
$null = Wait-EvidenceServerReady $process $query $sha -TimeoutMilliseconds 500 -PollMilliseconds 1
if ($script:attempts -ne 2) { throw 'Readiness did not retry' }
$script:checks++
$process.HasExited = $true
Assert-Rejected { Wait-EvidenceServerReady $process $query $sha -TimeoutMilliseconds 20 -PollMilliseconds 1 } 'server exit'
$process.HasExited = $false
Assert-Rejected { Wait-EvidenceServerReady $process { $null } $sha -TimeoutMilliseconds 20 -PollMilliseconds 1 } 'readiness timeout'
Write-Output "PASS gameplay evidence contracts: $script:checks cases. Temporary fixtures: $root"
