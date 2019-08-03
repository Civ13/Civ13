/datum/job/indians
	faction = "Human"
	var/tribe = "Carib"


/datum/job/indians/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_carib_name(H.gender)
	H.real_name = H.name

/datum/job/indians/carib_chief
	title = "Carib Elder"
	en_meaning = "Native Elder/Leader"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND"
	SL_check_independent = TRUE
	is_officer = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 20
/datum/job/indians/carib_chief/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chief_hat(H), slot_head)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/indianchief(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/indian2_a = new /obj/item/clothing/accessory/armband/indian2(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indian2_a, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/tribal(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/tribal(H), slot_r_hand)
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>Elder</b> of a Carib tribe. Organize your <b>Tribesmen</b> and take out the invaders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_NORMAL)


	return TRUE

/datum/job/indians/carib_shaman
	title = "Carib Shaman"
	en_meaning = "Native Shaman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 30
/datum/job/indians/carib_shaman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/indianshaman(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/indianshaman_a = new /obj/item/clothing/accessory/armband/indianshaman(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indianshaman_a, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bone(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/skullmask(H), slot_wear_mask)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/bruise_pack/herbs(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/bruise_pack/herbs(H), slot_r_store)
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>Shaman</b>, the healer and religious leader of your tribe. Keep your fellow tribesmen healthy and motivated!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/indians/carib
	title = "Carib Tribesman"
	en_meaning = "Native Tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 20
	max_positions = 300

/datum/job/indians/carib/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	var/obj/item/clothing/accessory/armband/indian1_a = new /obj/item/clothing/accessory/armband/indian1(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indian1_a, H)
	var/randweapon = rand(1,3)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_back)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
	else if (randweapon == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/club(H), slot_l_hand)
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a member of a Carib tribe. Organize with your <b>Chief</b> and take out the invaders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////TRIBES//RP//STUFF//////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/indians/tribes/red
	title = "Red Goose Tribesman"
	en_meaning = FALSE
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND1"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/red/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	var/obj/item/clothing/accessory/armband/indianr_a = new /obj/item/clothing/accessory/armband/indianr(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indianr_a, H)

	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Red Goose</b> tribe. You should wear red clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

datum/job/indians/tribes/blue
	title = "Blue Turkey Tribesman"
	en_meaning = FALSE
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND2"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/blue/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	var/obj/item/clothing/accessory/armband/indianb_a = new /obj/item/clothing/accessory/armband/indianb(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indianb_a, H)

	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Blue Turkey</b> tribe. You should wear blue clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

datum/job/indians/tribes/green
	title = "Green Monkey Tribesman"
	en_meaning = FALSE
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND3"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/green/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	var/obj/item/clothing/accessory/armband/indiang_a = new /obj/item/clothing/accessory/armband/indiang(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indiang_a, H)

	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Green Monkey</b> tribe. You should wear green clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

datum/job/indians/tribes/yellow
	title = "Yellow Mouse Tribesman"
	en_meaning = FALSE
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND4"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/yellow/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	var/obj/item/clothing/accessory/armband/indiany_a = new /obj/item/clothing/accessory/armband/indiany(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indiany_a, H)

	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Yellow Mouse</b> tribe. You should wear yellow clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

datum/job/indians/tribes/white
	title = "White Wolf Tribesman"
	en_meaning = FALSE
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND5"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/white/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	var/obj/item/clothing/accessory/armband/indianw_a = new /obj/item/clothing/accessory/armband/indianw(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indianw_a, H)

	if (H.h_style == "Bald")
		H.h_style = "Skinhead"
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>White Wolf</b> tribe. You should wear white clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

datum/job/indians/tribes/black
	title = "Black Bear Tribesman"
	en_meaning = FALSE
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND6"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/black/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	var/obj/item/clothing/accessory/armband/indianbl_a = new /obj/item/clothing/accessory/armband/indianbl(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indianbl_a, H)

	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Black Bear</b> tribe. You should wear black clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE