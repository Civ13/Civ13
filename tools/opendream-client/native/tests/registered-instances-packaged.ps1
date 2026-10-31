[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$FixtureParent
)
$ErrorActionPreference = 'Stop'
$exe = [IO.Path]::GetFullPath($Executable)
$parent = [IO.Path]::GetFullPath($FixtureParent).TrimEnd('\')
if (!(Test-Path -LiteralPath $exe -PathType Leaf) -or
    !$parent.StartsWith('D:\', [StringComparison]::OrdinalIgnoreCase) -or
    !(Test-Path -LiteralPath $parent -PathType Container)) {
    throw 'Packaged test requires an existing launcher and an explicit synthetic D: fixture parent.'
}
$fixture = [IO.Path]::GetFullPath((Join-Path $parent ('civ13-registration-fixture-' + [guid]::NewGuid().ToString('N'))))
if (!$fixture.StartsWith($parent + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped its parent.' }
$catalog = Join-Path $fixture 'catalog.json'
$created = $false
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $created = $true
    $example = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../../server-management/instance.example.json') -Raw | ConvertFrom-Json
    $payload = @{ schema = 'civ13.catalog.v1'; instances = @($example) } | ConvertTo-Json -Depth 8 -Compress
    [IO.File]::WriteAllText($catalog, $payload, [Text.UTF8Encoding]::new($false))

    $help = @(& $exe --help 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or !$help.Contains('--registered-instances') -or
        !$help.Contains('inspect the displayed status for freshness') -or
        !$help.Contains('launcher is optional for BYOND gameplay')) {
        throw 'Packaged help omitted the operator view or its status and gameplay limits.'
    }
    $output = @(& $exe --registered-instances $fixture $catalog 'example-host' 2>&1)
    $code = $LASTEXITCODE
    $text = $output -join "`n"
    if ($code -ne 0 -or !$text.Contains('Example Civ13 instance') -or
        !$text.Contains('no explicit process target was supplied') -or
        !$text.Contains('Ownership and backend readiness are unverified') -or
        $text.Contains('PID:') -or $text.Contains($fixture)) {
        throw 'Packaged registration success did not retain unknown process and ownership state.'
    }
    $output = @(& $exe --registered-instances 2>&1)
    if ($LASTEXITCODE -ne 1 -or !(($output -join "`n").Contains('Usage: --registered-instances'))) {
        throw 'Packaged malformed entrypoint did not fail closed.'
    }
    [IO.File]::WriteAllText($catalog, '{bad', [Text.UTF8Encoding]::new($false))
    $output = @(& $exe --registered-instances $fixture $catalog 'example-host' 2>&1)
    $text = $output -join "`n"
    if ($LASTEXITCODE -ne 1 -or !$text.Contains('Registration status: Invalid') -or
        !$text.Contains('Registered instances remain unknown') -or $text.Contains($fixture)) {
        throw 'Packaged invalid catalog did not retain unknown registration state.'
    }
    Write-Output 'PASS packaged registration view: synthetic catalog parsed; process and ownership remain unknown; malformed input refused.'
} finally {
    # Only the unique directory created by this invocation, inside the checked parent.
    if ($created -and (Test-Path -LiteralPath $fixture)) {
        $resolved = (Resolve-Path -LiteralPath $fixture).Path
        if (!$resolved.Equals($fixture, [StringComparison]::OrdinalIgnoreCase) -or
            !$resolved.StartsWith($parent + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Fixture cleanup refused: resolved path changed.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
# GitHub Actions propagates LASTEXITCODE after the script. The final negative
# control must return 1 from the launcher, but the completed fixture succeeded.
exit 0
