#define GERMAN_CO_TITLE "Hauptmann"
#define GERMAN_XO_TITLE "Oberleutnant"
#define GERMAN_SO_TITLE "Leutnant"
#define GERMAN_QM_TITLE "Frachtoffizier"
#define GERMAN_TO_TITLE "Dirigent" // train officer
#define GERMAN_SL_TITLE "Gruppenfuhrer"
#define GERMAN_AO_TITLE "Kanonier" // arty officer

/datum/job/german
	faction = "Station"

/datum/job/german/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_german_name(H.gender)
	H.real_name = H.name

// special event role
/datum/job/german/oberstleutnant
	title = "Oberstleutnant"
	en_meaning = "Oberstleutnant"
	rank_abbreviation = "obst"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerCO"
	faction = "Not Station"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 50, "Italian" = 100)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/german/oberstleutnant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/general(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	if (istype(H, /mob/living/carbon/human/mechahitler))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger/gibber(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	spawn (5) // after we have our name
		if (!istype(H, /mob/living/carbon/human/mechahitler))
			if (!istype(get_area(H), /area/prishtina/admin))
				world << "<b><big>[H.real_name] is the [title] of the German forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, a high-ranking officer who has come to inspect the front. You take orders from the <b>German High Command</b>.")
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

/datum/job/german/oberstleutnant/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high, new/obj/item/weapon/key/german/train, new/obj/item/weapon/key/german/SS)

/datum/job/german/commander
	title = GERMAN_CO_TITLE
	en_meaning = "Company Commander"
	rank_abbreviation = "hptm"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerCO"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 50, "Italian" = 100)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/german/commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	if (istype(H, /mob/living/carbon/human/mechahitler))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger/gibber(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	spawn (5) // after we have our name
		if (!istype(H, /mob/living/carbon/human/mechahitler))
			if (!istype(get_area(H), /area/prishtina/admin))
				world << "<b><big>[H.real_name] is the [title] of the German forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is the organize the German forces and lead them to victory, while working alongside the <b>SS-Untersharffuhrer</b>. You take orders from the <b>German High Command</b>.")
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

/datum/job/german/commander/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high, new/obj/item/weapon/key/german/train, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/XO
	title = GERMAN_XO_TITLE
	en_meaning = "Company XO"
	rank_abbreviation = "olt"
	head_position = FALSE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerXO"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 50, "Italian" = 100)
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_MEDIUM

/datum/job/german/XO/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, the XO of the German forces. Your job is to take orders from the <b>Hauptmann</b> and coordinate with squad leaders.")
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

/datum/job/german/XO/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high, new/obj/item/weapon/key/german/train, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/staff_officer
	title = GERMAN_SO_TITLE
	en_meaning = "Platoon Officer"
	rank_abbreviation = "lt"
	head_position = FALSE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerSO"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 50, "Italian" = 100)
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_HIGH
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/staff_officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, one of the vice-commanders of the German forces. Your job is to take orders from the <b>Hauptmann</b> and coordinate with squad leaders.")
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

/datum/job/german/staff_officer/update_character(var/mob/living/carbon/human/H)
	..()
	H.make_artillery_officer()

/datum/job/german/staff_officer/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high, new/obj/item/weapon/key/german/train)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/MP
	title = "Militärpolizei"
	en_meaning = "MPO"
	rank_abbreviation = "uffz"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerMP"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 33, "Italian" = 100)
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/MP/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/MP(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/MP(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/MP(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a military police officer. Keep the <b>Soldat</b>en in line.")
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

/datum/job/german/MP/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/train)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/squad_leader
	title = GERMAN_SL_TITLE
	en_meaning = "Platoon 2IC"
	rank_abbreviation = "uffz"
	head_position = FALSE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerSL"
	additional_languages = list( "Russian" = 33, "Italian" = 50)
	is_officer = TRUE
	is_squad_leader = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 4

/datum/job/german/squad_leader/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>. Your job is to lead offensive units of the German force according to the <b>Hauptmann</b>'s and <b>Stabsoffizier</b>en's orders.")
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

/datum/job/german/squad_leader/update_character(var/mob/living/carbon/human/H)
	..()
	H.make_artillery_officer()

/datum/job/german/squad_leader/get_keys()
	return list(new/obj/item/weapon/key/german,
		new/obj/item/weapon/key/german/command_intermediate,
		new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer, new/obj/item/weapon/key/german/QM)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/medic
	title = "Sanitäter"
	en_meaning = "Field Medic"
	rank_abbreviation = "oGftr"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 25, "Italian" = 50)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/german(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_r_hand)
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

/datum/job/german/medic/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic)

/datum/job/german/doctor
	title = "Medizinier"
	en_meaning = "Doctor"
	rank_abbreviation = "uffz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerDr"
	is_nonmilitary = TRUE
	additional_languages = list( "Russian" = 100, "Ukrainian" = 50, "Italian" = 100)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/doctor/equip(var/mob/living/carbon/human/H)
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

/datum/job/german/doctor/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/flamethrower_man
	title = "Flammenwerfersoldat"
	en_meaning = "Flamethrower Soldier"
	rank_abbreviation = "gftr"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_MEDIUM
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/flamethrower_man/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/flammenwerfer(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_belt)
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

/datum/job/german/flamethrower_man/get_keys()
	return list(new/obj/item/weapon/key/german)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/sniper
	title = "Scharfschütze"
	en_meaning = "Sniper"
	rank_abbreviation = "gftr"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_MEDIUM
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/sniper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper. Your job is to assist normal <b>Soldat</b> from behind defenses.")
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

/datum/job/german/sniper/get_keys()
	return list(new/obj/item/weapon/key/german)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/engineer
	title = "Pionier"
	en_meaning = "Engineer"
	rank_abbreviation = "gftr"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 4
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/engineer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/german(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/combat(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shovel/spade/german(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, an engineer. Your job is to build forward defenses.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/engineer/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/engineer)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/heavy_weapon
	title = "Maschinengewehrschütze"
	en_meaning = "Heavy Weapons Soldier"
	rank_abbreviation = "oGftr"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/heavy_weapon/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/mg34(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/german(H), slot_back)
	// sidearm
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a heavy weapons unit. Your job is to assist normal <b>Soldat</b>en in front line combat.")
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

/datum/job/german/heavy_weapon/get_keys()
	return list(new/obj/item/weapon/key/german)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/soldier
	title = "Soldat"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = "schtz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	allow_spies = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 5
	max_positions = 12
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german_basic/soldier(H), slot_belt)
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
	if (prob(8))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	return TRUE

/datum/job/german/soldier/get_keys()
	return list(new/obj/item/weapon/key/german)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*/datum/job/german/dogmaster
	title = "Hunden Trainer"
	en_meaning = "Dog Trainer"
	rank_abbreviation = "gftr"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	allow_spies = TRUE

/datum/job/german/dogmaster/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	H << "You are a <b>[title]</b>, the master of the dogs."
	H << "<span class = 'warning'>See your notes for dog commands."

	H.add_memory("As a Hunden Trainer, you have access to a number of dog commands. To use them, simply shout! them near a dog which belongs to your faction. These are listed below:")
	H.add_memory("")
	H.add_memory("attack! - attack armed enemies.")
	H.add_memory("kill! - kill armed or unarmed enemies.")
	H.add_memory("guard! - attack enemies who come near us.")
	H.add_memory("patrol! - start patrolling.")
	H.add_memory("stop patrolling! - stop patrolling.")
	H.add_memory("be passive! - only attack in self defense.")
	H.add_memory("stop everything! - stop patrolling and be passive.")
	H.add_memory("follow! - follow me.")
	H.add_memory("stop following! - stop following whoever you're following.")
	H.add_memory("prioritize {following/attacking}! - tells the dog if it should stop following you when it finds a target to attack.")
	H.add_memory("")
	H.add_memory("Some commands overlap. There are three categories of commands: attack modes, patrol modes, and follow modes. Each type of command can be used in tandem with commands of the other types.")
	H.add_memory("")
	H.memory()
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/german/dogmaster/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/soldat)
*/
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/tankcrew
	title = "Panzerbesatzung"
	en_meaning = "Tank Crewman"
	rank_abbreviation = "gftr"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	is_tankuser = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_MEDIUM

/datum/job/german/tankcrew/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gertankeruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gertankerhat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a tank crewman. Your job is to work with another crewman to operate a tank.")
	H.give_radio()
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/tankcrew/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/command_intermediate)

/datum/job/german/tankcrew/specialcheck()
	for (var/obj/tank/german/T in tank_list)
		if (!T.admin)
			return TRUE
	return FALSE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/anti_tank_crew
	title = "Panzer-Soldat"
	en_meaning = "Anti Tank Soldier"
	rank_abbreviation = "schtz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_MEDIUM

/datum/job/german/anti_tank_crew/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/heavy/ptrd(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/anti_tank_crew, slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, an anti-tank infantry unit. Your job is to destroy enemy tanks.")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/anti_tank_crew/get_keys()
	return list(new/obj/item/weapon/key/german)

/datum/job/german/anti_tank_crew/specialcheck()
	for (var/obj/tank/soviet/T in tank_list)
		if (!T.admin)
			return TRUE
	return FALSE

var/first_fallschirm = TRUE

/datum/job/german/paratrooper
	title = "Fallschirmjäger"
	en_meaning = "Paratrooper"
	rank_abbreviation = "schtz"
	selection_color = "#4c4ca5"
	spawn_location = "Fallschirm"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 100)
//	spawn_delay = 3000
//	delayed_spawn_message = "<span class = 'danger'><big>You are parachuting behind Russian lines. You won't spawn for 5 minutes.</big>"
	is_paratrooper = TRUE
	SL_check_independent = TRUE
	var/fallschirm_spawnzone = null
	var/list/fallschirm_spawnpoints = list()

	// AUTOBALANCE
	min_positions = 3
	max_positions = 8
	player_threshold = PLAYER_THRESHOLD_HIGH
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/german/paratrooper/equip(var/mob/living/carbon/human/H)
//	spawn_delay = config.paratrooper_drop_time

	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/falluni(H), slot_w_uniform)

	var/obj/item/clothing/accessory/storage/webbing/webbing = new/obj/item/clothing/accessory/storage/webbing(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(webbing, H)

	if (first_fallschirm)
		for (var/v in 1 to 4)
			uniform.attackby(new /obj/item/ammo_magazine/mp40(null), H)
	else
		for (var/v in 1 to 4)
			uniform.attackby(new /obj/item/ammo_magazine/kar98k(null), H)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/fallsparka(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/german/paratrooper(H), slot_back)

	if (first_fallschirm)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_r_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_r_hand)

	if (first_fallschirm)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/fallofficer(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/fallsoldier(H), slot_belt)

	first_fallschirm = FALSE

	if (!fallschirm_spawnzone)
		fallschirm_spawnzone = pick(fallschirm_landmarks)
		fallschirm_landmarks = list()
		for (var/turf/T in orange(5, fallschirm_spawnzone))
			fallschirm_spawnpoints += T
		H.loc = get_turf(fallschirm_spawnzone)
	else
		H.loc = pick(fallschirm_spawnpoints)

	H.add_note("Role", "You are a <b>[title]</b>, a paratrooper. Your job is to help any other units that need assistance.")
	if (processes.paratrooper_plane)
		H << processes.paratrooper_plane.getMessage()
	H.give_radio()
	// Paratroopers are elite so they have very nicu stats - Kachnov
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_HIGH)
	H.setStat("smg", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/paratrooper/get_keys()
	return list(new/obj/item/weapon/key/german)

/datum/job/german/paratrooper/specialcheck()
	return ((fallschirm_landmarks.len + fallschirm_spawnpoints.len) && processes.paratrooper_plane.altitude > 500)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/QM
	title = GERMAN_QM_TITLE
	en_meaning = "Quartermaster"
	rank_abbreviation = "uffz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerQM"
	additional_languages = list( "Russian" = 100, "Italian" = 100 )
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_LOW

/datum/job/german/QM/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a Quartermaster. Your job is to keep the army well armed and supplied. Use a pen to sign supply requisition sheets.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/QM/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/engineer)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/artyman
	title = GERMAN_AO_TITLE
	en_meaning = "Artillery Officer"
	rank_abbreviation = "uffz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerSO"
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGH

/datum/job/german/artyman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/wrench(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, an artillery officer. Your job is to obliterate the enemy with HE and gas shell attacks.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/artyman/update_character(var/mob/living/carbon/human/H)
	..()

	H.make_artillery_officer()

/datum/job/german/artyman/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/QM)

/datum/job/german/artyman/specialcheck()
	for (var/B in artillery_list)
		if (B:loc)
			return TRUE
	return FALSE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/scout
	title = "Aufklärtrupp"
	en_meaning = "Scout"
	rank_abbreviation = "schtz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGH

/datum/job/german/scout/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a scout. Your job is to assist the <b>Kanonier</b> by getting coordinates.")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/scout/update_character(var/mob/living/carbon/human/H)
	..()

	H.make_artillery_scout()

/datum/job/german/scout/get_keys()
	return list(new/obj/item/weapon/key/german)

/datum/job/german/scout/specialcheck()
	for (var/B in artillery_list)
		if (B:loc)
			return TRUE
	return FALSE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/conductor
	title = GERMAN_TO_TITLE
	en_meaning = "Train Conductor"
	rank_abbreviation = "uffz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerSO"
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/german/conductor/train_check() // if there's no train, don't let people be conductors!
	return WW2_train_check()

/datum/job/german/conductor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a train conductor. Your job is take men to and from the front.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/conductor/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/train,
		new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/QM)

////////////////////////////////
/datum/job/german/squad_leader_ss
	title = "SS-Unterscharfuhrer"
	en_meaning = "SS Squad Leader"
	rank_abbreviation = "uscha"
	head_position = TRUE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS-Officer"
	is_SS = TRUE
	additional_languages = list( "Russian" = 50, "Italian" = 50, "Ukrainian" = 50)
	is_officer = TRUE
	is_commander = TRUE // not a squad leader despite the title
	is_petty_commander = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10

/datum/job/german/squad_leader_ss/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/stg(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a squad leader for an elite SS unit. Your job is to work alongside normal <b>Gruppenfuhrer</b>s and the <b>Hauptmann</b>, while setting your own goals.")
	H.give_radio()
	if (secret_ladder_message)
		H << "<br>[secret_ladder_message]"

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_HIGH)
	H.setStat("smg", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/squad_leader_ss/update_character(var/mob/living/carbon/human/H)
	..()

	H.make_artillery_officer()

/datum/job/german/squad_leader_ss/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/command_intermediate,
		new/obj/item/weapon/key/german/SS)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/soldier_ss
	title = "SS-Schutze"
	en_meaning = "SS Infantry Soldier"
	rank_abbreviation = "schtz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	is_SS = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 3
	max_positions = 10
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/german/soldier_ss/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/sssmock(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/sshelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier for an elite SS unit. Your job is to follow the orders of the <b>SS-Untersharffuhrer</b>.")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/soldier_ss/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/medic_ss
	title = "SS-Sanitäter"
	en_meaning = "SS Medic"
	rank_abbreviation = "schtz" // oGftr for normal medics
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	is_SS = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/german/medic_ss/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/sssmock(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/sshelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier for an elite SS unit. Your job is to follow the orders of the <b>SS-Untersharffuhrer</b>.")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/medic_ss/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/german/chef
	title = "Kuechenchef" // note: SS13 does not like ü in job titles
	en_meaning = "Chef"
	rank_abbreviation = "Kch"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerChef"
	is_nonmilitary = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/german/chef/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef/classic(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/butcher(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a front chef. Your job is to keep the Wehrmacht well fed.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/chef/get_keys()
	return list(new/obj/item/weapon/key/german)

// this is a horrible hack.
/datum/job/german/trainsystem
	title = "N/A" // makes us unchooseable
	en_meaning = "N/A"
	head_position = FALSE
	is_officer = FALSE
	is_commander = FALSE
	faction = "trainsystem"


////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////
/datum/job/german/commander_sstv
	title = "SS-TV-Hauptsturmfuhrer"
	en_meaning = "SS Camp Director"
	rank_abbreviation = "Hstf"
	head_position = TRUE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS-Officer"
	is_SS_TV = TRUE
	additional_languages = list( "Russian" = 100, "Ukrainian" = 75)
	is_officer = TRUE
	is_commander = TRUE // not a squad leader despite the title
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 15

/datum/job/german/commander_sstv/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssformalofc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/luger, slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, and this camp's director. Keep the prisioners (and the guards) in order!")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start shooting at the prisoners without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave.")
	H.give_radio()
	if (secret_ladder_message)
		H << "<br>[secret_ladder_message]"

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_HIGH)
	H.setStat("smg", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/commander_sstv/update_character(var/mob/living/carbon/human/H)
	..()

	H.make_artillery_officer()

/datum/job/german/commander_sstv/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high,
		new/obj/item/weapon/key/german/SS)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////
/datum/job/german/squad_leader_sstv
	title = "SS-TV-Unterscharfuhrer"
	en_meaning = "SS Totenkopfverbände Squad Leader"
	rank_abbreviation = "uscha"
	head_position = TRUE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS-Officer"
	is_SS_TV = TRUE
	additional_languages = list( "Russian" = 100, "Ukrainian" = 75)
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10

/datum/job/german/squad_leader_sstv/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/SSTV(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a squad leader for an elite Totenkopfverbande unit. Your job is to follow the Camp Director's orders.")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start shooting at the prisoners without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave.")
	H.give_radio()
	if (secret_ladder_message)
		H << "<br>[secret_ladder_message]"

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_HIGH)
	H.setStat("smg", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/squad_leader_sstv/update_character(var/mob/living/carbon/human/H)
	..()

	H.make_artillery_officer()

/datum/job/german/squad_leader_sstv/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/command_intermediate,
		new/obj/item/weapon/key/german/SS)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/soldier_sstv
	title = "SS-TV-Sturmmann"
	en_meaning = "SS Totenkopfverbände Soldier"
	rank_abbreviation = "strm"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	additional_languages = list( "Russian" = 40, "Ukrainian" = 20)
	is_SS_TV = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 20
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/german/soldier_sstv/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/SSTV(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier for the SS Camp management division (Totenkopfverbande). Follow the rules of your <b>SS-Untersharffuhrer</b>.")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start shooting at the prisoners without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave.")
	H.give_radio()
	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/soldier_sstv/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/medic_sstv
	title = "SS-TV-Sanitäter"
	en_meaning = "SS Totenkopfverbände Medic"
	rank_abbreviation = "rttf" // oGftr for normal medics
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	is_SS_TV = TRUE
	SL_check_independent = TRUE
	additional_languages = list( "Russian" = 60, "Ukrainian" = 25)

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/german/medic_sstv/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/SSTV(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the camp doctor. Heal your comrades first, follow the orders of the <b>SS-Untersharfuhrer</b>, and maybe help some prisioners.")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start shooting at the prisoners without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave.")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/medic_sstv/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////REICHSTAG///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/german/commander_reichstag
	title = "SS-Sturmbannfuhrer"
	en_meaning = "Commander"
	rank_abbreviation = "Stubaf"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerCO"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 50, "Italian" = 100)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_reichstag = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/german/commander_reichstag/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssformalofc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	if (istype(H, /mob/living/carbon/human/mechahitler))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger/gibber(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	spawn (5) // after we have our name
		if (!istype(H, /mob/living/carbon/human/mechahitler))
			if (!istype(get_area(H), /area/prishtina/admin))
				world << "<b><big>[H.real_name] is the commander of the German forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is the organize all the German forces and lead them to victory! You take orders from the <b>German High Command</b>.")
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

/datum/job/german/commander_reichstag/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high, new/obj/item/weapon/key/german/train, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

/datum/job/german/subcommander_reichstag
	title = "NSDAP Blockleiter"
	en_meaning = "Nazi Party Official (2nd in Command)"
	rank_abbreviation = "Bltr"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerXO"
	additional_languages = list( "Russian" = 33)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_reichstag = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/german/subcommander_reichstag/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/sauni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/nsdap_cap(H), slot_head)
	var/obj/item/clothing/accessory/armband/nsdap/nsdap_a = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(nsdap_a, H)
	spawn (5) // after we have our name
	world << "<b><big>[H.real_name] is the NSDAP Block Leader for this area!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the Nazi party official in charge of this area, adn the second in command. Coordinate with the <b>Sturmbannfuhrer</b> and uphold the values of the NSDAP!")
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

/datum/job/german/subcommander_reichstag/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high, new/obj/item/weapon/key/german/train, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/squad_leader_reichstag
	title = "Unteroffizier"
	en_meaning = "Section Leader"
	rank_abbreviation = "uffz"
	head_position = FALSE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeerSL"
	additional_languages = list( "Russian" = 75)
	is_officer = TRUE
	is_squad_leader = TRUE
	SL_check_independent = TRUE
	is_reichstag = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 4

/datum/job/german/squad_leader_reichstag/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/gerofficer(H), slot_w_uniform)
	if (prob(75))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	if (prob(85))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>. Your job is to lead a section of the German forces according to the <b>Sturmbannfuhrer</b> and <b>Blockleiter</b> orders.")
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

/datum/job/german/squad_leader_reichstag/update_character(var/mob/living/carbon/human/H)
	..()
	H.make_artillery_officer()

/datum/job/german/squad_leader_reichstag/get_keys()
	return list(new/obj/item/weapon/key/german,
		new/obj/item/weapon/key/german/command_intermediate,
		new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer, new/obj/item/weapon/key/german/QM)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/german/soldier_ss_reichstag
	title = "SS-Sturmmann"
	en_meaning = "Waffen-SS Soldier"
	rank_abbreviation = "Strm"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	is_reichstag = TRUE
	SL_check_independent = TRUE
	additional_languages = list( "Russian" = 40)
	// AUTOBALANCE
	min_positions = 2
	max_positions = 25
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/soldier_ss_reichstag/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/sssmock(H), slot_wear_suit)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/sshelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the Waffen-SS. Your job is to defend the Reichstag to the last man, no surrender!")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/soldier_ss_reichstag/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/german/paratrooper_reichstag
	title = "Fallschirmjäger Schutze"
	en_meaning = "Paratrooper Soldier"
	rank_abbreviation = "schtz"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	additional_languages = list( "Russian" = 25)
	is_reichstag = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 25
	scale_to_players = PLAYER_THRESHOLD_HIGHEST
/datum/job/german/paratrooper_reichstag/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/falluni(H), slot_w_uniform)
	var/obj/item/clothing/accessory/storage/webbing/webbing = new/obj/item/clothing/accessory/storage/webbing(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(webbing, H)
	uniform.attackby(new /obj/item/ammo_magazine/kar98k(null), H)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/fallsparka(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a paratrooper from the 9th Fallschirmjäger Division. Your job is to help any other units that need assistance.")

	H.give_radio()
	// Paratroopers are elite so they have very nicu stats - Kachnov
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_HIGH)
	H.setStat("smg", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/german/paratrooper_reichstag/get_keys()
	return list(new/obj/item/weapon/key/german)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/german/volkssturm
	title = "Volkssturmmann"
	en_meaning = "Militia"
	rank_abbreviation = "Vlkst"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	is_reichstag = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 3
	max_positions = 60
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/volkssturm/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/det/grey(H), slot_head)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/panzerfaust(H), slot_back)
	var/obj/item/clothing/accessory/armband/volkssturm/volkssturm_a = new /obj/item/clothing/accessory/armband/volkssturm(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(volkssturm_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the conscripted Volkssturm, a popular militia. Fight alongside the Wehrmacht units and defend the Reichstag!")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_VERY_LOW)
	H.setStat("smg", STAT_VERY_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_VERY_LOW)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_r_hand)
	else
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_r_hand)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_belt)
	return TRUE

/datum/job/german/volkssturm/get_keys()
	return list(new/obj/item/weapon/key/german)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/german/kriegsmarine
	title = "Matrose"
	en_meaning = "Sailor"
	rank_abbreviation = "Mat"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	is_reichstag = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 3
	max_positions = 60
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/kriegsmarine/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/kriegsmarine(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/km_cap, slot_head)

	H.add_note("Role", "You are a <b>[title]</b>, a member of the Kriegsmarine (Navy), conscripted to figbht in the pront. Fight alongside the Wehrmacht units and defend the Reichstag!")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_VERY_LOW)
	H.setStat("smg", STAT_VERY_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_VERY_LOW)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_r_hand)
	else
		if (prob(75))
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_r_hand)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_belt)
	return TRUE

/datum/job/german/kriegsmarine/get_keys()
	return list(new/obj/item/weapon/key/german)
///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/hitlerjugend
	title = "Hitlerjunge"
	en_meaning = "Hitler's Youth Member"
	rank_abbreviation = "Hj"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	is_reichstag = TRUE
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 25
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/hitlerjugend/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/hj_uni(H), slot_w_uniform)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/panzerfaust(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a 16 year old member of the Hitler's Youth. You have been conscripted to fight alongside the Volkssturm and Wehrmacht. Do your best!")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_VERY_LOW)
	H.setStat("smg", STAT_VERY_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_VERY_LOW)
	H.age=15
	H.f_style = "Shaved"
	H.h_style = "Short Hair"
	H.r_hair = 153
	H.g_hair = 102
	H.b_hair = 51
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_r_hand)
	else
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_r_hand)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_belt)
	return TRUE

/datum/job/german/hitlerjugend/get_keys()
	return list(new/obj/item/weapon/key/german)
///////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
/datum/job/german/medic_ss_reichstag
	title = "SS-Sanitäter"
	en_meaning = "SS Field Medic"
	rank_abbreviation = "rrtf" // oGftr for normal medics
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	is_reichstag = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/german/medic_ss_reichstag/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/sssmock(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/sshelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/kar98k(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a field medic of the Waffen-SS. Your job is to take care of your comrades.")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/medic_ss_reichstag/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////Penal Battalion/////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/penal
	title = "Straffbattalion Schutze"
	en_meaning = "Penal Unit Soldier <b>*</b>"
	rank_abbreviation = "Straf"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateHeer"
	allow_spies = TRUE
	SL_check_independent = TRUE
	blacklisted = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 6 //we do not want too many of these guys
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/penal/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap2(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/wirecutters(H), slot_r_hand)

	var/obj/item/clothing/accessory/armband/penal_ger/penal_ger_a = new /obj/item/clothing/accessory/armband/penal_ger(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(penal_ger_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a criminal condemned to serve in a penal military unit. You are stripped of your ranks, and even below the average Soldat. Do not expect to be given priority on food and medical attention.")
//	H.give_radio() no radio for criminals!
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_MEDIUM_LOW)

// no weapons! go beg the QM for one. You are lucky to have a shovel
	H.equip_to_slot_or_del(new /obj/item/weapon/shovel/spade/german(H), slot_belt)
	return TRUE

/datum/job/german/penal/get_keys()
	return list(new/obj/item/weapon/key/german)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////FELDJAGERKORPS///////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/FJK
	title = "Feldjägerkorps Offizier"
	en_meaning = "Senior MP Officer"
	rank_abbreviation = "Lt"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeerMP"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 100, "Italian" = 100)
	is_officer = TRUE
	super_whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1


/datum/job/german/FJK/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/MP(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/MP(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/german/MP(H), slot_belt)
	var/obj/item/clothing/accessory/armband/fjk/fjk_a = new /obj/item/clothing/accessory/armband/fjk(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fjk_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a military police officer. You are responsible for keeping the order within the Wehrmacht, and assuring the political education of the troops. Even tough you aren't the highest ranked officer present, you are able to discipline and punish even the Hauptmann and members of the SS.")
	H.give_radio()
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("mg", STAT_MEDIUM_HIGH)
	H.setStat("smg", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

///datum/job/german/FJK/update_character(var/mob/living/carbon/human/H)
//	..()
//	H.make_senior_mp()

/datum/job/german/FJK/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/train)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////SS-Sturmbrigade "Dirlewanger"/////////////////////////////////

/datum/job/german/soldier_ss_dirlewanger
	title = "SS-Dirlewanger-Sturmmann"
	en_meaning = "SS-Sturmbrigade Dirlewanger Soldier"
	rank_abbreviation = "Strm"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	SL_check_independent = TRUE
	additional_languages = list( "Russian" = 40)
	is_dirlewanger = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 25
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/soldier_ss_dirlewanger/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/sssmock(H), slot_wear_suit)
	if (prob(75))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive/stgnade(H), slot_wear_mask)
	if (prob(75))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/gerhelm/sshelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	if (prob(75))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_back)
	else
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/stg(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the SS-Sturmbrigade Dirlewanger, an anti-partisan unit operating in Soviet territory. Destroy the partisans, leave no survivors!")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/soldier_ss_dirlewanger/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/german/squad_leader_ss_dirlewanger
	title = "SS-Dirlewanger-Unterscharfuhrer"
	en_meaning = "SS-Sturmbrigade Dirlewanger Squad Leader"
	rank_abbreviation = "Uscha"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS-Officer"
	SL_check_independent = TRUE
	additional_languages = list( "Russian" = 40)
	is_officer = TRUE
	is_dirlewanger = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 8
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/squad_leader_ss_dirlewanger/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	if (prob(75))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/stg(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, of the SS-Sturmbrigade Dirlewanger, an anti-partisan unit operating in Soviet territory. Command your soldiers to victory, and eleminate the partisans!")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_HIGH)
	H.setStat("smg", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/squad_leader_ss_dirlewanger/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/command_intermediate,
		new/obj/item/weapon/key/german/SS)

//////////////////////////////////////////////////////////////////////////////
/datum/job/german/penal_ss_dirlewanger
	title = "SS-Dirlewanger-Minensuchender"
	en_meaning = "SS-Sturmbrigade Dirlewanger Mine Clearer <b>*</b>"
	rank_abbreviation = "Strm"
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateSS"
	SL_check_independent = TRUE
	additional_languages = list( "Russian" = 40)
	is_dirlewanger = TRUE
	blacklisted = TRUE
	// AUTOBALANCE
	min_positions = 8
	max_positions = 8
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/german/penal_ss_dirlewanger/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gercap/fieldcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/shovel/spade/german(H), slot_belt)
	var/obj/item/clothing/accessory/armband/penal_ger/penal_ger_c = new /obj/item/clothing/accessory/armband/penal_ger(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(penal_ger_c, H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the SS-Sturmbrigade Dirlewanger, an anti-partisan unit operating in Soviet territory. As a pardoned death row prisoner, your job is to demine the area and remove barricades!")
	H.give_radio()

	// glorious SS stats
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("survival", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/german/penal_ss_dirlewanger/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/SS)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
datum/job/german/commander_escort
	title = "SS-Standartenfuhrer"
	en_meaning = "SS Colonel"
	rank_abbreviation = "Staf"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSS-Officer"
	additional_languages = list( "Russian" = 100, "Ukrainian" = 50, "Italian" = 100)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_escort = TRUE
	is_target = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/german/commander_escort/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/ssformalofc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_hand)
	world << "<b><big>[H.real_name] is the VIP of the German forces! Germans must protect him at all costs!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>,  a Colonel of the SS. You need to report to a OKW Command Center in the Belarus, but for that you need to cross this forest filled with partisans...")
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

/datum/job/german/commander_escort/get_keys()
	return list(new/obj/item/weapon/key/german, new/obj/item/weapon/key/german/medic, new/obj/item/weapon/key/german/engineer,
		new/obj/item/weapon/key/german/QM, new/obj/item/weapon/key/german/command_intermediate, new/obj/item/weapon/key/german/command_high, new/obj/item/weapon/key/german/train, new/obj/item/weapon/key/german/SS)
