[CmdletBinding()]
param([switch]$SelfTestOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1/.NET Framework supplies these assemblies and its C# compiler.
# There is no package restore, dependency installation or third-party executable.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'OwnedScreenProbe.cs') -ReferencedAssemblies System.dll, System.Windows.Forms.dll, System.Drawing.dll
$controls = [OwnedScreenProbe]::SelfTest()
if ($controls -ne 7) { throw 'Validator self-test count mismatch.' }
if ($SelfTestOnly) { Write-Output 'PASS: 7 synthetic pixel-validator controls; no desktop probe.'; exit 0 }

# Prevent accidental execution on a user workstation. Workflow source/runner selection
# is the real trust boundary; these environment checks are not an attestation service.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
    $env:RUNNER_OS -ne 'Windows' -or $env:GITHUB_REPOSITORY -ne 'Civ13/Civ13' -or
    $env:GITHUB_REF -ne 'refs/heads/ci/windows-render-preflight-20261025' -or
    $env:GITHUB_RUN_ATTEMPT -ne '1') { throw 'Only the reviewed hosted-runner invocation is admitted.' }
if ($env:GITHUB_SHA -notmatch '^[0-9a-f]{40}$' -or $env:GITHUB_RUN_ID -notmatch '^[0-9]+$') { throw 'Invalid CI provenance.' }
$output = Join-Path $env:RUNNER_TEMP 'owned-desktop-preflight'
if (Test-Path -LiteralPath $output) { throw 'Evidence directory must be fresh; no overwrite or retry.' }
New-Item -ItemType Directory -Path $output | Out-Null

function Read-WebViewRegistration([Microsoft.Win32.RegistryHive]$Hive) {
    $base = $null; $key = $null
    try {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, [Microsoft.Win32.RegistryView]::Registry32)
        $key = $base.OpenSubKey('SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', $false)
        if ($null -eq $key) { return @{ status = 'not_registered'; view = 'Registry32' } }
        $version = [string]$key.GetValue('pv', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($version -notmatch '^\d{1,5}(\.\d{1,5}){3}$' -or $version -eq '0.0.0.0') {
            return @{ status = 'no_valid_version'; view = 'Registry32' }
        }
        return @{ status = 'registered'; version = $version; view = 'Registry32' }
    } catch { return @{ status = 'read_unavailable'; view = 'Registry32' } }
    finally { if ($null -ne $key) { $key.Dispose() }; if ($null -ne $base) { $base.Dispose() } }
}
function Read-X86Runtime([string]$Name) {
    $stream = $null; $reader = $null
    try {
        $path = Join-Path (Join-Path $env:WINDIR 'SysWOW64') $Name
        # Open once, read at most the bounded PE-header locations; never load a DLL.
        $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $reader = New-Object System.IO.BinaryReader($stream)
        if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) { throw 'Not PE.' }
        $stream.Position = 0x3c; $offset = $reader.ReadUInt32()
        if ($offset -lt 64 -or $offset -gt 4096 -or ($offset + 6) -gt $stream.Length) { throw 'PE header out of bounds.' }
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x4550) { throw 'Not PE.' }
        $machine = $reader.ReadUInt16()
        return @{ name = $Name; status = 'header_read'; machine = ('0x{0:x4}' -f $machine); is_x86 = ($machine -eq 0x14c) }
    } catch [System.IO.FileNotFoundException] { return @{ name = $Name; status = 'not_present' } }
      catch [System.IO.DirectoryNotFoundException] { return @{ name = $Name; status = 'not_present' } }
      catch { return @{ name = $Name; status = 'read_unavailable_or_invalid' } }
    finally { if ($null -ne $reader) { $reader.Dispose() }; if ($null -ne $stream) { $stream.Dispose() } }
}

$receipt = [ordered]@{
    schema = 1
    scope = 'owned-native-window-screen-capture-only'
    head = $env:GITHUB_SHA
    run_id = $env:GITHUB_RUN_ID
    run_attempt = 1
    validator_controls = $controls
    workflow_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath '.github/workflows/windows-render-preflight.yml').Hash.ToLowerInvariant()
    script_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
    native_source_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot 'OwnedScreenProbe.cs')).Hash.ToLowerInvariant()
    dependency_inventory = @{
        webview2_machine = (Read-WebViewRegistration ([Microsoft.Win32.RegistryHive]::LocalMachine))
        webview2_user = (Read-WebViewRegistration ([Microsoft.Win32.RegistryHive]::CurrentUser))
        webview2_note = 'Registry32 detection only; no 32-bit loader or browser compatibility test.'
        vc_x86_files = @('msvcr120.dll', 'msvcp120.dll', 'mfc120u.dll', 'vcruntime140.dll', 'msvcp140.dll', 'vcruntime140_1.dll' | ForEach-Object { Read-X86Runtime $_ })
    }
    probe = [OwnedScreenProbe]::Run($output)
    image_sha256 = @{}
}
# Only exact validated patterns can have been serialized by the C# probe.
foreach ($name in @('red-blue.png', 'cyan-yellow.png')) {
    $path = Join-Path $output $name
    if (Test-Path -LiteralPath $path) { $receipt.image_sha256[$name] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
}
if ($receipt.probe.status -eq 'passed_owned_screen_capture' -and
    ($receipt.image_sha256.Count -ne 2 -or $receipt.image_sha256['red-blue.png'] -eq $receipt.image_sha256['cyan-yellow.png'])) {
    $receipt.probe.status = 'probe_error'; $receipt.probe.reason = 'image_pair_missing_or_identical'
}
$json = $receipt | ConvertTo-Json -Depth 8
if ($json.Length -gt 32768) { throw 'Receipt exceeds its output bound.' }
[System.IO.File]::WriteAllText((Join-Path $output 'receipt.json'), $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
$line = 'status={0}; reason={1}; synthetic_controls={2}; captures={3}; owned_window_closed={4}' -f $receipt.probe.status, $receipt.probe.reason, $controls, $receipt.probe.capture_count, $receipt.probe.owned_window_closed
[System.IO.File]::WriteAllText((Join-Path $output 'probe.log'), $line + "`n", (New-Object System.Text.UTF8Encoding($false)))
$allowed = @('receipt.json', 'probe.log', 'red-blue.png', 'cyan-yellow.png')
$files = @(Get-ChildItem -LiteralPath $output -Force)
if ($files.Count -gt 4) { throw 'Unexpected artifact count.' }
foreach ($file in $files) {
    if ($file.PSIsContainer -or $file.Name -notin $allowed -or $file.Length -gt 65536 -or
        ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { throw 'Unexpected artifact data; upload refused.' }
}
# This output is set only after validating the bounded, allowlisted artifact directory.
Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value 'evidence_ready=true' -Encoding utf8
Write-Output $line
if ($receipt.probe.status -ne 'passed_owned_screen_capture') { exit 2 }
