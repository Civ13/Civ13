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

/datum/job/pirates/redfaction/commander
	is_commander = TRUE
	title = "RDF Officer"
/datum/job/pirates/redfaction/medic
	title = "RDF Medic"
	is_medic = TRUE

/datum/job/pirates/redfaction/s1
	title = "RDF Squad 1 Private"
	squad = 1
/datum/job/pirates/redfaction/s1/sl
	title = "RDF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE
/datum/job/pirates/redfaction/s1/corpsman
	title = "RDF Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
/datum/job/pirates/redfaction/s1/machinegunner
	title = "RDF Squad 1 Machinegunner"
	squad = 1

/datum/job/pirates/redfaction/s2
	title = "RDF Squad 2 Private"
	squad = 2
/datum/job/pirates/redfaction/s2/sl
	title = "RDF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE
/datum/job/pirates/redfaction/s2/corpsman
	title = "RDF Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
/datum/job/pirates/redfaction/s2/machinegunner
	title = "RDF Squad 2 Machinegunner"
	squad = 2

/datum/job/pirates/redfaction/s3
	title = "RDF Squad 3 Private"
	squad = 3
/datum/job/pirates/redfaction/s3/sl
	title = "RDF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE
/datum/job/pirates/redfaction/s3/corpsman
	title = "RDF Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
/datum/job/pirates/redfaction/s3/machinegunner
	title = "RDF Squad 3 Machinegunner"
	squad = 3
/datum/job/pirates/redfaction/recon
	title = "RDF Recon"
	squad = 4
/datum/job/pirates/redfaction/armored
	title = "RDF Armored Crew"
	squad = 5
/datum/job/pirates/redfaction/armored/sl
	title = "RDF Armored Commander"
	squad = 5
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
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(pasgt_armor, H)

//equipment
	if (findtext(title, "Squadleader"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/sl(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/com(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)
	else if (findtext(title, "Machinegunner"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
	else
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
	if (findtext(title, "Corpsman"))
		H.setStat("medical", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else if (findtext(title, "Medic"))
		H.setStat("medical", STAT_VERY_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		if (findtext(title, "Machinegunner"))
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg(H), slot_belt)
		else if (findtext(title, "Sniper") || findtext(title, "Recon"))
			H.setStat("rifle", STAT_MEDIUM_HIGH)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/sniper/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/sniper(null)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red(H), slot_belt)
			uniform.attackby(webbing, H)
		else
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red(null)
			uniform.attackby(webbing, H)
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
	title = "BAF Officer"
/datum/job/civilian/bluefaction/medic
	title = "BAF Medic"
	is_medic = TRUE

/datum/job/civilian/bluefaction/s1
	title = "BAF Squad 1 Private"
	squad = 1
/datum/job/civilian/bluefaction/s1/sl
	title = "BAF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE
/datum/job/civilian/bluefaction/s1/corpsman
	title = "BAF Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
/datum/job/civilian/bluefaction/s1/machinegunner
	title = "BAF Squad 1 Machinegunner"
	squad = 1

/datum/job/civilian/bluefaction/s2
	title = "BAF Squad 2 Private"
	squad = 2
/datum/job/civilian/bluefaction/s2/sl
	title = "BAF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE
/datum/job/civilian/bluefaction/s2/corpsman
	title = "BAF Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
/datum/job/civilian/bluefaction/s2/machinegunner
	title = "BAF Squad 2 Machinegunner"
	squad = 2

/datum/job/civilian/bluefaction/s3
	title = "BAF Squad 3 Private"
	squad = 3
/datum/job/civilian/bluefaction/s3/sl
	title = "BAF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE
/datum/job/civilian/bluefaction/s3/corpsman
	title = "BAF Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
/datum/job/civilian/bluefaction/s3/machinegunner
	title = "BAF Squad 3 Machinegunner"
	squad = 3

/datum/job/civilian/bluefaction/recon
	title = "BAF Recon"
	squad = 4

/datum/job/civilian/bluefaction/armored
	title = "BAF Armored Crew"
	squad = 5

/datum/job/civilian/bluefaction/armored/sl
	title = "BAF Armored Commander"
	is_squad_leader = TRUE
	squad = 5
/datum/job/civilian/bluefaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	if(is_squad_leader)
		map.faction2_squad_leaders[squad] = H
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/green/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/green(null)
	uniform.attackby(pasgt_armor, H)
//equipment
	if (findtext(title, "Squadleader"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green/sl(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green/com(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)
	if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.setStat("rifle", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)
	else if (findtext(title, "Machinegunner"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
	else
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
	if (findtext(title, "Corpsman"))
		H.setStat("medical", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else if (findtext(title, "Medic"))
		H.setStat("medical", STAT_VERY_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		if (findtext(title, "Machinegunner"))
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg(H), slot_belt)
		else if (findtext(title, "Sniper") || findtext(title, "Recon"))
			H.setStat("rifle", STAT_MEDIUM_HIGH)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/sniper/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/sniper(null)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
			uniform.attackby(webbing, H)
		else
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue(null)
			uniform.attackby(webbing, H)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	H.make_artillery_scout()
	return TRUE
