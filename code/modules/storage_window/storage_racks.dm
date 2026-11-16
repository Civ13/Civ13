// Racks (storage overhaul, docs/storage-window.md): open frames that hold one
// kind of thing each and show what hangs on them. They are storage containers,
// so they open the storage window, take Dump Out, locks are not offered (an
// open frame can't be locked), and count as a container for a tidy room.
//   peg post (Primitive Construction)   hats, clothes, bags and tools
//   tool rack (Basic Furniture)          tools
//   weapon rack (Basic Furniture)        weapons, bows, guns and shields
//   coat stand (Fine Furniture)          coats, cloaks, hats and bags
//   clothes rail (Fine Furniture)        any clothing
// Sprites: icons/obj/storage_racks.dmi, drawn by tests/sprites/create_storage_racks.py.
// Each held thing is drawn on the rack, shrunk, at one of rack_spots (x, y in
// image pixels from the top left, the same points the sprite's pegs serve).

#define STORAGE_RACK_ICON 'icons/obj/storage_racks.dmi'

/obj/structure/storage_container/rack
	name = "rack"
	desc = "A frame to hang things on."
	icon = STORAGE_RACK_ICON
	icon_state = "peg_post"
	base_state = "peg_post"
	density = FALSE
	slots = 4
	max_item_size = ITEM_SIZE_LARGE
	max_space = 16
	dump_time = 10
	food_decay_step = 600 // hung in the open, like the floor
	var/rack_kind = "things" // for the refusal message
	var/rack_scale = 0.5
	var/list/rack_spots = list(list(9, 13), list(22, 13), list(9, 22), list(22, 22))

/obj/structure/storage_container/rack/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	if (!rack_takes(W))
		if (!stop_messages)
			to_chat(usr, SPAN_WARNING("\The [src] is for [rack_kind]."))
		return FALSE
	return ..()

// An open frame has nothing to lock.
/obj/structure/storage_container/rack/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/fitted_lock))
		to_chat(user, SPAN_WARNING("\The [src] is an open frame; there is nothing to lock."))
		return
	return ..()

/obj/structure/storage_container/rack/proc/rack_takes(obj/item/I)
	return TRUE

/obj/structure/storage_container/rack/update_icon()
	icon_state = base_state
	overlays.Cut()
	if (!storage)
		return
	var/i = 0
	for (var/obj/item/I in storage.contents)
		i++
		if (i > rack_spots.len)
			break
		var/list/spot = rack_spots[i]
		var/image/held = image(I.icon, I.icon_state)
		held.appearance_flags = RESET_COLOR | PIXEL_SCALE
		held.color = I.color
		held.transform = matrix(rack_scale, 0, spot[1] - 16, 0, rack_scale, 16 - spot[2])
		overlays += held

/obj/structure/storage_container/rack/examine(mob/user, distance = -1)
	..()
	if (storage && storage.contents.len)
		var/list/names = list()
		for (var/obj/item/I in storage.contents)
			names += "\a [I]"
		to_chat(user, SPAN_NOTICE("On it: [english_list(names)]."))

// What counts as what.
/proc/rack_is_clothing(obj/item/I)
	return istype(I, /obj/item/clothing) || (I.slot_flags & (SLOT_OCLOTHING | SLOT_ICLOTHING | SLOT_HEAD | SLOT_BACK | SLOT_BELT | SLOT_SHOULDER))

/proc/rack_is_tool(obj/item/I)
	return I.tool_flags || istype(I, /obj/item/weapon/plough) // tool_flags covers axes, picks, shovels and hammers

/proc/rack_is_weapon(obj/item/I)
	return istype(I, /obj/item/weapon/gun) || istype(I, /obj/item/weapon/material/sword) || istype(I, /obj/item/weapon/material/spear) || istype(I, /obj/item/weapon/shield) || istype(I, /obj/item/weapon/melee) || (istype(I, /obj/item/weapon/material) && I.force >= 10 && !rack_is_tool(I))

/////////////////////////////////////////////////////////////////// peg post
/obj/structure/storage_container/rack/peg_post
	name = "peg post"
	desc = "A forked post set in a heap of stones, with pegs lashed on to hang hats, clothes, bags and tools."
	icon_state = "peg_post"
	base_state = "peg_post"
	rack_kind = "hats, clothes, bags and tools"
	slots = 4

/obj/structure/storage_container/rack/peg_post/rack_takes(obj/item/I)
	return rack_is_clothing(I) || rack_is_tool(I)

/////////////////////////////////////////////////////////////////// tool rack
/obj/structure/storage_container/rack/tool_rack
	name = "tool rack"
	desc = "A board on legs with a row of pegs, so every tool has its place."
	icon_state = "tool_rack"
	base_state = "tool_rack"
	rack_kind = "tools"
	slots = 5
	max_space = 25
	rack_scale = 0.55
	rack_spots = list(list(7, 15), list(12, 15), list(17, 15), list(22, 15), list(27, 15))

/obj/structure/storage_container/rack/tool_rack/rack_takes(obj/item/I)
	return rack_is_tool(I)

///////////////////////////////////////////////////////////////// weapon rack
/obj/structure/storage_container/rack/weapon_rack
	name = "weapon rack"
	desc = "A notched crossbar over a trough, to stand spears, swords, bows and guns ready to hand."
	icon_state = "weapon_rack"
	base_state = "weapon_rack"
	rack_kind = "weapons"
	slots = 4
	max_item_size = ITEM_SIZE_HUGE
	max_space = 24
	rack_scale = 0.65
	rack_spots = list(list(9, 15), list(14, 15), list(19, 15), list(24, 15))

/obj/structure/storage_container/rack/weapon_rack/rack_takes(obj/item/I)
	return rack_is_weapon(I)

////////////////////////////////////////////////////////////////// coat stand
/obj/structure/storage_container/rack/coat_stand
	name = "coat stand"
	desc = "A turned pole on a sturdy foot, with hooks for coats, cloaks, hats and bags."
	icon_state = "coat_stand"
	base_state = "coat_stand"
	rack_kind = "coats, cloaks, hats and bags"
	slots = 4
	rack_spots = list(list(10, 12), list(22, 12), list(9, 19), list(23, 19))

/obj/structure/storage_container/rack/coat_stand/rack_takes(obj/item/I)
	return rack_is_clothing(I)

//////////////////////////////////////////////////////////////// clothes rail
/obj/structure/storage_container/rack/clothes_rail
	name = "clothes rail"
	desc = "A pole between two uprights, hung with hangers for clothing."
	icon_state = "clothes_rail"
	base_state = "clothes_rail"
	rack_kind = "clothing"
	slots = 5
	max_space = 25
	rack_scale = 0.55
	rack_spots = list(list(7, 16), list(12, 16), list(17, 16), list(22, 16), list(27, 16))

/obj/structure/storage_container/rack/clothes_rail/rack_takes(obj/item/I)
	return istype(I, /obj/item/clothing)
