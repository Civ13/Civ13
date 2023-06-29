////////////////////////////////////////////////MARINES (2000's)////////////////////////////////////////

/datum/job/american/usmc_lieutenant
	title = "USMC Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRNCap"

	is_coldwar = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_modernday = TRUE
	is_radioman = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/usmc_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat/khaki(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us/officer(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_sergeant
	title = "USMC Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRNCap"

	is_coldwar = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = TRUE
	is_modernday = TRUE
	can_be_female = TRUE
	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/usmc_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us/officer(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Insurgents!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_medic
	title = "USMC Field Medic"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRN"

	is_medic = TRUE
	is_coldwar = TRUE
	can_be_female = TRUE
	is_modernday = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/usmc_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/roller(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_marksman
	title = "USMC Designated Marksman"
	rank_abbreviation = "Spc."

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	is_modernday = TRUE
	uses_squads = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/american/usmc_marksman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14/sniper(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us/modern/m14(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_r_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Insurgents!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/usmc_lmg
	title = "USMC Automatic Rifleman"
	rank_abbreviation = "Spc."

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	is_modernday = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/usmc_lmg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m249(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/m249(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	if (prob(50))
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE
/datum/job/american/usmc_soldier
	title = "USMC Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	is_modernday = TRUE
	can_be_female = TRUE
	uses_squads = TRUE

	min_positions = 10
	max_positions = 100

/datum/job/american/usmc_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_dcu(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/knnif = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(knnif, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)
	if (prob(50))
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a4/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_stanag(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE


//////////////////////////////IDF////////////////////////////////////////////////////////
//Yes, i know they're set as americans. Can't be bothered to add a new faction.

/datum/job/american/idf
	default_language = "Hebrew"
	additional_languages = list("English" = 25, "Russian" = 25, "Arabic" = 10)

/datum/job/american/idf/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_hebrew_name(H.gender)
	H.real_name = H.name
	H.circumcised = TRUE

/datum/job/american/idf/lieutenant
	title = "Segen"
	rank_abbreviation = "Seg."
	en_meaning = "IDF Lieutenant"

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_modernday = TRUE
	is_radioman = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/idf/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/idf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat/khaki(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/jericho941(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us/idfoff(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/idf/sergeant
	title = "Samal"
	rank_abbreviation = "Sam."
	en_meaning = "IDF Sergeant"

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_radioman = TRUE
	is_modernday = TRUE
	can_get_coordinates = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/idf/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/idf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/idf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/jericho941(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us/idfoff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/idf/idf_armor = new /obj/item/clothing/accessory/armor/coldwar/idf(null)
	uniform.attackby(idf_armor, H)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Hezbollah!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/idf/medic
	title = "Chovesh"
	en_meaning = "IDF Field Medic"
	rank_abbreviation = "Chovesh"

	spawn_location = "JoinLateRN"

	is_medic = TRUE
	is_coldwar = TRUE
	is_modernday = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/idf/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/idf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/idf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/jericho941(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/idf/idf_armor = new /obj/item/clothing/accessory/armor/coldwar/idf(null)
	uniform.attackby(idf_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/idf/marksman
	title = "Tzalaf"
	en_meaning = "IDF Sniper"
	rank_abbreviation = "Rav."

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	is_modernday = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/idf/marksman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/idf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/idf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/m24, slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/m24(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/idf/idf_armor = new /obj/item/clothing/accessory/armor/coldwar/idf(null)
	uniform.attackby(idf_armor, H)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/m24/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing/m24(null)
	uniform.attackby(web, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Hezbollah! Provide your squad with accurate fire.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/idf/lmg
	title = "Miqla"
	en_meaning = "IDF Squad LMG"
	rank_abbreviation = "Rav."

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	is_modernday = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/idf/lmg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/idf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/idf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/negev(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/green/negev(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/jericho941(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/jericho(H), slot_r_store)


	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/idf/idf_armor = new /obj/item/clothing/accessory/armor/coldwar/idf(null)
	uniform.attackby(idf_armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/american/idf/soldier
	title = "Turai"
	en_meaning = "IDF Private"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	is_coldwar = TRUE
	is_modernday = TRUE
	uses_squads = TRUE

	min_positions = 10
	max_positions = 100

/datum/job/american/idf/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/idf(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_stanag(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/idf/idf_armor = new /obj/item/clothing/accessory/armor/coldwar/idf(null)
	uniform.attackby(idf_armor, H)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/idf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE


///////////////////////////////////////////HEZBOLLAH/////////////////////////////////////////////////////

/datum/job/arab/hezbollah/squad_leader
	title = "Hezbollah Squad Leader"
	en_meaning = ""
	rank_abbreviation = "Leader"

	spawn_location = "JoinLateAR"

	is_coldwar = TRUE
	is_officer = TRUE
	is_modernday = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/arab/hezbollah/squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland/hezbollah/officer(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/insuroff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/fullwebbing = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard")
		H.f_style = pick("Full Beard","Medium Beard","Long Beard")
	H.s_tone = rand(-92,-80)
	var/new_hair = pick("Dark Brown","Black")
	var/new_eyes = pick("Dark Brown", "Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	var/hex_eyes = eye_colors[new_eyes]
	H.r_eyes = hex2num(copytext(hex_eyes, 2, 4))
	H.g_eyes = hex2num(copytext(hex_eyes, 4, 6))
	H.b_eyes = hex2num(copytext(hex_eyes, 6, 8))
	H.change_eye_color(H.r_eyes, H.g_eyes, H.b_eyes)
	H.force_update_limbs()
	H.update_body()
	H.add_note("Role", "You are an <b>[title]</b>, a squad leader for the Hezbollah in this map. Organize your brothers and repel the Israelis!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/arab/hezbollah/medic
	title = "Hezbollah Field Medic"
	en_meaning = ""
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateAR"

	is_medic = TRUE
	is_coldwar = TRUE
	is_modernday = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/arab/hezbollah/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland/hezbollah(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/military(H), slot_l_store)


	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/fullwebbing = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fullwebbing, H)

	give_random_name(H)
	H.s_tone = rand(-92,-80)
	var/new_hair = pick("Dark Brown","Black")
	var/new_eyes = pick("Dark Brown", "Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	var/hex_eyes = eye_colors[new_eyes]
	H.r_eyes = hex2num(copytext(hex_eyes, 2, 4))
	H.g_eyes = hex2num(copytext(hex_eyes, 4, 6))
	H.b_eyes = hex2num(copytext(hex_eyes, 6, 8))
	H.change_eye_color(H.r_eyes, H.g_eyes, H.b_eyes)
	H.force_update_limbs()
	H.update_body()
	H.add_note("Role", "You are an <b>[title]</b>, fighting against Israel. Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/arab/hezbollah/sniper
	title = "Hezbollah Sniper"
	en_meaning = ""
	rank_abbreviation = ""

	spawn_location = "JoinLateAR"

	is_coldwar = TRUE
	is_modernday = TRUE
	uses_squads = TRUE

	min_positions = 3
	max_positions = 12

/datum/job/arab/hezbollah/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland/hezbollah(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/mosinsniper(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/military(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/fullwebbing = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fullwebbing, H)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/mosin/sniper/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing/mosin/sniper(null)
	uniform.attackby(web, H)

	give_random_name(H)
	H.s_tone = rand(-92,-80)
	var/new_hair = pick("Dark Brown","Black")
	var/new_eyes = pick("Dark Brown", "Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	var/hex_eyes = eye_colors[new_eyes]
	H.r_eyes = hex2num(copytext(hex_eyes, 2, 4))
	H.g_eyes = hex2num(copytext(hex_eyes, 4, 6))
	H.b_eyes = hex2num(copytext(hex_eyes, 6, 8))
	H.change_eye_color(H.r_eyes, H.g_eyes, H.b_eyes)
	H.force_update_limbs()
	H.update_body()
	H.add_note("Role", "You are an <b>[title]</b>, fighting against Israel. Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE
/datum/job/arab/hezbollah/soldier
	title = "Hezbollah Soldier"
	en_meaning = ""
	rank_abbreviation = ""

	spawn_location = "JoinLateAR"

	is_coldwar = TRUE
	is_modernday = TRUE
	uses_squads = TRUE

	min_positions = 12
	max_positions = 120

/datum/job/arab/hezbollah/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland/hezbollah(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
//back
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak47(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)

		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_r_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/military(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/fullwebbing = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fullwebbing, H)
	var/obj/item/clothing/accessory/storage/sheath/knife/knnif = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(knnif, H)

	give_random_name(H)
	H.s_tone = rand(-92,-80)
	var/new_hair = pick("Dark Brown","Black")
	var/new_eyes = pick("Dark Brown", "Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	var/hex_eyes = eye_colors[new_eyes]
	H.r_eyes = hex2num(copytext(hex_eyes, 2, 4))
	H.g_eyes = hex2num(copytext(hex_eyes, 4, 6))
	H.b_eyes = hex2num(copytext(hex_eyes, 6, 8))
	H.change_eye_color(H.r_eyes, H.g_eyes, H.b_eyes)
	H.force_update_limbs()
	H.update_body()
	H.add_note("Role", "You are an <b>[title]</b>, fighting against Israel. Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE

//// SYRIAN CIVIL WAR ////

/datum/job/arab/syrian_commander
	title = "J.A. Alqayid"
	en_meaning = "Syrian Goverment Army Commander"
	rank_abbreviation = "Alq."

	spawn_location = "JoinLateSYR"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	is_officer = TRUE
	is_commander = FALSE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/arab/syrian_commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syrian_gov(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_red(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/signal/rdg2_yellow(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armor, H)

	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak101/ak105(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/command(H), slot_belt)
	web.attackby(new/obj/item/ammo_magazine/ak74, H)
	web.attackby(new/obj/item/ammo_magazine/ak74, H)
	web.attackby(new/obj/item/ammo_magazine/ak74/box, H)
	var/obj/item/clothing/accessory/armband/british/white = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(white, H)
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/rpg22(H), slot_back)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, You are in Charge of the Whole Operation, Plan carefully and lead your Forces towards victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/arab/syrian_sl
	title = "J.A. Qayid Firqa"
	en_meaning = "Syrian Goverment Army Squadleader"
	rank_abbreviation = "Q.F."

	spawn_location = "JoinLateSYR"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/arab/syrian_sl/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syrian_gov(H), slot_w_uniform)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47/emr/desert(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(armor, H)


	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/command(H), slot_belt)
	web.attackby(new/obj/item/ammo_magazine/ak74, H)
	web.attackby(new/obj/item/ammo_magazine/ak74, H)
	web.attackby(new/obj/item/ammo_magazine/ak74/box, H)
	var/obj/item/clothing/accessory/armband/british/white = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(white, H)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/rpg22(H), slot_back)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, Fighting against the Free Syrian Army. Order your men around!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/arab/syrian_soldier
	title = "J.A. Sulydir"
	en_meaning = "Syrian Goverment Army Soldier"
	rank_abbreviation = "S."

	spawn_location = "JoinLateSYR"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE

	min_positions = 12
	max_positions = 120

/datum/job/arab/syrian_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syrian_gov(H), slot_w_uniform)
//head
	var/randhead2 = rand(1,7)
	switch(randhead2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47/emr/desert(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/olivebandana(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cap(H), slot_head)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(50))
		var/obj/item/clothing/accessory/armor/coldwar/plates/tatba/green/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/tatba/green(null)
		uniform.attackby(armor, H)
	else if (prob(40))
		var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
		uniform.attackby(armor, H)
	else
		var/obj/item/clothing/accessory/armor/coldwar/plates/b2/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b2(null)
		uniform.attackby(armor, H)

	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/ak74, H)
		web.attackby(new/obj/item/ammo_magazine/ak74, H)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/ak74, H)
		web.attackby(new/obj/item/ammo_magazine/ak74, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_r_store)
		web.attackby(new/obj/item/ammo_magazine/pkm/c100, H)
		web.attackby(new/obj/item/ammo_magazine/pkm/c100, H)
	var/obj/item/clothing/accessory/armband/british/white = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, Fighting against the Free Syrian Army. Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/arab/syrian_medic
	title = "J.A. Museif Qitaliun"
	en_meaning = "Syrian Goverment Army Combat Medic"
	rank_abbreviation = "Med."

	spawn_location = "JoinLateSYR"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE
	is_medic = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/arab/syrian_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syrian_gov(H), slot_w_uniform)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/med(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armor, H)

	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	web.attackby(new/obj/item/ammo_magazine/ak74, H)
	web.attackby(new/obj/item/ammo_magazine/ak74, H)
	web.attackby(new/obj/item/ammo_magazine/ak74, H)
	var/obj/item/clothing/accessory/armband/redcross/white = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, Maintain The Health of your Squadmates. Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/arab/wagner_pmc
	title = "Wagner Group PMC"
	rank_abbreviation = "PMC"
	default_language = "Russian"
	additional_languages = list("English" = 25, "Ukrainian" = 50)
	spawn_location = "JoinLateSYR"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/arab/wagner_pmc/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_russian_name(H.gender)
	H.real_name = H.name
	H.s_tone = rand(-35,-25)

/datum/job/arab/wagner_pmc/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//under
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/russiandesert(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//head
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47/emr/desert(H), slot_head)
		var/obj/item/clothing/accessory/armor/coldwar/plates/b45/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
		uniform.attackby(armor, H)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_head)
		var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
		uniform.attackby(armor, H)
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles/ballistic(H), slot_eyes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal/modern(H), slot_eyes)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	var/obj/item/clothing/accessory/storage/webbing/khaki_webbing/web = new /obj/item/clothing/accessory/storage/webbing/khaki_webbing(null)
	uniform.attackby(web, H)
//back
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/srm(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/srm(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/srm, H)
		web.attackby(new/obj/item/ammo_magazine/srm, H)
		web.attackby(new/obj/item/ammo_magazine/srm, H)
		web.attackby(new/obj/item/ammo_magazine/srm, H)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/svd(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/svd, H)
		web.attackby(new/obj/item/ammo_magazine/svd, H)
		web.attackby(new/obj/item/ammo_magazine/svd, H)
		web.attackby(new/obj/item/ammo_magazine/svd, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/nsv_utes(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/utes(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_r_store)
		web.attackby(new/obj/item/ammo_magazine/ammo127, H)
	var/obj/item/clothing/accessory/armband/wagner/white = new /obj/item/clothing/accessory/armband/wagner(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, fighting against the Free Syrian Army. As a PMC you may act on your own, but try to follow orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE

///// SYRIAN NATIONAL ARMY/FREE SYRIAN ARMY/REBELS /////

/datum/job/american/free_syrian_army
	default_language = "Arabic"
	additional_languages = list("English" = 25, "Russian" = 5)

/datum/job/american/free_syrian_army/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_arab_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	H.s_tone = rand(-95,-60)

/datum/job/american/free_syrian_army/commander
	title = "C.C. Qayid Almutamaridin"
	en_meaning = "Free Syrian Army Commander"
	rank_abbreviation = "Q.A."

	spawn_location = "JoinLateREB"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	is_commander = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/free_syrian_army/commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syria_fsa(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_green(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/signal/m18_red(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/thickcarrier/armor = new /obj/item/clothing/accessory/armor/nomads/thickcarrier(null)
	uniform.attackby(armor, H)

	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fal(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/command(H), slot_belt)
	web.attackby(new/obj/item/ammo_magazine/fal, H)
	web.attackby(new/obj/item/ammo_magazine/fal, H)
	web.attackby(new/obj/item/ammo_magazine/m14box, H)
	var/obj/item/clothing/accessory/armband/portuguese/white = new /obj/item/clothing/accessory/armband/portuguese(null)
	uniform.attackby(white, H)
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/m72law(H), slot_back)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, you are in charge of the whole operation. Plan carefully and lead your forces towards victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/american/free_syrian_army/sl
	title = "C.C. Qayid Firqa"
	en_meaning = "Free Syrian Army Squadleader"
	rank_abbreviation = "Q.F."

	spawn_location = "JoinLateREB"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/american/free_syrian_army/sl/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syria_fsa(H), slot_w_uniform)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/lwh(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrier(null)
	uniform.attackby(armor, H)


	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/command(H), slot_belt)
	web.attackby(new/obj/item/ammo_magazine/m16, H)
	web.attackby(new/obj/item/ammo_magazine/m16, H)
	web.attackby(new/obj/item/ammo_magazine/m16/box, H)
	var/obj/item/clothing/accessory/armband/portuguese/white = new /obj/item/clothing/accessory/armband/portuguese(null)
	uniform.attackby(white, H)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/m72law(H), slot_back)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, fighting against the Syrian Arab Republic forces. Order your men around!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/american/free_syrian_army/soldier
	title = "C.C. Sulydir"
	en_meaning = "Free Syrian Army Soldier"

	spawn_location = "JoinLateREB"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE

	min_positions = 16
	max_positions = 165

/datum/job/american/free_syrian_army/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syria_fsa(H), slot_w_uniform)
//head
	var/randhead2 = rand(1,7)
	switch(randhead2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_shemagh(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_beanie(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_bandana(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/keffiyeh(H), slot_head)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/custom/custom_beanie/black(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(50))
		var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
		uniform.attackby(armor, H)
	else
		var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp(null)
		uniform.attackby(armor, H)

	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/m16, H)
		web.attackby(new/obj/item/ammo_magazine/m16, H)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a2(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/m16, H)
		web.attackby(new/obj/item/ammo_magazine/m16, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m249(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/green/m249(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_r_store)
		web.attackby(new/obj/item/ammo_magazine/m249, H)
		web.attackby(new/obj/item/ammo_magazine/m249, H)
	var/obj/item/clothing/accessory/armband/portuguese/white = new /obj/item/clothing/accessory/armband/portuguese(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, Fighting against the Syrian Goverment Forces. Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

/datum/job/american/free_syrian_army/medic
	title = "C.C. Museif Qitaliun"
	en_meaning = "Free Syrian Army Combat Medic"
	rank_abbreviation = "Med."

	spawn_location = "JoinLateREB"

	is_medic = TRUE
	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/american/free_syrian_army/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syria_fsa(H), slot_w_uniform)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/desert(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	web.attackby(new/obj/item/ammo_magazine/m16, H)
	web.attackby(new/obj/item/ammo_magazine/m16, H)
	web.attackby(new/obj/item/ammo_magazine/m16, H)
	var/obj/item/clothing/accessory/armband/redcross/white = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, Maintain The Health of your Squadmates, Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_LOW)

	return TRUE

/datum/job/american/free_syrian_army/insurgent
	title = "Milishya Suria"
	en_meaning = "Syrian Insurgent Militia"

	spawn_location = "JoinLateREB"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE

	min_positions = 16
	max_positions = 100

/datum/job/american/free_syrian_army/insurgent/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/syria_fsa(H), slot_w_uniform)
//head
	var/randhead2 = rand(1,5)
	switch(randhead2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_bandana(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_shemagh(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_beanie(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/keffiyeh(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(50))
		var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
		uniform.attackby(armor, H)

	var/obj/item/clothing/accessory/storage/webbing/light/web = new /obj/item/clothing/accessory/storage/webbing/light(null)
	uniform.attackby(web, H)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/sten(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/sten(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/sten2, H)
		web.attackby(new/obj/item/ammo_magazine/sten2, H)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/greasegun(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/greasegun(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/greasegun, H)
		web.attackby(new/obj/item/ammo_magazine/greasegun, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/ar15(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ar15(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/m72law(H), slot_back)
		web.attackby(new/obj/item/ammo_magazine/ar15, H)
		web.attackby(new/obj/item/ammo_magazine/ar15, H)
	var/obj/item/clothing/accessory/armband/portuguese/white = new /obj/item/clothing/accessory/armband/portuguese(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, Fighting against the Syrian Goverment Forces. Follow your squad leader's orders!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_LOW)

	return TRUE

/datum/job/american/delta_force
	title = "Delta Force Operator"
	rank_abbreviation = "Spc."
	default_language = "English"
	additional_languages = list("Arabic" = 60)
	spawn_location = "JoinLateREB"

	is_coldwar = FALSE
	is_modernday = FALSE
	is_syria = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/american/delta_force/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//under
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/multicam(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/lwh(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(60))
		var/obj/item/clothing/accessory/armor/nomads/pcarriertan/armor = new /obj/item/clothing/accessory/armor/nomads/pcarriertan(null)
		uniform.attackby(armor, H)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
		var/obj/item/clothing/accessory/armor/nomads/thickcarrier/armor = new /obj/item/clothing/accessory/armor/nomads/thickcarrier(null)
		uniform.attackby(armor, H)
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles/ballistic(H), slot_eyes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal/modern(H), slot_eyes)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless/army(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	var/obj/item/clothing/accessory/storage/webbing/us_vest/web = new /obj/item/clothing/accessory/storage/webbing/us_vest(null)
	uniform.attackby(web, H)
//back
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/hk417/att(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/hk(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/scarh, H)
		web.attackby(new/obj/item/ammo_magazine/scarh, H)
		web.attackby(new/obj/item/ammo_magazine/scarh, H)
		web.attackby(new/obj/item/ammo_magazine/scarh, H)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14/sniper/m21(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/m14(H), slot_belt)
		web.attackby(new/obj/item/ammo_magazine/m14, H)
		web.attackby(new/obj/item/ammo_magazine/m14, H)
		web.attackby(new/obj/item/ammo_magazine/m14, H)
		web.attackby(new/obj/item/ammo_magazine/m14box, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m249/acog(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/tacpouches/m249(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb(H), slot_r_store)
		web.attackby(new/obj/item/ammo_magazine/m249, H)
	var/obj/item/clothing/accessory/armband/portuguese/white = new /obj/item/clothing/accessory/armband/portuguese(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are an <b>[title]</b>, assisting the Free Syrian Army in its operations. As an operator you may act on your own, but try to follow given orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE
