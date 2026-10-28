# Furniture follow-on review - 2026-10-28

Earlier published checkpoint: #3383 at `e5ca39f6471141073a1396c7f5244c7e2a01044a`,
stacked on #3382. Its explicitly requested hosted compile passed with BYOND
516.1688, zero errors/warnings. The workflow remains informational because its
dependency branch is outside ordinary master-target CI admission. No native
crafting or connected-game acceptance is claimed.

The stool checkpoint was isolated on `codex/furniture-next-stool` and is now
part of #3383; shelving was verified separately on `codex/furniture-wooden-shelf`. It adds one
missing wooden-stool route and a checked wooden shelf material route; it does not
expand every row in the inventory.

## What was inventoried versus actually reviewed

The earlier audit indexed 9,640 existing material rows across 11 catalogs and
captured 545 furniture/storage candidates. Those counts include duplicate map
and faction rows. Inclusion in the index is not historical verification or an
interaction audit. The first published expansion reviewed the shared crafting
path and added explicit table/chair/bed joinery and dowel sets.

This follow-on read the concrete stool constructor, icon updates, padding,
dismantling and material-sheet refund; table/rack defaults and break-to-parts;
wooden shelf subtype; bookcase initialization/dismantling; and closet/crate
initialization, opening, locking and dismantling. Source review is not runtime
execution, complete map reachability or review of every clothing/weapon/station
recipe. The inventory matcher now includes item stools/barstools as well as
structures, so future material rows are not omitted merely for being portable.

| Concrete candidate | Existing route/source facts | Decision |
|---|---|---|
| `/obj/item/weapon/stool/wood` | Existing wooden stool, working constructor/art/padding/refund; no active explicit material recipe in the reviewed base | Prepare one pegged wooden-stool recipe |
| `/obj/structure/table/rack/shelf/wooden` | Existing wood description/art, no active explicit material recipe; inherits iron buildstock and metal frame/rods from table | Correct wooden subtype fields and add the six-plank alternative |
| `/obj/structure/table/fancy` | Seven existing wood-only catalog routes costing seven units; inherits metal recovery fields | Keep recipes and gates; correct this subtype to wooden recovery and flammability |
| `/obj/structure/table/rack/coatrack` | Seven existing wood-only catalog routes costing three units; inherits metal recovery fields | Keep recipes and gates; recover the wooden stand without a separate tabletop |
| `/obj/structure/bookcase` | Existing 6-plank recipe, Fine Furniture node; accepts books, and has research behavior and hammer dismantling | Existing route already fits wooden furniture; no extra recipe now |
| `/obj/structure/closet/crate/empty` | Existing 5-plank route, Cooperage node; constructor initializes storage and may collect loose items | No duplicate route now; simple box versus cooperative barrel research needs separate evidence |
| `/obj/structure/closet/crate/chest` | Existing 7-plank route, Cooperage node; inherited closet locking/storage behavior | Do not infer metal hinges/locks are required or absent from the sprite; no invented hardware variant |
| `/obj/structure/closet/cabinet` | Existing 5-plank wardrobe, Fine Furniture node; inherits closet initialization/locking | Existing route fits; no arbitrary cheaper or earlier wardrobe |
| `/obj/structure/closet/coffin` | Existing 4-plank route, Basic Furniture node; separate burial object and shared closet mechanics | Already a plausible simple wooden route; no gratuitous alternative |

Map placements or loot may provide types without recipes. Absence of an explicit
material row establishes a crafting-menu gap, not universal unobtainability.

## Prepared stool route

`joinery: pegged wooden stool` consumes 2 ordinary logs and one paid dowel set,
with a chisel and hammer/mallet equipped or at the actor's feet. Base time is
100 ds under the existing crafting modifiers. It outputs the existing
`/obj/item/weapon/stool/wood` with explicit supplied material `wood`, retaining
Basic Furniture research and maximum era 8. No new art or output type is added.

The two-log input is smaller than the four-log chair while still paying the
same abstract dowel set. Costs/time are conservative gameplay assumptions, not
historical measurements. Successful hammer dismantling uses the stool's existing
`material.place_sheet` and yields one log. Thus the cycle cannot repay its two
logs plus consumed pegs. The existing one-unit padding handler remains the way
to upholster it; no duplicate padded-stool recipe is added. No native padding or
refund execution has yet been claimed.

The existing sprite depicts the game's ordinary wooden stool. This is an
all-wood gameplay form, not a replica of a museum stool with a reed seat.
[Met stool 14.10.3](https://www.metmuseum.org/art/collection/search/544800)
attests wood/reed stools ca. 1991-1450 BCE; it does not establish a solid wooden
seat or every joint in that object. [Met chair 12.182.28](https://www.metmuseum.org/art/collection/search/548636)
explicitly records peg/dowel assembly and forked-branch braces in early New
Kingdom furniture. The reviewed Neolithic well study linked in the first audit
supports earlier complex wood joining, not this precise stool. Combining these
into a basic peg-joined stool is an engineering/gameplay extrapolation, with
the broad Basic Furniture era-0 gate retained for consistency with the first batch.
Do not describe those Bronze Age objects as proof of this exact Stone Age stool.

The British Museum EA46705 search record also describes tenons/dowels and rush
webbing; its page returned 403 on the fresh read, so no date was inferred from
it and it is not needed to establish the candidate's precise chronology.

## Wooden shelf route and model correction

The existing wooden shelf now has a six-finished-plank route, 100 ds, mapped to
Fine Furniture (era 2), and remains available through maximum era 8. This is a
wood material alternative to the existing six-steel shelf, not a duplicate
bookcase or a new storage/research capability. Existing plank preparation routes
supply the wood; no extra station or special tool requirement is invented.

Only the wooden shelf subtype overrides its inherited frame to the existing
wooden frame, both stack fields to finished planks, and flammability to true.
Parent tables/racks and the steel shelf are unchanged. The actual shared
recovery paths now yield: destruction/deconstruction -> three planks; broken
parts -> one plank; disassembly -> one plank plus a wooden frame. Wrenching
that existing frame yields two logs, a lower-processing wood refund, not rods.
Every ordinary recovery route returns at most three wood units against six
paid planks. The special Wizard Boy MDF-board conversion is preserved.
Interrupted disassembly/deconstruction produces no output.

[Herculaneum Archaeological Park's sideboard record](https://ercolano.cultura.gov.it/il-ritorno-della-credenza-di-ercolano-un-viaggio-nel-tempo-tra-legno-e-memoria-dopo-quasi-novantanni-dal-ritrovamento-lo-straordinario-mobile-ligneo-con-il-suo-corredo-di-stoviglie-e-espost/?lang=en)
attests an ancient wooden storage cabinet/sideboard preserved by the 79 CE
eruption, with its domestic vessels. This supports pre-medieval wooden storage
furniture, not the precise open-shelf design, every joint, or an exclusively
wooden bill of materials. The simple open shelf and six-plank cost are explicit
engineering/gameplay abstractions. Keeping the existing Fine Furniture era-2
gate avoids newly backdating the feature from its existing furniture tier.
Existing `shelfwood` art is reused; no museum reconstruction is claimed.

Offline regressions execute the production `table_destroy`, `break_to_parts`
and wooden-frame parent wrench bodies with source-derived defaults. They
exercise all recovery branches, interruptions, old metal-default failure
controls, material budgets, research metadata and real DMI state names.
The isolated DM fixture also includes paid construction and actual lifecycle
assertions; compilation does not mean those native assertions ran.

Further audit still needs anvil, cooking, chemistry, tool/workbench, attackby
and processor inventories plus the non-furniture material categories. The
broader requested audit and recipe expansion remain in progress.

## Existing fancy table and coat rack recovery

The next source review covered these two additional concrete types, for nine
reviewed follow-on candidates in the table above. Each has six faction routes
using ordinary wood and one global finished-plank route. Their existing costs
(seven and three units respectively), research gates, timings and artwork stay
unchanged. Their metal defaults were a construction/recovery mismatch; correcting
it does not establish a new historical furniture design or era claim.

Both now use the existing wooden frame and finished-plank stack fields. The fancy
table also becomes flammable. Destruction/deconstruction returns three planks
from the table and two from the coat rack; broken parts return one plank. Table
disassembly yields a wooden frame and one plank, while the coat rack yields only
the frame because it has no separate tabletop. The frame's existing wrench route
returns two logs. Every path loses wood against the cheapest input. In particular,
the coat rack cannot return three planks' worth of logs/planks and generate free
bark by processing those logs again. Resurfacing a recovered frame spends another
log and produces an ordinary wooden table whose recovery is also lossy against
the full original furniture input. Parent table/frame procedures remain unchanged.

Offline regressions execute those production recovery bodies and the wooden-frame
resurfacing body, cover interruptions, all fourteen catalog rows and both recovery
cycles. Native assertions for destruction, deconstruction, disassembly and frame
wrenching are included in the compile-only fixture; they have not run in a world.
