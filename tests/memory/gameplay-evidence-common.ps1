function Read-EvidenceQueryResult {
    param([string]$Path, [string]$ExpectedCommit, [string]$Action)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing query result: $Path" }
    $text = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($text)) { throw "Empty query response: $Path" }
    try { $response = $text | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Invalid JSON query response: $Path" }
    if (!$response -or $response.commit -cne $ExpectedCommit) { throw "Query response does not match the tested commit: $Path" }
    if ($Action -eq 'run') {
        if ($response.PSObject.Properties.Name -contains 'passed') {
            if ($response.passed -ne 1) { throw "Gameplay check failed: $Path" }
        }
        elseif ($response.season -notin @('SPRING','SUMMER','FALL','WINTER')) {
            throw "Missing gameplay check outcome: $Path"
        }
    }
    return $response
}

function Get-EvidenceCheckoutCommit {
    param([string]$Repository)
    $commitOutput = git -C $Repository rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot determine checkout commit' }
    $commit = "$commitOutput".Trim()
    if ($commit -notmatch '^[a-f0-9]{40}$') { throw 'Invalid checkout commit' }
    $status = git -C $Repository status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'Cannot determine checkout status' }
    if ($status) { throw 'Use a clean committed checkout for evidence' }
    return $commit
}

function Remove-EvidenceBuildOutputs {
    param([string]$Environment, [string]$Repository)
    $path = [IO.Path]::GetFullPath($Environment)
    if ([IO.Path]::GetDirectoryName($path) -ne [IO.Path]::GetFullPath($Repository) -or
        [IO.Path]::GetFileName($path) -notmatch '^\.memory-evidence-[a-f0-9]{32}\.dme$') {
        throw 'Refusing cleanup outside the generated evidence build'
    }
    foreach ($extension in @('dme','dmb','rsc')) {
        $output = [IO.Path]::ChangeExtension($path,$extension)
        if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
    }
}

function Wait-EvidenceServerReady {
    param(
        $Process, [scriptblock]$StatusQuery, [string]$ExpectedCommit,
        [int]$TimeoutMilliseconds = 120000, [int]$PollMilliseconds = 1000
    )
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $lastError = 'No response'
    while ($watch.ElapsedMilliseconds -lt $TimeoutMilliseconds) {
        $Process.Refresh()
        if ($Process.HasExited) { throw "Evidence server exited before readiness (exit $($Process.ExitCode))" }
        try {
            $response = & $StatusQuery
            if ($response.commit -cne $ExpectedCommit -or !$response.map -or
                @($response.dimensions).Count -ne 3 -or
                $response.PSObject.Properties.Name -notcontains 'state') {
                throw 'Invalid readiness response'
            }
            $Process.Refresh()
            if ($Process.HasExited) { throw 'Evidence server exited after its status response' }
            return $response
        }
        catch { $lastError = $_.Exception.Message }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
    throw "Evidence server readiness timed out: $lastError"
}
