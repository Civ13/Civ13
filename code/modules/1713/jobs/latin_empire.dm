/datum/job/roman/colonel	//Latin Empire - Colonel
	title = "Colonellus"
	en_meaning = "Colonel (Latin-Italian)"
	rank_abbreviation = "Col."
	spawn_location = "JoinLateRO"
	additional_languages = list("English" = 5, "Greek" = 100, "French" = 100, "Russian" = 5, "Arabic" = 10)
	is_commander = TRUE
	is_officer = TRUE
	is_radioman = FALSE
	whitelisted = TRUE
	min_positions = 1
	max_positions = 1
	allowed_maps = list(MAP_CONSTANTINOPOLI)

/datum/job/roman/colonel/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MAX, "dexterity" = STAT_NORMAL, "swords" = STAT_MAX, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/roman/colonel/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_lightuni3 = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/ww2/japcoat/sand = slot_wear_suit,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/head/tricorne_black = slot_head,
	/obj/item/ammo_magazine/hk = slot_r_store,
	/obj/item/weapon/key/ancient/greek = slot_l_store,
	/obj/item/weapon/material/sword/gladius/iron = slot_belt,
	/obj/item/weapon/gun/projectile/submachinegun/g3 = slot_r_hand)
/datum/job/roman/colonel/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, the commander of <b>your entire regiment</b>. Organize your <b>Sergenti</b> and lead your soldiers to victory!</b>.")
	apply_job_stats(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/fj = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fj, H)
	var/obj/item/clothing/accessory/storage/webbing/us_bandolier = new /obj/item/clothing/accessory/storage/webbing/us_bandolier(null)
	uniform.attackby(us_bandolier, H)
	us_bandolier.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)	
	var/picklang = rand(1,3)
	switch(picklang)
		if (1)
			H.name = H.species.get_random_roman_name(H.gender)
			H.real_name = H.name
		if (2)
			H.name = H.species.get_random_greek_name(H.gender)
			H.real_name = H.name
		if (3)
			H.name = H.species.get_random_french_name(H.gender)
			H.real_name = H.name
	return TRUE

/datum/job/roman/sergeant	//Latin Empire - Squad Leader
	title = "Sergento"
	en_meaning = "Sergeant (Latin-Italian)"
	rank_abbreviation = "Sgt."
	spawn_location = "JoinLateRO"
	additional_languages = list("English" = 5, "Greek" = 75, "French" = 100, "Russian" = 5, "Arabic" = 10)
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_radioman = FALSE
	min_positions = 2
	max_positions = 10
	allowed_maps = list(MAP_CONSTANTINOPOLI)

/datum/job/roman/sergeant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MAX, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/roman/sergeant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_camo_woodland = slot_w_uniform,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/head/helmet/modern/mk6 = slot_head,
	/obj/item/ammo_magazine/hk = slot_r_store,
	/obj/item/weapon/key/ancient/greek = slot_l_store,
	/obj/item/weapon/material/sword/gladius/iron = slot_belt,
	/obj/item/weapon/gun/projectile/submachinegun/g3 = slot_shoulder)
/datum/job/roman/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a squad. Lead your <b>Fanti and Stratiotes</b> to battle, following the orders of the <b>Colonellus</b>!")
	apply_job_stats(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/fj = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fj, H)
	var/obj/item/clothing/accessory/storage/webbing/us_bandolier = new /obj/item/clothing/accessory/storage/webbing/us_bandolier(null)
	uniform.attackby(us_bandolier, H)
	us_bandolier.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	var/picklang = rand(1,3)
	switch(picklang)
		if (1)
			H.name = H.species.get_random_roman_name(H.gender)
			H.real_name = H.name
		if (2)
			H.name = H.species.get_random_greek_name(H.gender)
			H.real_name = H.name
		if (3)
			H.name = H.species.get_random_french_name(H.gender)
			H.real_name = H.name
	return TRUE

/datum/job/roman/stratiotes	// Latin Empire - Infantry
	title = "Stratiotes"
	en_meaning = "Soldier (Greek)"
	rank_abbreviation = "Pvt."
	default_language = "Greek"
	spawn_location = "JoinLateRO"
	additional_languages = list("English" = 5, "Latin" = 65, "French" = 65, "Russian" = 5, "Arabic" = 10)
	min_positions = 1
	max_positions = 100
	uses_squads = TRUE
	allowed_maps = list(MAP_CONSTANTINOPOLI)

/datum/job/roman/stratiotes/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_LOW, "pistol" = STAT_LOW, "bows" = STAT_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/stratiotes/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_camo_woodland = slot_w_uniform,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/head/helmet/modern/mk6 = slot_head,
	/obj/item/weapon/attachment/bayonet = slot_r_store,
	/obj/item/weapon/key/ancient/greek = slot_l_store,
	/obj/item/weapon/grenade/coldwar/m67 = slot_belt,
	/obj/item/weapon/gun/projectile/submachinegun/g3 = slot_shoulder)
/datum/job/roman/stratiotes/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Greek-speaking soldier of the <i>Latinike Katoche</i>. You are equipped with a G3, an M67 grenade, and a bayonet.")
	apply_job_stats(H)
	H.name = H.species.get_random_greek_name(H.gender)
	H.real_name = H.name
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/fj = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fj, H)
	var/obj/item/clothing/accessory/storage/webbing/us_bandolier = new /obj/item/clothing/accessory/storage/webbing/us_bandolier(null)
	uniform.attackby(us_bandolier, H)
	us_bandolier.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	return TRUE



/datum/job/roman/fante	// Latin Empire - Infantry
	title = "Fante"
	en_meaning = "Infantryman (Latin-Italian)"
	rank_abbreviation = "Pvt."
	additional_languages = list("English" = 5, "Greek" = 75, "French" = 75, "Russian" = 5, "Arabic" = 10)
	spawn_location = "JoinLateRO"
	uses_squads = TRUE
	min_positions = 1
	max_positions = 80
	allowed_maps = list(MAP_CONSTANTINOPOLI)

/datum/job/roman/fante/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_LOW, "pistol" = STAT_LOW, "bows" = STAT_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/fante/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/us_uni/us_camo_woodland = slot_w_uniform,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/head/helmet/modern/mk6 = slot_head,
	/obj/item/weapon/attachment/bayonet = slot_r_store,
	/obj/item/weapon/key/ancient/greek = slot_l_store,
	/obj/item/weapon/grenade/coldwar/m67 = slot_belt,
	/obj/item/weapon/gun/projectile/submachinegun/g3 = slot_shoulder)
/datum/job/roman/fante/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Latin-speaking soldier of the <i>Imperium Constantinopolitanum</i>. You are equipped with a G3, an M67 grenade, and a bayonet.")
	apply_job_stats(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/fj = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fj, H)
	var/obj/item/clothing/accessory/storage/webbing/us_bandolier = new /obj/item/clothing/accessory/storage/webbing/us_bandolier(null)
	uniform.attackby(us_bandolier, H)
	us_bandolier.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/hk, H)	
	var/picklang = rand(1,3)
	switch(picklang)
		if (1)
			H.name = H.species.get_random_roman_name(H.gender)
			H.real_name = H.name
		if (2)
			H.name = H.species.get_random_greek_name(H.gender)
			H.real_name = H.name
		if (3)
			H.name = H.species.get_random_french_name(H.gender)
			H.real_name = H.name
	return TRUE
	
/datum/job/roman/latinsniper	// Latin Empire - Marksman
	title = "Tireur d'elite"
	en_meaning = "Sniper (Latin-French)"
	rank_abbreviation = "Spc."
	additional_languages = list("English" = 5, "Greek" = 75, "Latin" = 75, "Russian" = 5, "Arabic" = 10)
	spawn_location = "JoinLateRO"
	default_language = "French"
	uses_squads = TRUE
	min_positions = 1
	max_positions = 12
	allowed_maps = list(MAP_CONSTANTINOPOLI)

/datum/job/roman/latinsniper/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MAX, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_LOW, "pistol" = STAT_LOW, "bows" = STAT_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/latinsniper/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/under/us_uni/us_camo_woodland = slot_w_uniform,
	/obj/item/clothing/head/helmet/modern/mk6 = slot_head,
	/obj/item/weapon/key/ancient/greek = slot_r_store,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_l_store,
	/obj/item/weapon/grenade/smokebomb/m18smoke = slot_belt,
	/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = slot_shoulder)
/datum/job/roman/latinsniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a French-speaking sniper of the <i>Imperium Constantinopolitanum</i>. You are equipped with an M14, binoculars, and a smoke grenade.")
	apply_job_stats(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/fj = new /obj/item/clothing/accessory/armor/coldwar/pasgt(null)
	uniform.attackby(fj, H)
	var/obj/item/clothing/accessory/storage/webbing/us_bandolier = new /obj/item/clothing/accessory/storage/webbing/us_bandolier(null)	
	uniform.attackby(us_bandolier, H)
	us_bandolier.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)
	us_bandolier.attackby(new/obj/item/ammo_magazine/m14, H)	
	var/picklang = rand(1,3)
	switch(picklang)
		if (1)
			H.name = H.species.get_random_roman_name(H.gender)
			H.real_name = H.name
		if (2)
			H.name = H.species.get_random_greek_name(H.gender)
			H.real_name = H.name
		if (3)
			H.name = H.species.get_random_french_name(H.gender)
			H.real_name = H.name
	return TRUE
	
/datum/job/roman/ceremonialguard	// Latin Empire - Ceremonial Guardsmen
	title = "Custos Caeremonialis"
	en_meaning = "Ceremonial Guard (Latin-French)"
	rank_abbreviation = ""
	additional_languages = list("English" = 5, "Greek" = 100, "Latin" = 100, "Russian" = 5, "Arabic" = 10)
	spawn_location = "JoinLateRO"
	default_language = "French"
	uses_squads = TRUE
	min_positions = 1
	max_positions = 4
	allowed_maps = list(MAP_CONSTANTINOPOLI)

/datum/job/roman/ceremonialguard/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MAX, "pistol" = STAT_LOW, "bows" = STAT_MAX, "medical" = STAT_MEDIUM_LOW)
/datum/job/roman/ceremonialguard/job_loadout = list(
	/obj/item/clothing/shoes/roman = slot_shoes,
	/obj/item/clothing/under/medieval/crusader = slot_w_uniform,
	/obj/item/clothing/suit/armor/medieval/chainmail = slot_wear_suit,
	/obj/item/clothing/head/helmet/roman_decurion = slot_head,
	/obj/item/weapon/material/halberd/steel = slot_shoulder,
	/obj/item/weapon/material/sword/gladius/iron = slot_belt,
	/obj/item/weapon/shield/roman/praetorian = slot_l_hand)
/datum/job/roman/ceremonialguard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a French-speaking ceremonial guardsman of the <i>Imperium Constantinopolitanum</i>. You are equipped with a Gladius, a pike, and a shield.")
	apply_job_stats(H)
	var/picklang = rand(1,3)
	switch(picklang)
		if (1)
			H.name = H.species.get_random_roman_name(H.gender)
			H.real_name = H.name
		if (2)
			H.name = H.species.get_random_greek_name(H.gender)
			H.real_name = H.name
		if (3)
			H.name = H.species.get_random_french_name(H.gender)
			H.real_name = H.name
	return TRUE