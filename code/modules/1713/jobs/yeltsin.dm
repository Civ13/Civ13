/datum/job/russian/ra
	title = "Russian Army (DO NOT USE)"
	allowed_maps = list()
/datum/job/russian/ra/lieutenant
	title = "Russian Army Lieutenant"
	rank_abbreviation = "Leyt."
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLateRUCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/ra/lieutenant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/russian/ra/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rus_vsr93(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_vdv(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/rusoff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour.attackby(plates1, H)
	armour.attackby(plates2, H)
	uniform.attackby(armour, H)
//jacket
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Russian Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ra/sergeant
	title = "Russian Army Sergeant"
	rank_abbreviation = "Srj."
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLateRUCap"

	is_squad_leader = TRUE
	uses_squads = TRUE

	can_get_coordinates = TRUE

	min_positions = 1
	max_positions = 8

/datum/job/russian/ra/sergeant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/russian/ra/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	var/randshoes = rand(1,3)
	switch(randshoes)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
		if(3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rus_vsr93(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/sovietfacehelmet(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/rusoff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
//jacket
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
	H.civilization = "Russian Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead your assigned squad against the Insurgents!")
	apply_job_stats(H)
	return TRUE


/datum/job/russian/ra/medic
	title = "Russian Army Corpsman"
	rank_abbreviation = "Efr."
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLateRU"

	is_medic = TRUE

	min_positions = 1
	max_positions = 8

/datum/job/russian/ra/medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/russian/ra/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)

//clothes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/rus_vsr93(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet_medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)

	H.civilization = "Russian Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ra/omon
	title = "OMON Officer"
	en_meaning = "Riot Police"
	rank_abbreviation = "OMON ofc."
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLateRUswat"


	uses_squads = TRUE

	min_positions = 1
	max_positions = 40

/datum/job/russian/ra/omon/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_LOW, "pistol" = STAT_VERY_HIGH, "bows" = STAT_LOW, "medical" = STAT_LOW, "machinegun" = STAT_NORMAL)
/datum/job/russian/ra/omon/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/omon(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armour, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/zsh2(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_swat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/balistic(H), slot_back)
	
	H.civilization = "Russian Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, part of the OMON, the Special Purpose Mobile Unit of the Minitry of Internal Affairs. Use your superior training and gear to control the miltia!")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ra/soldier
	title = "Russian Army Private"
	rank_abbreviation = "Ryad."
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLateRU"


	uses_squads = TRUE

	min_positions = 1
	max_positions = 100

/datum/job/russian/ra/soldier/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/russian/ra/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoes = rand(1,2)
	switch(randshoes)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/rus_vsr93(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	armour.attackby(plates1, H)
	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74/alt(H), slot_belt)

	H.civilization = "Russian Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ra/spetsnaz
	title = "Spetsnaz"
	rank_abbreviation = "Jr. Srj."
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLateRUsptz"
	whitelisted = TRUE

	uses_squads = TRUE

	min_positions = 1
	max_positions = 8

/datum/job/russian/ra/spetsnaz/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_HIGH)
/datum/job/russian/ra/spetsnaz/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/gorka(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour.attackby(plates1, H)
	armour.attackby(plates2, H)
	uniform.attackby(armour, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat(H), slot_gloves)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_spz(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74/ak74m, slot_r_store)

	H.civilization = "Russian Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an elite operator part of the FSB's \"Alfa\" Spetznaz Response Team.")
	apply_job_stats(H)
	return TRUE

/////////KGBS & SSMs//////////////

/datum/job/civilian/russian/hvt
	title = "Soviet Supreme Chairman"
	en_meaning = "Soviet HVT"
	rank_abbreviation = "Chairman"
	spawn_location = "JoinLatessm"
	is_kremlin = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	allowed_maps = list(MAP_YELTSIN)

	min_positions = 1
	max_positions = 3

/datum/job/civilian/russian/hvt/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_NORMAL)
/datum/job/civilian/russian/hvt/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/waistcoat(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/goldwatch(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30/silenced(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/medal/soviet/ww2/delegate_supreme_soviet/pin = new /obj/item/clothing/accessory/medal/soviet/ww2/delegate_supreme_soviet(null)
	uniform.attackby(pin, H)
	H.civilization = "Militia"
	H.add_note("Role", "You are an essential member of the Supreme Soviet. They are out to get you! Rely on the people who are still following your ideology and stay alive!")
	give_random_name(H)
	apply_job_stats(H)
	if (map && map.ID == MAP_YELTSIN)
		var/obj/map_metadata/yeltsin/CP = map
		CP.HVT_list |= H
	return TRUE


/datum/job/civilian/russian/kgb
	title = "KGB Officer"
	rank_abbreviation = "KGB"
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLatessm"
	is_kremlin = TRUE
	whitelisted = TRUE

	min_positions = 6
	max_positions = 6

/datum/job/civilian/russian/kgb/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_HIGH, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_HIGH, "machinegun" = STAT_HIGH)
/datum/job/civilian/russian/kgb/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/iogboots/black(H), slot_shoes)

	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd/kgb(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/toughguy(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/briefcase/kgb(H), slot_l_hand)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/nkvd_cap/kgb(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/large(H), slot_eyes)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/saiga12(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso/kgb(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/pen/reagent/paralysis(H), slot_l_ear)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer(H), slot_wear_suit)
	var/obj/item/clothing/accessory/medal/soviet/ww2/nkvd/pin = new /obj/item/clothing/accessory/medal/soviet/ww2/nkvd(null)
	uniform.attackby(pin, H)
	H.civilization = "Militia"
	give_random_name(H)
	H.add_note("Role", "You are a <b>KGB officer</b>.<br> Elite training, elite gear. Your pen conceals a potent paralysis toxin. Keep the High Value Target safe at all costs!<br><i>You can use the \"Find HVT\" command under the \"Officer\" tab to locate the HVT(s).</i>")
	apply_job_stats(H)
	return TRUE


////////////MILITIAS/////////////

/datum/job/civilian/russian/sov_militia
	title = "Opposition Militia"
	spawn_location = "JoinLateCiv"
	min_positions = 1
	max_positions = 250
	allowed_maps = list(MAP_YELTSIN)
	

/datum/job/civilian/russian/sov_militia/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/civilian/russian/sov_militia/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoe = rand(1,5)
	switch(randshoe)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/workboots(H), slot_shoes)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/winterboots(H), slot_shoes)

//clothes
	var/randuni = rand(1,8)
	switch(randuni)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/farmer_outfit(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/scavfit(H), slot_w_uniform)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/motorist(H), slot_w_uniform)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/oldmansuit(H), slot_w_uniform)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/engi(H), slot_w_uniform)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/cozyoldy(H), slot_w_uniform)
		if (8)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive(H), slot_w_uniform)

//head
	var/randhead = rand(1,6)
	switch(randhead)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/commando_bandana(H), slot_head)
//gloves
	var/randglove = rand(1,4)
	switch(randglove)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/watch(H), slot_gloves)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/specialwatch(H), slot_gloves)
//misc
	if (prob(60))
		var/randmisc = rand(1,5)
		switch(randmisc)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/clothing/glasses/pilot(H), slot_eyes)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
			if (4)
				H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette(H), slot_wear_mask)
			if (5)
				H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
//weapons
	// guns
	if (prob(60))
		var/randgun = rand(1,3)
		switch(randgun)
			if (1)
				if (prob(75))
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_belt)
				else
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_belt)
			if (2)
				if (prob(60))
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_shoulder)
				else
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_shoulder)
			if (3)
				if (prob(75))
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
				else
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/obrez(H), slot_shoulder)
	
	// melee
	var/randimpw = rand(1,8)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/steel(H), slot_l_hand)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bowie(H), slot_l_hand)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/scythe(H), slot_l_hand)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/molotov/vodka(H), slot_l_hand)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/weapon/branch/sharpened(H), slot_l_hand)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/weapon/hammer/modern(H), slot_l_hand)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/weapon/broken_bottle(H), slot_l_hand)
//suit
	var/randsuit = rand(1,6)
	switch(randsuit)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/bomberjacketbrown(H), slot_wear_suit)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/biker/lizard_jacket(H), slot_wear_suit)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/russian_rcw(H), slot_wear_suit)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet(H), slot_wear_suit)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/coveralls(H), slot_wear_suit)


	H.add_note("Role", "You are a <b>[title]</b>, insurging against Yeltsin's tyranny. You're ready to give your life for the dream of the people!")
	H.civilization = "Militia"
	give_random_name(H)
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/russian/militia_medic
	title = "Militia Medic"
	en_meaning = "Doctor"
	rank_abbreviation = "Dr."
	allowed_maps = list(MAP_YELTSIN)

	spawn_location = "JoinLateCiv"

	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/civilian/russian/militia_medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/civilian/russian/militia_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/scrubs/darkgreen(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/surgical_cap/darkgreen(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/sterile(H), slot_gloves)

//misc
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/vodka(H), slot_r_hand)

	H.add_note("Role", "You are a <b>[title]</b>. Keep your comrades healthy and motivated!")
	H.civilization = "Militia"
	give_random_name(H)
	apply_job_stats(H)
	return TRUE