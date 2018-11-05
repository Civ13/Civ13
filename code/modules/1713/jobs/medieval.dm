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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
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
	whitelisted = TRUE
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet1(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon/iron(H), slot_belt)
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
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet3(H), slot_head)
	var/randspear = pick(1,2,3)
	if (randspear == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_belt)
	if (randspear == 1)
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
	title = "Paysan avec Fourche"
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/battleaxe(H), slot_belt)

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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
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
	whitelisted = TRUE
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet1(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon/iron(H), slot_belt)
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
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet3(H), slot_head)
	var/randspear = pick(1,2,3)
	if (randspear == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_belt)
	if (randspear == 1)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/battleaxe(H), slot_belt)

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
