
/datum/job/japanese
	faction = "Station"

/datum/job/japanese/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name
	H.s_tone = 52

/datum/job/japanese/commander
	title = "Rikugun-Tai-i"
	en_meaning = "Company Commander"
	rank_abbreviation = "Ri-tai"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerCO"
	additional_languages = list("English" = 100)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/japanese/commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japncohat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/jap_katana(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	world << "<b><big>[H.real_name] is the [title] of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is the organize the Japanese forces and lead them to victory. You take orders from the <b>Japanese High Command</b>.")
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

/datum/job/japanese/commander/get_keys()
	return list(new/obj/item/weapon/key/japan, new/obj/item/weapon/key/japan/medic, new/obj/item/weapon/key/japan/engineer,
		new/obj/item/weapon/key/japan/QM, new/obj/item/weapon/key/japan/command_intermediate, new/obj/item/weapon/key/japan/command_high)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/MP
	title = "Kenpeitai"
	en_meaning = "MPO"
	rank_abbreviation = "Gu"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerMP"
	additional_languages = list( "Russian" = 25, "English" = 100)
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/MP/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japunimp(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japmphat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/japan/MP(H), slot_belt)
	var/obj/item/clothing/accessory/armband/japanesemp/japanesemp_a = new /obj/item/clothing/accessory/armband/japanesemp(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(japanesemp_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a military police officer. Keep the <b>Nitohei</b> in line.")
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

/datum/job/japanese/MP/get_keys()
	return list(new/obj/item/weapon/key/japan, new/obj/item/weapon/key/japan/medic, new/obj/item/weapon/key/japan/engineer,
		new/obj/item/weapon/key/japan/QM, new/obj/item/weapon/key/japan/command_intermediate)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/squad_leader
	title = "Gunso"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Gu"
	head_position = FALSE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerSL"
	additional_languages = list("English" = 50)
	is_officer = TRUE
	is_squad_leader = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 4

/datum/job/japanese/squad_leader/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japncohat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/jap_katana(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>. Your job is to lead offensive units of the Japanese force according to the <b>Rikigun-Tai-i</b>'s orders.")
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

/datum/job/japanese/squad_leader/update_character(var/mob/living/carbon/human/H)
	..()
	H.make_artillery_officer()

/datum/job/japanese/squad_leader/get_keys()
	return list(new/obj/item/weapon/key/japan,
		new/obj/item/weapon/key/japan/command_intermediate,
		new/obj/item/weapon/key/japan/medic, new/obj/item/weapon/key/japan/engineer, new/obj/item/weapon/key/japan/QM)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/soldier
	title = "Nitohei"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = "Ni"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	allow_spies = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 5
	max_positions = 12
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japanhelm(H), slot_head)
	H.add_note("Role", "You are a <b>[title]</b>, a normal infantry unit. Your job is to participate in front line combat.")
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

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka(H), slot_back)
	return TRUE

/datum/job/japanese/soldier/get_keys()
	return list(new/obj/item/weapon/key/japan)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/japanese/medic
	title = "Sento-i"
	en_meaning = "Field Medic"
	rank_abbreviation = "Se"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerDr"
	additional_languages = list( "English" = 75)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni_med(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japanhelm_med(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel_med(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_r_hand)
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

/datum/job/japanese/medic/get_keys()
	return list(new/obj/item/weapon/key/japan, new/obj/item/weapon/key/japan/medic)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/doctor
	title = "Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gu"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerDr"
	is_nonmilitary = TRUE
	additional_languages = list( "English" = 100, "Russian" = 20, "German" = 35)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/doctor/equip(var/mob/living/carbon/human/H)
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

/datum/job/japanese/doctor/get_keys()
	return list(new/obj/item/weapon/key/japan, new/obj/item/weapon/key/japan/medic)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/japanese/chef
	title = "Ryorijin"
	en_meaning = "Chef"
	rank_abbreviation = "Jo"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerChef"
	is_nonmilitary = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/japanese/chef/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef/classic(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japanhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/butcher(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a front chef. Your job is to keep the Imperial Japanese Army well fed.")
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

/datum/job/japanese/chef/get_keys()
	return list(new/obj/item/weapon/key/japan)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/flamethrower_man
	title = "Kaen Hosha-ki no Heishi"
	en_meaning = "Flamethrower Soldier"
	rank_abbreviation = "Jo"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_MEDIUM
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/flamethrower_man/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japanhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/flammenwerfer(H), slot_back) //yes, i know its german. Needs coding and spriting.
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_belt)
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

/datum/job/japanese/flamethrower_man/get_keys()
	return list(new/obj/item/weapon/key/japan)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/sniper
	title = "Senmeina Hito"
	en_meaning = "Sniper"
	rank_abbreviation = "Jo"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	additional_languages = list( "English" = 15)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_MEDIUM
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/sniper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japanhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka(H), slot_back)
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

/datum/job/japanese/sniper/get_keys()
	return list(new/obj/item/weapon/key/japan)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/heavy_weapon
	title = "Taiho"
	en_meaning = "Heavy Weapons Soldier"
	rank_abbreviation = "Jo"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/heavy_weapon/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/japanhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/type99(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/japan(H), slot_back)
	// sidearm
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_belt)
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

/datum/job/japanese/heavy_weapon/get_keys()
	return list(new/obj/item/weapon/key/japan)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////Penal Battalion/////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/penal
	title = "Kamikaze"
	en_meaning = "Kamikaze Suicide Bomber <b>*</b>"
	rank_abbreviation = "Ni"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	allow_spies = TRUE
	SL_check_independent = TRUE
	blacklisted = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 12 //we do not want too many of these guys
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/japanese/penal/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japanesebandana(H), slot_head)

	H.add_note("Role", "You are a <b>[title]</b>, a disgraced soldier serving as a Kamikaze suicide bomber. You are stripped of your ranks, and even below the average Nitohei. Your mission is to charge the enemy and blow yourself up, returning honor to your family!")
//	H.give_radio() no radio for criminals!
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_MEDIUM_LOW)

// no weapons! only a suicide bomb and a katana
	H.equip_to_slot_or_del(new/obj/item/weapon/grenade/explosive/kamikaze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/jap_katana(H), slot_back)
	return TRUE

/datum/job/japanese/penal/get_keys()
	return list(new/obj/item/weapon/key/japan)