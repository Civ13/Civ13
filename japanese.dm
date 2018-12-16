/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////JAPANESE///////////////////////////////////////////////////////

/datum/job/japanese
	faction = "Station"

/datum/job/japanese/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name

/datum/job/japanese/army_commander
	title = "Rikugun-tai-i"
	en_meaning = "Captain"
	rank_abbreviation = "Ri-Tai."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_army = TRUE
	is_commander = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/japanese/army_commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, the commander of this company. Organize your <b>lieutenant</b>s and lead your country to victory!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

	/datum/job/japanese/lieutenant
	title = "Japanese Lieutenant"
	en_meaning = "Platoon Commander"
	rank_abbreviation = "Lt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_army = TRUE
	is_commander = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/japanese/platoon_commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, the commander of this platoon. Organize your <b>Sergeant</b>s and lead your country to victory!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/sergeant
	title = "Gunso"
	en_meaning = "Sergeant"
	rank_abbreviation = "Sgt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 20

/datum/job/japanese/army_officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, squad leader. Organize your group of <b>Soldiers</b> according to your <b>Lieutenant</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/field_medic
	title = "Sento-i"
	en_meaning = "Infantry Field Medic"
	rank_abbreviation = "Sen-i.."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 6

/datum/job/japanese/field_medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka35(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a medic, and you are in charge of keeping the infantry alive.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/japanese/soldier
	title = "Nitohei"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = "Ni."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 100

/datum/job/japanese/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka35(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a basic infantry soldier of the Imperial Japanese Army. Follow your Officer's orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


/datum/job/japanese/sniper
	title = "Jotohei"
	en_meaning = "Marksman"
	rank_abbreviation = "Jo.."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 15

/datum/job/japanese/sniper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/armycoat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka35(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a  marksman. You are very skilled in marksmanship and can shoot straight.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE