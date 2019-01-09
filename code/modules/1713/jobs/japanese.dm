/datum/job/japanese
	faction = "Station"

/datum/job/japanese/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name

/datum/job/japanese/captain
	title = "Rikugun-Tai-i"
	en_meaning = "Army Captain"
	rank_abbreviation = "Ri-Tai"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/japanese/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japoffuni, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	world << "<b><big>[H.real_name] is the Captain of the Japanese Forces!</big></b>"
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

/datum/job/japanese/lieutenant
	title = "Rikugun-Chui"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "1lt."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_commander = TRUE
	is_officer = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/japanese/lieutenant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japoffuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	world << "<b><big>[H.real_name] is the 1st Lieutenant of the Japanese forces!</big></b>"
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

/datum/job/japanese/lieutenant2
	title = "Rikugun-Shoi"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = "2lt."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_commander = TRUE
	is_officer = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/japanese/lieutenant2/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japoffuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	world << "<b><big>[H.real_name] is the 2nd Lieutenant of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. Second to 1st Lieutenant. The whole operation relies on you and your orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/sergeant
	title = "Gunso"
	en_meaning = "Sergeant"
	rank_abbreviation = "Gunso"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/japanese/sergeant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/t26_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c9mm_jap_revolver(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
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

/datum/job/japanese/doctor
	title = "Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/japanese/doctor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

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

/datum/job/japanese/cook
	title = "Shefu"
	en_meaning = "Chef"
	rank_abbreviation = "Shefu"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/japanese/cook/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//head//
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap(H), slot_belt)

	H.add_note("Role", "You are the cook of the company. Feed the whole company according to the <b>Leiutenant's</b> orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW) //not used
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)





////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/japanese/infantry
	title = "Nitohei"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Ni."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 200

/datum/job/japanese/infantry/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_back)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/sniper
	title = "Ittohei"
	en_meaning = "Soldier First-class"
	rank_abbreviation = "Itto."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 3
	max_positions = 200

/datum/job/japanese/sniper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka35(H), slot_back)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/white_sash
	title = "Sash Nitohei"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Ni."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 200

/datum/job/japanese/white_sash/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_back)

	var/obj/item/clothing/accessory/white_sash = new /obj/item/clothing/accessory/white_sash(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(white_sash, H)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
