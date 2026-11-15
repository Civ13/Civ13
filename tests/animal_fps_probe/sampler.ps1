# Samples Dream Seeker CPU per probe phase and records 12 s of the game window
# per phase with ffmpeg, counting the distinct frames drawn (mpdecimate).
# Usage: powershell -ExecutionPolicy Bypass -File sampler.ps1 -RunDir <daemon folder> -WindowTitle "<title>"
param(
	[Parameter(Mandatory = $true)][string]$RunDir,
	[Parameter(Mandatory = $true)][string]$WindowTitle,
	[string]$Ffmpeg = "C:\Windows\System32\ffmpeg.exe"
)
$phaseFile = Join-Path $RunDir "probe-phase.txt"
$out = Join-Path $RunDir "client-samples.csv"
"time,phase,seeker_cpu_pct" | Set-Content $out
$cores = [Environment]::ProcessorCount
$last = $null
$lastCpu = $null
$lastTime = $null
$recorded = @{}
while ($true) {
	Start-Sleep -Milliseconds 500
	$phase = if (Test-Path $phaseFile) { (Get-Content $phaseFile -Raw).Trim() } else { "none" }
	$p = Get-Process dreamseeker -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq $WindowTitle } | Select-Object -First 1
	if (-not $p) { continue }
	$now = Get-Date
	$cpu = $p.TotalProcessorTime.TotalMilliseconds
	if ($lastCpu -ne $null) {
		$pct = [math]::Round(100 * ($cpu - $lastCpu) / (($now - $lastTime).TotalMilliseconds), 1)
		"$($now.ToString('HH:mm:ss.fff')),$phase,$pct" | Add-Content $out
	}
	$lastCpu = $cpu; $lastTime = $now
	if ($phase -ne $last -and $phase -match "^(walk|stand)" -and -not $recorded[$phase]) {
		$recorded[$phase] = $true
		$log = Join-Path $RunDir "frames-$phase.log"
		Start-Process -FilePath $Ffmpeg -ArgumentList @("-hide_banner", "-f", "gdigrab", "-framerate", "100", "-draw_mouse", "0", "-ss", "3", "-i", "`"title=$WindowTitle`"", "-t", "12", "-vf", "mpdecimate=hi=64:lo=32:frac=0.1", "-f", "null", "-") -RedirectStandardError $log -WindowStyle Hidden
	}
	$last = $phase
	if ($phase -eq "done") { break }
}
