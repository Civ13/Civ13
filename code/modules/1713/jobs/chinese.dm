/datum/job/chinese
	faction = "Human"

/datum/job/chinese/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_chinese_name(H.gender)
	H.real_name = H.name

/datum/job/chinese/captain
	title = "Shangwei"
	en_meaning = "Army Captain"
	rank_abbreviation = "Shang."


	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/chinese/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	var/randcloth = rand(1,3)
	if (randcloth== 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni2_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap2(H), slot_head)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_officer(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

	world << "<b><big>[H.real_name] is the Captain of the Chinese Forces!</big></b>"
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

/datum/job/chinese/lieutenant
	title = "Zhongwei"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "Zhong."


	spawn_location = "JoinLateRUCap"
	whitelisted = TRUE
	is_ww2 = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/chinese/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	var/randcloth = rand(1,3)
	if (randcloth== 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni2_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap2(H), slot_head)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_officer(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
////weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

	world << "<b><big>[H.real_name] is the 1st Lieutenant of the Chinese forces!</big></b>"
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

/datum/job/chinese/sergeant
	title = "Shangshi"
	en_meaning = "Sergeant"
	rank_abbreviation = "Shi."

	spawn_location = "JoinLateRU"
	is_ww2 = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/chinese/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	var/randcloth = rand(1,3)
	if (randcloth== 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni2_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap2(H), slot_head)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_officer(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

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

/datum/job/chinese/doctor
	title = "Shaowei"
	en_meaning = "Doctor"
	rank_abbreviation = "Shao."

	spawn_location = "JoinLateRUDoc"
	is_ww2 = TRUE


	is_medic = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/chinese/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	var/randcloth = rand(1,3)
	if (randcloth== 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni2_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap2(H), slot_head)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni_off(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german_doctor(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

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
/datum/job/chinese/infantry
	title = "Erdeng Bing"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Erd."

	spawn_location = "JoinLateRU"
	is_ww2 = TRUE
	uses_squads = TRUE

	can_be_female = TRUE
	min_positions = 6
	max_positions = 200

/datum/job/chinese/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

	var/randcloth = rand(1,2)
	if (randcloth== 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap2(H), slot_head)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese(H), slot_shoulder)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/chinese/sniper
	title = "Yideng Bing"
	en_meaning = "Soldier First-class"
	rank_abbreviation = "Yi."

	spawn_location = "JoinLateRU"
	is_ww2 = TRUE
	uses_squads = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/chinese/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	var/randcloth = rand(1,2)
	if (randcloth== 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap2(H), slot_head)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/chiuni(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/chicap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(60))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
//////////////////////////////////////////////////////////////////////////////////////////////////// KOREAN WAR /////////////////////////////////////////////////////
/datum/job/chinese/captain_korean
	title = " Shangwei"
	en_meaning = "Army Captain"
	rank_abbreviation = "Shang."


	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_korean_war = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/chinese/captain_korean/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese/officer(H), slot_wear_suit)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

	world << "<b><big>[H.real_name] is the Captain of the Chinese Forces!</big></b>"
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

/datum/job/chinese/lieutenant_korean
	title = " Zhongwei"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "Zhong."


	spawn_location = "JoinLateRUCap"
	whitelisted = TRUE
	is_korean_war = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/chinese/lieutenant_korean/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese/officer(H), slot_wear_suit)
////weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

	world << "<b><big>[H.real_name] is the 1st Lieutenant of the Chinese forces!</big></b>"
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

/datum/job/chinese/sergeant_korean
	title = " Shangshi"
	en_meaning = "Sergeant"
	rank_abbreviation = "Shi."

	spawn_location = "JoinLateRU"
	is_korean_war = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/chinese/sergeant_korean/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese/officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/soviet_ppsh(H), slot_belt)

//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

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

/datum/job/chinese/doctor_korean
	title = " Shaowei"
	en_meaning = "Doctor"
	rank_abbreviation = "Shao."

	spawn_location = "JoinLateRUDoc"
	is_korean_war = TRUE


	is_medic = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/chinese/doctor_korean/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese/officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

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
/datum/job/chinese/infantry_korean
	title = " Erdeng Bing"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Erd."

	spawn_location = "JoinLateRU"
	is_korean_war = TRUE
	uses_squads = TRUE


	min_positions = 6
	max_positions = 200

/datum/job/chinese/infantry_korean/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/chinese_rifle(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
//back

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese(H), slot_shoulder)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/khaki_webbingh = new /obj/item/clothing/accessory/storage/webbing/khaki_webbing(null)
	uniform.attackby(khaki_webbingh, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	khaki_webbingh.attackby(new/obj/item/weapon/grenade/ww2/rgd33, H)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/chinese/sniper_korean
	title = " Yideng Bing"
	en_meaning = "Soldier First-Class"
	rank_abbreviation = "Yi."

	spawn_location = "JoinLateRU"
	is_korean_war = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/chinese/sniper_korean/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/chinese_rifle(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(60))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/khaki_webbingh = new /obj/item/clothing/accessory/storage/webbing/khaki_webbing(null)
	uniform.attackby(khaki_webbingh, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	khaki_webbingh.attackby(new/obj/item/weapon/grenade/ww2/rgd33, H)
	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	else
		return
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/chinese/machinegunner_korean
	title = "Ji Qiangshou"
	en_meaning = "Machine Gunner"
	rank_abbreviation = "Yi."

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_korean_war = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/chinese/machinegunner_korean/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/chinese(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/khaki_webbingh = new /obj/item/clothing/accessory/storage/webbing/khaki_webbing(null)
	uniform.attackby(khaki_webbingh, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/dp, H)
	khaki_webbingh.attackby(new/obj/item/ammo_magazine/dp, H)
	khaki_webbingh.attackby(new/obj/item/weapon/grenade/ww2/rgd33, H)

	give_random_name(H)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

///////////////////1930s Chinese Red Army/////////////// TO BE COMPLETED

/datum/job/civilian/chinese
	default_language = "Chinese"
	additional_languages = list()
/datum/job/civilian/chinese/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_chinese_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")

/datum/job/civilian/chinese/cra_off
	title = "Chinese Red Army Officer"
	spawn_location = "JoinLateCiv"
	is_officer = TRUE
	is_commander = TRUE
	is_ccw = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/chinese/cra_off/equip(var/mob/living/human/H)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/cra_uni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	uniform.attackby(armband, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Lead your men to your destination!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/chinese/cra_sl
	title = "Chinese Red Army Squad Leader"
	spawn_location = "JoinLateCiv"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ccw = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/civilian/chinese/cra_sl/equip(var/mob/living/human/H)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/cra_uni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	var/obj/item/weapon/storage/belt/russian/soldier/belt1 = new /obj/item/weapon/storage/belt/russian/soldier(null)
	var/obj/item/weapon/storage/belt/russian/ww1/soldier/belt2 = new /obj/item/weapon/storage/belt/russian/ww1/soldier(null)
	belt1.name = "leather pouches"
	belt2.name = "leather pouches"
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	uniform.attackby(armband, H)
	if(prob(70))
		H.equip_to_slot_or_del(belt1, slot_belt)
		var/obj/item/clothing/accessory/storage/webbing/russbando = new /obj/item/clothing/accessory/storage/webbing/russband(null)
		uniform.attackby(russbando, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	else
		H.equip_to_slot_or_del(belt2, slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Lead your squad to your destination!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/chinese/cra_soldier
	title = "Chinese Red Army Soldier"
	spawn_location = "JoinLateCiv"
	uses_squads = TRUE
	is_ccw = TRUE

	min_positions = 2
	max_positions = 100

/datum/job/civilian/chinese/cra_soldier/equip(var/mob/living/human/H)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/cra_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/cra_uni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	var/obj/item/weapon/storage/belt/russian/soldier/belt1 = new /obj/item/weapon/storage/belt/russian/soldier(null)
	var/obj/item/weapon/storage/belt/russian/ww1/soldier/belt2 = new /obj/item/weapon/storage/belt/russian/ww1/soldier(null)
	belt1.name = "leather pouches"
	belt2.name = "leather pouches"
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(armband, H)
	if(prob(70))
		H.equip_to_slot_or_del(belt1, slot_belt)
		var/obj/item/clothing/accessory/storage/webbing/russbando = new /obj/item/clothing/accessory/storage/webbing/russband(null)
		uniform.attackby(russbando, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	else
		H.equip_to_slot_or_del(belt2, slot_belt)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Follow your leader's orders and reach your destination!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/chinese/cra_volunteer
	title = "Chinese Red Army Volunteer"
	spawn_location = "JoinLateCiv"
	uses_squads = TRUE
	is_ccw = TRUE

	min_positions = 2
	max_positions = 100

/datum/job/civilian/chinese/cra_volunteer/equip(var/mob/living/human/H)
//head
	var/randhat = rand(1,3)
	switch(randhat)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
		if(3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap2(H), slot_head)
	var/randclothes = rand(1,3)
	switch(randclothes)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		if(3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)

	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/obrez(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
	var/obj/item/weapon/storage/belt/russian/soldier/belt1 = new /obj/item/weapon/storage/belt/russian/soldier(null)
	var/obj/item/weapon/storage/belt/russian/ww1/soldier/belt2 = new /obj/item/weapon/storage/belt/russian/ww1/soldier(null)
	belt1.name = "leather pouches"
	belt2.name = "leather pouches"
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(armband, H)
	if(prob(70))
		H.equip_to_slot_or_del(belt1, slot_belt)
		var/obj/item/clothing/accessory/storage/webbing/russbando = new /obj/item/clothing/accessory/storage/webbing/russband(null)
		uniform.attackby(russbando, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	else
		H.equip_to_slot_or_del(belt2, slot_belt)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Follow your leader's orders and reach your destination!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

////////////////////MODERN PLA/////////////////////

/datum/job/chinese/pla/sergeant
	title = "Zhong Shi"
	en_meaning = "PLA Sergeant"
	rank_abbreviation = "Zh."
	spawn_location = "JoinLateRUSgt"

	is_pla = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	can_get_coordinates = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/chinese/pla/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_type07(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/qgf03(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/qbz95(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(armour, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/makarov, H)

	H.add_note("Role", "You are a <b>[title]</b>, lead your squad in the Chinese advance!")
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


/datum/job/chinese/pla/corpsman
	title = "Junren"
	rank_abbreviation = "Sdb."
	en_meaning = "PLA Corpsman"
	spawn_location = "JoinLateRUMedic"

	is_medic = TRUE
	is_pla = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/chinese/pla/corpsman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_type07(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/qgf03(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

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

/datum/job/chinese/pla
	title = "Lie Bing"
	en_meaning = "PLA Infantryman"
	rank_abbreviation = ""
	spawn_location = "JoinLateRU"
	is_pla = TRUE
	uses_squads = TRUE

	min_positions = 25
	max_positions = 80

/datum/job/chinese/pla/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_type07(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/qgf03(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/qbz95(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/khaki_webbing/h = new /obj/item/clothing/accessory/storage/webbing(null)
	uniform.attackby(h, H)
	H.add_note("Role", "You are a <b>[title]</b>, an infantryman of the PLA's Ground Forces. Follow orders given by your superiors and defeat the enemy!")
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

/datum/job/chinese/pla/sniper
	title = "Ju Ji Shou"
	en_meaning = "PLA Sniper"
	rank_abbreviation = "Sdb."
	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_pla = TRUE

	min_positions = 5
	max_positions = 10

/datum/job/chinese/pla/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_type07(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/qgf03(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_l_hand)
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

//////////////////////////////sovietsino borderconflict////////////////////////////////

/datum/job/chinese/sovcon/pla/commisar
	title = "Zhengwei"
	en_meaning = "PLA Political Commissar"
	rank_abbreviation = "Zhe."
	spawn_location = "JoinLateCH"

	is_pla = FALSE
	is_officer = TRUE
	is_sinosovbor = TRUE
	can_be_female = TRUE

	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 2

/datum/job/chinese/sovcon/pla/commisar/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka/down(H), slot_head)
//coat
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese/officer(H), slot_wear_suit)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/officeruni(H), slot_belt)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/chinese(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/akm/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/akm(null)
	uniform.attackby(webbing, H)
	H.add_note("Role", "You are a <b>[title]</b>, Give out orders to your Squads and Lead them towards Victory!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/chinese/sovcon/pla/sergeant
	title = "Junshi"
	en_meaning = "PLA Sergeant"
	rank_abbreviation = "Ju."
	spawn_location = "JoinLateCH"

	is_pla = FALSE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_sinosovbor = TRUE
	can_be_female = TRUE

	can_get_coordinates = TRUE

	min_positions = 4
	max_positions = 12

/datum/job/chinese/sovcon/pla/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
//head
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka/down(H), slot_head)
//coat
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese/officer(H), slot_wear_suit)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/officeruni(H), slot_belt)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/chinese(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/akm/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/akm(null)
	uniform.attackby(webbing, H)
	H.add_note("Role", "You are a <b>[title]</b>, Lead your Squad!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE


/datum/job/chinese/sovcon/pla/corpsman
	title = "Zhan Yi"
	rank_abbreviation = "Sdb."
	en_meaning = "PLA Combat Doctor"
	spawn_location = "JoinLateCH"

	is_pla = FALSE
	is_medic = TRUE
	is_sinosovbor = TRUE
	uses_squads = TRUE
	can_be_female = TRUE

	min_positions = 4
	max_positions = 8

/datum/job/chinese/sovcon/pla/corpsman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized/med(H), slot_head)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
//coat
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/white = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and alive!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/chinese/sovcon/pla/infantry
	title = "Jiefanqjun qing bubing"
	en_meaning = "PLA Light Infantry"
	rank_abbreviation = ""
	spawn_location = "JoinLateCH"
	is_pla = FALSE
	uses_squads = TRUE
	is_sinosovbor = TRUE
	can_be_female = TRUE

	min_positions = 10
	max_positions = 120

/datum/job/chinese/sovcon/pla/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chinese_winter(H), slot_w_uniform)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/cra_cap(H), slot_head)
	else if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized/winter(H), slot_head)
//coat
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/chinese(H), slot_wear_suit)
//belt
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/custom(H), slot_belt)
//gun
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,6)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/light/chinese/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/light/chinese/gewehr98(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/chinese(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/light/chinese/ak47/webbing = new /obj/item/clothing/accessory/storage/webbing/light/chinese/ak47(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/sks/chinese(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/light/chinese/sks/webbing = new /obj/item/clothing/accessory/storage/webbing/light/chinese/sks(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
			uniform.attackby(webbing, H)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/dpgun/webbing = new/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/dpgun(null)
			uniform.attackby(webbing, H)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/sks/chinese(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(H), slot_l_hand)
			var/obj/item/clothing/accessory/storage/webbing/light/chinese/sks/webbing = new /obj/item/clothing/accessory/storage/webbing/light/chinese/sks(null)
			uniform.attackby(webbing, H)
	H.add_note("Role", "You are a <b>[title]</b>, an infantryman of the PLA's Ground Forces. Follow orders given by your superiors and defeat the enemy!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/chinese/sovcon/pla/redguard
	title = "Hong Weibing Wenyuan"
	en_meaning = "Red Guard Conscript"
	rank_abbreviation = ""
	spawn_location = "JoinLateCH"
	is_pla = FALSE
	uses_squads = TRUE
	is_sinosovbor = TRUE
	can_be_female = TRUE

	min_positions = 10
	max_positions = 90

/datum/job/chinese/sovcon/pla/redguard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chinaguard(H), slot_w_uniform)
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/chinaguardcap(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/cra_uni(H), slot_w_uniform)
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/cra_cap(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized/winter(H), slot_head)
//belt
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/custom(H), slot_belt)
//bayo
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
//gun
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/chinese(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/light/chinese/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/light/chinese/gewehr98(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/sks/chinese(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/light/chinese/sks/webbing = new /obj/item/clothing/accessory/storage/webbing/light/chinese/sks(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
			uniform.attackby(webbing, H)
	H.add_note("Role", "You are a <b>[title]</b>, a conscript from the red guard. Follow orders given by your superiors and defeat the enemy!")
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