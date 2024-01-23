/datum/job/pirates/redfaction
	title = "Red Faction"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	is_event = TRUE
	uses_squads = TRUE
	squad = 0
	additional_languages = list("Blugoslavian" = 15)
	min_positions = 1
	max_positions = 999
	selection_color = "#CC0000"

/datum/job/pirates/redfaction/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/pirates/redfaction/civilian
	title = "Redmenian Civilian"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_civilizations = TRUE
	additional_languages = list("Blugoslavian" = 15)
	min_positions = 999
	max_positions = 999

/datum/job/pirates/redfaction/rotstadt_fighter
	title = "RPR Fighter"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_rotstadt = TRUE
	is_event = TRUE
	additional_languages = list("Blugoslavian" = 89)
	min_positions = 999
	max_positions = 999

/datum/job/pirates/redfaction/rotstadt_medic
	title = "RPR Doctor"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_rotstadt = TRUE
	is_event = TRUE
	is_medic = TRUE
	additional_languages = list("Blugoslavian" = 89)
	min_positions = 1
	max_positions = 2

/datum/job/pirates/redfaction/rotstadt_commander
	title = "RPR Commander"
	rank_abbreviation = ""
	spawn_location = "JoinLateRed"
	uses_squads = FALSE
	can_be_female = TRUE
	is_rotstadt = TRUE
	is_event = TRUE
	is_commander = TRUE
	additional_languages = list("Blugoslavian" = 89)
	min_positions = 1
	max_positions = 1

/datum/job/pirates/redfaction/commander
	is_commander = TRUE
	title = "RDF Commander"
	rank_abbreviation = "CO-Cpt."
	additional_languages = list("Blugoslavian" = 100)
/datum/job/pirates/redfaction/officer
	is_commander = TRUE
	title = "RDF Officer"
	rank_abbreviation = "XO-Lt."
	additional_languages = list("Blugoslavian" = 100)

/datum/job/pirates/redfaction/doctor
	title = "RDF Doctor"
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
	rank_abbreviation = "2-Sgt"
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

/datum/job/pirates/redfaction/s3/sl
	title = "RDF Squad 3 Squadleader"
	squad = 3
	is_squad_leader = TRUE
	rank_abbreviation = "3-Sgt"
/datum/job/pirates/redfaction/s3/pvt
	title = "RDF Squad 3 Private"
	squad = 3
	rank_abbreviation = "3-Pvt"
/datum/job/pirates/redfaction/s3/corpsman
	title = "RDF Squad 3 Corpsman"
	is_medic = TRUE
	squad = 3
	rank_abbreviation = "3-Corpsman"
/datum/job/pirates/redfaction/s3/machinegunner
	title = "RDF Squad 3 Machinegunner"
	squad = 3
	rank_abbreviation = "3-MG"

/datum/job/pirates/redfaction/recon
	title = "RDF Recon"
	squad = 4
	rank_abbreviation = "4-Recon"

/datum/job/pirates/redfaction/armored/sl
	title = "RDF Armored Squadleader"
	squad = 5
	is_squad_leader = TRUE
	rank_abbreviation = "5-Tank Sgt"
/datum/job/pirates/redfaction/armored/crew
	title = "RDF Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"

/datum/job/pirates/redfaction/at
	title = "RDF Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"

/datum/job/pirates/redfaction/engineer
	title = "RDF Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"

/datum/job/pirates/redfaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Redmenia"
	if(is_squad_leader)
		map.faction1_squad_leaders[squad] = H
//shoes
	var/area/A = get_area(get_turf(H))
	if (A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/grey(H), slot_shoes)
	else if (!findtext(title, "RPR Fighter"))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/brown(H), slot_shoes)
//clothes
	if (!findtext(title, "RPR"))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/redmenia/standard/modern(H), slot_w_uniform)
	else
		if (findtext(title, "RPR Commander"))
			H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
		else
			var/rand_uni = rand(1,4)
			switch (rand_uni)
				if (1)
					H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
				if (2)
					H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
				if (3)
					var/obj/item/clothing/under/customuniform/CU = new /obj/item/clothing/under/customuniform(null)
					CU.shirtcolor = pick ("#ffbaba", "#ff7b7b", "#ff5252", "#ab1f1f", "#a70000", "#800020", "#361414", "#a32525", "#c25d5d", "#EFEFEF", "#4A403A")
					CU.pantscolor = pick ("#313345", "#777777", "#555555", "#333333", "#111111", "#494960", "#94989a", "#141627", "#373429", "#25231c", "#5c5745")
					var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "[CU.base_icon]_pants")
					pants.color = CU.pantscolor
					var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "[CU.base_icon]_shirt")
					shirt.color = CU.shirtcolor
					var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custom_belt")
					CU.overlays += pants
					CU.overlays += shirt
					CU.overlays += belt
					CU.update_icon()
					H.equip_to_slot_or_del (CU, slot_w_uniform)
					H.update_icons(1)
					spawn(6)
						CU.uncolored = FALSE
				if (4)
					var/obj/item/clothing/under/customtrackpants/TP = new /obj/item/clothing/under/customtrackpants(null)
					TP.pantscolor = pick ("#ff5252", "#ab1f1f", "#a70000", "#800020", "#361414", "#a32525", "#c25d5d", "#4A403A", "#141627",)
					TP.sidescolor = "#EFEFEF"
					TP.shirtcolor = pick ("#EFEFEF", "#b8ad8a", "#d9dddc", "#3c3b3c")
					var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "trackpants_custom_pants")
					pants.color = TP.pantscolor
					var/image/sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "trackpants_custom_sides")
					sides.color = TP.sidescolor
					var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "trackpants_custom_shirt")
					shirt.color = TP.shirtcolor
					TP.overlays += pants
					TP.overlays += sides
					TP.overlays += shirt
					TP.update_icon()
					var/obj/item/clothing/suit/storage/jacket/customtracksuit/TS = new /obj/item/clothing/suit/storage/jacket/customtracksuit(null)
					TS.basecolor = TP.pantscolor
					TS.linescolor = "#EFEFEF"
					var/image/base = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customtracksuit_base")
					base.color = TS.basecolor
					var/image/lines = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customtracksuit_lines")
					lines.color = TS.linescolor
					TS.overlays += base
					TS:overlays += lines
					TS.update_icon()
					H.equip_to_slot_or_del (TP, slot_w_uniform)
					H.equip_to_slot_or_del (TS, slot_wear_suit)
					H.update_icons(1)
					spawn(6)
						TP.uncolored = FALSE
						TS.uncolored = FALSE
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (!findtext(title, "Redmenian Civilian") && !findtext(title, "RPR Fighter") && !findtext(title, "RPR Doctor"))
		var/obj/item/clothing/accessory/armor/coldwar/rb23/armor = new /obj/item/clothing/accessory/armor/coldwar/rb23(null)
		uniform.attackby(armor, H)

//equipment
	if (findtext(title, "Squadleader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_r_hand)
	else if (findtext(title, "Commander") && !findtext(title, "RPR"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_r_hand)
	else if (findtext(title, "RPR Commander"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_redmenia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/crewman(H), slot_head)
	else if ((findtext(title, "Sniper") || findtext(title, "Recon")) /*&& A.climate == "taiga" || A.climate == "tundra"*/)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
	else if (!findtext(title, "Redmenian Civilian") && !findtext(title, "RPR"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)

	if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/key/red, slot_l_store)

	if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)
	else if (findtext(title, "Machinegunner"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
	else if (findtext(title, "Anti-Tank"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/rpg7/loaded(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rpg_pack/filled_at(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
	else if (findtext(title, "Engineer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/steel, slot_l_store)
	else if (!findtext(title, "Redmenian Civilian") && !findtext(title, "Armored") && !findtext(title, "RPR"))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
		var/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
	if (findtext(title, "Redmenian Civilian") && world.time <= 6000 && prob(60)) // Under 10 minutes
		var/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4/campaign/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4/campaign(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
		if (prob(40))
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red/nomads(null)
			uniform.attackby(webbing, H)
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
	else if (findtext(title, "Doctor"))
		H.setStat("medical", STAT_MAX)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else if (!findtext(title, "Redmenian Civilian"))
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/british(null)
		uniform.attackby(armband, H)
	else
		if (findtext(title, "Machinegunner"))
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/redmg/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/redmg(H), slot_belt)
		else if (findtext(title, "Sniper") || findtext(title, "Recon"))
			H.setStat("rifle", STAT_MEDIUM_HIGH)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/mosin/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/mosin(null)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red(H), slot_belt)
			uniform.attackby(webbing, H)
		else if (findtext(title, "Engineer"))
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper, slot_belt)

		else if (!findtext(title, "Redmenian Civilian"))
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
					var/obj/item/clothing/accessory/storage/webbing/green_webbing/red/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/red/m16(null)
					uniform.attackby(webbing, H)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)

	H.setStat("machinegun", STAT_NORMAL)
	if (!findtext(title, "Redmenian Civilian") && !findtext(title, "RPR Fighter") && !findtext(title, "RPR Doctor"))
		H.make_artillery_scout()
	if (findtext(title, "Redmenian Civilian"))
		//H.civilization = civname_a
		H.make_nation()
		H.add_note("Civilization", "You are a member of the <b>[civname_a]</b> civilization.")
	if(A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/schneetarn(H), slot_wear_suit)
	if(istype(map, /obj/map_metadata/campaign/campaign8))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/lifejacket(H), slot_wear_suit)
	return TRUE

/datum/job/civilian/bluefaction
	title = "Blue Faction"
	rank_abbreviation = ""
	spawn_location = "JoinLateBlue"
	is_event = TRUE
	uses_squads = TRUE
	squad = 0
	min_positions = 1
	max_positions = 999
	additional_languages = list("Redmenian" = 15)
	selection_color = "#102f44"

/datum/job/civilian/bluefaction/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/civilian/bluefaction/civilian
	title = "Blugoslavian Civilian"
	rank_abbreviation = ""
	spawn_location = "JoinLateBlue"
	uses_squads = FALSE
	can_be_female = TRUE
	is_civilizations = TRUE
	additional_languages = list("Redmenian" = 15)
	min_positions = 999
	max_positions = 999

/datum/job/civilian/bluefaction/commander
	is_commander = TRUE
	title = "BAF Commander"
	rank_abbreviation = "CO-Cpt."
	additional_languages = list("Redmenian" = 100)
/datum/job/civilian/bluefaction/officer
	is_commander = TRUE
	title = "BAF Officer"
	rank_abbreviation = "XO-Lt."
	additional_languages = list("Redmenian" = 100)

/datum/job/civilian/bluefaction/doctor
	title = "BAF Doctor"
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
/*
/datum/job/civilian/bluefaction/s1/marksman
	title = "BAF Squad 1 Des. Marksman"
	squad = 1
	rank_abbreviation = "1-DM"
*/

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
/*
/datum/job/civilian/bluefaction/s2/marksman
	title = "BAF Squad 2 Des. Marksman"
	squad = 2
	rank_abbreviation = "2-DM"
*/

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
/*
/datum/job/civilian/bluefaction/s3/marksman
	title = "BAF Squad 3 Des. Marksman"
	squad = 3
	rank_abbreviation = "3-DM"
*/

/datum/job/civilian/bluefaction/recon
	title = "BAF Recon"
	squad = 4
	rank_abbreviation = "4-Recon"

/datum/job/civilian/bluefaction/armored/sl
	title = "BAF Armored Squadleader"
	is_squad_leader = TRUE
	squad = 5
	rank_abbreviation = "5-Tank Sgt"
/datum/job/civilian/bluefaction/armored/crew
	title = "BAF Armored Crew"
	squad = 5
	rank_abbreviation = "5-Tank"

/datum/job/civilian/bluefaction/at
	title = "BAF Anti-Tank"
	squad = 6
	rank_abbreviation = "6-AT"

/datum/job/civilian/bluefaction/engineer
	title = "BAF Engineer"
	squad = 7
	rank_abbreviation = "7-Engineer"

/datum/job/civilian/bluefaction/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.squad = squad
	H.nationality = "Blugoslavia"
	if(is_squad_leader)
		map.faction2_squad_leaders[squad] = H
//shoes
	var/area/A = get_area(get_turf(H))
	if (A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/grey(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	if (findtext(title, "Commander") || findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/blugoslavia/standard/command(H), slot_w_uniform)
	else if (findtext(title, "Squadleader"))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/blugoslavia/standard/squadlead(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/blugoslavia/standard(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (findtext(title, "Doctor") || findtext(title, "Corpsman"))
		var/obj/item/clothing/accessory/armor/coldwar/plates/b5/n34/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b5/n34/medical(null)
		uniform.attackby(armor, H)
	else if (!findtext(title, "Blugoslavian Civilian"))
		var/obj/item/clothing/accessory/armor/coldwar/plates/b5/n34/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/b5/n34(null)
		uniform.attackby(armor, H)
//equipment
	if (findtext(title, "Squadleader") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_head)
	else if (findtext(title, "Officer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_blugoslavia(H), slot_r_hand)
	else if (findtext(title, "Commander"))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_blugoslavia(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_r_hand)
	else if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
	else if ((findtext(title, "Sniper") || findtext(title, "Recon")) && A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_head)
	else if (!findtext(title, "Blugoslavian Civilian"))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/a6b47(H), slot_head)

	if (findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/key/blue, slot_l_store)

	if (findtext(title, "Sniper") || findtext(title, "Recon"))
		H.setStat("rifle", STAT_MEDIUM_HIGH)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)
	else if (findtext(title, "Des. Marksman"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd/acog(H), slot_shoulder)
	else if (findtext(title, "Machinegunner"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/rpk47(H), slot_shoulder)
	else if (findtext(title, "Anti-Tank"))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/rpg7/loaded(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rpg_pack/filled_at(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
	else if (findtext(title, "Engineer"))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/steel, slot_l_store)
	else if (!findtext(title, "Blugoslavian Civilian") && !findtext(title, "Armored"))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_l_store)
		var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
	if (findtext(title, "Blugoslavian Civilian") && world.time <= 6000 && prob(60)) // Under 10 minutes
		var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/campaign/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/campaign(H)
		H.equip_to_slot_or_del(HGUN, slot_shoulder)
		if (prob(40))
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/nomads(null)
			uniform.attackby(webbing, H)
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
	else if (findtext(title, "Doctor"))
		H.setStat("medical", STAT_MAX)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
		var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
		uniform.attackby(medicalarm, H)
	else if (!findtext(title, "Blugoslavian Civilian"))
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/armband/french(null)
		uniform.attackby(armband, H)
		if (findtext(title, "Machinegunner"))
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/bluemg/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/bluemg(H), slot_belt)
		else if (findtext(title, "Sniper") || findtext(title, "Recon"))
			H.setStat("rifle", STAT_MEDIUM_HIGH)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/mosin/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/mosin(null)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
			uniform.attackby(webbing, H)
		else if  (findtext(title, "Des. Marksman"))
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd(null)
			uniform.attackby(webbing, H)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
		else if (findtext(title, "Engineer"))
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper, slot_belt)

		else if (!findtext(title, "Blugoslavian Civilian"))
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
					var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak(null)
					uniform.attackby(webbing, H)
			if(A.climate == "taiga" || A.climate == "tundra")
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue/white(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)

	H.setStat("machinegun", STAT_NORMAL)
	if (!findtext(title, "Blugoslavian Civilian"))
		H.make_artillery_scout()
	if (findtext(title, "Blugoslavian Civilian"))
		//H.civilization = civname_b
		H.make_nation()
		H.add_note("Civilization", "You are a member of the <b>[civname_b]</b> civilization.")
	if(A.climate == "taiga" || A.climate == "tundra")
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
	return TRUE

/datum/job/civilian/bluefaction/navy/captain
	title = "BNF Captain"
	is_commander = TRUE
	is_navy = TRUE
	max_positions = 1
	rank_abbreviation = "Captain"
	additional_languages = list("Redmenian" = 100)
	
/datum/job/civilian/bluefaction/navy/petty
	title = "BNF Petty Officer"
	is_squad_leader = TRUE
	is_navy = TRUE
	max_positions = 10
	rank_abbreviation = "PO"
	squad = 1
/datum/job/civilian/bluefaction/navy/one
	is_navy = TRUE
	title = "BNF Sailor"
	squad = 1
	rank_abbreviation = "Sailor"

/datum/job/civilian/bluefaction/navy/marine/sl
	is_navy = TRUE
	title = "BNF Marine Squadleader"
	is_squad_leader = TRUE
	max_positions = 5
	rank_abbreviation = "Sgt."
	squad = 2
/datum/job/civilian/bluefaction/navy/marine/soldier
	is_navy = TRUE
	title = "BNF Marine"
	max_positions = 20
	rank_abbreviation = "Pvt."
	squad = 2
/datum/job/civilian/bluefaction/navy/doctor
	is_navy = TRUE
	title = "BNF Doctor"
	rank_abbreviation = "Dr."
	max_positions = 6
	is_medic = TRUE
	
/datum/job/civilian/bluefaction/navy/equip(var/mob/living/human/H)
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
		var/obj/item/weapon/attachment/scope/adjustable/advanced/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/acog(src)
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
				var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak(null)
				uniform.attackby(webbing, H)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/blue(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.make_artillery_scout()
	return TRUE

/datum/job/pirates/redfaction/navy/captain
	title = "IRN Captain"
	is_commander = TRUE
	is_navy = TRUE
	max_positions = 1
	rank_abbreviation = "Captain"
	additional_languages = list("Blugoslavian" = 100)
	
/datum/job/pirates/redfaction/navy/petty
	title = "IRN Petty Officer"
	is_squad_leader = TRUE
	is_navy = TRUE
	max_positions = 10
	rank_abbreviation = "PO"
	squad = 1
/datum/job/pirates/redfaction/navy/one
	is_navy = TRUE
	title = "IRN Sailor"
	squad = 1
	rank_abbreviation = "Sailor"

/datum/job/pirates/redfaction/navy/marine/sl
	is_navy = TRUE
	title = "IRN Marine Squadleader"
	is_squad_leader = TRUE
	max_positions = 5
	rank_abbreviation = "Sgt."
	squad = 2
/datum/job/pirates/redfaction/navy/marine/soldier
	is_navy = TRUE
	title = "IRN Marine"
	max_positions = 20
	rank_abbreviation = "Pvt."
	squad = 2
/datum/job/pirates/redfaction/navy/doctor
	is_navy = TRUE
	title = "IRN Doctor"
	max_positions = 6
	rank_abbreviation = "Dr."
	is_medic = TRUE

/datum/job/pirates/redfaction/navy/equip(var/mob/living/human/H)
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
		var/obj/item/weapon/attachment/scope/adjustable/advanced/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/acog(src)
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
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/red(H), slot_belt)
		H.setStat("medical", STAT_NORMAL)
	H.make_artillery_scout()
	return TRUE
