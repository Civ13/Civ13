// Belt pouches: small pouches hung from a leather belt or shoulder belt, or
// attached to clothing, for small things such as herbs, stones, ore and
// coins. See docs/gemstones.md.
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

// A second pouch on the same garment or belt hangs on the left hip, so the
// two never draw on top of each other.
/obj/item/clothing/accessory/storage/belt_pouch/on_attached(obj/item/clothing/S, mob/user)
	var/others = 0
	if (istype(S))
		for (var/obj/item/clothing/accessory/storage/belt_pouch/P in S.accessories)
			if (P != src)
				others++
	overlay_state = others ? "[icon_state]_left" : null
	mob_overlay = null
	inv_overlay = null
	..()
	if (istype(S))
		S.update_clothing_icon()

// Two pouches per outfit or belt, so they stay small pockets, not a backpack.
/obj/item/clothing/can_attach_accessory(obj/item/clothing/accessory/A)
	if (istype(A, /obj/item/clothing/accessory/storage/belt_pouch))
		var/pouches = 0
		for (var/obj/item/clothing/accessory/storage/belt_pouch/P in accessories)
			pouches++
		if (pouches >= MAX_BELT_POUCHES_PER_OUTFIT)
			return FALSE
	return ..()

// Plain leather waist belt worn in the belt slot. Pouches, a sheath or holster
// and a tool loop hang from it.
/obj/item/clothing/pouch_belt
	name = "leather belt"
	desc = "A plain leather belt with a buckle. Hang a pouch or two, a sheath or holster and a tool loop from it to keep things close at hand."
	icon = 'icons/obj/belt_pouches.dmi'
	icon_state = "pouch_belt"
	item_state = "pouch_belt"
	icon_override = 'icons/mob/belt_pouches.dmi'
	slot_flags = SLOT_BELT
	w_class = ITEM_SIZE_SMALL
	body_parts_covered = 0
	// Two pouches, one sheath or holster, and one tool loop.
	valid_accessory_slots = list("decor", "utility", "loop")
	restricted_accessory_slots = list("utility", "loop")
	value = 3
	// Accessory types that may hang from this belt.
	var/list/belt_attachable = list(
		/obj/item/clothing/accessory/storage/belt_pouch,
		/obj/item/clothing/accessory/storage/sheath,
		/obj/item/clothing/accessory/holster,
		/obj/item/clothing/accessory/storage/tool_loop)

/obj/item/clothing/pouch_belt/can_attach_accessory(obj/item/clothing/accessory/A)
	if (!is_type_in_list(A, belt_attachable))
		return FALSE
	return ..()

/obj/item/clothing/pouch_belt/update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_belt()

// Shoulder belt worn across the body over clothes, beside the waist belt.
// It is a garment accessory, so it needs no second belt slot.
/obj/item/clothing/accessory/storage/baldric
	name = "shoulder belt"
	desc = "A leather strap worn across the body from shoulder to hip. A pouch or two can hang from it, or a sword and a pouch."
	icon = 'icons/obj/belt_pouches.dmi'
	icon_state = "baldric"
	icon_override = 'icons/mob/belt_pouches.dmi'
	slot = "sash"
	slot_flags = 0
	w_class = ITEM_SIZE_SMALL
	slots = 2
	value = 3

/obj/item/clothing/accessory/storage/baldric/New()
	..()
	hold.max_w_class = ITEM_SIZE_NORMAL
	hold.max_storage_space = 8
	hold.can_hold = list(/obj/item/clothing/accessory/storage/belt_pouch, /obj/item/weapon/material/sword)

// A shoulder belt carries one sword at the hip; the other place is for a pouch.
/obj/item/clothing/accessory/storage/baldric/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	if (istype(W, /obj/item/weapon/material/sword) && hold && (locate(/obj/item/weapon/material/sword) in hold))
		if (!stop_messages)
			to_chat(usr, SPAN_NOTICE("\The [src] already carries a sword."))
		return FALSE
	return TRUE

// Leather loop for a belt: one hand tool or other thing made to hang from a belt.
/obj/item/clothing/accessory/storage/tool_loop
	name = "tool loop"
	desc = "A leather loop that hangs from a belt and holds one hand tool, or anything else made to be worn on a belt."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "knifeholster"
	item_state = "knifeholster"
	slot = "loop"
	slots = 1
	w_class = ITEM_SIZE_SMALL
	ripable = FALSE
	value = 2

/obj/item/clothing/accessory/storage/tool_loop/New()
	..()
	hold.max_w_class = ITEM_SIZE_NORMAL
	hold.max_storage_space = 4

/obj/item/clothing/accessory/storage/tool_loop/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	var/fits = (W.slot_flags & SLOT_BELT) && !istype(W, /obj/item/weapon/storage) && !istype(W, /obj/item/clothing) && !istype(W, /obj/item/weapon/gun)
	if (!fits && !stop_messages)
		to_chat(usr, SPAN_NOTICE("\The [W] is not made to hang from a belt."))
	return fits

#undef MAX_BELT_POUCHES_PER_OUTFIT
