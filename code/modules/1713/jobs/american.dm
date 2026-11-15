/datum/job/american/captain_ww2
	title = "US Captain"
	rank_abbreviation = "Cpt."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRNCap"

	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/captain_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/captain_ww2/job_loadout = list(
	/obj/item/clothing/shoes/us_ww2_boots = slot_shoes,
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/us_cap = slot_head,
	/obj/item/weapon/gun/projectile/submachinegun/thompson = slot_shoulder,
	/obj/item/weapon/storage/belt/smallpouches/us/officer = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand,
	/obj/item/weapon/key/american = slot_r_store,
	/obj/item/weapon/radio/faction1 = slot_back)
/datum/job/american/captain_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole company. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/lieutenant_ww2
	title = "US Lieutenant"
	rank_abbreviation = "Lt."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRNBoatswain"

	is_officer = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = TRUE
	is_ardennes = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/lieutenant_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/lieutenant_ww2/job_loadout = list(
	/obj/item/clothing/shoes/us_ww2_boots = slot_shoes,
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/us_1lt = slot_head,
	/obj/item/weapon/gun/projectile/submachinegun/thompson = slot_shoulder,
	/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand,
	/obj/item/weapon/key/american = slot_r_store,
	/obj/item/weapon/radio/faction1 = slot_back)
/datum/job/american/lieutenant_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/sergeant_ww2
	title = "US Sergeant"
	rank_abbreviation = "Sgt."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRN"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE
	is_ww2 = TRUE
	is_ardennes = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/sergeant_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/sergeant_ww2/job_loadout = list(
	/obj/item/clothing/shoes/us_ww2_boots = slot_shoes,
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/us_2lt = slot_head,
	/obj/item/weapon/radio/faction1 = slot_back,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand)
/datum/job/american/sergeant_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//gun
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1carbine(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgtc(H), slot_belt)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Axis enemy and follow your CO's orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/medic_ww2
	title = "US Field Medic"
	rank_abbreviation = "Cpl."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRNSurgeon"
	is_medic = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardennes = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/medic_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/medic_ww2/job_loadout = list(
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/us_medic = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand,
	/obj/item/roller = slot_r_hand)
/datum/job/american/medic_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots/leggings(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots(H), slot_shoes)
//clothes
	equip_loadout(H)
//gun
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1carbine(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1carbine(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1carbine(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
//lamp
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and breathing!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/doctor_ww2
	title = "US Doctor"
	rank_abbreviation = "2lt."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRNSurgeon"
	is_ardennes = TRUE
	is_medic = TRUE
	is_ww2 = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/american/doctor_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/doctor_ww2/job_loadout = list(
	/obj/item/clothing/shoes/us_ww2_boots = slot_shoes,
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/doctor = slot_wear_suit,
	/obj/item/clothing/head/helmet/ww2/us_medic = slot_head,
	/obj/item/roller = slot_r_hand,
	/obj/item/stack/medical/bruise_pack/bint/medic = slot_l_store,
	/obj/item/weapon/storage/firstaid/surgery = slot_belt,
	/obj/item/weapon/storage/firstaid/combat = slot_back,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand)
/datum/job/american/doctor_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your soldiers healthy and breathing! The medics will bring you men to operate on.")
	apply_job_stats(H)
	return TRUE

/datum/job/american/sniper_ww2
	title = "US Sniper"
	rank_abbreviation = "Pfc."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardennes = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/sniper_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/sniper_ww2/job_loadout = list(
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/usm1 = slot_head)
/datum/job/american/sniper_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots/leggings(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots(H), slot_shoes)
//clothes
	equip_loadout(H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield/sniper, slot_shoulder)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
//pocket
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/us_ww2/web = new /obj/item/clothing/accessory/storage/webbing/us_ww2(null)
	uniform.attackby(web, H)
	web.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	web.attackby(new/obj/item/ammo_magazine/m3006box, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Axis! Keep the enemy off our guys and take out high value targets from a distance!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/flamethrower_ww2
	title = "Flamethrower Unit"
	rank_abbreviation = "Pfc."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardennes = TRUE

	min_positions = 1
	max_positions = 3

/datum/job/american/flamethrower_ww2/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/flamethrower_ww2/job_loadout = list(
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/gloves/thick/firefighter = slot_gloves,
	/obj/item/clothing/head/helmet/ww2/usm1 = slot_head,
	/obj/item/clothing/mask/gas/american = slot_wear_mask,
	/obj/item/weapon/flamethrower = slot_l_hand,
	/obj/item/weapon/reagent_containers/glass/flamethrower/filled = slot_back,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_belt)
/datum/job/american/flamethrower_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots/leggings(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots(H), slot_shoes)
//clothes
	equip_loadout(H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/us_ww2/webbing = new /obj/item/clothing/accessory/storage/webbing/us_ww2(null)
	uniform.attackby(webbing, H)
	webbing.attackby(new/obj/item/stack/medical/bruise_pack/bint, H)
	webbing.attackby(new/obj/item/ammo_magazine/m1911, H)
	webbing.attackby(new/obj/item/ammo_magazine/m1911, H)
	webbing.attackby(new/obj/item/ammo_magazine/m1911, H)
	webbing.attackby(new/obj/item/ammo_magazine/m1911, H)
	webbing.attackby(new/obj/item/ammo_magazine/m1911, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Axis tasked with spraying the flaming fires of hell upon your enemies. Follow your commander's orders!")
	apply_job_stats(H)

/datum/job/american/machine_gunner_ww2
	title = "US Machine Gunner"
	rank_abbreviation = "Pfc."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardennes = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/machine_gunner_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/american/machine_gunner_ww2/job_loadout = list(
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/usm1 = slot_head,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand)
/datum/job/american/machine_gunner_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots/leggings(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots(H), slot_shoes)
//clothes
	equip_loadout(H)
	if (prob(85))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/bar(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun_cleaning_kit(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/browning_lmg(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/browning(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/browning(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun_cleaning_kit(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_r_store)
//more shit
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/ammo_bearer_ww2
	title = "Ammo Bearer"
	rank_abbreviation = "Pfc."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardennes = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/american/ammo_bearer_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/american/ammo_bearer_ww2/job_loadout = list(
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/usm1 = slot_head,
	/obj/item/weapon/storage/ammo_can/browning = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand,
	/obj/item/weapon/storage/ammo_can/bar = slot_back,
	/obj/item/weapon/attachment/bayonet = slot_l_store)
/datum/job/american/ammo_bearer_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots/leggings(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots(H), slot_shoes)
//clothes
	equip_loadout(H)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/us_ww2 = new /obj/item/clothing/accessory/storage/webbing/us_ww2(null)
	uniform.attackby(us_ww2, H)
	us_ww2.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying the ammo for a light machine gun. Keep your squad gunner supplied!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/soldier_ww2
	title = "US Rifleman"
	rank_abbreviation = "Pvt."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardennes = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/american/soldier_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/soldier_ww2/job_loadout = list(
	/obj/item/clothing/under/ww2/us = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/usm1 = slot_head,
	/obj/item/weapon/gun/projectile/semiautomatic/m1garand = slot_shoulder,
	/obj/item/weapon/attachment/bayonet = slot_l_store,
	/obj/item/weapon/storage/belt/smallpouches/us_ww2 = slot_belt)
/datum/job/american/soldier_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots/leggings(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/us_ww2_boots(H), slot_shoes)

//clothes
	equip_loadout(H)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/us_ww2 = new /obj/item/clothing/accessory/storage/webbing/us_ww2(null)
	uniform.attackby(us_ww2, H)
	us_ww2.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/tanker_ww2
	title = "US Tanker"
	rank_abbreviation = "Cpl."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	is_tanker = TRUE
	is_ardennes = TRUE
	uses_squads = FALSE

	min_positions = 4
	max_positions = 12

/datum/job/american/tanker_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/tanker_ww2/job_loadout = list(
	/obj/item/clothing/shoes/us_ww2_boots = slot_shoes,
	/obj/item/clothing/under/ww2/us_tanker = slot_w_uniform,
	/obj/item/clothing/head/ww2/us_tanker = slot_head,
	/obj/item/weapon/gun/projectile/semiautomatic/m1garand = slot_shoulder,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand,
	/obj/item/weapon/key/american = slot_r_store,
	/obj/item/ammo_magazine/m1911 = slot_l_store,
	/obj/item/weapon/storage/belt/smallpouches/us_ww2 = slot_belt)
/datum/job/american/tanker_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/bomberjacketbrown(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)


	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a crewman. Follow orders and use your armor to defeat the enemy!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/mp_ww2
	title = "US Military Police"
	rank_abbreviation = "Ssgt."
	allowed_maps = list(MAP_ARDENNES, MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE
	is_ww2 = TRUE
	whitelisted = TRUE
	is_ardennes = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/american/mp_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/mp_ww2/job_loadout = list(
	/obj/item/clothing/shoes/us_ww2_boots = slot_shoes,
	/obj/item/clothing/under/ww2/us_mp = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/usm1mpblack = slot_head)
/datum/job/american/mp_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//back
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an MP. Follow orders of your CO, stay at base, and arrest the soldiers committing war crimes or not following protocol!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/chef_ww2
	title = "US Chef"
	rank_abbreviation = "Pfc."
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRNCook"

	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/chef_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/chef_ww2/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/us_shirtless = slot_w_uniform)
/datum/job/american/chef_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (map.ID == MAP_ARDENNES)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/us_coat(H), slot_wear_suit)

//back
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_l_hand)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a chef. Stay at base and cook meals for the soldiers! You can try interesting recipes in your spare time or can the food to make it last.")
	apply_job_stats(H)
	return TRUE


/datum/job/american/soldier_ww2_filipino/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_filipino_name(H.gender)
	H.real_name = H.name

/datum/job/american/soldier_ww2_filipino
	title = "Filipino Scout"
	rank_abbreviation = ""
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_OMAHA, MAP_MICROMAHA, MAP_REICHFLAKTURM, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateRN"
	is_ww2 = TRUE
	uses_squads = TRUE
	can_be_female = TRUE
	min_positions = 4
	max_positions = 24
	default_language = "Filipino"
	additional_languages = list("English" = 95, "Spanish" = 45, "Japanese" = 25)

/datum/job/american/soldier_ww2_filipino/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/soldier_ww2_filipino/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	var/pickuni = rand(1,5)
	if (pickuni == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
	if (pickuni == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_shirtless(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
	if (pickuni == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	if (pickuni == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	if (pickuni == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat/khaki(H), slot_head)
	if (pickuni == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	if (pickuni == 7)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_shirtless(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
//back
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper(H), slot_belt)
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	apply_job_stats(H)
	return TRUE
////////////////////////NAVY/////////////////////////////
/datum/job/american/sailor_ww2
	title = "US Sailor"
	rank_abbreviation = "Pvt."
	allowed_maps = list(MAP_IWO_JIMA)

	spawn_location = "JoinLateRNNavy"

	is_ww2 = TRUE
	whitelisted = TRUE

	is_navy = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/american/sailor_ww2/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/sailor_ww2/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/ww2/us_navy = slot_w_uniform,
	/obj/item/clothing/head/ww2/us_sailor_hat = slot_head,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_belt)
/datum/job/american/sailor_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a US Navy Sailor. Follow orders of your CO, stay at base, and provide covering artillery fire for the army and marines!")
	apply_job_stats(H)
	return TRUE

////////////////////////////KOREAN WAR///////////////////////////////////
/datum/job/american/captain_korean_war
	title = " US Captain"
	rank_abbreviation = "Cpt."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRNCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	min_positions = 1
	max_positions = 1

/datum/job/american/captain_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/captain_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/us_cap = slot_head,
	/obj/item/weapon/gun/projectile/submachinegun/m2carbine = slot_shoulder,
	/obj/item/weapon/storage/belt/smallpouches/us_ww2_sgtc = slot_belt,
	/obj/item/ammo_magazine/m1carbine/big = slot_l_store,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand,
	/obj/item/weapon/key/american = slot_r_store,
	/obj/item/weapon/radio/faction1 = slot_back)
/datum/job/american/captain_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole company. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/lieutenant_korean_war
	title = " US Lieutenant"
	rank_abbreviation = "Lt."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRNBoatswain"

	is_officer = TRUE
	whitelisted = TRUE
	is_radioman = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/american/lieutenant_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/lieutenant_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/us_1lt = slot_head,
	/obj/item/weapon/gun/projectile/submachinegun/thompson = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand,
	/obj/item/weapon/key/american = slot_r_store)
/datum/job/american/lieutenant_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/sergeant_korean_war
	title = " US Sergeant"
	rank_abbreviation = "Sgt."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRN"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/sergeant_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/sergeant_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/us_2lt = slot_head,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand)
/datum/job/american/sergeant_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//gun
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m2carbine(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgtc(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1carbine/big(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Chinese enemy and follow your CO's orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/medic_korean_war
	title = " US Field Medic"
	rank_abbreviation = "Cpl."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRNSurgeon"
	is_medic = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/medic_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/medic_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/us_medic = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat = slot_belt)
/datum/job/american/medic_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (prob(95))
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1carbine(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1carbine(H), slot_l_store)
		if (prob(45))
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1carbine(H), slot_shoulder)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m2carbine(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and breathing!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/doctor_korean_war
	title = " US Doctor"
	rank_abbreviation = "2lt."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRNSurgeon"

	is_medic = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/american/doctor_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/doctor_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/doctor = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/us_medic = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand)
/datum/job/american/doctor_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your soldiers healthy and breathing! The medics will bring you men to operate on.")
	apply_job_stats(H)
	return TRUE

/datum/job/american/sniper_korean_war
	title = " US Sniper"
	rank_abbreviation = "Pfc."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRN"

	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/sniper_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/sniper_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/usm1 = slot_head)
/datum/job/american/sniper_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield/sniper, slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper(H), slot_belt)
//pocket
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Chinese! Keep the enemy off our guys and take out high value targets from a distance!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/machine_gunner_korean_war
	title = " US Machine Gunner"
	rank_abbreviation = "Pfc."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRN"

	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/machine_gunner_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/american/machine_gunner_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/usm1 = slot_head,
	/obj/item/weapon/gun/projectile/pistol/m1911 = slot_l_hand)
/datum/job/american/machine_gunner_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/bar(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun_cleaning_kit(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/browning_lmg(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/browning(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/browning(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun_cleaning_kit(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/soldier_korean_war
	title = " US Rifleman"
	rank_abbreviation = "Pvt."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRN"

	uses_squads = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/american/soldier_korean_war/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/soldier_korean_war/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/usm1 = slot_head,
	/obj/item/weapon/gun/projectile/semiautomatic/m1garand = slot_shoulder,
	/obj/item/weapon/storage/belt/smallpouches/us_ww2 = slot_belt,
	/obj/item/weapon/attachment/bayonet = slot_l_store)
/datum/job/american/soldier_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/american_radioman_korea
	title = " USA Radio Operator"
	rank_abbreviation = "Cpl."
	allowed_maps = list(MAP_RETREAT)

	spawn_location = "JoinLateRN"

	is_radioman = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/american/american_radioman_korea/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/american_radioman_korea/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/us_uni_korean = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/american = slot_wear_suit,
	/obj/item/clothing/head/helmet/korean/usm1 = slot_head,
	/obj/item/weapon/storage/belt/smallpouches/us_ww2_grease = slot_belt,
	/obj/item/weapon/gun/projectile/submachinegun/greasegun = slot_l_hand,
	/obj/item/weapon/radio/faction1 = slot_back)
/datum/job/american/american_radioman_korea/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of your squad communications. Keep the line open between the <b>Squad Leader</b> and HQ!")
	apply_job_stats(H)

	return TRUE

/datum/job/american/war_correspondent
	title = "War Correspondent"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	additional_languages = list("Blugoslavian" = 100, "Redmenian" = 100)

	min_positions = 1
	max_positions = 5

/datum/job/american/war_correspondent/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_NORMAL)
/datum/job/american/war_correspondent/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new  /obj/item/clothing/under/reporter(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kevlarhelmet/press(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/hazard/yellow(src), slot_r_store)
	var/obj/item/clothing/under/uniform = slot_w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/press/press_armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/press(null)
	uniform.attackby(press_armor, src)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, take some pictures and record the chaos!")
	apply_job_stats(H)

	return TRUE