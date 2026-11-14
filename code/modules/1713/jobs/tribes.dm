//Red Tribe
/datum/job/british/rchief
	title = "Red Tribe Chieftain"
	en_meaning = FALSE
	rank_abbreviation = "Chieftain"
	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	allowed_maps = list(MAP_TWOTRIBES)
	
	is_twotribes = TRUE
	spawn_location = "JoinLateRChief"
	can_be_female = TRUE
	
	min_positions = 1
	max_positions = 1
	
/datum/job/british/rchief/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_VERY_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_VERY_HIGH, "medical" = STAT_MEDIUM_LOW)
/datum/job/british/rchief/equip(var/mob/living/human/H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/bone_battleaxe(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/nguni_shield(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(armband, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/gatorpelt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
	apply_job_stats(H)
	
	
/datum/job/british/rshaman
	title = "Red Tribe Shaman"
	en_meaning = FALSE
	rank_abbreviation = "Shaman"
	allowed_maps = list(MAP_TWOTRIBES)
	
	is_twotribes = TRUE
	spawn_location = "JoinLateRShaman"
	can_be_female = TRUE
	
	min_positions = 1
	max_positions = 8
	
/datum/job/british/rshaman/job_stats = list("strength" = STAT_MEDIUM_LOW, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_LOW, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_VERY_HIGH)
/datum/job/british/rshaman/equip(var/mob/living/human/H)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint/leather(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/herbs(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(armband, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/goatpelt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
	
	apply_job_stats(H)
	
/datum/job/british/rtribesperson
	title = "Red Tribe Tribesperson"
	en_meaning = FALSE
	rank_abbreviation = ""
	allowed_maps = list(MAP_TWOTRIBES)
	
	is_twotribes = TRUE
	spawn_location = "JoinLateRTribesperson"
	can_be_female = TRUE
	
	min_positions = 1
	max_positions = 200
	
/datum/job/british/rtribesperson/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/british/rtribesperson/equip(var/mob/living/human/H)
	apply_job_stats(H)
	
//Blue Tribe
/datum/job/french/BChief
	title = "Blue Tribe Chieftain"
	en_meaning = FALSE
	rank_abbreviation = "Chieftain"
	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	allowed_maps = list(MAP_TWOTRIBES)
	
	is_twotribes = TRUE
	spawn_location = "JoinLateBChief"
	can_be_female = TRUE
	
	min_positions = 1
	max_positions = 1
	
/datum/job/french/bchief/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_VERY_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_VERY_HIGH, "medical" = STAT_MEDIUM_LOW)
/datum/job/french/bchief/equip(var/mob/living/human/H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/bone_battleaxe(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/nguni_shield(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/armband = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(armband, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/gatorpelt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
	
	apply_job_stats(H)
	
	
/datum/job/french/bshaman
	title = "Blue Tribe Shaman"
	en_meaning = FALSE
	rank_abbreviation = "Shaman"
	allowed_maps = list(MAP_TWOTRIBES)
	
	is_twotribes = TRUE
	spawn_location = "JoinLateBShaman"
	can_be_female = TRUE
	
	min_positions = 1
	max_positions = 8
	
/datum/job/french/bshaman/job_stats = list("strength" = STAT_MEDIUM_LOW, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_LOW, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_VERY_HIGH)
/datum/job/french/bshaman/equip(var/mob/living/human/H)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint/leather(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/herbs(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/armband = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(armband, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/goatpelt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
	
	apply_job_stats(H)
	
/datum/job/french/btribesperson
	title = "Blue Tribe Tribesperson"
	en_meaning = FALSE
	rank_abbreviation = ""
	allowed_maps = list(MAP_TWOTRIBES)
	
	is_twotribes = TRUE
	spawn_location = "JoinLateBTribesperson"
	can_be_female = TRUE
	
	min_positions = 1
	max_positions = 200
	
/datum/job/french/btribesperson/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/french/btribesperson/equip(var/mob/living/human/H)
	apply_job_stats(H)