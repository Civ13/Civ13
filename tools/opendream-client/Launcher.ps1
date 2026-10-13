[CmdletBinding()]
param(
 [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Civ13'),
 [string]$ManifestUrl = 'https://raw.githubusercontent.com/Civ13/Civ13/master/tools/opendream-client/channel.json',
 [string]$ManifestPath,
 [string]$ArchivePath,
 [switch]$InstallOnly
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Read-Channel {
 if ($ManifestPath) { return Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json }
 try {
  Write-Host 'Checking Civ13 client updates...'
  return (Invoke-WebRequest -Uri $ManifestUrl -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
 } catch {
  Write-Host 'Update check unavailable. Using the bundled verified client version.'
  $cached = Join-Path $InstallRoot 'last-channel.json'
  if (Test-Path -LiteralPath $cached) { return Get-Content -LiteralPath $cached -Raw | ConvertFrom-Json }
  return Get-Content -LiteralPath (Join-Path $PSScriptRoot 'channel.json') -Raw | ConvertFrom-Json
 }
}
function Test-Channel($channel) {
 if ($channel.schema -ne 1 -or $channel.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid client update manifest.' }
 $uri = [uri]$channel.url
 if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com' -or !$uri.AbsolutePath.StartsWith('/Civ13/Civ13/releases/download/', [StringComparison]::Ordinal)) { throw 'Update must be a Civ13 GitHub release.' }
}
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
# Exclusive lock covers download, validation and installation. Separate launchers cannot race.
$lock = $null
try {
 try { $lock = [IO.File]::Open((Join-Path $InstallRoot 'launcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
 catch { throw 'Another Civ13 launcher is updating. Wait for it to finish.' }
 $channel = Read-Channel
 Test-Channel $channel
 $destination = Join-Path $InstallRoot ('OpenDream-' + $channel.sha256.Substring(0,12).ToLowerInvariant())
 Write-Host "Client version: $($channel.version)"
 & (Join-Path $PSScriptRoot 'Install-Client.ps1') -DownloadUrl $channel.url -ExpectedSha256 $channel.sha256 -InstallRoot $InstallRoot -ArchivePath $ArchivePath -NoShortcuts
 $channel | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallRoot 'last-channel.json')
 # Installation is side by side: running clients and account settings are never overwritten.
} finally { if ($lock) { $lock.Dispose() } }
if ($InstallOnly) { return }
while ($true) {
 Write-Host ''
 Write-Host 'Civ13 - 1: Sign in   2: Play Nomads   3: Play TDM   4: Exit'
 $choice = Read-Host 'Choose a number (sign in before your first game)'
 $file = switch ($choice) { '1' {'Sign-In.cmd'} '2' {'Play-Nomads.cmd'} '3' {'Play-TDM.cmd'} '4' {return} default {$null} }
 if ($file) { Start-Process -FilePath (Join-Path $destination $file) -WorkingDirectory $destination }
}

