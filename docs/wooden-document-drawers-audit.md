# Document drawer review - 2026-10-28

Follow-on status, 2026-10-29: [upholstered seating](upholstered-seating-audit.md)
has now been source-reviewed, with narrow padding/recovery conservation fixes.
The bounded [canopy action review](canopy-crafting-audit.md) follows it; the next
independent family is production/storage handlers.

This is one additional reviewed family, after the merged joinery, cloth-bedroll
and hammock work. The three existing document-cabinet routes all cost six plastic
units: ordinary/tall filing cabinets use Papermaking and the chest drawer uses
Fine Furniture. Their actual handler accepts papers, paper bundles and folders;
they are not general wardrobes. Existing plastic rows, prototypes and handlers
are preserved. No arbitrary wooden version of each modern filing cabinet is added.

## Added route

`joinery: wooden document drawers` pays six finished planks and one paid dowel set,
with a chisel and hammer/mallet equipped or at the actor's feet, for 180 ds under
normal modifiers. It produces a distinct wooden chest-drawer subtype, retains
the parent drawer's Fine Furniture node (tier 2, bench 1) and maximum era 8.
The route is global-only; separate faction catalogs do not receive it automatically.

The existing dowel unit is a **set**, representing a batch of pegs, not an
individual dowel. Individual pegs within a set have no fixed count. The original
one-set requirement is retained as the gameplay abstraction; no numeric peg
count is invented and no other furniture's cost or set meaning is rebalanced.
Preparing the set separately costs one finished plank, so starting without a
set costs seven finished planks in total: six cabinet planks plus one for the set.

The existing data-driven joinery action validates the retained stock, peg set,
tools, research, occupied turf and persistence identity after waiting, before
either payment or XP. This slice does not extend the hammock's special guard or
change any shared transaction code. Existing plank and peg preparation is reused.
The dowel description now refers to the recipe's wood stock rather than logs only.

The subtype uses the existing `chestdrawer` and `chestdrawer-open` art with a brown
tint, and explicit wooden/document names and description. It inherits document
admission, flammability, wrench anchoring and generic-disassembly refusal. No
capacity, retrieval UI, strength, wardrobe admission, refund or new sprite is added.
The paper handler and all existing cabinet models remain unchanged.

## Historical limits

The Met's [Tuscan walnut credenza, second half of the sixteenth century](https://www.metmuseum.org/art/collection/search/190788)
and [Barberini Cabinet, ca. 1606-23](https://www.metmuseum.org/art/collection/search/207712)
attest preindustrial wooden cabinetry. The latter has an oak/poplar substrate
with elaborate veneers and stone decoration; the game object is not a reproduction
or an assertion that that particular cabinet was built with pegs alone. The Met's
[oak/yellow-pine chest-with-drawers, 1690-1710](https://www.metmuseum.org/art/collection/search/2011)
also establishes a drawer form in wood, not its earliest invention.

A simple peg-joined frame with wooden drawer runners, six planks and the wait are
engineering/gameplay abstractions. The existing Fine Furniture tier is retained
for consistency with the parent, not used as proof of Stone Age or universal
medieval document drawers. Earlier plain chests/cabinets already have wood routes;
this review does not backdate the modern filing-cabinet design or invent metal
hinges/sliders from a sprite. Paper-only use is the existing game's purpose.

## Verification and remaining work

Offline checks execute the production document-admission body with bounded
chat/sleep/inventory adapters, apply the existing joinery guard to the new plank
route, preserve legacy rows, and check real Atlas/Help output, cost, tools and tier.
The native fixture covers paid construction, legal-hand document admission,
cloth rejection, hammer refusal and late occupied/tool/research changes without
stock or XP debit. Report execution separately from compilation. Connected
retrieval UI, natural resource/research reachability, occupied animation and real
saved-world round trips remain unverified.

The broader audit is still partial. This family includes review of all three
legacy outputs and the added subtype; inventory inclusion alone is not review.
Upholstered seating (frame/padding costs and recovery) is now source-reviewed in
[the follow-on audit](upholstered-seating-audit.md), followed by the bounded
[canopy action review](canopy-crafting-audit.md). Next are production/storage stations
(barrels, cutting boards and kitchen handlers). Full anvil, cooking,
chemistry, clothing and weapons route reviews remain outside the completed slices.
