////////////////////////////////////////////////Soviet army (1985's)////////////////////////////////////////

/datum/job/russian/sovafghan/lieutenant
	title = "Soviet Army Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRUCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_afghan = TRUE
	is_soviet = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/russian/sovafghan/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/gglasses(H), slot_eyes)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_officercap(H), slot_head)

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

/datum/job/russian/sovafghan/sergeant
	title = "Soviet Army Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRUCap"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_afghan = TRUE
	is_soviet = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/russian/sovafghan/sergeant/equip(var/mob/living/human/H)
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
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Insurgents!")
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


/datum/job/russian/sovafghan/medic
	title = "Soviet Army Field Medic"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"

	is_medic = TRUE
	is_afghan = TRUE
	is_soviet = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/russian/sovafghan/medic/equip(var/mob/living/human/H)
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
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
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

/datum/job/russian/sovafghan/radop
	title = "Soviet Army Radio Operator"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"
	is_afghan = TRUE
	uses_squads = TRUE
	is_soviet = TRUE
	is_radioman = TRUE

	min_positions = 10
	max_positions = 8

/datum/job/russian/sovafghan/radop/equip(var/mob/living/human/H)
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
	H.add_note("Role", "You are a <b>[title]</b>, you're the most important person in your squad after the SL. Relay communications between the HQ and your squad, call in for artillery strikes.")
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

/datum/job/russian/sovafghan/soldier
	title = "Soviet Army Private"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRU"
	is_afghan = TRUE
	uses_squads = TRUE
	is_soviet = TRUE

	min_positions = 10
	max_positions = 100

/datum/job/russian/sovafghan/soldier/equip(var/mob/living/human/H)
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
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)
	else if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
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

/datum/job/russian/sovafghan/tanker
	title = "Soviet Army Tankist"
	rank_abbreviation = "Tanker"

	spawn_location = "JoinLateRU"

	uses_squads = TRUE
	is_afghan = TRUE
	is_soviet = TRUE

	min_positions = 10
	max_positions = 32

/datum/job/russian/sovafghan/tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_tanker(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/pilot(H), slot_eyes)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
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

/datum/job/russian/sovafghan/vdv
	title = "VDV Paratrooper"
	rank_abbreviation = "Spz. VDV"

	spawn_location = "JoinLateRUsptz"
	whitelisted = TRUE
	is_afghan = TRUE
	is_soviet = TRUE

	uses_squads = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/russian/sovafghan/vdv/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/iogboots/black(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_amoeba(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour.attackby(plates1, H)
	armour.attackby(plates2, H)
	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_vdv(H), slot_head)
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
	H.add_note("Role", "You are a <b>[title]</b>, part of the Soviet Airborne Forces. You are the best of the best; end this insurrection!")
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

/////////DRA Goverment//////////////

/datum/job/civilian/afghan/dra/governor
	title = "DRA Governor"
	rank_abbreviation = "Gov."
	spawn_location = "JoinLateDRAGov"

	is_commander = TRUE
	whitelisted = TRUE
	is_afghan = TRUE
	is_dra = TRUE
	default_language = "Arabic"
	additional_languages = list("Russian" = 100,"English" = 100)

	min_positions = 1
	max_positions = 1

/datum/job/civilian/afghan/dra/governor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_l_store)
	H.civilization = "DRA"
	if (H.f_style != "Full Beard" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache" )
		H.f_style = pick("Full Beard","Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.s_tone = rand(-85,-65)
	var/new_hair = pick("Dark Brown","Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.add_note("Role", "You are an member of the DRA Goverment, manage the region in cooperation with the Soviets!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

////////////DRA soldiers/////////////

/datum/job/civilian/afghan/dra/sergeant
	title = "DRA Sergeant"
	rank_abbreviation = "DRA Sgt."

	spawn_location = "JoinLateDRACap"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = TRUE
	is_afghan = TRUE
	is_dra = TRUE

	can_get_coordinates = TRUE
	default_language = "Arabic"
	additional_languages = list("Russian" = 30)

	min_positions = 1
	max_positions = 4

/datum/job/civilian/afghan/dra/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/coldwar/dra/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_black(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armband/red = new/obj/item/clothing/accessory/armband(null)
	uniform.attackby(red, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	H.civilization = "DRA"
	if (H.f_style != "Full Beard" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache" )
		H.f_style = pick("Full Beard","Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.s_tone = rand(-90,-70)
	var/new_hair = pick("Dark Brown","Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, responsible for leading DRA soldiers and guards in the province.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/civilian/afghan/dra/soldier
	title = "DRA Rifleman"
	rank_abbreviation = "DRA Pvt."

	spawn_location = "JoinLateDRA"
	is_afghan = TRUE
	is_dra = TRUE

	uses_squads = TRUE
	default_language = "Arabic"

	min_positions = 10
	max_positions = 40

/datum/job/civilian/afghan/dra/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/coldwar/dra/soldier, slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/red = new/obj/item/clothing/accessory/armband(null)
	uniform.attackby(red, H)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/custom/fieldcap/dra(H), slot_head)

//back
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/sks(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)

	H.civilization = "DRA"
	if (H.f_style != "Shaved" && H.f_style != "Full Beard" && H.f_style != "Selleck Mustache" && H.f_style != "Hulk Hogan Mustache" && H.f_style != "Van Dyke Mustache" && H.f_style != "Waston Mustache" )
		H.f_style = pick("Shaved","Full Beard","Selleck Mustache","Watson Mustache","Hulk Hogan Mustache","Van Dyke Mustache")
	if (H.h_style != "Bald" && H.f_style != "Crewcut" && H.f_style != "Undercut" && H.f_style != "Short Hair" && H.f_style != "Cut Hair" && H.f_style != "Skinhead" && H.f_style != "Average Joe" && H.f_style != "Fade" && H.f_style != "Combover" && H.f_style != "Gelled Back" && H.f_style != "Slick" && H.f_style != "Balding Hair" && H.f_style != "Joestar")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Gelled Back","Slick","Balding Hair","Joestar")
	H.s_tone = rand(-95,-75)
	var/new_hair = pick("Dark Brown","Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt of the DRA. Follow orders and defeat the terrorists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/*/datum/job/afghan/civilian/dra/palg
	title = "DRA Palace Guard"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRN"


	uses_squads = TRUE

	min_positions = 10
	max_positions = 45

/datum/job/afghan/civilian/dra/palg(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/plate = new /obj/item/clothing/accessory/armor/modern(null)
	uniform.attackby(plate, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
	var/obj/item/clothing/accessory/ruffle/neck = new /obj/item/clothing/accessory/ruffle(null)
	uniform.attackby(neck, H)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)

	H.civilization = "Afgov"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt of the DRA. Follow orders and defeat the terrorists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

////////////////////////////////////////////////Afghan civilians////////////////////////////////////////

/datum/job/civilian/afghan/facworker
	title = "factory worker"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 45

/datum/job/civilian/afghan/facworker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)

	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local factory worker")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afghan/miner
	title = "miner"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 50

/datum/job/civilian/afghan/miner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pickaxe/stone(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)

	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local miner, good luck mining!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afghan/villager
	title = "villager"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 90

/datum/job/civilian/afghan/villager/equip(var/mob/living/human/H)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)

	H.civilization = "civilian"

	H.add_note("Role", "You are a <b>[title]</b>,a poor villager")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afghan/doctor
	title = "Doctor"
	en_meaning = " "
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 15

/datum/job/civilian/afghan/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/paramedics(H), slot_l_store)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local doctor, keep your fellow citizens healthy!!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	give_random_name(H)
	return TRUE

/datum/job/civilian/afghan/urbanciv
	title = "urban unemployed civilian"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 45

/datum/job/civilian/afghan/urbanciv/equip(var/mob/living/human/H)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)

	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, a local civilian,you are unemployed. Good luck finding a job!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)
	return TRUE

/datum/job/civilian/afghan/ubrec
	title = "factory overseer"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 2

/datum/job/civilian/afghan/ubrec/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)
	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local factory overseer, command your workers and recruit new people!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afghan/ubmin
	title = "Mine overseer"
	en_meaning = " "
	rank_abbreviation = "Overseer"

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 2

/datum/job/civilian/afghan/ubmin/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)
	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[H.title]</b>, an local mine overseer, command your workers and recruit new people!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE */
////////////////////////////////////////////////Mujahideen////////////////////////////////////////

/datum/job/arab/mujahideen/leader
	title = "Mujahideen Leader"
	rank_abbreviation = "Leader"

	spawn_location = "JoinLateAR"
	is_afghan = TRUE
	is_muj = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/arab/mujahideen/leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/british = new /obj/item/clothing/accessory/armor/modern(null)
	uniform.attackby(british, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban/imam(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a4/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)

	H.civilization = "Mujahideen"
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard")
		H.f_style = pick("Full Beard","Medium Beard","Long Beard")
	H.s_tone = rand(-92,-80)
	var/new_hair = pick("Dark Brown","Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.add_note("Role", "You are an <b>[title]</b>, an islamic leader. Lead the Holy war against the red menace!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	give_random_name(H)


	return TRUE

/datum/job/arab/mujahideen/insurgent
	title = "Insurgent"
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"
	is_afghan = TRUE
	is_muj = TRUE


	min_positions = 10
	max_positions = 250

/datum/job/mujahideen/insurgent/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab3(H), slot_w_uniform)
//gun and belt
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a4/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)

	H.civilization = "Mujahideen"
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard")
		H.f_style = pick("Full Beard","Medium Beard","Long Beard")
	H.s_tone = rand(-92,-80)
	var/new_hair = pick("Dark Brown","Black")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.add_note("Role", "You are a <b>[title]</b>, an islamic rifleman militia. Use guerrila warfare tactics to defeat the infidels!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE