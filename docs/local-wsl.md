# Local Civ13 servers controlled from Windows

These scripts prepare separate PC-only Nomads and TDM runtimes. They do not
update, restart or copy credentials from the official Debian servers.
CivilizationBot has a separate local-profile setup in its own repository.

Run in Administrator PowerShell once:

```powershell
./scripts/local-wsl.ps1 -Action PrepareWindows
```

Restart Windows. Firmware virtualization must also be enabled. Then, from
ordinary Windows PowerShell at the Civ13 checkout, run:

```powershell
./scripts/local-wsl.ps1 -Action Prepare
./scripts/local-wsl.ps1 -Action Build -Server nomads
./scripts/local-wsl.ps1 -Action Build -Server tdm
./scripts/local-wsl.ps1 -Action Start -Server nomads
./scripts/local-wsl.ps1 -Action Start -Server tdm
./scripts/local-wsl.ps1 -Action Status -Server nomads
./scripts/local-wsl.ps1 -Action Stop -Server nomads
```

The default distribution is Debian; default Linux user is root for automated
bootstrap. Use `-LinuxUser` for an existing nonroot account consistently for
Build/Start/Stop/Status. Root is used only for dependency installation by Prepare.
No interactive Linux terminal is required. Windows UAC elevation and a restart
are still needed when the virtualization components are absent.

BYOND is pinned to 516.1681. Builds use a committed Git snapshot and reject
tracked local edits. They regenerate the crafting catalog and require zero
compiler errors/warnings. Build while the selected local server is stopped.
Run `git pull --ff-only origin master` in Windows before rebuilding to update
the source; this launcher does not hard-reset the checkout.

Each server has its own Linux-home `.local/share/civ13-local/<server>` directory,
SQL files, data, logs and PID/start-time record. Nomads uses PERSISTENCE catalog
selection, TDM uses TDM; ports are 1715/1714. Generated configuration disables
hub advertisement, TTS and script hooks and supplies no webhooks or official
bot credentials. Daemons use safe mode. Saves remain through rebuilds.
The launcher does not configure firewall rules, router forwarding or DNS.
Check port conflicts before launch; public access requires separate network
verification. `Status` checks owned process identity, not successful player login.

After startup inspect logs for engine diagnostics and verify client admission,
selected maps and actual save/reload. A two-second surviving process is not
gameplay acceptance. Stop sends SIGTERM only to the recorded matching process;
it does not force-kill stalled saves. WSL startup failure
`HCS_E_HYPERV_NOT_INSTALLED` is a Windows prerequisite blocker.
