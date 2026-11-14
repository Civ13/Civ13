// ============================================================
// SUBCOM13 - Submarine crew job definitions.
// Captain (whitelisted), Officer, and Crew roles.
// ============================================================

/datum/job/american/submarine_captain
	title = "Submarine Captain"
	en_meaning = "Commanding Officer"
	rank_abbreviation = "Cmdr."
	spawn_location = "JoinLateSub"
	allowed_maps = list(MAP_SUBCOM13)

	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/american/submarine_captain/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/submarine_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_navy(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/navyofficercap(H), slot_head)
//gear
	H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are the <b>Commanding Officer</b> of this submarine. You are in charge of the entire vessel and crew. Give orders, manage strategy, and ensure mission success!")
	apply_job_stats(H)
	// Register with submarine crew tracking
	if(global.all_submarines.len)
		var/datum/submarine/sub = global.all_submarines[1]
		sub.add_crew_member(H, "Captain")
	return TRUE

/datum/job/american/submarine_officer
	title = "Submarine Officer"
	en_meaning = "Junior Officer"
	rank_abbreviation = "Lt."
	spawn_location = "JoinLateSub"
	allowed_maps = list(MAP_SUBCOM13)

	is_officer = TRUE
	whitelisted = TRUE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/american/submarine_officer/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/submarine_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_navy(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/frenchcoat/navy(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/navyofficercap(H), slot_head)
//gear
	H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>Submarine Officer</b>. You serve as the Executive Officer or department head. Support the Captain and manage your assigned station.")
	apply_job_stats(H)
	// Register with submarine crew tracking
	if(global.all_submarines.len)
		var/datum/submarine/sub = global.all_submarines[1]
		sub.add_crew_member(H, "Officer")
	return TRUE

/datum/job/american/submarine_crew
	title = "Submarine Crewman"
	en_meaning = "Enlisted Sailor"
	rank_abbreviation = "PO"
	spawn_location = "JoinLateSub"
	allowed_maps = list(MAP_SUBCOM13)

	can_be_female = FALSE

	min_positions = 4
	max_positions = 10

/datum/job/american/submarine_crew/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/submarine_crew/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_navy(H), slot_w_uniform)
//gear
	H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>Submarine Crewman</b>. Operate your assigned station - helm, weapons, engineering, or sonar. Follow your officer's orders and keep the boat running!")
	apply_job_stats(H)
	// Register with submarine crew tracking
	if(global.all_submarines.len)
		var/datum/submarine/sub = global.all_submarines[1]
		sub.add_crew_member(H, "Crewman")
	return TRUE
