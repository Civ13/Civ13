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
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

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
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

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
	is_officer = TRUE
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
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

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
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
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
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/chinese/sniper
	title = "Yideng Bing"
	en_meaning = "Soldier First-class"
	rank_abbreviation = "Yi."

	spawn_location = "JoinLateRU"
	is_ww2 = TRUE
	uses_squads = TRUE

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

	give_random_name(H)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
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
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

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
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/chi_korea_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chinese_ushanka(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

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
	is_officer = TRUE
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
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

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
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
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
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
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
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")
	else
		return
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
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
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Chinese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE