/datum/job/french
	faction = "Station"

/datum/job/french/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_french_name(H.gender)
	H.real_name = H.name

/datum/job/french/captain
	title = "Capitaine"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Capitaine"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFRCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_captain(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_french(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Captain of the French Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE

/datum/job/french/qm
	title = "Quartier-Maître"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Qua.-Maî."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFRQM"
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/qm/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_french(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Quartermaster of the French Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the ship's supply allocation. You are also the second in command, after the <b>Capitaine</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE

/datum/job/french/boatswain
	title = "Chef d'équipage"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Chef d'eq."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFRBoatswain"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_commander = TRUE
	is_officer = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/boatswain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_french(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Boatswain of the French Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the crew and their job allocation. The whole ship relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE

/datum/job/french/midshipman
	title = "Aspirant"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Aspirant"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFRMidshipman"
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5

/datum/job/french/midshipman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor1(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer, slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer in the ship. Organize your group according to the <b>Chef d'équipage</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE

/datum/job/french/surgeon
	title = "Chirurgien"
	en_meaning = "Medic"
	rank_abbreviation = "Chirurgien"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFRSurgeon"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/french/surgeon/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor1(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the sailors healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("shotgun", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/french/carpenter
	title = "Charpentier"
	en_meaning = "Carpenter"
	rank_abbreviation = "Charpentier"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFRCarpenter"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3

/datum/job/french/carpenter/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/boarding_axe(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Quartier-maître</b> to ensure everyting is in good conditions!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/french/cook
	title = "Cuisinier"
	en_meaning = "Cook"
	rank_abbreviation = "Cuisinier"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFRCook"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3

/datum/job/french/cook/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef/classic(H), slot_wear_suit)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are the cook of the ship. Feed the whole crew according to the <b>Quartier-maître</b> orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW) //not used
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_MEDIUM_LOW)




////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/french/seaman
	title = "Matelot"
	en_meaning = "Seaman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN" //for testing!
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 20

/datum/job/french/seaman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor3(H), slot_w_uniform)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the french Marine Royale. Follow your <b>Capitaine</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("engineering", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("shotgun", STAT_NORMAL)

	return TRUE
