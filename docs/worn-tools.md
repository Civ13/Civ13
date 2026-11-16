# Tools built into wearable gear

Code: `code/modules/1713/worn_tools.dm`. Tests: `tests/worn_tools/`.

## Worn tools at hand

`/mob/living/human/proc/reach_worn_tool(tool_type)` returns the first item of
that type a free hand can reach without unpacking: the other hand, then the
belt slot item, the Hip slot item and the accessories hanging from the uniform,
belt, Hip item, coat and shoes, and whatever those hold (one level deep).
Backpacks and pockets are never searched. Reaching is instant.

Callers: the fire striker (a flint in a worn pouch).

Do not use it for actions that start when an item is clicked onto worn
clothing (gem setting): the clothing hand-off would steal the click.

## Fittings

Shoes and suits (coats) take one accessory in the `fitting` slot. A fitting is
an ordinary storage accessory (`/obj/item/clothing/accessory/storage/sheath/fitting`):

| Fitting | Garment | Holds | Research |
| --- | --- | --- | --- |
| boot sheath | shoes | one small knife | Iron Tools |
| sleeve sheath | coat | one small knife or the bone awl | Iron Tools |

Big knives (sickles, butcher, meat, bread, bowie, hook) are refused. Fittings
draw nothing on the garment or the wearer; examining the garment says what the
sheath holds. Clicking the worn garment with an empty hand draws the knife.

The old hidden `holding` knife on every shoe was removed. A shoe loaded with
one drops it beside itself (`/obj/item/clothing/shoes/after_load`).

Attaching any accessory now redraws the slot the garment is worn in
(`update_clothing_icon()`), not only the uniform.

## Stone Age kits

| Item | Worn as | What it does | Research |
| --- | --- | --- | --- |
| fire pouch | belt, hip or clothes (counts as a belt pouch) | Holds flint, fire drill, striker and small flint tools. A candle, pipe or cigarette held against the worn pouch lights from a flint inside (1 s, 70%) or a fire drill (4 s, sure) | Basic Toolmaking |
| fire drill | in hand or in a fire pouch | Spun in hand for 4 s, an ember for 5 s that lights candles and pipes | Basic Toolmaking |
| needle case | clothes | Holds the bone needle and sinew. The needle mends with sinew from a worn case | Basic Toolmaking |
| neck sheath | clothes | One small knife; click the clothes with an empty hand to draw it | Basic Toolmaking |

Campfires, ovens and torches still light by hand (Val's choice); the kits are
for things that need a flame.

A damaged garment with attachments is mended by a bone needle clicked onto it;
an undamaged one stores the needle in an attached case. A candle or pipe held
against clothes with a fire pouch always goes to the fire pouch.

## Bronze and Iron kits

| Item | Worn as | What it does | Research |
| --- | --- | --- | --- |
| pendant hone | clothes, or on a chatelaine | Use a chipped blade on it, or on the worn clothes, to hone it (25 s, +6 condition, -4 most condition, as on a flint). Not storage, so it never swallows the blade | Bronze Working |
| strike-a-light pouch | belt, hip or clothes (counts as a belt pouch) | A fire pouch with a steel striker: 85% per strike | Iron Tools |
| chatelaine | clothes | Three chains for a small knife, keys, a needle case, a hone or shears; all count as at hand | Iron Tools |

A chipped blade clicked on worn clothes is honed when the wearer reaches a hone,
before any pouch is offered the blade. A needle case on a chatelaine still feeds
the bone needle.
