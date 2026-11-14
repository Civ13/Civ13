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

/datum/job/npc/bandit/job_loadout = list(
	/obj/item/clothing/shoes/laceup = slot_shoes,
	/obj/item/clothing/under/wastelander = slot_w_uniform,
	/obj/item/clothing/mask/shemagh = slot_wear_mask,
	/obj/item/ammo_magazine/glock17 = slot_l_store)
/datum/job/npc/bandit/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

	return TRUE