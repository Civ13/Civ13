# Portable barrel ingredient audit - 2026-10-29

This follows the merged [cutting-board slice](cutting-board-production-audit.md).
The existing wood barrel already costs five finished planks, 75 ds, Cooperage,
maximum era 8 in the global catalog. Faction rows retain their existing wood
inputs. No additional recipe, research gate, sprite or historical design is
justified here. The portable barrel's specialized solid/manure handler is the
implemented scope; shared glass fruit/food conversions and large dispensers
need separate review. Inventory is not implementation or historical verification.

## Source findings and implemented behavior

The old handler admitted any recognized ingredient when `total_volume + 3`
was strictly below the type's volume. This excluded an exact final three-unit
ore dose, ignored the real holder's capacity and the lid, and directly changed
stack amounts rather than checking a valid whole unit. For manure it requested
up to ten units, then deleted the entire item even if a closed barrel moved
nothing or a nearly full one took only part. For example, 3.5 free units could
take 3.5 from a ten-unit item and destroy the remaining 6.5.

| Existing conversion | Preserved payment/output | Corrected admission |
| --- | --- | --- |
| Sulphur | 1 stack unit -> 3 sulfur | Whole valid stock, open barrel, real free capacity >= 3 |
| Saltpeter | 1 stack unit -> 3 potassium | Same; no recipe chemistry rebalance |
| Coal/charcoal | 1 stack unit -> 3 carbon | Same; ordinary subtypes remain accepted |
| Poo/manure/compost item | Its complete existing reagent payload, up to 10 units | Open barrel; entire payload must fit without holder loss |

Ore uses `stack.use(1)` and grants nothing if payment fails. Last-unit removal
uses the stack/item lifecycle, clearing the actual hand. Manure is deleted only
after its contents are gone. Empty, oversized or child-containing items are
refused intact. Depleted eligible items retain their smaller actual payload;
there is no default ten-unit grant. Actor/held-item, reach, removability and
persistence-admission checks precede mutation. The actor must stand on a turf;
the barrel must be carried or loose within one tile, not nested storage.
Unrelated items still dispatch to the parent once, including full/closed cases.

Checking only total volume is insufficient for mixed payloads: at a near-full
250-unit holder, rounding can clamp a final 0.01 cyanide addition below the
existing chemistry minimum. A temporary holder previews IDs/volumes in actual
addition order, with reactions and atom callbacks disabled and no live data
copied. If clamping/pruning changes any expected reagent volume, the operation
is refused before transfer. A mixture of 9.99 poo plus 0.01 cyanide can transfer
with sufficient headroom; the unsafe exact-room case stays intact in hand.
The real transfer keeps the existing touch/reaction API and reagent data.
Shared chemistry, fertilizer-grade abstraction and large-dispenser logic are
unchanged; this is not a general reaction-product conservation redesign.

## Verification and remaining scope

Offline projections execute the production classifier, actor admission, preview
and handler with inert inventory/holders. Frozen routes check all four original
ore mappings. Cases cover exact capacity, final/multiple/preset stock, failed
payment, wrong location, bound/disabled actors, persistence state, closed/full
barrels, depleted/manipulated/trace manure, zero transfers and parent dispatch.
Existing barrel recipe rows remain checked against the versioned fixture.

The separate food-runner `--probe barrels` compiles the whole game without maps
or normal startup, supplies legal hands and uses actual stacks, barrels and
reagent APIs. It checks actor/capacity/stock/lid cases, ordinary/animal/fertilizer
manure, partial-room and trace-boundary refusals, zero transfer and a real barrel
entry save/load of paid results. Compile-only starts no world. Record hosted
execution separately; connected-client rendering, natural bootstrap access and
full-world save/import remain unverified.

The prior index had 557 furniture candidates and 15 follow-on families/29 models
with bounded source reviews, plus recipe triage of three models. This adds
implementation for one specialized portable-barrel path, not a claim that every
inherited glass action is reviewed. Shared fruit/food extraction can still
discard partial doses and needs its own coherent batch. Large-dispenser key
assignment ordering was spotted during triage but is not changed by this
ingredient fix. Cooking/trays, anvils/workbenches, chemistry and other material
categories remain actionable audit families.
