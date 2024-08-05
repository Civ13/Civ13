/obj/item/clothing/under/afghanka/cafr
	name = "cafr afghanka uniform"
	desc = "A heavily weathered Afghanka uniform with a CAFR patch on the front."
	icon_state = "cafr_afghanka_open"
	item_state = "cafr_afghanka_open"
	worn_state = "cafr_afghanka_open"

/obj/item/clothing/under/afghanka/cafr/toggle()
	set category = null
	set src in usr
	set name = "Adjust collar"
	if (type != /obj/item/clothing/under/afghanka/cafr)
		return
	else
		if(adjusted)
			worn_state = "cafr_afghanka_open"
			item_state = "cafr_afghanka_open"
			icon_state = "cafr_afghanka_open"
			item_state_slots["w_uniform"] = "cafr_afghanka_open"
			usr << "You <b>open up</b> the collar of your uniform."
			adjusted = FALSE
			update_clothing_icon()
		else if (!adjusted)
			worn_state = "cafr_afghanka_closed"
			item_state = "cafr_afghanka_closed"
			icon_state = "cafr_afghanka_closed"
			item_state_slots["w_uniform"] = "cafr_afghanka_closed"
			usr << "You <b>close up</b> the collar of your uniform."
			adjusted = TRUE
			update_clothing_icon()

/obj/item/clothing/under/cafr_newiform
	name = "cafr uniform"
	desc = "A camouflage uniform issued by the Central Asian Federal Republic."
	icon_state = "cafr_newiform"
	item_state = "cafr_newiform"
	worn_state = "cafr_newiform"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS

/obj/item/clothing/suit/storage/jacket/afghanka/cafr
	name = "cafr afghanka coat"
	desc = "An Afghanka coat made with the CAFR camouflage pattern."
	icon_state = "cafr_pattern_afghanka"
	item_state = "cafr_pattern_afghanka"
	worn_state = "cafr_pattern_afghanka"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 12, arrow = 5, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)

/datum/job/cafr
	faction = "Human"
	title = "Central Asian Federal Republic"
	rank_abbreviation = ""
	spawn_location = "JoinLateCAFR"
	uses_squads = TRUE
	squad = 0
	default_language = "Tajik"
	additional_languages = list("Kyrgyz" = 15, "Russian" = 90, "Kazakh" = 15, "Turkmen" = 15, "Uzbek" = 15, "Ukrainian" = 5, "Finnish" = 5, "Mongolian" = 5, "Polish" = 2)
	min_positions = 1
	max_positions = 999
	selection_color = "#102f44"

/datum/job/cafr/give_random_name(var/mob/living/human/H)
	switch(rand(1,3))
		if(1)
			H.name = H.species.get_random_russian_name(H.gender)
			H.real_name = H.name
		if(2)
			H.name = H.species.get_random_kazakh_name(H.gender)
			H.real_name = H.name
		if(3)
			H.name = H.species.get_random_tajik_name(H.gender)
			H.real_name = H.name

/datum/job/cafr/commander
	is_commander = TRUE
	title = "CAFR Commander"
	rank_abbreviation = "CO-Cpt."
	spawn_location = "JoinLateCAFRCpt"

/datum/job/cafr/officer
	is_commander = TRUE
	title = "CAFR Officer"
	rank_abbreviation = "XO-Lt."

/datum/job/cafr/doctor
	title = "CAFR Doctor"
	is_medic = TRUE
	rank_abbreviation = "Dr."
	spawn_location = "JoinLateCAFRDoc"

/datum/job/cafr/s1/sl
	title = "CAFR Squad 1 Squad Leader"
	squad = 1
	is_squad_leader = TRUE
	rank_abbreviation = "1-Sgt"

/datum/job/cafr/s1/pvt
	title = "CAFR Squad 1 Private"
	squad = 1
	rank_abbreviation = "1-Pvt"

/datum/job/cafr/s1/corpsman
	title = "CAFR Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
	rank_abbreviation = "1-Corpsman"

/datum/job/cafr/s1/machinegunner
	title = "CAFR Squad 1 Machinegunner"
	squad = 1
	rank_abbreviation = "1-MG"

/datum/job/cafr/s2/sl
	title = "CAFR Squad 2 Squad Leader"
	squad = 2
	is_squad_leader = TRUE
	rank_abbreviation = "2-Sgt"

/datum/job/cafr/s2/pvt
	title = "CAFR Squad 2 Private"
	squad = 2
	rank_abbreviation = "2-Pvt"

/datum/job/cafr/s2/corpsman
	title = "CAFR Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
	rank_abbreviation = "2-Corpsman"

/datum/job/cafr/s2/machinegunner
	title = "CAFR Squad 2 Machinegunner"
	squad = 2
	rank_abbreviation = "2-MG"

/datum/job/cafr/s3/sl
	title = "CAFR Squad 3 Squad Leader"
	squad = 3
	is_squad_leader = TRUE
	rank_abbreviation = "3-Sgt"

/datum/job/cafr/s3/pvt
	title = "CAFR Squad 3 Private"
	squad = 3
	rank_abbreviation = "3-Pvt"

/datum/job/cafr/s3/corpsman
	title = "CAFR Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
	rank_abbreviation = "3-Corpsman"

/datum/job/cafr/s3/machinegunner
	title = "CAFR Squad 3 Machinegunner"
	squad = 3
	rank_abbreviation = "3-MG"

/datum/job/cafr/recon
	title = "CAFR Recon"
	squad = 4
	rank_abbreviation = "4-Recon"

/datum/job/cafr/armored/sl
	title = "CAFR Armored Squad Leader"
	squad = 5
	is_squad_leader = TRUE
	rank_abbreviation = "5-Tank Sgt"

/datum/job/cafr/armored/crew
	title = "CAFR Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"

/datum/job/cafr/at
	title = "CAFR Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"

/datum/job/cafr/engineer
	title = "CAFR Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"

/datum/job/cafr/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Central Asian Federal Republic"
	if(is_squad_leader)
		map.faction2_squad_leaders[squad] = H

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/cafr_newiform(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka/cafr(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/bluefaction(null)
	uniform.attackby(armband, H)
//helmet
	if (findtext(title, "Squad Leader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/coldwar/cafr_officer(H), slot_l_hand)
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/coldwar/cafr_officer(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_l_hand)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
	else if (findtext(title, "Corpsman"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/med(H), slot_head)
	else
		switch(rand(1,2))
			if(1)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
			if(2)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
	
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	if (findtext(title, "Engineer"))
		H.setStat("strength", STAT_VERY_HIGH)
		H.setStat("crafting", STAT_VERY_HIGH)
	else
		H.setStat("strength", STAT_NORMAL)
		H.setStat("crafting", STAT_NORMAL)
	if (findtext(title, "Recon"))
		H.setStat("rifle", STAT_HIGH)
	else
		H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	if (findtext(title, "Officer") || findtext(title, "Commander"))
		H.setStat("pistol", STAT_MAX)
	else
		H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	if (findtext(title, "Corpsman"))
		H.setStat("medical", STAT_MEDIUM_HIGH)
	else if (findtext(title, "Doctor"))
		H.setStat("medical", STAT_VERY_HIGH)
	else
		H.setStat("medical", STAT_NORMAL)
	if (findtext(title, "machinegunner"))
		H.setStat("machinegun", STAT_HIGH)
	else
		H.setStat("machinegun", STAT_NORMAL)

	H.make_artillery_scout()
	return TRUE