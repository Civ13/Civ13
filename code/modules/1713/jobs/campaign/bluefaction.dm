/datum/job/bluefaction
	faction = "Human"
	title = "Blue Faction"
	rank_abbreviation = ""
	spawn_location = "JoinLateBlue"
	uses_squads = TRUE
	squad = 0
	min_positions = 1
	max_positions = 999
	additional_languages = list("Redmenian" = 15)
	selection_color = "#102f44"

/datum/job/bluefaction/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_bluefaction_name(H.gender)
	H.real_name = H.name

/datum/job/bluefaction/commander
	is_commander = TRUE
	title = "BAF Commander"
	rank_abbreviation = "CO-Cpt."
	additional_languages = list("Redmenian" = 100)
/datum/job/bluefaction/officer
	is_commander = TRUE
	title = "BAF Officer"
	rank_abbreviation = "XO-Lt."
	additional_languages = list("Redmenian" = 100)

/datum/job/bluefaction/doctor
	title = "BAF Doctor"
	is_medic = TRUE
	rank_abbreviation = "Dr."

/datum/job/bluefaction/s1/sl
	title = "BAF Squad 1 Squadleader"
	squad = 1
	is_squad_leader = TRUE
	rank_abbreviation = "1-Sgt"
/datum/job/bluefaction/s1/pvt
	title = "BAF Squad 1 Private"
	squad = 1
	rank_abbreviation = "1-Pvt"
/datum/job/civilian/bluefaction/s1/corpsman
	title = "BAF Squad 1 Corpsman"
	is_medic = TRUE
	squad = 1
	rank_abbreviation = "1-Corpsman"
/datum/job/bluefaction/s1/machinegunner
	title = "BAF Squad 1 Machinegunner"
	squad = 1
	rank_abbreviation = "1-MG"
/*
/datum/job/bluefaction/s1/marksman
	title = "BAF Squad 1 Des. Marksman"
	squad = 1
	rank_abbreviation = "1-DM"
*/

/datum/job/bluefaction/s2/sl
	title = "BAF Squad 2 Squadleader"
	squad = 2
	is_squad_leader = TRUE
	rank_abbreviation = "2-Sgt"
/datum/job/bluefaction/s2/pvt
	title = "BAF Squad 2 Private"
	squad = 2
	rank_abbreviation = "2-Pvt"
/datum/job/bluefaction/s2/corpsman
	title = "BAF Squad 2 Corpsman"
	is_medic = TRUE
	squad = 2
	rank_abbreviation = "2-Corpsman"
/datum/job/bluefaction/s2/machinegunner
	title = "BAF Squad 2 Machinegunner"
	squad = 2
	rank_abbreviation = "2-MG"
/*
/datum/job/bluefaction/s2/marksman
	title = "BAF Squad 2 Des. Marksman"
	squad = 2
	rank_abbreviation = "2-DM"
*/

/datum/job/bluefaction/s3/sl
	title = "BAF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE
	rank_abbreviation = "3-Sgt"
/datum/job/bluefaction/s3/pvt
	title = "BAF Squad 3 Private"
	squad = 3
	rank_abbreviation = "3-Pvt"
/datum/job/bluefaction/s3/corpsman
	title = "BAF Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
	rank_abbreviation = "3-Corpsman"
/datum/job/bluefaction/s3/machinegunner
	title = "BAF Squad 3 Machinegunner"
	squad = 3
	rank_abbreviation = "3-MG"
/*
/datum/job/bluefaction/s3/marksman
	title = "BAF Squad 3 Des. Marksman"
	squad = 3
	rank_abbreviation = "3-DM"
*/

/datum/job/bluefaction/recon
	title = "BAF Recon"
	squad = 4
	rank_abbreviation = "4-Recon"
/*
/datum/job/bluefaction/armored/sl
	title = "BAF Armored Squadleader"
	is_squad_leader = TRUE
	squad = 5
	rank_abbreviation = "5-Tank Sgt"
/datum/job/bluefaction/armored/crew
	title = "BAF Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"

/datum/job/bluefaction/at
	title = "BAF Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"
*/

/datum/job/bluefaction/engineer
	title = "BAF Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"

/datum/job/bluefaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Blugoslavia"
	if(is_squad_leader)
		map.faction2_squad_leaders[squad] = H
	var/area/A = get_area(get_turf(H))
	
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_tigerstripes(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform

//armor
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(armor, H)

//helmet
	if (findtext(title, "Squadleader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_blugoslavia(H), slot_r_hand)
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_blugoslavia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_r_hand)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
	else if ((findtext(title, "Sniper") || findtext(title, "Recon")) && (A.climate == "taiga" || A.climate == "tundra"))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava/snow(H), slot_wear_mask)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/white(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava(H), slot_wear_mask)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/green(H), slot_head)

//equipment
	if (findtext(title, "Squadleader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/key/bluefaction, slot_l_store)

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
		var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
	else if (!findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
		var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(H)
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
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/bluefaction(null)
		uniform.attackby(armband, H)

	if (findtext(title, "Machinegunner"))
		if(A.climate == "taiga" || A.climate == "tundra")
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/blue/white/mg(H), slot_belt)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/blue/mg(H), slot_belt)
	else if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.setStat("rifle", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/mosin(null)
		if(A.climate == "taiga" || A.climate == "tundra")
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white/recon(H), slot_belt)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/recon(H), slot_belt)
		uniform.attackby(webbing, H)
	else if  (findtext(title, "Des. Marksman"))
		var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd(null)
		uniform.attackby(webbing, H)
		if(A.climate == "taiga" || A.climate == "tundra")
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white/marksman(H), slot_belt)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/marksman(H), slot_belt)
	else if (findtext(title, "Engineer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper(H), slot_belt)
		var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak47(null)
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
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
			else
				var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak47(null)
				uniform.attackby(webbing, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/full(H), slot_belt)
		
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/black(H), slot_gloves)
	
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
	return TRUE

/datum/job/bluefaction/navy/captain
	title = "BNF Captain"
	is_commander = TRUE
	is_navy = TRUE
	max_positions = 1
	rank_abbreviation = "Captain"
	additional_languages = list("Redmenian" = 100)
	
/datum/job/bluefaction/navy/petty
	title = "BNF Petty Officer"
	is_squad_leader = TRUE
	is_navy = TRUE
	max_positions = 10
	rank_abbreviation = "PO"
	squad = 1
/datum/job/bluefaction/navy/one
	is_navy = TRUE
	title = "BNF Sailor"
	squad = 1
	rank_abbreviation = "Sailor"

/datum/job/bluefaction/navy/marine/sl
	is_navy = TRUE
	title = "BNF Marine Squadleader"
	is_squad_leader = TRUE
	max_positions = 5
	rank_abbreviation = "Sgt."
	squad = 2
/datum/job/bluefaction/navy/marine/soldier
	is_navy = TRUE
	title = "BNF Marine"
	max_positions = 20
	rank_abbreviation = "Pvt."
	squad = 2
/datum/job/bluefaction/navy/doctor
	is_navy = TRUE
	title = "BNF Doctor"
	rank_abbreviation = "Dr."
	max_positions = 6
	is_medic = TRUE
	
/datum/job/bluefaction/navy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Blugoslavia"
	if(is_squad_leader)
		map.faction2_squad_leaders[squad] = H
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//armor and clothes
	if (findtext(title, "Marine"))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni(H), slot_w_uniform)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b3/blue(null)
		uniform.attackby(armor, H)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/blugoslavian_sailor(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
//equipment
	if (findtext(title, "Petty Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_blugoslavia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	else if (findtext(title, "Captain"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap_blugoslavia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	else if (findtext(title, "Marine"))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/nvg(H), slot_eyes)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
		var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog(src)
		SP.attached(null,HGUN,TRUE)
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,HGUN,TRUE)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/us_sailor_hat/blugoslavia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/lifejacket/blue(H), slot_wear_suit)
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
				var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak47(null)
				uniform.attackby(webbing, H)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/full(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.make_artillery_scout()
	return TRUE

/datum/job/bluefaction/civilian
	title = "Blugoslavian Civilian"
	rank_abbreviation = ""
	spawn_location = "JoinLateBlue"
	uses_squads = FALSE
	can_be_female = TRUE
	is_civilizations = TRUE
	additional_languages = list("Redmenian" = 15)
	min_positions = 999
	max_positions = 999

/datum/job/bluefaction/civilian/equip(mob/living/human/H)
	if (!H)	return FALSE
	H.nationality = "Blugoslavia"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/blugoslavia/standard(H), slot_w_uniform)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/bluefaction(null)
	uniform.attackby(armband, H)
//equipment

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
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