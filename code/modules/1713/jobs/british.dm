/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////BRITISH///////////////////////////////////////////////////////

/datum/job/british
	faction = "Human"

/datum/job/british/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/british/captain
	title = "Royal Navy Captain"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Captain"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_captain(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Captain of the Royal Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/british/qm
	title = "Royal Navy Quartermaster"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Quartermaster"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNQM"
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/qm/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Quartermaster of the Royal Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the ship's supply allocation. You are also the second in command, after the <b>Captain</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/british/boatswain
	title = "Royal Navy Boatswain"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Boatswain"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNBoatswain"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_commander = TRUE
	is_officer = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/boatswain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Boatswain of the Royal Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the crew and their job allocation. The whole ship relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/midshipman
	title = "Royal Navy Midshipman"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Midshipman"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/british/midshipman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer in the ship. Organize your group according to the <b>Boatswain</b>'s orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/surgeon
	title = "Royal Navy Surgeon"
	en_meaning = "Medic"
	rank_abbreviation = "Surgeon"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNSurgeon"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/british/surgeon/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the sailors healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/british/carpenter
	title = "Royal Navy Carpenter"
	en_meaning = "Carpenter"
	rank_abbreviation = "Carpenter"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCarpenter"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/british/carpenter/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor4(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/british_scarf/british_scarf_a = new /obj/item/clothing/accessory/armband/british_scarf(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(british_scarf_a, H)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Quartermaster</b> to ensure everyting is in good conditions!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/cook
	title = "Royal Navy Cook"
	en_meaning = "Cook"
	rank_abbreviation = "Cook"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCook"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/british/cook/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor4(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are the cook of the ship. Feed the whole crew according to the <b>Quartermaster</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW) //not used
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)





////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/british/seaman
	title = "Royal Navy Seaman"
	en_meaning = "Seaman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 200

/datum/job/british/seaman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,4)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/british_sailor4(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/british_scarf/british_scarf_a = new /obj/item/clothing/accessory/armband/british_scarf(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(british_scarf_a, H)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the Royal Navy. Follow your Captain's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

//////////////////////////////ARMY////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/british/army_commander
	title = "British Lieutenant"
	en_meaning = "Infantry Commander"
	rank_abbreviation = "Lt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCap"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_army = TRUE
	is_commander = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/army_commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/rapier(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, the commander or this company. Organize your <b>Sergeant</b> and lead your country to victory!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/british/army_officer
	title = "British Sergeant"
	en_meaning = "Infantry Squad Leader"
	rank_abbreviation = "Sgt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 20

/datum/job/british/army_officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/rapier(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, squad leader. Organize your group of <b>Soldiers</b> according to your <b>Lieutenant</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/field_medic
	title = "British Army Doctor"
	en_meaning = "Infantry Field Medic"
	rank_abbreviation = "Doc."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNSurgeon"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 6

/datum/job/british/field_medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the infantry healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/british/soldier
	title = "British Army Soldier"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 100

/datum/job/british/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a basic infantry soldier of the British Colonial Army. Follow your Officer's orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


	return TRUE

/datum/job/british/chasseur
	title = "British Light Infantry"
	en_meaning = "Light Infantry"
	rank_abbreviation = "Cha."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 20

/datum/job/british/chasseur/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chasseur_british(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/sabre(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/musketoon(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, a light infantry soldier. You are very skilled in melee weapons and can move fast. Your job relies on hit-and-run tactics.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

////////////////////////////WW1///////////////////////
/datum/job/british/ww1captain
	title = "Army Captain"
	rank_abbreviation = "Cap."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/ww1captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british, slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Captain of the British Forces!</big></b>"
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

/datum/job/british/ww1lieutenant
	title = "Army 1st Lieutenant"
	rank_abbreviation = "1Lt."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCap"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/ww1lieutenant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the 1st Lieutenant of the British Forces!</big></b>"
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


/datum/job/british/ww1second_lieutenant
	title = "Army 2nd Lieutenant"
	rank_abbreviation = "2Lt."
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCap"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/ww1second_lieutenant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the 2nd Lieutenant of the British Forces!</big></b>"
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


/datum/job/british/ww1sergeant
	title = "Army Sergeant"
	rank_abbreviation = "Sgt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/british/ww1sergeant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/brodie(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/webley(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c455(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/enfield(H), slot_shoulder)
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

/datum/job/british/ww1doctor
	title = "Army Doctor"
	rank_abbreviation = "Dr."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNSurgeon"
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/british/ww1doctor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/britishcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
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
/datum/job/british/ww1shocktroop
	title = "Shock Troop"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN" //for testing!
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 200

/datum/job/british/ww1shocktroop/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/brodie(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/p14enfield(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/british/newplate = new /obj/item/clothing/accessory/armor/modern/british(null)
	uniform.attackby(newplate, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier specialized in infiltration and shock tactics. Lead the way for your fellow soldiers to the enemy trenches!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/british/ww1infantry
	title = "Army Private"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN" //for testing!
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 400

/datum/job/british/ww1infantry/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/british(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/brodie(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/enfield(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/british(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/british/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/british(null)
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Royal Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE