/datum/job/soviet
	faction = "Station"

/datum/job/soviet/give_random_name(var/mob/living/carbon/human/H)
	if (H.client && H.client.prefs)
		switch (H.client.prefs.soviet_ethnicity)
			if (RUSSIAN)
				H.name = H.species.get_random_russian_name(H.gender)
			if (UKRAINIAN)
				H.name = H.species.get_random_ukrainian_name(H.gender)
			if (POLISH)
				H.name = H.species.get_random_polish_name(H.gender)
	else
		H.name = H.species.get_random_russian_name(H.gender)
	H.real_name = H.name

/datum/job/soviet/commander
	title = "Kapitan"
	en_meaning = "Company Commander"
	rank_abbreviation = "Kpt"
	head_position = TRUE
	selection_color = "#530909"
	spawn_location = "JoinLateRACO"
	additional_languages = list( "German" = 100, "Ukrainian" = 50 )
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/soviet/commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/sovofficercap(H), slot_head)
	if (istype(H, /mob/living/carbon/human/megastalin))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver/gibber(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_hand)
	spawn (5) // after we have our name
		if (!istype(H, /mob/living/carbon/human/megastalin))
			if (!istype(get_area(H), /area/prishtina/admin))
				world << "<b><big>[H.real_name] is the [title] of the Soviet forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is the organize the Russian forces and lead them to victory. You take orders from the <b>Soviet High Command</b>.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/soviet/commander/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/medic, new/obj/item/weapon/key/soviet/engineer,
		new/obj/item/weapon/key/soviet/QM, new/obj/item/weapon/key/soviet/command_intermediate, new/obj/item/weapon/key/soviet/command_high, new/obj/item/weapon/key/soviet/bunker_doors)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/XO
	title = "Starshiy Leytenant"
	en_meaning = "Company Executive Officer"
	rank_abbreviation = "StLy"
	head_position = FALSE
	selection_color = "#530909"
	spawn_location = "JoinLateRAXO"
	additional_languages = list( "German" = 100, "Ukrainian" = 50 )
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_MEDIUM

/datum/job/soviet/XO/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/sovofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_hand)
	H.add_note("Role", "You are a <b>[title]</b>, the second-in-command of the Russian forces. Your job is to take orders from the <b>Commandir</b> and coordinate with squad leaders.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/soviet/XO/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/medic, new/obj/item/weapon/key/soviet/engineer,
		new/obj/item/weapon/key/soviet/QM, new/obj/item/weapon/key/soviet/command_intermediate, new/obj/item/weapon/key/soviet/command_high, new/obj/item/weapon/key/soviet/bunker_doors)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/staff_officer
	title = "Leytenant"
	en_meaning = "Platoon Officer"
	rank_abbreviation = "Lyt"
	head_position = FALSE
	selection_color = "#530909"
	spawn_location = "JoinLateRASO"
	additional_languages = list( "German" = 100, "Ukrainian" = 50 )
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_HIGH
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/staff_officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/sovofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_hand)
	H.add_note("Role", "You are a <b>[title]</b>, one of the vice-commanders of the Russian forces. Your job is to take orders from the <b>Commandir</b> and coordinate with squad leaders.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/soviet/staff_officer/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/medic, new/obj/item/weapon/key/soviet/engineer,
		new/obj/item/weapon/key/soviet/QM, new/obj/item/weapon/key/soviet/command_intermediate, new/obj/item/weapon/key/soviet/command_high, new/obj/item/weapon/key/soviet/bunker_doors)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/MP
	title = "Voyennaya Politsiya"
	en_meaning = "MPO"
	rank_abbreviation = "Srg"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRAMP"
	additional_languages = list( "German" = 100, "Ukrainian" = 33 )
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/MP/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/MP(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm/MP(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/soviet/MP(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a military police officer. Keep the <b>Soldat</b>en in line.")
	H.give_radio()
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_VERY_LOW)
	H.setStat("smg", STAT_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/soviet/MP/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/medic, new/obj/item/weapon/key/soviet/engineer,
		new/obj/item/weapon/key/soviet/QM, new/obj/item/weapon/key/soviet/command_intermediate)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/soviet/squad_leader
	title = "Starshiy Serzhant"
	en_meaning = "Platoon 2IC"
	rank_abbreviation = "Srg"
	head_position = FALSE
	selection_color = "#770e0e"
	spawn_location = "JoinLateRASL"
	additional_languages = list( "German" = 33 )
	is_officer = TRUE
	is_squad_leader = TRUE
	SL_check_independent = TRUE


	// AUTOBALANCE
	min_positions = 4
	max_positions = 4

/datum/job/soviet/squad_leader/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/sovofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_hand)
	H.add_note("Role", "You are a <b>[title]</b>. Your job is to lead offensive units of the Russian force according to the <b>Commandir</b>'s and the <b>Ofitser</b>'s orders.")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/soviet/squad_leader/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/command_intermediate,
	    new/obj/item/weapon/key/soviet/bunker_doors, new/obj/item/weapon/key/soviet/medic,
	      new/obj/item/weapon/key/soviet/engineer, new/obj/item/weapon/key/soviet/QM)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/medic
	title = "Sanitar"
	en_meaning = "Medic"
	rank_abbreviation = "Efr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRAMedic"
	additional_languages = list( "German" = 100, "Ukrainian" = 50, "Italian" = 25)
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm/medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/soviet(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_r_hand)
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

/datum/job/soviet/medic/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/medic)

/datum/job/soviet/doctor
	title = "Doktor"
	en_meaning = "Doctor"
	rank_abbreviation = "2lt"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRADr"
	is_nonmilitary = TRUE
	additional_languages = list( "German" = 100, "Ukrainian" = 50 )
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/doctor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/doctor(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel_med(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/latex(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/medical(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/toggle/labcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_l_hand)
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

/datum/job/soviet/doctor/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/medic)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/sniper
	title = "Snaiper"
	en_meaning = "Sniper"
	rank_abbreviation = "Efr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_MEDIUM
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/sniper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_back)
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

/datum/job/soviet/sniper/get_keys()
	return list(new/obj/item/weapon/key/soviet)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/engineer
	title = "Boyevoy Saper"
	en_meaning = "Engineer"
	rank_abbreviation = "Efr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRAEng"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 4
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/engineer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/industrial(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/combat(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shovel/spade/russia(H), slot_belt)
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

/datum/job/soviet/engineer/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/engineer)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/heavy_weapon
	title = "Pulemetchik"
	en_meaning = "Heavy Weapons Operator"
	rank_abbreviation = "Efr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/heavy_weapon/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/soviet(H), slot_back)
	// sidearm
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tokarev(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a heavy weapons unit. Your job is to assist normal <b>Soldat</b>i in front line combat.")
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

/datum/job/soviet/heavy_weapon/get_keys()
	return list(new/obj/item/weapon/key/soviet)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/soldier
	title = "Sovietsky Soldat"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = "Kras"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	allow_spies = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 5
	max_positions = 12
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/soviet_basic/soldier(H), slot_belt)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svt(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_back)

	return TRUE

/datum/job/soviet/soldier/get_keys()
	return list(new/obj/item/weapon/key/soviet)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
/datum/job/soviet/dogmaster
	title = "Dressirovshchik"
	en_meaning = "Dog Trainer"
	rank_abbreviation = "MlSr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	allow_spies = TRUE

/datum/job/soviet/dogmaster/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, the master of the dogs.")
	H << "<span class = 'warning'>See your notes for dog commands.")

	H.add_memory("As a Dressirovshchik, you have access to a number of dog commands. To use them, simply shout! them near a dog which belongs to your faction. These are listed below:")
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

/datum/job/soviet/dogmaster/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/soldat)
*/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/tankcrew
	title = "Tank-ekipazh"
	en_meaning = "Tank Crewman"
	rank_abbreviation = "Efr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	is_tankuser = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_MEDIUM

/datum/job/soviet/tankcrew/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/sovtankerhat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/sovtankeruni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_back)
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

/datum/job/soviet/tankcrew/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/command_intermediate)

/datum/job/soviet/tankcrew/specialcheck()
	for (var/obj/tank/soviet/T in tank_list)
		if (!T.admin)
			return TRUE
	return FALSE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/anti_tank_crew
	title = "Protivotankovyy Soldat"
	en_meaning = "Anti-Tank Trooper"
	rank_abbreviation = "Kras"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 2
	player_threshold = PLAYER_THRESHOLD_MEDIUM

/datum/job/soviet/anti_tank_crew/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/heavy/ptrd(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/soviet/anti_tank_crew(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tokarev(H), slot_r_store)
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

/datum/job/soviet/anti_tank_crew/get_keys()
	return list(new/obj/item/weapon/key/soviet)

/datum/job/soviet/anti_tank_crew/specialcheck()
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
/datum/job/soviet/guard
	title = "Gvardeyec"
	en_meaning = "Guard"
	rank_abbreviation = "Efr"
	selection_color = "#a8b800"
	spawn_location = "JoinLateRA"
	additional_languages = list( "German" = 100 )
	is_guard = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

var/first_guard = FALSE
/datum/job/soviet/guard/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ushanka(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	if (first_guard)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/heavy/ptrd(H), slot_back)
		var/obj/item/weapon/storage/belt/security/tactical/belt = new(H)
		for (var/v in 1 to 8)
			new /obj/item/ammo_casing/a145(belt)
		H.equip_to_slot_or_del(belt, slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svt(H), slot_back)
		var/obj/item/weapon/storage/belt/security/tactical/belt = new(H)
		new /obj/item/ammo_magazine/mosin(belt)
		new /obj/item/ammo_magazine/mosin(belt)
		new /obj/item/ammo_magazine/mosin(belt)
		new /obj/item/ammo_magazine/mosin(belt)
		new /obj/item/ammo_magazine/mosin(belt)
		new /obj/item/ammo_magazine/mosin(belt)
		H.equip_to_slot_or_del(belt, slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a guard. Your job is to operate the minigun.")
	H.give_radio()
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH) // was STAT_VERY_HIGH
	H.setStat("mg", STAT_VERY_HIGH)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/soviet/guard/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/bunker_doors)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/QM
	title = "Zavhoz"
	en_meaning = "Quartermaster"
	rank_abbreviation = "Srg"
	selection_color = "#a8b800"
	spawn_location = "JoinLateRAQM"
	additional_languages = list( "German" = 100 )
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_LOW

/datum/job/soviet/QM/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/sovcap/fieldcap(H), slot_head)
	H.add_note("Role", "You are a <b>[title]</b>, a Quartermaster. Your job is to keep the army well armed and supplied.")
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

/datum/job/soviet/QM/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/QM, new/obj/item/weapon/key/soviet/bunker_doors, new/obj/item/weapon/key/soviet/command_intermediate, new/obj/item/weapon/key/soviet/engineer)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/sturmovik
	title = "Sturmovik"
	en_meaning = "Shock Trooper"
	rank_abbreviation = "Efr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	is_sturmovik = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5
	player_threshold = PLAYER_THRESHOLD_LOW
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/sturmovik/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/cn42(H), slot_wear_suit)
	H.add_note("Role", "You are a <b>[title]</b>, an elite infantry soldier. Your job is assist normal <b>Soldat</b>i in front line combat.")
	H.give_radio()

	// glorious sturmovik stats
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("engineering", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("heavyweapon", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/soviet/sturmovik/get_keys()
	return list(new/obj/item/weapon/key/soviet)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/chef
	title = "Povar"
	en_meaning = "Chef"
	rank_abbreviation = "Pov"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRAChef"
	allow_spies = TRUE
	is_nonmilitary = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/soviet/chef/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/sovhelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef/classic(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/butcher(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a front chef. Your job is to keep the Red Army well fed.")
	H.give_radio()
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

/datum/job/soviet/chef/get_keys()
	return list(new/obj/item/weapon/key/soviet)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/soviet/squad_leader_pris
	title = "Offizier Kriegsgefangener"
	en_meaning = "Officer POW"
	rank_abbreviation = "KGO"
	head_position = FALSE
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW_off"
	additional_languages = list( "German" = 100 )
	is_officer = TRUE
	SL_check_independent = TRUE
	is_prisoner = TRUE


	// AUTOBALANCE
	min_positions = 1
	max_positions = 4

/datum/job/soviet/squad_leader_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>. Your job is to lead the other prisioners and organize the escape or takeover of the prison camp.")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_LOW)
	H.setStat("engineering", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_NORMAL)
	H.setStat("smg", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE


////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/soldier_pris
	title = "Soldat Kriegsgefangener"
	en_meaning = "Soldier POW"
	rank_abbreviation = "KG"
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW"
	additional_languages = list( "German" = 33 )
	allow_spies = TRUE
	is_prisoner = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 60

/datum/job/soviet/soldier_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a captured soviet soldier. Escape the camp, coordinating with the officers present!")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_LOW)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/soviet/chef_pris
	title = "Kuechenchef Kriegsgefangener"
	en_meaning = "Chef POW"
	rank_abbreviation = "KGK"
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW_chef"
	additional_languages = list( "German" = 33 )
	allow_spies = TRUE
	SL_check_independent = TRUE
	is_prisoner = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 8

/datum/job/soviet/chef_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef/classic(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/armband/chef_pris(H), slot_l_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a captured soviet chef. Escape the camp, but first keep your comrades well fed!")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_LOW)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_VERY_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE


////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/medic_pris
	title = "Sanitär Kriegsgefangener"
	en_meaning = "Medic POW"
	rank_abbreviation = "KGS"
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW_med"
	additional_languages = list( "German" = 100 )
	allow_spies = TRUE
	SL_check_independent = TRUE
	is_prisoner = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 8

/datum/job/soviet/medic_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/surgical(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/latex(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/armband/med_pris(H), slot_l_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a captured soviet field medic. Escape the camp, but first keep your comrades healthy!")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_LOW)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/janitor_pris
	title = "Hausmeister Kriegsgefangener"
	en_meaning = "Janitor POW"
	rank_abbreviation = "KG"
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW_jan"
	additional_languages = list( "German" = 33 )
	allow_spies = TRUE
	is_prisoner = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 60

/datum/job/soviet/janitor_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/armband/jan_pris(H), slot_l_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a captured soviet soldier. Your job is to keep the camp clean. Escape the camp, coordinating with the officers present!")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_LOW)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/miner_pris
	title = "Bergarbeiter Kriegsgefangener"
	en_meaning = "Miner POW"
	rank_abbreviation = "KG"
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW_min"
	additional_languages = list( "German" = 33 )
	allow_spies = TRUE
	is_prisoner = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 60

/datum/job/soviet/miner_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/armband/min_pris(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/brown(H), slot_gloves)
	H.add_note("Role", "You are a <b>[title]</b>, a captured soviet soldier. Your job is to work in the mines. Escape the camp, coordinating with the officers present!")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/soviet/collaborator_pris
	title = "Hilfswillinge"
	en_meaning = "Collaborator POW"
	rank_abbreviation = "KG"
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW_col"
	additional_languages = list( "German" = 100 )
	allow_spies = TRUE
	is_prisoner = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 60

/datum/job/soviet/collaborator_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/armband/col_pris(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/money(H), slot_r_store)
//	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/MP/german(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret(H), slot_head)
	H.add_note("Role", "You are a <b>[title]</b>, a captured soviet soldier who is collaborating with the Germans. Help the guards keep the order in the camp, but be careful about your comrades!")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/penal_pris
	title = "Kriminal Kriegsgefangener"
	en_meaning = "Criminal POW <b>*</b>"
	rank_abbreviation = "Krim"
	selection_color = "#770e0e"
	spawn_location = "JoinLatePOW"
	additional_languages = list( "German" = 100 )
	allow_spies = TRUE
	is_prisoner = TRUE
	SL_check_independent = TRUE
	blacklisted = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 60

/datum/job/soviet/penal_pris/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
	H.add_note("Role", "You are a <b>[title]</b>, the lowest scum of the POW Camp. You were a criminal before being captured by the Germans, so don't expect to be well treated by either the other POWs or the guards. You will be asked to do the worst jobs, like dragging bodies.")
	H.add_note("Rules", "ATTENTION! This is a <b>HIGH-ROLEPLAY</b> map! <b>DO NOT</b> start attacking the guards without a reason, and act reallisticaly. If you do not want to play in a HIGH RP gamemode, please leave. Your objective is to escape and reach one of the corners of the map. Dig tunnels, destroy the fence, and do anything to escape, but be realistic.")
	H.setStat("strength", STAT_LOW)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_LOW)
	H.setStat("smg", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("heavyweapon", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("shotgun", STAT_LOW)
	return TRUE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////Penal Battalion/////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/penal
	title = "Shtrafbat Soldat"
	en_meaning = "Penal Unit Soldier <b>*</b>"
	rank_abbreviation = "Shtr"
	selection_color = "#770e0e"
	spawn_location = "JoinLateRA"
	allow_spies = TRUE
	SL_check_independent = TRUE
	blacklisted = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 6 //we do not want too many of these guys
	scale_to_players = PLAYER_THRESHOLD_HIGHEST

/datum/job/soviet/penal/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/sovcap/fieldcap2(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/wirecutters(H), slot_l_hand)

	var/obj/item/clothing/accessory/armband/penal_sov/penal_sov_a = new /obj/item/clothing/accessory/armband/penal_sov(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(penal_sov_a, H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/shovel/spade/russia(H), slot_belt)
	return TRUE

/datum/job/soviet/penal/get_keys()
	return list(new/obj/item/weapon/key/soviet)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////NKVD Officer///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/soviet/NKVD
	title = "NKVD Leytenant"
	en_meaning = "Senior MP Officer"
	rank_abbreviation = "Lyt"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRAMP"
	additional_languages = list( "German" = 100, "Ukrainian" = 100 )
	is_officer = TRUE
	super_whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/soviet/NKVD/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/sovuni/nkvduni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/NKVDcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/soviet/MP(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the Soviet Comissariat for Internal Affairs. You are responsible for keeping the order within the Red Army, and assuring the political education of the troops. Even tough you aren't the highest ranked officer present, you are able to discipline and punish even the Kapitan.")
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

///datum/job/german/NKVD/update_character(var/mob/living/carbon/human/H)
//	..()
//	H.make_senior_mp()

/datum/job/soviet/NKVD/get_keys()
	return list(new/obj/item/weapon/key/soviet, new/obj/item/weapon/key/soviet/medic, new/obj/item/weapon/key/soviet/engineer,
		new/obj/item/weapon/key/soviet/QM, new/obj/item/weapon/key/soviet/command_intermediate)