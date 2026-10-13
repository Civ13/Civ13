param([Parameter(Mandatory)][string]$Engine,[Parameter(Mandatory)][string]$Dotnet)
$ErrorActionPreference='Stop'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('civ13-direction-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
 Copy-Item -LiteralPath "$PSScriptRoot/Program.cs","$PSScriptRoot/Stubs.cs" -Destination $temp
 Copy-Item -LiteralPath (Join-Path $Engine 'OpenDreamShared/Resources/DMIParser.cs') -Destination "$temp/DMIParser.cs"
 '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><OutputType>Exe</OutputType><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup></Project>' | Set-Content "$temp/Probe.csproj"
 & $Dotnet run --project "$temp/Probe.csproj" -c Release -p:NuGetAudit=false
 if($LASTEXITCODE -ne 0){throw 'Patched production parser failed'}
 $source=Get-Content -LiteralPath "$temp/DMIParser.cs" -Raw
 $fixed='frames = Directions.Count == 1 && Directions.TryGetValue(AtomDirection.South, out var southFrames)'+[Environment]::NewLine+'                        ? southFrames : Array.Empty<ParsedDMIFrame>();'
 # Normalize line endings before the targeted negative control.
 $source=$source.Replace("`r`n","`n")
 $fixed=$fixed.Replace("`r`n","`n")
 if(!$source.Contains($fixed)){throw 'Negative control cannot locate fixed selector'}
 $source.Replace($fixed,'frames = Array.Empty<ParsedDMIFrame>();') | Set-Content "$temp/DMIParser.cs"
 $output=& $Dotnet run --project "$temp/Probe.csproj" -c Release -p:NuGetAudit=false 2>&1
 if($LASTEXITCODE -eq 0 -or ($output -join "`n") -notmatch 'normalized SOUTH frame must insert into each cardinal direction'){throw 'Negative control failed unexpectedly'}
 Write-Host 'PASS: unsafe original selector rejected.'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force}
