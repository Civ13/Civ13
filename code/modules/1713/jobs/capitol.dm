////VIPS

/datum/job/american/hvt
	title = "US HVT"
	en_meaning = "High Value Target"
	rank_abbreviation = "Mr."
	allowed_maps = list()
	spawn_location = "JoinLateFeds"
	is_commander = TRUE
	whitelisted = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/hvt/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_NORMAL)
/datum/job/american/hvt/job_loadout = list(
	/obj/item/clothing/shoes/laceup = slot_shoes,
	/obj/item/clothing/under/modern2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/black_suit = slot_wear_suit,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/gloves/watch/goldwatch = slot_gloves,
	/obj/item/stack/medical/bruise_pack/gauze = slot_l_store,
	/obj/item/weapon/gun/projectile/pistol/glock17/silenced = slot_belt)
/datum/job/american/hvt/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)
	H.add_note("Role", "You are an essential member of the U.S. Government. They are out to get you! Rely on the feds and stay alive!")
	apply_job_stats(H)
	if (map && map.ID == MAP_CAPITOL_HILL)
		var/obj/map_metadata/capitol_hill/CP = map
		CP.HVT_list |= H
	return TRUE

// Special roles for the Chinese Offensive mode
/datum/job/american/hvt/specials
	title = "President of the USA"
	en_meaning = "VIP"
	rank_abbreviation = "President"
	allowed_maps = list(MAP_CAPITOL_HILL, MAP_CAPITOL_HILL_PLA)
	whitelisted = FALSE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 1

	equip(var/mob/living/human/H)
		..()
		H.gender = MALE
		H.f_style = "Shaved"
		var/hex_hair = hair_colors["Light Grey"]
		H.r_hair = hex2num(copytext(hex_hair, 2, 4))
		H.g_hair = hex2num(copytext(hex_hair, 4, 6))
		H.b_hair = hex2num(copytext(hex_hair, 6, 8))
		H.r_facial = hex2num(copytext(hex_hair, 2, 4))
		H.g_facial = hex2num(copytext(hex_hair, 4, 6))
		H.b_facial = hex2num(copytext(hex_hair, 6, 8))
		if (map && map.ID == MAP_CAPITOL_HILL_PLA)
			var/obj/map_metadata/capitol_hill/pla_offensive/CP = map
			CP.HVT_list |= H
		return TRUE

/datum/job/american/hvt/specials/vice
	title = "Vice-President of the USA"
	en_meaning = "VIP"
	rank_abbreviation = "Vice-President"
	can_be_female = FALSE
	allowed_maps = list(MAP_CAPITOL_HILL_PLA)

	equip(var/mob/living/human/H)
		H.gender = MALE
		H.f_style = "Shaved"
		var/hex_hair = hair_colors["Light Grey"]
		H.r_hair = hex2num(copytext(hex_hair, 2, 4))
		H.g_hair = hex2num(copytext(hex_hair, 4, 6))
		H.b_hair = hex2num(copytext(hex_hair, 6, 8))
		H.r_facial = hex2num(copytext(hex_hair, 2, 4))
		H.g_facial = hex2num(copytext(hex_hair, 4, 6))
		H.b_facial = hex2num(copytext(hex_hair, 6, 8))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/burgundy_suit(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/goldwatch(H), slot_gloves)
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_belt)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
		uniform.attackby(armor, H)
		var/obj/item/clothing/accessory/holster/hip/double/HOLSTER = new /obj/item/clothing/accessory/holster/hip/double(null)
		uniform.attackby(HOLSTER, H)
		H.add_note("Role", "You are an essential member of the U.S. Government. They are out to get you! Rely on the feds and stay alive!")
		if (map && map.ID == MAP_CAPITOL_HILL_PLA)
			var/obj/map_metadata/capitol_hill/pla_offensive/CP = map
			CP.HVT_list |= H
		return TRUE

/datum/job/american/hvt/specials/speaker
	title = "Speaker of the House"
	en_meaning = "VIP"
	rank_abbreviation = "Speaker"
	can_be_female = FALSE
	allowed_maps = list(MAP_CAPITOL_HILL_PLA)
	equip(var/mob/living/human/H)
		H.gender = MALE
		H.f_style = "Shaved"
		var/hex_hair = hair_colors["Light Grey"]
		H.r_hair = hex2num(copytext(hex_hair, 2, 4))
		H.g_hair = hex2num(copytext(hex_hair, 4, 6))
		H.b_hair = hex2num(copytext(hex_hair, 6, 8))
		H.r_facial = hex2num(copytext(hex_hair, 2, 4))
		H.g_facial = hex2num(copytext(hex_hair, 4, 6))
		H.b_facial = hex2num(copytext(hex_hair, 6, 8))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/navy_suit(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/goldwatch(H), slot_gloves)
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/uzi(H), slot_l_hand)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
		uniform.attackby(armor, H)
		H.add_note("Role", "You are an essential member of the U.S. Government. They are out to get you! Rely on the feds and stay alive!")
		if (map && map.ID == MAP_CAPITOL_HILL_PLA)
			var/obj/map_metadata/capitol_hill/pla_offensive/CP = map
			CP.HVT_list |= H
		return TRUE


// National Guard

/datum/job/american/ng_lieutenant
	title = "National Guard Lieutenant"
	rank_abbreviation = "Lt."
	allowed_maps = list(MAP_CAPITOL_HILL, MAP_CAPITOL_HILL_PLA)

	spawn_location = "JoinLateRNCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/ng_lieutenant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/ng_lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_camo_ocp = slot_w_uniform,
	/obj/item/clothing/head/jungle_hat/khaki = slot_head,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att = slot_shoulder,
	/obj/item/weapon/gun/projectile/pistol/m9beretta = slot_belt)
/datum/job/american/ng_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.civilization = "National Guard"
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/ng_sergeant
	title = "National Guard Sergeant"
	rank_abbreviation = "Sgt."
	allowed_maps = list(MAP_CAPITOL_HILL, MAP_CAPITOL_HILL_PLA)

	spawn_location = "JoinLateRNCap"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = TRUE
	can_be_female = TRUE

	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/ng_sergeant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/ng_sergeant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_camo_ocp = slot_w_uniform,
	/obj/item/clothing/head/helmet/modern/ach = slot_head,
	/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att = slot_shoulder,
	/obj/item/weapon/gun/projectile/pistol/m9beretta = slot_l_hand,
	/obj/item/clothing/mask/gas/swat = slot_belt,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id)
/datum/job/american/ng_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp/ocp_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp(null)
	uniform.attackby(ocp_armor, H)
	give_random_name(H)
	H.civilization = "National Guard"
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Insurgents!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/ng_medic
	title = "National Guard Field Medic"
	rank_abbreviation = "Cpl."
	allowed_maps = list(MAP_CAPITOL_HILL, MAP_CAPITOL_HILL_PLA)

	spawn_location = "JoinLateRN"

	is_medic = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/ng_medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/ng_medic/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_camo_ocp = slot_w_uniform,
	/obj/item/clothing/head/helmet/modern/ach = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat/modern = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m9beretta = slot_l_hand,
	/obj/item/clothing/mask/gas/swat = slot_wear_mask,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id)
/datum/job/american/ng_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp/ocp_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp(null)
	uniform.attackby(ocp_armor, H)
	give_random_name(H)
	H.civilization = "National Guard"
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/ng_soldier
	title = "National Guard Rifleman"
	rank_abbreviation = "Pvt."
	allowed_maps = list(MAP_CAPITOL_HILL, MAP_CAPITOL_HILL_PLA)

	spawn_location = "JoinLateRN"

	uses_squads = TRUE
	can_be_female = TRUE
	min_positions = 10
	max_positions = 100

/datum/job/american/ng_soldier/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/ng_soldier/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_camo_ocp = slot_w_uniform,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id)
/datum/job/american/ng_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp/ocp_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp(null)
	uniform.attackby(ocp_armor, H)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a4(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_stanag(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/swat(H), slot_wear_mask)
	give_random_name(H)
	H.civilization = "National Guard"
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	apply_job_stats(H)
	return TRUE

/////////FEDS & HVTs//////////////
/datum/job/american/fbi
	title = "FBI officer"
	rank_abbreviation = "FBI"
	allowed_maps = list(MAP_CAPITOL_HILL, MAP_CAPITOL_HILL_PLA)

	spawn_location = "JoinLateFeds"

	whitelisted = TRUE
	can_be_female = TRUE

	min_positions = 4
	max_positions = 4

/datum/job/american/fbi/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_HIGH, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_HIGH, "machinegun" = STAT_HIGH)
/datum/job/american/fbi/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/modern2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/fbi = slot_wear_suit,
	/obj/item/clothing/head/cap/fbi = slot_head,
	/obj/item/clothing/glasses/sunglasses = slot_eyes,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/mask/gas/swat = slot_belt,
	/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/fbi = slot_shoulder,
	/obj/item/weapon/gun/projectile/pistol/m9beretta = slot_l_hand)
/datum/job/american/fbi/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>FBI officer</b>.<br> Keep the High Value Target safe at all costs!<br><i>You can use the \"Find HVT\" command under the \"Officer\" tab to locate the HVT(s).</i>")
	apply_job_stats(H)
	return TRUE

////////////MILITIAS/////////////

/datum/job/civilian/us_militia
	title = "Boogaloo Boy"
	en_meaning = "Assault Infantry"
	rank_abbreviation = ""
	spawn_location = "JoinLateCiv"
	min_positions = 10
	max_positions = 150
	can_be_female = TRUE
	allowed_maps = list(MAP_CAPITOL_HILL)

/datum/job/civilian/us_militia/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/civilian/us_militia/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	var/randjack = rand(1,4)
	if (randjack == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tacticool_hawaiian(H), slot_w_uniform)
	else if (randjack == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tacticool_hawaiian/purple(H), slot_w_uniform)
	else if (randjack == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tacticool_hawaiian/orange(H), slot_w_uniform)
	else if (randjack == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/tacticool_hawaiian/green(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randarm = rand(1,2)
	if (randarm == 1)
		var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
		uniform.attackby(pasgt_armor, H)
	else if (randarm == 2)
		var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/plate_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
		uniform.attackby(plate_armor, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//head
	var/randhead = rand(1,2)
	switch(randhead)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/lwh/black(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/cap(H), slot_head)
//eyewear
	if (prob(50))
		if (prob(80))
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)
//gunz
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/ar15(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_stanag(H), slot_belt)
	H.civilization = "Militia"
	H.add_note("Role", "You are a <b>[title]</b>, insurging against the U.S. Government's tyranny. You've trained for this all your life, so go for it!")
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/us_patriot
	title = "American Patriot"
	en_meaning = "Support Infantry"
	rank_abbreviation = ""
	spawn_location = "JoinLateCiv"
	min_positions = 10
	max_positions = 150
	can_be_female = TRUE
	allowed_maps = list(MAP_CAPITOL_HILL)

/datum/job/civilian/us_patriot/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/civilian/us_patriot/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	var/randjack = rand(1,3)
	if (randjack == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/boomerwaffen1(H), slot_w_uniform)
	else if (randjack == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/boomerwaffen2(H), slot_w_uniform)
	else if (randjack == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/boomerwaffen3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//head
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/maga(H), slot_head)
//eyewear
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
//gunz
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/remington870(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump(H), slot_shoulder)
	H.civilization = "Militia"
	H.add_note("Role", "You are a <b>[title]</b>, insurging against the U.S. Government's tyranny. You've trained for this all your life, so go for it!")
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/us_shaman
	title = "Shaman"
	en_meaning = "Field Medic"
	rank_abbreviation = "Shaman"
	allowed_maps = list(MAP_CAPITOL_HILL)

	spawn_location = "JoinLateCiv"

	is_medic = TRUE

	min_positions = 3
	max_positions = 10

/datum/job/civilian/us_shaman/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/civilian/us_shaman/job_loadout = list(
	/obj/item/clothing/shoes/leatherboots = slot_shoes,
	/obj/item/clothing/under/modern_shaman = slot_w_uniform,
	/obj/item/clothing/head/bisonpelt = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat/modern = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/m9beretta = slot_l_hand,
	/obj/item/weapon/radio/walkietalkie/faction2 = slot_wear_id)
/datum/job/civilian/us_shaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard")
		H.f_style = pick("Full Beard","Medium Beard","Long Beard")
	H.civilization = "Militia"
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow patriots healthy and motivated!")
	apply_job_stats(H)
	return TRUE
