$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('civ13-launcher-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
 $package=Join-Path $root 'source/Civ13-OpenDream-Windows'
 foreach($name in @('Sign-In.cmd','Play-Nomads.cmd','Play-TDM.cmd','Connect.ps1','dotnet/dotnet.exe','RobustToolbox/bin/ClientAuth/Robust.Client.dll','Content.Client.zip')) {
  $path=Join-Path $package $name
  New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
  Set-Content -LiteralPath $path -Value 'isolated fixture, never executed'
 }
 $zip=Join-Path $root 'client.zip'
 [IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $root 'source'),$zip)
 $manifest=Join-Path $root 'manifest.json'
 $hash=(Get-FileHash $zip).Hash.ToLowerInvariant()
 $channel=@{schema=1;version='fixture';url='https://github.com/Civ13/Civ13/releases/download/test/client.zip';sha256=$hash}
 $channel|ConvertTo-Json|Set-Content $manifest
 $install=Join-Path $root 'installed'
 & "$PSScriptRoot/Launcher.ps1" -InstallRoot $install -ManifestPath $manifest -ArchivePath $zip -InstallOnly
 & "$PSScriptRoot/Launcher.ps1" -InstallRoot $install -ManifestPath $manifest -ArchivePath $zip -InstallOnly
 if (@(Get-ChildItem $install -Directory -Filter 'OpenDream-*').Count -ne 1) {throw 'Repeat install duplicated version'}
 $lock=[IO.File]::Open((Join-Path $install 'launcher.lock'),'OpenOrCreate','ReadWrite','None')
 try { $rejected=$false; try { & "$PSScriptRoot/Launcher.ps1" -InstallRoot $install -ManifestPath $manifest -ArchivePath $zip -InstallOnly } catch {$rejected=$true}; if(!$rejected){throw 'Lock negative failed'} } finally {$lock.Dispose()}
 $channel.sha256='0'*64; $channel|ConvertTo-Json|Set-Content $manifest
 $rejected=$false;try { & "$PSScriptRoot/Launcher.ps1" -InstallRoot $install -ManifestPath $manifest -ArchivePath $zip -InstallOnly }catch{$rejected=$true};if(!$rejected){throw 'Checksum negative failed'}
 $channel.sha256=$hash;$channel.url='https://example.com/client.zip';$channel|ConvertTo-Json|Set-Content $manifest
 $rejected=$false;try { & "$PSScriptRoot/Launcher.ps1" -InstallRoot $install -ManifestPath $manifest -ArchivePath $zip -InstallOnly }catch{$rejected=$true};if(!$rejected){throw 'Origin negative failed'}
 $unsafe=Join-Path $root 'unsafe.zip';$archive=[IO.Compression.ZipFile]::Open($unsafe,'Create');try {$null=$archive.CreateEntry('../escape.txt')}finally{$archive.Dispose()}
 $channel.url='https://github.com/Civ13/Civ13/releases/download/test/client.zip';$channel.sha256=(Get-FileHash $unsafe).Hash;$channel|ConvertTo-Json|Set-Content $manifest
 $rejected=$false;try { & "$PSScriptRoot/Launcher.ps1" -InstallRoot $install -ManifestPath $manifest -ArchivePath $unsafe -InstallOnly }catch{$rejected=$true};if(!$rejected){throw 'Traversal negative failed'}
 Write-Host 'PASS: install, repeat, exclusive lock, checksum rejection, origin rejection, archive traversal rejection.'
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
