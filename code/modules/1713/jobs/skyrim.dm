/datum/job/skyrim
	faction = "Human"

/datum/job/skyrim/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_oldnorse_name(H.gender)
	H.real_name = H.name

/datum/job/skyrim/imperial/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_roman_name(H.gender)
	H.real_name = H.name

/datum/job/skyrim/imperial/captain	//imperial - captain
	title = "Imperial Captain"
	rank_abbreviation = "Cen."

	spawn_location = "JoinLateRO"

	is_commander = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/skyrim/imperial/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/tes13/imperial(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial/officer(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/imperial(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a <b>Captain</b>, a company of Legionaries. Organize your <b>Lieutenants</b> and lead your soldiers to victory!</b>.")
	H.setStat("strength", STAT_VERY_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_VERY_HIGH)
	H.setStat("swords", STAT_VERY_VERY_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/skyrim/imperial/lieutenant	//imperial - lieutenant
	title = "Imperial Lieutenant"
	rank_abbreviation = "Dec."

	spawn_location = "JoinLateRO"

	is_commander = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/skyrim/imperial/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/tes13/imperial(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial/officer(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/imperial(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, the second in command as a <b>lieutenant</b>, a platoon of Legionaries. Organize your <b>sergeants</b> and lead your soldiers to victory!</b>.")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/skyrim/imperial/sergeant	//imperial - sergeant
	title = "Imperial squad leader"
	rank_abbreviation = "Vex."

	spawn_location = "JoinLateRO"

	is_commander = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/skyrim/imperial/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/imperial(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, the squad leader <b>sergeant</b>, a squad of Legionaries. Organize your <b>men</b> and lead your soldiers to victory!</b>.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/skyrim/imperial/soldier //imperial - soldier
	title = "Imperial soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateRO"

	is_skyrim = TRUE
	is_imperial = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 200

/datum/job/skyrim/imperial/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/imperial(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, the infantry and backbone of the Empire. Fight for the glory of the Empire!</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/skyrim/imperial/archer //imperial - soldier
	title = "Imperial archer"
	rank_abbreviation = ""

	spawn_location = "JoinLateRO"

	is_skyrim = TRUE
	is_imperial = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 200

/datum/job/skyrim/imperial/archer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/longbow(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, the ranged support of the Empire. Keep the enemy full of arrows and allow the infantry to charge in!</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE
//////////////////////WHITERUN GARRISON///////////////////////////////////////////
/datum/job/skyrim/imperial/guard_captain
	title = "Whiterun Head Guard"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"

	is_medieval = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/skyrim/imperial/guard_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/whiterun(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/whiterun/female(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/guard(H), slot_head)
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/whiterun(H), slot_l_hand)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/twohanded(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe/tes13/battleaxe(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a whiterun guard. Defend the city from those rebel storm cloaks! Organize the defense!")
	H.setStat("strength", STAT_VERY_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_VERY_VERY_HIGH)
	H.setStat("swords", STAT_VERY_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_VERY_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/skyrim/imperial/guard
	title = "Whiterun Guard"
	rank_abbreviation = ""

	spawn_location = "JoinLateFR"

	is_medieval = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE


	min_positions = 5
	max_positions = 25

/datum/job/skyrim/imperial/guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/whiterun(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/whiterun/female(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/guard(H), slot_head)
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/whiterun(H), slot_l_hand)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/twohanded(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe/tes13/battleaxe(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a whiterun guard. Defend the city from those rebel storm cloaks!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE