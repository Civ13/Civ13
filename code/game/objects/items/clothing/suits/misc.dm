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

/obj/item/clothing/suit/chef/tfc
	name = "Texas Fried Chicken apron"
	desc = "A cloth apron. It reads TFC."
	icon_state = "aprontfc"
	item_state = "aprontfc"

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

/obj/item/clothing/suit/pimpsuit
	name = "purple pimp jacket."
	desc = "A brightly colored purple button up coat for gangsters."
	icon_state = "pimpcoat"
	item_state = "pimpcoat"

/obj/item/clothing/suit/blugojacket
	name = "Blugoslavian Jacket."
	desc = "A standard issue combat jacket of the blugo army."
	icon_state = "bcj"
	item_state = "bcj"
	body_parts_covered = UPPER_TORSO|ARMS

/obj/item/clothing/suit/blugojacket/flak //only issued to the commander
	name = "Blugoslavian Flak Jacket."
	desc = "A Blugo Jacket, feels pretty heavy and is probably stuffed with a mix of kevlar and canvas"
	icon_state = "bcj"
	item_state = "bcj"
	body_parts_covered = UPPER_TORSO|ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 5, arrow = 2, gun = 2, energy = 15, bomb = 5, bio = 30, rad = 20)
	slowdown = 0.1

/obj/item/clothing/suit/gorillasuit
	name = "full body gorilla outfit"
	desc = "A lifelike full body gorilla suit-outfit, ideal for costume parties and pranksters."
	icon_state = "gorilla_suit"
	item_state = "gorilla_suit"
	worn_state = "gorilla_suit"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|FEET|ARMS
	cold_protection = LOWER_TORSO|LEGS|ARMS|FEET
	var/adjusted = FALSE

/obj/item/clothing/suit/gorillasuit/verb/toggle_hood()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/suit/gorillasuit)
		return
	else
		if (adjusted)
			item_state = "gorilla_suit"
			icon_state = "gorilla_suit"
			worn_state = "gorilla_suit"
			item_state_slots["slot_w_uniform"] = "gorilla_suit"
			usr << "<span class = 'danger'>You take down your body suit's hood.</span>"
			adjusted = FALSE
		else if (!adjusted)
			item_state = "gorilla_suit_h"
			icon_state = "gorilla_suit_h"
			worn_state = "gorilla_suit_h"
			item_state_slots["slot_w_uniform"] = "gorilla_suit_h"
			usr << "<span class = 'danger'>You put up your body suit's hood.</span>"
			body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|FEET|ARMS|HEAD
			flags_inv = BLOCKHEADHAIR
			adjusted = TRUE
	update_clothing_icon()