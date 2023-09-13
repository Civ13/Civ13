/datum/job/italian
	faction = "Human"

/datum/job/italian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_italian_name(H.gender)
	H.real_name = H.name

/datum/job/italian/squad_leader
	title = "Tenente"
	en_meaning = "Officer"
	rank_abbreviation = "Ten."

	spawn_location = "JoinLateIT"
	is_officer = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/italian/squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/italian_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//head

//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/modello38(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38(null)
	uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Tenente attached to this army unit. Your job is to make sure the soldiers follow your orders. You can even discipline the officers if need be!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/italian/squad_leader
	title = "Caposquadra"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Srg."

	spawn_location = "JoinLateIT"
	is_squad_leader = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/italian/squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/italian_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//head

//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/modello38(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38(null)
	uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Sergeant leading a squad. Organize your group according to the <b>Tenente's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/italian/soldier
	title = "Soldato"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateIT"

	uses_squads = TRUE

	min_positions = 1
	max_positions = 999

/datum/job/italian/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/italian(H), slot_w_uniform)

//head
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/m33(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/carcano(H), slot_shoulder)
			if (prob(50))
				var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/carcano/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/carcano(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/carcano/assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/carcano/assault(null)
				uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/carcano(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/carcano/smoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/carcano/smoke(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/modello38(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38(null)
			uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Royal Italian Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/italian/machine_gunner
	title = "Mitragliere"
	en_meaning = "Machinegunner"
	rank_abbreviation = ""

	spawn_location = "JoinLateIT"

	uses_squads = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/italian/machine_gunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/italian(H), slot_w_uniform)

//head
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/m33(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/breda30(H), slot_shoulder)
	var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/breda30/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/breda30(null)
	uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a machinegunner of the Royal Italian Army. Follow your <b>Sergeant's</b> orders and lay down some fire!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)


	return TRUE

/datum/job/italian/machine_gunner_assistant
	title = "Porta munizioni"
	en_meaning = "Ammo Bearer"
	rank_abbreviation = ""

	spawn_location = "JoinLateIT"

	min_positions = 2
	max_positions = 6

/datum/job/italian/machine_gunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/italian(H), slot_w_uniform)

//head
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/m33(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/ammo_can/breda30(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mauser/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mauser(null)
	uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an ammo bearer of the Royal Italian Army. Provide ammo to the Machinegunner and take over if they die. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)


	return TRUE