/datum/job/redfaction
	faction = "Human"
	title = "Red Faction"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = TRUE
	squad = 0
	additional_languages = list("Blugoslavian" = 15)
	min_positions = 1
	max_positions = 999
	selection_color = "#CC0000"

/datum/job/redfaction/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_redfaction_name(H.gender)
	H.real_name = H.name

/datum/job/redfaction/commander
	is_commander = TRUE
	title = "RDF Commander"
	rank_abbreviation = "CO-Cpt."
	additional_languages = list("Blugoslavian" = 100)
/datum/job/redfaction/officer
	is_commander = TRUE
	title = "RDF Officer"
	rank_abbreviation = "XO-Lt."
	additional_languages = list("Blugoslavian" = 100)

/datum/job/redfaction/doctor
	title = "RDF Doctor"
	is_medic = TRUE
	rank_abbreviation = "Dr."

/datum/job/redfaction/s1/sl
	title = "RDF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE
	rank_abbreviation = "1-Sgt"
/datum/job/redfaction/s1/pvt
	title = "RDF Squad 1 Private"
	squad = 1
	rank_abbreviation = "1-Pvt"
/datum/job/redfaction/s1/corpsman
	title = "RDF Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
	rank_abbreviation = "1-Corpsman"
/datum/job/redfaction/s1/machinegunner
	title = "RDF Squad 1 Machinegunner"
	squad = 1
	rank_abbreviation = "1-MG"
/*
/datum/job/bluefaction/s1/marksman
	title = "RDF Squad 1 Des. Marksman"
	squad = 1
	rank_abbreviation = "1-DM"
*/

/datum/job/redfaction/s2/sl
	title = "RDF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE
	rank_abbreviation = "2-Sgt"
/datum/job/redfaction/s2/pvt
	title = "RDF Squad 2 Private"
	squad = 2
	rank_abbreviation = "2-Pvt"
/datum/job/redfaction/s2/corpsman
	title = "RDF Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
	rank_abbreviation = "2-Corpsman"
/datum/job/redfaction/s2/machinegunner
	title = "RDF Squad 2 Machinegunner"
	squad = 2
	rank_abbreviation = "2-MG"
/*
/datum/job/bluefaction/s2/marksman
	title = "RDF Squad 2 Des. Marksman"
	squad = 2
	rank_abbreviation = "2-DM"
*/

/datum/job/redfaction/s3/sl
	title = "RDF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE
	rank_abbreviation = "3-Sgt"
/datum/job/redfaction/s3/pvt
	title = "RDF Squad 3 Private"
	squad = 3
	rank_abbreviation = "3-Pvt"
/datum/job/redfaction/s3/corpsman
	title = "RDF Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
	rank_abbreviation = "3-Corpsman"
/datum/job/redfaction/s3/machinegunner
	title = "RDF Squad 3 Machinegunner"
	squad = 3
	rank_abbreviation = "3-MG"
/*
/datum/job/bluefaction/s3/marksman
	title = "RDF Squad 3 Des. Marksman"
	squad = 3
	rank_abbreviation = "3-DM"
*/

/datum/job/redfaction/recon
	title = "RDF Recon"
	squad = 4
	rank_abbreviation = "4-Recon"
/*
/datum/job/redfaction/armored/sl
	title = "RDF Armored Squadleader"
	squad = 5
	is_squad_leader = TRUE
	rank_abbreviation = "5-Tank Sgt"
/datum/job/redfaction/armored/crew
	title = "RDF Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"

/datum/job/redfaction/at
	title = "RDF Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"
*/
/datum/job/redfaction/engineer
	title = "RDF Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"

/datum/job/redfaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Redmenia"
	if(is_squad_leader)
		map.faction1_squad_leaders[squad] = H
	var/area/A = get_area(get_turf(H))

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
	
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/redmenia/standard/modern(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	
//armor
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(armor, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)

//helmet
	if (findtext(title, "Squadleader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_r_hand)
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_r_hand)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
	else if ((findtext(title, "Sniper") || findtext(title, "Recon")) && (A.climate == "taiga" || A.climate == "tundra"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/white(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)

//equipment
	if (findtext(title, "Squadleader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/key/redfaction, slot_l_store)

	if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.setStat("rifle", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)
	else if (findtext(title, "Machinegunner"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
	else if (findtext(title, "Anti-Tank"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/rpg7/loaded(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rpg_pack/filled_at(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
	else if (findtext(title, "Engineer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/plastique/c4(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/flare_pouch/normal_full (H), slot_r_store)
		var/obj/item/weapon/gun/projectile/submachinegun/g3/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/g3(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
	else if (!findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
		var/obj/item/weapon/gun/projectile/submachinegun/g3/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/g3(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
	
	if (findtext(title, "Corpsman"))
		H.setStat("medical", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else if (findtext(title, "Doctor"))
		H.setStat("medical", STAT_MAX)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/redfaction(null)
		uniform.attackby(armband, H)

	if (findtext(title, "Machinegunner"))
		if(A.climate == "taiga" || A.climate == "tundra")
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/red/white/mg(H), slot_belt)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/red/mg(H), slot_belt)
	else if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.setStat("rifle", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red/mosin(null)
		if(A.climate == "taiga" || A.climate == "tundra")
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/white/recon(H), slot_belt)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/recon(H), slot_belt)
		uniform.attackby(webbing, H)
	else if  (findtext(title, "Des. Marksman"))
		var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red/svd(null)
		uniform.attackby(webbing, H)
		if(A.climate == "taiga" || A.climate == "tundra")
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/white/marksman(H), slot_belt)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/marksman(H), slot_belt)
	else if (findtext(title, "Engineer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper(H), slot_belt)
		var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red/g3(null)
		uniform.attackby(webbing, H)
	else
		if (findtext(title, "Armored"))
			var/obj/item/clothing/accessory/holster/hip/HH = new /obj/item/clothing/accessory/holster/hip(null)
			uniform.attackby(HH, H)
			var/obj/item/weapon/gun/projectile/pistol/m1911/PISTOL = new /obj/item/weapon/gun/projectile/pistol/m1911(H)
			uniform.attackby(PISTOL, H)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_r_store)
		else
			if (is_officer || is_squad_leader || is_commander || is_medic || squad == 6)
				var/obj/item/clothing/accessory/holster/hip/HH = new /obj/item/clothing/accessory/holster/hip(null)
				uniform.attackby(HH, H)
				var/obj/item/weapon/gun/projectile/pistol/m1911/PISTOL = new /obj/item/weapon/gun/projectile/pistol/m1911(H)
				uniform.attackby(PISTOL, H)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_r_store)
			else
				var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red/g3(null)
				uniform.attackby(webbing, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/full(H), slot_belt)
	
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)

	H.make_artillery_scout()
	if(A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/schneetarn(H), slot_wear_suit)
	return TRUE

/datum/job/redfaction/navy/captain
	title = "IRN Captain"
	is_commander = TRUE
	is_navy = TRUE
	max_positions = 1
	rank_abbreviation = "Captain"
	additional_languages = list("Blugoslavian" = 100)
	
/datum/job/redfaction/navy/petty
	title = "IRN Petty Officer"
	is_squad_leader = TRUE
	is_navy = TRUE
	max_positions = 10
	rank_abbreviation = "PO"
	squad = 1
/datum/job/redfaction/navy/one
	is_navy = TRUE
	title = "IRN Sailor"
	squad = 1
	rank_abbreviation = "Sailor"

/datum/job/redfaction/navy/marine/sl
	is_navy = TRUE
	title = "IRN Marine Squadleader"
	is_squad_leader = TRUE
	max_positions = 5
	rank_abbreviation = "Sgt."
	squad = 2
/datum/job/redfaction/navy/marine/soldier
	is_navy = TRUE
	title = "IRN Marine"
	max_positions = 20
	rank_abbreviation = "Pvt."
	squad = 2
/datum/job/redfaction/navy/doctor
	is_navy = TRUE
	title = "IRN Doctor"
	max_positions = 6
	rank_abbreviation = "Dr."
	is_medic = TRUE

/datum/job/redfaction/navy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Redmenia"
	if(is_squad_leader)
		map.faction1_squad_leaders[squad] = H
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//armor and clothes
	if (findtext(title, "Marine"))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/armor/coldwar/rb23/armor = new /obj/item/clothing/accessory/armor/coldwar/rb23(null)
		uniform.attackby(armor, H)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/redmenian_sailor(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
//equipment
	if (findtext(title, "Petty Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	else if (findtext(title, "Captain"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap_redmenia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	else if (findtext(title, "Marine"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
		var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog(src)
		SP.attached(null,HGUN,TRUE)
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,HGUN,TRUE)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/us_sailor_hat/redmenia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/lifejacket(H), slot_wear_suit)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	if (findtext(title, "Doctor"))
		H.setStat("medical", STAT_MAX)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else
		if (is_officer || is_squad_leader || is_commander || squad == 6 || findtext(title, "Sailor"))
			var/obj/item/clothing/accessory/holster/hip/HH = new /obj/item/clothing/accessory/holster/hip(null)
			uniform.attackby(HH, H)
			var/obj/item/weapon/gun/projectile/pistol/m1911/PISTOL = new /obj/item/weapon/gun/projectile/pistol/m1911(H)
			uniform.attackby(PISTOL, H)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
		else
			if (findtext(title, "Marine"))
				var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red/ak47(null)
				uniform.attackby(webbing, H)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/full(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.make_artillery_scout()
	return TRUE

/datum/job/redfaction/rotstadt_fighter
	title = "RPR Fighter"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_rotstadt = TRUE
	additional_languages = list("Blugoslavian" = 89)
	min_positions = 999
	max_positions = 999

/datum/job/redfaction/rotstadt_fighter/equip(mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Redmenia"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/brown(H), slot_shoes)
//clothes
	var/rand_uni = rand(1,2)
	switch (rand_uni)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
	
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/redfaction(null)
	uniform.attackby(armband, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	
	return TRUE
	

/datum/job/redfaction/rotstadt_medic
	title = "RPR Doctor"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_rotstadt = TRUE
	is_medic = TRUE
	additional_languages = list("Blugoslavian" = 89)
	min_positions = 1
	max_positions = 2

/datum/job/redfaction/rotstadt_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Redmenia"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	var/rand_uni = rand(1,2)
	switch (rand_uni)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
	
	var/obj/item/clothing/under/uniform = H.w_uniform
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(medicalarm, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MAX)
	

	return TRUE

/datum/job/redfaction/rotstadt_commander
	title = "RPR Commander"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_rotstadt = TRUE
	is_commander = TRUE
	additional_languages = list("Blugoslavian" = 89)
	min_positions = 1
	max_positions = 1

/datum/job/redfaction/rotstadt_commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Redmenia"
	if(is_squad_leader)
		map.faction1_squad_leaders[squad] = H
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/rb23/armor = new /obj/item/clothing/accessory/armor/coldwar/rb23(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/redfaction(null)
	uniform.attackby(armband, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_head)

	var/obj/item/clothing/accessory/holster/hip/HH = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(HH, H)
	var/obj/item/weapon/gun/projectile/pistol/m1911/PISTOL = new /obj/item/weapon/gun/projectile/pistol/m1911(H)
	uniform.attackby(PISTOL, H)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_r_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	
	H.make_artillery_scout()

	return TRUE

/datum/job/redfaction/civilian
	title = "Redmenian Civilian"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_civilizations = TRUE
	additional_languages = list("Blugoslavian" = 15)
	min_positions = 999
	max_positions = 999

/datum/job/redfaction/civilian/equip(mob/living/human/H)
	if (!H)	return FALSE
	H.nationality = "Redmenia"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/redmenia/standard/modern(H), slot_w_uniform)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/redfaction(null)
	uniform.attackby(armband, H)
//equipment

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	
	H.make_nation()
	H.add_note("Civilization", "You are a member of the <b>[civname_a]</b> civilization.")

	return TRUE
	