# Save-to-map export

Two tools live here:

- `export.py` turns a completed world save (level formats 3, 4 and stream
  format 5) into a new source map package: a DMM, a companion map metadata
  declaration, a manifest and a redacted report, with an optional full-game
  compile check. See [Native save export](#native-save-export) below.
- `core.py` is the earlier synthetic canonical-JSON core, kept as is.

The in-game admin verb Export Whole World (`code/modules/admin/map_area_export.dm`)
exports a running test world instead; `export.py` works from save files without
starting the game, and also writes the map metadata and spawns.

# Synthetic static-source export core

This is an offline canonical JSON validator, deterministic DMM geometry writer
and redacted disposition reporter. It is an initial serializer proof with an
exact wood/iron/chair catalog, not a useful full-world exporter or a working
save-to-map converter. It does not read `.sav` files, inspect a running world,
load maps, invoke BYOND or modify Civ13's DME/maps/configuration.

The only supported input is `kind: synthetic_static_source`, profile
`synthetic-static-v0` and explicit `synthetic_authored_fixture` provenance.
`tests/save_to_map/fixtures/canonical.json` is the complete 3x2x2 example. The
`synthetic_constructor_defaults` declaration is a fixture assumption, never
evidence about an actual object's saved material or flooring. Real-world source,
topology and constructor-default proof are not implemented.

Run from the repository root using a verified Python 3.10+ interpreter. On
Windows, use its full path to avoid the Microsoft Store aliases:

```powershell
& $PythonPath -I -B tools/save_to_map/core.py --input tests/save_to_map/fixtures/canonical.json --output C:/temporary/new-static-package
& $PythonPath -I -B -m unittest discover -s tests/save_to_map -p 'test_*.py' -v
```

The output parent must already exist and be a trusted directory. The package
path must not exist. Existing files/directories, symlinks/reparse components,
hardlinked input, duplicate JSON keys and input/output overlap are rejected.
The input is opened read-only and must end in `.json`; `.sav` is refused before
opening. This is not a hostile concurrent-filesystem containment mechanism.

## Projection and package results

Each cell explicitly supplies x/y/z, one exact allowed turf with a synthetic
default declaration, the allowed area and an ordered object list. Complete
unique in-bounds grids are mandatory. The core permits only exact policy types,
cardinal integer directions and bounded integer pixel offsets. Landmark names
must be the authored `JoinLateCivilian` token. At least one marker must be on wood
floor without a retained structure occupying that tile. This geometric check
does not establish a working job or native spawn.

All variable names and type paths sent to the writer come from fixed catalogs.
String literal encoding escapes backslashes, quotes, interpolation brackets,
newlines and tabs; unsupported controls, booleans, floats and arbitrary objects
are refused. The current policy emits only integers and the fixed landmark
token. Native acceptance of generated literals remains unverified.

- `static_source_only`: complete geometry for this synthetic catalog. Output has
  `geometry.dmm`, `report.json`, `report.txt`, `manifest.json` and a final
  `CORE_COMPLETE.json` receipt bound to the manifest hash. Every result says
  `ready: false`; this receipt confirms offline core output only.
- `rejected`: invalid grid/provenance, unknown terrain/topology, invalid admitted
  properties or an unsupported static object/property. No DMM or completion
  receipt is emitted. Reports contain fixed reason categories and counts.
- `--preview`: unsupported static objects (including unknown subtypes) may be
  omitted with explicit `incomplete_preview` status. An unknown variable with
  unknown semantics makes its whole object unsupported. Preview does not relax
  terrain, topology, input-integrity or required-spawn checks and has no receipt.

Mobs/NPCs and their subtrees, and nested contents of allowed objects, are
transitively omitted with explicit counts. Known identity, credential, user-text
and runtime variables are excluded. No raw input values, unknown type/field
labels, saved identifiers or paths enter reports or exception messages.
Descendants of skipped roots are marked uninspected, with their count unknown.
Report counters describe examined projection before acceptance; a rejected
projection's candidate counts do not mean a map was emitted. Group saturation
preserves exact aggregate/overflow counts.

Output files use exclusive creation and are verified before the completion
receipt. Write errors retain the partial directory without automatic retry.
Failed receipt writes remove only the newly created receipt; if its removal
fails, the result is explicitly `package_write_uncertain` and requires inspection.
Read/decode/IO errors before report construction return a fixed redacted CLI error
and exit 2. Strict rejection or incomplete preview exits 1; complete synthetic
core output exits 0. No exit code establishes compilation or playability.

## Bounds and verification scope

Fixed defaults: 1 MiB input JSON; 2 MiB aggregate output including the receipt;
4,096 cells; eight equal-sized levels; 4,096 objects and 32/cell; 64 fields/record;
65,536 visited data nodes; depth 16; 256 UTF-8 bytes/text value; 64 report groups.
The Python API can select lower test limits but cannot raise these maxima.
Exceeding a bound rejects the projection; output saturation produces a small
fixed rejection report. Unknown/skipped payloads still undergo tree bounds.

Tests execute real synthetic conversions and failure controls, including
determinism, coordinates, object order/multiplicity, literals, credential canaries,
unknown state, budgets, original-byte preservation, exclusive package writing,
injected write/receipt failures and redacted CLI behavior. They neither parse
native saves nor establish native syntax, material reconstruction, complete
topology, startup, rendering, job registration or gameplay acceptance.

See [the proposed companion profile](../../docs/save-to-map/synthetic-profile.md).
The core intentionally emits no metadata/job declarations and changes no DME.
Matching Civ13 code/assets remain required. Native save extraction and real
topology provenance are future work; the profile needs review and separate
source-to-native acceptance before any output can be called playable.

# Native save export

`export.py` reads a **copy** of a completed `map_saves/` generation and writes a
new package directory. It never loads the save into the game, edits the
production DME or touches a server.

```bash
source "$HOME/byond-516.1688/byond/bin/byondsetup"
python3 tools/save_to_map/export.py --save-dir /copies/gaia-map_saves \
  --export-id riverside --title "Riverside" --output /tmp/riverside-export \
  --byond-bin "$(dirname "$(which DreamMaker)")" --compile
```

On Windows: `py -3 tools\save_to_map\export.py --save-dir D:\copies\map_saves
--export-id riverside --title "Riverside" --output D:\exports\riverside
--byond-bin "C:\Program Files (x86)\BYOND\bin" --compile`.

Steps:

1. **Admit and copy.** The save folder must hold `map.txt`, `round.json`,
   `save_complete.txt` and the level files (`<z>.sav`, format-4
   `<z>.part<n>.sav`, format-5 `<z>.stream.sav`), all regular files. They are
   hashed, copied to a private temporary folder, and hashed again at the end:
   the export fails if the originals changed.
2. **Read.** `extract/extract.dme` is a standalone world with no game code. One
   Dream Daemon run per level reads the copied index: header, turf grid, zone
   captures and, for formats 3 and 4, each turf entry and its direct contents
   (type, field names, `dir`/`pixel_x`/`pixel_y`, content refs). No other saved
   value leaves the reader. Format-5 entries are decoded from the stream file
   by `savestream_reader.py` (pure data; no helper process). `round.json`
   contributes only the zone list (ID to area type), the spawn registry, the
   elevation snapshot and the map type. Generations must match everywhere.
3. **Project** through `native_profile.json` (`native-static-v1`):
   - every turf, by its saved type, which must exist in this checkout's source;
     unknown terrain rejects the export;
   - objects directly on turfs under `/obj/structure`, `/obj/covers` and
     `/obj/roof`, minus vehicles, trains, aircraft, orbit and vessel parts,
     economy/trade/account machines and event controllers;
   - `dir` and integral `pixel_x`/`pixel_y` (-32..32); every other saved field
     resets to its compiled default and is counted in the report;
   - areas from the saved zone capture (sparse cells use the level's baseline
     turf and zone); zones of the same area type merge into one area;
   - spawn landmarks rebuilt from the saved spawn registry (named latejoin
     groups, `start`, `JoinLate`, `supplydrop`); a `JoinLateCiv` spawn is
     required, since players join as Nomads.
   Mobs (players, NPCs, animals), loose items, effects and everything inside a
   kept object are left out. Unknown static types reject the export unless
   `--preview` is given, which omits them and marks the package incomplete.
4. **Write** `map/<id>.dmm`, `metadata/export_<id>.dm`, `INTEGRATION.txt`,
   `report.json`, `report.txt` and `manifest.json` (file hashes, source commit,
   save formats). The metadata is a direct `/obj/map_metadata` child with ID
   `EXPORT_<ID>`: a fresh Stone Age nomads round with map generation off, the
   saved elevation profile, the source map's terrain height file when it
   declares one, and the ordinary Nomad job enabled. It sits at (1,1,1).
5. **Compile** (`--compile`): a disposable root-local DME replaces only the
   `BEGIN_SELECTED_MAP` block with the export and includes the metadata after
   the other map metadata. It must compile with zero errors and warnings, and
   a copy with one turf renamed to a missing type must fail. Results go to
   `compile.json`.

Exit codes: 0 complete (and compiled when asked), 1 incomplete preview or
failed compile, 2 rejected (reason code on stderr, no map written).

Not carried over: players, inventories, contents of containers, research,
factions, economy, timers, vehicles, machine/network state, custom names and
text, damage and other per-object state, door locks and codes. Hills come back
only through the source map's terrain height file. Starting a round on the
export is still a manual step (`INTEGRATION.txt`); the exporter never adds it
to map rotation.

Reading a large full-file (format 3) level materialises it in the reader's
memory like a normal load does, but in a separate process. A synthetic
500x350 level with 350,000 entries reads in about a minute.

Tests:

```bash
python3 -I -B -m unittest discover -s tests/save_to_map -p 'test_*.py' -v   # offline, CI
python3 tests/save_to_map/run_native.py --byond-bin "$(dirname "$(which DreamMaker)")"
```

`run_native.py` writes synthetic saves in formats 3, 4 and 5 (the stream file
through the real helper), exports each, checks they produce the same map, that
no saved names, keys or IDs leak into any output, that original bytes are
unchanged, and compiles the format-3 export into the full game with the
missing-type control.
