/////////////BRITISH//////////////////////////
/datum/job/british/medieval_lord
	title = "Lord"
	en_meaning = "Lord"
	rank_abbreviation = "Lord"


	spawn_location = "JoinLateRN"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_medieval = TRUE


	min_positions = 1
	max_positions = 1


/datum/job/british/medieval_lord/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/meat(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/broadsword(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/steel(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/h = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform.attackby(h, H)
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
	give_random_name(H)

	return TRUE

/datum/job/british/medieval_knight
	title = "Knight"
	en_meaning = "Knight"
	rank_abbreviation = "Knight"

	spawn_location = "JoinLateRN"
	is_officer = TRUE
	whitelisted = TRUE

	is_medieval = TRUE


	min_positions = 1
	max_positions = 5

/datum/job/british/medieval_knight/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/red(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/military(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longsword/h = new /obj/item/clothing/accessory/storage/sheath/longsword(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a landed citizen of the Realm. You are a heavy soldier, so protect the Lord!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)


	return TRUE

/datum/job/british/medieval_swordsman
	title = "Men-at-Arms"
	en_meaning = "Swordsman"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	is_medieval = TRUE


	min_positions = 5
	max_positions = 25

/datum/job/british/medieval_swordsman/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/meat(H), slot_r_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a trained swordsman. You have good armor, compared to the lower-ranking conscripted militias and levies.")
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

/datum/job/british/medieval_spearman
	title = "Levy Pikeman"
	en_meaning = "Levy Pikeman"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	is_medieval = TRUE


	min_positions = 12
	max_positions = 80

/datum/job/british/medieval_spearman/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/iron(H), slot_shoulder)
	if (randspear == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_shoulder)
	if (randspear == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/halberd(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/shield/red_buckler(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/meat(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant spearman. You have basic armor and a shield. You are in charge of fighting in the frontlines!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)


	return TRUE

/datum/job/british/medieval_archer
	title = "Levy Archer"
	en_meaning = "Levy Archer"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	is_medieval = TRUE


	min_positions = 6
	max_positions = 40

/datum/job/british/medieval_archer/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/meat(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/longbow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant archer. You have basic armor and a bow and arrow. You are in charge of harassing the enemy troops from a safe distance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/british/medieval_militia
	title = "Levy Militia"
	en_meaning = "Levy Militia"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	is_medieval = TRUE


	min_positions = 18
	max_positions = 100

/datum/job/british/medieval_militia/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/iron(H), slot_back)
	if (randwep == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pitchfork(H), slot_back)
	if (randwep == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/club(H), slot_belt)
	if (randwep == 4)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/meat(H), slot_l_store)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_l_hand)
	var/obj/item/clothing/accessory/armband/british/fr_a = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fr_a, H)
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant militia with no combat experience. You are barely armed, so be sure to loot!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE

///////////////FRENCH/////////////////
/datum/job/french/medieval_lord
	title = "Seigneur"
	en_meaning = "Lord"
	rank_abbreviation = "Seigneur"


	spawn_location = "JoinLateFR"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_medieval = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/french/medieval_lord/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/iron_chestplate/blue(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/h = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform.attackby(h, H)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat2(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fish(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/broadsword(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/steel(H), slot_l_hand)
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
	give_random_name(H)

	return TRUE

/datum/job/french/medieval_knight
	title = "Chevalier"
	en_meaning = "Knight"
	rank_abbreviation = "Chevalier"

	spawn_location = "JoinLateFR"
	is_officer = TRUE
	whitelisted = TRUE

	is_medieval = TRUE


	min_positions = 1
	max_positions = 5

/datum/job/french/medieval_knight/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets(H), slot_gloves)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longsword/h = new /obj/item/clothing/accessory/storage/sheath/longsword(null)
	uniform.attackby(h, H)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/military(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a landed citizen of the Realm. You are a heavy soldier, so protect the Lord!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/french/medieval_swordsman
	title = "Homme dArme"
	en_meaning = "Swordsman"
	rank_abbreviation = ""

	spawn_location = "JoinLateFR"

	is_medieval = TRUE


	min_positions = 5
	max_positions = 25

/datum/job/french/medieval_swordsman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fish(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)
	H.add_note("Role", "You are a <b>[title]</b>, a trained swordsman. You have good armor, compared to the lower-ranking conscripted militias and levies.")
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

/datum/job/french/medieval_spearman
	title = "Paysan avec Pique"
	en_meaning = "Levy Pikeman"
	rank_abbreviation = ""

	spawn_location = "JoinLateFR"

	is_medieval = TRUE


	min_positions = 12
	max_positions = 80

/datum/job/french/medieval_spearman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/iron(H), slot_shoulder)
	if (randspear == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_shoulder)
	if (randspear == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/halberd(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fish(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_back)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)
	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant spearman. You have basic armor and a shield. You are in charge of fighting in the frontlines!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/french/medieval_archer
	title = "Paysan Archer"
	en_meaning = "Levy Archer"
	rank_abbreviation = ""

	spawn_location = "JoinLateFR"

	is_medieval = TRUE


	min_positions = 6
	max_positions = 40

/datum/job/french/medieval_archer/equip(var/mob/living/human/H)
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

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/crossbow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/crossbow(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/meat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)
	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant archer. You have basic armor and a crossbow and bolts. You are in charge of harassing the enemy troops from a safe distance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/french/medieval_militia
	title = "Milice"
	en_meaning = "Levy Militia"
	rank_abbreviation = ""

	spawn_location = "JoinLateFR"

	is_medieval = TRUE


	min_positions = 18
	max_positions = 100

/datum/job/french/medieval_militia/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/iron(H), slot_back)
	if (randwep == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/pitchfork(H), slot_back)
	if (randwep == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/club(H), slot_belt)
	if (randwep == 4)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/meat(H), slot_l_store)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_l_hand)
	var/obj/item/clothing/accessory/armband/french/fr_a = new /obj/item/clothing/accessory/armband/french(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fr_a, H)
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)
	H.add_note("Role", "You are a <b>[title]</b>, a levied peasant militia with no combat experience. You are barely armed, so be sure to loot!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE


///////////////////////////////////////////////FRENCH//CRUSADERS/////////////////////////////////////////

/datum/job/french/crusader_lord
	title = "Grand Master"
	en_meaning = "Crusader Leader"
	rank_abbreviation = "Grand Master"


	spawn_location = "JoinLateFR"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_medieval = TRUE
	is_crusader = TRUE


	min_positions = 1
	max_positions = 1


/datum/job/french/crusader_lord/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/templar(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/crusaderking(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/baltic_crusaderking(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/broadsword(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fish(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/steel(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/h = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform.attackby(h, H)

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
	H.setStat("throwing", STAT_MEDIUM_HIGH)
	give_random_name(H)



	return TRUE

/datum/job/french/crusader_templar
	title = "Templar Knight"
	en_meaning = "Crusader Noble Knight"
	rank_abbreviation = "Templar Knight"

	spawn_location = "JoinLateFR"
	is_officer = TRUE
	whitelisted = TRUE

	is_medieval = TRUE
	is_crusader = TRUE


	min_positions = 2
	max_positions = 10


/datum/job/french/crusader_templar/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/templar(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/templar(H), slot_head)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar2(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/broadsword(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fish/silver(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets(H), slot_gloves)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longer/h = new /obj/item/clothing/accessory/storage/sheath/longer(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a Knight who joined the Templars. Lead your bretheren to victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)


	return TRUE

/datum/job/french/crusader_heavy
	title = "Crusader Sergeant"
	en_meaning = "Crusader Heavy Infantry"
	rank_abbreviation = ""

	spawn_location = "JoinLateFR"

	is_medieval = TRUE
	is_crusader = TRUE


	min_positions = 8
	max_positions = 50

/datum/job/french/crusader_heavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/crusader(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif_helmet(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword/iron(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/blackknife(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_l_store)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval/templar2(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longsword/h = new /obj/item/clothing/accessory/storage/sheath/longsword(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a trained swordsman and heavy infantry of the order. Fight the infidels!")
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

/datum/job/french/crusader_light
	title = "Crusader Squire"
	en_meaning = "Crusader Light Infantry"
	rank_abbreviation = ""

	spawn_location = "JoinLateFR"

	is_medieval = TRUE
	is_crusader = TRUE

	min_positions = 12
	max_positions = 80

/datum/job/french/crusader_light/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/crusader(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)

//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif(H), slot_head)

	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/halberd(H), slot_shoulder)


	H.equip_to_slot_or_del(new /obj/item/weapon/shield/red_buckler(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fish(H), slot_r_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/crossbow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/crossbow(H), slot_back)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)


	H.add_note("Role", "You are a <b>[title]</b>, newly arrived member of the Templar Order. Assist your fellow members in defending the faith!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)


	return TRUE

/datum/job/french/crusader_priest
	title = "Templar Priest"
	en_meaning = "Priest"
	rank_abbreviation = "Father"

	spawn_location = "JoinLateFR"

	is_medieval = TRUE
	is_crusader = TRUE
	is_religious = TRUE

	min_positions = 1
	max_positions = 5


/datum/job/french/crusader_priest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/cognac(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery_bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fish(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/red_buckler(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, an annointed member of the Templar Order. Take care of the injured soldiers and keep the morale up!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE




///////////////////////////////////////////////////////
/////////////////////ARABS/////////////////////////////
//////////////////////////////////////////////////////
/datum/job/arab
	faction = "Human"

/datum/job/arab/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_arab_name()
	H.real_name = H.name

/datum/job/arab/medieval_lord
	title = "Emir"
	en_meaning = "Lord"
	rank_abbreviation = "Emir"
	is_arabcaliph = TRUE

	spawn_location = "JoinLateAR"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_medieval = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/arab/medieval_lord/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/emirate(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/emirate(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/emirate(H), slot_wear_suit)
//head

	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/emirate(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fancy/silver(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/saif(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/scimitar(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/steel(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/thrown/h = new /obj/item/clothing/accessory/storage/sheath/thrown(null)
	uniform.attackby(h, H)

	var/obj/item/weapon/material/thrown/throwing_knife/thrown1 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	var/obj/item/weapon/material/thrown/throwing_knife/thrown2 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	var/obj/item/weapon/material/thrown/throwing_knife/thrown3 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	var/obj/item/weapon/material/thrown/throwing_knife/thrown4 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	uniform.attackby(thrown1, H)
	uniform.attackby(thrown2, H)
	uniform.attackby(thrown3, H)
	uniform.attackby(thrown4, H)

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
	H.setStat("throwing", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/arab/medieval_knight
	title = "Mamluk"
	en_meaning = "Heavy Infantry"
	rank_abbreviation = "Mamluk"
	is_arabcaliph = TRUE

	spawn_location = "JoinLateAR"
	is_officer = TRUE
	whitelisted = TRUE

	is_medieval = TRUE


	min_positions = 2
	max_positions = 10

/datum/job/arab/medieval_knight/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets(H), slot_gloves)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/hauberk(H), slot_wear_suit)

//head
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/arab2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/arab3(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/military/iron(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/saif(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/longsword/h = new /obj/item/clothing/accessory/storage/sheath/longsword(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a member of the slave-soldier caste of the Caliphate. Assist the <b>Emir</b> organize the troops!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/arab/medieval_swordsman
	title = "Sayaf"
	en_meaning = "Swordsman"
	rank_abbreviation = ""
	is_arabcaliph = TRUE

	spawn_location = "JoinLateAR"

	is_medieval = TRUE


	min_positions = 12
	max_positions = 80

/datum/job/arab/medieval_swordsman/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fancy/silver(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/scimitar(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets(H), slot_gloves)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/thrown/h = new /obj/item/clothing/accessory/storage/sheath/thrown(null)
	uniform.attackby(h, H)

	var/obj/item/weapon/material/thrown/throwing_knife/thrown1 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	var/obj/item/weapon/material/thrown/throwing_knife/thrown2 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	var/obj/item/weapon/material/thrown/throwing_knife/thrown3 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	var/obj/item/weapon/material/thrown/throwing_knife/thrown4 = new /obj/item/weapon/material/thrown/throwing_knife(null)
	uniform.attackby(thrown1, H)
	uniform.attackby(thrown2, H)
	uniform.attackby(thrown3, H)
	uniform.attackby(thrown4, H)

	H.add_note("Role", "You are a <b>[title]</b>, an arabic swordsman. Use hit-and-run tactics to defeat the infidels!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("throwing", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/arab/medieval_spearman
	title = "Alraamih"
	en_meaning = "Spearman"
	rank_abbreviation = ""
	is_arabcaliph = TRUE

	spawn_location = "JoinLateAR"

	is_medieval = TRUE


	min_positions = 12
	max_positions = 80

/datum/job/arab/medieval_spearman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/iron(H), slot_shoulder)
	if (randspear == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_shoulder)
	if (randspear == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/halberd(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fancy/silver(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, an arabic pikeman. Use hit-and-run tactics to defeat the infidels!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/arab/medieval_archer
	title = "Rami Alsiham"
	en_meaning = "Archer"
	rank_abbreviation = ""
	is_arabcaliph = TRUE

	spawn_location = "JoinLateAR"

	is_medieval = TRUE


	min_positions = 6
	max_positions = 40

/datum/job/arab/medieval_archer/equip(var/mob/living/human/H)
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


	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/longbow(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fancy/silver(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/h = new /obj/item/clothing/accessory/storage/sheath(null)
	uniform.attackby(h, H)
	H.add_note("Role", "You are a <b>[title]</b>, an arabic archer. Use hit-and-run tactics to defeat the infidels!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE


/datum/job/arab/imam
	title = "Imam"
	en_meaning = "Priest"
	rank_abbreviation = "Imam"
	is_arabcaliph = TRUE

	spawn_location = "JoinLateAR"

	is_medieval = TRUE
	is_religious = TRUE


	min_positions = 1
	max_positions = 5

/datum/job/arab/imam/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban/imam(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/arab_buckler(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/pill/opium(H), slot_l_ear)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/pill/opium(H), slot_r_ear)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/tea(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery_bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fancy/silver(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are an <b>[title]</b>, an Islamic religious leader.  Take care of the injured soldiers and keep the morale up!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/german/lord
	title = "Freiherr"
	en_meaning = "Baron"
	rank_abbreviation = "Freiherr"


	spawn_location = "JoinLateGECap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = FALSE
	is_rp = TRUE
	is_medieval = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/german/lord/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat2(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/hall(H), slot_l_store)
	world << "<b><big>[H.real_name] is the Bohemian Lord!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the absolute Lord of this state. Organize your subjects!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/german/retainer
	title = "Dienstmann"
	en_meaning = "Retainer"
	rank_abbreviation = "Dienstmann"

	spawn_location = "JoinLateGECap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE
	is_ww1 = FALSE
	is_rp = TRUE
	is_medieval = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/german/retainer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(H), slot_w_uniform)
//jacket
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/noblehat2(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/hall(H), slot_l_store)

	world << "<b><big>[H.real_name] is the Bohemian Retainer!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the retainer to the Lord of this state. Recruit staff to serve the lord in the castle and keep them well mannered! Keep the lord safe!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/german/medieval_knight
	title = "Ritter"
	en_meaning = "Knight"
	rank_abbreviation = "Herr"

	spawn_location = "JoinLateGE"
	is_officer = TRUE
	whitelisted = TRUE

	is_medieval = TRUE
	is_rp = TRUE
	is_squad_leader = TRUE


	min_positions = 1
	max_positions = 3

/datum/job/german/medieval_knight/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/knight(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/red(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/hall(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/escudo/ten(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a landed citizen of the Realm. You are a heavy soldier, so protect the Lord!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/german/medieval_swordsman
	title = "Wachmann"
	en_meaning = "Guardsman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_medieval = TRUE
	is_rp = TRUE


	min_positions = 5
	max_positions = 15

/datum/job/german/medieval_swordsman/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/helmet1(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/twenty(H), slot_l_store)

	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron/semioval(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a trained swordsman. You have good armor, compared to the lower-ranking conscripted militias and levies. Protect the Lord and his city!")
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

/datum/job/german/priest
	title = "Pfaffe"
	en_meaning = "Church Priest"
	rank_abbreviation = ""

	spawn_location = "JoinLateCivC"

	is_religious = TRUE
	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/german/priest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)

	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/nun(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/nun_hood(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/twenty(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of the colony's religious affairs, assisting the doctor, and if possible, of converting the natives...")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)

	return TRUE

/datum/job/german/prospector
	title = "Kumpel"
	en_meaning = "Miner/Explorer"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"

	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/german/prospector/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/weapon/material/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/shovel(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifty(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a miner who is tasked with collecting metals for the local lord and smithy. Explore the area, mine, and sell to the <b>Merchant or Blacksmith</b> what you find!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/german/farmer
	title = "Bauer"
	en_meaning = "Farmer/Rancher"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"

	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE

	min_positions = 3
	max_positions = 10

/datum/job/german/farmer/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifty(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("farming", STAT_VERY_HIGH)

	return TRUE

/datum/job/german/blacksmith
	title = "Schmied"
	en_meaning = "Blacksmith"
	rank_abbreviation = "Blacksmith"

	spawn_location = "JoinLateCivB"
	whitelisted = TRUE

	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/german/blacksmith/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/hammer(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/stack/material/iron/twentyfive(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/twenty(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>. Your job is to craft weapons and guns. However, you probably should follow the <b>Governor's</b> orders!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_VERY_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)

	return TRUE

/datum/job/german/inkeeper
	title = "Gastwirst"
	en_meaning = "Innkeeper"
	rank_abbreviation = ""

	spawn_location = "JoinLateCivD"

	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE


	min_positions = 1
	max_positions = 2

/datum/job/german/inkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifty(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to run an Inn and house tired customers!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/german/barkeep
	title = "Kneiper"
	en_meaning = "Taverner/Barkeeper"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"

	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/german/barkeep/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifty(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Barkeeper</b>. Your job is to man the Tavern to supply the people with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)


	return TRUE

/datum/job/german/worker
	title = "Kleinbauer"
	en_meaning = "Basic Peasant"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"

	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE


	min_positions = 10
	max_positions = 50

/datum/job/german/worker/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real/fifty(H), slot_l_store)

	H.add_note("Role", "You are a simple <b>Peasant</b>. Live your life!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/german/merchant
	title = "Kaufmann"
	en_meaning = "Merchant/Trader"
	rank_abbreviation = "Kaufmann"

	spawn_location = "JoinLateCivA"
	is_merchant = TRUE

	whitelisted = TRUE
	is_medieval = TRUE
	is_rp = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 3

/datum/job/german/merchant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/twenty(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/twenty(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.make_businessman()

	return TRUE

/datum/job/german/medic
	title = "Arzt"
	en_meaning = "Doctor"
	rank_abbreviation = "Arzt"

	spawn_location = "JoinLateRNSurgeon"

	is_medic = TRUE
	is_medieval = TRUE
	is_rp = TRUE


	min_positions = 1
	max_positions = 20

/datum/job/german/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/dollar/twenty(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the people and peasants healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE