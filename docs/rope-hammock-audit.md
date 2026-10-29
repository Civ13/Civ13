# Rope hammock and remaining furniture review - 2026-10-28

The existing `/obj/structure/bed/hammock` is explicitly described as a rope bed,
uses the registered rope material and has working static/occupied icon states.
No active material catalog provided it and no research node mapped it. This is
a crafting-menu gap, not proof that maps or administrators could never supply it.

One new global recipe pays six rope units and 180 ds, with one output per turf,
supplied material `rope`, Weaving research and maximum era 8. Rope production
from the separately merged rope-making work is unchanged. Atlas and Player Help
index the material row normally. No special tool or powered station is invented.
Six coils and the wait are gameplay costs, not historical measurements.

Availability follows the existing catalog selector: this row is in `global`
only. Nomads (Africa) players assigned the separate `pygmy` catalog do not
receive it merely by unlocking Weaving. New routes remain global-only under
the current scoped guidance; faction catalogs and their selection are unchanged.

The [Library of Congress 1492 exhibition](https://www.loc.gov/exhibits/1492/america.html)
records Indigenous Caribbean cotton hammocks encountered in 1492 and reproduces
Oviedo's 1535 description of a woven sleeping sling with henequen suspension
twine. That supports a preindustrial woven-and-corded bed. Using the game's
generic rope material (currently made from hemp/flax) for the entire hammock is
an engineering abstraction, not a reconstruction of a cotton Taíno hammock or
evidence of its use in every early culture. The existing era-0 Weaving tier is
a technical/gameplay gate; it does not establish Stone Age hammock chronology.

This is the existing stationary hammock, directly derived from `bed`, without
the bedroll's portable type or folding verb. The ceiling-hanging description
and visual model are reused. Construction retains the game's ordinary clear-turf
placement rule; it does not simulate roof
anchors, rope tension, tree supports or load ratings. No suspension physics,
buckling, occupied animation or padding behavior is changed.

## Recovery and checks

The hammock inherited the ordinary bed's `not_disassemblable = FALSE`. A hammer
falls through the bed handler to the shared structure branch, which creates one
wood log. The hammock subtype now refuses that generic wood conversion, just as
textile bedrolls do. Ordinary beds and shared dispatch are unchanged. This adds
no raw-rope refund or portable hammock system.

Offline regressions execute the actual generic hammer branch and prove the old
inherited default still produces wood as a negative control. They also check paid
recipe/research/Atlas identity. The compiled native fixture uses real six-unit
production, short-stock and occupied-turf refusal, existing unoccupied processing
and a hammer in a legal hand slot. Report actual execution separately from fixture
compilation. Connected play, natural resource reachability, suspended/occupied
animation and real saved-world round trips remain unverified.

The hammock recipe rechecks `one_per_turf` after its action wait, before awarding
XP or consuming rope. Another hammock completing during the wait therefore cannot
create a duplicate on that tile. This preserves the same-output-type predicate and
disabled-flag behavior. The check is explicitly limited to this hammock recipe:
legacy recipes such as the powered sawmill prepay secondary inputs before waiting
and must not gain a new late rejection without a separate payment/refund design.
The offline control proves an occupied powered-sawmill result does not enter the
new rejection path; it is not a claim of atomic crafting for that legacy recipe.
Offline regressions change hammock occupancy across the completion boundary; the
native fixture places a competing hammock during the real wait and checks unchanged
stock and only the competitor's output. No shared reservation or atomic-crafting
rewrite is included.

## Broader audit stopping point

The first furniture PR and cloth-bedroll PR are merged. This source slice adds
one existing hammock type; the compact index now identifies eleven reviewed
follow-on families, separate from initial table/chair/bed/dowel review. It is not
a historical or interaction audit of every indexed recipe.

This pass additionally inspected the following existing routes and handlers. They
are source triage, not accepted native interaction tests or historically dated designs:

| Family | Concrete route/behavior | Decision |
| --- | --- | --- |
| Curtains | Global cloth and leather routes, one unit/80 ds, Weaving; toggle/cut-down handler and generic hammer refusal | Both materials already represented; no extra variant |
| Ceiling cabinet | Four finished planks, Fine Furniture; inherited closet storage/locking; open harm-hammer path removes the object | Existing wooden route; no invented hinge bill |
| Large wooden crate | Eight finished planks, Cooperage; existing wooden model and shared closet storage/deconstruction | Existing route; no duplicate peg recipe |
| Wooden mailbox | Three finished planks, Printing Press; explicit paper/photo/sealed-envelope admission | Existing wood route; research reflects mail use, not woodworking; no arbitrary early gate |
| Drawer cabinet | Only six-plastic route; Fine Furniture; actual handler admits paper, paper bundles and folders, not arbitrary clothing | Candidate for a separate material/chronology review; do not relabel it as a general medieval clothes chest |

Actionable remaining slices, in order:

1. Drawer/file storage: decide whether a wooden document drawer subtype/route is
   justified by its actual art, handler and period evidence. Review all three
   filing-cabinet types together; preserve their paper-only purpose and modern routes.
2. Upholstered seating: inspect red/winged wood chairs, padded/comfy chairs,
   sofas and psychology couches for constructor padding, wood/textile costs,
   recovery and research. The inventory's single-material rows alone cannot tell
   which are missing alternatives; do not add free upholstery.
3. Canopies/tents: both leather and cloth rows already exist, but review the
   shared fold/unfold identity and area/roof interaction before proposing changes.
4. Production/storage stations: review barrels, cutting boards and kitchen
   implements across Cooperage and the bespoke handlers. Material catalogs alone
   omit manual construction and processor/anvil/cooking/chemistry alternatives.

Weapons, clothing, stations, anvil, cooking and chemistry have not been exhaustively
route-reviewed by this task. Their inventory counts are follow-up indexes only.
