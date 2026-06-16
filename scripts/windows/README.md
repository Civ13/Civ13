# Scripts (Windows)

Windows-specific server management scripts for Civ13.

## Interactive Map Tools

| Script | Description |
|---|---|
| `select_map.bat` | Interactive two-stage map selector. Pick an era folder, then a map, and it compiles and launches. |
| `launch_map.bat` | Swap the map in `civ13.dme`, compile, and run on DreamSeeker. |

### Usage

```bat
REM Interactive selector - pick folder then map
scripts\select_map.bat

REM Direct - pass a map name
scripts\launch_map.bat nomads
scripts\launch_map.bat SUBCOM13
```

`launch_map.bat` resolves maps in this order:
1. Checks `code\__defines\maps.dm` for `#define MAP_<ARG>` - uses the quoted value as the map ID
2. Falls back to finding `<arg>.dmm` (case-insensitive) under `maps\`

## Server Scripts

| Script | Description |
|---|---|
| `launch.py` | Pulls latest from git, rebuilds, copies config, starts DreamDaemon. Production server launcher. |
| `mapswap.py` | Called by the epoch/map vote process. Pulls, rebuilds, copies binaries, kills old server, restarts. |
| `copyconfigfiles.py` | Copies `config\` files to the live server directory. Called by other scripts. |

## Configuration

Scripts that deploy to a live server read paths from `paths.txt`:
```
mdir:C:\path\to\server\
cdir:C:\path\to\live\
port:1313
```
