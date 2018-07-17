/proc/civ_stat()
	return pick(ALL_STATS)

/datum/job/partisan/civilian
	title = "Civilian"
	selection_color = "#530909"
	spawn_location = "JoinLateCivilian"

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 10
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 10

/datum/job/partisan/civilian/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/flashlight(H), pick(slot_l_hand, slot_r_hand))
	equip_random_civilian_clothing(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple civilian trying to live his life in the warzone. Survive.")
	H.setStat("strength", civ_stat())
	H.setStat("engineering", civ_stat())
	H.setStat("shotgun", civ_stat())
	H.setStat("medical", civ_stat())

	H.setStat("rifle", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))
	H.setStat("mg", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))
	H.setStat("smg", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))

	H.setStat("survival", pick(STAT_MEDIUM_HIGH, STAT_HIGH))
	return TRUE


////////////////////////////////////////////////////////////////////////////
/datum/job/partisan/civilian/redcross
	title = "Red Cross"
	selection_color = "#530909"
	spawn_location = "JoinLateRC"
	is_redcross = TRUE
	additional_languages = list( "Russian" = 100, "German" = 100, "Italian" = 100, "Polish" = 100)

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3
	player_threshold = PLAYER_THRESHOLD_HIGHEST - 20
	scale_to_players = PLAYER_THRESHOLD_HIGHEST + 20

/datum/job/partisan/civilian/redcross/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/redcross(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel_med(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/latex(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/medical(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new 	/obj/item/clothing/head/caphat/gercap/fieldcap2(H), slot_head)
	var/obj/item/clothing/accessory/armband/redcross_a = new /obj/item/clothing/accessory/armband/redcross(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(redcross_a, H)
	H.add_note("Role", "You are a member of the Red Cross, a civilian organization whose mission is to provide medical and humanitarian help to anyone who needs it, regarding of the side in the war.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("shotgun", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)

	H.setStat("rifle", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))
	H.setStat("mg", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))
	H.setStat("smg", pick(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW))

	H.setStat("survival", pick(STAT_MEDIUM_HIGH, STAT_HIGH))
	return TRUE