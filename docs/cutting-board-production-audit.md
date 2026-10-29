# Wooden food-production/storage audit - 2026-10-29

This slice follows the merged [canopy correction](canopy-crafting-audit.md).
It reviews the cutting board's intake, preparation, scraping, parent dispatch and
saved input; it triages the two wooden barrel models and rolling pin for recipe
gaps. It does not audit every barrel reagent interaction or dough recipe.

| Concrete output | Existing global route | Research | Decision |
| --- | --- | --- | --- |
| Cutting board | 5 finished planks, 50 ds | Cooperage | Preserve route; correct paid food processing |
| Portable wood barrel | 5 finished planks, 75 ds | Cooperage | Existing wood route fits; no duplicate |
| Large barrel | 16 finished planks, 100 ds | Cooperage | Existing wood route fits; no duplicate |
| Rolling pin | 1 finished plank, 50 ds | Basic Tools | Already wooden; no extra route |

All four global rows retain maximum era 8. Faction rows include ordinary wood
and differing costs (the voyage cutting board costs seven). All 34 existing
rows for these exact outputs are frozen in `legacy-production-storage.json` and
checked without Git history. No gate, recipe, art, material refund or period
claim changes. Portable barrel capacity is 250 units; the large base barrel has
1000-unit capacity and is empty, unlike its supplied beer/ale/water subtypes.
These capacity/default checks do not establish all mixing/transfer behavior.

## Confirmed cutting-board defects and correction

The old empty-slot intake checked `input` rather than the offered item for
fillets/cutlets, so those intended conversions were refused. Other admitted food
was deleted while its object reference remained in the board. GC could then
destroy that reference. Knife preparation and scraping also committed after
waiting without checking that the same paid input remained. Two preparers could
produce from one input, and scraping could erase a replacement. An unrelated
tool could reach the parent twice, including the wrench anchoring handler.

The board now owns the actual food as a live child, removed from the actor's
hand. Its ordinary decay process keeps running, charging exposed-board time at
the same rate as loose food. Contents and the input reference use the existing
custom save codec. A deleted reference or an earlier type-only marker cannot
reconstruct food state and cannot produce output. Scraping can clear old markers.

Every timed completion checks the actor, tile, held knife where applicable,
persistence identity and the exact live food, location and freshness. The slot
is cleared and its food detached before output
constructors run. Scraping still intentionally discards the input, while refusing
to clear a changed slot or icon. Unrelated tools dispatch to the parent once.
The board lives in its own DM file; other production stations stay unchanged.

| Paid food | Output | Original base delay |
| --- | --- | --- |
| Fillet or raw cutlet | 1 mince | 180 ds |
| Meat slab or raw fish | 2 mince | 180 ds |
| Mince | 1 meatball | 10 ds |
| Meatball | 1 patty | Immediate |
| Dried meat | 1 minced dried meat | 180 ds |

The seven exact input types retain these item quantities and delays. Unknown
subtypes are refused intact, including poisonous frog meat and already-minced
dried meat; the latter cannot be repeatedly refreshed. Rotten, expired,
disabled-decay, over-capacity or child-containing food is likewise refused.
Freshness is checked again after preparation. Each output's constructor reagents
are cleared, then the original reagents/data are divided among outputs without
creating nutrition or removing added poison. Salt state and relative age transfer
to the output's decay limit, with raw/cooked and unpleasant-food flags retained.
This intentionally replaces the old state-resetting conversion behavior.
Scraping is deliberately lossy.
Existing material knives, including the wooden kitchen knife, remain usable.
No new wear, tool, research or era restriction is introduced. Existing icons
and food constructors are reused; no new sprite or historical reconstruction.

## Verification boundary and remaining audit

Offline tests execute the production bodies with inert actor/wait/constructor
adapters. Frozen expectations check all seven admitted types, quantities, delays,
icons, occupied/unsupported/nonremovable inputs, concurrent/reentrant work,
scraping, movement, lost tools, save-state changes and parent dispatch. These
projections are not DM execution or a savefile. The separate bounded food probe
compiles all game sources, uses legal hands, real knives/food/handlers and waits,
checks live food ownership, races two preparers, changes state during waits,
refuses poisonous/repeated-mincing subtypes, checks actual aging/rot and carries
salt, age and poison through a real board-plus-food-child save round trip.
The fixture shortens preparation and food-decay callback waits to two ticks while
retaining production age charges; production preparation delays are independently
checked against frozen data. This accelerated cadence proves state flow, not
full-game wall-clock timing. Record hosted execution separately from
local compile-only results. Connected gameplay, rendering and full-world saves
remain separate evidence; this fixture does not prove all-map bootstrap access.

This adds one fully source-reviewed family/one concrete board model to the prior
14 follow-on families/28 models, plus recipe triage of three additional models.
The 557 indexed furniture candidates remain an inventory, not reviewed routes.
Barrel mixing/transfer handlers, cooking/tray processors, anvils/workbenches,
chemistry and the other material categories remain actionable follow-ons.
No additional route was justified by this four-output slice.
