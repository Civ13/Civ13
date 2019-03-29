/mob/living/carbon/human/proc/give_random_civ_name()
	name = species.get_random_english_name(gender)
	real_name = name

/mob/living/carbon/human/proc/give_clothes()
	if (map.ID == MAP_NOMADS_MOUNTAIN)
		if (map.ordinal_age == 0)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bone(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/pickaxe/bone(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/shovel/bone(src), slot_belt)
		else if (map.ordinal_age == 1)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bronze(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/pickaxe/bone(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/shovel/bone(src), slot_belt)
		else if (map.ordinal_age == 2)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/pickaxe(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/shovel(src), slot_belt)
		else if (map.ordinal_age >= 3)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/steel(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/pickaxe(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/shovel(src), slot_belt)
	if (!map.chad_mode)

//knives and other tools/////////////////////////////////////////////////
		if (map.civilizations && map.ID != MAP_NOMADS_MOUNTAIN)
			if (map.ordinal_age == 0)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bone(src), slot_belt)
			else if (map.ordinal_age == 1)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bronze(src), slot_belt)
			else if (map.ordinal_age == 2)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(src), slot_belt)
			else if (map.ordinal_age >= 3)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/steel(src), slot_belt)

//clothes/////////////////////////////////////////////////
		if (map.ordinal_age == 0)
			equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(src), slot_w_uniform)

		else if (map.ordinal_age == 1)
			equip_to_slot_or_del(new /obj/item/clothing/under/celtic_short_braccae(src), slot_w_uniform)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(src), slot_shoes)

		else if (map.ordinal_age == 2)
			equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(src), slot_w_uniform)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
		else if (map.ordinal_age == 3)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(src), slot_shoes)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/under/civ2(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
		else if (map.ordinal_age == 4)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/industrial3(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
		else if (map.ordinal_age == 5)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/modern4(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
//coats/////////////////////////////////////////////////
		spawn(5)
			var/area/mob_area = get_area(src)
			if (mob_area.climate == "tundra" || (mob_area.climate == "temperate" && season == "WINTER") || map.ID == MAP_NOMADS_ICE_AGE)
				if (map.ordinal_age < 4)
					equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur(src), slot_wear_suit)
					if (map.ordinal_age == 0)
						equip_to_slot_or_del(new /obj/item/clothing/shoes/fur(src), slot_shoes)
				else if (map.ordinal_age == 4)
					equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat/grey(src), slot_wear_suit)
				else if (map.ordinal_age == 5)
					equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat/grey(src), slot_wear_suit)

///////////////LANGUAGE PROC/////////////////////////

/mob/living/carbon/human/proc/give_languages()
	if (map && map.civilizations)
		if (map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("tundra")
						if (x<100)
							add_language("Russian",TRUE)
							remove_language("English")
							for (var/datum/language/russian/A in languages)
								default_language = A
							name = species.get_random_russian_name(gender)
							real_name = name
							return
						else
							add_language("Ukrainian",TRUE)
							remove_language("English")
							for (var/datum/language/ukrainian/A in languages)
								default_language = A
							name = species.get_random_ukrainian_name(gender)
							real_name = name
							return
					if ("sea")
						if (x<100)
							add_language("Spanish",TRUE)
							remove_language("English")
							for (var/datum/language/spanish/A in languages)
								default_language = A
							name = species.get_random_spanish_name(gender)
							real_name = name
							add_note("Known Languages", "Spanish")
							return
						else
							add_language("French",TRUE)
							remove_language("English")
							for (var/datum/language/french/A in languages)
								default_language = A
							name = species.get_random_french_name(gender)
							real_name = name
							add_note("Known Languages", "French")
							return
					if ("jungle")
						if (x<100)
							add_language("Swahili",TRUE)
							remove_language("English")
							for (var/datum/language/swahili/A in languages)
								default_language = A
							name = species.get_random_swahili_name(gender)
							real_name = name
							add_note("Known Languages", "Swahili")
							return
						else
							add_language("Zulu",TRUE)
							remove_language("English")
							for (var/datum/language/zulu/A in languages)
								default_language = A
							name = species.get_random_zulu_name(gender)
							real_name = name
							add_note("Known Languages", "Zulu")
							return
					if ("desert")
						if (x<100)
							add_language("Arabic",TRUE)
							remove_language("English")
							for (var/datum/language/arab/A in languages)
								default_language = A
							name = species.get_random_arab_name(gender)
							real_name = name
							add_note("Known Languages", "Arabic")
							return
						else
							add_language("Hebrew",TRUE)
							remove_language("English")
							for (var/datum/language/hebrew/A in languages)
								default_language = A
							name = species.get_random_hebrew_name(gender)
							real_name = name
							add_note("Known Languages", "Hebrew")
							return
					if ("temperate")
						if (x<100)
							add_language("Dutch",TRUE)
							remove_language("English")
							for (var/datum/language/dutch/A in languages)
								default_language = A
							name = species.get_random_dutch_name(gender)
							real_name = name
							add_note("Known Languages", "Dutch")
							return
						else
							add_language("German",TRUE)
							remove_language("English")
							for (var/datum/language/german/A in languages)
								default_language = A
							name = species.get_random_german_name(gender)
							real_name = name
							add_note("Known Languages", "German")
							return
//////////////////////////////////////////////////////
///////////////////Karafuta-Sakhalinsk////////////////
//////////////////////////////////////////////////////
	if (map && map.civilizations)
		if (map.ID == MAP_NOMADS_KARAFUTA)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("tundra")
						if (x<100)
							add_language("Russian",TRUE)
							remove_language("English")
							for (var/datum/language/russian/A in languages)
								default_language = A
							name = species.get_random_russian_name(gender)
							real_name = name
							return
						else
							add_language("Ainu",TRUE)
							remove_language("English")
							for (var/datum/language/ainu/A in languages)
								default_language = A
							name = species.get_random_ainu_name(gender)
							real_name = name
							add_note("Known Languages", "Ainu")
							return

					if ("temperate")
						if (x<100)
							add_language("Japanese",TRUE)
							remove_language("English")
							for (var/datum/language/japanese/A in languages)
								default_language = A
							name = species.get_random_japanese_name(gender)
							real_name = name
							add_note("Known Languages", "Japanese")
							return
						else
							add_language("Ainu",TRUE)
							remove_language("English")
							for (var/datum/language/ainu/A in languages)
								default_language = A
							name = species.get_random_ainu_name(gender)
							real_name = name
							add_note("Known Languages", "Ainu")
							return

/////////////////////////CIVS////////////////////////

/datum/job/civilian/civa
	title = "Civilization A Citizen"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCivA"
	SL_check_independent = TRUE
	is_civilizations = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civa/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.civilization = civname_a
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_a]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civb
	title = "Civilization B Citizen"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCivB"
	SL_check_independent = TRUE
	is_civilizations = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civb/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.civilization = civname_b
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_b]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civc
	title = "Civilization C Citizen"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCivC"
	SL_check_independent = TRUE
	is_civilizations = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civc/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.civilization = civname_c
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_c]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civd
	title = "Civilization D Citizen"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCivD"
	SL_check_independent = TRUE
	is_civilizations = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civd/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.civilization = civname_d
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_d]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/cive
	title = "Civilization E Citizen"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCivE"
	SL_check_independent = TRUE
	is_civilizations = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/cive/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.civilization = civname_e
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_e]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civf
	title = "Civilization F Citizen"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCivF"
	SL_check_independent = TRUE
	is_civilizations = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civf/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.civilization = civname_f
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_f]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civnomad
	title = "Nomad"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_nomad = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civnomad/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_clothes()
	H.make_nomad()
	H.give_languages()

	H.add_note("Role", "You are a <b>Nomad</b>. Form a tribe and survive!")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE
