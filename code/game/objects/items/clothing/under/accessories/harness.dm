// Leather harness: shoulder straps with loops for hand tools and short weapons.
// Adapted from PolarisSS13's "decorated harness" (/obj/item/clothing/accessory/storage/knifeharness,
// https://github.com/PolarisSS13/Polaris, code/modules/clothing/under/accessories/storage.dm), AGPL-3.0.
// Its sprites ("unathiharness0" in icons/obj/clothing/ties.dmi and icons/mob/ties.dmi, CC BY-SA 3.0)
// were recoloured from sinew red to tanned leather brown for the "leather_harness" states.
/obj/item/clothing/accessory/storage/harness
	name = "leather harness"
	desc = "Crossed leather straps with loops for hand tools and short weapons. Attach it to your clothing, then click it to reach what hangs on it."
	icon_state = "leather_harness"
	slots = 4
	slot = "utility"
	flammable = TRUE

/obj/item/clothing/accessory/storage/harness/New()
	..()
	hold.max_w_class = ITEM_SIZE_NORMAL
	hold.max_storage_space = 12
	hold.can_hold = list(
		/obj/item/weapon/material/kitchen/utensil/knife,
		/obj/item/weapon/material/hatchet,
		/obj/item/weapon/material/machete,
		/obj/item/weapon/material/pickaxe,
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/material/trowel,
		/obj/item/weapon/material/sword,
		/obj/item/weapon/melee,
		/obj/item/weapon/flint,
		/obj/item/weapon/hammer,
		/obj/item/weapon/chisel,
		/obj/item/weapon/saw,
		/obj/item/weapon/crowbar,
		/obj/item/weapon/wrench,
		/obj/item/weapon/screwdriver,
		/obj/item/weapon/wirecutters,
		/obj/item/weapon/weldingtool,
		/obj/item/flashlight,
		)
