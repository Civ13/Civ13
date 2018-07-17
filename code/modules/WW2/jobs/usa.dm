
/datum/job/usa
	faction = "Station"

/datum/job/usa/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/usa/commander
	title = "Captain"
	en_meaning = "Company Commander"
	rank_abbreviation = "Cpt"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRACO"
	additional_languages = list( "German" = 100, "Japanese" = 75)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/usa/commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/uscapuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/usnco(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/_45(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	world << "<b><big>[H.real_name] is the [title] of the American forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is the organize the American forces and lead them to victory. You take orders from the <b>US Army High Command</b>.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/commander/get_keys()
	return list(new/obj/item/weapon/key/allied, new/obj/item/weapon/key/allied/medic, new/obj/item/weapon/key/allied/engineer,
		new/obj/item/weapon/key/allied/QM, new/obj/item/weapon/key/allied/command_intermediate, new/obj/item/weapon/key/allied/command_high)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/MP
	title = "Military Police"
	en_meaning = "MPO"
	rank_abbreviation = "1Sgt"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRAMP"
	additional_languages = list( "German" = 100, "Japanese" = 33, "Russian" = 100)
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/MP/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni_mp(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/usmphelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/usa/MP(H), slot_belt)
	var/obj/item/clothing/accessory/armband/usmp/usmp_a = new /obj/item/clothing/accessory/armband/usmp(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(usmp_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a military police officer. Keep the <b>Private</b>s in line.")
	H.give_radio()
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/MP/get_keys()
	return list(new/obj/item/weapon/key/allied, new/obj/item/weapon/key/allied/medic, new/obj/item/weapon/key/allied/engineer,
		new/obj/item/weapon/key/allied/QM, new/obj/item/weapon/key/allied/command_intermediate)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/squad_leader
	title = "Sergeant"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Sgt"
	head_position = FALSE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRASL"
	additional_languages = list( "German" = 33, "Japanese" = 10)
	is_officer = TRUE
	is_squad_leader = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 4

/datum/job/usa/squad_leader/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm_nco(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>. Your job is to lead offensive units of the US Army force according to the <b>Captain</b>'s orders.")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/squad_leader/update_character(var/mob/living/carbon/human/H)
	..()
	H.make_artillery_officer()

/datum/job/usa/squad_leader/get_keys()
	return list(new/obj/item/weapon/key/allied,
		new/obj/item/weapon/key/allied/command_intermediate,
		new/obj/item/weapon/key/allied/medic, new/obj/item/weapon/key/allied/engineer, new/obj/item/weapon/key/allied/QM)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/soldier
	title = "Private"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = "Pvt"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRA"
	allow_spies = TRUE
	SL_check_independent = TRUE
	additional_languages = list("German" = 15)

	// AUTOBALANCE
	min_positions = 5
	max_positions = 12
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni(H), slot_w_uniform)
	else
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni2(H), slot_w_uniform)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm(H), slot_head)
//	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german_basic/soldier(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a normal infantry unit. Your job is to participate in front line combat.")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_back)
	return TRUE

/datum/job/usa/soldier/get_keys()
	return list(new/obj/item/weapon/key/allied)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/usa/medic
	title = "Field Medic"
	en_meaning = "Field Medic"
	rank_abbreviation = "Cpl"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRADr"
	additional_languages = list( "English" = 75, "German" = 25)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm_med(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel_med(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/grease(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a medic. Your job is to keep the army healthy and in good condition.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/medic/get_keys()
	return list(new/obj/item/weapon/key/allied, new/obj/item/weapon/key/allied/medic)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/doctor
	title = "Army Doctor"
	en_meaning = "Doctor"
	rank_abbreviation = "1st Sgt"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRADr"
	is_nonmilitary = TRUE
	additional_languages = list( "English" = 100, "Russian" = 20, "German" = 35)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/doctor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/doctor(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel_med(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/latex(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/medical(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/toggle/labcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a doctor. Your job is to stay back at base and treat wounded that come in from the front, as well as treat prisoners and base personnel.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_HIGH)

	H.setStat("rifle", STAT_VERY_VERY_LOW)
	H.setStat("mg", STAT_VERY_VERY_LOW)
	H.setStat("smg", STAT_VERY_VERY_LOW)
	H.setStat("pistol", STAT_VERY_VERY_LOW)
	H.setStat("heavyweapon", STAT_VERY_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/doctor/get_keys()
	return list(new/obj/item/weapon/key/allied, new/obj/item/weapon/key/allied/medic)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/usa/chef
	title = "Army Cook"
	en_meaning = "Chef"
	rank_abbreviation = "Pfc"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRAChef"
	is_nonmilitary = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/usa/chef/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef/classic(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/butcher(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a front chef. Your job is to keep the US Armed Forces well fed.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/chef/get_keys()
	return list(new/obj/item/weapon/key/allied)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/flamethrower_man
	title = "Flamethrower Soldier"
	en_meaning = "Flamethrower Soldier"
	rank_abbreviation = "Pfc"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_MEDIUM
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/flamethrower_man/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/flammenwerfer(H), slot_back) //yes, i know its german. Needs coding and spriting.
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/_45(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a flamethrower unit. Your job is incinerate the enemy!")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/flamethrower_man/get_keys()
	return list(new/obj/item/weapon/key/allied)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/sniper
	title = "Sniper"
	en_meaning = "Sniper"
	rank_abbreviation = "Pfc"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRA"
	additional_languages = list( "Japanese" = 15, "German" = 25)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_MEDIUM
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/sniper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper. Your job is to assist regular troops from behind defenses.")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/sniper/get_keys()
	return list(new/obj/item/weapon/key/allied)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/heavy_weapon
	title = "Machinegunner"
	en_meaning = "Heavy Weapons Soldier"
	rank_abbreviation = "Pfc"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/heavy_weapon/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	if (prob(85))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/bar(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/usa(H), slot_back)
	// sidearm
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/_45(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a heavy weapons unit. Your job is to assist in front line combat.")
	H.give_radio()
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_VERY_HIGH)
	H.setStat("smg", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL) // misleading statname, heavyweapons soldiers are best with MGs
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/heavy_weapon/get_keys()
	return list(new/obj/item/weapon/key/allied)

///////////////////////////////////////MARINES///////////////////////////////////////////////////////////
/datum/job/usa/marines_squad_leader
	title = "Marine Sergeant"
	en_meaning = "Marines Squad Leader"
	rank_abbreviation = "Sgt"
	head_position = FALSE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateMARSL"
	additional_languages = list( "German" = 50, "Japanese" = 15)
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/usa/marines_squad_leader/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm_mar_nco(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>. Your job is to lead a squad of marines according to the <b>Captain</b>'s orders.")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/usa/marines_squad_leader/update_character(var/mob/living/carbon/human/H)
	..()
	H.make_artillery_officer()

/datum/job/usa/marines_squad_leader/get_keys()
	return list(new/obj/item/weapon/key/allied,
		new/obj/item/weapon/key/allied/command_intermediate,
		new/obj/item/weapon/key/allied/medic, new/obj/item/weapon/key/allied/engineer, new/obj/item/weapon/key/allied/QM)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/usa/marines_soldier
	title = "Marine Private"
	en_meaning = "Marines Infantry Soldier"
	rank_abbreviation = "Pvt"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateMAR"
	allow_spies = TRUE
	SL_check_independent = TRUE
	additional_languages = list("German" = 25)

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/usa/marines_soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usboots(H), slot_shoes)
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/usuni2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ushelm_mar(H), slot_head)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier specialized in amphibious operations. Your mission is to spearhead the American forces and capture the beachhead.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/bar(H), slot_back)
	return TRUE

/datum/job/usa/marines_soldier/get_keys()
	return list(new/obj/item/weapon/key/allied)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////