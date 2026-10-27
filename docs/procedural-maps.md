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
surface algorithm and golden hashes. Legacy oceanic schema 1 and cavern
generation reject explicitly. The reserve underground plane is not a playable cavern.

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
| UNDERGROUND_CAVERN | Connected usable chambers/passages, paired safe layer entrances/exits, start/resource/exit routes | Validators/fixtures only; generator rejects |

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

The current static export catalog pins Civ13 commit
`067478b82c7ad9f1b83759a221e6f22080ba865a`. Export verifies actual declarations
and Git blob identities, accounting for LF/CRLF checkout conversion. If source
changes cause `CATALOG_SOURCE_MISMATCH`, use a clean matching source checkout
instead of weakening pins. For example, manually prepare another Git worktree:

```sh
git worktree add --detach ../civ13-map-catalog 067478b82c7ad9f1b83759a221e6f22080ba865a
python3 -m tools.procedural_maps generate --config data/procedural_maps/config.json --out data/procedural_maps/pinned-demo --catalog-root ../civ13-map-catalog
```

This optional worktree command only prepares source. The tool does not create
it, download dependencies, update a BYOND installation or launch an editor.
Use `--catalog-root` consistently for `export`, `verify` and source inspection
when the current checkout has drifted.

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
and sidecars, and the emitter adds no playable native supply objects.

Full hydraulic bed/head/capacity simulation, arbitrary river graphs, naturalistic
channel curvature, minimum ecotone width, native actor/resource behavior,
runtime climate/elevation, persistence and cavern generation remain
future work. The prototype cannot approve production host capacity or a live
map replacement. It never opens or overwrites saved player worlds.

## Tests and contributions

From the repository root:

```sh
python3 -I -B tests/procedural_maps/run.py
```

The explicit test list retains the prior generator/validator/config, source
annotation, source-backed resource proposal, golden/hash, negative-control and
DMM round-trip tests. Public CLI tests exercise the commands above, output
preservation, strict JSON, catalog drift and complete bundle binding. GitHub
Actions runs this suite on Ubuntu/Windows with Python 3.11/3.13; ordinary repo CI
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
