////////////////////////////////////////////PIRATES///////////////////////////////////////////////////////
/datum/job/pirates
	faction = "Station"

/datum/job/pirates/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name
	H.s_tone = 58

/datum/job/pirates/captain
	title = "Pirate Captain"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Cpt"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerCO"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/pirates/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/piratehat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the [title] of the Pirate ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE


////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/datum/job/pirates/seaman
	title = "Pirate"
	en_meaning = "Pirate Seaman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 20

/datum/job/pirates/seaman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate5(H), slot_w_uniform)
//jacket
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket4(H), slot_wear_suit)
	else if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket3(H), slot_wear_suit)

//head
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/piratebandana1(H), slot_head)
	var/randweapon = rand(1,5)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/cutlass(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	else if (randweapon == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 4)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/boarding_axe(H), slot_belt)
	else if (randweapon == 5)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple pirate. Follow your Captain's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("mg", STAT_MEDIUM_LOW) //not used
	H.setStat("smg", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////BRITISH///////////////////////////////////////////////////////

/datum/job/british
	faction = "Station"

/datum/job/british/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/british/captain
	title = "Royal Navy Captain"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Cpt"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRACO"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform) // for now
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_captain(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the [title] of the Royal Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE


////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/british/seaman
	title = "Seaman"
	en_meaning = "Royal Navy Seaman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 20

/datum/job/british/seaman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor4(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/british_scarf/british_scarf_a = new /obj/item/clothing/accessory/armband/british_scarf(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(british_scarf_a, H)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the Royal Navy. Follow your Captain's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("mg", STAT_MEDIUM_LOW) //not used
	H.setStat("smg", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
