//Chef
/obj/item/clothing/suit
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_suits.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_suits.dmi',
		)


/obj/item/clothing/suit/chef
	name = "A classic chef's apron."
	desc = "A basic, dull, white chef's apron."
	icon_state = "apronchef"
	item_state = "apronchef"
	blood_overlay_type = "armor"
	body_parts_covered = FALSE
	gas_transfer_coefficient = 0.90
	permeability_coefficient = 0.50
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
