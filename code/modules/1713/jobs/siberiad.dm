/// NATO/COALITION ///

/datum/job/american/siberiad/commander
	title = "Coalition Commander"
	rank_abbreviation = "Capt."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE
	is_commander = TRUE
	is_officer = TRUE

	uses_squads = TRUE
	whitelisted = TRUE

	additional_languages = list("Russian" = 70)
	min_positions = 1
	max_positions = 1
	selection_color = "#153043"

/datum/job/american/siberiad/commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava/snow(H), slot_wear_mask)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/hk417/att(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/hk417(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_black/insig(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/blue = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(blue, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/command/nato(H), slot_back)

	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Coordinate your men during the operation in order to complete the objective!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/american/siberiad/squadlead
	title = "Coalition Squad Leader"
	rank_abbreviation = "Sgt."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE
	is_squad_leader = TRUE

	uses_squads = TRUE

	additional_languages = list("Russian" = 20)
	min_positions = 2
	max_positions = 8
	selection_color = "#153043"

/datum/job/american/siberiad/squadlead/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//eyes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles/ballistic(H), slot_eyes)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava/snow(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/red = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/scarl(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_grenade(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m16/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m16(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_grenade(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m16/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m16(null)
			uniform.attackby(webbing, H)
//helmet
	var/rand_helmet = rand(1,3)
	switch(rand_helmet)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt/two(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/medical(H), slot_back)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/extracap/medicalh(H), slot_back)
	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Take orders from your Operation Leader and lead your squad towards victory!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/american/siberiad/spec
	title = "Coalition Weapons Specialist"
	rank_abbreviation = "Spc."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE

	uses_squads = TRUE

	additional_languages = list("Russian" = 10)
	min_positions = 4
	max_positions = 8
	selection_color = "#153043"

/datum/job/american/siberiad/spec/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/red = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m60(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/olive/m60(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m60/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m60(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/manual/m249(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/green/m249(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m249/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m249(null)
			uniform.attackby(webbing, H)
//helmet
	var/rand_helmet = rand(1,3)
	switch(rand_helmet)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt/two(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)

	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Provide assistance to your squad sing your weapon expertise!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/american/siberiad/medic
	title = "Coalition Corpsman"
	rank_abbreviation = "Cpl."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE

	is_medic = TRUE

	additional_languages = list("Russian" = 10)
	min_positions = 1
	max_positions = 4
	selection_color = "#153043"

/datum/job/american/siberiad/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband  = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5(H), slot_shoulder)
//helmet
	var/rand_helmet = rand(1,4)
	switch(rand_helmet)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt/two(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_beanie(H), slot_head)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/sterile/nitrile(H), slot_gloves)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)

	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Keep your squadmates alive!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_LOW)
	give_random_name(H)

	return TRUE


/datum/job/american/siberiad/infantry
	title = "Coalition Rifleman"
	rank_abbreviation = "Pfc."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE

	uses_squads = TRUE

	additional_languages = list("Russian" = 10)
	min_positions = 9
	max_positions = 90
	selection_color = "#153043"

/datum/job/american/siberiad/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/red = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//gun
	var/loadout = rand(1,3)
	switch(loadout)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a2(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/stanag(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m16/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m16(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a2/att(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/stanag(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m16/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m16(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/g3(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/g3/FW = new /obj/item/clothing/accessory/storage/webbing/green_webbing/g3(null)
			uniform.attackby(FW, H)
//helmet
	var/rand_helmet = rand(1,4)
	switch(rand_helmet)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt/two(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white/alt(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/black_beanie(H), slot_head)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)

	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Follow your Squad Leader and his orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/// SOVIET UNION ///

/datum/job/russian/siberiad/commander
	title = "Soviet Army Commander"
	rank_abbreviation = "Kapt."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE
	is_commander = TRUE
	is_officer = TRUE

	uses_squads = TRUE
	whitelisted = TRUE

	additional_languages = list("English" = 70)
	min_positions = 1
	max_positions = 1

	selection_color = "#CC0000"

/datum/job/russian/siberiad/commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/gorka(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer/alt(H), slot_wear_suit)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/pso1(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/sov_ushanka_new(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//misc
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armour2, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour2.attackby(plates1, H)
	armour2.attackby(plates2, H)
	uniform.attackby(armour2, H)

	H.civilization = "Soviet Army"
	H.add_note("Role", "You are the <b>[title]</b>. Command and lead your men towards the objective.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/siberiad/sl
	title = "Soviet Army Squad Leader"
	rank_abbreviation = "Snr Srj."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE
	is_squad_leader = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 20)
	min_positions = 2
	max_positions = 8
	selection_color = "#CC0000"

/datum/job/russian/siberiad/sl/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/gorka(H), slot_w_uniform)
//mask
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava/green(H), slot_wear_mask)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/sovietbala(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m/ak12(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_trench(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
			uniform.attackby(webbing, H)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
//back
	H.civilization = "Soviet Army"
	H.add_note("Role", "You are a <b>[title]</b>. Take orders from your commander and lead your squad towards the objective!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/siberiad/heavy
	title = "Soviet Army Heavy Weapons Specialist"
	rank_abbreviation = "Efr."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 10)
	min_positions = 4
	max_positions = 8
	selection_color = "#CC0000"

/datum/job/russian/siberiad/heavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey/asbestos(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armour2, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour2.attackby(plates1, H)
	armour2.attackby(plates2, H)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/white/pkm(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/pkm/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/pkm(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/rpk74(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/white/rpk(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/rpk/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/rpk(null)
			uniform.attackby(webbing, H)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/sovietfacehelmet(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

	H.civilization = "Soviet Army"
	H.add_note("Role", "You are a <b>[title]</b>. Provide support to your squad using your heavy weaponry!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/russian/siberiad/medic
	title = "Soviet Army Corpsman"
	rank_abbreviation = "Efr."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE

	is_medic = TRUE

	additional_languages = list("English" = 5)
	min_positions = 1
	max_positions = 4
	selection_color = "#CC0000"

/datum/job/russian/siberiad/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband  = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
	uniform.attackby(webbing, H)
//helmet
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/sov_ushanka_new(H), slot_head)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/sterile(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)

	H.civilization = "Soviet Army"
	H.add_note("Role", "You are a <b>[title]</b>. Follow your Squad Leader and his orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/russian/siberiad/infantry
	title = "Soviet Army Rifleman"
	rank_abbreviation = "Ryad."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 5)
	min_positions = 9
	max_positions = 90
	selection_color = "#CC0000"

/datum/job/russian/siberiad/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
//gun
	var/loadout= rand(1,2)
	switch(loadout)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74(H), slot_belt)
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
	uniform.attackby(webbing, H)
//helmet
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/sov_ushanka_new(H), slot_head)
//masks
	if (prob(50))
		var/rand_mask = rand(1,3)
		switch(rand_mask)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh(H), slot_wear_mask)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/clothing/mask/sovietbala(H), slot_wear_mask)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava/green(H), slot_wear_mask)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)

	H.civilization = "Soviet Army"
	H.add_note("Role", "You are a <b>[title]</b>. Follow your Squad Leader and his orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE