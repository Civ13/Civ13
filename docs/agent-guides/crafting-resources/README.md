# Crafting resources: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-28: gathered manual woodworking -->
Manual woodworking in primitive_woodworking.dm keeps pieces and crude planks
distinct from finished planks. Whittling admits sharpened flint or an actual knife
whose working material is harder than the wood; flattening admits sharpened flint
or sharp verified non-wood working material and charges no tool wear. Wooden
handles on metal blades do not make those blades wooden. Hammer/wedge splitting
is axe-free; the existing plank-to-handle recipes remain unchanged. Ownership is
runtime-only; waits snapshot the shared persistence admission identity and become
invalid when a save/load is admitted, even if it finishes before the wait returns.
The offline source projections and hosted wiring do not establish native gameplay
or savefile acceptance. Keep the sawmill owner's one-finished-plank-per-log contract
separate; no spawn kit, map cache, peg joinery or respawn resource grant is added.
Woodworking Atlas provenance uses `scripts/atlas/woodworking-contract.json` and
the normalized source hash, not Git history. Refresh that reviewed contract when
production source changes; depth-one CI must regenerate the same catalog.

<!-- 2026-10-19: consumed crafting handles -->
Consumed wood handles are selected from hands and real equipment slots, including
shoulder/back, then retained through do_after. Revalidate the exact item and source
before debit; consume only after successful stack.use and clear its actual slot.
Do not recurse through storage or recreate handles on cancellation. Existing
get_equipped_items omits shoulder; use the slot getter with equipment priority.
<!-- 2026-10-21: digging tool and research admission -->
Trench digging uses Field Defenses, matching the trench shovel unlock; ordinary
non-harm dirt collection remains ungated. Rock mining accepts pickaxes only at
both click dispatch and shared action admission. The utensil base includes wood
knives; retain spoons for loose dirt/sand/snow collection, not rock mining.
`tests/test_digging_tools.py` checks source-derived gates offline; it does not
establish connected-client collision or native gameplay acceptance.

<!-- 2026-10-19: collision mining ownership -->
Dense mineable underground rock uses one shared click/bump mining action. Its
explicit optional do_after context owns actor and turf reservations before any
spawn; never queue mining from deferred living.Bump work or switch the player's
active hand. The custom saver must exclude both reservation pointers.

<!-- 2026-10-11: crafting validation -->
## Crafting checks

<!-- 2026-10-15: Modern processor recipe validation -->
The recipe catalog fixture defaults to era 0. New era-gated machine families
must select their real supported era in tests/crafting/checks.dm; the reactor
fuel processor is Modern despite not inheriting civ_generator. Keep separate
locked-era/node tests so a fixture-era fix cannot bypass production gating.

<!-- 2026-10-11: staged component workbench -->
`scripts/check-component-tools.py` now checks staged bench cancellation,
concurrent assembly, ingredient removal, destruction and nested native saves.
Its consumption/runtime-save negative controls mutate generated source only.
Workbench waits retain their busy lock until returning; runtime actor/wait state
must never be serialized. Bench contents are actual paid items, not stock counters.

tests/crafting/README.md documents scripts/check-recipes.py, a compiled
BYOND recipe-schema/registration and isolated crafting-fixture check. Use the
current research-tree and map-mode gates when testing material registration;
zero legacy thresholds alone do not unlock node-gated or mode-only recipes.
<!-- 2026-10-13: dehydrator native save baseline -->
`tests/food_progression/rack_save.dm` exports the owning turf and rack graph.
The 769ae4911 baseline compiled cleanly but failed exporting runtime `slots`.
Load_Entry replaces constructor contents even for an empty saved record; rack
runtime pointers must be excluded and live internal storage rebound or rebuilt.
Source-only preparation does not establish native candidate or control acceptance.

<!-- 2026-10-17: yeast bread -->
Dough bakes into a sliceable loaf only after yeast (5 `enzyme` units) is kneaded
in and its 5-minute rise deadline passes; otherwise ovens produce flatbread.
`rise_ready_at` is runtime-only and restarted by `after_load()`; `check_risen()`
is lazy so a lost wait cannot strand dough. Oven `process()` ejects products onto
its turf, so fixtures must inspect the turf, not oven contents. `map_storage.Load_Entry`
does not call `after_load()`; isolated fixtures must call it like the world loader.
`tests/yeast_bread/run.py` covers this with five generated-source controls.

<!-- 2026-10-11: automatic crafting atlas -->
`scripts/build-crafting-atlas.py --catalog-only --game-catalog UI/crafting-atlas.json`
refreshes the shared Notes-style game reference before direct local compilation.
Production build scripts do this automatically. The existing api-pages workflow
also emits `crafting/` with isolated BYOND 516.1681 inherited sprite exports.
Missing/transparent defaults use a labeled actual paper DMI source symbol;
constructor graphics and material recoloring remain dynamic. See
docs/crafting-atlas.md; acquisition annotations retain their historical audit SHA.

<!-- 2026-10-15: atlas unlock and processing contracts -->
<!-- 2026-10-23: atlas catalog variants -->
<!-- 2026-10-27: direct atlas resource search -->
Atlas search has separate bounded Resource and Recipe results. Resource matching
uses catalog names and canonical IDs, with case/whitespace/underscore normalization;
IDs and labels stay unchanged. Recipe filters do not hide resource matches; direct
resource navigation reuses atlas_resource/resource(id) and clears recipe filters.
Empty input browses recipes. tests/crafting_atlas/resource-search.test.mjs checks
the production template offline; resource_search.dm is a hosted renderer fixture,
not connected-client or live-server acceptance. Do not add guessed reagent aliases.

`scripts/atlas/variants.py` groups only identical explicit 13-field material rows
with equal extracted semantics. Catalog identity/source IDs stay as variants;
never group by name, canonical ingredients or outputs alone. Counts and legacy
pages use groups; search/system filters must match the same variant and selected
details must use its source. `tests/crafting_atlas/variants.dm` executes selected
source, old-ID, filter and legacy page contracts through the existing bounded
Atlas runner. Verify exact-head hosted renderer/assets results before acceptance.

`scripts/atlas/catalog_metadata.py` keeps unlock research tiers/minimum gates
separate from catalog field 12's maximum allowed era. Parse research constructors
with balanced arguments; the enclosing registration call adds another closing
parenthesis. Processor tiers describe station construction, not use restrictions.
`tests/crafting_atlas/run.py --compile-only` never starts DreamDaemon; runtime
navigation and omission controls require the normal isolated runner or CI.

<!-- 2026-10-11: bounded animal harvesting -->
- `code/modules/1713/animal_harvest.dm` centralizes corpse claims and bounded species products. The custom saver enumerates `tmp` fields, so in-progress harvesting/axe locks explicitly opt out via `persistence_runtime_var`.
- `tests/animal_harvest/run.py --byond-bin <516.1681-bin>` executes production yields, cancellation/concurrency, binding conservation and object save/load in temporary offline storage. `preview.py` renders existing DMI states for PR sprite review; it is not a gameplay capture or full-server memory test.

<!-- 2026-10-23: leather tanning accounting -->
Leather processing in `stacks/sheets/leather.dm` uses one eventual leather sheet
per stack unit, with distinct raw/prepared/wet/dry material identities. Never add
unpropagated per-object yield fields: splitting and merging must conserve yield.
Tanning uses explicit paid vessel interactions, since reagent touch callbacks can
see the whole holder volume. The rack preserves actual contents and excludes its
runtime epoch/busy flag from saves. `tests/animal_harvest/test_tanning_sources.py`
is offline evidence; `tanning_probe.dm` requires separate native acceptance.

Rack insertion must transfer held inventory directly with `transfer_held_item_to`,
not stage stacks through a turf. Human `drop_from_inventory` definitions must
forward the parent's result with `return ..()`; keep both organ guards and the
implicit arguments. The parent can still report TRUE after refused/redirected
movement, so destination-sensitive callers must check actual location too.
The #3286 discarded-return control now uses an explicit legacy wrapper adapter
alongside a production-human success assertion. Offline checks and the remaining
native acceptance proposal are in `tests/flax_processing/test_drop_return.py`
and `tests/flax_processing/drop-return-acceptance.md`.
The selected Linux flax runner follows the current manifest and verifies archive
members before each launch; old/mismatched banners fail offline runner contracts.
Its historical 1681 CI rejection is preserved. Existing tanning-fixture edits do
not select the harvest suite; its frozen version gate needs separate admission.
Use the production human subtype in transfer tests, not just a `/mob/living` stub.
Production `stack/Crossed` merges floor pieces
into the arriving stack; clear hand/HUD ownership only after destination admission,
check actual location, and restore the hand on rejection/redirect. Keep nodrop and
persistence movement checks. [Rack transfer regressions](../../../tests/animal_harvest/rack_transfer_probe.dm) cover
human inventory, floor-merge controls, bags, and explicit movement-failure adapters;
those adapters do not establish the exact trigger of an unobserved live failure.
Raw, prepared, wet and dry hides are `processing_only` materials: softness is not
a crafting permission. Clear cached recipes before that guard and mirror it in
Atlas export. [Hide recipe regressions](../../../tests/animal_harvest/hide_recipe_probe.dm) use the actual global catalog plus explicit
research admission; it rejects intermediate utensils while retaining leather/pelt
recipes. [Atlas contracts](../../../tests/test_tanning_atlas.py) check the exported processing-only boundary.

<!-- 2026-10-11: finite fracking verification -->
- `tests/hydraulic_fracturing/probe.dm` checks finite terrain conversion, batch
  costs, replacement cancellation and native contained-input disk saves through
  the resource-extraction launcher. Same-type `ChangeTurf()` can return the
  existing turf; use actual native replacement when testing replacement identity.
<!-- 2026-10-11: bounded mining yield comparison -->
- The resource extraction launcher's `tests/mining_yields/probe.dm` option adapts
  only RNG calls in the production mining body. It checks branch/era endpoints
  and finite conversion; fossils yield one (two in special caves), so do not
  claim every destructive resource exceeds two-unit renewable mineral batches.

<!-- 2026-10-11: petroleum save lifecycle -->
- Oil wells preserve barrels in native saved contents and rebuild runtime links after load. Constructors must not claim floor barrels: empty contents restoration can delete those links, while moving a contained barrel to its turf during save can omit it from the turf iteration. `tests/petroleum_lifecycle/probe.dm` checks disk-backed entry/turf round trips and bounded callbacks through the resource extraction launcher.
<!-- 2026-10-11: irrigation propagation -->
Irrigation propagates through cardinally connected channels with temporary local
lists. Ordinary floors and filled-in channels are not water sources; salt reaches
already-wet channels. Source removal does not drain existing channel water.
`tests/irrigation/run.ps1 -ByondBin <516.1681-bin>` checks production procedures,
including the pre-fix baseline; it does not prove map or construction acceptance.

<!-- 2026-10-11: component work tools -->
`scripts/check-component-tools.py` compiles production head/handle assembly and
material stats with isolated startup, then checks rejection, bounded properties,
wear/provenance and current-format native entry save/load. Use BYOND 516.1681.
The legacy `QDELETED` macro reads `gc_destroyed`, while legacy qdel uses
`gcDestroyed`/null locations; ingredient accessibility must also be validated.

<!-- 2026-10-11: chemistry verification -->
Chemical recipe IDs do not register reagents: each product needs a matching
`/datum/reagent` ID or mixing can consume inputs without producing the result.
`tests/chemistry/run.py` compiles production sources with normal world startup
disabled and runs bounded reactions in temporary storage. CI also runs its
wrong-feedstock negative control; this does not replace gameplay verification.
Linux DreamDaemon safe mode rejects an absolute `-log` path. Use a relative
log filename with the runtime working directory set to temporary storage.

<!-- 2026-10-11: chemistry recipe acceptance -->
<!-- 2026-10-17: chemical registration -->
`initialize_chemical_reagents()` keys reagents by `id` and skips nameless types:
a subtype without its own `id` silently replaces its parent (cafe latte once
made `"coffee"` resolve to Cafe Latte). Give every concrete reagent an `id` and
abstract parents `name = null`. A proc on a misspelled path creates a phantom
registered type. Never redeclare `/datum/chemical_reaction/` with defaults: its
`required_reagents` were inherited by `kevlar` and `wizard_boy_recipe`. Reactions
only queue in `handle_reactions()`; fixtures call `process_reactions()`.
`tests/chemical_registration/run.py` audits all of this natively.

`tests/chemistry/run.py --probe biochemistry` checks production acquisition,
construction, controlled reactions, heated polymers, gelatin separation and
engine fuel in temporary storage. See docs/chemistry-recipes.md for game yields,
finite supplies and labels. Its isolated error handler and explicit completion
flags are necessary: normal game error infrastructure is unavailable when
global/controller startup is disabled. Parenthesize each `in` expression when
combining membership checks with `&&` in DM.
<!-- 2026-10-11: gasoline precursor regression -->
`tests/chemistry/run.py --probe fuel` verifies precursor registration and real
beaker gasoline mixing; its negative control removes octane registration in a
generated copy. Fuel ratios and engine behavior are separate contracts.

<!-- 2026-10-11: wire power verification -->
`tests/power/README.md` documents isolated cable accounting regressions and an
opt-in full-game capture adapter. `scripts/test-power.ps1` requires an explicit
BYOND bin path; CI also compiles the excluded gameplay adapter. Powerflow and
currentflow are instantaneous capacity and reserved demand, not stored energy.

<!-- 2026-10-11: medicine regression isolation -->
`tests/survival/run.py` checks production disease courses, oral metabolism,
ingredient acquisition and timed fermentation/distillation in temporary storage.
Its fixture materializes the global-controller `vars` name list before union:
BYOND 516.1681 otherwise logs Bad ref during initialization on the historical
baseline too. Runtime errors/engine diagnostics invalidate evidence. Direct
`del()` of live test atoms triggers the production GC error; use `qdel()`.

<!-- 2026-10-11: trace resource extraction -->
`tests/resource_extraction/run.ps1` compiles production extraction types with
normal startup disabled and temporary storage. It checks bounded output, drill
power/callback lifecycle, construction costs, gathering guards and shortened
production action waits and serialized drill entries. It does not establish
graphical menus or full-world save round trips. Custom saves require explicit
exclusion of transient extraction locks. The fixture closes its port at startup and rejects reopening;
`-close` alone does not prevent a Windows DreamDaemon listening port.

<!-- 2026-10-11: food fertility save regression -->
- Turfs use a persistence allowlist rather than all changed vars. Dirt adds `soil_nutrition` through its parent-calling `get_saved_vars()` override; do not serialize its live soil recovery token.
- `tests/food_progression/run.py --soil-negative-control` proves omission is detected. The full-game world-save probe checks crop/soil and nested seed stock; its frozen crop does not establish post-load growth or season transitions.

<!-- 2026-10-11: trench save progress -->
- Trench types reconstruct depth/flooring and neighbor edges, but construction
  progress requires explicit turf save fields: trench_filling and dirt/sand
  trench_stage. Do not persist cooldowns, overlays or recovery registries.
- tests/trench_save/run.py runs production whole-world disk round trips with
  isolated startup and independent filling/digging omission controls.

<!-- 2026-10-12: era-dependent research prototypes -->
Established factions retain their founding research baseline when another faction
advances the world era. Prototype recipes must remain obtainable afterward:
Digital Computing needs the cold-war camera subtype, not its modern camera parent.
The compiled crafting fixture checks two-faction era advancement and the paid
recipe; --camera-prototype-negative-control restores its obsolete era cap in
isolated runtime data and must detect exactly the lost recipe.

<!-- 2026-10-12: finite digging completion -->
Loose snow/dirt/sand stock must be checked after the action wait, because another actor may consume the last unit. Underground pickaxe actions use one wait/completion path. `tests/resource_extraction/digging_probe.dm` runs production handlers with competing completion and cancellation adapters; `-DiggingBaseline` rejects immutable pre-fix source without changing the checkout.

<!-- 2026-10-15: paid wood residue and plant nitrary -->
Wood-fuel residue uses a saved scalar ledger shared by existing ovens, furnaces
and factories; unknown legacy fuel earns no ash. The existing compost bin's
optional nitrary mode stores paid feedstock and remaining active-server time,
excluding its runtime clock. Feedstock uses stack.use without a human argument:
Production religion otherwise discounts consumption and breaks conservation.
See docs/wood-ash-compost.md and tests/wood_ash_compost/run.py for isolated
production-path/native-save checks and generated-source mutation controls.
