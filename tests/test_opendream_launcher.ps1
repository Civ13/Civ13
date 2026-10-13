# Actual production functions, injected process/state effects, temporary files only.
[CmdletBinding()]
param([ValidateSet('','Ancestor','StateWrite')][string]$NegativeControl = '')
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../scripts/opendream/Manage-Local.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) {throw 'Launcher syntax is invalid'}
$names = @('Assert-UnlinkedClientPath','Remove-OwnedClientRuntime','Start-VerifiedClient','Stop-LaunchedClient')
foreach ($name in $names) {
    $node = $ast.Find({param($entry) $entry -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $entry.Name -eq $name},$true)
    if (!$node) {throw "Missing production function: $name"}
    $body = $node.Extent.Text
    if ($NegativeControl -eq 'StateWrite' -and $name -eq 'Start-VerifiedClient') {
        $needle = 'if ($client) {Stop-LaunchedClient $client}'
        if (!$body.Contains($needle)) {throw 'State-write control cannot locate cleanup'}
        $body = $body.Replace($needle, '')
    }
    . ([scriptblock]::Create($body))
}
if ($NegativeControl -eq 'Ancestor') {function Assert-UnlinkedClientPath {}}
function Require([bool]$condition,[string]$message) {if (!$condition) {throw $message}}
function Expect-Failure([scriptblock]$operation,[string]$message) {
    $failed = $false
    try {& $operation} catch {$failed = $_.Exception.Message -like "*$message*"}
    Require $failed "Expected rejection: $message"
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $profile = Join-Path $temporary 'profile'
    $parent = Join-Path $profile 'client-runtime'
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $owned = Join-Path $parent ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $owned | Out-Null
    Set-Content -LiteralPath (Join-Path $owned 'settings') -Value 'owned fixture'
    $state = [pscustomobject]@{client=@{runtime=$owned}}
    Remove-OwnedClientRuntime
    Require (!(Test-Path -LiteralPath $owned)) 'Owned copy should be reclaimed'

    $external = Join-Path $temporary 'external'
    New-Item -ItemType Directory -Path $external | Out-Null
    $externalOwned = Join-Path $external ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $externalOwned | Out-Null
    Set-Content -LiteralPath (Join-Path $externalOwned 'keep') -Value 'external fixture'
    $originalParent = Join-Path $profile 'original-runtime'
    Move-Item -LiteralPath $parent -Destination $originalParent
    $linkType = if ($env:OS -eq 'Windows_NT') {'Junction'} else {'SymbolicLink'}
    New-Item -ItemType $linkType -Path $parent -Target $external | Out-Null
    $state.client = @{runtime=(Join-Path $parent ([IO.Path]::GetFileName($externalOwned)))}
    Expect-Failure {Remove-OwnedClientRuntime} 'ancestor'
    Require (Test-Path -LiteralPath (Join-Path $externalOwned 'keep')) 'Redirected parent must preserve external data'
    # Remove only the link before final test-fixture cleanup.
    (Get-Item -LiteralPath $parent -Force).Delete()
    Move-Item -LiteralPath $originalParent -Destination $parent

    function Start-ClientProcess {return $fakeClient}
    function Stop-ClientProcessTree($process) {
        Require ($process -eq $fakeClient) 'Stop must use the returned launch handle'
        $script:stopped = $true
    }
    function Save-ClientState {
        $script:writes++
        if ($script:writes -eq 1) {throw 'injected state-write failure'}
    }
    $fakeClient = [pscustomobject]@{Id=123;Path='fake-dotnet';StartTime=[DateTime]::Now;HasExited=$false}
    $fakeClient | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
        param($milliseconds)
        if (!$script:stopped) {throw 'Cleanup attempted before process termination'}
        return $true
    }
    $script:stopped = $false; $script:writes = 0
    $owned = Join-Path $parent ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $owned | Out-Null
    $verified = [pscustomobject]@{loader='fake-loader';root=$owned;webview='fake-webview';staging_root=$owned}
    $trial = 'fake-trial'
    $settings = [pscustomobject]@{native_byond_bin='fake-byond';native_observer_directory='fake-observer'}
    $configuration = [pscustomobject]@{game_port=18452}
    $state.client = $null
    $oldOverride = $env:ROBUST_CVAR_LAUNCHER_TEST
    $env:ROBUST_CVAR_LAUNCHER_TEST = 'fixture'
    try {
        Expect-Failure {Start-VerifiedClient $verified} 'injected state-write failure'
        Require $script:stopped 'Failed record write must stop exact launched client'
        Require ($script:writes -eq 2) 'Recovery must attempt to persist cleared ownership'
        Require (!$state.client) 'Failed launch must clear client state after confirmed exit'
        Require (!(Test-Path -LiteralPath $owned)) 'Failed launch must reclaim its runtime after exit'
        Require ($env:ROBUST_CVAR_LAUNCHER_TEST -eq 'fixture') 'Calling environment must be restored'
    } finally {$env:ROBUST_CVAR_LAUNCHER_TEST = $oldOverride}
    Write-Output 'PASS production launcher ownership, redirected-parent rejection and state-write recovery (injected effects)'
} finally {
    $resolved = [IO.Path]::GetFullPath($temporary)
    if ([IO.Path]::GetDirectoryName($resolved) -ne [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar) -or [IO.Path]::GetFileName($resolved) -notmatch '^[0-9a-f]{32}$') {throw 'Unsafe fixture cleanup target'}
    # The test's owned link was explicitly removed; never traverse it on failure.
    if ($parent -and (Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {(Get-Item -LiteralPath $parent -Force).Delete()}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
