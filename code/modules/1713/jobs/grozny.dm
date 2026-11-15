/////////Chechen Army//////////////
/datum/job/arab/civilian/chechen/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_chechen_name(H.gender)
	H.real_name = H.name
	H.circumcised = TRUE

/datum/job/arab/civilian/chechen/leader
	title = "Chechen Warlord"
	spawn_location = "JoinLateCCWL"
	allowed_maps = list(MAP_GROZNY)
	
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 3

/datum/job/arab/civilian/chechen/leader/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_NORMAL)
/datum/job/arab/civilian/chechen/leader/job_loadout = list(
	/obj/item/clothing/shoes/toughguy = slot_shoes,
	/obj/item/clothing/head/ww/papakha = slot_head,
	/obj/item/clothing/under/insurgent_leader = slot_w_uniform,
	/obj/item/clothing/suit/b3 = slot_wear_suit,
	/obj/item/clothing/mask/smokable/cigarette/cigar = slot_wear_mask,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/gloves/toughguy = slot_gloves,
	/obj/item/clothing/mask/gas/russia = slot_l_store,
	/obj/item/weapon/gun/projectile/pistol/tt30 = slot_l_hand,
	/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso/kgb = slot_shoulder,
	/obj/item/weapon/storage/backpack/duffel = slot_back,
	/obj/item/weapon/storage/belt/smallpouches/green/chechoff = slot_belt)
/datum/job/arab/civilian/chechen/leader/equip(var/mob/living/human/H)

//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	H.s_tone = rand(-60,-30)
	H.f_style = pick("Full Beard","Medium Beard","Long Beard","Abraham Lincoln Beard","Neckbeard","Selleck Mustache","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father","Parted","Shoulder-length Hair")

	var/new_hair = pick("Dark Brown","Black","Orange","Grey")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Militia"
	give_random_name(H)
	H.add_note("Role", "You are a Warlord! Organize the militia and fend off the russian invaders!")
	apply_job_stats(H)
	return TRUE

/datum/job/arab/civilian/chechen/militia
	title = "Chechen Militia"
	rank_abbreviation = ""
	spawn_location = "JoinLateCC"
	min_positions = 10
	max_positions = 200
	allowed_maps = list(MAP_GROZNY)

/datum/job/arab/civilian/chechen/militia/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_LOW, "machinegun" = STAT_NORMAL)
/datum/job/arab/civilian/chechen/militia/equip(var/mob/living/human/H)

//shoes
	var/randshoe2 = rand(1,5)
	switch(randshoe2)
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
	var/randjack2 = rand(1,10)
	switch(randjack2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_black(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_sand(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_sand_dcu(H), slot_w_uniform)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_sand_green(H), slot_w_uniform)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/oldmansuit(H), slot_w_uniform)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/engi(H), slot_w_uniform)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_sand_woodland(H), slot_w_uniform)
		if (8)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/mafia(H), slot_w_uniform)
		if (9)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		if (10)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)

//head
	var/randhead2 = rand(1,6)
	switch(randhead2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adriansoviet(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha/white(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/commando_bandana(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)

//gloves
	var/randglove2 = rand(1,4)
	switch(randglove2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/watch(H), slot_gloves)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/specialwatch(H), slot_gloves)

//misc
	var/randmisc2 = rand(1,6)
	switch(randmisc2)
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
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava(H), slot_wear_mask)

//weapon
	var/randarmw = rand(1,3)
	switch(randarmw)
		if (1)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/vz58(H), slot_l_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_l_hand)

		if (2)
			if (prob(60))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_l_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso(H), slot_l_hand)
		if (3)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_l_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_l_hand)

//quran
	if (prob(33))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/bible/quran(H), slot_r_hand)

	var/randsword2 = rand(1,3)
	switch(randsword2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/machete(H), slot_belt)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/shashka(H), slot_belt)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/tacticalknife(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/plate/armor = new /obj/item/clothing/accessory/armor/modern/plate(null)
	uniform.attackby(armor, H)

//suit
	var/randsuit = rand(1,6)
	switch(randsuit)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/biker/lizard_jacket(H), slot_wear_suit)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/bomberjacketbrown(H), slot_wear_suit)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/b3(H), slot_wear_suit)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/expensivecoat(H), slot_wear_suit)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat2(H), slot_wear_suit)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/winter_coat(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

//back
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(H), slot_back)

	H.s_tone = rand(-60,-30)
	H.f_style = pick("Full Beard","Medium Beard","Long Beard","Abraham Lincoln Beard","Neckbeard","Selleck Mustache","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father","Parted","Shoulder-length Hair")

	var/new_hair = pick("Dark Brown","Black","Orange","Grey")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.add_note("Role", "You are a <b>[title]</b> insurging against the Russian occupants! Do all it takes to prevent them from crossing the bridge south of the city and listen to your Warlords!")
	H.civilization = "Militia"
	give_random_name(H)
	apply_job_stats(H)
	return TRUE

/datum/job/arab/civilian/chechen/medic
	title = "Chechen Militia Medic"
	rank_abbreviation = "Dr."
	allowed_maps = list(MAP_GROZNY)

	spawn_location = "JoinLateCC"

	is_medic = TRUE

	min_positions = 3
	max_positions = 10

/datum/job/arab/civilian/chechen/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/arab/civilian/chechen/job_loadout = list(
	/obj/item/clothing/shoes/laceup = slot_shoes,
	/obj/item/clothing/under/insurgent_black = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/doctor = slot_wear_suit,
	/obj/item/clothing/head/helmet/ww/adrianm26medic = slot_head,
	/obj/item/clothing/mask/sterile = slot_wear_mask,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat/modern = slot_belt,
	/obj/item/weapon/storage/firstaid/surgery = slot_l_hand,
	/obj/item/weapon/radio/walkietalkie/faction1 = slot_wear_id,
	/obj/item/clothing/gloves/color/white = slot_gloves,
	/obj/item/weapon/gun/projectile/revolver/smithwesson = slot_r_store)
/datum/job/arab/civilian/chechen/equip(var/mob/living/human/H)

//shoes
	equip_loadout(H)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	H.s_tone = rand(-60,-30)
	H.f_style = pick("Full Beard","Medium Beard","Long Beard","Abraham Lincoln Beard","Neckbeard","Selleck Mustache","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father","Parted","Shoulder-length Hair")

	var/new_hair = pick("Dark Brown","Black","Orange","Grey")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.add_note("Role", "You are a <b>[title]</b>. Keep your brothers healthy and motivated!")
	H.civilization = "Militia"
	give_random_name(H)
	apply_job_stats(H)
	return TRUE

/////////Russian Federal Forces//////////////

/datum/job/russian/ruff_lieutenant
	title = "Russian Federal Forces Lieutenant"
	rank_abbreviation = "Leyt."
	allowed_maps = list(MAP_GROZNY)

	spawn_location = "JoinLateRUCap"

	allowed_maps = list(MAP_CONSTANTINOPOLI)
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/ruff_lieutenant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_NORMAL)
/datum/job/russian/ruff_lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/rus_vsr93 = slot_w_uniform,
	/obj/item/clothing/gloves/thick/swat/officer = slot_gloves,
	/obj/item/clothing/head/beret_rus_vdv = slot_head,
	/obj/item/weapon/radio/walkietalkie/faction2 = slot_wear_id,
	/obj/item/weapon/gun/projectile/special/ak74mtactical = slot_shoulder,
	/obj/item/weapon/gun/projectile/pistol/makarov = slot_l_hand,
	/obj/item/weapon/storage/belt/smallpouches/green/rusoff = slot_belt)
/datum/job/russian/ruff_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
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
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Full Beard","Goatee","Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown","Grey")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ruff_sergeant
	title = "Russian Federal Forces Sergeant"
	rank_abbreviation = "Sgt."
	allowed_maps = list(MAP_GROZNY)

	spawn_location = "JoinLateRUSgt"

	allowed_maps = list(MAP_CONSTANTINOPOLI)
	is_squad_leader = TRUE
	uses_squads = TRUE

	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/russian/ruff_sergeant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_LOW, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/russian/ruff_sergeant/job_loadout = list(
	/obj/item/clothing/under/rus_vsr93 = slot_w_uniform,
	/obj/item/clothing/gloves/thick/combat = slot_gloves)
/datum/job/russian/ruff_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	equip_loadout(H)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/sfera(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/rusoff(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
//jacket
	if (prob(33))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Goatee","Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown","Grey")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead and coordinate your squad with your officer! Remember to issue coordinates to your Radio Operator.")
	apply_job_stats(H)
	return TRUE


/datum/job/russian/ruff_medic
	title = "Russian Federal Forces Corpsman"
	rank_abbreviation = "Efr."
	allowed_maps = list(MAP_GROZNY)

	spawn_location = "JoinLateRUMedic"

	is_medic = TRUE
	allowed_maps = list(MAP_CONSTANTINOPOLI)

	min_positions = 2
	max_positions = 8

/datum/job/russian/ruff_medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_NORMAL, "bows" = STAT_LOW, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/russian/ruff_medic/job_loadout = list(
	/obj/item/clothing/mask/sterile = slot_wear_mask,
	/obj/item/clothing/head/helmet/ww2/soviet_medic = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/combat/modern = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/makarov = slot_l_hand,
	/obj/item/weapon/radio/walkietalkie/faction2 = slot_wear_id,
	/obj/item/clothing/gloves/color/white = slot_gloves)
/datum/job/russian/ruff_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/rus_vsr93(H), slot_w_uniform)
		if (prob(15))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
		if (prob(15))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)
//head
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Goatee","Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and alive!")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ruff_radioman
	title = "Russian Federal Forces Radio Operator"
	rank_abbreviation = "Efr."
	allowed_maps = list(MAP_GROZNY)

	spawn_location = "JoinLateRURadop"

	allowed_maps = list(MAP_CONSTANTINOPOLI)
	is_radioman = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/russian/ruff_radioman/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_LOW, "medical" = STAT_LOW, "machinegun" = STAT_NORMAL)
/datum/job/russian/ruff_radioman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/rus_vsr93(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	var/randhead3 = rand(1,3)
	switch(randhead3)
		if (1)
			if (prob(70))
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap_fed(H), slot_head)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
		if (2)
			if (prob(30))
				H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap_fed(H), slot_head)
		if (3)
			if (prob(40))
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap_fed(H), slot_head)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/head/olivebandana(H), slot_head)
//back
	var/randarmwrus = rand(1,2)
	switch(randarmwrus)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
	
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, follow orders given by your superiors and call in airstrikes using the coordinates given to you.")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ruff_soldier
	title = "Russian Federal Forces Private"
	rank_abbreviation = "Ryad."
	allowed_maps = list(MAP_GROZNY)

	spawn_location = "JoinLateRU"

	allowed_maps = list(MAP_CONSTANTINOPOLI)

	uses_squads = TRUE

	min_positions = 10
	max_positions = 80

/datum/job/russian/ruff_soldier/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_LOW, "medical" = STAT_LOW, "machinegun" = STAT_NORMAL)
/datum/job/russian/ruff_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/rus_vsr93(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/afghanka(H), slot_w_uniform)
		if (prob(65))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	var/randhead3 = rand(1,3)
	switch(randhead3)
		if (1)
			if (prob(70))
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap_fed(H), slot_head)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
		if (2)
			if (prob(70))
				H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap_fed(H), slot_head)
		if (3)
			if (prob(60))
				H.equip_to_slot_or_del(new /obj/item/clothing/head/black_beanie(H), slot_head)
			else
				H.equip_to_slot_or_del(new /obj/item/clothing/head/olivebandana(H), slot_head)
//back
	var/randarmwrus = rand(1,2)
	switch(randarmwrus)
		if (1)
			if (prob(80))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/pkm(H), slot_belt)
		if (2)
			if (prob(80))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svd(H), slot_shoulder)
				H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_svd(H), slot_belt)

	H.s_tone = rand(-32,-24)
	H.f_style = pick("Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, you were conscripted right after your 18th birthday; What a joy! Follow orders given by your superiors and defeat the enemy!")
	apply_job_stats(H)
	return TRUE

/datum/job/russian/ruff_spetsnaz
	title = "Spetsnaz GRU Operative"
	rank_abbreviation = "Spz. Op."
	allowed_maps = list(MAP_GROZNY)

	spawn_location = "JoinLateRUsptz"
	whitelisted = TRUE
	allowed_maps = list(MAP_CONSTANTINOPOLI)

	uses_squads = TRUE

	min_positions = 1
	max_positions = 8

/datum/job/russian/ruff_spetsnaz/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/russian/ruff_spetsnaz/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/gorka = slot_w_uniform,
	/obj/item/weapon/radio/walkietalkie/faction2 = slot_wear_id)
/datum/job/russian/ruff_spetsnaz/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour.attackby(plates1, H)
	armour.attackby(plates2, H)
	uniform.attackby(armour, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)

//head
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sovietbala(H), slot_wear_mask)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	
	var/randarmwruspez = rand(1,3)
	switch (randarmwruspez)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/vintorez(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_vintorez(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/vintorez, slot_l_store)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_spez(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/saiga12(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_saiga(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/saiga12, slot_l_store)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_spz(H), slot_belt)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74/ak74m, slot_l_store)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/zsh1(H), slot_head)

	H.f_style = pick("Goatee","Selleck Mustache","Shaved","Short Facial Hair")
	H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover")

	var/new_hair = pick("Red","Orange","Light Blond","Blond","Dirty Blond","Light Brown")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

	H.civilization = "Russian"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, part of the Spetsnaz GRU. You are the best of the best; put an end to this conflict!")
	apply_job_stats(H)
	return TRUE