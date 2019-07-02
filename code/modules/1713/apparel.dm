/obj/item/clothing/under
	var/swapped = FALSE

/obj/item/clothing/under/chad
	name = "chad clothing"
	desc = "wow!"
	icon_state = "chad"
	item_state = "chad"
	worn_state = "chad"

/obj/item/clothing/shoes/chad
	name = "chad shoes"
	desc = "ouch!"
	icon_state = "chad"
	item_state = "chad"
	worn_state = "chad"
	force = WEAPON_FORCE_WEAK

/obj/item/clothing/under/flamengo
	name = "Flamengo shirt with yellow shorts"
	desc = "A C.R. Flamengo football shirt, with yellow swimming trunks."
	icon_state = "flamengo"
	item_state = "flamengo"
	worn_state = "flamengo"

/obj/item/clothing/shoes/flipflops
	name = "flip-flops"
	desc = "Brazilian style flip-flops."
	icon_state = "flipflops"
	item_state = "flipflops"
	worn_state = "flipflops"
	force = WEAPON_FORCE_WEAK

/obj/item/clothing/under/jedi
	name = "Jedi outfit"
	desc = "A loose outfit worn by the Jedi."
	icon_state = "jedi_knight"
	item_state = "jedi_knight"
	worn_state = "jedi_knight"

/obj/item/clothing/under/sith
	name = "Sith outfit"
	desc = "A loose outfit worn by the Siths."
	icon_state = "sith_knight"
	item_state = "sith_knight"
	worn_state = "sith_knight"

/obj/item/clothing/suit/storage/jacket/jedi
	name = "Jedi robe"
	desc = "A brown Jedi robe."
	icon_state = "jedi_robe"
	item_state = "jedi_robe"
	worn_state = "jedi_robe"
	var/toggled = FALSE

/obj/item/clothing/suit/storage/jacket/jedi/verb/toggle_hood()
	set category = null
	set src in usr
	if (type !=/obj/item/clothing/suit/storage/jacket/jedi)
		return
	else
		if (toggled)
			item_state = "jedi_robe"
			icon_state = "jedi_robe"
			worn_state = "jedi_robe"
			item_state_slots["slot_w_uniform"] = "jedi_robe"
			usr << "<span class = 'danger'>You take down your robe's hood.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "jedi_robe_hooded"
			icon_state = "jedi_robe_hooded"
			worn_state = "jedi_robe_hooded"
			item_state_slots["slot_w_uniform"] = "jedi_robe_hooded"
			usr << "<span class = 'danger'>You put up your robe's hood.</span>"
			toggled = TRUE
	update_clothing_icon()

/obj/item/clothing/suit/storage/jacket/sith
	name = "Sith robe"
	desc = "A black Sith robe."
	icon_state = "sith_robe"
	item_state = "sith_robe"
	worn_state = "sith_robe"
	var/toggled = FALSE

/obj/item/clothing/suit/storage/jacket/sith/verb/toggle_hood()
	set category = null
	set src in usr
	if (type !=/obj/item/clothing/suit/storage/jacket/sith)
		return
	else
		if (toggled)
			item_state = "sith_robe"
			icon_state = "sith_robe"
			worn_state = "sith_robe"
			item_state_slots["slot_w_uniform"] = "sith_robe"
			usr << "<span class = 'danger'>You take down your robe's hood.</span>"
			toggled = FALSE
		else if (!toggled)
			item_state = "sith_robe_hooded"
			icon_state = "sith_robe_hooded"
			worn_state = "sith_robe_hooded"
			item_state_slots["slot_w_uniform"] = "sith_robe_hooded"
			usr << "<span class = 'danger'>You put up your robe's hood.</span>"
			toggled = TRUE
	update_clothing_icon()

/obj/item/clothing/under/flamengo
	name = "Flamengo shirt with yellow shorts"
	desc = "A C.R. Flamengo football shirt, with yellow swimming trunks."
	icon_state = "flamengo"
	item_state = "flamengo"
	worn_state = "flamengo"

/obj/item/clothing/shoes/heavyboots/wrappedboots
	name = "\improper wrapped boots"
	icon_state = "wrappedboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 10, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = 40)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
