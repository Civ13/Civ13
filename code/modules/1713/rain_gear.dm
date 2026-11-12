// Rain gear: type paths and art hookup only. Weather protection, recipes and
// research are wired up by the weather protection work.
// All art is drawn by tests/sprites/create_rain_gear.py.

/obj/item/clothing/suit/straw_rain_cape
	name = "straw rain cape"
	desc = "Bundles of dried grass tied in overlapping tiers. Rain runs down the straw and drips off the hem."
	icon = 'icons/obj/clothing/rain_gear.dmi'
	icon_state = "straw_rain_cape"
	item_state = "straw_rain_cape"
	item_icons = list(
		slot_wear_suit_str = 'icons/mob/rain_gear.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_rain_gear.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_rain_gear.dmi',
		)
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS

/obj/item/clothing/suit/oilskin_coat
	name = "oilskin coat"
	desc = "A long canvas coat soaked in linseed oil until it sheds water. Stiff, yellow and smelling faintly of paint."
	icon = 'icons/obj/clothing/rain_gear.dmi'
	icon_state = "oilskin_coat"
	item_state = "oilskin_coat"
	item_icons = list(
		slot_wear_suit_str = 'icons/mob/rain_gear.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_rain_gear.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_rain_gear.dmi',
		)
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS|LEGS

/obj/item/clothing/head/souwester
	name = "sou'wester"
	desc = "An oilskin rain hat. The long back brim keeps water from running down your collar."
	icon = 'icons/obj/clothing/rain_gear.dmi'
	icon_state = "souwester"
	item_state = "souwester"
	item_icons = list(
		slot_head_str = 'icons/mob/rain_gear.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_rain_gear.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_rain_gear.dmi',
		)

// Umbrellas. The held sheets are 32x48, so the open canopy is drawn above the
// holder's head by the ordinary in-hand overlay.
/obj/item/weapon/umbrella
	name = "umbrella"
	desc = "Keeps the rain off whoever holds it open."
	icon = 'icons/obj/clothing/rain_gear.dmi'
	icon_state = "umbrella_cloth"
	item_state = "umbrella_cloth"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_rain_gear.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_rain_gear.dmi',
		)
	w_class = ITEM_SIZE_NORMAL
	force = 4
	var/base_state = "umbrella_cloth"
	var/open = FALSE

/obj/item/weapon/umbrella/attack_self(mob/user)
	open = !open
	to_chat(user, "<span class='notice'>You [open ? "open" : "close"] \the [src].</span>")
	update_icon()

/obj/item/weapon/umbrella/update_icon()
	icon_state = open ? "[base_state]_open" : base_state
	item_state = icon_state
	update_held_icon()

/obj/item/weapon/umbrella/paper
	name = "oiled paper umbrella"
	desc = "Oiled paper stretched over split bamboo ribs. Light, and surprisingly good at shedding rain."
	icon_state = "umbrella_paper"
	item_state = "umbrella_paper"
	base_state = "umbrella_paper"

/obj/item/weapon/umbrella/cloth
	name = "black umbrella"
	desc = "Waxed black cloth on steel ribs, with a crooked wooden handle."

/obj/item/weapon/umbrella/nylon
	name = "folding umbrella"
	desc = "A nylon umbrella that telescopes down small enough for a bag."
	icon_state = "umbrella_nylon"
	item_state = "umbrella_nylon"
	base_state = "umbrella_nylon"
	w_class = ITEM_SIZE_SMALL

// Lean-to. dir is the open side. lean_to is the whole shelter in one state;
// lean_to_frame (poles, bedding, shade) and lean_to_roof (leaf thatch) are the
// same art split so the roof can be drawn over whoever shelters inside.
/obj/structure/lean_to
	name = "lean-to"
	desc = "Branches propped on forked poles and thatched with leaves. One side is open."
	icon = 'icons/obj/rain_shelter.dmi'
	icon_state = "lean_to_frame"
	anchored = TRUE
	density = FALSE
	var/image/roof

/obj/structure/lean_to/New()
	..()
	update_icon()

/obj/structure/lean_to/update_icon()
	overlays -= roof
	roof = image(icon, "lean_to_roof", dir = dir, layer = MOB_LAYER + 1)
	overlays += roof
