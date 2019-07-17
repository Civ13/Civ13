/datum/job/french
	faction = "Human"

/datum/job/french/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_french_name(H.gender)
	H.real_name = H.name

/datum/job/french/captain
	title = "Capitaine"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Capitaine"
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
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/qm
	title = "Quartier-Maître"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Qua.-Maî."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNQM"
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
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/boatswain
	title = "Chef déquipage"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Chef deq."
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
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/midshipman
	title = "Aspirant"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Aspirant"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

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
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/surgeon
	title = "Chirurgien"
	en_meaning = "Medic"
	rank_abbreviation = "Chirurgien"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNSurgeon"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/french/surgeon/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/french_sailor1(H), slot_w_uniform) // for now
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

/datum/job/french/carpenter
	title = "Charpentier Naval"
	en_meaning = "Carpenter"
	rank_abbreviation = "Charpentier"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCarpenter"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

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

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Quartier-maître</b> to ensure everyting is in good conditions!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/cook
	title = "Cuisinier"
	en_meaning = "Cook"
	rank_abbreviation = "Cuisinier"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNCook"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/french/cook/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)

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
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW) //not used
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)





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
	max_positions = 200

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
		H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the french Marine Royale. Follow your <b>Capitaine</b> orders!")
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
/datum/job/french/army_commander
	title = "Lieutenant"
	en_meaning = "Infantry Commander"
	rank_abbreviation = "Ltn."
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePTCap"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_army = TRUE
	is_commander = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/army_commander/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_french(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/rapier(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, the commander or this company. Organize your <b>Sergent</b> and lead your country to victory!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/french/army_officer
	title = "Sergent"
	en_meaning = "Infantry Squad Leader"
	rank_abbreviation = "Srg."
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePTMidshipman"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 20

/datum/job/french/army_officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/french_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/rapier(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, squad leader. Organize your group of <b>Soldat</b> according to your <b>Lieutenant</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/field_medic
	title = "Docteur"
	en_meaning = "Infantry Field Medic"
	rank_abbreviation = "Doc."
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePTSurgeon"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 6

/datum/job/french/field_medic/equip(var/mob/living/carbon/human/H)
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

/datum/job/french/soldier
	title = "Soldat"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 100

/datum/job/french/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/french_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a basic infantry soldier of the French Colonial Army. Follow your Officer's orders!")
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

/datum/job/french/chasseur
	title = "Chasseur"
	en_meaning = "Light Infantry"
	rank_abbreviation = "Cha."
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_army = TRUE

	// AUTOBALANCE
	min_positions = 4
	max_positions = 20

/datum/job/french/chasseur/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/french_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chasseur_french(H), slot_head)

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
/datum/job/french/ww1captain
	title = "Capitaine de le Armée"
	en_meaning = "Army Captain"
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

/datum/job/french/ww1captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/french, slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/frenchcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/m1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8x27(H), slot_l_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Captain of the French Forces!</big></b>"
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

/datum/job/french/ww1lieutenant
	title = "Lieutenant de le Armée"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "Lt."
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

/datum/job/french/ww1lieutenant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/french(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/frenchcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/m1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8x27(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the 1st Lieutenant of the French Forces!</big></b>"
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


/datum/job/french/ww1second_lieutenant
	title = "Sous-Lieutenant de le Armée"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = "Slt."
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

/datum/job/french/ww1second_lieutenant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/french(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/frenchcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/m1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8x27(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the 2nd Lieutenant of the French Forces!</big></b>"
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


/datum/job/french/ww1sergeant
	title = "Sergeant de le Armée"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Sgt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	is_officer = TRUE
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/french/ww1sergeant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/french(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adrian(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/french(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/m1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8x27(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/lebel(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Lieutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/ww1doctor
	title = "Docteur de le Armée"
	en_meaning = "Doctor"
	rank_abbreviation = "Dr."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRNSurgeon"
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 10

/datum/job/french/ww1doctor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/french(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/frenchcap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)

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

/datum/job/french/ww1shocktroop
	title = "Chasseur Léger"
	en_meaning = "Shock Troop"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN" //for testing!
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 200

/datum/job/french/ww1shocktroop/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/french(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adrian(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/berthier(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/french(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/plate/newplate = new /obj/item/clothing/accessory/armor/modern/plate(null)
	uniform.attackby(newplate, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier specialized in infiltration and shock tactics. Lead the way for your fellow soldiers to the enemy trenches!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/ww1infantry
	title = "Soldat de infanterie"
	en_meaning = "Private"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN" //for testing!
	SL_check_independent = TRUE
	is_ww1 = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 400

/datum/job/french/ww1infantry/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/french(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adrian(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/lebel(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/french(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/french/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/french(null)
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the French Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE