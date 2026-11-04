# Scripts (Windows)

Windows-specific server management scripts for Civ13.

## Compile only

Run `compile.bat` from the repository root, or call it by its full path from
any working directory. It compiles the map and options already selected in
`civ13.dme`, writing `civ13.dmb` and `civ13.rsc` beside that file. It does not
start a client/server, select a map, deploy files, or touch save data. Compile
in a development checkout to keep generated binaries separate from a live server.

The script requires Windows PowerShell and the exact BYOND version in
`tools/byond/version.json`. It finds the console compiler `dm.exe` through
`BYOND_BIN`, then `PATH`, then the standard `Program Files (x86)\BYOND\bin`
and `Program Files\BYOND\bin` directories. An explicit `BYOND_BIN` or a
compiler found on `PATH` must match the pin; an invalid selection fails clearly.
For a custom or versioned installation, set the bin directory without quotes
inside the value:

```bat
set "BYOND_BIN=C:\Program Files (x86)\BYOND\bin"
compile.bat
```

Compiler output stays in the console. The script returns the compiler's exit
code, or `1` for setup errors and `2` for unsupported arguments. From another
batch script, use `call "C:\path to\Civ13\compile.bat"`. There is no automatic
pause; run it from a command prompt to keep the output visible.

To check discovery, version rejection, path quoting and exit handling without
running BYOND, use a working Python installation on Windows:
`python -m unittest discover -s tests/windows_compile -v`. The tests build a
harmless console compiler stub with Windows PowerShell in a temporary directory.

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
