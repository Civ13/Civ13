/datum/job/civilian/skyrim
	faction = "Human"

/datum/job/civilian/skyrim/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_oldnorse_name(H.gender)
	H.real_name = H.name

/datum/job/roman/skyrim/imperial/guard_captain/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_oldnorse_name(H.gender)
	H.real_name = H.name

/datum/job/roman/skyrim/imperial/guard/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_oldnorse_name(H.gender)
	H.real_name = H.name

/datum/job/roman/skyrim/imperial/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_roman_name(H.gender)
	H.real_name = H.name

/datum/job/roman/skyrim/imperial/balgruuf	//imperial - captain
	title = "Jarl Balgruuf"
	rank_abbreviation = "Jarl"

	spawn_location = "JoinLateRUCap"

	is_commander = TRUE
	is_officer = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	is_medieval = TRUE
	selection_color = "#9A662C"
	min_positions = 1
	max_positions = 1

/datum/job/roman/skyrim/imperial/balgruuf/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial/bolgruf(H), slot_w_uniform)
		//head
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel/balgruuf(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/whiterun(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/draught(H), slot_belt)
	H.add_note("Role", "You are <b>[title]</b>, the Jarl of the <b>Whiterun</b>, an imperial aligned city. Organize your men and lead the defense to victory, for the Empire and all her people!</b>.")
	H.setStat("strength", STAT_MAX)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MAX)
	H.setStat("swords", STAT_MAX)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MAX)
	H.setStat("medical", STAT_MAX)
	H.real_name = "Balgruuf"
	H.h_style = "Flaired Hair"
	H.f_style = "Goatee"
	H.b_hair = 120
	H.g_hair = 151
	H.r_hair = 184
	H.b_facial = 120
	H.g_facial = 151
	H.r_facial = 184

	return TRUE

/datum/job/roman/skyrim/imperial/captain	//imperial - captain
	title = "Imperial Captain"
	rank_abbreviation = "Cen."

	spawn_location = "JoinLateRO"

	is_commander = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	is_officer = TRUE
	selection_color = "#7c0006"

	min_positions = 1
	max_positions = 1

/datum/job/roman/skyrim/imperial/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/tes13/imperial(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial/officer(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/vigorous(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_l_hand)
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

/datum/job/roman/skyrim/imperial/lieutenant	//imperial - lieutenant
	title = "Imperial Lieutenant"
	rank_abbreviation = "Dec."

	spawn_location = "JoinLateRO"

	is_commander = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	is_officer = TRUE
	selection_color = "#7c0006"

	min_positions = 1
	max_positions = 1

/datum/job/roman/skyrim/imperial/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/tes13/imperial(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial/officer(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/plentiful(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_l_hand)
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

/datum/job/roman/skyrim/imperial/sergeant	//imperial - sergeant
	title = "Imperial Squad Leader"
	rank_abbreviation = "Vex."

	spawn_location = "JoinLateRO"

	is_skyrim = TRUE
	is_imperial = TRUE
	is_squad_leader = TRUE
	is_officer = TRUE
	uses_squads = TRUE
	selection_color = "#7c0006"

	min_positions = 1
	max_positions = 4

/datum/job/roman/skyrim/imperial/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/plentiful(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_l_hand)
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

/datum/job/roman/skyrim/imperial/soldier //imperial - soldier
	title = "Imperial Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateRO"

	is_skyrim = TRUE
	is_imperial = TRUE
	uses_squads = TRUE
	selection_color = "#7c0006"

	min_positions = 1
	max_positions = 200

/datum/job/roman/skyrim/imperial/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(H), slot_r_store)
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

/datum/job/roman/skyrim/imperial/archer //imperial - soldier
	title = "Imperial Archer"
	rank_abbreviation = ""

	spawn_location = "JoinLateRO"

	is_skyrim = TRUE
	is_imperial = TRUE
	uses_squads = TRUE
	selection_color = "#7c0006"

	min_positions = 1
	max_positions = 200

/datum/job/roman/skyrim/imperial/archer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/imperial(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/imperial(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/longbow(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(H), slot_r_store)
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

/datum/job/roman/skyrim/imperial/guard_captain
	title = "Whiterun Head Guard"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"

	is_medieval = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	selection_color = "#9A662C"
	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/roman/skyrim/imperial/guard_captain/equip(var/mob/living/human/H)
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

/datum/job/roman/skyrim/imperial/guard
	title = "Whiterun Guard"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"

	is_medieval = TRUE
	is_skyrim = TRUE
	is_imperial = TRUE
	selection_color = "#9A662C"

	min_positions = 5
	max_positions = 25

/datum/job/roman/skyrim/imperial/guard/equip(var/mob/living/human/H)
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
	if(prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/hide(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/guard(H), slot_head)
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/whiterun(H), slot_l_hand)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/twohanded(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe/tes13/battleaxe(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(H), slot_r_store)
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



/////////////////////////////////////////////////////////////STORMCLOAKS///////////////////////////////////////////////////////////////////////////
/datum/job/civilian/skyrim/stormcloak/ulfric	//stormcloak - captain
	title = "Ulfric Stormcloak"
	rank_abbreviation = ""

	spawn_location = "JoinLateGECap"

	is_commander = TRUE
	is_skyrim = TRUE
	is_stormcloak = TRUE
	is_officer = TRUE
	selection_color = "#315972"

	min_positions = 1
	max_positions = 1

/datum/job/civilian/skyrim/stormcloak/ulfric/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak/ulfirc(H), slot_w_uniform)
		//head
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe/tes13/ulfric(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/stormcloak(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/draught(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of the <b>Stormcloaks</b>, an entire rebellion. Organize your men and lead the rebellion to victory, for Skyrim and all her people!</b>.")
	H.setStat("strength", STAT_MAX)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MAX)
	H.setStat("swords", STAT_MAX)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MAX)
	H.setStat("medical", STAT_MAX)
	H.real_name = "Ulfric Stormcloak"
	H.h_style = "Flaired Hair"
	H.f_style = "Goatee"
	H.b_hair = 36
	H.g_hair = 48
	H.r_hair = 59
	H.b_facial = 36
	H.g_facial = 48
	H.r_facial = 59

	return TRUE

/datum/job/civilian/skyrim/stormcloak/lieutenant	//imperial - lieutenant
	title = "Stormcloak Lieutenant"
	rank_abbreviation = ""

	spawn_location = "JoinLateGECap"

	is_commander = TRUE
	is_skyrim = TRUE
	is_officer = TRUE
	is_stormcloak = TRUE
	selection_color = "#315972"

	min_positions = 1
	max_positions = 1

/datum/job/civilian/skyrim/stormcloak/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/tes13/stormcloak(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/stormcloak(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/stormcloak(H), slot_back)
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

/datum/job/civilian/skyrim/stormcloak/sergeant	//imperial - sergeant
	title = "Stormcloak Squad Leader"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_skyrim = TRUE
	is_stormcloak = TRUE
	is_imperial = FALSE
	is_squad_leader = TRUE
	is_officer = TRUE
	uses_squads = TRUE
	selection_color = "#315972"

	min_positions = 1
	max_positions = 4

/datum/job/civilian/skyrim/stormcloak/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
		//clothes
	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak/female(H), slot_w_uniform)
		//head
	if(prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/guard(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/hide(H), slot_head)
		//weapons
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/stormcloak(H), slot_l_hand)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/twohanded(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe/tes13/battleaxe(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>. Organize your <b>men</b> and lead your soldiers to victory!</b>.")
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

/datum/job/civilian/skyrim/stormcloak/soldier //imperial - soldier
	title = "Stormcloak Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_skyrim = TRUE
	is_stormcloak = TRUE
	uses_squads = TRUE
	selection_color = "#315972"

	min_positions = 1
	max_positions = 200

/datum/job/civilian/skyrim/stormcloak/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak/female(H), slot_w_uniform)
//head
	if(prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/guard(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/hide(H), slot_head)
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/tes13/stormcloak(H), slot_l_hand)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/twohanded(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe/tes13/battleaxe(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a rebel soldier. Fight the Empire and liberate Skyrim!")
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

/datum/job/civilian/skyrim/stormcloak/archer //imperial - soldier
	title = "Stormcloak Archer"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_skyrim = TRUE
	is_stormcloak = TRUE
	uses_squads = TRUE
	selection_color = "#315972"

	min_positions = 1
	max_positions = 200

/datum/job/civilian/skyrim/stormcloak/archer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		//clothes
	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tes13/stormcloak/female(H), slot_w_uniform)
		//head
	if(prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/guard(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/tes13/hide(H), slot_head)
		//weapons
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/tes13/steel(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe/tes13(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/longbow(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, the ranged support of the Stormcloaks. Keep the enemy full of arrows and allow the infantry to charge in!</b>.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE