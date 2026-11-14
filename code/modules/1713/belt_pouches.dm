// Belt pouches: small pouches worn on the belt or attached to clothing, for
// small things such as herbs, stones, ore and coins. See docs/gemstones.md.
// Included after clothing_accessories.dm: the can_attach_accessory override
// falls back to that definition.

#define MAX_BELT_POUCHES_PER_OUTFIT 2

/obj/item/clothing/accessory/storage/belt_pouch
	name = "leather belt pouch"
	desc = "A small leather pouch with a flap. Hang it from a belt or attach it to your clothes to carry small things: herbs, stones, ore, coins."
	icon = 'icons/obj/belt_pouches.dmi'
	icon_state = "leather_pouch"
	icon_override = 'icons/mob/belt_pouches.dmi'
	slot = "decor" // several decor accessories may share an outfit; see the cap below
	slot_flags = SLOT_BELT | SLOT_POCKET
	w_class = ITEM_SIZE_SMALL
	slots = 6
	value = 4

/obj/item/clothing/accessory/storage/belt_pouch/New()
	..()
	hold.max_w_class = ITEM_SIZE_SMALL
	hold.max_storage_space = 12
	hold.cant_hold = list(/obj/item/weapon/storage, /obj/item/clothing/accessory/storage)

/obj/item/clothing/accessory/storage/belt_pouch/cloth
	name = "cloth drawstring pouch"
	desc = "A small cloth pouch closed with a drawstring. Hang it from a belt or attach it to your clothes to carry small things: herbs, stones, ore, coins."
	icon_state = "cloth_pouch"
	value = 3

// Two pouches per outfit, so they stay small pockets rather than a backpack.
/obj/item/clothing/can_attach_accessory(obj/item/clothing/accessory/A)
	if (istype(A, /obj/item/clothing/accessory/storage/belt_pouch))
		var/pouches = 0
		for (var/obj/item/clothing/accessory/storage/belt_pouch/P in accessories)
			pouches++
		if (pouches >= MAX_BELT_POUCHES_PER_OUTFIT)
			return FALSE
	return ..()

#undef MAX_BELT_POUCHES_PER_OUTFIT
