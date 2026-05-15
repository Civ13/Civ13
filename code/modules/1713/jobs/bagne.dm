
/datum/job/french/bagnedirecteur
	title = "Directeur"
	en_meaning = "Camp Governor"
	rank_abbreviation = "Dir."
	spawn_location = "JoinLateFRCap"
	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_prison = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/french/bagnedirecteur/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	var/obj/item/clothing/under/civ2/UN = new /obj/item/clothing/under/civ2(H)
	H.equip_to_slot_or_del(UN, slot_w_uniform)
	var/obj/item/clothing/accessory/armband/yellow_scarf/YS = new /obj/item/clothing/accessory/armband/yellow_scarf(null)
	UN.attackby(YS,H)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/white_suit(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/abashiri_guard/french(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/m1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/melee/nightbaton/sandman(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8x27(H), slot_r_store)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/french/guard/G1 = new/obj/item/weapon/key/french/guard(null)
	var/obj/item/weapon/key/french/guard/G2 = new/obj/item/weapon/key/french/guard/max(null)
	var/obj/item/weapon/key/french/guard/G3 = new/obj/item/weapon/key/french/guard/max/command(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	KC.attackby(G3,H)
	H.equip_to_slot_or_del(KC, slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the commander of the <b>Bagne</b>. Organize your squad leaders and make sure all the prisoners are kept in their place!")
	H.setStat("strength", STAT_MAX)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MAX)
	H.setStat("dexterity", STAT_MAX)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MAX)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.verbs += /mob/living/human/proc/Sound_Alarm
	H.verbs += /mob/living/human/proc/Stop_Alarm
	return TRUE

/datum/job/french/bagneguard
	title = "Surveillant"
	en_meaning = "Camp Guard"
	rank_abbreviation = ""
	spawn_location = "JoinLateFR"
	min_positions = 10
	max_positions = 50
	is_prison = TRUE

/datum/job/french/bagneguard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/british/french(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pith(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/lebel(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/french/guard(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a guard of the Bagne, the labour camp. Keep the prisoners in place!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/french/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/french(null)
	uniform.attackby(fullwebbing, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/c8x50, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/c8x50, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/c8x50, H)
	return TRUE


/////////////////////////////////////////////////
///////////////// PRISONERS /////////////////////
/////////////////////////////////////////////////

/datum/job/civilian/prisoner/bagne_logger
	title = "Bucheron"
	en_meaning = "Prisoner"

	min_positions = 10
	max_positions = 100
	equip(var/mob/living/human/H)
		if (!H)	return FALSE
	//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
	//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/bagne_prisoner(H), slot_w_uniform)

		H.equip_to_slot_or_del(new /obj/item/weapon/prisoner_passport(H), slot_wear_id)
		var/obj/item/stack/money/francs/RUB = new /obj/item/stack/money/francs(H)
		RUB.amount = 2
		H.equip_to_slot_or_del(RUB, slot_r_store)

		H.setStat("strength", STAT_MEDIUM_HIGH)
		H.setStat("crafting", STAT_NORMAL)
		H.setStat("rifle", STAT_NORMAL)
		H.setStat("dexterity", STAT_MEDIUM_LOW)
		H.setStat("swords", STAT_NORMAL)
		H.setStat("pistol", STAT_NORMAL)
		H.setStat("bows", STAT_NORMAL)
		H.setStat("medical", STAT_MEDIUM_LOW)
		H.give_languages()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#36a52a"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "Logger armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are a <b>Logger</b>. Your job is to collect wood from the nearby forest, as instructed by the guards.")
		randrole = title
		set_prisoner(H)
		give_objective(H, "Easy")

/datum/job/civilian/prisoner/bagne_nurse
	title = "Infirmier"
	en_meaning = "Prisoner - Nurse"

	min_positions = 3
	max_positions = 30
	equip(var/mob/living/human/H)
		if (!H)	return FALSE
	//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
	//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/bagne_prisoner(H), slot_w_uniform)

		H.equip_to_slot_or_del(new /obj/item/weapon/prisoner_passport(H), slot_wear_id)
		var/obj/item/stack/money/francs/RUB = new /obj/item/stack/money/francs(H)
		RUB.amount = 2
		H.equip_to_slot_or_del(RUB, slot_r_store)

		H.setStat("strength", STAT_MEDIUM_HIGH)
		H.setStat("crafting", STAT_NORMAL)
		H.setStat("rifle", STAT_NORMAL)
		H.setStat("dexterity", STAT_MEDIUM_LOW)
		H.setStat("swords", STAT_NORMAL)
		H.setStat("pistol", STAT_NORMAL)
		H.setStat("bows", STAT_NORMAL)
		H.setStat("medical", STAT_VERY_VERY_HIGH)
		H.give_languages()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#FFFFFF"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "Nurse armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are a <b>Nurse Helper</b>. Keep other prisoners alive with the sparse supplies you have...")
		randrole = title
		set_prisoner(H)

/datum/job/civilian/prisoner/bagne_kitchen
	title = "Cuistot"
	en_meaning = "Prisoner - Kitchen"

	min_positions = 3
	max_positions = 25
	equip(var/mob/living/human/H)
		if (!H)	return FALSE
	//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
	//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/bagne_prisoner(H), slot_w_uniform)

		H.equip_to_slot_or_del(new /obj/item/weapon/prisoner_passport(H), slot_wear_id)
		var/obj/item/stack/money/francs/RUB = new /obj/item/stack/money/francs(H)
		RUB.amount = 2
		H.equip_to_slot_or_del(RUB, slot_r_store)

		H.setStat("strength", STAT_MEDIUM_HIGH)
		H.setStat("crafting", STAT_NORMAL)
		H.setStat("rifle", STAT_NORMAL)
		H.setStat("dexterity", STAT_HIGH)
		H.setStat("swords", STAT_MEDIUM_HIGH)
		H.setStat("pistol", STAT_NORMAL)
		H.setStat("bows", STAT_NORMAL)
		H.setStat("medical", STAT_MEDIUM_LOW)
		H.give_languages()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#990000"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "Kitchen armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are on <b>Kitchen Duty</b>. Your job is to manage the prisoner's stock of food (if the guards actually deliver it...) and keep everyone fed.")
		randrole = title
		set_prisoner(H)

/datum/job/civilian/prisoner/proc/set_prisoner(mob/living/human/H)
	if (istype(H.original_job, /datum/job/civilian/prisoner/bagne_kitchen) || istype(H.original_job, /datum/job/civilian/prisoner/bagne_logger) || istype(H.original_job, /datum/job/civilian/prisoner/bagne_nurse))
		var/datum/job/civilian/prisoner/PJ = H.original_job
		H.add_language("French",TRUE)
		H.remove_language("English")
		PJ.original_hair = pick("Black", "Light Brown", "Dark Brown", "Red", "Orange", "Light Blond", "Blond", "Dirty Blond", "Light Grey", "Grey")
		PJ.original_facial = PJ.original_hair
		var/hex_hair = hair_colors[PJ.original_hair]
		var/red = hex2num(copytext(hex_hair, 2, 4))
		var/green = hex2num(copytext(hex_hair, 4, 6))
		var/blue = hex2num(copytext(hex_hair, 6, 8))
		H.r_hair = red
		H.g_hair = green
		H.b_hair = blue
		H.r_facial = red
		H.g_facial = green
		H.b_facial = blue
		PJ.original_eyes = pick("Black", "Brown", "Dark Brown", "Green", "Blue")
		var/hex_eyes = eye_colors[PJ.original_eyes]
		red = hex2num(copytext(hex_eyes, 2, 4))
		green = hex2num(copytext(hex_eyes, 4, 6))
		blue = hex2num(copytext(hex_eyes, 6, 8))
		H.r_eyes = red
		H.g_eyes = green
		H.b_eyes = blue
		if (H.gender == FEMALE)
			H.h_style = pick("Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Parted","Bedhead","Shoulder-length Hair")
			H.f_style = pick("Shaved")
		else
			H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Parted","Bedhead","Shoulder-length Hair")
			H.f_style = pick("Shaved","Chinstrap","Medium Beard","Long Beard","Full Beard","Very Long Beard")
		H.update_body()

/datum/job/civilian/prisoner/proc/give_objective(mob/living/human/H, difficulty = "Easy")
	if (!H)	return FALSE
	var/obj/map_metadata/bagne13/G = null
	if (istype(map, /obj/map_metadata/bagne13))
		G = map
	else
		return FALSE
	var/multiplier = 1
	switch (difficulty)
		if ("Easy")
			multiplier = 1
		if ("Medium")
			multiplier = 2
		if ("Hard")
			multiplier = 3

	var/list/objective = pick(list("cigarettes",20), list("opium",6))
	G.prisoner_scores[H] = list(objective[1], objective[2]*multiplier, 0)
	switch(objective[1])
		if ("cigarettes")
			H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/pill/opium(H), slot_l_store)
		if ("opium")
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/fancy/cigarettes/randompack(H), slot_l_store)
	H.add_note("Objective", "Your personal objective is to collect <b>[G.prisoner_scores[H][2]] [G.prisoner_scores[H][1]]</b>. You will gain points for every item you stash in a hidden stash around the prison camp.")