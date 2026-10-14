[CmdletBinding()]
param([string]$InstallRoot, [string]$ManifestPath, [string]$ArchivePath)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($ManifestPath) { $channel = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json }
else { $channel = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Civ13/Civ13/master/tools/opendream-client/launcher-channel.json' -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json }
$uri = [uri]$channel.url
if ($channel.schema -ne 1 -or $channel.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com' -or !$uri.AbsolutePath.StartsWith('/Civ13/Civ13/releases/download/', [StringComparison]::Ordinal)) { throw 'Invalid launcher update channel.' }
$destination = Join-Path $InstallRoot ('Launchers/' + $channel.sha256.ToLowerInvariant())
if (!(Test-Path -LiteralPath (Join-Path $destination 'ready.txt'))) {
 New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
 $lock = [IO.File]::Open((Join-Path $InstallRoot 'launcher-update.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
 try {
  if (!(Test-Path -LiteralPath (Join-Path $destination 'ready.txt'))) {
   $stage = Join-Path $InstallRoot ('launcher-stage-' + [guid]::NewGuid().ToString('N'))
   New-Item -ItemType Directory -Path $stage | Out-Null
   if (!$ArchivePath) { $ArchivePath = Join-Path $stage 'launcher.zip'; Invoke-WebRequest -Uri $channel.url -OutFile $ArchivePath -UseBasicParsing -TimeoutSec 60 }
   if ((Get-FileHash -LiteralPath $ArchivePath).Hash -ne $channel.sha256) { throw 'Launcher checksum failed.' }
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
   $allowed = @('Civ13.cmd','Launcher.ps1','Install-Client.ps1','Update-Launcher.ps1','channel.json','LAUNCHER-README.txt')
   try {
    if ($zip.Entries.Count -ne $allowed.Count) { throw 'Unexpected launcher archive entries.' }
    $seen = @{}
    foreach ($entry in $zip.Entries) {
     if ($entry.FullName -cnotin $allowed -or $seen.ContainsKey($entry.FullName)) { throw 'Unsafe launcher archive entry.' }
     $seen[$entry.FullName] = $true
     [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $stage $entry.FullName))
    }
   } finally { $zip.Dispose() }
   New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
   Move-Item -LiteralPath $stage -Destination $destination
   Set-Content -LiteralPath (Join-Path $destination 'ready.txt') -Value $channel.sha256
  }
 } finally { $lock.Dispose() }
}
return (Join-Path $destination 'Launcher.ps1')
