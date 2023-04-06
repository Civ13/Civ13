/datum/job/german
	faction = "Human"

/datum/job/german/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_german_name(H.gender)
	H.real_name = H.name
	if(H.h_style != "Bald" && H.h_style != "Crewcut" && H.h_style != "Undercut" && H.h_style != "Short Hair" && H.h_style != "Cut Hair" && H.h_style != "Skinhead" && H.h_style != "Average Joe" && H.h_style != "Fade" && H.h_style != "Combover" && H.h_style != "Father")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")
	if(H.f_style != "Goatee" && H.f_style != "Selleck Mustache" && H.f_style != "Shaved" && H.f_style != "Short Facial Hair")
		H.f_style = pick("Full Beard","Goatee","Selleck Mustache","Shaved", "Short Facial Hair")
/datum/job/german/captain
	title = "Heer Hauptmann"
	en_meaning = "Army Captain"
	rank_abbreviation = "Hpt."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_ww1 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/german/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german, slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/germcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mauser(H), slot_l_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Hauptmann of the German Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/lieutenant
	title = "Heer Oberleutnant"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "Oblt."


	spawn_location = "JoinLateGECap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/german/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/germcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mauser(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Oberleutenant of the German Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/german/second_lieutenant
	title = "Heer Leutnant"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = "Lt."


	spawn_location = "JoinLateGECap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/german/second_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/germcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mauser(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Leutenant of the German Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/german/sergeant
	title = "Heer Unteroffizier"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Uffz."

	spawn_location = "JoinLateGE"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ww1 = TRUE


	min_positions = 2
	max_positions = 12

/datum/job/german/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/pickelhaube2(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mauser(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/doctor
	title = "Heer Doktor"
	en_meaning = "Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateGEDoc"

	is_medic = TRUE
	is_ww1 = TRUE


	min_positions = 1
	max_positions = 10

/datum/job/german/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/germcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/shocktroop
	title = "Stosstrupp"
	en_meaning = "Shock Troop"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE" //for testing!

	is_ww1 = TRUE
	uses_squads = TRUE


	min_positions = 6
	max_positions = 200

/datum/job/german/shocktroop/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/stahlhelm(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/plate/newplate = new /obj/item/clothing/accessory/armor/modern/plate(null)
	uniform.attackby(newplate, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier specialized in infiltration and shock tactics. Lead the way for your fellow soldiers to the enemy trenches!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/german/infantry
	title = "Heer Soldat"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE" //for testing!

	is_ww1 = TRUE
	uses_squads = TRUE


	min_positions = 12
	max_positions = 400

/datum/job/german/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/pickelhaube2(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Imperial German Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

////////////////////////////WW2  Reichstag//////////////////////////////////////////////
/datum/job/german/captain_reichstag
	title = "Waffen-SS Hauptsturmfuhrer"
	en_meaning = "SS Captain"
	rank_abbreviation = "Hpt."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_ww2 = TRUE
	is_reichstag = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/german/captain_reichstag/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ss_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the commander of the German Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the remaining german troops.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/sergeant_reichstag
	title = "Feldwebel"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Uffz."

	spawn_location = "JoinLateGE"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ww2 = TRUE
	is_reichstag = TRUE

	min_positions = 1
	max_positions = 6

/datum/job/german/sergeant_reichstag/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ger_officercap(H), slot_head)
//weapons
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_belt)
	if (prob(85))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Hauptsturmfuhrer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/doctor_reichstag
	title = "Feldmediziner"
	en_meaning = "Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateGEDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_reichstag = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/german/doctor_reichstag/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_doctor(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm_medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/ss_reichstag
	title = "Waffen-SS Sturmmann"
	en_meaning = "Waffen-SS Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	whitelisted = TRUE
	is_reichstag = TRUE
	uses_squads = TRUE

	min_positions = 6
	max_positions = 30

/datum/job/german/ss_reichstag/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss_camo(H), slot_w_uniform)

	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/ss_parka(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/ss(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g43(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/stg(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg(null)
			uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the Waffen-SS tasked with defending the Reichstag to the last man. Surrendering is not an option!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/german/infantry_reichstag
	title = "Infanterie Soldat"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = TRUE
	uses_squads = TRUE

	min_positions = 6
	max_positions = 30

/datum/job/german/infantry_reichstag/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,5)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/sniper/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/sniper(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g43(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
			uniform.attackby(webbing, H)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
			uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Wehrmacht forces. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/volkssturm_reichstag
	title = "Volkssturmmann"
	en_meaning = "Militia"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = TRUE
	uses_squads = TRUE
	can_be_female = TRUE

	min_positions = 12
	max_positions = 60

/datum/job/german/volkssturm_reichstag/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)

//head
	var/pickhat = pick(1,2,3)
	if (pickhat == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	else if (pickhat == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
//back
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_l_hand)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr71(H), slot_l_hand)
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/panzerfaust(H), slot_shoulder)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/flamethrower/eins(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/glass/flamethrower/eins/filled(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/volkssturm/armband = new /obj/item/clothing/accessory/armband/volkssturm(null)
	uniform.attackby(armband, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a conscripted civilian hastly organized into a militia. Do your best to defend the Reichstag!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/hj_reichstag
	title = "Hitlerjunge"
	en_meaning = "Militia"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = TRUE
	uses_squads = TRUE
	can_be_minor = TRUE


	min_positions = 12
	max_positions = 60

/datum/job/german/hj_reichstag/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/hitlerjugend(H), slot_w_uniform)

//back
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr71(H), slot_l_hand)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/panzerfaust(H), slot_shoulder)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/flamethrower/eins(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/glass/flamethrower/eins/filled(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a young member of the Hitler's Youth. Defend the Reichstag!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////BERLIN ONLY//////////////////////////////////////////////////////////////////

/datum/job/german/volksturm_berlin
	title = "Volkssturm"
	en_meaning = "Militia"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = FALSE
	is_reichstag = FALSE
	uses_squads = TRUE
	can_be_female = TRUE

	min_positions = 12
	max_positions = 45

/datum/job/german/volksturm_berlin/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)

//head
	var/pickhat = pick(1,2,3)
	if (pickhat == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	else if (pickhat == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
//back
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_l_hand)
	else if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/vg5(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/antitank/stg24_bundle(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/stg(H), slot_r_store)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fg42(H), slot_l_hand)
		H.equip_to_slot_or_del(new/obj/item/ammo_magazine/fg42(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/fg42/small(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/vg(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/vgclip(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/vgclip(H), slot_r_store)
//other
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/panzerfaust(H), slot_shoulder)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/flamethrower/eins(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/glass/flamethrower/eins/filled(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(30))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/volkssturm/armband = new /obj/item/clothing/accessory/armband/volkssturm(null)
	uniform.attackby(armband, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a conscripted civilian hastly organized into a militia. Do your best to defend berlin!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////WW2 NOT REICHSTAG////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/hauptmann
	title = "Hauptmann"
	en_meaning = "Captain"
	rank_abbreviation = "Hpt."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_ww2 = TRUE
	is_reichstag = FALSE
	is_borderger = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/german/hauptmann/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/gerbelt/officer(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ger_officercap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_l_hand)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the commander of the German Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the german troops and organize them to victory.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/oberleutnant
	title = "Oberleutnant"
	en_meaning = "First Lieutenant"
	rank_abbreviation = "Oblt."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	whitelisted = TRUE

	is_ww2 = TRUE
	is_reichstag = FALSE
	is_borderger = TRUE
	is_ardeness = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/german/oberleutnant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ger_officercap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/gerbelt/officer(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the second highest ranking officer present. Your job is to command the german troops and organize them to victory according to the Hauptmann's orders.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/leutnant
	title = "Leutnant"
	en_meaning = "Second Lieutenant"
	rank_abbreviation = "lt."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	whitelisted = TRUE

	is_ww2 = TRUE
	is_reichstag = FALSE
	is_borderger = TRUE
	is_warsawger = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/german/leutnant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ger_officercap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/gerbelt/officer(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	var/obj/item/clothing/accessory/armband/nsdap/armband = new /obj/item/clothing/accessory/armband/nsdap(null)
	uniform.attackby(armband, H)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the second highest ranking officer present. Your job is to command the german troops and organize them to victory according to the Hauptmann's orders.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/gruppenfuhrer
	title = "Unteroffizier"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Uffz."

	spawn_location = "JoinLateGE"
	is_squad_leader = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_borderger = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/german/gruppenfuhrer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//head
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ger_officercap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/gerbelt/officer(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Hauptmann's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/schutze_soldaten
	title = "Schutze"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_borderger = TRUE

	min_positions = 8
	max_positions = 120

/datum/job/german/schutze_soldaten/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
//mask
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey(H), slot_wear_mask)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randgun = rand(1,5)
	switch(randgun)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g43(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			if (prob(50))
				var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault(null)
				uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_shoulder)
			if (prob(50))
				var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/smoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/smoke(null)
				uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault(null)
			uniform.attackby(webbing, H)
		if (5) //this is here so every 2th german doesnt get a semi auto
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_shoulder)
			if (prob(30))
				var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/smoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/smoke(null)
				uniform.attackby(webbing, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Wehrmacht forces. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/ard_volksgrenadier
	title = "Volksgrenadier"
	en_meaning = "Solider"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ardeness = TRUE
	is_ss_panzer = FALSE
	is_reichstag = FALSE
	is_ww2 = FALSE
	uses_squads = TRUE
	is_warsawger = FALSE

	min_positions = 10
	max_positions = 90

/datum/job/german/ard_volksgrenadier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
//parka
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german/winter(H), slot_wear_suit)
	else if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
//head
	if (prob(55))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
//hand
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/panzerfaust(H), slot_l_hand)
//guns
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,5)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/stg(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault(null)
			uniform.attackby(webbing, H)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98a(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault(null)
			uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the Volksgrenadier. Follow your sergeants's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	if (prob(50))
		H.setStat("rifle", STAT_MEDIUM_LOW)
	else
		H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/german/machine_gunner
	title = "MG-Schutze"
	en_meaning = "Machine Gunner"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_borderger = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 5

/datum/job/german/machine_gunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
//mask
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey(H), slot_wear_mask)
//head
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mg34belt(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/mg34(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun_cleaning_kit(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mg34(H), slot_r_store)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mg34/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mg34(null)
	uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner of the Wehrmacht forces.Provide suppressing fire, support your comrades, and follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_HIGH)


	return TRUE

/datum/job/german/machine_gunner_assistant
	title = "Munitionsträger"
	en_meaning = "Ammo Bearer"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_borderger = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 5

/datum/job/german/machine_gunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)

//head
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/ammo_can/german_mg(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/ammo_can/german_mg_drum(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mauser/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mauser(null)
	uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an ammo bearer of the Wehrmacht forces. Provide ammo to the Machinengewehr schutze and take over if they die. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_HIGH)


	return TRUE

/datum/job/german/german_antitank
	title = "Panzerabwehrschütze"
	en_meaning = "Anti Tank Rifleman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_borderger = TRUE
	is_warsawger = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/german/german_antitank/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_BARBAROSSA)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
//weapons
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
//AT GUN
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SIEGEMOSCOW || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KURSK || map.ID == MAP_BARBAROSSA || map.ID == MAP_VITEBSK)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/pzb39(H), slot_r_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/pzb_pouch(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/pzb_pouch_ap(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/rpb54(H), slot_r_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_casing/rocket/rpb54(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/walther(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/walther(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Anti tank Solider of the Wermacht,Your job is to Disable and Destroy enemy tanks,Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE
/datum/job/german/german_antitankassitant
	title = "Anti Panzer Schützen Assistent"
	en_meaning = "Anti Tank Rifleman Assistant"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_borderger = TRUE
	is_warsawger = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/german/german_antitankassitant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
//head
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_BARBAROSSA)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//weapons
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
//AT GUN
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SIEGEMOSCOW || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KURSK || map.ID == MAP_BARBAROSSA || map.ID == MAP_VITEBSK)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_r_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/antitank/stg24_bundle(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel/black/germanat/pzb(H), slot_back)
		var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault(null)
		uniform.attackby(webbing, H)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_casing/rocket/rpb54(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/stg(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/stg(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel/black/germanat/rpb54(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/stg(H), slot_shoulder)
		var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg(null)
		uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Anti tank Assistant of the Wermacht,Your job is to Provide Anti tank Ammo and Cover to the Anti tank Rifleman and take over if he dies,Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/german/sniper_schutze
	title = "Scharfschutze"
	en_meaning = "Sniper"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/german/sniper_schutze/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)

//head
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/sniper(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/gewehr98box(H), slot_belt)
//pockets
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(60))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/sniper/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/sniper(null)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
	uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper of the Wehrmacht forces. Provide suppressing fire, support your comrades, take out high value targets, and follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/german/mediziner
	title = "Mediziner"
	en_meaning = "Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateGEDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	is_borderger = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/german/mediziner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_doctor(H), slot_w_uniform) // for now
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm_medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/roller(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint/medic(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_back)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/german/sanitater
	title = "Sanitater"
	en_meaning = "Medic"
	rank_abbreviation = "Obrgf."

	spawn_location = "JoinLateGEDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_borderger = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/german/sanitater/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_doctor(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm_medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/roller(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/trench(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, and you are in charge of keeping the soldiers healthy and alive. Bring them back to a Mediziner for surgery.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_HIGH)

	return TRUE

////////////////////////////////TANKERS AND PANZERGRANADIERS///////////////////////////
/datum/job/german/tank_crew_leader
	title = "Panzerfuhrer"
	en_meaning = "Armored Squad Leader"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = FALSE
	is_tanker = TRUE
	whitelisted = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE
	uses_squads = TRUE
	is_tankcom = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 6

/datum/job/german/tank_crew_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_tanker(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ger_officercap_tanker(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/gerbelt/officer(H), slot_belt)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hip = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(hip, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the commander of a tank. Assemble your crew and lead your tank to victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/german/tank_crew
	title = "Panzerschutze"
	en_meaning = "Armored Crewman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_reichstag = FALSE
	is_tanker = TRUE
	uses_squads = TRUE
	is_ardeness = TRUE

	min_positions = 4
	max_positions = 32

/datum/job/german/tank_crew/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_tanker(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_tanker(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hip = new /obj/item/clothing/accessory/holster/hip(null)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_l_store)
	uniform.attackby(hip, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of an armored vehicle crew. Get your role assigned and follow your Commander!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/german/ss_panzergrenadier_squad_leader
	title = "Waffen-SS Unterscharfuhrer Panzergrenadier"
	en_meaning = "Mechanized Infantry Squad Leader"
	rank_abbreviation = "Uscha."

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ss_panzer = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 6

/datum/job/german/ss_panzergrenadier_squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/gerbelt/officer(H), slot_belt)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hip = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(hip, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a squad of Waffen-SS Mechanized Infantry. Coordinate with the Panzers and defeat the enemy!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/german/ss_panzergrenadier
	title = "Waffen-SS Panzergrenadier"
	en_meaning = "Mechanized Infantry"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ss_panzer = TRUE

	is_ww2 = TRUE
	uses_squads = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 6
	max_positions = 30

/datum/job/german/ss_panzergrenadier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss_camo(H), slot_w_uniform)

	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/ss_parka(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/ss(H), slot_head)
//hand
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/rocket/single_shot/panzerfaust(H), slot_l_hand)
//guns
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,4)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g43(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/stg(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault(null)
			uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the Waffen-SS Mechanized Infantry Corps. Follow your commander's orders and coordinate with the Panzers!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/german/ss_pionier
	title = "Waffen-SS Pionier"
	en_meaning = "Sapper"
	rank_abbreviation = ""

	spawn_location = "JoinLateGESap"
	is_ss_panzer = TRUE
	is_ww2 = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/german/ss_pionier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/ss(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/pilot(H), slot_eyes)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/sapper/german(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen, slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hip = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(hip, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sapper of the Waffen-SS. Place mines, sandbags, barbed wire, and help repair the vehicles!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/german/ss_flamethrower
	title = "Waffen-SS Flammenwerfer"
	en_meaning = "Flamethrower Unit"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_warsawger = TRUE
	is_ardeness = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/german/ss_flamethrower/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/firefighter(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/ss(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_wear_mask)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/flamethrower/flammenwerfer(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer/filled(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	uniform.attackby(webbing, H)
	webbing.attackby(new/obj/item/stack/medical/bruise_pack/bint, H)
	webbing.attackby(new/obj/item/ammo_magazine/walther, H)
	webbing.attackby(new/obj/item/ammo_magazine/walther, H)
	webbing.attackby(new/obj/item/ammo_magazine/walther, H)
	webbing.attackby(new/obj/item/ammo_magazine/walther, H)
	webbing.attackby(new/obj/item/ammo_magazine/walther, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the Waffen-SS tasks with spraying the flaming fires of hell upon your enemies. Follow your commander's orders!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/german/paratrooper
	title = "Fallschirmjäger"
	en_meaning = "Paratrooper"
	rank_abbreviation = ""

	spawn_location = "Paradrop"

	uses_squads = TRUE
	is_paratrooper = TRUE
	whitelisted = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/german/paratrooper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,4)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/stg(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg(null)
			uniform.attackby(webbing, H)
		if (4)
			if (prob(40))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fg42/scope(H), slot_shoulder)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fg42(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/fg42/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/fg42(null)
			uniform.attackby(webbing, H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a paratrooper. Your job is to help any other units that need assistance.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

////////////////////////////WARSAWUPRISING/////////////////////////////////////
/datum/job/german/warsaw_schutzpolizei
	title = "Schutzpolizei"
	en_meaning = "Security Police"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ss_panzer = FALSE
	is_ww2 = FALSE
	uses_squads = TRUE
	is_warsawger = TRUE

	min_positions = 5
	max_positions = 90

/datum/job/german/warsaw_schutzpolizei/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)

	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
//guns
	var/obj/item/clothing/under/uniform = H.w_uniform
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
	uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Security Unit member,guard captured positions and attack with the SS. Follow your Squad leader's orders!")
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

/datum/job/german/ss_abbruchspezialist
	title = "Waffen-SS Abbruchspezialist"
	en_meaning = "Demolitions Specialist"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_ww2 = FALSE
	uses_squads = TRUE
	is_warsawger = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/german/ss_abbruchspezialist/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_ss(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/firefighter(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/ss(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/destructionpouch(H), slot_belt)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/flamethrower/flammenwerfer(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer/filled(H), slot_back)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault(null)
	uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the Waffen-SS tasked with destroying warsaw,assault enemy positions with your flamethrower or your MP40 and burn down everything. Follow your commander's orders!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE