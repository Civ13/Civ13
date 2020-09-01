/datum/job/russian/nkvd_gulag_commander
	title = "GULAG Nachalnik Lagerya"
	en_meaning = "NKVD GULAG Camp Commander"
	rank_abbreviation = "NKVD Kom."


	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE

	is_prison = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/nkvd_gulag_commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/nkvd_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton(H), slot_belt)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/soviet/guard/G1 = new/obj/item/weapon/key/soviet/guard(null)
	var/obj/item/weapon/key/soviet/guard/G2 = new/obj/item/weapon/key/soviet/guard/max(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the commander of <b></b>. Organize your squad leaders and make sure all the prisoners are kept in their place!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.verbs += /mob/living/human/proc/Sound_Alarm
	H.verbs += /mob/living/human/proc/Stop_Alarm
	return TRUE

/datum/job/russian/nkvd_gulag_officer
	title = "GULAG Nachalnik Karaula"
	en_meaning = "NKVD GULAG Squad Leader"
	rank_abbreviation = "NKVD Str."

	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	whitelisted = TRUE

	is_prison = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/russian/nkvd_gulag_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/soviet/guard/G1 = new/obj/item/weapon/key/soviet/guard(null)
	var/obj/item/weapon/key/soviet/guard/G2 = new/obj/item/weapon/key/soviet/guard/max(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an officer of the NKVD GULAG guards. Organize your men and keep the prisoners in place!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.verbs += /mob/living/human/proc/Sound_Alarm
	H.verbs += /mob/living/human/proc/Stop_Alarm

	return TRUE

/datum/job/russian/nkvd_gulag_medic
	title = "GULAG Medik"
	en_meaning = "NKVD GULAG Medic"
	rank_abbreviation = "NKVD Srj."

	spawn_location = "JoinLateRU"
	whitelisted = TRUE

	is_medic = TRUE
	is_prison = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/russian/nkvd_gulag_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha/white(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/advsmall(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet/guard(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a medic of the GULAG staff. Keep both the prisoners and the guards healthy and alive.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/russian/nkvd_gulag_guard
	title = "GULAG Karaulnyi"
	en_meaning = "NKVD GULAG Guard"
	rank_abbreviation = "NKVD"

	spawn_location = "JoinLateRU"
	whitelisted = TRUE
	is_prison = TRUE

	min_positions = 10
	max_positions = 50

/datum/job/russian/nkvd_gulag_guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha/white(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet/guard(H), slot_l_store)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a guard of the GULAG. Keep the prisoners in place!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////PRISONERS////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/civilian/prisoner

	is_prison = TRUE
	spawn_location = "JoinLateCiv"

	rank_abbreviation = ""
	title = "DO NOT USE"
	var/nationality = "none"
	default_language = "Russian"
	var/randrole = "none"
	var/original_eyes = "Black"
	var/original_facial = "Shaved"
	var/original_hair = "Short Hair"
/datum/job/civilian/prisoner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/gulag_prisoner(H), slot_w_uniform)
//head
	if (prob(30))
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)

	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat2(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/prisoner_passport(H), slot_wear_id)
	var/obj/item/stack/money/rubles/RUB = new /obj/item/stack/money/rubles(H)
	RUB.amount = 25
	H.equip_to_slot_or_del(RUB, slot_r_store)
	if (prob(5))
		if (prob(70))
			H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/shank(H), slot_r_store)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/shank/glass(H), slot_r_store)
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.give_nationality()
	return TRUE

/mob/living/human/proc/give_nationality()
	if (istype(original_job, /datum/job/civilian/prisoner))
		var/datum/job/civilian/prisoner/PJ = original_job
		var/randpick = rand(1,4)
		switch(randpick)
			if (1)
				if (PJ.nationality == "none")
					add_language("Polish",FALSE)
					add_note("Known Languages", "Polish")
					remove_language("English")
					name = species.get_random_polish_name(gender)
					real_name = name
					add_note("Group", "You are a Polish anti-communist prisoner. You are part of the <b>Polish</b> faction. Try to escape and/or keep your faction powerful!")
					PJ.nationality = "Polish"

			if (2)
				if (PJ.nationality == "none")
					add_language("Ukrainian",FALSE)
					add_note("Known Languages", "Ukrainian")
					remove_language("English")
					name = species.get_random_ukrainian_name(gender)
					real_name = name
					add_note("Group", "You are a Ukrainian political prisoner. You are part of the <b>Ukrainian</b> faction. Try to escape and/or keep your faction powerful!")
					PJ.nationality = "Ukrainian"

			if (3)
				if (PJ.nationality == "none")
					remove_language("English")
					name = species.get_random_russian_name(gender)
					real_name = name
					add_note("Group", "You are a Vor, a Soviet criminal. You are part of the <b>Vory</b> faction. Try to escape and/or keep your faction powerful!")
					PJ.nationality = "Vory"

			if (4)
				if (PJ.nationality == "none")
					add_language("German",FALSE)
					add_note("Known Languages", "German")
					remove_language("English")
					name = species.get_random_german_name(gender)
					real_name = name
					add_note("Group", "You are a Wehrmacht prisoner of war. You are part of the <b>German</b> faction. Try to escape and/or keep your faction powerful!")
					PJ.nationality = "German"
		PJ.original_hair = pick("Black", "Light Brown", "Dark Brown", "Red", "Orange", "Light Blond", "Blond", "Dirty Blond", "Light Grey", "Grey")
		PJ.original_facial = PJ.original_hair
		var/hex_hair = hair_colors[PJ.original_hair]
		var/red = hex2num(copytext(hex_hair, 2, 4))
		var/green = hex2num(copytext(hex_hair, 4, 6))
		var/blue = hex2num(copytext(hex_hair, 6, 8))
		r_hair = red
		g_hair = green
		b_hair = blue
		r_facial = red
		g_facial = green
		b_facial = blue
		PJ.original_eyes = pick("Black", "Brown", "Dark Brown", "Green", "Blue")
		var/hex_eyes = eye_colors[PJ.original_eyes]
		red = hex2num(copytext(hex_eyes, 2, 4))
		green = hex2num(copytext(hex_eyes, 4, 6))
		blue = hex2num(copytext(hex_eyes, 6, 8))
		r_eyes = red
		g_eyes = green
		b_eyes = blue

		h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Parted","Bedhead","Shoulder-length Hair")
		f_style = pick("Shaved","Chinstrap","Medium Beard","Long Beard","Full Beard","Very Long Beard")
		update_body()
/datum/job/civilian/prisoner/janitor
	title = "Janitor"
	en_meaning = ""


	min_positions = 2
	max_positions = 20
	equip(var/mob/living/human/H)
		..()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#906AD1"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "[title] armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are a <b>Janitor</b>. Your job is to keep the camp area clean. Make sure its spotless or you'll get beaten!")
		randrole = title

/datum/job/civilian/prisoner/miner
	title = "Miner"
	en_meaning = ""


	min_positions = 10
	max_positions = 100
	equip(var/mob/living/human/H)
		..()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#A5682A"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "[title] armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are a <b>Miner</b>. Your job is to get to the mines and collect minerals for the guards.")
		randrole = title
/*
/datum/job/civilian/prisoner/logger
	title = "Logger"
	en_meaning = ""


	min_positions = 10
	max_positions = 100
	equip(var/mob/living/human/H)
		..()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#5AB300"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "[title] armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are a <b>Logger</b>. Your job is to collect wood from the nearby forest, as instructed by the guards.")
		randrole = title

/datum/job/civilian/prisoner/builder
	title = "Builder"
	en_meaning = ""


	min_positions = 10
	max_positions = 100
	equip(var/mob/living/human/H)
		..()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#000000"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "[title] armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are a <b>Builder</b>. Your job is to build roads and railroads nearby, as instructed by the guards.")
		randrole = title
*/
/datum/job/civilian/prisoner/nurse
	title = "Nurse Helper"
	en_meaning = ""


	min_positions = 3
	max_positions = 30
	equip(var/mob/living/human/H)
		..()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#FFFFFF"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "[title] armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are a <b>Nurse Helper</b>. Keep other prisoners alive with the sparse supplies you have...")
		randrole = title

/datum/job/civilian/prisoner/kitchen
	title = "Kitchen Duty"
	en_meaning = ""


	min_positions = 3
	max_positions = 25
	equip(var/mob/living/human/H)
		..()
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		armband.color = "#990000"
		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "[title] armband"
		uniform.attackby(armband, H)
		H.add_note("Role", "You are on <b>Kitchen Duty</b>. Your job is to manage the prisoner's stock of food (if the guards actually deliver it...) and keep everyone fed.")
		randrole = title

/datum/job/civilian/prisoner/collaborator
	title = "Collaborator"
	en_meaning = ""


	min_positions = 1
	max_positions = 12
	equip(var/mob/living/human/H)
		..()
		randrole = pick("Janitor", "Kitchen Duty", "Miner", "Nurse Helper",/* "Builder", "Logger"*/)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/custom/armband/armband = new /obj/item/clothing/accessory/custom/armband(null)
		switch(randrole)
			if ("Janitor")
				armband.color = "#906AD1"
			if ("Kitchen Duty")
				armband.color = "#990000"
			if ("Miner")
				armband.color = "#A5682A"
			if ("Nurse Helper")
				armband.color = "#FFFFFF"
			if ("Builder")
				armband.color = "#000000"
			if ("Logger")
				armband.color = "#5AB300"

		armband.setd = TRUE
		armband.uncolored = FALSE
		armband.name = "[randrole] armband"
		uniform.attackby(armband, H)
		H.add_note("Primary Role", "You are a <b>Collaborator</b>. Your job is to get information and pass it to the guards. Be careful, your fellow prisoners might not like it if they find it out... Try to act like your assigned role, <b>[randrole]</b>.")