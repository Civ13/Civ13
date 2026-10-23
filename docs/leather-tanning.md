# Leather tanning

Animals yield untanned skin, rather than finished leather. The existing
`/obj/item/stack/material/leather` type and material remain the finished product,
so existing leather stacks, saves, and recipes retain their identity. Skinning
still yields the existing species pelts for fur clothing and other pelt recipes.

## Processing

1. Butcher a dead eligible animal with a sharp tool on harm intent, or skin it
   on grab intent. Adult male and female turkeys each provide one raw hide piece.
   Turkey chicks provide no hide. Turkeys are not classified as mammals and gain
   no mammalian bones, sinew, fat, or organs from this change.
2. Apply a held sharp tool to a nearby raw hide or pelt. Scraping takes 50 ticks
   and consumes one piece only after successful completion and revalidation.
3. Apply an open held liquid container containing at least 5 units of water to the
   prepared hairless hide. This consumes 5 water and one prepared piece, producing
   one wet hide. Existing saved hairless hides enter at this stage.
4. Put a held wet-hide stack on the existing tanning rack. A batch takes
   300 ticks, normally 30 seconds. Click the rack with an empty hand to retrieve
   its contents; removing wet hides cancels that batch and preserves the pieces.
   Completed dry hides must be retrieved before another batch can be loaded.
5. Apply an open held liquid container containing at least 5 units of tannin to a dry hide.
   One dry hide and 5 tannin produce one ordinary leather sheet.

Cutting logs into planks also yields one bark piece per paid log unit. Existing
hatchet cutting costs two log units for one plank and now also yields two bark;
existing saw cutting costs one log for four planks and also yields one bark.
The tool, log location, remaining stock, and actor are rechecked after the wait.
Use an open held liquid container with 10 units of water on one bark piece to replace that
water with 10 units of tannin. The equal liquid volumes fit even in a full vessel.
All liquid interactions process one hide or bark piece at a time; a splash alone
does not turn a whole stack into leather.

Wood mugs, canteens and glass vessels work through the same open-container API.
You can also hold the bark, prepared hide or dry hide and click a nearby open
liquid container or unlocked barrel on the ground. This reverse interaction
processes one piece and the same liquid costs, without pouring or splashing.
Keep the ingredient in hand and both objects within reach. Sealed containers,
locked barrels, another person's inventory, nested storage and insufficient
liquid are rejected. The vessel must have an actual accessible reagent holder;
terrain water and a cooking pot's separate cooking-water counter are not reagent
vessels. Use an ordinary reagent vessel for tanning instead.

These processing actions add no map, era, faction, or research restrictions.
Rack construction continues to use the existing wood recipe (8 logs in the global
catalog) and its Resource Processing research requirement where research applies.
Water and appropriate vessels retain their existing acquisition routes; the
change does not add free supplies or bypass a map's crafting gates.

The [Crafting Atlas](crafting-atlas.md#leather-processing) includes all stages,
paid quantities, bark/tannin acquisition and existing leather/fur uses. The rack's
**Processing Reference** opens its drying route and links to rack construction.

## Accounting and saves

Each stack unit is one eventual leather sheet. New mammalian raw-hide output is
bounded to `min(6, max(1, butcher_yield() - 2))`; turkey output is explicitly one.
Species pelt quantities are unchanged. A pelt can still be used as fur, or its
owner may sacrifice one pelt piece to make one prepared hide. The old rack's
one-hide-to-three-leather multiplication is intentionally removed.

Raw, prepared, wet, and dry stages have separate material/stack identities.
Splitting and merging thus preserve yield using the existing amount field;
there is no per-object yield field that could be lost when a stack splits.
Conversions call `use(n)` without a human argument, avoiding crafting discounts,
and pass final counts into constructors before any automatic merging occurs.
Preparation no longer falls through into a second output when a destination
stack already exists.

The rack stores actual wet/dry stack objects in its saved contents. Its runtime
epoch and derived busy flag are excluded from both save export and legacy import.
Restored wet batches start a fresh full drying interval. Cancellation invalidates
old callbacks, and rack destruction releases its contents. Saved hairless hides
and finished leather keep their existing type paths; old converter timers that
already consumed input without retaining it cannot reconstruct that missing input.
Preparation/log-cutting locks are also runtime-only, including legacy imports.

## Provenance and verification

The stage sequence is based on
[Pocket Stronghold 13 at `2bfb1906a9a68f58c5e5da25383f83dd495bf138`](https://github.com/Valgorithms/Pocket-Stronghold-13/tree/2bfb1906a9a68f58c5e5da25383f83dd495bf138):
log cutting in `dwarfs/code/modules/carpentry/log.dm`, water exposure in
`code/modules/reagents/chemistry/reagents/food_reagents.dm`, and
`dwarfs/code/modules/leatherworking/{tanning_rack,reagents}.dm`.
Behavior is implemented with Civ13's own stack, inventory, reagent, crafting,
and persistence APIs rather than copying the upstream subsystem. The only
imported art is the single bark state, whose source, contributor, and CC BY-SA
3.0 license are retained in [its adjacent notice](../icons/obj/bark.dmi.LICENSE.md)
and embedded PNG metadata. The other icons reuse existing Civ13 states.
All artwork is reused human-created game art; no AI-generated visuals were used.

Offline source contracts:

```powershell
& '<verified-python-executable>' -B -m unittest discover -s tests/animal_harvest -p test_tanning_sources.py -v
```

The source checks evaluate production type/admission predicates, charge/output
counts, cancellation guards, stage identities, and unchanged harvesting claims,
meat, anatomy, and pelt outputs. Historical double-output/lead-input cases and
mutated threefold yields are controls. They do not execute DM or prove native
scheduling, client interactions, or save reconstruction.
The sprite preview check requires Pillow. It counts unnamed animated DMI states
as well as named states so every displayed cell matches its actual state offset.

`tests/animal_harvest/tanning_probe.dm` extends the existing isolated harvest
fixture with production conversion/cancellation/stack/rack/turkey/save cases.
BYOND compilation, fixture execution, production save round trips, and graphical
gameplay acceptance are explicitly **not run** during the parent's preparation
review. This is a preparation gate, not an evidenced indefinite external hold.
The preparation commits used `[skip ci]` to respect the initial no-compilation
instruction. A later user approval permits a normal non-skipped commit for the
existing free public GitHub-hosted build and selected tanning/Atlas fixtures.
Local BYOND remains unrun. No live Gaia process, settings, saves, or canonical
checkout files are changed.

The [native validation proposal](leather-tanning-native-validation.md) describes
the four-launch Windows driver, source-only containment changes, port limitations,
retained evidence, and the existing hosted CI alternative. No new approval-file
protocol is required.

Atlas checks run without BYOND:

```powershell
& '<verified-python-executable>' -B -m unittest discover -s tests -p '*atlas*.py' -v
node tests/crafting_atlas/navigation.test.mjs
node tests/crafting_atlas/tanning.test.mjs
```

The catalog checks verify prices and source drift, mandatory intermediate stages,
turkey eligibility, fur/finished-leather continuity, resource acquisition links and
the rack construction research tier. The DOM checks exercise production website
navigation; they do not prove image exports, browser appearance or native clients.
