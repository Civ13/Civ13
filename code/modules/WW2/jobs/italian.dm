/datum/job/italian
	faction = "Station"

/datum/job/italian/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_italian_name(H.gender)
	H.real_name = H.name

/* Soldier */

/datum/job/italian/soldier
	title = "Soldato"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = "sdo"
	total_positions = 5
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateIT" // WIP

	// AUTOBALANCE
	min_positions = 3
	max_positions = 10
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/italian/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/italianboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/itauni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/itahelm(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/shovel/spade/russia(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/carcano(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, an Italian infantry unit assisting the Wehrmacht. Your job is to participate in front line combat.")
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
	return TRUE

/datum/job/italian/soldier/get_keys()
	return list(new/obj/item/weapon/key/italian)

/* Medic */

/datum/job/italian/medic
	title = "Medico"
	en_meaning = "Medic"
	rank_abbreviation = "mdo"
	total_positions = 1
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateIT-Medic" // WIP

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/italian/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/italianboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/itauni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/itahelm/medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/modello38(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/german(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a medic. Your job is to keep your squad healthy and in good condition.")
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

/datum/job/italian/medic/get_keys()
	return list(new/obj/item/weapon/key/italian, new/obj/item/weapon/key/italian/medic)

/* Squad Leader/Commander */

/datum/job/italian/squad_leader
	title = "Capo Squadra"
	en_meaning = "Squad Leader"
	rank_abbreviation = "cap"
	head_position = TRUE
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateIT-Officer"
	is_officer = TRUE
	is_commander = TRUE // not a squad leader despite the title
	is_petty_commander = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10

/datum/job/italian/squad_leader/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/italianboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/itauni/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/gerofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/modello38(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, an Italian squad leader assisting the Wehrmacht. Your job is to participate in front line combat.")
	H.give_radio()
	if (secret_ladder_message)
		H << "<br>[secret_ladder_message]"

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

/datum/job/italian/squad_leader/update_character(var/mob/living/carbon/human/H)
	..()
	H.make_artillery_officer()

/datum/job/italian/squad_leader/get_keys()
	return list(new/obj/item/weapon/key/italian, new/obj/item/weapon/key/italian/medic,
		new/obj/item/weapon/key/italian/command_intermediate, new/obj/item/weapon/key/italian/command_high)