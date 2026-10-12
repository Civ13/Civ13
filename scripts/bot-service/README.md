# Game-to-bot service control

The game can request recovery even when CivilizationBot is stopped. A root-installed
helper controls exactly `civilizationbot.service`; it does not contact the bot's
HTTP server. Server administrators get **CivilizationBot Service** under Server.
The feature defaults off. Ordinary players cannot invoke it.

## Reviewed host layout

Read-only SSH inspection on 2026-10-12 found the bot checkout at
`/home/civ13/Civilizationbot`, games under `/home/civ13/civ13-rp` and
`/home/civ13/civ13-tdm`, and unmanaged root PHP/DreamDaemon processes.
No dedicated systemd bot unit was present. The legacy game launcher paths are
not installation instructions for this host.

## Installation and controlled cutover

Installing a service and stopping the existing bot are separate host operations.
Do not install blindly on a different layout or run a second bot beside the old
one. Do not use `pkill php` or kill game servers.

1. Confirm `/usr/bin/php`, the bot working directory, its entry point, required
   files and permissions, and the exact existing PHP process with the operator.
   Back up the current launch arrangement and establish rollback.
2. Install `civilizationbot.service` as root into
   `/etc/systemd/system/civilizationbot.service`. Install `control.py` as
   `/usr/local/sbin/civ13-bot-control`, owned root:root with mode 0755.
   Both files and their parent directories must be non-writable by game/bot users.
   The helper is standalone; never replace it with a symlink into a checkout.
3. Review the unit. **User=root deliberately matches the observed bot**, whose
   existing game administration uses sudo. It is a compatibility step, not a
   privilege reduction. Migrating both game and bot to service accounts requires
   a separate permissions audit of file IPC, game launch controls and secrets.
   Do not grant a non-root bot unrestricted sudo to compensate.
4. Run `systemd-analyze verify /etc/systemd/system/civilizationbot.service`
   and `systemctl daemon-reload`. Verify the installed helper syntax.
5. During an operator-approved cutover, stop only the identified old bot and
   remove its old startup mechanism. Verify it exited before
   `systemctl enable --now civilizationbot.service`. Inspect service status
   and its journal and verify one bot process, required Discord connectivity
   and game IPC. The unit stops its entire cgroup and retries exits after
   ten seconds, with five starts per five minutes.
6. If DreamDaemon runs non-root, use `visudo` to allow its exact service account
   only these commands (replace GAMEUSER with the audited runtime user):

   ```sudoers
   GAMEUSER ALL=(root) NOPASSWD: /usr/local/sbin/civ13-bot-control status, /usr/local/sbin/civ13-bot-control start, /usr/local/sbin/civ13-bot-control restart
   ```

   Do not grant arbitrary systemctl, shell, Python, service edits or wildcard
   helper arguments. The currently observed root game already has these powers.
7. Only after installation verification, set `bot_service_control 1` in each
   game runtime's config. The game parses this at startup; deploy/reload using
   the host's normal separately authorized procedure. No automated game restart
   is provided by this change.

Rollback: disable the game setting, stop/disable the new bot unit, verify its
cgroup is gone, then restore the recorded previous launch arrangement. Do not
restart the old bot before the new one has stopped.

## Behavior and limits

The game passes fixed literal commands to sudo with `-n`, so it cannot prompt
for a password. The helper accepts start/restart/status only, serializes requests
with a root-owned flock in /run, and shares a sixty-second mutation cooldown
across all game servers. Failed requests also consume that budget. Reboot clears
the budget. Status does not consume it. systemctl mutations use --no-block:
zero means the request was accepted, not that Discord is connected. Recheck
status/journal. The subprocess has a three-second timeout; the DM calling proc sleeps until
the command finishes, and the operation is deliberately admin-only, not a tick
watchdog. DreamDaemon must permit shell calls (trusted mode). Automatic crash recovery belongs to systemd.

The existing bot self-restart is not this API. Validate it during cutover before
using it under supervision; prefer the service control while deployed.
No public lifecycle HTTP endpoint, credentials or configurable shell is added.

## Verification

`python3 -m unittest discover -s tests/bot_service -v` tests exact commands,
invalid input rejection, shared cooldown boundaries, status, failed requests and
timeouts with injected effects. It never invokes systemctl.
Compile the game with BYOND 516.1681. These checks do not prove host permissions,
real service recovery, Discord connection or deployment. Installation acceptance
requires the explicit cutover checks above.
