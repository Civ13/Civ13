/obj/item/clothing/under
	var/swapped = FALSE

/obj/item/clothing/under/chad
	name = "chad clothing"
	desc = "Wow!"
	icon_state = "chad"
	item_state = "chad"
	worn_state = "chad"

/obj/item/clothing/shoes/chad
	name = "chad shoes"
	desc = "Ouch!"
	icon_state = "chad"
	item_state = "chad"
	worn_state = "chad"
	force = WEAPON_FORCE_WEAK

/obj/item/clothing/shoes/flipflops
	name = "flip-flops"
	desc = "Brazilian style flip-flops."
	icon_state = "flipflops"
	item_state = "flipflops"
	worn_state = "flipflops"
	force = WEAPON_FORCE_WEAK

/obj/item/clothing/under/wise_tutor
	name = "wise tutor's outfit"
	desc = "A loose outfit worn by the wise & experienced."
	icon_state = "wise_tutor"
	item_state = "wise_tutor"
	worn_state = "wise_tutor"

/obj/item/clothing/under/wise_tutor2
	name = "wise tutor's alternative outfit"
	desc = "A loose outfit worn by the wise & experienced."
	icon_state = "wise_tutor2"
	item_state = "wise_tutor2"
	worn_state = "wise_tutor2"

/obj/item/clothing/under/wise_disciple
	name = "wise disciple outfit"
	desc = "A loose outfit worn by the unwise & unexperienced."
	icon_state = "wise_tutor3"
	item_state = "wise_tutor3"
	worn_state = "wise_tutor3"

/obj/item/clothing/under/arrogant_student
	name = "arrogant student's outfit"
	desc = "A loose outfit worn by arrogant students."
	icon_state = "arrogant_student"
	item_state = "arrogant_student"
	worn_state = "arrogant_student"

/obj/item/clothing/suit/storage/coat/wise_tutor_robes
	name = "wise tutor robes"
	desc = "Robes commonly worn by wise tutors."
	icon_state = "wise_tutor_robe"
	item_state = "wise_tutor_robe"
	worn_state = "wise_tutor_robe"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/suit/storage/coat/wise_tutor_robes/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Toggle Hood"
	if (hood)
		icon_state = "wise_tutor_robe"
		item_state = "wise_tutor_robe"
		worn_state = "wise_tutor_robe"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "wise_tutor_robe"
		usr << "<span class = 'danger'>you take off your robes' hood.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return
	else if (!hood)
		icon_state = "wise_tutor_hooded"
		item_state = "wise_tutor_hooded"
		worn_state = "wise_tutor_hooded"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT|HEAD
		item_state_slots["slot_wear_suit"] = "wise_tutor_hooded"
		usr << "<span class = 'danger'>you cover your head with your robes' hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/obj/item/clothing/suit/storage/coat/arrogant_student_robes
	name = "arrogant student robes"
	desc = "Robes commonly worn by spiteful students."
	icon_state = "arrogant_student_robe"
	item_state = "arrogant_student_robe"
	worn_state = "arrogant_student_robe"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/suit/storage/coat/arrogant_student_robes/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Toggle Hood"
	if (hood)
		icon_state = "arrogant_student_robe"
		item_state = "arrogant_student_robe"
		worn_state = "arrogant_student_robe"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "arrogant_student_robe"
		usr << "<span class = 'danger'>you take off your robes' hood.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return
	else if (!hood)
		icon_state = "arrogant_student_robe_hooded"
		item_state = "arrogant_student_robe_hooded"
		worn_state = "arrogant_student_robe_hooded"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT|HEAD
		item_state_slots["slot_wear_suit"] = "arrogant_student_robe_hooded"
		usr << "<span class = 'danger'>you cover your head with your robes' hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/obj/item/clothing/shoes/heavyboots/wrappedboots
	name = "\improper wrapped boots"
	icon_state = "wrappedboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 10, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = 40)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
