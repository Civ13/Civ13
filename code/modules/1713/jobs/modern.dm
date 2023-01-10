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