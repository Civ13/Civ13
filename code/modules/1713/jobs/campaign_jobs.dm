/datum/job/pirates/redfaction
	title = "Red Faction"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	is_event = TRUE
	uses_squads = TRUE
	squad = 0
	additional_languages = list("Russian" = 15)
	min_positions = 999
	max_positions = 999

/datum/job/civilian/redfaction/commander
	is_commander = TRUE
	title = "RDF Commander"

/datum/job/civilian/redfaction/s1
	title = "RDF Squad 1 Pvt"
	squad = 1
/datum/job/civilian/redfaction/s1/sl
	title = "RDF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE
/datum/job/civilian/redfaction/s1/corpsman
	title = "RDF Squad 1 Corpsman"
	squad = 1

/datum/job/civilian/redfaction/s2
	title = "RDF Squad 2 Pvt"
	squad = 2
/datum/job/civilian/redfaction/s2/sl
	title = "RDF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE

/datum/job/civilian/redfaction/s3
	title = "RDF Squad 3 Pvt"
	squad = 3
/datum/job/civilian/redfaction/s3/sl
	title = "RDF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE

/datum/job/pirates/redfaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	if(is_squad_leader)
		map.faction1_squad_leaders[squad] = H
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(pasgt_armor, H)
	uniform.attackby(webbing, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	if (title == "RDF Squad 1 Corpsman" || title == "RDF Squad 2 Corpsman" || title == "RDF Squad 3 Corpsman")
		H.setStat("medical", STAT_MEDIUM_HIGH)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else if (title == "RDF Medic")
		H.setStat("medical", STAT_VERY_HIGH)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	H.make_artillery_scout()
	return TRUE

/datum/job/civilian/bluefaction
	title = "Blue Faction"
	rank_abbreviation = ""
	spawn_location = "JoinLateBlue"
	is_event = TRUE
	uses_squads = TRUE
	squad = 0
	min_positions = 999
	max_positions = 999

/datum/job/civilian/bluefaction/commander
	is_commander = TRUE
	title = "BAF Commander"

/datum/job/civilian/bluefaction/s1
	title = "BAF Squad 1 Pvt"
	squad = 1
/datum/job/civilian/bluefaction/s1/sl
	title = "BAF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE

/datum/job/civilian/bluefaction/s2
	title = "BAF Squad 2 Pvt"
	squad = 2
/datum/job/civilian/bluefaction/s2/sl
	title = "BAF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE

/datum/job/civilian/bluefaction/s3
	title = "BAF Squad 3 Pvt"
	squad = 3
/datum/job/civilian/bluefaction/s3/sl
	title = "BAF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE

/datum/job/civilian/bluefaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	if(is_squad_leader)
		map.faction2_squad_leaders[squad] = H
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni(H), slot_w_uniform)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/green/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/green(null)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(pasgt_armor, H)
	uniform.attackby(webbing, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/sks/sksm(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	if (title == "BAF Squad 1 Corpsman" || title == "BAF Squad 2 Corpsman" || title == "BAF Squad 3 Corpsman")
		H.setStat("medical", STAT_MEDIUM_HIGH)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else if (title == "BAF Medic")
		H.setStat("medical", STAT_VERY_HIGH)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	H.make_artillery_scout()
	return TRUE
