/datum/job/kpd
	title = "KPD"
	selection_color = "#530909"
	spawn_location = "JoinLateRA"
	faction = "Station"

/datum/job/nsdap/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_german_name(H.gender)
	H.real_name = H.name

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////RFB////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/kpd/commander
	title = "RFB-Zugfuhrer"
	en_meaning = "Communist Commander"
	rank_abbreviation = "Zug"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE
	head_position = TRUE
	is_officer = TRUE
	is_squad_leader = TRUE
	is_weimar = TRUE
	is_commander = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/kpd/commander/equip(var/mob/living/carbon/human/H)
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
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/kpd/squad_leader
	title = "RFB-Gruppenfuhrer"
	en_meaning = "Communist Squad Leader"
	rank_abbreviation = "Gruf"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE
	is_officer = TRUE
	is_squad_leader = TRUE
	is_weimar = TRUE

	// AUTOBALANCE
	min_positions = 5
	max_positions = 5

/datum/job/kpd/squad_leader/equip(var/mob/living/carbon/human/H)
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

/datum/job/kpd/trooper
	title = "RFB-Mann"
	en_meaning = "Communist Trooper"
	rank_abbreviation = "Man"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRA"
	SL_check_independent = TRUE
	is_weimar = TRUE

	// AUTOBALANCE
	min_positions = 10
	max_positions = 50

/datum/job/kpd/trooper/equip(var/mob/living/carbon/human/H)
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