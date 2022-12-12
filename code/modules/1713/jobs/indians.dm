/datum/job/indians
	faction = "Human"
	var/tribe = "Carib"

/datum/job/indians/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_carib_name(H.gender)
	H.real_name = H.name

/datum/job/indians/carib_chief
	title = "Carib Elder"
	en_meaning = "Native Elder/Leader"
	rank_abbreviation = ""

	spawn_location = "JoinLateIND"
	can_be_female = TRUE
	is_officer = TRUE
	is_1713 = TRUE


	min_positions = 2
	max_positions = 20
/datum/job/indians/carib_chief/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chief_hat(H), slot_head)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/indianchief(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/indian2_a = new /obj/item/clothing/accessory/armband/indian2(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indian2_a, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/thrown/tomahawk(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/thrown/tomahawk(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/bone_battleaxe(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear(H), slot_shoulder)

	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>Elder</b> of a Carib tribe. Organize your <b>Tribesmen</b> and take out the invaders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
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

	spawn_location = "JoinLateIND"
	can_be_female = TRUE
	is_1713 = TRUE

	min_positions = 2
	max_positions = 30
/datum/job/indians/carib_shaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/indianshaman(H), slot_w_uniform)

	var/obj/item/clothing/accessory/armband/indianshaman_a = new /obj/item/clothing/accessory/armband/indianshaman(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(indianshaman_a, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/leather/shaman(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/skullmask(H), slot_wear_mask)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot/palmsap(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/herbs(H), slot_r_store)
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>Shaman</b>, the healer and religious leader of your tribe. Keep your fellow tribesmen healthy and motivated!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
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

	spawn_location = "JoinLateIND"
	can_be_female = TRUE
	is_1713 = TRUE

	min_positions = 20
	max_positions = 300

/datum/job/indians/carib/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/bone_battleaxe(H), slot_l_hand)
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a member of a Carib tribe. Organize with your <b>Chief</b> and take out the invaders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
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

	spawn_location = "JoinLateIND1"
	can_be_female = TRUE


	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/red/equip(var/mob/living/human/H)
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
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Red Goose</b> tribe. You should wear red clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
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
	can_be_female = TRUE
	spawn_location = "JoinLateIND2"



	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/blue/equip(var/mob/living/human/H)
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
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Blue Turkey</b> tribe. You should wear blue clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
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
	can_be_female = TRUE
	spawn_location = "JoinLateIND3"
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/green/equip(var/mob/living/human/H)
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
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Green Monkey</b> tribe. You should wear green clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
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
	can_be_female = TRUE
	spawn_location = "JoinLateIND4"
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/yellow/equip(var/mob/living/human/H)
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
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Yellow Mouse</b> tribe. You should wear yellow clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
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
	can_be_female = TRUE
	spawn_location = "JoinLateIND5"
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/white/equip(var/mob/living/human/H)
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
	give_random_name(H)
	if (H.h_style == "Bald")
		H.h_style = "Skinhead"
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>White Wolf</b> tribe. You should wear white clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
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
	can_be_female = TRUE
	spawn_location = "JoinLateIND6"
	min_positions = 60
	max_positions = 300

/datum/job/indians/tribes/black/equip(var/mob/living/human/H)
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
	give_random_name(H)
	H.f_style = "Shaved"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your tribe, build your village, and honor the Gods!")
	H.add_note("Tribe", "You are a member of the <b>Black Bear</b> tribe. You should wear black clothes.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
/datum/job/indians/warlords
	title = "warlord (do not use)"
	en_meaning = FALSE
	rank_abbreviation = ""
	can_be_female = TRUE
	is_coldwar = TRUE
	uses_squads = FALSE
	spawn_location = "JoinLateIND1"
	min_positions = 40
	max_positions = 1000
	default_language = "Zulu"
	additional_languages = list("Swahili" = 80, "English" = 10)

/datum/job/indians/warlords/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.name = H.species.get_random_zulu_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	//shoes
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/flipflops(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sneakers/courier(H), slot_shoes)

	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

/datum/job/indians/warlords/proc/give_gun(var/mob/living/human/H)
	var/randgun = pick(1,2,3,4)
	if (map.ID == MAP_TADOJSVILLE)
		switch(randgun)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/sks(H), slot_shoulder)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/fal(H), slot_shoulder)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_shoulder)
			if (4)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/rpd(H), slot_shoulder)
	else
		switch(randgun)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/g3(H), slot_shoulder)
			if (2)
				if(prob(40))
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_shoulder)
					H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)
				else
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_shoulder)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_shoulder)
			if (4)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/vz58(H), slot_shoulder)
	if (prob(7))
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/machete(H), slot_back)
	if (prob(33))
		var/obj/item/clothing/accessory/storage/webbing/us_bandolier/FJ = new /obj/item/clothing/accessory/storage/webbing/us_bandolier(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(FJ, H)

/datum/job/indians/warlords/red
	title = "Redkantu Warband Mercenary"
	spawn_location = "JoinLateIND1"
	selection_color = "#ac0909"
	is_warlords = TRUE
	is_redka = TRUE
/datum/job/indians/warlords/red/equip(var/mob/living/human/H)
	..()
	H.nationality = "Redkantu"
	H.add_note("Role", "You are a member of <b>Redkantu Freedom Movement</b>. Stick with your warband and honour your contract!.")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")

	//hat or mask
	if (prob(50))
		if(prob(60))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/red(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet(H), slot_head)
	if(prob(35) || !istype(H.head, /obj/item/clothing/head/cap/yellow))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	//uniform
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband1(H), slot_w_uniform)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/red_shorts(H), slot_w_uniform)

	//suit
	var/pick2 = pick(1,2,3)
	if (pick2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else if (pick2 == 2)
		if (prob(50))
			var/obj/item/clothing/accessory/armor/coldwar/flakjacket/FJ = new /obj/item/clothing/accessory/armor/coldwar/flakjacket(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(FJ, H)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/ab = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(ab, H)
	//guns
	give_gun(H)
/datum/job/indians/warlords/proc/equip_shaman(mob/living/human/H)
	if (!H)	return FALSE
	H.name = H.species.get_random_zulu_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/flipflops(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/zulu_slene(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/shaman(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/machete(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/colthammerless/m1908(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/mush(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/handle(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/armpit/holsterh = new /obj/item/clothing/accessory/holster/armpit(null)
	uniform.attackby(holsterh, H)

	H.setStat("medical", STAT_VERY_HIGH)
/datum/job/indians/warlords/red/shaman
	title = "Redkantu Warband Shaman"
	min_positions = 5
	max_positions = 15
/datum/job/indians/warlords/red/shaman/equip(mob/living/human/H)
	equip_shaman(H)
	H.nationality = "Redkantu"
	H.add_note("Role", "You are a member of <b>Redkantu Freedom Movement</b>. Stick with your warband and honour your contract!.")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/cape(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/fez(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/ab = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(ab, H)

/datum/job/indians/warlords/blue
	title = "Blugisi Warband Mercenary."
	spawn_location = "JoinLateIND2"
	selection_color = "#2a28b6"
	is_warlords = TRUE
/datum/job/indians/warlords/blue/equip(var/mob/living/human/H)
	..()
	H.nationality = "Blugisi"
	H.add_note("Role", "You are a member of <b>Blugisi People's Front</b>. Stick with your warband and honour your contract!")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")
	//hat or mask
	if (prob(50))
		if(prob(60))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/blue(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet(H), slot_head)
	if(prob(35) || !istype(H.head, /obj/item/clothing/head/cap/yellow))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/bluekerchief(H), slot_wear_mask)
	//uniform
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband1(H), slot_w_uniform)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/blue_shorts(H), slot_w_uniform)

	//suit
	var/pick2 = pick(1,2,3)
	if (pick2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else if (pick2 == 2)
		if (prob(50))
			var/obj/item/clothing/accessory/armor/coldwar/flakjacket/FJ = new /obj/item/clothing/accessory/armor/coldwar/flakjacket(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(FJ, H)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/ab = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(ab, H)
	//guns
	give_gun(H)
/datum/job/indians/warlords/blue/shaman
	title = "Blugisi Warband Shaman"
	min_positions = 5
	max_positions = 15
/datum/job/indians/warlords/blue/shaman/equip(mob/living/human/H)
	equip_shaman(H)
	H.nationality = "Blugisi"
	H.add_note("Role", "You are a member of <b>Blugisi People's Front</b>. Stick with your warband and honour your contract!")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/surgeon(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/fiendish/blugi(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/ab = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(ab, H)
/datum/job/indians/warlords/yellow
	title = "Yellowagwana Warband Mercenary."
	spawn_location = "JoinLateIND3"
	selection_color = "#969607"
	is_warlords = TRUE

/datum/job/indians/warlords/yellow/equip(var/mob/living/human/H)
	..()
	H.nationality = "Yellowagwana"
	H.add_note("Role", "You are a member of <b>Yellowagwana Liberation Army</b>. Stick with your warband and honour your contract!")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")

	//hat or mask
	if (prob(50))
		if(prob(60))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/yellow(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet(H), slot_head)
	if(prob(35) || !istype(H.head, /obj/item/clothing/head/cap/yellow))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/yellowkerchief(H), slot_wear_mask)
	//uniform
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband1(H), slot_w_uniform)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/yellow_shorts(H), slot_w_uniform)

	//suit
	var/pick2 = pick(1,2,3)
	if (pick2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else if (pick2 == 2)
		if (prob(50))
			var/obj/item/clothing/accessory/armor/coldwar/flakjacket/FJ = new /obj/item/clothing/accessory/armor/coldwar/flakjacket(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(FJ, H)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
	var/obj/item/clothing/accessory/armband/spanish/ab = new /obj/item/clothing/accessory/armband/spanish(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(ab, H)
	//guns
	give_gun(H)
/datum/job/indians/warlords/yellow/shaman
	title = "Yellowagwana Warband Shaman"
	min_positions = 5
	max_positions = 15

/datum/job/indians/warlords/yellow/shaman/equip(mob/living/human/H)
	equip_shaman(H)
	H.nationality = "Yellowagwana"
	H.add_note("Role", "You are a member of <b>Yellowagwana Liberation Army</b>. Stick with your warband and honour your contract!.")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/zulu_mbata(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/zulu_umghele(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/spanish/ab = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform.attackby(ab, H)

///////TADOJSVILLE///////////
/datum/job/indians/warlords/tadojsville
	title = "Mercenary (do not use)"

/datum/job/indians/warlords/tadojsville/sergeant
	title = "Katnegwa Mercenary Sergeant"
	spawn_location = "JoinLateIND3"
	selection_color = "#3a6916"
	is_warlords = TRUE
	is_tadoj = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	min_positions = 1
	max_positions = 12

/datum/job/indians/warlords/tadojsville/sergeant/equip(var/mob/living/human/H)
	H.nationality = "Katnegwa"
	H.add_note("Role", "You are a member of <b>Katnegwa Mercenary Force</b>. Lead your fellow mercs and honour your contract!")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")
	//hat or mask
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_black(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

	if(prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh(H), slot_wear_mask)
	//uniform
	H.equip_to_slot_or_del(new /obj/item/clothing/under/afr_merc(H), slot_w_uniform)
	//suit
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
	//guns
	give_gun(H)

/datum/job/indians/warlords/tadojsville/shaman
	title = "Katnegwa Shaman"
	spawn_location = "JoinLateIND3"
	selection_color = "#3a6916"
	is_warlords = TRUE
	is_tadoj = TRUE
	is_medic = TRUE
	max_positions = 10

/datum/job/indians/warlords/tadojsville/shaman/equip(mob/living/human/H)
	equip_shaman(H)
	H.nationality = "Katnegwa"
	H.add_note("Role", "You are a <b>[title]</b>. Stick with your warband and keep it medicated!")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/zulu_mbata(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/zulu_umghele(H), slot_head)

/datum/job/indians/warlords/tadojsville/soldier
	title = "Katnegwa Mercenary"
	spawn_location = "JoinLateIND3"
	selection_color = "#3a6916"
	is_warlords = TRUE
	is_tadoj = TRUE
	uses_squads = TRUE
	max_positions = 300

/datum/job/indians/warlords/tadojsville/soldier/equip(var/mob/living/human/H)
	..()
	H.nationality = "Katnegwa"
	H.add_note("Role", "You are a member of <b>Katnegwa Mercenary Force</b>. Stick with your fellow mercs and honour your contract!")
	H.add_note("Extra mechanics", "Collect Peacekeeper heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to get weapons and equipment.  <b>Only United Nations Peacekeeper heads will do, all others are worthless.</b>.")

	//hat or mask
	if (prob(50))
		if(prob(60))
			var/obj/item/clothing/head/custom/fieldcap/FC = new /obj/item/clothing/head/custom/fieldcap(null)
			FC.color = "#A4804B"
			FC.uncolored1 = FALSE
			FC.update_icon()
			H.equip_to_slot_or_del(FC, slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet(H), slot_head)
	if(prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh(H), slot_wear_mask)
	//uniform
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband1(H), slot_w_uniform)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/afr_merc/alt(H), slot_w_uniform)

	//suit
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
	//guns
	give_gun(H)

/////////////////////////////////////////////SECOND RACE 4 AND JOB FILES HEAD 2 HEAD AUTOBALANCE////////////////////////////////////////////////////

/datum/job/civilian/warlords
	title = "warlord (do not uze)"
	en_meaning = FALSE
	rank_abbreviation = ""
	can_be_female = TRUE
	is_coldwar = TRUE
	uses_squads = FALSE
	spawn_location = "JoinLateIND1"
	min_positions = 40
	max_positions = 100
	default_language = "Zulu"
	additional_languages = list("Swahili" = 80, "English" = 10)

/datum/job/civilian/warlords/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.name = H.species.get_random_zulu_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	//shoes
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/flipflops(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sneakers/courier(H), slot_shoes)

	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

/datum/job/civilian/warlords/proc/give_gun(var/mob/living/human/H)
	var/randgun = pick(1,2,3,4)
	switch(randgun)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/g3(H), slot_shoulder)
		if (2)
			if(prob(40))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_shoulder)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_shoulder)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_shoulder)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/vz58(H), slot_shoulder)
	if (prob(7))
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/machete(H), slot_back)
	if (prob(33))
		var/obj/item/clothing/accessory/storage/webbing/us_bandolier/FJ = new /obj/item/clothing/accessory/storage/webbing/us_bandolier(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(FJ, H)

/datum/job/civilian/warlords/proc/equip_shaman(mob/living/human/H)
	if (!H)	return FALSE
	H.name = H.species.get_random_zulu_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/flipflops(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/zulu_slene(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/duffel/shaman(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/machete(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/colthammerless/m1908(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/mush(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/handle(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/armpit/holsterh = new /obj/item/clothing/accessory/holster/armpit(null)
	uniform.attackby(holsterh, H)
	H.setStat("medical", STAT_VERY_HIGH)
/datum/job/civilian/warlords/yellow
	title = "Yellowagwana Brave"
	spawn_location = "JoinLateIND3"
	selection_color = "#969607"
	is_yellowag = TRUE
/datum/job/civilian/warlords/yellow/equip(var/mob/living/human/H)
	..()
	H.nationality = "Yellowagwana"
	H.add_note("Role", "You are a member of <b>Yellowagwana Liberation Army</b>. Stick with your warband and collect skulls! <b>Bring them back to the Shaman's shack for points!</b>.")
	H.add_note("Winning Conditions", "Collect enemy heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to score <b>2 points</b>.")
	//hat or mask
	if (prob(50))
		if(prob(60))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/yellow(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet(H), slot_head)
	if(prob(35) || !istype(H.head, /obj/item/clothing/head/cap/yellow))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/yellowkerchief(H), slot_wear_mask)
	//uniform
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband1(H), slot_w_uniform)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/yellow_shorts(H), slot_w_uniform)

	//suit
	var/pick2 = pick(1,2,3)
	if (pick2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else if (pick2 == 2)
		if (prob(50))
			var/obj/item/clothing/accessory/armor/coldwar/flakjacket/FJ = new /obj/item/clothing/accessory/armor/coldwar/flakjacket(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(FJ, H)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
	var/obj/item/clothing/accessory/armband/spanish/ab = new /obj/item/clothing/accessory/armband/spanish(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(ab, H)
	//guns
	give_gun(H)
/datum/job/civilian/warlords/yellow/shaman
	title = "Yellowagwana Shaman"
	min_positions = 5
	max_positions = 15
	is_yellowag = TRUE
/datum/job/civilian/warlords/yellow/shaman/equip(mob/living/human/H)
	equip_shaman(H)
	H.nationality = "Yellowagwana"
	H.add_note("Role", "You are a member of <b>Yellowagwana Liberation Army</b>. Stick with your warband and collect skulls! <b>Bring them back to the your shack for points!</b>")
	H.add_note("Winning Conditions", "Collect enemy heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to score <b>2 points</b>.")
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/zulu_mbata(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/zulu_umghele(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/mush(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/spanish/ab = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform.attackby(ab, H)

/datum/job/indians/warlords/bluevp
	title = "Blugisi Brave"
	spawn_location = "JoinLateIND2"
	selection_color = "#2a28b6"
	is_blugi = TRUE
	min_positions = 40
	max_positions = 100
/datum/job/indians/warlords/bluevp/equip(var/mob/living/human/H)
	..()
	H.nationality = "Blugisi"
	H.add_note("Role", "You are a member of <b>Blugisi People's Front</b>. Stick with your warband and collect skulls! <b>Bring them back to the Shaman's shack for points !</b>")
	H.add_note("Winning Conditions", "Collect enemy heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to score <b>2 points</b>.")
	//hat or mask
	if (prob(50))
		if(prob(60))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/blue(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet(H), slot_head)
	if(prob(35) || !istype(H.head, /obj/item/clothing/head/cap/yellow))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/bluekerchief(H), slot_wear_mask)
	//uniform
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband1(H), slot_w_uniform)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/blue_shorts(H), slot_w_uniform)

	//suit
	var/pick2 = pick(1,2,3)
	if (pick2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else if (pick2 == 2)
		if (prob(50))
			var/obj/item/clothing/accessory/armor/coldwar/flakjacket/FJ = new /obj/item/clothing/accessory/armor/coldwar/flakjacket(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(FJ, H)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/ab = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(ab, H)
	//guns
	give_gun(H)
/datum/job/indians/warlords/bluevp/shaman
	title = "Blugisi Shaman"
	min_positions = 5
	max_positions = 15
	is_blugi = TRUE
/datum/job/indians/warlords/bluevp/shaman/equip(mob/living/human/H)
	equip_shaman(H)
	H.nationality = "Blugisi"
	H.add_note("Role", "You are a member of <b>Blugisi People's Front</b>. Stick with your warband and collect skulls! <b>Bring them back to the your shack for points</b>.")
	H.add_note("Winning Conditions", "Collect enemy heads by targeting the head on HELP intent with machette in hand. Bring them back to the Shaman's Hut and place them on the altar to score <b>2 points</b>.")

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/surgeon(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/fiendish/blugi(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/ab = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(ab, H)
