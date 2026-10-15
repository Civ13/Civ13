[CmdletBinding()]
param([string]$Dotnet = 'C:/Program Files/dotnet/dotnet.exe', [string]$Output = (Join-Path $PSScriptRoot 'publish'), [string]$Version)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Dotnet -PathType Leaf)) { throw 'A verified .NET 8 or newer SDK path is required.' }
$configured = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'version.json') -Raw | ConvertFrom-Json
if ($configured.schema -ne 1 -or $configured.version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw 'Invalid native launcher version configuration.' }
if (!$Version) { $Version = $configured.version }
if ($Version -cne $configured.version) { throw 'Build version differs from the checked-out release configuration.' }
& $Dotnet publish (Join-Path $PSScriptRoot 'Civ13.Launcher.csproj') -c Release -r win-x64 --self-contained true "-p:Version=$Version" -p:ContinuousIntegrationBuild=true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false -o $Output
if ($LASTEXITCODE -ne 0) { throw 'Launcher publish failed.' }
$exe = Join-Path $Output 'Civ13.exe'
$actual = & $exe --version
if ($LASTEXITCODE -ne 0) { throw 'Standalone launcher startup failed.' }
if (($actual | ConvertFrom-Json).version -cne $Version) { throw 'Published executable version mismatch.' }
Write-Output $actual
& $exe --self-check
if ($LASTEXITCODE -ne 0) { throw 'Embedded launcher resources failed.' }
Get-FileHash -LiteralPath $exe -Algorithm SHA256
