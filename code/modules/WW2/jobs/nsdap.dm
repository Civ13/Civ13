/datum/job/nsdap
	title = "NSDAP"
	selection_color = "#530909"
	spawn_location = "JoinLateHeer"
	faction = "Station"

/datum/job/nsdap/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_german_name(H.gender)
	H.real_name = H.name

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////NSDAP////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/nsdap/sa_scharfuhrer
	title = "SA-Scharfuhrer"
	en_meaning = "Sturmabteilung Squad Leader"
	rank_abbreviation = "Scha"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE
	is_officer = TRUE
	is_squad_leader = TRUE
	is_weimar = TRUE

	// AUTOBALANCE
	min_positions = 5
	max_positions = 5

/datum/job/nsdap/sa_scharfuhrer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/sauni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/nsdap_cap(H), slot_head)
	var/obj/item/clothing/accessory/armband/nsdap/nsdap_a = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(nsdap_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a squad leader for the SA. Coordinate with the <b>SA-Sturmfuhrer</b> and lead your squad against the Communists!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("engineering", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/nsdap/sa_mann
	title = "SA-Sturmmann"
	en_meaning = "Sturmabteilung Stormtrooper"
	rank_abbreviation = "Strm"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateHeer"
	SL_check_independent = TRUE
	is_weimar = TRUE

	// AUTOBALANCE
	min_positions = 10
	max_positions = 50

/datum/job/nsdap/sa_mann/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/geruni/sauni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/caphat/nsdap_fieldcap(H), slot_head)
	var/obj/item/clothing/accessory/armband/nsdap/nsdap_a = new /obj/item/clothing/accessory/armband/nsdap(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(nsdap_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a Sturmabteilung stormtrooper. Follow the orders of your <b>SA-Scharfuhrer</b> and attack the Communist hordes!")
	H.give_radio()
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_VERY_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("mg", STAT_MEDIUM_LOW)
	H.setStat("smg", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("heavyweapon", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_LOW)
	H.setStat("shotgun", STAT_NORMAL)
	return TRUE