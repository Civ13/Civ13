# Recipe research coverage (phase 0, issue #4239)

## Scope and baseline

The implementation base is `dc938f7429530ee4c117edc34da1110900084fa0`.
The grouped atlas still contains 3,418 distinct recipes. The original output-only
count was 2,700 mapped and 718 unmapped; it did not canonicalize material stack
aliases or inspect explicit factory, foundry and armor recipe requirements.
The new coverage is route-based: 3,112 gated, 11 basic and 295 excluded records.
There are 114 research nodes, including two new chemical-cell nodes.

The generator now fails on any non-basic crafting route without a valid node.
`research_nodes` lists every required node for the specific route;
`research_status` distinguishes gated, basic and excluded records. Grouped material
variants retain the same semantic research metadata. Maximum recipe eras are
expiry bounds, never evidence of an unlock era.

## Confirmed basics and exclusions

Only these exact outputs are exempt: ordinary rope, stone bricks, research desk.
Subtypes do not inherit the exemption. The old Basic Tools mapping on ordinary
rope has been removed. Factory-produced bricks still require the factory route's
Assembly Line node. Paid yarn can still be laid into basic rope, while producing
its prepared intermediates requires Basic Tools. Map/mode, tool, stock and expiry
conditions remain in force even for basics.

Stone/early tools, fire, shelter, research bench and trail marker are NOT silently
exempted. They retain nodes and are proposed onboarding basics for review. In
particular, a new character in the later knowledge phase needs a starter manual
to make a research bench; that phase's flag must not be activated before onboarding
is approved and available.

The 295 exclusions are the 152 generic chemistry reactions, 139 curated
acquisition records, three corpse-hide harvesting records historically classified
as tanning, and one flint-gathering record historically classified as flintlock
preparation. Scraping/tanning, explicit bark tannin production and flint sharpening
are crafting and are gated. No generic mixing, mining or butchering check is added.

## Runtime enforcement

`recipe_gates.dm` separates world eligibility from the actor admission hook:

- `crafting_node_world_allowed(faction, node_id)` validates a real node and checks
  the unchanged faction/era ceiling.
- `crafting_node_allowed(H, node_id)` is the shared actor hook for later personal
  knowledge. Unknown nodes fail closed.
- `crafting_recipe_allowed(H, result_path_string)` admits exact basics or resolves
  the output node. Unknown outputs fail closed.

Material crafting checks admission and rechecks after waiting. The same hook is
used by anvil choices and casts, assembly benches and direct part/ammunition
assembly, tanning and manual woodworking, rope intermediates, cooking insertion,
torch creation, flint sharpening, and mill/sawmill work. Existing explicit node
requirements remain authoritative for armor and factory recipes. Foundry casting
requires both Machined Tools and the selected tool's node. Retrieval remains open.

Automatic processors check the user at input/setup. Already admitted tanning,
large-mill and factory work can finish after the actor leaves; no actor pointer is
made durable. Belt-fed powered sawmills have no actor and retain construction
research rather than inventing a personal owner. This is intentional automation,
not a claim that every autonomous tick has a character identity.

## Era and round-map audit

Existing recipe minimum/maximum eras, material costs and station requirements are
unchanged. Existing output-node mappings are unchanged except confirmed basic
rope. New mappings use the actual output type, recipe category, source minimum era
and production route, not display-name substring matching at runtime.

- Stone-era tool heads and manual wood processing use Basic Tools/Stone Arms.
- Ancient arms use Bronze Arms; medieval and later blades use Steel Blades.
- Flintlock parts/weapons use Gunsmithing. Industrial cartridge weapons use
  Rifling (tier 4), not Cartridge Firearms (tier 5), so their existing tier-4
  anvil window remains usable. RPG-7 uses Missiles (tier 7).
- Trains and the railway office use Rail & Steam (tier 4).
- Early Chemical Cells (tier 1) covers the jar-cell assembly. Galvanic Cells
  (tier 4) covers voltaic piles and lead-acid cells. Electricity (tier 5) would
  have delayed these earlier chemical power sources, so two distinct nodes were
  necessary. These nodes do not change electrochemistry or voltage behavior.
- Manual mills and primitive sawmills use Resource Processing; automated large
  mills and larger sawmills use Watermills. Foundry use retains tier 4.
- Anvil armor uses Main-tree nodes from the same era, so anyone with era access
  can forge it: medieval mail and plate use Steel Blades (era 2), trench-era
  armor uses Cartridge Ammo (era 5) and modern armor uses Automatic Weapons
  (era 7). The specialist armor nodes are not used for anvil recipes, because
  they never unlock for factionless round-map players.
- Fletched bolts now require Crossbows (tier 2); arrows require Archery (tier 0).
  Hand hide processing requires Resource Processing (tier 1), consistent with
  rack construction but stricter than previously ungated scraping.

These are source-level availability checks, not a proof that every round map
supplies all materials, manuals or research infrastructure. Review those exceptions
before enabling personal knowledge or accepting round-map balance changes.

## Verification

The focused offline suite is `python scripts/ci_baseline.py unit --suite research_coverage --output data/research-coverage.json`.
It includes missing-map and unknown-node negative controls, exact basic/exclusion
boundaries, material aliases, route-specific factory requirements and runtime
material admission/recheck wiring. The full pinned compiler, recipe fixture and
all offline preflight suites are reported on the draft PR. Source projections do
not establish connected-client gameplay, natural map reachability or save/load
acceptance. No feature flag, deployment or live world is changed in this phase.
