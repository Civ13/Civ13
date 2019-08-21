/datum/job/chinese
	faction = "Human"

/datum/job/chinese/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_chinese_name(H.gender)
	H.real_name = H.name

/datum/job/chinese/captain
	title = "Shàngwèi"
	en_meaning = "Army Captain"
	rank_abbreviation = "Shang."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/chinese/captain/equip(var/mob/living/carbon/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
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
	title = "Zhongwèi"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "Zhong."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRUCap"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_commander = TRUE
	is_officer = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/chinese/lieutenant/equip(var/mob/living/carbon/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
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
	title = "Shàngshi"
	en_meaning = "Sergeant"
	rank_abbreviation = "Shi."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJRU"
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/chinese/sergeant/equip(var/mob/living/carbon/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	var/randweap = rand(1,3)
	if (randweap== 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
	else if (randweap == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_shoulder)
	else if (randweap == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
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

/datum/job/chinese/doctor
	title = "Shàowèi"
	en_meaning = "Doctor"
	rank_abbreviation = "Shao."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRUDoc"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/chinese/doctor/equip(var/mob/living/carbon/human/H)
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
	title = "Èrdeng Bing"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Erd."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRU"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 200

/datum/job/chinese/infantry/equip(var/mob/living/carbon/human/H)
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
	var/randweap = rand(1,3)
	if (randweap== 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
	else if (randweap == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_shoulder)
	else if (randweap == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)

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
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRU"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10

/datum/job/chinese/sniper/equip(var/mob/living/carbon/human/H)
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
	var/randweap = rand(1,3)
	if (randweap== 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
	else if (randweap == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_shoulder)
	else if (randweap == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(H), slot_l_store)
	give_random_name(H)
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