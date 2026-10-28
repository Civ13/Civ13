# Furniture follow-on source preparation - 2026-10-28

Published first batch: #3383 at `e5ca39f6471141073a1396c7f5244c7e2a01044a`,
stacked on #3382. Its explicitly requested hosted compile passed with BYOND
516.1688, zero errors/warnings. The workflow remains informational because its
dependency branch is outside ordinary master-target CI admission. No native
crafting or connected-game acceptance is claimed.

This follow-on is isolated on `codex/furniture-next-stool`. It prepares one
missing wooden-stool route; it does not expand every row in the inventory.

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
| `/obj/structure/table/rack/shelf/wooden` | Existing wood description/art, no active explicit material recipe; inherits iron buildstock and metal frame/rods from table | Review model correction before any recipe; do not mint metal from a wood build |
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

## Shelf batch after the stool

Before making the existing wood shelf craftable, set and verify wood frame and
build/refund stock on that subtype, assess flammability and inherited table
interactions, and check the actual `shelfwood` appearance. A proposed 4-6-plank
open shelf with optional pegging must be balanced against the six-plank bookcase
and its research functionality. Do not backdate the current store-shelf art or
reuse the steel shelf's six-metal recipe merely because both are named shelf.
Obtain a primary source for the chosen simple shelf form, then choose its gate.
No shelf gameplay source is changed in this preparation.

Further audit still needs anvil, cooking, chemistry, tool/workbench, attackby
and processor inventories plus the non-furniture material categories. The
broader requested audit and recipe expansion remain in progress.
