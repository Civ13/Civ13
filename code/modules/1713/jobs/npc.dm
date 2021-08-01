/datum/job/npc
	faction = "Human"

/datum/job/npc/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/npc/bandit
	title = "Bandit"
	en_meaning = ""
	rank_abbreviation = ""

	spawn_location = ""


	min_positions = 0
	max_positions = 0

/datum/job/npc/bandit/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/wastelander(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh(H), slot_wear_mask)
//weapons
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_l_store)

	return TRUE