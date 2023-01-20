////////////////////////////////////////////////Soviet army (1985's)////////////////////////////////////////

/datum/job/russian/coldwar/lieutenant
	title = "Soviet Armed Forces Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRUCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_reds = TRUE

	can_get_coordinates = TRUE

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
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/pso1(H), slot_shoulder)
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
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Soviet Armed Forces"
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
	title = "Soviet Armed Forces Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRUCap"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_reds = TRUE

	can_get_coordinates = TRUE

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
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)

	H.civilization = "Soviet Armed Forces"
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
	title = "Soviet Armed Forces Field Medic"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"

	is_medic = TRUE

	is_reds = TRUE

	min_positions = 2
	max_positions = 10

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
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Soviet Armed Forces"
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
	title = "Soviet Armed Forces Radio Operator"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_radioman = TRUE
	is_reds = TRUE


	min_positions = 1
	max_positions = 10

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
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Soviet Armed Forces"
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
	title = "Soviet Armed Forces Private"
	rank_abbreviation = "Ryad."

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_reds = TRUE


	min_positions = 1
	max_positions = 200

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
	title = "Soviet Armed Forces Tanker"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"

	uses_squads = TRUE
	is_reds = TRUE

	min_positions = 1
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
	title = "Spetsnaz GRU"
	rank_abbreviation = "Spz."

	spawn_location = "JoinLateRU"
	whitelisted = TRUE

	is_reds = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/russian/coldwar/spez/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/iogboots/black(H), slot_shoes)
//clothes
	var/randuni = rand(1,3)
	switch(randuni)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/sov_klmk(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/gorka(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/sov_kzs(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_spez(H), slot_head)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/sovietbala(H), slot_wear_mask)
//back
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/pso1(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_spz(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_svd(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov/silenced(H), slot_r_hand)
	H.civilization = "Soviet Armed Forces"
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache")
		H.f_style = pick("Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache","Shaved")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.add_note("Role", "You are a <b>[title]</b>, part of the Main Intelligence Directorate. You are an elite soldier. Assist the regular troops with your high skills.")
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
//clothes
	if (prob(75))
		var/pickoutfit = rand(1,8)
		switch(pickoutfit)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/modern1(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/brown(H), slot_shoes)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/modern3(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
			if (4)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/modern4(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/brown(H), slot_shoes)
			if (5)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/modern7(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
			if (6)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
			if (7)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
			if (8)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/mafia(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/white(H), slot_shoes)

		H.add_note("Role", "You are a proud American citizen! Defend against the Red Menace!")
		H.setStat("strength", STAT_NORMAL)
		H.setStat("crafting", STAT_NORMAL)
		H.setStat("rifle", STAT_NORMAL)
		H.setStat("dexterity", STAT_NORMAL)
		H.setStat("swords", STAT_NORMAL)
		H.setStat("pistol", STAT_NORMAL)
		H.setStat("bows", STAT_NORMAL)
		H.setStat("medical", STAT_MEDIUM_LOW)
		H.setStat("machinegun", STAT_NORMAL)
		give_random_name(H)
	else
		var/loadout = rand(1,7)
		switch(loadout)
			if(1)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/paramedic(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
				var/obj/item/clothing/accessory/stethoscope/stet = new /obj/item/clothing/accessory/stethoscope(null)
				var/obj/item/clothing/under/uniform = H.w_uniform
				uniform.attackby(stet, H)
				H.add_note("Role", "You are a Paramedic. Tend to your fellow American citizens!")
				H.setStat("strength", STAT_NORMAL)
				H.setStat("crafting", STAT_NORMAL)
				H.setStat("rifle", STAT_NORMAL)
				H.setStat("dexterity", STAT_MEDIUM_HIGH)
				H.setStat("swords", STAT_NORMAL)
				H.setStat("pistol", STAT_NORMAL)
				H.setStat("bows", STAT_NORMAL)
				H.setStat("medical", STAT_VERY_HIGH)
				give_random_name(H)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
				H.equip_to_slot_or_del(new /obj/item/clothing/under/traffic_police, slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
				H.equip_to_slot_or_del(new /obj/item/clothing/head/traffic_police(H), slot_head)
				if (prob(30))
					H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/police(H), slot_wear_suit)
				var/obj/item/clothing/under/uniform1 = H.w_uniform
				var/obj/item/clothing/accessory/holster/hip/hiph = new /obj/item/clothing/accessory/holster/hip(null)
				uniform1.attackby(hiph, H)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/coltpolicepositive(H), slot_l_hand)
				H.add_note("Role", "You are a Police Officer. Keep your fellow American citizens safe!")
				H.setStat("strength", STAT_MEDIUM_HIGH)
				H.setStat("crafting", STAT_NORMAL)
				H.setStat("rifle", STAT_NORMAL)
				H.setStat("dexterity", STAT_MEDIUM_HIGH)
				H.setStat("swords", STAT_NORMAL)
				H.setStat("pistol", STAT_HIGH)
				H.setStat("bows", STAT_NORMAL)
				H.setStat("medical", STAT_MEDIUM_LOW)
				give_random_name(H)
			if (3)
			//shoes
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/workboots(H), slot_shoes)
			//clothes
				H.equip_to_slot_or_del(new /obj/item/clothing/under/engi(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/hazard(H), slot_wear_suit)
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
			//head
				H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/hardhaty(H), slot_head)
			//back
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/full(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/weapon/material/shovel/steel(H), slot_back)
				H.add_note("Role", "You are a Construction Worker. Help your fellow citizens build barricades and repair structures against the invaders.")
				H.setStat("strength", STAT_MEDIUM_HIGH)
				H.setStat("crafting", STAT_HIGH)
				H.setStat("rifle", STAT_NORMAL)
				H.setStat("dexterity", STAT_NORMAL)
				H.setStat("swords", STAT_NORMAL)
				H.setStat("pistol", STAT_NORMAL)
				H.setStat("bows", STAT_NORMAL)
				H.setStat("medical", STAT_LOW)
				give_random_name(H)
			if (4)
			//shoes
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
			//clothes
				H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)
			//head
				H.equip_to_slot_or_del(new /obj/item/clothing/head/chefhat(H), slot_head)
			//back
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/full(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_r_hand)
				H.add_note("Role", "You are a Cook. Use your cooking skills to defeat the invaders.")
				H.setStat("strength", STAT_MEDIUM_HIGH)
				H.setStat("crafting", STAT_MEDIUM_LOW)
				H.setStat("rifle", STAT_NORMAL)
				H.setStat("dexterity", STAT_NORMAL)
				H.setStat("swords", STAT_MEDIUM_HIGH)
				H.setStat("pistol", STAT_NORMAL)
				H.setStat("bows", STAT_NORMAL)
				H.setStat("medical", STAT_LOW)
				give_random_name(H)
			if (5)
			//shoes
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
			//clothes
				H.equip_to_slot_or_del(new /obj/item/clothing/under/wastelander(H), slot_w_uniform)
			//head
				H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
			//back
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump(H), slot_shoulder)
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
				var/obj/item/clothing/under/uniform = H.w_uniform
				var/obj/item/clothing/accessory/storage/webbing/shotgun_bandolier/band = new /obj/item/clothing/accessory/storage/webbing/shotgun_bandolier(null)
				uniform.attackby(band, H)
				H.add_note("Role", "You are a Hunter. Defend your town against the invaders.")
				H.setStat("strength", STAT_NORMAL)
				H.setStat("crafting", STAT_NORMAL)
				H.setStat("rifle", STAT_MEDIUM_HIGH)
				H.setStat("dexterity", STAT_MEDIUM_HIGH)
				H.setStat("swords", STAT_NORMAL)
				H.setStat("pistol", STAT_NORMAL)
				H.setStat("bows", STAT_MEDIUM_HIGH)
				H.setStat("medical", STAT_LOW)
				give_random_name(H)
			if (6)
			//shoes
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
			//clothes
				H.equip_to_slot_or_del(new /obj/item/clothing/under/firefighter(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/firefighter(H), slot_wear_suit)
			//head
				H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/firefighter(H), slot_head)
			//back
				H.equip_to_slot_or_del(new /obj/item/weapon/material/twohanded/fireaxe(H), slot_shoulder)
				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/firefighter(H), slot_gloves)
				H.equip_to_slot_or_del(new /obj/item/weapon/fire_extinguisher(H), slot_r_hand)
				H.add_note("Role", "You are a Firefighter. Assist your fellow citizens against the invasion.")
				H.setStat("strength", STAT_MEDIUM_HIGH)
				H.setStat("crafting", STAT_NORMAL)
				H.setStat("rifle", STAT_NORMAL)
				H.setStat("dexterity", STAT_MEDIUM_HIGH)
				H.setStat("swords", STAT_NORMAL)
				H.setStat("pistol", STAT_NORMAL)
				H.setStat("bows", STAT_NORMAL)
				H.setStat("medical", STAT_MEDIUM_HIGH)
				give_random_name(H)
			if (7)
			//shoes
				H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/white(H), slot_shoes)
			//clothes
				H.equip_to_slot_or_del(new /obj/item/clothing/under/cartel(H), slot_w_uniform)
				H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
				var/obj/item/weapon/storage/briefcase/BC = new /obj/item/weapon/storage/briefcase(null)
				var/obj/item/weapon/reagent_containers/pill/cocaine/CK = new /obj/item/weapon/reagent_containers/pill/cocaine(null)
				var/obj/item/weapon/gun/projectile/submachinegun/tec9/TC = new /obj/item/weapon/gun/projectile/submachinegun/tec9(null)
				var/obj/item/ammo_magazine/tec9/AT = new /obj/item/ammo_magazine/tec9(null)
				BC.attackby(CK, H)
				BC.attackby(CK, H)
				BC.attackby(CK, H)
				BC.attackby(TC, H)
				BC.attackby(AT, H)
				BC.attackby(AT, H)
				H.equip_to_slot_or_del(BC, slot_r_hand)
				H.add_note("Role", "You are a Colombian Businessman. Those commies are messing with the wrong guy, time for them to pay back for ruining your business opportunities!")
				H.setStat("strength", STAT_MEDIUM_HIGH)
				H.setStat("crafting", STAT_MEDIUM_LOW)
				H.setStat("rifle", STAT_MEDIUM_HIGH)
				H.setStat("dexterity", STAT_NORMAL)
				H.setStat("swords", STAT_NORMAL)
				H.setStat("pistol", STAT_MEDIUM_HIGH)
				H.setStat("bows", STAT_NORMAL)
				H.setStat("medical", STAT_MEDIUM_LOW)
				H.name = H.species.get_random_spanish_name(H.gender)
				H.real_name = H.name
	return TRUE

/datum/job/american/coldwar/ssergeant
	title = "US Army Staff Sergeant"
	rank_abbreviation = "SSgt."

	spawn_location = "JoinLateRNSL"

	can_be_female = FALSE
	is_reds = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE
	can_get_coordinates = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/coldwar/ssergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a2(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/stanag, slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/signal(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Guide your squad of survivors to protect your homeland at all costs.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


/datum/job/american/coldwar/radop
	title = "US Army Radio Operator"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRN2"

	can_be_female = FALSE
	is_reds = TRUE
	uses_squads = TRUE
	is_radioman = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/coldwar/radop/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a2(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/stanag, slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You're responsible for your squad's communications.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

/datum/job/american/coldwar/dmr
	title = "US Army Designated Marksman"
	rank_abbreviation = "Spc."

	spawn_location = "JoinLateRN2"

	can_be_female = FALSE
	is_reds = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/coldwar/dmr/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14/sniper/m21(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/m14, slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Support your squad by providing accurate fire at distant enemies, as well as their positions.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

/datum/job/american/coldwar/mgunner
	title = "US Army Automatic Rifleman"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRN2"

	can_be_female = FALSE
	is_reds = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/coldwar/mgunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m249(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/green/m249, slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, one of the few survivors of your platoon. Follow your sergeant's orders and protect the civilians from the invaders.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

/datum/job/american/coldwar/private
	title = "US Army Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRN2"

	can_be_female = FALSE
	is_reds = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/american/coldwar/private/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a2(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/stanag, slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(armor, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, one of the few survivors of your platoon. Follow your sergeant's orders and protect the civilians from the invaders.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)

/datum/job/american/coldwar/tanker
	title = "US Army Crewman"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRNT"

	can_be_female = FALSE
	is_reds = TRUE
	is_tanker = FALSE

	min_positions = 1
	max_positions = 8

/datum/job/american/coldwar/tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo, slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/crewman(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/american(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/(null)
	uniform.attackby(armor, H)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Follow orders and use your armor to defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE