# Read-only local file metadata only; no BYOND, setup, encoder execution or policy changes.
param([Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference='Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
    $env:GITHUB_REPOSITORY -ne 'Civ13/Civ13' -or $env:GITHUB_RUN_ATTEMPT -ne '1' -or
    $env:GITHUB_REF -ne 'refs/heads/ci/cloud-directx-inventory-20261030-r1' -or
    $env:GITHUB_RUN_ID -notmatch '^[1-9][0-9]{0,19}$' -or $env:GITHUB_SHA -notmatch '^[0-9a-f]{40}$') { throw 'wrong_diagnostic_admission' }
if (-not [Environment]::Is64BitOperatingSystem -or -not [Environment]::Is64BitProcess) { throw 'unexpected_windows_architecture' }
$windows = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
if (-not [IO.Path]::IsPathFullyQualified($windows) -or $windows -notmatch '^[A-Za-z]:\\') { throw 'windows_root_unavailable' }
$expected = [ordered]@{
    'd3dx9_43.dll' = '0b28546be22c71834501f7d7185ede5d79742457331c7ee09efc14490dd64f5f'
    'D3DCompiler_43.dll' = '2f23182ec6f4889397ac4bf03d62536136c5bdba825c7d2c4ef08c827f3a8a1c'
}
function InspectFolder([string]$path, [string]$label) {
    $row=[ordered]@{name=$label;status='unknown';reparse=$null}
    try {
        $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
        $row.reparse=[bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
        $row.status=if ($item.PSIsContainer) {'directory'} else {'not_directory'}
    } catch [System.Management.Automation.ItemNotFoundException] { $row.status='missing' }
      catch [UnauthorizedAccessException] { $row.status='access_denied' }
      catch { $row.status='read_error'; $row.error_class=$_.Exception.GetType().Name }
    return $row
}
function InspectFile([string]$path, [string]$name, [string]$folder, [string]$expectedSha) {
    $row = [ordered]@{ name=$name; folder=$folder; status='unknown'; size=$null; sha256=$null; expected_x86_sha256=$expectedSha; expected_match=$null; pe_machine=$null; file_version=$null; executed=$false }
    $stream = $null
    try {
        $info = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($info.PSIsContainer -or ($info.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $row.status='not_regular_or_reparse'; return $row }
        if ($info.Length -gt 8388608) { $row.status='oversize'; $row.size=$info.Length; return $row }
        $stream = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        $row.size = $stream.Length
        $hash = [Security.Cryptography.SHA256]::Create()
        try { $row.sha256 = [Convert]::ToHexString($hash.ComputeHash($stream)).ToLowerInvariant() } finally { $hash.Dispose() }
        $row.expected_match = if ($folder -eq 'SysWOW64') { $row.sha256 -eq $expectedSha } else { $null }
        $stream.Position=0
        $reader=[IO.BinaryReader]::new($stream,[Text.Encoding]::UTF8,$true)
        try {
            if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) { $row.status='not_pe'; return $row }
            $stream.Position=0x3c; $offset=$reader.ReadUInt32()
            if ($offset -gt $stream.Length-6) { $row.status='invalid_pe_offset'; return $row }
            $stream.Position=$offset
            if ($reader.ReadUInt32() -ne 0x4550) { $row.status='invalid_pe_header'; return $row }
            $row.pe_machine=('0x{0:x4}' -f $reader.ReadUInt16())
        } finally { $reader.Dispose() }
        try { $row.file_version = [Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileVersion }
        catch { $row.version_error = $_.Exception.GetType().Name }
        $row.status='read'
    } catch [System.Management.Automation.ItemNotFoundException] { $row.status='missing' }
      catch [IO.FileNotFoundException] { $row.status='missing' }
      catch [IO.DirectoryNotFoundException] { $row.status='missing_parent' }
      catch [UnauthorizedAccessException] { $row.status='access_denied' }
      catch { $row.status='read_error'; $row.error_class=$_.Exception.GetType().Name }
    finally { if ($null -ne $stream) { $stream.Dispose() } }
    return $row
}
$dlls = @()
$folders=@(InspectFolder ([IO.Path]::GetPathRoot($windows)) 'drive_root'; InspectFolder $windows 'windows_root')
foreach ($folder in @('SysWOW64','System32')) {
    $folders += InspectFolder (Join-Path $windows $folder) $folder
    foreach ($name in $expected.Keys) {
        $dlls += InspectFile (Join-Path (Join-Path $windows $folder) $name) $name $folder $expected[$name]
    }
}
$encoder=[ordered]@{ status='not_found_on_path'; executed=$false; provenance_verified=$false }
try {
    $cmd=Get-Command -Name 'ffmpeg.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
        $p=$cmd.Source
        if ($p -notmatch '^[A-Za-z]:\\') { $encoder.status='nonlocal_candidate_rejected' }
        else {
            $f=Get-Item -LiteralPath $p -Force -ErrorAction Stop
            if ($f.PSIsContainer -or ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $f.Length -gt 268435456) { $encoder.status='unsafe_candidate_rejected' }
            else { $encoder=[ordered]@{status='candidate_only';path=$f.FullName;bytes=$f.Length;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant();file_version=$f.VersionInfo.FileVersion;executed=$false;provenance_verified=$false} }
        }
    }
} catch { $encoder=[ordered]@{status='inventory_error';error_class=$_.Exception.GetType().Name;executed=$false;provenance_verified=$false} }
$result=[ordered]@{schema=1;kind='read_only_windows_dependency_inventory';head=$env:GITHUB_SHA;run_id=$env:GITHUB_RUN_ID;attempt=1;process_64bit=$true;os_64bit=$true;folders=$folders;dlls=$dlls;encoder=$encoder;native_game_executed=$false;installer_executed=$false;firewall_changed=$false}
$raw=[Text.Encoding]::UTF8.GetBytes(($result | ConvertTo-Json -Depth 8 -Compress)+"`n")
if ($raw.Length -gt 16384) { throw 'inventory_output_size_limit' }
$outputPath=[IO.Path]::GetFullPath($Output)
$temp=[IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
if (-not $outputPath.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($outputPath) -ne 'dll-inventory.json') { throw 'wrong_inventory_output' }
$stream=[IO.File]::Open($outputPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $stream.Write($raw,0,$raw.Length); $stream.Flush($true) } finally { $stream.Dispose() }
Write-Output ([Text.Encoding]::UTF8.GetString($raw))
