/datum/job/roman/colonel	//Latin Empire - Colonel
	title = "Colonellus"
	en_meaning = "Colonel (Latin-Italian)"
	rank_abbreviation = "Col."
	is_latin = TRUE
	spawn_location = "JoinLateRO"
	additional_languages = list("English" = 5, "Greek" = 100, "French" = 100, "Russian" = 5, "Arabic" = 10)
	is_commander = TRUE
	is_officer = TRUE
	is_radioman = FALSE
	whitelisted = TRUE
	min_positions = 1
	max_positions = 1

/datum/job/roman/colonel/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/japcoat/sand(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/hk(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/greek(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/g3(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, the commander of <b>your entire regiment</b>. Organize your <b>Sergenti</b> and lead your soldiers to victory!</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MAX)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MAX)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
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
	is_latin = TRUE
	spawn_location = "JoinLateRO"
	additional_languages = list("English" = 5, "Greek" = 75, "French" = 100, "Russian" = 5, "Arabic" = 10)
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_radioman = FALSE
	min_positions = 2
	max_positions = 10

/datum/job/roman/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/mk6(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/hk(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/greek(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/g3(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a squad. Lead your <b>Fanti and Stratiotes</b> to battle, following the orders of the <b>Colonellus</b>!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MAX)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
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
	is_latin = TRUE

/datum/job/roman/stratiotes/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/mk6(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/greek(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/g3(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, a Greek-speaking soldier of the <i>Latinike Katoche</i>. You are equipped with a G3, an M67 grenade, and a bayonet.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
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
	is_latin = TRUE

/datum/job/roman/fante/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/mk6(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/greek(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/g3(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, a Latin-speaking soldier of the <i>Imperium Constantinopolitanum</i>. You are equipped with a G3, an M67 grenade, and a bayonet.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
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
	is_latin = TRUE

/datum/job/roman/latinsniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/mk6(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/greek(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/m18smoke(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14/sniper(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, a French-speaking sniper of the <i>Imperium Constantinopolitanum</i>. You are equipped with an M14, binoculars, and a smoke grenade.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MAX)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
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
	is_latin = TRUE

/datum/job/roman/ceremonialguard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/crusader(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman_decurion(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/halberd/steel(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman/praetorian(H), slot_l_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a French-speaking ceremonial guardsman of the <i>Imperium Constantinopolitanum</i>. You are equipped with a Gladius, a pike, and a shield.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MAX)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MAX)
	H.setStat("medical", STAT_MEDIUM_LOW)
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