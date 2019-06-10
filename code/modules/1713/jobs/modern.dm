////////////////////////////////////////////////MARINES (2000's)////////////////////////////////////////

/datum/job/american/usmc_lieutenant
	title = "USMC Lieutenant"
	rank_abbreviation = "Lt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCap"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_modernday = TRUE
	is_radioman = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/american/usmc_lieutenant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat/khaki(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/glasses/sunglasses(H), slot_wear_mask)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_sergeant
	title = "USMC Sergeant"
	rank_abbreviation = "Sgt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCap"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_squad_leader = TRUE
	is_radioman = TRUE
	is_modernday = TRUE
	can_get_coordinates = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/american/usmc_sergeant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet/military(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/glasses/tactical_goggles(H), slot_wear_mask)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Insurgents!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_medic
	title = "USMC Field Medic"
	rank_abbreviation = "Cpl."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_modernday = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/american/usmc_medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(pasgt_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW) //not used
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("mg", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_marksman
	title = "USMC Designated Marksman"
	rank_abbreviation = "Spc."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_modernday = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 12

/datum/job/american/usmc_marksman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14/sniper, slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet/military(H), slot_l_store)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Insurgents!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_lmg
	title = "USMC Automatic Rifleman"
	rank_abbreviation = "Spc."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_modernday = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/american/usmc_lmg/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m249(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/m249(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_store)
	if (prob(50))
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/glasses/tactical_goggles(H), slot_wear_mask)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/glasses/sunglasses/large(H), slot_wear_mask)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_HIGH)
	return TRUE
/datum/job/american/usmc_soldier
	title = "USMC Rifleman"
	rank_abbreviation = "Pvt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_modernday = TRUE
	// AUTOBALANCE
	min_positions = 10
	max_positions = 100

/datum/job/american/usmc_soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	if (prob(50))
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/glasses/tactical_goggles(H), slot_wear_mask)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/glasses/sunglasses/large(H), slot_wear_mask)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a4/att(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet/military(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	return TRUE
