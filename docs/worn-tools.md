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
