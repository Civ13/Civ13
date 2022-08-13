/datum/job/civilian/ukrainian/lieutenant
	title = "Starshiy Leitenant"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "Stl."

	spawn_location = "JoinLateRNCap"

	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_ww2 = FALSE
	is_upa = FALSE
	is_ukrainerussowar = TRUE
	is_modernday = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/ukrainian/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ukraine(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/ukraine(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead the Ukrainian Ground Forces in the fight against the invaders!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.") //Partisan mechanics are kept because ukrainians are on defense and rely on traps and not just soldiers to cause enemy casualties
	H.setStat("strength", STAT_MAX)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MAX)
	H.setStat("dexterity", STAT_MAX)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MAX)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MAX)
	return TRUE

/datum/job/civilian/ukrainian/sergeant
	title = "Serzhant"
	en_meaning = "Sergeant"
	rank_abbreviation = "Srz."

	spawn_location = "JoinLateRNSL"

	uses_squads = TRUE
	is_squad_leader = TRUE
	is_ww2 = FALSE
	is_upa = FALSE
	is_ukrainerussowar = TRUE
	is_modernday = FALSE

	min_positions = 4
	max_positions = 8

/datum/job/civilian/ukrainian/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ukraine(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/ukraine(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine(null)
	uniform.attackby(platecarrier_ukraine, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad of the Ukrainian Ground Forces in the fight against the invaders!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE

/datum/job/civilian/ukrainian/infantry
	title = "UGF Soldat"
	en_meaning = "Ukrainian Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	uses_squads = TRUE
	is_ww2 = FALSE
	is_upa = FALSE
	is_ukrainerussowar = TRUE
	is_modernday = FALSE

	min_positions = 25
	max_positions = 80 ////lowpop map, not a grand scale offensive. If ukrainians somehow lose 80 troops, they deserve to lose.

/datum/job/civilian/ukrainian/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ukraine(H), slot_w_uniform)

//head
	if(prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/mk6(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/ukraine(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine(null)
	uniform.attackby(platecarrier_ukraine, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, apart of the Ukrainian Ground Forces in the fight against the invaders!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE





/datum/job/civilian/ukrainian/ugf_doctor
	title = "UGF Likar"
	en_meaning = "Ukrainian Doctor"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRNMed"

	is_medic = TRUE
	is_ww2 = FALSE
	is_upa = FALSE
	is_ukrainerussowar = TRUE
	is_modernday = FALSE

	min_positions = 2
	max_positions = 2

/datum/job/civilian/ukrainian/ugf_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ukraine(H), slot_w_uniform)

//head
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/mk6(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/ukraine(H), slot_head)

//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine(null)
	uniform.attackby(platecarrier_ukraine, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your comrades healthy!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MAX)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/ukrainian/sniper
	title = "UGF Sniper"
	en_meaning = "Ukrainian sniper"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	uses_squads = TRUE
	is_ww2 = FALSE
	is_upa = FALSE
	is_ukrainerussowar = TRUE
	is_modernday = FALSE

	min_positions = 5
	max_positions = 10

/datum/job/civilian/ukrainian/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ukraine(H), slot_w_uniform)

//head
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/mk6(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/ukraine(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrier_ukraine(null)
	uniform.attackby(platecarrier_ukraine, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_shoulder)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, take out enemy officers and high value targets from a distance!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE



///////////////////////////////////////////////////////////////////////////////////////////RUSKI/////////////////////////////////////////////////////////////////////////////

/datum/job/russian/russ_lieutenant
	title = " Russian Federal Forces Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRUCap"

	is_grozny = FALSE
	is_officer = TRUE
	is_commander = TRUE
	is_modernday = FALSE
	is_ww2 = FALSE
	whitelisted = TRUE
	is_ukrainerussowar = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/russ_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_vdv(H), slot_head)


	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/rusoff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia_pmk2(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Full Beard","Goatee","Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown","Grey")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_MAX)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MAX)
	H.setStat("dexterity", STAT_MAX)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MAX)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MAX)
	return TRUE

/datum/job/russian/russ_sergeant
	title = " Russian Federal Forces Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRUSgt"

	is_grozny = FALSE
	is_modernday = FALSE
	is_ww2 = FALSE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ukrainerussowar = TRUE

	can_get_coordinates = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/russian/russ_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	if (prob(33))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/sovietfacehelmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/rusoff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia_pmk2(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(armour, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)

	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/civbag(H), slot_back)
//jacket
	if (prob(33))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Goatee","Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown","Grey")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead your squad in the russian advance!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE


/datum/job/russian/russ_medic
	title = " Russian Federal Forces Corpsman"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRUMedic"

	is_medic = TRUE
	is_grozny = FALSE
	is_modernday = FALSE
	is_ww2 = FALSE
	is_ukrainerussowar = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/russian/russ_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia_pmk2(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(armour, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Goatee","Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and alive!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_HIGH)
	return TRUE

/datum/job/russian/russ_soldier
	title = " Russian Federal Forces Private"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"

	is_grozny = FALSE
	is_modernday = FALSE
	is_ww2 = FALSE
	is_ukrainerussowar = TRUE

	uses_squads = TRUE

	min_positions = 25
	max_positions = 80

/datum/job/russian/russ_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap_fed(H), slot_head)
//back
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74m(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)


	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia_pmk2(H), slot_r_store)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, apart of the Russian Federal Forces. Follow orders given by your superiors and defeat the enemy!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/russian/russ_sniper
	title = "Russian Federal Forces Sniper"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"

	uses_squads = TRUE
	is_ww2 = FALSE
	is_upa = FALSE
	is_ukrainerussowar = TRUE
	is_modernday = FALSE

	min_positions = 5
	max_positions = 10

/datum/job/russian/russ_sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap_fed(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(armour, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_l_hand)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, take out enemy officers and high value targets from a distance!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE