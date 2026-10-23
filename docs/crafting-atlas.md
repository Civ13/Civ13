# Crafting atlas

The IC **Crafting Atlas** verb opens a local dependency diagram in the game
browser. Craft menus link to the same default view. Search and unlock-era or
processor filters narrow a sorted index of at most 150 matches; refine filters
to reach additional records. Select a recipe to follow inputs, quantities and
outputs. **Legacy paginated list** deliberately opens the older 12-record pages.
Requests are limited to once per second.
Icons are compiled from inherited defaults without constructing any items.
The hosted searchable diagram is published alongside source documentation at
https://civ13.github.io/Civ13/crafting/ by the existing Pages workflow.

## Unlock eras and processors

Era metadata comes from explicit minimum-era gates or the actual research node's
`era_tier`, rather than the catalog's maximum allowed era. That upper bound
remains in conditions and `maximum_era`. Research can be ahead of the map era;
the filter does not claim that a faction currently has the research, resources,
skill or map access. Multiple explicit tiers remain selectable individually or
through **Multiple eras**. Unmapped and contextual routes stay **Unknown**.

Nearby sawmills, grain mills and tanning racks expose **Processing Reference**. The processor
views show the three sawmill variants (4/10/12 nominal planks per log, with
skill-failure reductions) and manual/large grain conversions, including wheat
to flour. Grain quantities count whole objects, not equal reagent volumes.
Conditions describe anchoring, power, action completion, mood and stamina.
Processor era annotations describe station construction research, not a new
restriction on using an existing machine.

`scripts/atlas/catalog_metadata.py` extracts these conversions from production
code and rejects recognized source-contract changes for review. It does not
assert that every processor in the game is covered.

## Leather processing

Search for **raw hide**, **prepared hairless hide**, **wet hide**, **dry hide**,
**tree bark** or **tannin** to follow the complete [leather process](leather-tanning.md).
The adult turkey hen/tom acquisition routes each yield one raw hide; chicks yield
none. Scraping consumes one raw hide or fur pelt, washing consumes 5 water,
rack drying preserves the whole stack count after 300 ticks, and tanning consumes
5 tannin per dry hide to make one ordinary leather sheet. Existing leather
crafting recipes connect to that finished resource. Fur recipes remain connected
to the original species pelts, before the optional scraping step.

Hatchet cutting shows 2 logs to 1 plank plus 2 bark; saw cutting shows 1 log to
4 planks plus 1 bark. Applying an open held glass vessel with 10 water to one bark
produces 10 tannin in the vessel. These are explicit paid item interactions,
rather than chemistry recipes. Conditions show the required held tools/vessel.

The **Tanning racks** processor filter shows the drying conversion. Its station
resource links to the existing rack construction recipe (8 logs in the global
catalog) and Resource Processing research. The rack is labeled **not consumed**.
The displayed Bronze Age tier belongs to station construction research; using
an existing rack has no new era gate. Resource acquisition links retain the
reviewed production source revision. The old direct animal-to-leather route is
removed from the reviewed acquisition annotations.

`scripts/atlas/tanning.py` documents the procedural conversions, guarded by the
four reviewed source digests in `scripts/atlas/tanning-contracts.json`. Review the
routes and digests together when those callbacks change. Catalog generation
fails on source drift, rather than silently publishing stale costs or stages.

## Obtaining resources

Search for **tree seeds** or **wood** to follow [timber tree planting](tree-planting.md).
The reviewed route covers existing bush seed foraging, an empty outdoor ploughed
plot, watering and six successful growth stages, then ordinary tree chopping.
Seedlings mature into existing world trees; cutting a seedling no longer returns
logs or seeds. Winter pauses development and obstructions pause the stage clock.
The route is a source-reviewed procedure, not a guarantee of a map-placed crate.

Select an ingredient or product to see reviewed gathering and processing routes,
including steps, tools or stations, restrictions and conditional outcomes. The
same route data appears in the in-game reference, with at most 12 routes per
resource view. Producer recipes remain available for following processing chains.
Resources without reviewed instructions say so explicitly; raw production-site
occurrences are never presented as player acquisition instructions.

Annotations in `scripts/atlas/resource-sources.json` carry their reviewed source
commit. They are curated source interpretations rather than live map inventory
or guaranteed yields. Recipe additions regenerate automatically; changes to
procedural gathering behavior still require annotation review.

## Updating recipes

Production build scripts regenerate `UI/crafting-atlas.json` before compilation.
For a direct local DreamMaker build, first run:

```
python scripts/build-crafting-atlas.py --catalog-only --game-catalog UI/crafting-atlas.json
```

Windows users should use a verified Python executable rather than a Store alias.
The committed catalog supports direct compilation; regenerate it when changing
recipes. Check freshness with `--check-game-catalog UI/crafting-atlas.json`.

The Pages workflow generates current recipes and real PNG previews using pinned
BYOND 516.1681 and Pillow:

```
python scripts/build-crafting-atlas.py --output dmdoc/crafting --byond-bin /path/to/byond/bin
node scripts/atlas/check.mjs dmdoc/crafting
```

The compiler resolves inherited icon resources, states and directions without
constructing items. The isolated fixture exports first-frame icons through the
engine, checks required inherited sprites, and closes its listening port.
Transparent and missing defaults receive a real paper DMI source symbol with an
explicit abstract/dynamic label. A symbol is not a depiction of that resource.
Material-stack exemplars can differ from runtime recoloring, overlays and
constructor-selected states. No generated artwork is used.
Source-defined material stack/name aliases keep plank outputs connected to
softwood recipe inputs. The [frame preview](images/crafting-atlas-preview.png)
contains actual engine exports; flintlock-part attribution is preserved in
[flintlock assembly](flintlock-assembly.md).

## Scope and verification

The generator extracts every material catalog row, static anvil records,
chemical reactions with explicit products, native stack recipes and boiling
conversions. Alternative catalogs are not simultaneously available. Map, era,
faction, research, fuel, power, tools, timing and custom callbacks still govern
gameplay. Every lexical object/reagent production site remains searchable in a
separate source index; setup, effects and admin spawning do not become asserted
player acquisition routes.

Procedural acquisition annotations retain their historical audit revision in
`scripts/atlas/resource-sources.json`. They require review when behavior changes;
automatic extraction does not prove exhaustive acquisition or map reachability.
Unresolved inherited/custom reactions remain explicitly listed.

Flintlock assembly is a separate connected route: wooden stock, matching iron
barrel, steel mechanism and sharpened flint produce the same finished pistol or
musket. Loaded mechanisms and barreled stocks are distinct state nodes with
their actual DMI frames. The legacy 20-iron pistol anvil route remains valid;
its cost fields are alternative feedstocks, not a component list. The generator
now emits those alternatives separately instead of presenting cumulative costs.
Reviewed procedural extraction is guarded by source digests in
`scripts/atlas/procedural-contracts.json`; changes to those production callbacks
require review of the extraction and updated digests before generation succeeds.
Ordinary catalog additions regenerate automatically without that manual review.

`tests/test_crafting_atlas.py` adds a temporary recipe and proves stale catalog
detection plus regeneration, restoring the original source in `finally`.
`scripts/atlas/check.mjs` checks search/navigation and graph consistency using a
DOM contract. Neither establishes client rendering or gameplay reachability.

`tests/test_tanning_atlas.py` checks exact quantities, station research, all
processing-stage and acquisition links, the lack of direct animal leather, and
fur crafting continuity. Removing any essential stage breaks the turkey-to-leather
reachability control. `node tests/crafting_atlas/tanning.test.mjs` executes the
actual website template with the committed game catalog, including processor
filtering, construction links and every tanning resource's producers and uses.
These are offline catalog/DOM checks. The new full native renderer cases are
authored but have not run while native validation is held; no browser appearance,
engine-exported new previews or in-game client acceptance is claimed.
The sprite harness's existing `--negative-control` rejects a deliberately wrong
inherited icon resource. Runtime constructor/overlay graphics need separate
focused evidence when their appearance matters.
`tests/crafting_atlas/run.py` runs the real bounded renderer in a temporary
native BYOND fixture, checking pagination, ingredient search, escaping, real
fallback sprites and zero item constructors. Its pagination negative control
must fail. These contracts do not prove a particular BYOND client rendering.
