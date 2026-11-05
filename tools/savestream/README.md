# Stream saves

World-save serialization runs in a 64-bit helper instead of the 32-bit Dream
Daemon process. Since level format 5, `Save_World` writes every level's
entries and lists through it (`code/modules/persistence/stream/level_stream.dm`)
whenever the shim and helper sit beside `civ13.dmb` and `call_ext` works
(`-trusted`). Otherwise saves fall back to `/savefile` levels (format 3 or 4)
on their own; `PERSISTENCE_NO_STREAM_SAVES` in `config.txt` forces that.

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
| `code/modules/persistence/stream/save_stream.dm` | DM API: `/datum/save_stream` with `open_write`/`put`/`put_text`/`finish` and `open_read`/`get`/`dir`/`iterate`/`seek`/`subtree`. |
| `code/modules/persistence/stream/level_stream.dm` | Level format 5: the stream writer and reader behind the format-4 segment seams. |
| `../../savestream.dll`, `../../savestream_helper.exe` | Windows builds shipped at the repository root (like `rust_g.dll`); `shipped.json` pins their bytes and sources. |
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

## Level format 5

`map_saves/<z>.sav` stays a small savefile index (`/format_version` 5, turf
grid, zone capture, header, `/stream/file`), so every tool that checks for
`<z>.sav` keeps working. Entries and lists go to `map_saves/<z>.stream.sav`.
The save still fills one small scratch savefile per segment
(`PERSISTENCE_SEGMENT_SIZE`) and hands it to the helper when it closes; the
few late appends to an earlier turf's contents (roster drain, animal sweep)
read that node back from the helper. On load, `level_entry_file()` and
`level_list_file()` materialise one entry shard (512 entries) or list block
at a time from the stream. Backups, rollback, the validation record and the
completion marker treat the stream like a segment file.

Formats 3 and 4 still load. Builds before format 5 refuse a format-5 save, so
the first stream save keeps the last full-file generation in `map_rollback/`
as format 4 did.

## Shipping the Windows binaries

```bash
bash tools/savestream/build.sh windows      # mingw-w64, no link timestamp: same bytes every build
cp tools/savestream/bin/windows/* .         # then update tools/savestream/shipped.json
python3 -m unittest tests/savestream/test_helper.py
```

The test fails when a source file changed without updating `shipped.json`, and
with mingw-w64 installed it rebuilds and compares the shipped bytes.

## Native check

`bash tests/world_save/run-stream.sh` runs the world-save fixture with stream
levels through the real `Save_World`/`Load_World` (needs gcc-multilib and the
pinned BYOND).
