/datum/job/polish
	faction = "Station"

/datum/job/polish/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_polish_name(H.gender)
	H.real_name = H.name
	default_language = "Polish"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////PARTISANS////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/polish
	faction = "Station"

/datum/job/polish/soldier
	title = "Polish Partisan"
	selection_color = "#530909"
	spawn_location = "JoinLatePartisan"
	SL_check_independent = TRUE
	is_partisan = TRUE


	// AUTOBALANCE
	min_positions = 1
	max_positions = 10
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/polish/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	equip_random_polish_partisan_clothing(H)
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/combat(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/flashlight(H), slot_l_hand)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/polhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/polhelm2(H), slot_head)
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/polcoat1(H), slot_wear_suit)
	else if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/polcoat2(H), slot_wear_suit)

	H.give_radio()
	H.add_note("Role", "You are a <b>[title]</b>, a Polish partisan soldier. You take orders from the <b>Partisan Leader</b> alone.")
	if (partisan_stockpile)
		H << "<br><span class = 'warning'>You have a stockpile of weapons at [partisan_stockpile.name]. Also, there are some stockpiles of medical items and tools around the town.</span>"
	H.setStat("strength", civ_stat())
	H.setStat("engineering", civ_stat())
	H.setStat("medical", civ_stat())

	H.setStat("rifle", pick(STAT_MEDIUM_LOW, STAT_NORMAL, STAT_MEDIUM_HIGH))
	H.setStat("mg", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))
	H.setStat("smg", pick(STAT_MEDIUM_LOW, STAT_NORMAL, STAT_MEDIUM_HIGH))
	H.setStat("survival", pick(STAT_MEDIUM_HIGH, STAT_HIGH, STAT_VERY_HIGH))

	H.setStat("shotgun", pick(STAT_MEDIUM_HIGH, STAT_HIGH, STAT_VERY_HIGH))
	H.name = H.species.get_random_polish_name(H.gender)
	H.real_name = H.name
	H.default_language = "Polish"
	if (H.gender==FEMALE)
		H.name = capitalize(pick(first_names_female_polish)) + " " + capitalize(pick(polify(last_names_polish, H.gender)))
	else
		H.name = capitalize(pick(first_names_male_polish)) + " " + capitalize(pick(polify(last_names_polish, H.gender)))
	return TRUE

/datum/job/polish/commander
	title = "Polish Partisan Commander"
	is_officer = TRUE
	is_commander = TRUE
	head_position = TRUE
	SL_check_independent = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePartisanLeader"
	additional_languages = list( "Russian" = 100, "German" = 100)
	is_partisan = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
	player_threshold = PLAYER_THRESHOLD_HIGHEST

/datum/job/polish/commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	equip_random_polish_partisan_clothing(H)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/flashlight(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/stenmk2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tokarev(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/uia_cap(H), slot_head)
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/pol_officer_coat(H), slot_wear_suit)

	H.give_radio()

	H.add_note("Role", "You are a <b>[title]</b>, the leader of the Polish partisan forces in the area. Protect your men and defeat the Germans!")
	if (partisan_stockpile)
		H << "<br><span class = 'warning'>You have a stockpile of weapons at [partisan_stockpile.name]. Also, there are some stockpiles of medical items and tools around the town.</span>"
	H.setStat("strength", civ_stat())
	H.setStat("engineering", civ_stat())
	H.setStat("medical", civ_stat())

	H.setStat("rifle", pick(STAT_MEDIUM_LOW, STAT_NORMAL, STAT_MEDIUM_HIGH))
	H.setStat("mg", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))
	H.setStat("smg", pick(STAT_MEDIUM_LOW, STAT_NORMAL, STAT_MEDIUM_HIGH))
	H.setStat("survival", pick(STAT_MEDIUM_HIGH, STAT_HIGH, STAT_VERY_HIGH))

	H.setStat("shotgun", pick(STAT_MEDIUM_HIGH, STAT_HIGH, STAT_VERY_HIGH))
	return TRUE
