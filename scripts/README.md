# Scripts (Linux)

Server management and development scripts for Civ13.

## Interactive Map Tools

| Script | Description |
|---|---|
| `select_map.sh` | Interactive two-stage map selector. Pick an era folder, then a map, and it compiles and launches. |
| `launch_map.sh` | Swap the map in `civ13.dme`, compile, and run on DreamSeeker. |

### Usage

```bash
# Interactive selector — pick folder then map
./scripts/select_map.sh

# Direct — pass a map name
./scripts/launch_map.sh nomads
./scripts/launch_map.sh SUBCOM13
```

`launch_map.sh` resolves maps in this order:
1. Checks `code/__defines/maps.dm` for `#define MAP_<ARG>` — uses the quoted value as the map ID
2. Falls back to finding `<arg>.dmm` (case-insensitive) under `maps/`

## Server Scripts

| Script | Description |
|---|---|
| `launch.py` | Pulls latest from git, rebuilds, copies config, starts DreamDaemon. Production server launcher. |
| `mapswap.py` | Called by the epoch/map vote process. Pulls, rebuilds, copies binaries, kills old server, restarts. |
| `updateserver.py` | Pulls from git, rebuilds, copies config and binaries to the live server path. |
| `copyconfigfiles.py` | Copies `config/` files to the live server directory. Called by other scripts. |
| `restartinactiveserver.py` | Monitors for inactive server processes and restarts them. |
| `killciv13.py` | Kills running DreamDaemon processes for civ13. |
| `killsudos.py` | Kills orphaned sudo processes left behind by server scripts. |

## CI / Build

| Script | Description |
|---|---|
| `travis_pre_byond.sh` | CI helper — installs BYOND on Travis CI for build testing. |

## Configuration

Scripts that deploy to a live server read paths from `paths.txt`:
```
mdir:/path/to/server/
cdir:/path/to/live/
port:1313
```
