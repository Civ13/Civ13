# Portable canopy review - 2026-10-29

Twelve existing material rows across six catalogs already provide the same folded
canopy from four cloth or five leather units, at 75 ds, under the existing Weaving
mapping. Both 35 ds unfold/fold waits are retained. This slice preserves all rows,
research, availability and art rather than adding a third recipe. A folded item
is an existing complete portable assembly; folding returns that item, not raw
cloth/leather or a newly invented pole/peg bill.

## Concrete lifecycle corrections

Unfolding previously searched the held item's `loc`, usually the actor's inventory,
for an existing standing canopy. It did not inspect the destination tile or
recheck after waiting. Competing actions could create duplicate standing objects,
and a user inside a container could create a roof in a non-turf location.
The action now retains its destination and source location, requires a physical
outdoor tile without another canopy or roof, and checks again after the wait.
Nested stock, moved actors/items, incapacitation, active persistence operations
and changed persistence identity refuse completion without consuming the item.
The constructor also refuses roof creation when placed inside a container.

Folding previously deleted every roof on the tile, including independent wood
or clay roofs. It now refuses folding while another roof type occupies the tile,
both before and after waiting. That keeps the separate roof's area transition
outside canopy teardown; players must remove the other roof first. Only canopy
roof objects are removed, and only after the last standing canopy leaves the tile.
This also lets legacy duplicate canopies fold one at a time without stripping
the remaining structure's cover. The old instance is retired before roof
callbacks/output creation, preventing a competing fold from producing a second
item from the same instance.

Neighbor icons update after retirement and reset to their initial state before
recomputing seams. Existing assets and roof constructor/destructor behavior are
reused. There are no new persisted fields, area/roof implementations, seasonal
collapse changes or crafting transaction changes. The active seasonal-construction
lane is separate from this source slice.

## Historical and model limits

The [Vindolanda Trust's tent research](https://www.vindolanda.com/blog/the-romans-camping-and-me)
describes excavated Roman wooden tent pegs, stitched leather panels and evidence
for framed tents. It supports preindustrial leather shelter construction, not
the game's four/five material units, its cloth canopy silhouette or a universal
Stone Age chronology. The associated [research publication record](https://scholarlypublications.universiteitleiden.nl/handle/1887/57787)
identifies the 2017 study of the Vindolanda tent; this audit does not infer details
from an unread full chapter. Existing costs, implicit supports and Weaving era
are gameplay abstractions. The generic folded item does not record which of the
two materials was used, and no raw-material refund is introduced.

## Verification and remaining work

Offline checks execute production admission and completion bodies with inert
wait/actor/constructor adapters. They cover destination occupancy, late roof or
canopy arrival, nested inventory/container actors, cancellation, movement,
persistence state/identity, competing folds and legacy shared cover. The native
fixture uses real paid recipe production, actual canopy/roof/area constructors,
real 35 ds waits, competing actors, independent-roof preservation, shared legacy
cover and neighbor icon-state assertions. Record hosted execution separately from
local compilation; these checks are not connected-client rendering or save-file
round-trip acceptance.

This adds one source-reviewed follow-on family/two concrete models to the audit
index, independently from 557 inventoried furniture candidates. The wider audit
remains partial. The next [production/storage slice](cutting-board-production-audit.md)
reviews the cutting board and triages wooden barrel/kitchen-implement recipes.
Shared roof damage/destruction policy, seasonal
collapse, graphical shelter effects and world restoration are outside this
bounded action correction; their ownership and existing guards are preserved.
