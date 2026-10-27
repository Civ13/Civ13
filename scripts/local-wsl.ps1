param(
    [ValidateSet('PrepareWindows','Check','Prepare','Build','Start','Stop','Status')]
    [string]$Action = 'Status',
    [ValidateSet('nomads','tdm')][string]$Server = 'nomads',
    [string]$Distribution = 'Debian',
    [string]$LinuxUser = 'root'
)
$ErrorActionPreference = 'Stop'
if ($Distribution -notmatch '^[a-zA-Z0-9._-]+$' -or $LinuxUser -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid distribution/user name' }
if ($Action -eq 'PrepareWindows') {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script in Administrator PowerShell with -Action PrepareWindows.'
    }
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null
    & "$env:SystemRoot/System32/bcdedit.exe" /set hypervisorlaunchtype auto
    if ($LASTEXITCODE -ne 0) { throw 'Could not enable hypervisor startup' }
    Write-Host 'Windows features prepared. Restart Windows, then run -Action Prepare.'
    return
}
$wsl = "$env:SystemRoot/System32/wsl.exe"
if ($Action -eq 'Prepare') {
    $names = (& $wsl --list --quiet) -replace "`0", ''
    if ($names -notcontains $Distribution) {
        & $wsl --install --distribution $Distribution --no-launch
        if ($LASTEXITCODE -ne 0) { throw 'WSL installation failed. Run PrepareWindows as Administrator and restart Windows.' }
    }
}
& $wsl --distribution $Distribution --user $LinuxUser --exec /bin/true
if ($LASTEXITCODE -ne 0) { throw 'WSL cannot start. Run PrepareWindows as Administrator and restart Windows.' }
if ($Action -eq 'Check') { Write-Host 'WSL starts successfully'; return }
$repo = Split-Path -Parent $PSScriptRoot
$linuxRepo = (& $wsl --distribution $Distribution --user $LinuxUser --exec wslpath -a $repo).Trim()
if ($LASTEXITCODE -ne 0 -or -not $linuxRepo.StartsWith('/')) { throw 'Could not translate checkout path' }
if ($Action -eq 'Prepare') {
    & $wsl --distribution $Distribution --user root --exec bash "$linuxRepo/scripts/setup-local-wsl.sh"
} else {
    & $wsl --distribution $Distribution --user $LinuxUser --exec python3 "$linuxRepo/scripts/local-wsl.py" $Action.ToLowerInvariant() --server $Server --source $linuxRepo
}
if ($LASTEXITCODE -ne 0) { throw "Local WSL action $Action failed ($LASTEXITCODE)" }
