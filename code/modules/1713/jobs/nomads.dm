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
			if (map && map.ID == MAP_CIVILIZATIONS)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
				spawn(5)
					if (gender == "male")
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(src), slot_w_uniform)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/green(src), slot_w_uniform)
					else
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/civfr(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/civfg(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
			else if(map && map.ID == MAP_TRIBES)
				if (orc)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
					var/obj/item/clothing/under/customtribalrobe/C = new/obj/item/clothing/under/customtribalrobe(src)
					spawn(10)
						C.uncolored = FALSE
					C.shirtcolor = "#000000"
					C.pantscolor = "#9A1313"
					var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_decoration")
					pants.color = C.pantscolor
					var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robe")
					shirt.color = C.shirtcolor
					var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robebelt")
					overlays += pants
					overlays += shirt
					overlays += belt
					equip_to_slot_or_del(C, slot_w_uniform)
					update_icons(1)
				else if (gorillaman)
					equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(src), slot_w_uniform)
				else if (ant)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
					equip_to_slot_or_del(new /obj/item/clothing/under/celtic_blue(src), slot_w_uniform)
				else if (lizard)
					equip_to_slot_or_del(new /obj/item/clothing/under/mayan_loincloth(src), slot_w_uniform)
				else if (wolfman || crab)
					equip_to_slot_or_del(new /obj/item/clothing/under/loincotton(src), slot_w_uniform)
				else
					equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
					equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(src), slot_w_uniform)
		else if (map.ordinal_age == 3)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(src), slot_shoes)
			if (map.ID == MAP_CIVILIZATIONS)
				spawn(5)
					make_nomad()
					if (gender == "male")
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(src), slot_w_uniform)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/green(src), slot_w_uniform)
					else
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/civfr(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/civfg(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
			else
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
		else if (map.ordinal_age == 6)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/modern4(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
		else if (map.ordinal_age == 7)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/modern4(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
		else if (map.ordinal_age == 8)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/modern4(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
//coats/////////////////////////////////////////////////
		spawn(5)
			var/area/mob_area = get_area(src)
			if (mob_area.climate == "tundra" || mob_area.climate == "taiga" || (mob_area.climate == "temperate" && season == "WINTER") || map.ID == MAP_NOMADS_ICE_AGE)
				if (map.ordinal_age < 4)
					equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur(src), slot_wear_suit)
					if (map.ordinal_age == 0)
						equip_to_slot_or_del(new /obj/item/clothing/shoes/fur(src), slot_shoes)
				else if (map.ordinal_age == 4)
					equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat/grey(src), slot_wear_suit)
				else if (map.ordinal_age >= 5)
					equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat/grey(src), slot_wear_suit)

///////////////LANGUAGE PROC/////////////////////////

/mob/living/carbon/human/proc/give_languages()
	if (map && map.civilizations)
		if (map.ID == MAP_NOMADS_CONTINENTAL)
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

		else if (map.ID == MAP_NOMADS_PANGEA)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("tundra")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						return
					if ("taiga")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						return
					if ("semiarid")
						add_language("Latin",TRUE)
						remove_language("English")
						for (var/datum/language/latin/A in languages)
							default_language = A
						name = species.get_random_roman_name(gender)
						real_name = name
						add_note("Known Languages", "Latin")
						return
					if ("savanna")
						add_language("Swahili",TRUE)
						remove_language("English")
						for (var/datum/language/swahili/A in languages)
							default_language = A
						name = species.get_random_swahili_name(gender)
						real_name = name
						add_note("Known Languages", "Swahili")
						return
					if ("jungle")
						add_language("Japanese",TRUE)
						remove_language("English")
						for (var/datum/language/japanese/A in languages)
							default_language = A
						name = species.get_random_japanese_name(gender)
						real_name = name
						add_note("Known Languages", "Japanese")
						return
					if ("desert")
						add_language("Arabic",TRUE)
						remove_language("English")
						for (var/datum/language/arab/A in languages)
							default_language = A
						name = species.get_random_arab_name(gender)
						real_name = name
						add_note("Known Languages", "Arabic")
						return
					if ("temperate")
						add_language("German",TRUE)
						remove_language("English")
						for (var/datum/language/german/A in languages)
							default_language = A
						name = species.get_random_german_name(gender)
						real_name = name
						add_note("Known Languages", "German")
						return
/*
		else if (map.ID == MAP_NOMADS_PANGEA)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("tundra")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						return
					if ("taiga")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						return
					if ("semiarid")
						add_language("Dutch",TRUE)
						remove_language("English")
						for (var/datum/language/dutch/A in languages)
							default_language = A
						name = species.get_random_dutch_name(gender)
						real_name = name
						add_note("Known Languages", "Dutch")
						return
					if ("savanna")
						add_language("Chinese",TRUE)
						remove_language("English")
						for (var/datum/language/chinese/A in languages)
							default_language = A
						name = species.get_random_chinese_name(gender)
						real_name = name
						add_note("Known Languages", "Chinese")
						return
					if ("jungle")
						add_language("Chinese",TRUE)
						remove_language("English")
						for (var/datum/language/chinese/A in languages)
							default_language = A
						name = species.get_random_chinese_name(gender)
						real_name = name
						add_note("Known Languages", "Chinese")
						return
					if ("desert")
						add_language("Dutch",TRUE)
						remove_language("English")
						for (var/datum/language/dutch/A in languages)
							default_language = A
						name = species.get_random_dutch_name(gender)
						real_name = name
						add_note("Known Languages", "Dutch")
						return
					if ("temperate")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						return
*/
//////////////////////////////////////////////////////
///////////////////Karafuta-Sakhalinsk////////////////
//////////////////////////////////////////////////////
		else if (map.ID == MAP_NOMADS_KARAFUTA)
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
		else if (map && map.ID == MAP_TRIBES)
			spawn(5)
				if (original_job_title == "Orc tribesman")
					orc = 1
					civilization = "Orc Horde"
					add_language("Black Speech",TRUE)
					remove_language("English")
					for (var/datum/language/blackspeech/A in languages)
						default_language = A
					name = species.get_random_orc_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Ant tribesman")
					ant = 1
					civilization = "Ant Colony"
					add_language("Antspeak",TRUE)
					remove_language("English")
					for (var/datum/language/ant/A in languages)
						default_language = A
					name = species.get_random_ant_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Gorilla tribesman")
					gorillaman = 1
					civilization = "Gorilla Tribe"
					add_language("Ape Speech",TRUE)
					remove_language("English")
					for (var/datum/language/ape/A in languages)
						default_language = A
					name = species.get_random_gorilla_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Wolf tribesman")
					wolfman = 1
					civilization = "Wolfpack"
					add_language("Wolf Howling",TRUE)
					remove_language("English")
					for (var/datum/language/wolf/A in languages)
						default_language = A
					name = species.get_random_wolf_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Lizard tribesman")
					lizard = 1
					civilization = "Lizard Clan"
					add_language("Lizard Hissing",TRUE)
					remove_language("English")
					for (var/datum/language/lizard/A in languages)
						default_language = A
					name = species.get_random_lizard_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Crustacean tribesman")
					crab = 1
					civilization = "Crustacean Union"
					add_language("Clack Tongue",TRUE)
					remove_language("English")
					for (var/datum/language/crab/A in languages)
						default_language = A
					name = species.get_random_crab_name(gender)
					real_name = name
					give_clothes()
					return
				else
					civilization = "Human Kingdom"
					name = species.get_random_english_name(gender)
					real_name = name
					give_clothes()
		spawn(10)
			if (map.ID == MAP_NOMADS_CONTINENTAL || MAP_NOMADS_PANGEA)
				if (!isemptylist(whitelist_list) && config.use_job_whitelist && !client.prefs.be_random_name)
					var/found = FALSE
					for (var/i in whitelist_list)
						if (i == client.ckey)
							found = TRUE
					if (found)
						var/datum/language/currlg
						for (var/datum/language/A in languages)
							currlg = A
						var/input_msg = WWinput(src, "Welcome, [client.ckey]. You have spawned as a [currlg.name] speaker. Since you are whitelisted, you can customize your name. Do you want to?", "Custom Name", "No", list("Yes","No"))
						if (input_msg == "No")
							return
						else
							var/input_name = input(src, "Choose the new name: (Max 15 characters, please keep it language appropriate)","Custom Name", name) as text
							input_name = sanitizeName(input_name, 15, FALSE)
							if (input_name != "")
								name = input_name
								real_name = input_name
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
	H.make_nomad()

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
	H.make_nomad()

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
//////////////////////////////////////SPECIES/////////////////////////
/datum/job/civilian/fantasy

/datum/job/civilian/fantasy/orc
	title = "Orc tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND1"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/orc/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Orc Host"

	H.add_note("Role", "You are a <b>[title]</b>. You are stronger than the other races but somewhat limited in what to build and use.")
	H.add_note("Race Mechanics", "- Stronger than humans, good starting strength and average construction skills.<br>- Second most advanced after humans, but no gunpowder.<br>- Radioactive resistance, can't get cholera or food posioning from raw meat, no bad mood from raw meat, gore, or hygiene.<br>- Need to eat more often.")

	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("philosophy", STAT_NORMAL)


	return TRUE


/datum/job/civilian/fantasy/ant
	title = "Ant tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND2"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/ant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Ant Colony"

	H.add_note("Role", "You are a <b>[title]</b>. You have very high strength and crafting skills, and can dig much faster, but are very limited in what you can build.")
	H.add_note("Race Mechanics", "- Very good strength and dexterity, decent construction skills.<br>- Lowest technology of all races. Can't build walls besides dirt walls, can't build doors.<br>- Can dig holes, mine, and collect dirt/sand without tools use grab intent and click on a floor. To dig a hole, right click and use the Dig verb.<br>- Natural armoured skin gives some melee and radioactive defense.")

	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_LOW)



	return TRUE


/datum/job/civilian/fantasy/gorilla
	title = "Gorilla tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND3"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/gorilla/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Gorilla Tribe"

	H.add_note("Role", "You are a <b>[title]</b>. You are strong and nimble and can craft a wide range of things.")
	H.add_note("Race Mechanics", "- Very high strength, dexterity, and stamina. Good on unarmed fights.<br>- Can jump further than other races. <br>- Doesn't need to drink as often as other races, as they get water from their food.<br>- Since you are an herbivore, you cannot eat meat, eggs, and so on. You can use grab intent to collect and eat leaves from trees.")

	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_LOW)
	H.stats["stamina"][1] = 150
	H.stats["stamina"][2] = 150

	return TRUE

/datum/job/civilian/fantasy/human
	title = "Human tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND4"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/human/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Human Kingdom"

	H.add_note("Role", "You are a <b>[title]</b>. You have weak and soft pink skin but are very intelligent and can craft a wide range of things.")
	H.add_note("Race Mechanics", "- Advanced technology compared to all other races (can build crude gunpowder weapons like arquebuses)<br>- Good crafting and intelligence.<br>- The weakest race physically, compared to other races.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_MEDIUM_HIGH)


	return TRUE

/datum/job/civilian/fantasy/wolf
	title = "Wolf tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND4"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/wolf/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Wolfpack"

	H.add_note("Role", "You are a <b>[title]</b>. You are very nimble, strong and with a great sense of organization.")
	H.add_note("Race Mechanics", "- Fastest race and highest stamina. <br>- Can use howls to communicate with members far away.<br>- Poweful bite.<br>- Not attacked by wild wolves.<br>- Can only eat meat.")

	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_LOW)
	H.stats["stamina"][1] = 180
	H.stats["stamina"][2] = 180

	return TRUE

/datum/job/civilian/fantasy/lizard
	title = "Lizard tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND4"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/lizard/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Lizard Clan"

	H.add_note("Role", "You are a <b>[title]</b>. You have a poisonous bite and faster movement in rough terrain.")
	H.add_note("Race Mechanics", "- Not slowed down by rough terrain (mud, snow). <br>- Poisonous bite gives toxic damage. <br>- Not attacked by wild reptiles.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("philosophy", STAT_LOW)

	return TRUE

/datum/job/civilian/fantasy/crab
	title = "Crustacean tribesman"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateIND4"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/crab/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Crustacean Union"

	H.add_note("Role", "You are a <b>[title]</b>. You have a very hard shell and strong claws, but need water to survive.")
	H.add_note("Race Mechanics", "- Natural armoured skin gives good melee and radioactive defense.<br>- Cannot wear shoes or gloves.<br>- Can only eat meat (including rotten, doesn't get food poisoning).<br>- No movement delay on water or sand.")

	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("philosophy", STAT_LOW)

	return TRUE