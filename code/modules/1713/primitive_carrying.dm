// Early carrying gear for Stone and Bronze Age players, below and beside the
// leather backpack (Cooperage, Bronze Age). Each step holds more than the last:
//   grass carry net (belt)  -> hide sling bag (back) -> pack basket on a
//   tumpline (back) -> wooden pack frame (back, Bronze Age, slows the wearer),
// plus a travois that is dragged behind like a crate.
// Sprites: icons/obj/primitive_carrying.dmi and icons/mob/primitive_carrying.dmi,
// drawn by tests/sprites/create_primitive_carrying.py.

/obj/item/weapon/storage/backpack
	// Added to the wearer's movement delay while worn on the back.
	var/carry_slowdown = 0

/obj/item/weapon/storage/belt/carry_net
	name = "grass carry net"
	desc = "A loose net knotted from twine and tied at the waist. It holds a few small things."
	icon = 'icons/obj/primitive_carrying.dmi'
	icon_state = "carry_net"
	item_state = "belt_holster"
	icon_override = 'icons/mob/primitive_carrying.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand.dmi',
		)
	storage_slots = 6
	max_w_class = ITEM_SIZE_SMALL
	max_storage_space = 12
	flammable = TRUE

/obj/item/weapon/storage/backpack/sling_bag
	name = "hide sling bag"
	desc = "A fur-lined hide bag on a strap, slung over one shoulder."
	icon = 'icons/obj/primitive_carrying.dmi'
	icon_state = "sling_bag"
	base_icon = "sling_bag"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_backpacks.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_backpacks.dmi',
		slot_back_str = 'icons/mob/primitive_carrying.dmi',
		)
	max_w_class = ITEM_SIZE_NORMAL
	max_storage_space = 14 // three normal-sized things or seven small ones

/obj/item/weapon/storage/backpack/pack_basket
	name = "pack basket"
	desc = "A tall woven basket carried on the back, its weight taken by a tumpline across the forehead."
	icon = 'icons/obj/primitive_carrying.dmi'
	icon_state = "pack_basket"
	base_icon = "pack_basket"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_backpacks.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_backpacks.dmi',
		slot_back_str = 'icons/mob/primitive_carrying.dmi',
		)
	item_state_slots = list(
		slot_l_hand_str = "produce_basket",
		slot_r_hand_str = "produce_basket",
		)
	max_w_class = ITEM_SIZE_NORMAL
	max_storage_space = 18 // four normal-sized things or nine small ones

/obj/item/weapon/storage/backpack/pack_frame
	name = "pack frame"
	desc = "Two poles and cross bars lashed into a ladder, with bundles tied on. It carries more than a backpack, but the load slows you down."
	icon = 'icons/obj/primitive_carrying.dmi'
	icon_state = "pack_frame"
	base_icon = "pack_frame"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_backpacks.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_backpacks.dmi',
		slot_back_str = 'icons/mob/primitive_carrying.dmi',
		)
	w_class = ITEM_SIZE_HUGE
	max_w_class = ITEM_SIZE_LARGE
	max_storage_space = 28 // three large things, against the backpack's two
	carry_slowdown = 0.3

/obj/item/weapon/storage/backpack/pack_frame/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("Worn on the back, it slows your walk a little."))

/obj/structure/closet/crate/travois
	name = "travois"
	desc = "Two long poles lashed into a drag, with a hide platform between them. Pull it to haul a load across country."
	icon = 'icons/obj/primitive_carrying.dmi'
	icon_state = "travois"
	icon_opened = "travois_open"
	icon_closed = "travois"
	climbable = FALSE
	storagecap = 15
	flammable = TRUE
