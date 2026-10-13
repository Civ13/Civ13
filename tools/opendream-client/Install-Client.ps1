[CmdletBinding()]
param(
    [string]$DownloadUrl = 'https://github.com/Civ13/Civ13/releases/download/opendream-client-2026-10-12/Civ13-OpenDream-Windows.zip',
    [string]$ExpectedSha256 = '7920884440e94a1d97ebccc202c892dba50cca994174af4b1e557ec56cf65f1b',
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Civ13'),
    [string]$ArchivePath,
    [switch]$NoShortcuts
)
$ErrorActionPreference = 'Stop'
if (![Environment]::Is64BitOperatingSystem) { throw 'Windows x64 is required.' }
if ($ExpectedSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'A SHA256 checksum is required.' }
$version = $ExpectedSha256.Substring(0, 12).ToLowerInvariant()
$destination = Join-Path $InstallRoot "OpenDream-$version"
if (Test-Path -LiteralPath $destination) {
    if (!(Test-Path -LiteralPath (Join-Path $destination 'install-receipt.json'))) { throw "Existing incomplete installation: $destination" }
    $receipt = Get-Content -LiteralPath (Join-Path $destination 'install-receipt.json') -Raw | ConvertFrom-Json
    if ($receipt.sha256 -ne $ExpectedSha256) { throw 'Existing installation checksum differs.' }
} else {
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    $stage = Join-Path $InstallRoot ('setup-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    if (!$ArchivePath) {
        $ArchivePath = Join-Path $stage 'client.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host 'Downloading Civ13 client (about 761 MB)...'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash -ne $ExpectedSha256) { throw "Checksum failed. Installation stopped; files retained at $stage" }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ArchivePath).Path)
    $extract = Join-Path $stage 'extracted'
    New-Item -ItemType Directory -Path $extract | Out-Null
    $prefix = [IO.Path]::GetFullPath($extract) + [IO.Path]::DirectorySeparatorChar
    try {
        foreach ($entry in $archive.Entries) {
            $resolved = [IO.Path]::GetFullPath((Join-Path $extract $entry.FullName))
            if (!$resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe archive path; installation stopped.' }
        }
    } finally { $archive.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $ArchivePath).Path, $extract)
    $package = Join-Path $extract 'Civ13-OpenDream-Windows'
    foreach ($required in @('Sign-In.cmd','Play-Nomads.cmd','Play-TDM.cmd','Connect.ps1','dotnet/dotnet.exe','RobustToolbox/bin/ClientAuth/Robust.Client.dll','Content.Client.zip')) {
        if (!(Test-Path -LiteralPath (Join-Path $package $required) -PathType Leaf)) { throw "Incomplete package: $required" }
    }
    Get-ChildItem -LiteralPath $package -Recurse -File | Unblock-File
    @{sha256=$ExpectedSha256;url=$DownloadUrl;installedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $package 'install-receipt.json')
    Move-Item -LiteralPath $package -Destination $destination
}
if (!$NoShortcuts) {
    $menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Civ13'
    New-Item -ItemType Directory -Path $menu -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    foreach ($name in @('Sign-In','Play-Nomads','Play-TDM')) {
        $shortcut = $shell.CreateShortcut((Join-Path $menu "Civ13 $name.lnk"))
        $shortcut.TargetPath = Join-Path $destination "$name.cmd"
        $shortcut.WorkingDirectory = $destination
        $shortcut.Save()
    }
}
Write-Host "Installed: $destination"
Write-Host 'First run Sign-In.cmd and log into your own account. Then run Play-Nomads.cmd or Play-TDM.cmd.'
Write-Host 'No Administrator access is needed. Native BYOND is unchanged.'
