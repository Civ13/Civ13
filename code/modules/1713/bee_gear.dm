// Beekeeping clothes (bee farming 4b). A veil of fine gauze hung from a broad
// hat keeps stings off the face and neck (Medieval, Tailoring); a loose white
// beekeeper suit closed at wrist and ankle keeps them off the body (Industrial,
// Textile Mills). Worn together they make stings rare. See bee_sting_chance()
// in wild_bees.dm.

/obj/item/clothing/head/bee_veil
	name = "bee veil"
	desc = "A broad hat with a fine dark gauze veil hanging all round to the shoulders. Bees cannot get at your face or neck through it."
	icon = 'icons/obj/clothing/bee_gear.dmi'
	icon_state = "bee_veil"
	item_state = "bee_veil"
	item_icons = list(
		slot_head_str = 'icons/mob/bee_gear.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_bee_gear.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_bee_gear.dmi',
		)
	body_parts_covered = HEAD|FACE
	flammable = TRUE

/obj/item/clothing/suit/beekeeper_suit
	name = "beekeeper suit"
	desc = "A loose one-piece suit of thick white cotton, closed tight at the wrists and ankles so no bee can crawl inside."
	icon = 'icons/obj/clothing/bee_gear.dmi'
	icon_state = "beekeeper_suit"
	item_state = "beekeeper_suit"
	item_icons = list(
		slot_wear_suit_str = 'icons/mob/bee_gear.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_bee_gear.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_bee_gear.dmi',
		)
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS|LEGS
	flammable = TRUE
