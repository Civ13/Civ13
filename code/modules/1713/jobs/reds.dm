////////////////////////////////////////////////Soviet army (1985's)////////////////////////////////////////

/datum/job/russian/coldwar/lieutenant
	title = "Soviet Army Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRUCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_reds = TRUE
	
	min_positions = 1
	max_positions = 2

/datum/job/russian/coldwar/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
//head
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/gglasses(H), slot_eyes)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_vdv(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour.attackby(plates1, H)
	armour.attackby(plates2, H)
	uniform.attackby(armour, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/soviet/sovk = new/obj/item/weapon/key/soviet(null)
	KC.attackby(sovk,H)
	H.equip_to_slot_or_del(KC, slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Soviet Army"
	give_random_name(H)

	if (H.f_style != "Shaved" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache")
		H.f_style = pick("Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache","Shaved")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.s_tone = rand(-40,-25)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/russian/coldwar/sergeant
	title = "Soviet Army Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRUCap"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_reds = TRUE
	
	min_positions = 2
	max_positions = 8

/datum/job/russian/coldwar/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/sov_ushanka_new(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	var/obj/item/ammo_magazine/ak74/mag = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag, H)
	var/obj/item/ammo_magazine/ak74/mag2 = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag2, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)

	H.civilization = "Soviet Army"
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache")
		H.f_style = pick("Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache","Shaved")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.s_tone = rand(-40,-25)
	H.add_note("Role", "You are a <b>[title]</b>, a non-comissioned officer, lead your squad in the diverse operations and follow the orders of your superior officers!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE


/datum/job/russian/coldwar/medic
	title = "Soviet Army Field Medic"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"

	is_medic = TRUE
	is_reds = TRUE
	
	min_positions = 2
	max_positions = 8

/datum/job/russian/coldwar/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet_medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Soviet Army"
	give_random_name(H)
	H.s_tone = rand(-40,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow comrades alive and healthy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/russian/coldwar/radop
	title = "Soviet Army Radio Operator"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_radioman = TRUE
	is_reds = TRUE

	min_positions = 10
	max_positions = 8

/datum/job/russian/coldwar/radop/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)
	else if(prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	var/obj/item/ammo_magazine/ak74/mag = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag, H)
	var/obj/item/ammo_magazine/ak74/mag2 = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag2, H)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Soviet Army"
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache")
		H.f_style = pick("Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache","Shaved")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.s_tone = rand(-40,-25)
	H.add_note("Role", "You are a <b>[title]</b>, you're the most important person in your squad after the squad leader. Relay communications between the HQ and your squad, call in for artillery strikes.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/russian/coldwar/soldier
	title = "Soviet Army Private"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_reds = TRUE
	
	min_positions = 10
	max_positions = 100

/datum/job/russian/coldwar/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)
	else if(prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fieldcap/afghanka(H), slot_head)
//back
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)
	else if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_svd(H), slot_belt)
	else if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
		var/obj/item/ammo_magazine/ak74/mag = new /obj/item/ammo_magazine/ak74(null)
		uniform.attackby(mag, H)
		var/obj/item/ammo_magazine/ak74/mag2 = new /obj/item/ammo_magazine/ak74(null)
		uniform.attackby(mag2, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
		var/obj/item/ammo_magazine/ak74/mag = new /obj/item/ammo_magazine/ak74(null)
		uniform.attackby(mag, H)
		var/obj/item/ammo_magazine/ak74/mag2 = new /obj/item/ammo_magazine/ak74(null)
		uniform.attackby(mag2, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(33))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/sovpack(H), slot_back)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Soviet Army"
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Selleck Mustache")
		H.f_style = pick("Selleck Mustache","Shaved")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Joestar")
	H.s_tone = rand(-40,-25)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/russian/coldwar/tanker
	title = "Soviet Army Tankist"
	rank_abbreviation = "Tanker"

	spawn_location = "JoinLateRU"

	uses_squads = TRUE
	is_reds = TRUE
	
	min_positions = 10
	max_positions = 18

/datum/job/russian/coldwar/tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_tanker(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/pilot(H), slot_eyes)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	if (prob(50))
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
		uniform.attackby(armour2, H)
		var/obj/item/ammo_magazine/ak74/mag = new /obj/item/ammo_magazine/ak74(null)
		uniform.attackby(mag, H)
		var/obj/item/ammo_magazine/ak74/mag2 = new /obj/item/ammo_magazine/ak74(null)
		uniform.attackby(mag2, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
//jacket
	H.s_tone = rand(-40,-25)
	H.civilization = "Soviet Army"
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache")
		H.f_style = pick("Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache","Shaved")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.add_note("Role", "You are a <b>[title]</b>, a tankmen. Follow orders and defeat the enemy with heavy soviet armor!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/russian/coldwar/spez
	title = "Spetznaz GRU"
	rank_abbreviation = "Spz."

	spawn_location = "JoinLateRU"
	whitelisted = TRUE
	is_reds = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/russian/coldwar/spez/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/iogboots/black(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/sov_klmk(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/sov_kzs(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/fieldcap/afghanka(H), slot_head)
//back
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_spz(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_svd(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	H.civilization = "Soviet Army"
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache")
		H.f_style = pick("Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache","Shaved")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.add_note("Role", "You are a <b>[title]</b>, part of the Main Intelligence Directorate. You are the best of the best; end this insurrection!")
	H.s_tone = rand(-40,-25)
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

////////////////////////////////////////////////Americans (1985)////////////////////////////////////////

/datum/job/american/modernciv
	title = "American Civilian"
	rank_abbreviation = ""
	
	spawn_location = "JoinLateRN"

	can_be_female = TRUE
	is_reds = TRUE
	
	min_positions = 1
	max_positions = 1000

/datum/job/american/modernciv/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
//clothes
	var/pickuni = rand(1,5)
	if (pickuni == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern1(H), slot_w_uniform)
	if (pickuni == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
	if (pickuni == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern3(H), slot_w_uniform)
	if (pickuni == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern4(H), slot_w_uniform)
	if (pickuni == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern7(H), slot_w_uniform)
	if (pickuni == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	if (pickuni == 7)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
	H.add_note("Role", "You are a proud American citizen! Defend against the Red Menace!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE