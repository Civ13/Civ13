/obj/item/clothing/suit // why can't this be on a uniform suit dm?
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_suits.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_suits.dmi',
		)

/* Miscallaneous Suits */

/obj/item/clothing/suit/chef
	name = "a classic chef's apron."
	desc = "A basic, dull, white chef's apron."
	icon_state = "apronchef"
	item_state = "apronchef"
	blood_overlay_type = "armor"
	body_parts_covered = FALSE
	gas_transfer_coefficient = 0.90
	permeability_coefficient = 0.50
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS

/obj/item/clothing/suit/hawaiian
	name = "blue hawaiian shirt."
	desc = "A brightly patterned and gaudy hawaiian shirt. It has a blue hue"
	icon_state = "hawaiian_blue"
	item_state = "hawaiian_blue"
	body_parts_covered = UPPER_TORSO

/obj/item/clothing/suit/hawaiian/orange
	name = "orange hawaiian shirt."
	desc = "A brightly patterned and gaudy hawaiian shirt. It has a orange hue"
	icon_state = "hawaiian_orange"
	item_state = "hawaiian_orange"

/obj/item/clothing/suit/hawaiian/purple
	name = "purple hawaiian shirt."
	desc = "A brightly patterned and gaudy hawaiian shirt. It has a purple hue"
	icon_state = "hawaiian_purple"
	item_state = "hawaiian_purple"

/obj/item/clothing/suit/hawaiian/green
	name = "green hawaiian shirt."
	desc = "A brightly patterned and gaudy hawaiian shirt. It has a green hue"
	icon_state = "hawaiian_green"
	item_state = "hawaiian_green"