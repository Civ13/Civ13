# Generate an offline procedural map

This experimental tool makes new map data and a static `.dmm` layout for Civ13.
It runs locally with Python and does not start the game or change installed maps.
The current SURFACE backend supports configurable coast/edge-port sides and
spans, a confluence, a lake, connected mountain ranges, climate regions,
vegetation and abstract start/resource routes. It does not yet produce a verified
playable native round. A separate OCEANIC backend now generates islands with
inland fresh lakes and connected navigable salt sea; see the profile section below.

## Prerequisites

1. A local checkout of this Civ13 source, including `tools/`, `code/`, `maps/`
   and the root `civ13.dme`. Run commands from the repository root.
2. Python **3.11 or later**. The generator and tests use only the standard
   library; there is no pip install step.
3. For later **viewing only**, a separately installed BYOND Dream Maker editor
   and the matching complete Civ13 project/assets are required. Python generation,
   validation and export do not require BYOND. The source project's current
   toolchain requirement is recorded in `tools/byond/version.json`.

On Linux/macOS use `python3` below. On Windows select a real Python installation;
the Microsoft Store alias may not work. In PowerShell, set a variable to **your**
installed executable, then invoke it with `&`:

```powershell
$Python = 'C:\Path\To\Python\python.exe'
& $Python --version
```

## First map: one small candidate

These commands produce a 64 x 80 surface plus an equal blocked underground
reserve. The default seed is `ports-0`. Every output path must be new.

```sh
python3 -m tools.procedural_maps preset --out data/procedural_maps/config.json
python3 -m tools.procedural_maps validate-config data/procedural_maps/config.json
python3 -m tools.procedural_maps generate --config data/procedural_maps/config.json --out data/procedural_maps/demo
python3 -m tools.procedural_maps verify data/procedural_maps/demo
```

PowerShell equivalents:

```powershell
& $Python -m tools.procedural_maps preset --out data/procedural_maps/config.json
& $Python -m tools.procedural_maps validate-config data/procedural_maps/config.json
& $Python -m tools.procedural_maps generate --config data/procedural_maps/config.json --out data/procedural_maps/demo
& $Python -m tools.procedural_maps verify data/procedural_maps/demo
```

Open `data/procedural_maps/demo/preview.png` for a typed-data preview, visibly
labeled **OFFLINE PROTOTYPE - NOT GAMEPLAY**. Orange marks declared port spans;
purple marks the graph confluence. It uses generated data and its own simple
renderer, not game sprites or a copied reference image.

For a 155 x 225 map with an eastern coast and another seed, use a new config and
output directory:

```sh
python3 -m tools.procedural_maps preset --coast E --seed my-seed --width 155 --height 225 --out data/procedural_maps/east.json
python3 -m tools.procedural_maps generate --config data/procedural_maps/east.json --out data/procedural_maps/east-map
```

One attempt can reject: numeric configuration validity does not guarantee a
geometrically feasible map. Rejected candidates return exit **1**, print reasons
and write `rejection.json`; there is no silent retry or rule relaxation. Input,
catalog, output-conflict or export errors return **2**. Exit **0** confirms only
the requested offline operation. An existing output path is refused, including
an incomplete earlier result. Choose a new path; no automatic cleanup occurs.
A bundle is complete only after `complete.json` exists and `verify` succeeds.

## Output files

| File | Purpose |
| --- | --- |
| `map.ir.json` | Complete typed intermediate representation (IR) |
| `seed.manifest.json` | Exact config/hash, seed, algorithm/content/profile versions, route/graph records and IR hash |
| `map.dmm` | Static native-type/area/object layout for the pinned catalog |
| `map.dmm.sidecar.json` | Complete semantic IR and manifest, bound to the DMM hash |
| `roundtrip.json` | Static DMM parse-back result and its acceptance limits |
| `preview.png` | Original generated-data preview; optional with `--no-preview` |
| `complete.json` | Expected bundle file hashes; written last |

Keep the sidecar and seed manifest with the DMM. River/lake identity, bodies,
port spans, graph nodes, climate, elevation and abstract supplies are not
undefined DM variables. They live in the sidecar. DMM alone does not retain all
IR semantics. Verification checks file hashes, config/version/IR binding,
sidecar equality, every native layout coordinate/atom and pinned source types.
It does not establish engine rendering, gameplay or persistence.

Validate an IR or re-export an existing IR/manifest to a new bundle:

```sh
python3 -m tools.procedural_maps validate data/procedural_maps/demo/map.ir.json
python3 -m tools.procedural_maps export --ir data/procedural_maps/demo/map.ir.json --manifest data/procedural_maps/demo/seed.manifest.json --out data/procedural_maps/reexport
python3 -m tools.procedural_maps verify data/procedural_maps/reexport
```

Generation never reads `.sav` files. Its CLI accepts JSON data and a source
catalog; it has no runtime/server application command. The `data/` output area
is ignored by Git. Do not commit large generated IR/sidecars or put output into
live-server directories.

## Playable region maps

`map.dmm` is the offline terrain layout: it keeps cave floors as solid rock and
leaves supplies and cave exits in the sidecar. `playable` turns a verified
bundle into a separate DMM that a region world can run, without changing the
bundle or its hashes:

```sh
python3 -m tools.procedural_maps playable data/procedural_maps/demo --out data/procedural_maps/demo-playable.dmm
```

It writes the DMM and `<name>.playable.json` (bundle and output hashes, starts,
ladder pairs and supply counts). The native supply layer
(`civ13-native-supplies/2`, `tools/procedural_maps/playable.py`) is
deterministic from the IR seed and coordinates:

| Source | Native result |
| --- | --- |
| STONE site | flint rock (`/obj/structure/wild/rock`) |
| WOOD site | tree for the biome (broadleaf, pine on arid, palm on coast); dead tree in caverns (does not block passage) |
| FOOD site | berry bush that starts stocked and regrows; about a third also get a turkey or boar spawner; mushroom spores in caverns |
| Open grass | about 3% tall grass and 3% small bushes |
| Water | a few fish (fresh water more than sea) |
| Cavern floor | open dirt instead of solid rock; some fungus cells get mushrooms |
| Cavern exit pair | ladder down on the surface plane, ladder up below |

Start cells stay clear. Every placed type is checked against the DM source
before writing.

The map also keeps its relief. The IR's per-cell elevation becomes the Nomads
metadata's [elevation profile](elevation.md) with a lapse rate of 6.5 C per km
(`--lapse` sets 0 to 10; 0 keeps the climate flat). Equal heights merge into
rectangles, and the default is whichever of the three most common heights needs
the fewest; if a map needs more than the 256 rectangles DM accepts, heights are
rounded to coarser bands (50, 100, 200, 500 then 1000 m) until it fits, and at
1000 m only the largest 256 are kept. The report's `elevation` entry gives the
band, the rectangle count and any dropped. On the 64 x 80 pilot surface map,
216 rectangles cover hills and mountains up to 1000 m; a native boot read 9 C at
sea level, 8 C at 100 m, 6 C at 400 m and 2 C on the 1000 m peak. Use the result as a region map with
[scripts/shard-group](../scripts/shard-group/README.md) (an absolute `map`
path is copied into the region). It runs under the classic Nomads metadata.

On 2026-11-05 a Linux run of the three example profiles as one region group
loaded without runtime errors; a Nomad spawned at a start in each, found flint
in a surface rock, and walked to a cave exit and climbed to the surface. No
Windows client or long round was tested.

### Barren worlds

For the [space settlement roadmap](space-settlement-roadmap.md), a SURFACE
bundle can be written as a barren world instead. `preset --barren` gives the
port surface family a dry, cold and bare configuration (70% desert and 30%
arid land, -50 to -10 C, no vegetation, one to three ranges, six starts), and
`playable --skin barren` writes it as a barren region map:

```sh
python3 -m tools.procedural_maps preset --profile SURFACE --barren --width 200 --height 200 --out data/procedural_maps/barren.json
python3 -m tools.procedural_maps generate --config data/procedural_maps/barren.json --out data/procedural_maps/barren
python3 -m tools.procedural_maps playable data/procedural_maps/barren --skin barren --out data/procedural_maps/barren-playable.dmm
```

| Source | Barren result |
| --- | --- |
| Open ground, hills and beaches | regolith (`/turf/floor/dirt/dust/regolith`) |
| Lakes and sea | ice (`/turf/floor/beach/water/ice`) |
| Rivers and swamps | dry channels of crater floor (`/turf/floor/dirt/dust/regolith/crater`) |
| Mountains | bare basalt ridges, as on the native skin |
| STONE site | flint rock |
| FOOD and WOOD sites, trees, grass, bushes, fish, game | nothing |
| Surface area | `/area/caribbean/nomads/barren` (dry climate, dust storms) |

Regolith has no breathable outside air and a -60 C ambient for the life-support
work in later phases; until those land, the map plays like a cold, empty desert.
The underground reserve plane and starts are unchanged, and the report records
`"skin": "barren"`. The barren skin refuses OCEANIC and cavern bundles.

To run one as a region, add it to a shard group like any other generated map,
with `kind` `OTHER`. Keep it out of the first position, which is the mainland.
Players should not be sent there until launch sites exist (phase 2).

#### Survey maps

The mission console that flies survey probes reads a coarse map of a barren
world from `config/space/survey/<region>.json` instead of loading a level. `survey`
writes it from a verified SURFACE bundle; each cell covers 5x5 tiles (change it
with `--cell-tiles`) and takes the most common class among them, with ties going
to ridge, then ice, then channel, so hazards are never hidden:

```sh
python3 -m tools.procedural_maps survey data/procedural_maps/barren --out config/space/survey/barren.json
```

| Source tiles | Survey cell |
| --- | --- |
| Open ground | `.` plain (costs the probe 1 battery) |
| Rivers and swamps | `~` dry channel (2) |
| Lakes and sea | `*` ice (3) |
| Mountains and rock | `^` ridge (blocks the probe) |

Rows run south to north and the map must be 8 to 64 cells a side with at least
one plain to land on. The shipped map is the 200x200 `barren-0` preset at 40x40;
a test regenerates it, so rebuild it with the command above after a generator
change. Replacing the file while a probe is flying loses that probe.

Files are keyed by destination region (`config/space/survey/<region>.json`,
lowercase letters and digits only) and record the source bundle's
`ir_sha256`. `survey-check` exits 0 when a survey map was drawn from a
bundle and 1 when it was not; generate each region's survey map from that
region's own bundle:

```sh
python3 -m tools.procedural_maps survey-check data/procedural_maps/barren --survey config/space/survey/barren.json
```

## Configuration reference

Use `preset` for seed, dimensions and N/S/E/W coast selection, then edit the new
JSON for advanced controls. Re-run `validate-config` before generation. Examples
under `tools/procedural_maps/examples/` include all four coast sides and legacy
profile configs. Changing dimensions manually also requires reviewing absolute
port spans; `preset` recomputes those for the selected dimensions.

| Group | Supported controls and units |
| --- | --- |
| Identity | Schema, preset/profile and ASCII seed of 1..128 characters. Exact config is saved; no hidden wall-clock seed. |
| Dimensions | Width/height 32..512. Two equal planes: `SURFACE: 2`, `UNDERGROUND: 1`. Limits are provisional offline caps, not measured safe native host ranges. Start with 64 x 80. |
| `biome_mix_pct` | Land-only percentages summing to 100. Current SURFACE backend supports contiguous subsets of lush -> temperate -> steppe -> arid -> desert. |
| `climate` | Moisture 0..100 and temperature -50..50 C ranges. Lush/desert envelopes and permitted transitions remain mandatory. |
| `water` | Whole-map coverage/sea/swamp/lake-area percentage intervals; river-network/lake counts; interior raster-brush width 1..16. |
| `mountains` | Range count, minimum connected component area and width. Mountain-free settings remain supported. |
| `vegetation` | 0..70% occupancy of suitable, unreserved habitat; no ordinary trees in water or blocked sites. |
| `resources` | Extra abstract labels per 1,000 land tiles; required abstract start supplies are handled separately. These are not native items. |
| `starts` | Count 1..64, minimum cardinal spacing 3..64, maximum abstract survival route 8..256 tiles. Actual geometry can still reject. |
| `surface_layout` (schema 2) | Sea side; 2..3 named inlet ports; outlet; lake/confluence anchors and climate axis. |

For schema 2, each port has a side and inclusive **zero-based** span. N/S spans
index x; E/W spans index y. Span width is 1..16; corners and overlapping spans
reject. Inlets cannot occupy the solid sea-coast side. `outlet.kind: SEA`
requires positive sea coverage on the same side. `EDGE` requires
`sea_side: NONE` and `water.sea_pct: [0,0]`. The implemented graph family has one
connected network, one confluence and one through-lake: set both network and
lake count intervals to `[1,1]`. Arbitrary river graphs are not implemented.

`junction_pct` and `lake_pct` give interior anchor percentages. The
`climate_axis` is a nonzero integer vector with components -4..4, combined with
a smooth 2D field. Zero vectors, unsupported fields and conflicting controls
reject. Geometry and playability invariants cannot be disabled by configuration.
IR grid row zero is south; the writer reverses rows for DMM and adds one to x/y.
Native z-levels are layer IDs, not geographic elevation.

Legacy schema 1 and `--legacy` preserve the earlier north-inlet/south-coast
surface algorithm and golden hashes. Legacy oceanic schema 1 rejects explicitly.
The reserve underground plane of a surface map is not a playable cavern; use the
UNDERGROUND_CAVERN profile below for that.

## Underground caverns

```
python3 -m tools.procedural_maps preset --profile UNDERGROUND_CAVERN --seed cave-0 --width 64 --height 80 --out cave.json
python3 -m tools.procedural_maps generate --config cave.json --out cave-bundle
python3 -m tools.procedural_maps verify cave-bundle
```

The cavern backend works on the UNDERGROUND plane (native z1):

- About one chamber per 900 tiles (4 to 40) is grown from a noise-shaped blob
  on a jittered lattice. A minimum spanning set of tunnels plus one loop joins
  them, so every usable floor tile is connected.
- Spring pools are fresh, terminal lakes grown into solid rock beside a chamber.
  They can never cut the floor apart. The water and lake intervals in the config
  bound their total area. Underground rivers and wetlands are rejected before
  generation (`BACKEND_RIVERS`, `BACKEND_WATER`).
- Fungus pillars (`FUNGUS`) only go where all eight neighbours are open floor and
  no other pillar touches them, so they never block a passage, route or exit.
- About one chamber in four gets a surface exit, paired with the same tile on an
  open placeholder SURFACE plane. Starts keep a reserved route to a pool bank and
  to FOOD/WOOD/STONE within four tiles.
- DMM export writes cave floor as `/turf/floor/dirt/underground` and rock as
  basalt. Fungus pillars and the exit pairs have no pinned native type yet and
  stay in the sidecar.

## Oceanic islands (configuration and IR schema 3)

Run from the same repository root with the same Python prerequisites:

```sh
python3 -m tools.procedural_maps preset --profile OCEANIC --seed ocean-0 --out data/procedural_maps/ocean.json
python3 -m tools.procedural_maps validate-config data/procedural_maps/ocean.json
python3 -m tools.procedural_maps generate --config data/procedural_maps/ocean.json --out data/procedural_maps/ocean-map
python3 -m tools.procedural_maps verify data/procedural_maps/ocean-map
```

In PowerShell use `& $Python` in place of `python3`. For reference dimensions,
add `--width 155 --height 225` to `preset`. A new seed or tighter settings can
reject; this is one bounded candidate, with the same rejection log and new-path
rules as SURFACE. `--coast` is rejected for OCEANIC; oceanic coasts surround
each island and four ocean edge ports are declared automatically.

| Profile | Mandatory topology and start rules | Implemented generation |
| --- | --- | --- |
| SURFACE | Explicit river edge ports, graph/raster confluences, valid lake/sea endings; clear abstract survival routes | Config schemas 1 and 2 |
| OCEANIC | Majority salt sea, separate inland islands, connected deep sea and eroded ship-clear core, ocean edge access, inland fresh basin and start on every island, bounded fresh/coast/resource routes | Config schema 3 |
| UNDERGROUND_CAVERN | Connected usable chambers/passages, paired safe layer entrances/exits, start/resource/exit routes | Config schema 1 |

`ocean_layout` is required in schema 3. These are provisional offline caps:

| Control | Meaning and bounds |
| --- | --- |
| `island_count` | Inclusive interval, 2..6; one count is selected per candidate. |
| `island_min_area` | Minimum dry cells per island after lake carving, 32..8192. |
| `island_gap_tiles` | Minimum cardinal sea gap, 4..24; must be at least `2 * ship_radius + 2`. |
| `ship_radius` | Square footprint radius 1..3; the deep-water core after erosion must remain connected. This is abstract clearance, not a native boat test. |
| `coast_width_tiles` | Sand beach depth in cardinal tiles, 1..4; shore moisture does not become desert. |
| `climate_axis` | Nonzero integer vector with components -4..4 for the interior climate gradient. |

Existing water, mountain, vegetation, resource and start controls still apply.
This slice requires `river_networks: [0,0]` and `swamp_pct: [0,0]`; positive
requests reject before generation. `lake_count` must equal the island-count
interval. Each island has exactly one positive-area **terminal inland lake**,
wholly surrounded by dry land. It has no inferred flow or invented spring.
Island lake-to-sea rivers need a new explicit endpoint grammar and are deferred;
they must not borrow the SURFACE rule requiring map-edge river inlets.

Start count must cover the maximum island count. Starts rotate between islands,
respect cardinal spacing and retain tree-free witnesses to fresh-water banks,
navigable coasts and synthetic FOOD/WOOD/STONE sites. No native supplies are
emitted. Mountains are connected elongated components, at most one requested
range per island in this version. Unsupported packing rejects explicitly.

The implementation recursively partitions the longer extent, reserves sea
channels, and grows islands by a seeded radial priority. Inland lakes and ranges
also use bounded connected growth. Shape variety is currently limited by this
partition/radial family. The sidecar records realized counts, component water
coverage, eligible tree density, route witnesses and growth expansion counts.
Climate fractions are targets with coastal relabelling, not exact biome areas;
shared gradient, ecotone and habitat checks remain mandatory. A COAST biome label
retains its underlying climate; the physical sand strip is distance-based.
Every candidate gets independent graph/raster validation; there is no repair,
hidden retry, image input or large seed search. No native boat or gameplay
acceptance is established by the offline water-connectivity check.

## Source catalog and Dream Maker viewing

The current static export catalog `civ13-static-layout/4` pins declarations,
not whole files: each exported type must be declared exactly in its source file and
that file must be included by `civ13.dme`. Unrelated edits to those files keep it
valid. It was first verified at `bc7209b23d4ee39651a736a7a9ddb1d1081166ac`, which
manifests record as its source commit; no checkout of that commit is required.
Historical catalogs `civ13-static-layout/3`, `/2` and `/1` respectively pin the
whole-file Git blobs of `c39f4d6846c8882df0097a6bba021cc5288a9229`,
`eedc9862fcb7b2b7c3617c6972965fafa650e51a` and
`067478b82c7ad9f1b83759a221e6f22080ba865a`, accounting for LF/CRLF conversion.
A fresh seed uses the first historical catalog its checkout matches exactly, and
`/4` otherwise; it rejects mixed or unknown source. New seed manifests record
their catalog version and source commit. A bound manifest cannot be re-exported
against another catalog. An older unbound manifest requires an explicit
`export --catalog-version civ13-static-layout/1`, `/2`, `/3` or `/4` choice; use
the matching `--catalog-root`. Existing historical bundles verify only against
their historical catalog, without rewriting their sidecars.

If a historical bundle reports `CATALOG_SOURCE_MISMATCH`, use a clean matching
source checkout instead of weakening pins. `CATALOG_TYPE_MISSING` or
`CATALOG_INCLUDE_MISSING` under `/4` means an exported type was renamed, removed
or dropped from the DME; that needs a new catalog version, not a looser check.
For example, prepare the historical source:

```sh
git worktree add --detach ../civ13-map-catalog 067478b82c7ad9f1b83759a221e6f22080ba865a
python3 -m tools.procedural_maps generate --config data/procedural_maps/config.json --out data/procedural_maps/pinned-demo --catalog-root ../civ13-map-catalog
```

This optional worktree command only prepares source. The tool does not create
it, download dependencies, update a BYOND installation or launch an editor.
Use `--catalog-root` consistently for `export`, `verify` and source inspection.
For an old unbound manifest, explicitly select its intended catalog when exporting:

```sh
python3 -m tools.procedural_maps export --ir old/map.ir.json --manifest old/seed.manifest.json --out data/procedural_maps/old-export --catalog-version civ13-static-layout/1 --catalog-root ../civ13-map-catalog
```

The four catalogs project the same static map types and layout. Version 2 adds
flower declarations and DME includes; version 3 maps the missing generic flower3
appearance to flower2 without another random draw. Version 4 changes only how
source is verified, so it cannot detect constructor or appearance edits inside the
declaring files. This comparison does not
establish equal native appearance, constructor, runtime or gameplay behavior.

To view a generated DMM later:

1. Use the matching Civ13 checkout with its full `civ13.dme`, included DM sources
   and `icons/` assets. A standalone DMM cannot resolve project types/icons.
2. Open that DME in Dream Maker, then open the generated `map.dmm` in the map
   editor. Keep the sidecar and seed manifest beside it. Do not replace the
   project's map include merely to inspect a layout.
3. Treat editor viewing, compilation and running a round as distinct actions.
   The offline tool performs none of them. Static parse-back has been tested;
   native editor appearance and gameplay have not been established by it.

The export uses uniform keys, literal landmark overrides, objects before turf
before area, equal planes and north-first rows. Mountains/blocked reserve are
projected to dense basalt on underground dirt; this does not add a runtime
elevation system. Constructors can randomize icons and schedule work, so static
determinism does not imply deterministic runtime appearance, lighting or state.

## Reference and native-resource limits

The classic source map is 155 x 225 x 2, with surface z2 and 18 JoinLateCiv
markers. Source inspection is reproducible without an image download:

```sh
python3 -m tools.procedural_maps audit-source
python3 -m tools.procedural_maps annotate-reference --out data/procedural_maps/reference-proposal.json
```

Annotations distinguish exact water-type components/edge contacts from proposed
lake cores, channels and unresolved flow direction. They do not assume the
source meets new invariants. Brown is not proof of mountains; beach sand is not
proof of desert. If you separately obtain the
[reference PNG](https://civ13.github.io/civ13-wiki/images/map_temperate.png),
`audit-source --reference-image PATH` can verify its expected byte identity.
The image is not bundled or read by generation.

No seed matching that image has been demonstrated. Structural similarity needs
reviewed annotations and frozen thresholds; exact reconstruction is a separate
semantic-equality claim. Neither a color mask nor passing offline fixtures proves
a matching Civ13 generator. No automatic large seed search is included.

`tools/procedural_maps/catalog/native-resources-v0.1.json` is a frozen,
source-backed **proposal, not an admitted native catalog**. It records wood,
flint and forage candidates with unresolved interaction/era/quantity/safety
gates. Flint is not generic stone blocks; an edible flag is not proof of
common-human nutrition. FOOD/WOOD/STONE remain abstract reachable labels in IR
and sidecars, and the bundle emitter adds no playable native supply objects;
the separate `playable` command above does.

Full hydraulic bed/head/capacity simulation, arbitrary river graphs, naturalistic
channel curvature, minimum ecotone width, native actor/resource behavior,
runtime climate beyond the elevation lapse rate, persistence, native cavern fungus and exit types,
and underground rivers remain future work. The prototype cannot approve production host capacity or a live
map replacement. It never opens or overwrites saved player worlds.

## Tests and contributions

From the repository root, prepare the historical checkout above and separate
version 2 and version 3 source checkouts. The suite checks original evidence and
all catalogs:

```sh
git worktree add --detach ../civ13-map-catalog-v2 eedc9862fcb7b2b7c3617c6972965fafa650e51a
git worktree add --detach ../civ13-map-catalog-v3 c39f4d6846c8882df0097a6bba021cc5288a9229
python3 -I -B tests/procedural_maps/run.py --historical-catalog-root ../civ13-map-catalog --intermediate-catalog-root ../civ13-map-catalog-v2 --v3-catalog-root ../civ13-map-catalog-v3
```

The explicit test list retains the prior generator/validator/config, source
annotation, source-backed resource proposal, golden/hash, negative-control and
DMM round-trip tests. Public CLI tests exercise the commands above, output
preservation, strict JSON, catalog drift and complete bundle binding. GitHub
Actions runs this suite on Ubuntu/Windows with Python 3.13 (master's supported version only); ordinary repo CI
retains its own selection and compile policy. Tests do not launch a native game.

When contributing, keep old algorithm versions/golden vectors stable or add a
new version with an explicit migration story. Add a focused negative control
for each new invariant. Keep invariant rules separate from density/scale
targets, bound attempts/repairs, record rejected seeds, and preserve uncertain
reference annotations. Add tests to the explicit `TEST_FILES` list in `run.py`.
Do not include native test launchers in this offline suite, change source pins
to hide drift, add DFLib or other unreviewed dependencies, or commit large raw
generated outputs. Propose native catalogs/integration separately, with exact
source and acceptance evidence.
