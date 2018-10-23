////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////ROMAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/roman
	faction = "Station"

/datum/job/roman/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_portuguese_name(H.gender)
	H.real_name = H.name

/datum/job/roman/soldier
	title = "Romanus Legionarius"
	en_meaning = "Roman Legionary"
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
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the Roman Army. Defend the Republic!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////GREEK///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/greek
	faction = "Station"

/datum/job/greek/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_portuguese_name(H.gender)
	H.real_name = H.name