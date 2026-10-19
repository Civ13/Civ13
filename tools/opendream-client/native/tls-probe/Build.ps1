$ErrorActionPreference = 'Stop'
$root = Join-Path $env:RUNNER_TEMP ('civ13-tls-build-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$source = Join-Path $root 'Updater.cs'
Invoke-WebRequest 'https://raw.githubusercontent.com/Civ13/Civ13/d6efd6f00262fc7717589581f443f0ff5361090d/tools/opendream-client/native/Updater.cs' -OutFile $source
if ((Get-FileHash $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne '97fbbfed97f24c0b9476802c107af40140f8b8e4b58bbe4870e322c26604ae93') { throw 'Historical updater source hash mismatch' }
Copy-Item (Join-Path $PSScriptRoot 'Diagnostic.cs') (Join-Path $root 'Diagnostic.cs')
@'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework>
    <AssemblyName>Civ13-TLS-Diagnostic</AssemblyName><Version>1.0.0</Version>
    <ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
'@ | Set-Content (Join-Path $root 'Diagnostic.csproj')
$output = Join-Path $PSScriptRoot 'publish'
dotnet publish (Join-Path $root 'Diagnostic.csproj') -c Release -r win-x64 --self-contained true -p:ContinuousIntegrationBuild=true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false -o $output
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$exe = Join-Path $output 'Civ13-TLS-Diagnostic.exe'
& $exe --self-test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $exe --no-pause
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$hash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  Civ13-TLS-Diagnostic.exe" | Set-Content (Join-Path $output 'Civ13-TLS-Diagnostic.exe.sha256')
Write-Output "Diagnostic EXE SHA256: $hash"

Copy-Item (Join-Path $PSScriptRoot 'README.txt') (Join-Path $output 'README.txt')
