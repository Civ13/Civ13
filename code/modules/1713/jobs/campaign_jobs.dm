/datum/job/pirates/redfaction
	title = "Red Faction"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	is_event = TRUE
	uses_squads = TRUE
	squad = 0
	additional_languages = list("Blugoslavian" = 15)
	min_positions = 999
	max_positions = 999

/datum/job/pirates/redfaction/commander
	is_commander = TRUE
	title = "RDF Commander"
	rank_abbreviation = "CO-Cpt."

	additional_languages = list("Blugoslavian" = 100)
/datum/job/pirates/redfaction/officer
	is_commander = TRUE
	title = "RDF Officer"
	rank_abbreviation = "XO-Lt."
	additional_languages = list("Blugoslavian" = 50)
/datum/job/pirates/redfaction/medic
	title = "RDF Medic"
	is_medic = TRUE
	rank_abbreviation = "Dr."
/datum/job/pirates/redfaction/s1/sl
	title = "RDF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE
	rank_abbreviation = "1-Sgt"
/datum/job/pirates/redfaction/s1/pvt
	title = "RDF Squad 1 Private"
	squad = 1
	rank_abbreviation = "1-Pvt"
/datum/job/pirates/redfaction/s1/corpsman
	title = "RDF Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
	rank_abbreviation = "1-Corpsman"
/datum/job/pirates/redfaction/s1/machinegunner
	title = "RDF Squad 1 Machinegunner"
	squad = 1
	rank_abbreviation = "1-MG"
/datum/job/pirates/redfaction/s2/sl
	title = "RDF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE
	rank_abbreviation = "2-SL"
/datum/job/pirates/redfaction/s2/pvt
	title = "RDF Squad 2 Private"
	squad = 2
	rank_abbreviation = "2-Pvt"
/datum/job/pirates/redfaction/s2/corpsman
	title = "RDF Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
	rank_abbreviation = "2-Corpsman"
/datum/job/pirates/redfaction/s2/machinegunner
	title = "RDF Squad 2 Machinegunner"
	squad = 2
	rank_abbreviation = "2-MG"
/*
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
	*/
/datum/job/pirates/redfaction/recon
	title = "RDF Recon"
	squad = 4
	rank_abbreviation = "4-Recon"
/datum/job/pirates/redfaction/at
	title = "RDF Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"
/datum/job/pirates/redfaction/engineer
	title = "RDF Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"
/datum/job/pirates/redfaction/armored/sl
	title = "RDF Armored Squadleader"
	squad = 5
	is_squad_leader = TRUE
	rank_abbreviation = "5-Tank Sgt"
/datum/job/pirates/redfaction/armored/crew
	title = "RDF Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"
/datum/job/pirates/redfaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Redmenia"
	if(is_squad_leader)
		map.faction1_squad_leaders[squad] = H
//shoes
	var/area/A = get_area(H)
	if(A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/grey(H), slot_shoes)
	else
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
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_head)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
	else if ((findtext(title, "Sniper") || findtext(title, "Recon")) && A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/key/red, slot_l_store)
	if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/remington870(H), slot_shoulder)
	else if (findtext(title, "Machinegunner"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
	else if (findtext(title, "Anti-Tank"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/rpg7(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/rpg(H), slot_back)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		if (findtext(title, "Machinegunner"))
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg(H), slot_belt)
		else if (findtext(title, "Sniper") || findtext(title, "Recon"))
			H.setStat("rifle", STAT_MEDIUM_HIGH)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/sniper/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/sniper(null)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red(H), slot_belt)
			uniform.attackby(webbing, H)
		else if (findtext(title, "Engineer"))
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper, slot_belt)
		else
			if(findtext(title, "Armored"))
				var/obj/item/clothing/accessory/storage/webbing/shotgun_bandolier/filled_buckshot/webbing = new /obj/item/clothing/accessory/storage/webbing/shotgun_bandolier/filled_buckshot(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red(null)
				uniform.attackby(webbing, H)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	H.make_artillery_scout()
	if(A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/schneetarn(H), slot_wear_suit)
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
	additional_languages = list("Redmenian" = 15)

/datum/job/civilian/bluefaction/commander
	is_commander = TRUE
	title = "BAF Commander"
	rank_abbreviation = "CO-Cpt."
	additional_languages = list("Redmenian" = 100)
/datum/job/civilian/bluefaction/officer
	is_commander = TRUE
	title = "BAF Officer"
	rank_abbreviation = "XO-Lt."
	additional_languages = list("Redmenian" = 50)
/datum/job/civilian/bluefaction/medic
	title = "BAF Medic"
	is_medic = TRUE
	rank_abbreviation = "Dr."

/datum/job/civilian/bluefaction/s1/sl
	title = "BAF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE
	rank_abbreviation = "1-Sgt"
/datum/job/civilian/bluefaction/s1/pvt
	title = "BAF Squad 1 Private"
	squad = 1
	rank_abbreviation = "1-Pvt"
/datum/job/civilian/bluefaction/s1/corpsman
	title = "BAF Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
	rank_abbreviation = "1-Corpsman"
/datum/job/civilian/bluefaction/s1/machinegunner
	title = "BAF Squad 1 Machinegunner"
	squad = 1
	rank_abbreviation = "1-MG"
/datum/job/civilian/bluefaction/s1/marksman
	title = "BAF Squad 1 Des. Marksman"
	squad = 1
	rank_abbreviation = "1-DM"

/datum/job/civilian/bluefaction/s2/sl
	title = "BAF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE
	rank_abbreviation = "2-Sgt"
/datum/job/civilian/bluefaction/s2/pvt
	title = "BAF Squad 2 Private"
	squad = 2
	rank_abbreviation = "2-Pvt"
/datum/job/civilian/bluefaction/s2/corpsman
	title = "BAF Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
	rank_abbreviation = "2-Corpsman"
/datum/job/civilian/bluefaction/s2/machinegunner
	title = "BAF Squad 2 Machinegunner"
	squad = 2
	rank_abbreviation = "2-MG"
/datum/job/civilian/bluefaction/s2/marksman
	title = "BAF Squad 2 Des. Marksman"
	squad = 2
	rank_abbreviation = "2-DM"

/datum/job/civilian/bluefaction/s3/sl
	title = "BAF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE
	rank_abbreviation = "3-Sgt"
/datum/job/civilian/bluefaction/s3/pvt
	title = "BAF Squad 3 Private"
	squad = 3
	rank_abbreviation = "3-Pvt"
/datum/job/civilian/bluefaction/s3/corpsman
	title = "BAF Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
	rank_abbreviation = "3-Corpsman"
/datum/job/civilian/bluefaction/s3/machinegunner
	title = "BAF Squad 3 Machinegunner"
	squad = 3
	rank_abbreviation = "3-MG"
/datum/job/civilian/bluefaction/s3/marksman
	title = "BAF Squad 3 Des. Marksman"
	squad = 3
	rank_abbreviation = "3-DM"

/datum/job/civilian/bluefaction/recon
	title = "BAF Recon"
	squad = 4
	rank_abbreviation = "4-Recon"
/datum/job/civilian/bluefaction/at
	title = "BAF Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"
/*
/datum/job/civilian/bluefaction/engineer
	title = "BAF Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"
*/
/datum/job/civilian/bluefaction/armored/sl
	title = "BAF Armored Squadleader"
	is_squad_leader = TRUE
	squad = 5
	rank_abbreviation = "5-Tank Sgt"
/datum/job/civilian/bluefaction/armored/crew
	title = "BAF Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"

/datum/job/civilian/bluefaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Blugoslavia"
	if(is_squad_leader)
		map.faction2_squad_leaders[squad] = H
//shoes
	var/area/A = get_area(H)
	if(A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/grey(H), slot_shoes)
	else
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
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_blugoslavia(H), slot_head)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
	else if ((findtext(title, "Sniper") || findtext(title, "Recon")) && A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/white(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)
	if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/key/blue, slot_l_store)
	if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.setStat("rifle", STAT_MEDIUM_HIGH)
		if(A.climate == "taiga" || A.climate == "tundra")
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_shoulder)
	else if (findtext(title, "Des. Marksman"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd/acog(H), slot_shoulder)
	else if (findtext(title, "Machinegunner"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
	else if (findtext(title, "Anti-Tank"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/rpg7(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/rpg(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
		var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
		var/obj/item/weapon/attachment/scope/adjustable/advanced/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/acog(src)
		SP.attached(null,HGUN,TRUE)
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,HGUN,TRUE)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/nvg(H), slot_eyes)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		if (findtext(title, "Machinegunner"))
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg(H), slot_belt)
		else if (findtext(title, "Sniper") || findtext(title, "Recon"))
			H.setStat("rifle", STAT_MEDIUM_HIGH)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd(null)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
			uniform.attackby(webbing, H)
		else if  (findtext(title, "Des. Marksman"))
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd(null)
			uniform.attackby(webbing, H)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
		else if (findtext(title, "Engineer"))
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper, slot_belt)
		else
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak(null)
			uniform.attackby(webbing, H)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	H.make_artillery_scout()
	if(A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
	return TRUE
