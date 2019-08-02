/obj/item/clothing/shoes/creed
	name = "creed boots"
	desc = "A pair of leather boots worn by the creed."
	icon_state = "ac_boots"
	item_state = "ac_boots"
	worn_state = "ac_boots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, arrow = 10, gun = FALSE, energy = 8, bomb = 15, bio = 10, rad = 25)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/under/creed
	name = "creed shirt"
	desc = "A white shirt of the creed."
	icon_state = "ac_shirt"
	item_state = "ac_shirt"
	worn_state = "ac_shirt"

/obj/item/clothing/suit/armor/creed
	name = "creed armor"
	desc = "A leather armor worn by the creed."
	icon_state = "ac_armor"
	item_state = "ac_armor"
	worn_state = "ac_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 65, arrow = 80, gun = 10, energy = 15, bomb = 40, bio = 20, rad = 10)
	value = 45
	slowdown = 0.2
	health = 42

/obj/item/clothing/gloves/creed
	name = "creed gauntlets"
	desc = "A pair of armored creed gauntlets with a hidden blade."
	icon_state = "ac_gauntlets"
	item_state = "ac_gauntlets"
	worn_state = "ac_gauntlets"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 20, arrow = 40, gun = 10, energy = 8, bomb = 15, bio = 10, rad = 5)
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	health = 25

/obj/item/clothing/head/creed
	name = "creed hood"
	desc = "It's hood that covers the head."
	icon_state = "ac_hood"
	item_state = "ac_hood"
	worn_state = "ac_hood"
	var/hood = FALSE

/obj/item/clothing/head/creed/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Toggle Hood"
	if (hood)
		icon_state = "ac_hood"
		item_state = "ac_hood"
		worn_state = "ac_hood"
		flags_inv = initial(flags_inv)
		body_parts_covered = initial(body_parts_covered)
		item_state_slots["slot_wear_suit"] = "ac_hood"
		usr << "<span class = 'danger'>You take off your hood.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		return
	else if (!hood)
		icon_state = "ac_hood_up"
		item_state = "ac_hood_up"
		worn_state = "ac_hood_up"
		flags_inv = BLOCKHAIR|HIDEFACE
		body_parts_covered = HEAD|FACE
		item_state_slots["slot_wear_suit"] = "ac_hood_up"
		usr << "<span class = 'danger'>You cover your head with your hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		return