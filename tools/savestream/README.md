# Stream saves (prototype)

Prototype of the save offload recommended by the 64-bit Dream Daemon
feasibility study: world-save serialization leaves the 32-bit Dream Daemon
process and goes to a 64-bit helper. **Off by default.** Nothing in the game
calls it yet; `Save_World` and `Load_World` still use `/savefile` (formats 3
and 4). It is tested on save copies only.

## Why

A level `/savefile` is materialized in Dream Daemon as an in-memory tree at
about 5 to 7 times the file size, and BYOND never returns that memory to the
OS. On Gaia that tree, not the world, is what pushes save and load peaks
toward the 32-bit ceiling. A stream save never builds that tree in Dream
Daemon: the game hands each path and value to the helper, which writes the
file sequentially and keeps the index and validation state in its own 64-bit
address space.

## Pieces

| Path | What |
| --- | --- |
| `src/savestream_shim.c` | 32-bit library loaded with `call_ext` (classic string interface). Spawns the helper and forwards framed requests over a pipe. Holds no save data. |
| `src/savestream_helper.c` | 64-bit helper: `write` (stream writer, blob deduplication, structural validation), `read` (index lookups, directory listing, ordered iteration), `dump`. |
| `src/savestream_format.h` | File format, wire tokens and pipe protocol. |
| `code/modules/persistence/stream/save_stream.dm` | DM API: `/datum/save_stream` with `open_write`/`put`/`put_text`/`finish` and `open_read`/`get`/`dir`/`iterate`. |
| `bench/` | Converter and benchmark modes (one Dream Daemon process per mode). |
| `diagnosis/address_space.py` | Scriptable VMMap summary for a running Dream Daemon (Windows `VirtualQueryEx`, Linux `/proc`). |
| `diagnosis/run_bench.py` | Runs the benchmark modes and samples each process. |

The file stores the same logical tree as a level savefile: absolute paths
(`/entries/0/17/name`, `/map/2/5/9`, `/lists/3/1/key`) mapped to values. Values
are null, float32 numbers, text, type paths, lists (with associations), file
data (icons and sounds, stored once per distinct file and referenced by id) and
raw BYOND savefile text for anything else (appearances). The index is written
last, so a file whose writer died has no trailer and is never read; the
writer publishes `<file>` from `<file>.tmp` only after the structure validates
(every referenced entry and list exists) or when `finish(force = TRUE)`.

## Build and test

```bash
bash tools/savestream/build.sh linux     # needs gcc-multilib
bash tools/savestream/build.sh windows   # needs mingw-w64; savestream.dll (x86) + savestream_helper.exe (x64)
python3 -m unittest tests/savestream/test_helper.py   # offline, host compiler only (CI suite "savestream")
python3 tests/savestream/run_native.py                # Linux Dream Daemon round trip (pinned BYOND)
```

Binaries go to `tools/savestream/bin/` and are not committed. To use them in
a game directory, put the shim and helper next to the `.dmb`
(`savestream.dll` + `savestream_helper.exe`, or `libsavestream.so` +
`savestream_helper`); `call_ext` needs `-trusted`.

## Benchmark on a save copy

Copy a level file into a scratch folder with `bench.dmb` (compile
`bench/bench.dme`), the shim and the helper, then:

```bash
python3 tools/savestream/diagnosis/run_bench.py --work <folder> --dd DreamDaemon --level 2
py -3 tools\savestream\diagnosis\run_bench.py --work <folder> --dd "C:\Program Files (x86)\BYOND\bin\dd.exe" --level 2
```

Modes: `read_savefile` and `write_savefile` are today's load and save memory
for that level; `read_stream` and `write_stream` are the same work through the
helper. `convert` turns a format-3 level into a stream (the converter itself
materializes the source savefile) and `verify` compares every leaf both ways.
Never point it at a live server's `map_saves/`.

## Not done yet

- Wiring into `Save_World`/`Load_World` behind a config flag, after the
  compact save format lands (the persistence work owns the format number).
- Format 4 segment files as converter input (format 3 only today).
- A rollback copy and migration step before any live use, as format 4 did.
