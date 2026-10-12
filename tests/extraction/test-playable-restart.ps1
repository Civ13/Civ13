# Offline guard tests: synthetic artifacts, no BYOND or client process launch.
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('extraction-restart-test-' + [guid]::NewGuid().ToString('N'))
$run = Join-Path ([IO.Path]::GetTempPath()) ('civ13-extraction-area-' + [guid]::NewGuid().ToString('N'))
$checks = 0
try {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'tests/extraction'),(Join-Path $fixture 'bin'),$run | Out-Null
    $launcher = Join-Path $fixture 'tests/extraction/run-playable.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'run-playable.ps1') -Destination $launcher
    foreach ($name in @('dm.exe','dd.exe')) { Set-Content -LiteralPath (Join-Path $fixture ('bin/' + $name)) -Value 'inert offline fixture' }
    & git -C $fixture init -q
    & git -C $fixture add .
    & git -C $fixture -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create offline provenance fixture' }
    $head = (& git -C $fixture rev-parse HEAD).Trim()
    foreach ($name in @('data','config','UI','SQL')) { New-Item -ItemType Directory -Path (Join-Path $run $name) | Out-Null }
    foreach ($name in @('area.dmb','area.rsc')) { Set-Content -LiteralPath (Join-Path $run $name) -Value 'inert artifact' }
    $manifest = @{ commit=$head; dirty=$false; visual=$true; city=$false; vehicle_world_save=$false; byond_bin=(Join-Path $fixture 'bin'); artifacts=@{} }
    foreach ($name in @('area.dmb','area.rsc')) { $manifest.artifacts[$name] = (Get-FileHash -LiteralPath (Join-Path $run $name)).Hash }
    function Save-Manifest { $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'invocation.json') }
    function Check-Guard([string]$expected, [string]$target = $run) {
        $caught = $null
        try { $result = & $launcher -ByondBin (Join-Path $fixture 'bin') -Visual -ResumeRunDirectory $target -ValidateRestartOnly } catch { $caught = $_.Exception.Message }
        if ($expected) {
            if (!$caught -or !$caught.Contains($expected)) { throw "Wrong rejection: expected $expected; got $caught" }
        } elseif ($caught -or ($result -join '') -notmatch '^PASS:') { throw "Valid offline restart rejected: $caught" }
        $script:checks++
    }
    Save-Manifest
    Check-Guard ''
    Check-Guard 'Restart target must be an original' $fixture
    $manifest.dirty = $true; Save-Manifest; Check-Guard 'Restart provenance'
    $manifest.dirty = $false
    $manifest.commit = 'wrong-commit'; Save-Manifest; Check-Guard 'Restart provenance'
    $manifest.commit = $head; $manifest.city = $true; Save-Manifest; Check-Guard 'Restart provenance'
    $manifest.city = $false; Save-Manifest
    Add-Content -LiteralPath (Join-Path $run 'area.dmb') -Value 'changed'; Check-Guard 'Restart artifact changed'
    Set-Content -LiteralPath (Join-Path $run 'area.dmb') -Value 'inert artifact'
    $manifest.artifacts.Remove('area.rsc'); Save-Manifest; Check-Guard 'Restart artifact changed'
    $manifest.artifacts['area.rsc'] = (Get-FileHash -LiteralPath (Join-Path $run 'area.rsc')).Hash; Save-Manifest
    Add-Content -LiteralPath $launcher -Value '# dirty fixture'; Check-Guard 'Restart provenance'
    Write-Output "PASS: $checks offline restart guards; no native processes launched"
} finally {
    foreach ($path in @($fixture,$run)) {
        $full = [IO.Path]::GetFullPath($path)
        $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
        if ([IO.Path]::GetDirectoryName($full) -ine $temp -or [IO.Path]::GetFileName($full) -notmatch '^(extraction-restart-test-|civ13-extraction-area-)[a-f0-9]{32}$') { throw 'Unsafe fixture cleanup path' }
        if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
    }
}
