/datum/job/indians
	faction = "Station"
	var/tribe = "Carib"


/datum/job/indians/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_carib_name(H.gender)
	H.real_name = H.name

/datum/job/indians/carib_chief
	title = "Carib Chief"
	en_meaning = "Native Leader"
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

	if (H.h_style == "Bald")
		H.h_style = "Skinhead"
	H.s_tone = 140
	H.f_style = "Shaved"
	H.add_note("Role", "You are the <b>Chief</b> of a Carib tribe. Organize your <b>Tribesmen</b> and take out the invaders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH) //not used
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/skullmask(H), slot_head)
	//todo: poisonous arrows
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/bruise_pack/herbs(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/bruise_pack/herbs(H), slot_r_store)

	if (H.h_style == "Bald")
		H.h_style = "Skinhead"
	H.s_tone = 140
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>Shaman</b>, the healer and religious leader of your tribe. Keep your fellow tribesmen healthy and motivated!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH) //not used
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

	if (H.h_style == "Bald")
		H.h_style = "Skinhead"
	H.s_tone = 140
	H.f_style = "Shaved"
	H.add_note("Role", "You are a member of a Carib tribe. Organize with your <b>Chief</b> and take out the invaders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////TRIBES//RP//STUFF//////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/indians/tribes/worker
	title = "Tribesman"
	en_meaning = "Tribe Worker"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/worker/equip(var/mob/living/carbon/human/H)
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

	if (H.h_style == "Bald")
		H.h_style = "Skinhead"
	H.f_style = "Shaved"
	H.add_note("Role", "You are a simple tribesmen, trying to live your life. Build a house, hunt for food, and survive!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW) //muskets
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE