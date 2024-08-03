/datum/job/tsfsr
	faction = "Human"
	title = "Turkestan SFSR"
	rank_abbreviation = ""
	spawn_location = "JoinLateTSFSR"
	uses_squads = TRUE
	squad = 0
	default_language = "Russian"
	additional_languages = list("Kyrgyz" = 15, "Tajik" = 15, "Kazakh" = 15, "Turkmen" = 15, "Uzbek" = 15, "Ukrainian" = 5, "Finnish" = 5, "Mongolian" = 5, "Polish" = 2)
	min_positions = 1
	max_positions = 999
	selection_color = "#CC0000"

/datum/job/tsfsr/give_random_name(var/mob/living/human/H)
	switch(rand(1,2))
		if(1)
			H.name = H.species.get_random_russian_name(H.gender)
			H.real_name = H.name
		if(2)
			H.name = H.species.get_random_kazakh_name(H.gender)
			H.real_name = H.name
	
/datum/job/tsfsr/commander
	is_commander = TRUE
	title = "TSFSR Commander"
	rank_abbreviation = "CO-Cpt."
	spawn_location = "JoinLateTSFSRCpt"

/datum/job/tsfsr/officer
	is_commander = TRUE
	title = "TSFSR Officer"
	rank_abbreviation = "XO-Lt."

/datum/job/tsfsr/doctor
	title = "TSFSR Doctor"
	is_medic = TRUE
	rank_abbreviation = "Dr."
	spawn_location = "JoinLateTSFSRDoc"

/datum/job/tsfsr/s1/sl
	title = "TSFSR Squad 1 Squad Leader"
	squad = 1
	is_squad_leader = TRUE
	rank_abbreviation = "1-Sgt"

/datum/job/tsfsr/s1/pvt
	title = "TSFSR Squad 1 Private"
	squad = 1
	rank_abbreviation = "1-Pvt"

/datum/job/tsfsr/s1/corpsman
	title = "TSFSR Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
	rank_abbreviation = "1-Corpsman"

/datum/job/tsfsr/s1/machinegunner
	title = "TSFSR Squad 1 Machinegunner"
	squad = 1
	rank_abbreviation = "1-MG"

/datum/job/tsfsr/s2/sl
	title = "TSFSR Squad 2 Squad Leader"
	squad = 2
	is_squad_leader = TRUE
	rank_abbreviation = "2-Sgt"

/datum/job/tsfsr/s2/pvt
	title = "TSFSR Squad 2 Private"
	squad = 2
	rank_abbreviation = "2-Pvt"

/datum/job/tsfsr/s2/corpsman
	title = "TSFSR Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
	rank_abbreviation = "2-Corpsman"

/datum/job/tsfsr/s2/machinegunner
	title = "TSFSR Squad 2 Machinegunner"
	squad = 2
	rank_abbreviation = "2-MG"

/datum/job/tsfsr/s3/sl
	title = "TSFSR Squad 3 Squad Leader"
	squad = 3
	is_squad_leader = TRUE
	rank_abbreviation = "3-Sgt"

/datum/job/tsfsr/s3/pvt
	title = "TSFSR Squad 3 Private"
	squad = 3
	rank_abbreviation = "3-Pvt"

/datum/job/tsfsr/s3/corpsman
	title = "TSFSR Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
	rank_abbreviation = "3-Corpsman"

/datum/job/tsfsr/s3/machinegunner
	title = "TSFSR Squad 3 Machinegunner"
	squad = 3
	rank_abbreviation = "3-MG"

/datum/job/tsfsr/recon
	title = "TSFSR Recon"
	squad = 4
	rank_abbreviation = "4-Recon"

/datum/job/tsfsr/armored/sl
	title = "TSFSR Armored Squad Leader"
	squad = 5
	is_squad_leader = TRUE
	rank_abbreviation = "5-Tank Sgt"

/datum/job/tsfsr/armored/crew
	title = "TSFSR Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"

/datum/job/tsfsr/at
	title = "TSFSR Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"

/datum/job/tsfsr/engineer
	title = "TSFSR Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"

/datum/job/tsfsr/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Turkestan SFSR"
	if(is_squad_leader)
		map.faction1_squad_leaders[squad] = H

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/redfaction(null)
	uniform.attackby(armband, H)

//helmet
	if (findtext(title, "Squad Leader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/coldwar/soviet_officer(H), slot_l_hand)
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/coldwar/soviet_officer(H), slot_head)
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
				H.equip_to_slot_or_del(new /obj/item/clothing/head/fieldcap/afghanka(H), slot_head)
	
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
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