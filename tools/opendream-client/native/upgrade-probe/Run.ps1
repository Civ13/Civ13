$ErrorActionPreference = 'Stop'
$root = Join-Path $env:RUNNER_TEMP ('civ13-upgrade-probe-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
# Compile the exact immutable 1.0.2 updater, not today's implementation.
$source = Join-Path $root 'Updater.cs'
Invoke-WebRequest 'https://raw.githubusercontent.com/Civ13/Civ13/d6efd6f00262fc7717589581f443f0ff5361090d/tools/opendream-client/native/Updater.cs' -OutFile $source
if ((Get-FileHash $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne '97fbbfed97f24c0b9476802c107af40140f8b8e4b58bbe4870e322c26604ae93') { throw 'Historical updater source hash mismatch' }
Copy-Item (Join-Path $PSScriptRoot 'Probe.cs') (Join-Path $root 'Probe.cs')
@'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
'@ | Set-Content (Join-Path $root 'Probe.csproj')
dotnet run --project (Join-Path $root 'Probe.csproj') -- (Join-Path $root 'isolated-install')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
