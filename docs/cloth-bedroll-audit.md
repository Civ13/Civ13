# Portable bedding review - 2026-10-28

This is one further reviewed furniture family, following the nine concrete
follow-on candidates in `furniture-next-batch-review.md`. It is not a completed
audit of the 9,647 material rows now indexed across 11 catalogs. The inventory
matcher now includes item bedrolls even when a map labels them `none`: 555
furniture/storage/bedding candidates include 12 bedroll rows, eleven legacy
leather rows and the single new global cloth row.

## Real gap and bounded change

Every existing explicit bedroll route used four leather units and a 100 ds base
wait. Both rolled and open models explicitly described leather and fur. Weaving
already unlocks the original bedroll; no cloth alternative was offered. A cloth
recipe producing that unchanged leather/fur model would misdescribe the material.

The new global `cloth bedroll` route consumes four cloth units, 100 ds, with the
same Weaving node (era 0, including existing Main-tree baseline grants), maximum
era 8 and ordinary recipe modifiers. All eleven legacy rows are frozen in
`tests/furniture_joinery/legacy-bedrolls.json` and remain unchanged. No new sewing
station, special tool, filler, synthetic insulation or free resource is invented.
The cloth stack and existing Weaving chain abstract the prepared textile work.

Cloth is a new subtype of the existing bedroll. Static rolled/unrolled typepaths
keep each variant's identity over repeated folding, and backpack handlers retain
the same object through their existing subtype-aware checks. The original leather
pair remains the default. The fold verb keeps its existing use guard and delegates
to the same procedure exercised by tests. Reused `bedroll_r`, `bedroll_o` and
`bedroll_w` states are generic game art; names, descriptions and rustling text
identify cloth. No new sprites, comfort, warmth or strength values are added.

## Recovery finding

Unrolled bedrolls inherited `not_disassemblable = FALSE` from beds. Their hammer
dispatch reached the generic structure handler, which returns a wood log and
deletes the object. That converts textile bedding, including a leather bedroll
from existing starting equipment, into wood. No material-aware bed refund is
called on this path. The existing bedroll class now disables that generic hammer
conversion, covering both variants. Folding remains the recovery route; it
produces one bedroll of the same type and no raw material. Shared beds, structures,
starting equipment and spawn quantities are unchanged.

## Historical basis and limits

[The Met's linen sheet 36.3.131](https://www.metmuseum.org/art/collection/search/549005)
is dated ca. 1491-1473 BCE and measures 520 by 154 cm. It attests large linen cloth
long before medieval times, not an excavated camping roll or the game's quantities.
[Homer, Iliad 24.643-648, A. T. Murray translation, Perseus/Tufts](https://github.com/PerseusDL/canonical-greekLit/blob/master/data/tlg0012/tlg001/tlg0012.tlg001.perseus-eng3.xml#L5671-L5674)
describes beds prepared with blankets, coverlets and fleecy cloaks. This is ancient
literary evidence of textile bedding, not archaeological proof of a standardized
portable bedroll or evidence that every early culture used the same materials.

Rolling a bundle of woven bedding for transport is the engineering/gameplay
extrapolation. Reusing the existing Weaving tier is a consistency choice, not a
claim that this particular item existed throughout every culture in era 0. No
equivalence in real-world weather protection between cloth and hide is claimed.
Hammocks and rope furniture were excluded from this slice because the rope-making
work has a separate owner and needs its own material and chronology review.

## Verification scope

The offline suite executes the actual fold/unroll and generic hammer bodies
through bounded constructors/chat/wait adapters. It checks both material identities,
used-state refusal, the old wood-output negative control, unchanged legacy rows,
new recipe cost/research, real DMI states and Atlas/Help naming. The native crafting
fixture adds paid four-unit construction, three real fold/unfold cycles, hammer
refusal and actual backpack admission/insertion/removal for both variants.

Compilation alone is not native execution. Report the exact native CI outcome
separately. Connected gameplay, natural resource reachability, and real saved-world
round trips remain separate and unverified unless a dated report establishes them.
