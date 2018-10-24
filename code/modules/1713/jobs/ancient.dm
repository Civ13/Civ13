////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////ROMAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/roman
	faction = "Station"

/datum/job/roman/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_roman_name()
	H.real_name = H.name
	
/datum/job/roman/captain	//Roman - Centurion
	title = "Centurion"
	en_meaning = "Ancient and legendary Commander"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	is_commander = TRUE
	head_position = TRUE
	is_officer = TRUE
	// Autobalance
	min_positions = 1
	max_positions = 2
																					//Must create /datum/job/roman/captain/equip, its b0rking
	/*
	/datum/job/roman/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman, slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a Ancient Captain of the Roman Army. You are equipped with two <b>Pila</b> javelins, your shield and a <b>Gladius</b>.") 
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
	*/
	
	
/datum/job/roman/qm	//Roman - Decurion
	title = "Decurion"
	en_meaning = "Combat Officer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	head_position = TRUE
	is_officer = TRUE
	
	// Autobalance
	min_positions = 2
	max_positions = 4
	//add the qm/equip


/datum/job/roman/soldier
	title = "Legionarius"
	en_meaning = "Main Infantry"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 12
	max_positions = 200

/datum/job/roman/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman, slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the Roman Army. You are equipped with two <b>Pila</b> javelins, your shield and a <b>Gladius</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
	
	
/datum/job/roman/bearer
	title = "Aquila-Bearer"
	en_meaning = "Light Infantry, spread wisdom and religiosity between roman troops"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 12
	max_positions = 200
//Add bearer/equip
	
/datum/job/roman/velites
	title = "Legionarius"
	en_meaning = "Light Archer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 12
	max_positions = 200
//add velites/equip
////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////GREEK///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/greek
	faction = "Station"

/datum/job/greek/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_greek_name()
	H.real_name = H.name


/datum/job/greek/captain	//Greek Strategus
	title = "Strategus"
	en_meaning = "Great Macedonian ancient Commander"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE
	is_commander = TRUE
	head_position = TRUE
	is_officer = TRUE
	// Autobalance
	min_positions = 1
	max_positions = 2
	//Must create /datum/job/greek/captain/equip, its b0rking

	
	
/datum/job/greek/qm	//Greek - Phalanx
	title = "Phalanx Espartan"
	en_meaning = "Combat Officer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE
	head_position = TRUE
	is_officer = TRUE
	// Autobalance
	min_positions = 2
	max_positions = 4
	//add the qm/equip


/datum/job/greek/soldier
	title = "Athenian Hoplites"
	en_meaning = "Main infantry soldier"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 200

/datum/job/greek/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/athens, slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/athens(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/dory(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier fromt the city-state of Athens. You have your <b>Dory</b> spear, your round <b>Aspis</b> shield and your <b>Xiphos</b> sword.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
	
/datum/job/greek/bearer
	title = "Hellenistic Bearer"
	en_meaning = "Ligh Infantry, guardians of knowledge"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 200
	
/datum/job/greek/toxotai
	title = "Greek Toxotai"
	en_meaning = "Light Archer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 200
