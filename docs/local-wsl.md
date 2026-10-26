# Local Civ13 servers controlled from Windows

## Replacing the retired legacy installer

`INSTALL` and `INSTALL.py` now exit with status 2 without provisioning, regardless
of supplied version arguments. Their former unchecked HTTP download and PATH
compiler selection did not implement the central BYOND target. They no longer
run system-wide upgrades or replace themselves with a moving remote script.
Automation that depended on these entrypoints must migrate explicitly.

The Windows/WSL flow below and the direct Linux flow at the end use the existing
manifest-driven local runtime tools. They are for **separate local test servers**,
not replacements for a production deployment procedure. `scripts/launch.py` and
`scripts/updateserver.py` remain legacy, unversioned PATH consumers and are **not
upgraded**. Do not use them to migrate an existing server. Retain original saves,
configuration and old binaries, coordinate its shutdown with the owner, and
review the runtime-specific upgrade before replacing it. These instructions do
not authorize execution, restart a running server or establish native acceptance.

## Windows/WSL

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
Build/Start/Stop/Status. Prepare always uses root for dependency installation;
the selected Linux user also owns and runs the local game processes.
No interactive Linux terminal is required. Windows UAC elevation and a restart
are still needed when the virtualization components are absent.

BYOND targets 516.1688 from `tools/byond/version.json`, installed separately under
`/opt/civ13-byond-516.1688`. Setup verifies observed official HTTPS archive bytes
before extraction. This is source preparation; native acceptance is pending.
Existing runtime records without the matching version fail closed and require an
owner-coordinated stop using their original toolchain before rebuilding. Never
delete the record to bypass that check. Compiled-world version receipts also
prevent starting an old build with the new daemon. Builds fetch the selected local commit into an
independent temporary Git repository, check it out detached and reject tracked
local edits. The temporary HEAD and index support the real crafting catalog
generator without switching the operator's checkout or registering a worktree.
Builds regenerate the crafting catalog and require zero
compiler errors/warnings. Build while the selected local server is stopped.
Run `git pull --ff-only origin master` in Windows before rebuilding to update
the source; this launcher does not hard-reset the checkout.

Each server has its own Linux-home `.local/share/civ13-local/<server>` directory,
SQL files, data, logs and PID/start-time record. Nomads uses PERSISTENCE catalog
selection, TDM uses TDM; ports are 1715/1714. Generated configuration disables
hub advertisement, TTS and script hooks and supplies no webhooks or official
bot credentials. Daemons retain the existing trusted mode; execution requires maintainer approval. Saves remain through rebuilds.
The launcher does not configure firewall rules, router forwarding or DNS.
Check port conflicts before launch; public access requires separate network
verification. `Status` checks owned process identity, not successful player login.

After startup inspect logs for engine diagnostics and verify client admission,
selected maps and actual save/reload. A two-second surviving process is not
gameplay acceptance. Stop sends SIGTERM only to the recorded matching process;
it does not force-kill stalled saves. A failed start terminates and waits up to
ten seconds for its exact launched child before removing the identity record.
If exit cannot be confirmed, the launcher reports its PID and retains any
identity record for investigation; it does not claim cleanup or force-kill it.
WSL startup failure
`HCS_E_HYPERV_NOT_INSTALLED` is a Windows prerequisite blocker.

## Direct Linux local test runtime

Despite their names, `setup-local-wsl.sh` and `local-wsl.py` do not invoke WSL.
The setup uses Debian-compatible apt packages; the controller uses Linux `/proc`,
`fcntl`, and signals. Only `local-wsl.ps1` requires Windows/WSL. For an x86 Linux
host with compatible 32-bit libraries (the pinned archive references GLIBC_2.34),
the same local flow can be invoked directly from a clean, reviewed Git checkout:

```sh
# System dependency and pinned runtime installation; review before authorizing.
sudo bash scripts/setup-local-wsl.sh
# Use the same ordinary Linux user for all controller actions, not sudo.
python3 scripts/local-wsl.py build --server nomads --source "$PWD"
# Start only with maintainer approval, sufficient resources and free port 1715.
python3 scripts/local-wsl.py start --server nomads --source "$PWD"
python3 scripts/local-wsl.py status --server nomads --source "$PWD"
python3 scripts/local-wsl.py stop --server nomads --source "$PWD"
```

Use `--server tdm` for the separate port-1714 runtime; port 1714 must also be free
and must not conflict with another server. The setup reads
`tools/byond/version.json` and uses its existing checked official HTTPS downloader,
with no automatic mirror fallback. It does not repair or verify an already-present
installation merely because its DreamMaker path exists. Build checks the exact
compiler banner; Start requires a matching build receipt. A receipt/path alone is
not proof of the installed daemon's bytes or of a live serving engine's version.
Verify the existing installation and runtime evidence before reuse; do not bypass
old-version identity guards or delete their records. The source-level Linux path
has been inspected, but installation/startup were not executed for this change.
Non-Debian platforms, production migration and existing-server orchestration have
no replacement in this patch and require a separately reviewed operator plan.
