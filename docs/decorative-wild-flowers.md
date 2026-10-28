# Inactive decorative wild-flower types

Four concrete types reuse the existing `/obj/structure/wild/flowers` behavior:

| Type suffix | State in `icons/farming/humanity_wild_herbs.dmi` |
| --- | --- |
| `yarrow_scenery` | `yarrow` |
| `milk_thistle_scenery` | `milk_thistle` |
| `elderflower_scenery` | `elderflower` |
| `comfrey_scenery` | `comfrey` |

All paths begin `/obj/structure/wild/flowers/`. They have the same initial health,
layer, anchored/non-dense/non-opaque defaults and inherited destruction/removal
behavior as ordinary flowers. They are not farming plants, bushes or tall grass.
They introduce no medicine, seeds, harvest, usable leaves, fibre, branches, wood,
recipes or species physiology. Their descriptions identify visible plants without
claiming medical efficacy.

No existing map, seeding function, random spawn pool, climate policy, native map
metadata or procedural generator references these types. They are inactive source
definitions for later review. No placement or gameplay activation occurs.

## Appearance and inherited effects

The default-false `fixed_flower_appearance` field is source policy. Ordinary
flowers retain their exact `flower[rand(1,14)]` constructor. Each new subtype sets
the flag and pins its original 32x32, one-direction, one-frame image. Its constructor
does not draw a second appearance or request invented crop/dead/sway states.

Radiation calls the unchanged inherited `rad_act` first. If the parent selected
its generic fallback resource/state after a positive dose, the subtype restores
only its fixed image. Radiation accumulation, threshold behavior, health/maxhealth
halving and the existing irradiated name are retained. Repeated doses do not add
repeated damage by clearing that name. The live image identifies the plant; it is
not a dead/healthy/radiation indicator. Nonpositive and subthreshold doses do not
erase a seasonal icon produced by existing code. No radiation immunity is added.

Wild saves use an existing partial allowlist that includes `icon_state` and name
but omits `icon`. `after_load()` delegates to its parent, then restores the fixed
subtype's initial resource/state. This also normalizes an old or mismatched state
against that resource. The ordinary flower's load behavior remains unchanged.
The global saver, loader and allowlist are untouched; no claim is made that health
or radiation now persists when the parent's policy did not preserve it.

Existing fire, attacks, tool wear, strength adaptation, explosions and seasonal
color/overlay code remain inherited. These are not indestructible props. No new
worker, timer, regrowth or per-world vegetation registry is added. Source art,
credit, metadata and hashes remain exactly as imported in frozen PR #3332.

This local combined review reconciles the independently prepared `flower3` fix
inside the ordinary-flower else branch only. Roll 3 reuses existing `flower2`;
fixed scenery retains its chosen state without a draw. Both original commits and
the original failing evidence remain unchanged on their separate branches.
Combined offline checks do not establish native acceptance.

## Validation and limits

From the repository root, using a verified Python 3 executable and Pillow:

```powershell
& $PythonPath -B -m unittest discover -s tools/art_ports -p test_decorative_flowers.py -v
& $PythonPath -B -m unittest discover -s tools/art_ports -p test_humanity_wild_herbs.py -v
```

Thirteen offline tests execute the selected production constructor, normalization,
radiation and load-hook source bodies through a small fail-closed scalar adapter.
They check the four original assets and required-type manifest, all 14 reconciled
generic draw outcomes, 96 radiation starting-state/dose combinations, repeated
and nonpositive doses, generic-parent parity and the actual allowlist's projected
round trip. Omission controls expose overwritten constructor states, a missing
parent radiation call and missing after-load normalization. Another control exposes
the damage suppression caused by setting the parent's dead image equal to the live
image. Unknown source syntax is rejected. Protected-source hashes guard eleven
shared placement, farming, radiation, persistence, interaction and DME files.
The nine unchanged conversion/source-hash tests are also retained.
Four standalone pool-audit tests additionally pass. A combined check compares the
source projection with the independent pool/DMI audit and every fixed type under
all 14 injected ordinary-flower rolls. No random sampling is used.

These are **offline source projections**, not DM execution. Parent construction,
parent loading, native icon-resource identity and JSON primitive round trips are
adapters. They do not prove real savefiles, season/overlay reconstruction, tool
interaction dispatch or client rendering. Four types were added to the existing
compiled sprite-required manifest, but its native extractor was not launched.
No world/server or native fixture ran, and no native tools were installed. A hosted
compile, if reported on the PR, remains separate from runtime acceptance.

## Placement handoff to the existing generator owner

Ownership remains with #3331 / #3338 and their current continuations. This task
does not edit `tools/procedural_maps`, its exact schemas, frozen source catalogs,
golden maps, hydrology, routes or sidecars. The new `wild.dm` source hash requires
that owner to review any future catalog refresh; do not bypass drift rejection.

Later placement needs a separately reviewed, default-off consumer. Prefer existing
temperate flower opportunities rather than extra vegetation rolls. Preserve default
maps, RNG state/order, resource and tree yields; exclude roofs/indoors, occupied
tiles, crop plots, water/deep/salt/ice sites, starts, routes, resource and port
reservations. Do not preplace decorations before native `plant()` and silently
suppress its structure-guarded vegetation roll. Do not overload generator `tree`
or `resource` fields for flowers. Future schema/export changes need strict versioned
IR/DMM/sidecar round trips and existing golden preservation under the current owner.

Humanity reeds remain unimported: native `ausflora.dmi:smallbush5..8` already
provides cattail-like art. A dedicated no-yield wetland placement policy for those
existing images is a future decision, not an additional feature in this branch.
