///////////////FRENCH/////////////////
/datum/job/french/medieval_lord
	title = "Seigneur"
	en_meaning = "Lord"
	rank_abbreviation = "Seigneur"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/medieval_lord/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/iron_chestplate/blue(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat2(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	world << "<b><big>[H.real_name] is the French Lord!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the absolute Lord of this army. Organize your men!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/medieval_knight
	title = "Chevalier"
	en_meaning = "Knight"
	rank_abbreviation = "Chevalier"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	is_officer = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5

/datum/job/french/medieval_knight/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/blue(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a landed citizen of the Realm. You are a heavy soldier, so protect the Lord!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/medieval_swordsman
	title = "Homme dArme"
	en_meaning = "Swordsman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 5
	max_positions = 25

/datum/job/french/medieval_swordsman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a trained swordsman. You have good armor, compared to the lower-ranking conscripted militias and levies.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/medieval_spearman
	title = "Paysan avec Pique"
	en_meaning = "Levy Pikeman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 80

/datum/job/french/medieval_spearman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)

//head
	var/randhead = pick(1,2,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)
	if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet3(H), slot_head)
	if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet1(H), slot_head)
	var/randspear = pick(1,2,3)
	if (randspear == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_belt)
	if (randspear == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pike(H), slot_belt)
	if (randspear == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/halberd(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant spearman. You have basic armor and a shield. You are in charge of fighting in the frontlines!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/medieval_archer
	title = "Paysan Archer"
	en_meaning = "Levy Archer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 40

/datum/job/french/medieval_archer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
//jacket
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet3(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant archer. You have basic armor and a bow and arrow. You are in charge of harassing the enemy troops from a safe distance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/french/medieval_militia
	title = "Milice"
	en_meaning = "Levy Militia"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 18
	max_positions = 100

/datum/job/french/medieval_militia/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	var/randclothes = pick(1,2,3,4)
	if (randclothes == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	if (randclothes == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
	if (randclothes == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	if (randclothes == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
//jacket
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)
//head
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)

	var/randwep = pick(1,2,3,4)
	if (randwep == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_back)
	if (randwep == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pitchfork(H), slot_back)
	if (randwep == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/club(H), slot_belt)
	if (randwep == 4)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(H), slot_l_store)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_l_hand)
	var/obj/item/clothing/accessory/armband/french/fr_a = new /obj/item/clothing/accessory/armband/french(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fr_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant militia with no combat experience. You are barely armed, so be sure to loot!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)

	return TRUE


///////////////////////////////////////////////FRENCH//CRUSADERS/////////////////////////////////////////

/datum/job/french/crusader_lord
	title = "Grand Master"
	en_meaning = "Crusader Leader"
	rank_abbreviation = "Grand Master"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE
	is_crusader = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/crusader_lord/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/iron_chestplate/crusader(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat2(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	world << "<b><big>[H.real_name] is the French Lord!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the Leader of the Templar Knights in the Holy Land. Defend Christianity!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/crusader_templar
	title = "Templar Knight"
	en_meaning = "Crusader Noble Knight"
	rank_abbreviation = "Templar Knight"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	is_officer = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE
	is_crusader = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10

/datum/job/french/crusader_templar/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/templar(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/templar(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_belt)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar2(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a Knight who joined the Templars. Lead your bretheren to victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/crusader_heavy
	title = "Crusader Sergeant"
	en_meaning = "Crusader Heavy Infantry"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	SL_check_independent = TRUE
	is_medieval = TRUE
	is_crusader = TRUE

	// AUTOBALANCE
	min_positions = 8
	max_positions = 50

/datum/job/french/crusader_heavy/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/crusader(H), slot_w_uniform)

//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif_helmet(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_belt)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar2(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a trained swordsman and heavy infantry of the order. Fight the infidels!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/crusader_light
	title = "Crusader Squire"
	en_meaning = "Crusader Light Infantry"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	SL_check_independent = TRUE
	is_medieval = TRUE
	is_crusader = TRUE
	// AUTOBALANCE
	min_positions = 12
	max_positions = 80

/datum/job/french/crusader_light/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/crusader(H), slot_w_uniform)

//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif(H), slot_head)

	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pike(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/halberd(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)

	H.add_note("Role", "You are a <b>[title]</b>, newly arrived member of the Templar Order. Assist your fellow members in defending the faith!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/french/crusader_priest
	title = "Templar Priest"
	en_meaning = "Priest"
	rank_abbreviation = "Father"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateFR"
	SL_check_independent = TRUE
	is_medieval = TRUE
	is_crusader = TRUE
	is_religious = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 4

/datum/job/french/crusader_priest/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, an annointed member of the Templar Order. Take care of the injured soldiers and keep the morale up!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)


	return TRUE

/////////////BRITISH//////////////////////////
/datum/job/british/medieval_lord
	title = "Lord"
	en_meaning = "Lord"
	rank_abbreviation = "Lord"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/medieval_lord/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/iron_chestplate/red(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat2(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	world << "<b><big>[H.real_name] is the British Lord!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the absolute Lord of this army. Organize your men!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/british/medieval_knight
	title = "Knight"
	en_meaning = "Knight"
	rank_abbreviation = "Knight"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	is_officer = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5

/datum/job/british/medieval_knight/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/red(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a landed citizen of the Realm. You are a heavy soldier, so protect the Lord!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/medieval_swordsman
	title = "Men-at-Arms"
	en_meaning = "Swordsman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 5
	max_positions = 25

/datum/job/british/medieval_swordsman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif_helmet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a trained swordsman. You have good armor, compared to the lower-ranking conscripted militias and levies.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/medieval_spearman
	title = "Levy Pikeman"
	en_meaning = "Levy Pikeman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 80

/datum/job/british/medieval_spearman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)

//head
	var/randhead = pick(1,2,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)
	if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet3(H), slot_head)
	if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet1(H), slot_head)
	var/randspear = pick(1,2,3)
	if (randspear == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_belt)
	if (randspear == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pike(H), slot_belt)
	if (randspear == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/halberd(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/shield/red_buckler(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant spearman. You have basic armor and a shield. You are in charge of fighting in the frontlines!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/british/medieval_archer
	title = "Levy Archer"
	en_meaning = "Levy Archer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 40

/datum/job/british/medieval_archer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red2(H), slot_w_uniform)
//jacket
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet3(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant archer. You have basic armor and a bow and arrow. You are in charge of harassing the enemy troops from a safe distance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/british/medieval_militia
	title = "Levy Militia"
	en_meaning = "Levy Militia"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 18
	max_positions = 100

/datum/job/british/medieval_militia/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	var/randclothes = pick(1,2,3,4)
	if (randclothes == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
	if (randclothes == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red2(H), slot_w_uniform)
	if (randclothes == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	if (randclothes == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
//jacket
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)
//head
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)

	var/randwep = pick(1,2,3,4)
	if (randwep == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_back)
	if (randwep == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pitchfork(H), slot_back)
	if (randwep == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/club(H), slot_belt)
	if (randwep == 4)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(H), slot_l_store)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_l_hand)
	var/obj/item/clothing/accessory/armband/british/fr_a = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fr_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant militia with no combat experience. You are barely armed, so be sure to loot!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)

	return TRUE


///////////////////////////////////////////////////////
/////////////////////ARABS/////////////////////////////
//////////////////////////////////////////////////////
/datum/job/arab
	faction = "Human"

/datum/job/arab/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_arab_name()
	H.real_name = H.name

/datum/job/arab/medieval_lord
	title = "Emir"
	en_meaning = "Lord"
	rank_abbreviation = "Emir"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateAR"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/arab/medieval_lord/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/arabic_robe(H), slot_wear_suit)
//head

	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/saif(H), slot_belt)
	world << "<b><big>[H.real_name] is the Emir!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the military leader of this group of soldiers. Defeat the crusaders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/arab/medieval_knight
	title = "Mamluk"
	en_meaning = "Heavy Infantry"
	rank_abbreviation = "Mamluk"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateAR"
	is_officer = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10

/datum/job/arab/medieval_knight/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/hauberk(H), slot_wear_suit)
//head
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/arab2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/arab3(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/pike(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/saif(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the slave-soldier caste of the Caliphate. Assist the <b>Emir</b> organize the troops!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/arab/medieval_swordsman
	title = "Sayaf"
	en_meaning = "Swordsman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateAR"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 80

/datum/job/arab/medieval_swordsman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab3(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/arab(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/scimitar(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, an arabic swordsman. Use hit-and-run tactics to defeat the infidels!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/arab/medieval_spearman
	title = "Alraamih"
	en_meaning = "Spearman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateAR"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 80

/datum/job/arab/medieval_spearman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab3(H), slot_w_uniform)

//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/arab(H), slot_head)

	var/randspear = pick(1,2,3)
	if (randspear == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_belt)
	if (randspear == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pike(H), slot_belt)
	if (randspear == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/halberd(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, an arabic pikeman. Use hit-and-run tactics to defeat the infidels!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/arab/medieval_archer
	title = "Rami Alsiham"
	en_meaning = "Archer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateAR"
	SL_check_independent = TRUE
	is_medieval = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 40

/datum/job/arab/medieval_archer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/arab(H), slot_head)


	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, an arabic archer. Use hit-and-run tactics to defeat the infidels!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/arab/imam
	title = "Imam"
	en_meaning = "Priest"
	rank_abbreviation = "Imam"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateAR"
	SL_check_independent = TRUE
	is_medieval = TRUE
	is_religious = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 5

/datum/job/arab/imam/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban/imam(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are an <b>[title]</b>, an islamic religious leader.  Take care of the injured soldiers and keep the morale up!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)

	return TRUE
