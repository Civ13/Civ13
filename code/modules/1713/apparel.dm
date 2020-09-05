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

/obj/item/clothing/under/arrogant_student
	name = "arrogant student's outfit"
	desc = "A loose outfit worn by arrogant students."
	icon_state = "arrogant_student"
	item_state = "arrogant_student"
	worn_state = "arrogant_student"

/obj/item/clothing/suit/storage/jacket/wise_tutor
	name = "wise tutor's robe"
	desc = "A rough brown robe, favored by wizened teachers."
	icon_state = "wise_tutor_robe"
	item_state = "wise_tutor_robe"
	worn_state = "wise_tutor_robe"
	var/toggled = FALSE

/obj/item/clothing/suit/storage/jacket/wise_tutor/verb/toggle_hood()
	set category = null
	set src in usr
	if (type !=/obj/item/clothing/suit/storage/jacket/wise_tutor)
		return
	else
		if (toggled)
			item_state = "wise_tutor_robe"
			icon_state = "wise_tutor_robe"
			worn_state = "wise_tutor_robe"
			item_state_slots["slot_w_uniform"] = "wise_tutor_robe"
			usr << "<span class = 'danger'>you take down your robe's hood.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "wise_tutor_hooded"
			icon_state = "wise_tutor_hooded"
			worn_state = "wise_tutor_hooded"
			item_state_slots["slot_w_uniform"] = "wise_tutor_hooded"
			usr << "<span class = 'danger'>you put up your robe's hood.</span>"
			toggled = TRUE
	update_clothing_icon()

/obj/item/clothing/suit/storage/jacket/arrogant_student
	name = "arrogant_student robe"
	desc = "A rough black robe, favored by those who believe they are already good enough."
	icon_state = "arrogant_student_robe"
	item_state = "arrogant_student_robe"
	worn_state = "arrogant_student_robe"
	var/toggled = FALSE

/obj/item/clothing/suit/storage/jacket/arrogant_student/verb/toggle_hood()
	set category = null
	set src in usr
	if (type !=/obj/item/clothing/suit/storage/jacket/arrogant_student)
		return
	else
		if (toggled)
			item_state = "arrogant_student_robe"
			icon_state = "arrogant_student_robe"
			worn_state = "arrogant_student_robe"
			item_state_slots["slot_w_uniform"] = "arrogant_student_robe"
			usr << "<span class = 'danger'>you take down your robe's hood.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "arrogant_student_robe_hooded"
			icon_state = "arrogant_student_robe_hooded"
			worn_state = "arrogant_student_robe_hooded"
			item_state_slots["slot_w_uniform"] = "arrogant_student_robe_hooded"
			usr << "<span class = 'danger'>you put up your robe's hood.</span>"
			toggled = TRUE
	update_clothing_icon()

/obj/item/clothing/shoes/heavyboots/wrappedboots
	name = "\improper wrapped boots"
	icon_state = "wrappedboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 10, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = 40)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
