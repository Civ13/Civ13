[CmdletBinding()]
param([string]$Dotnet = 'C:/Program Files/dotnet/dotnet.exe', [string]$Output = (Join-Path $PSScriptRoot 'publish'))
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Dotnet -PathType Leaf)) { throw 'A verified .NET 8 or newer SDK path is required.' }
& $Dotnet publish (Join-Path $PSScriptRoot 'Civ13.Launcher.csproj') -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false -o $Output
if ($LASTEXITCODE -ne 0) { throw 'Launcher publish failed.' }
$exe = Join-Path $Output 'Civ13.exe'
& $exe --version
if ($LASTEXITCODE -ne 0) { throw 'Standalone launcher startup failed.' }
& $exe --self-check
if ($LASTEXITCODE -ne 0) { throw 'Embedded launcher resources failed.' }
Get-FileHash -LiteralPath $exe -Algorithm SHA256
