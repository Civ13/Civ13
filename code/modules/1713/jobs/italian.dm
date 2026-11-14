/datum/job/italian
	faction = "Human"

/datum/job/italian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_italian_name(H.gender)
	H.real_name = H.name

/datum/job/italian/officer
	title = "Tenente"
	en_meaning = "Officer"
	rank_abbreviation = "Ten."

	spawn_location = "JoinLateIT"
	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/italian/officer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/italian/officer/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/italian_officer = slot_w_uniform,
	/obj/item/clothing/gloves/thick/swat/officer = slot_gloves,
	/obj/item/weapon/gun/projectile/submachinegun/mp40/modello38 = slot_shoulder)
/datum/job/italian/officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38(null)
	uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Tenente attached to this army unit. Your job is to make sure the soldiers follow your orders. You can even discipline the officers if need be!")
	apply_job_stats(H)


	return TRUE

/datum/job/italian/squad_leader
	title = "Caposquadra"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Srg."
	allowed_maps = list(MAP_ELAIA)

	spawn_location = "JoinLateIT"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/italian/squad_leader/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/italian/squad_leader/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/italian_officer = slot_w_uniform,
	/obj/item/clothing/gloves/thick/swat/officer = slot_gloves,
	/obj/item/weapon/gun/projectile/submachinegun/mp40/modello38 = slot_shoulder)
/datum/job/italian/squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38(null)
	uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Sergeant leading a squad. Organize your group according to the <b>Tenente's</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/italian/soldier
	title = "Soldato"
	en_meaning = "Soldier"
	rank_abbreviation = ""
	allowed_maps = list(MAP_ELAIA)

	spawn_location = "JoinLateIT"

	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 999

/datum/job/italian/soldier/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/italian/soldier/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/italian = slot_w_uniform)
/datum/job/italian/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

//head
	if (prob(95))
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
	apply_job_stats(H)


	return TRUE

/datum/job/italian/medic
	title = "Medico dell Esercito"
	en_meaning = "Medic"
	rank_abbreviation = ""
	allowed_maps = list(MAP_ELAIA)

	spawn_location = "JoinLateITDoc"

	is_medic = TRUE
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 16

/datum/job/italian/medic/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/italian/medic/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/italian = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/m33_medic = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat = slot_belt)
/datum/job/italian/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a medic of the Royal Italian Army. Follow your <b>Sergeant's</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/italian/machine_gunner
	title = "Mitragliere"
	en_meaning = "Machinegunner"
	rank_abbreviation = ""
	allowed_maps = list(MAP_ELAIA)

	spawn_location = "JoinLateIT"

	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/italian/machine_gunner/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/italian/machine_gunner/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/italian = slot_w_uniform)
/datum/job/italian/machine_gunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

//head
	if (prob(95))
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
	apply_job_stats(H)


	return TRUE

/datum/job/italian/machine_gunner_assistant
	title = "Porta munizioni"
	en_meaning = "Ammo Bearer"
	rank_abbreviation = ""
	allowed_maps = list(MAP_ELAIA)

	spawn_location = "JoinLateIT"
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 6

/datum/job/italian/machine_gunner_assistant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/italian/machine_gunner_assistant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/italian = slot_w_uniform)
/datum/job/italian/machine_gunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

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
	apply_job_stats(H)


	return TRUE

/datum/job/italian/tanker
	title = "Cisterna"
	en_meaning = "Tanker"
	rank_abbreviation = ""
	allowed_maps = list(MAP_ELAIA)

	spawn_location = "JoinLateIT"
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/italian/tanker/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/italian/tanker/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/italian = slot_w_uniform,
	/obj/item/clothing/head/ww2/italian_tanker = slot_head,
	/obj/item/ammo_magazine/c762x38mmR = slot_l_store,
	/obj/item/weapon/key/italian = slot_r_store,
	/obj/item/weapon/gun/projectile/revolver/nagant_revolver = slot_l_hand)
/datum/job/italian/tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a tanker Royal Italian Army. Support the infantry in one of the armored vehicles. Follow your <b>Sergeant's</b> orders!")
	apply_job_stats(H)


	return TRUE