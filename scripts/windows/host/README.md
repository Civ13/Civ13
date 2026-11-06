# Windows host scripts

Double-click or command-line wrappers for running Civ13 worlds on Windows
through the [host service](../../gaia-host/README.md#one-host-service-for-gaia-and-region-groups)
and [region groups](../../shard-group/README.md). They only call
`gaia_host.py` and `shard_group.py`; Linux hosts use those scripts directly
(see `scripts/gaia-host/civ13-host.service.example`).

| Script | What it does |
| --- | --- |
| `status.bat [REGION]` | Each region's state (`awake`, `asleep`, `cold`, `stopped`) and last action. |
| `start.bat`, `stop.bat`, `restart.bat [REGION]` | Start; save and stop (with a verified backup); both. They run in the background, so follow them with `status.bat`. |
| `update.bat [REGION]` | Fetch, check out the group's revision and compile. Stop the regions first. |
| `deploy.bat [REGION ...]` | The whole update in one go: `git pull --ff-only --autostash` the source checkout, stage the build beside every running region (or only the ones named, such as `deploy.bat gaia`), and once every build is ready save and stop them, install the builds, start, then restart the host service. Each step waits for the last and it stops at the first failure. A world that does not save makes it stop with exit code 3 before anything is updated; see [deploying](#deploying-a-new-master). The launcher's **Save, update and restart** button runs it. |
| `stage.bat [REGION]` | Pull the source checkout, then build the update beside the running regions. Each region installs it by itself the next time it is empty and saved (or asleep), so nobody is kicked. `status.bat` shows its progress under `stage`. |
| `force-stop.bat`, `force-restart.bat [REGION]` | For a world that hangs (a save that never finishes): end it at once **without saving**, or end it and start it again. The start loads the last completed save (an interrupted save is swapped for the copy in `map_backups`), and the BYOND lock files (`*.lk`) the dead world left in `map_saves` are removed so the start is not refused. The launcher's Force stop and Force restart buttons do the same. |
| `restart-host.bat` | Restart the `Civ13 Host` task so it loads changed host scripts or new regions. The worlds keep running. |
| `freeze.bat`, `thaw.bat [REGION]` | Put an empty, saved region to sleep now, or wake it. The host service does this on its own. |
| `setup.bat [REGION]` | Create or refresh each region's worktree and config. Safe to run again. With a region, adds or refreshes only that one while the others keep running. |
| `enrol.bat REGION` | Enrol a set-up region with the transfer agents and coordinator while they run. `setup.bat REGION` already does this; use it for a region added before it did. Safe to repeat. |
| `unlock.bat`, `force-unlock.bat [REGION]` | Check each region's save for BYOND lock files (`*.lk`, left when a world is killed) and remove them, then report whether the save loads. `unlock` refuses for a region that runs or has an action in progress; `force-unlock` skips that check, for a world whose process is gone but still looks alive. Removing a lock a live world holds can corrupt its save. The launcher's Clear lock files and Force clear lock files buttons do the same. |
| `serve.bat` | Run the host service in this window, for testing. |
| `install-host-task.bat` | Register the host service as the `Civ13 Host` logon task and start it. Needs an administrator terminal. |
| `make-gaia-overlay.bat` | Copy live Gaia's local-only files (config with the webhook key, host.txt, Kestrel DLL and settings) into its overlay folder. |
| `retire-standalone-gaia.bat` | Disable the old doorman and Gaia tasks and save-and-stop standalone Gaia. |
| `adopt-gaia.bat` | Copy the stopped standalone Gaia's save, SQL and runtime data into the Gaia region. The originals are not touched. |

Every script reads `settings.bat` from this folder (copy `settings.example.bat`;
it is git-ignored). The update check for the launcher is
`py -3 scripts\shard-group\shard_group.py --config <group.json> check-update`.

## Moving live Gaia onto the host service

Gaia becomes the mainland region `gaia` of a live group on port 1714, run from
its own worktree under `D:\Civ13Regions`. `D:\GitHub\Civ13` stays on master and
is only the source the worktree is made from. Run each step from
`D:\GitHub\Civ13\scripts\windows\host` in a normal (not elevated) command prompt,
as the user who runs Gaia. Gaia is offline from step 4 until step 8.

1. **Settings.** Copy `settings.example.bat` to `settings.bat` and check the
   paths. Copy `group.example.json` to `D:\Civ13Regions\earth.json` and set
   `public_host` to the address players use. `save_minutes` is 0, so the
   group adds no autosaves during play.
2. **Overlay.** Run `make-gaia-overlay.bat`. Check that
   `D:\Civ13Regions\overlay\gaia\config\config.txt` has the webhook lines.
3. **Clean master.** The live config now lives in the overlay, so the local
   edits to it can go: `git checkout -- config/config.txt config/host.txt`
   (and `maps/nomads/nomads_europe.dmm` too, if that change was not on
   purpose), then `git pull --ff-only`. Gaia keeps running from its compiled build.
   From now on Gaia reads its config only from the region folder
   (`D:\Civ13Regions\earth\gaia\config`, refreshed from the overlay on every
   update), so `D:\GitHub\Civ13\config` going back to the repository's
   defaults (for example `host.txt` saying Tais) does not affect it. Change
   live settings in the overlay, then run `update.bat`, or edit the region's
   copy for a quick fix that the next update replaces.
4. **Stop standalone Gaia.** Run `retire-standalone-gaia.bat`, then follow it
   with the status command it prints until `phase` is `stopped` (a Gaia save
   takes about ten minutes).
5. **Build the region.** Run `setup.bat`, then `update.bat`. Run `status.bat`
   until the gaia region's phase is `compiled`.
6. **Move the save.** Run `adopt-gaia.bat`. It refuses unless standalone Gaia
   is stopped with a complete save, and it checks every copied save file.
7. **Start.** Make sure the BYOND pager is signed in, then run `start.bat`
   and `status.bat` until gaia is `awake`. Join and check your character.
8. **Host service.** Run `install-host-task.bat` from an administrator
   terminal (Windows requires admin rights to register a logon task; the
   task itself still runs as you with normal rights). It replaces the old doorman
   on TCP 1713, so the router forward still works.
9. **Bot and launcher.** The bot reads Gaia's status files (`serverdata.txt`,
   `SQL/`) from the server's folder, so until this step it shows the old,
   stopped checkout. In the bot's `profile.json`, point the `test1714`
   server's `basedir` at `D:/Civ13Regions/earth/gaia` and its `gaia_host`
   config at `D:/Civ13Regions/earth/gaia/data/shard-host/host.json`, then
   restart the bot. In the launcher's `host.json`, point `control.config` at
   the same `host.json`. Start, Stop, Restart, Update and the update check then
   drive the Gaia region.

**Rollback.** Stop the region with `stop.bat`, re-enable the
`Civ13 Gaia On-Demand` and `Civ13 Gaia Doorman` tasks, and start Gaia the old
way. Its old save in `D:\GitHub\Civ13\map_saves` is untouched, but anything
played on the region since step 7 is only in the region's save
(`D:\Civ13Regions\earth\gaia\map_saves`). Copy that back first if you need it.

Adding regions later: add them to `earth.json` (with `transfer_port` on every
region for travel), run `setup.bat REGION` and `update.bat REGION`, then
`start.bat REGION` and `restart-host.bat`. Nothing else stops: setup enrols the
new region with the running transfer agents and coordinator at once, and the
running worlds get the new peer in their config and use it from their next restart.
The host service picks them up when restarted with `restart-host.bat`.

## Deploying a new master

Run `deploy.bat` from a normal command prompt, or press **Save, update and
restart** on the launcher's Updates or Host server tab and tick the regions to
update (all of them, or for example only Gaia). It pulls `D:\GitHub\Civ13`
first (its local edits are kept). Then it stages the update for each chosen
region, building it beside the running world one region at a time at low
priority, like `stage.bat`. Nobody is kicked until every build is ready, and a
pull or build that fails stops it before then. Only then does it save the
chosen regions (Gaia takes up to ten minutes), install the staged builds (a file
copy instead of a compile), start them and restart the host service so it also
runs the new host scripts. Regions left out keep running. `wait_group.py` does
the waiting; it only reads `status`.

**A world that will not save** (busy, not ready, or its save fails) stays
running, and `deploy.bat` stops with exit code 3 before updating anything. The
regions that did save stay stopped. Either force-stop the ones that did not save
with `force-stop.bat REGION` (they go back to their last completed save) and
run `deploy.bat continue` with the same regions, or start the stopped regions
again with `start.bat`. The launcher lists each such world with its error and
asks which; it never stops a world without a save unless you choose that.

If any other step fails, the regions stay as that step left them: fix the
cause, then carry on by hand with `update.bat`, `start.bat` and `restart-host.bat`.
