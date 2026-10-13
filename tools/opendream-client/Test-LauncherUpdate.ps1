$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('civ13-launcher-update-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$root/package" -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
 foreach ($name in @('Civ13.cmd','Launcher.ps1','Install-Client.ps1','Update-Launcher.ps1','channel.json','LAUNCHER-README.txt')) { Set-Content -LiteralPath "$root/package/$name" -Value 'fixture - never executed' }
 [IO.Compression.ZipFile]::CreateFromDirectory("$root/package", "$root/launcher.zip")
 $channel = @{schema=1;url='https://github.com/Civ13/Civ13/releases/download/test/launcher.zip';sha256=(Get-FileHash "$root/launcher.zip").Hash}
 $channel | ConvertTo-Json | Set-Content "$root/channel.json"
 $args = @{InstallRoot="$root/install";ManifestPath="$root/channel.json";ArchivePath="$root/launcher.zip"}
 $first = & "$PSScriptRoot/Update-Launcher.ps1" @args
 $second = & "$PSScriptRoot/Update-Launcher.ps1" @args
 if ($first -ne $second -or !(Test-Path -LiteralPath $first)) { throw 'Repeat installation failed' }
 $channel.sha256='0'*64; $channel | ConvertTo-Json | Set-Content "$root/channel.json"
 $rejected=$false; try { & "$PSScriptRoot/Update-Launcher.ps1" @args } catch {$rejected=$true}; if (!$rejected) {throw 'Checksum negative failed'}
 $channel.url='https://example.com/launcher.zip'; $channel | ConvertTo-Json | Set-Content "$root/channel.json"
 $rejected=$false; try { & "$PSScriptRoot/Update-Launcher.ps1" @args } catch {$rejected=$true}; if (!$rejected) {throw 'Origin negative failed'}
 Set-Content -LiteralPath "$root/package/unexpected.ps1" -Value 'never execute'
 [IO.Compression.ZipFile]::CreateFromDirectory("$root/package", "$root/unsafe.zip")
 $channel.url='https://github.com/Civ13/Civ13/releases/download/test/launcher.zip'; $channel.sha256=(Get-FileHash "$root/unsafe.zip").Hash
 $channel | ConvertTo-Json | Set-Content "$root/channel.json"; $args.ArchivePath="$root/unsafe.zip"
 $rejected=$false; try { & "$PSScriptRoot/Update-Launcher.ps1" @args } catch {$rejected=$true}; if (!$rejected) {throw 'Archive negative failed'}
 Write-Host 'PASS: launcher install/repeat, checksum, origin and unexpected-entry rejection.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force }
