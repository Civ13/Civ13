/mob/living/human/proc/nomads_spawn()
	var/list/possible_h_list = list("Black")
	var/list/possible_e_list = list("Black")
	var/list/possible_s_range = list(-10,-60)
	var/area/mob_area = get_area(src)
	if (map && map.is_zombie)
		add_note("Map Mechanics", "- Zombies will spawn in some areas <b>at night</b>.<br><br>- Bodies will turn into zombies after a while! To prevent this, <b>remove the head from the body</b>.<br><br>- Getting bit or scratched by a zombie will not automatically turn you into one. There is a small chance you get <b>infected with the zombie virus</b> from every strike a zombie lands on you. You will get high fevers, massive headaches, and eventually succumb to the disease; turning into a zombie. This can be cured by taking <b>Potassium Iodide</b>, which will kill the virus, even after symptoms have started.")

	if (map && (map.is_fantrace))
		var/newnamera = list("Order of the Great Tree" = list(null,"Knowledge",0, "Tree","#098518","#9A9A9A","Shamans")) //gorillas
		var/newnamerb = list("The Great Serpent" = list(null,"Combat",0, "Skull","#654321","#014421","Shamans")) //lizards
		var/newnamerc = list("Father in the Sky" = list(null,"Production",0, "Cross","#FFD700","#FFFFFF","Priests")) //hoo-mans
		var/newnamerd = list("Followers of Morgoth" = list(null,"Combat",0, "Skull","#000000","#9A1313","Cultists")) //orcs
		var/newnamere = list("Followers of the Hive Mother" = list(null,"Knowledge",0, "Star","#67A7CE","#0C1EA7","Monks")) //ants
		var/newnamerf = list("Moon Worshippers" = list(null,"Combat",0, "Moon","#848484","#FFFFFF","Priests")) //wolves
		var/newnamerg = list("Cthulhu" = list(null,"Production",0, "Sun","#ADFF2F","#000000","Cultists")) //crustaceans
		map.custom_religions += newnamera
		map.custom_religions += newnamerb
		map.custom_religions += newnamerc
		map.custom_religions += newnamerd
		map.custom_religions += newnamere
		map.custom_religions += newnamerf
		map.custom_religions += newnamerg
		var/choices = WWinput(src, "Welcome to the Forgotten Time! As your new life starts you can choose if you want to customize your character. Do you want to?","Character Customization","Randomize",list(/*"Biome Appropriate",*/"Randomize","Customize"))
		if (choices == "Customize")
			var/choice_race = WWinput(src, "Which race do you want to be?","Character Customization","Randomize",list("Randomize","Human","Ant","Lizard","Crustacean","Orc","Gorilla","Wolf"))
			if (choice_race == "Randomize")
				choice_race = pick("Human","Ant","Lizard","Crustacean","Orc","Gorilla","Wolf")
			switch(choice_race)

				if ("Gorilla")
					gorillaman = 1
					religion = "Order of the Great Tree"
					add_language("Ape Speech",TRUE)
					for (var/datum/language/ape/A in languages)
						default_language = A
					name = species.get_random_gorilla_name(gender)
					real_name = name
					give_clothes()

				if ("Orc")
					orc = 1
					religion = "Followers of Morgoth"
					add_language("Black Speech",TRUE)
					for (var/datum/language/blackspeech/A in languages)
						default_language = A
					name = species.get_random_orc_name(gender)
					real_name = name
					give_clothes()

				if ("Ant")
					ant = 1
					religion = "Followers of the Hive Mother"
					add_language("Antspeak",TRUE)
					for (var/datum/language/ant/A in languages)
						default_language = A
					name = species.get_random_ant_name(gender)
					real_name = name
					give_clothes()

				if ("Lizard")
					lizard = 1
					religion = "The Great Serpent"
					add_language("Lizard Hissing",TRUE)
					for (var/datum/language/lizard/A in languages)
						default_language = A
					name = species.get_random_lizard_name(gender)
					real_name = name
					give_clothes()

				if ("Wolf")
					wolfman = 1
					religion = "Moon Worshippers"
					add_language("Wolf Howling",TRUE)
					for (var/datum/language/wolf/A in languages)
						default_language = A
					name = species.get_random_wolf_name(gender)
					real_name = name
					give_clothes()

				if ("Crustacean")
					crab = 1
					religion = "Cthulhu"
					add_language("Clack Tongue",TRUE)
					for (var/datum/language/crab/A in languages)
						default_language = A
					name = species.get_random_crab_name(gender)
					real_name = name
					give_clothes()

			var/choice1 = "English"
			if (choice_race == "Human")
				religion = "Father in the Sky"
				name = species.get_random_english_name(gender)
				real_name = name
				give_clothes()
				choice1 = "English"
				//choice1 = WWinput(src, "Which ethnicity do you want to be?","Character Customization","Randomize",list("Randomize","Russian","Zulu","Arabic",/*"Japanese","Chinese","Portuguese","Arabic",*/"Latin"))
			if (choice1 == "Randomize")
				choice1 = pick("Russian","Zulu","Arabic",/*"Japanese","Chinese","Portuguese","Arabic",*/"Latin")
			else
				switch(choice1)
					if ("Russian")
						add_language("Russian",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						add_note("Known Languages", "Russian")
						possible_h_list = list("Red","Orange","Light Blond","Blond","Dirty Blond")
						possible_e_list = list("Blue","Green")
						possible_s_range = list(-10,-28)
					if ("German")
						add_language("German",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/german/A in languages)
							default_language = A
						name = species.get_random_german_name(gender)
						real_name = name
						add_note("Known Languages", "German")
						possible_h_list = list("Light Brown","Blond","Dirty Blond")
						possible_e_list = list("Blue","Green")
						possible_s_range = list(-15,-30)
					if ("English")
						possible_h_list = list("Dark Brown","Light Brown","Dirty Blond")
						possible_e_list = list("Blue","Green","Brown")
						possible_s_range = list(-25,-38)
					if ("Japanese")
						add_language("Japanese",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/japanese/A in languages)
							default_language = A
						name = species.get_random_japanese_name(gender)
						real_name = name
						add_note("Known Languages", "Japanese")
						possible_h_list = list("Dark Brown","Black")
						possible_e_list = list("Brown","Black")
						possible_s_range = list(-15,-25)
					if ("Chinese")
						add_language("Chinese",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/chinese/A in languages)
							default_language = A
						name = species.get_random_chinese_name(gender)
						real_name = name
						add_note("Known Languages", "Chinese")
						possible_h_list = list("Dark Brown","Black")
						possible_e_list = list("Brown","Black")
						possible_s_range = list(-15,-25)
					if ("Zulu")
						add_language("Zulu",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/zulu/A in languages)
							default_language = A
						name = species.get_random_zulu_name(gender)
						real_name = name
						add_note("Known Languages", "Zulu")
						possible_h_list = list("Black")
						possible_e_list = list("Black")
						possible_s_range = list(-165,-195)
					if ("Arabic")
						add_language("Arabic",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/arab/A in languages)
							default_language = A
						name = species.get_random_arab_name(gender)
						real_name = name
						add_note("Known Languages", "Arabic")
						possible_h_list = list("Dark Brown","Black")
						possible_e_list = list("Black")
						possible_s_range = list(-85,-110)
					if ("Hebrew")
						add_language("Hebrew",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/hebrew/A in languages)
							default_language = A
						name = species.get_random_hebrew_name(gender)
						real_name = name
						add_note("Known Languages", "Hebrew")
						possible_h_list = list("Dark Brown","Black")
						possible_e_list = list("Brown","Black")
						possible_s_range = list(-75,-100)
					if ("Latin")
						add_language("Latin",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/latin/A in languages)
							default_language = A
						name = species.get_random_roman_name(gender)
						real_name = name
						add_note("Known Languages", "Latin")
						possible_h_list = list("Light Brown","Dark Brown")
						possible_e_list = list("Green","Brown","Black")
						possible_s_range = list(-45,-65)
					if ("Portuguese")
						add_language("Portuguese",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/portuguese/A in languages)
							default_language = A
						name = species.get_random_portuguese_name(gender)
						real_name = name
						add_note("Known Languages", "Portuguese")
						possible_h_list = list("Light Brown","Dark Brown")
						possible_e_list = list("Green","Brown")
						possible_s_range = list(-40,-58)
					if ("Greek")
						add_language("Greek",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/greek/A in languages)
							default_language = A
						name = species.get_random_greek_name(gender)
						real_name = name
						add_note("Known Languages", "Greek")
						possible_h_list = list("Light Brown","Dark Brown","Black")
						possible_e_list = list("Brown","Black")
						possible_s_range = list(-50,-70)

				possible_h_list += "Randomize"
				possible_e_list += "Randomize"
				var/custom_new_hair = WWinput(src, "Choose the hair color:","Character Customization","Randomize",possible_h_list)
				if (custom_new_hair == "Randomize")
					possible_h_list -= "Randomize"
				var/custom_new_eyes = WWinput(src, "Choose the eye color:","Character Customization","Randomize",possible_e_list)
				if (custom_new_eyes == "Randomize")
					possible_e_list -= "Randomize"
				var/custom_s_tone = input(src, "Choose the skin tone ([abs(possible_s_range[1])] to [abs(possible_s_range[2])]):","Character Customization") as num
				if (custom_s_tone > abs(possible_s_range[2]))
					custom_s_tone = abs(possible_s_range[2])
				else if (s_tone < abs(possible_s_range[1]))
					custom_s_tone = abs(possible_s_range[1])
				s_tone = -(custom_s_tone)
				var/list/sec_lang_list = list("Randomize","Russian","Zulu","Arabic","Latin")
				sec_lang_list -= choice1
				var/sec_lang = WWinput(src, "Choose your secondary language:","Character Customization","Randomize",sec_lang_list)
				if (sec_lang == "Randomize")
					sec_lang_list -= "Randomize"
					sec_lang = pick(sec_lang_list)
				add_language(sec_lang,TRUE)
				add_note("Known Languages", sec_lang)
		else if (choices == "Biome Appropriate")
			switch (mob_area.climate)
				if ("tundra","taiga")
					if (prob(50))
						add_language("Russian",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						add_note("Known Languages", "Russian")
						possible_h_list = list("Red","Orange","Light Blond","Blond","Dirty Blond")
						possible_e_list = list("Blue","Green")
						possible_s_range = list(10,28)
						choices = "Russian"
					else
						add_language("German",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/german/A in languages)
							default_language = A
						name = species.get_random_german_name(gender)
						real_name = name
						add_note("Known Languages", "German")
						possible_h_list = list("Light Brown","Blond","Dirty Blond")
						possible_e_list = list("Blue","Green")
						possible_s_range = list(15,30)
						choices = "German"
				if ("temperate")
					if (prob(50))
						add_language("Latin",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/latin/A in languages)
							default_language = A
						name = species.get_random_roman_name(gender)
						real_name = name
						add_note("Known Languages", "Latin")
						possible_h_list = list("Light Brown","Dark Brown")
						possible_e_list = list("Green","Brown","Black")
						possible_s_range = list(45,65)
						choices = "Latin"
					else
						add_language("Greek",TRUE)
						remove_language("English")
						remove_note("Known Languages","English")
						for (var/datum/language/greek/A in languages)
							default_language = A
						name = species.get_random_greek_name(gender)
						real_name = name
						add_note("Known Languages", "Greek")
						possible_h_list = list("Light Brown","Dark Brown","Black")
						possible_e_list = list("Brown","Black")
						possible_s_range = list(50,70)
						choices = "Greek"

			var/list/sec_lang_list = list("Russian","Arabic","Zulu","Latin")
			sec_lang_list -= choices
			var/sec_lang = pick(sec_lang_list)
			add_language(sec_lang,FALSE)
			add_note("Known Languages", sec_lang)

		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

///////////////////////////////////////////////////////////////////
/////////////////////////Karafuta-Sakhalinsk///////////////////////
///////////////////////////////////////////////////////////////////
	else if (map && (map.ID == MAP_NOMADS_KARAFUTO))
		switch (mob_area.climate)
			if ("tundra")
				if (y>420)
					add_language("Russian",TRUE)
					remove_language("English")
					remove_note("Known Languages","English")
					for (var/datum/language/russian/A in languages)
						default_language = A
					name = species.get_random_russian_name(gender)
					real_name = name
					add_note("Known Languages", "Russian")
					possible_h_list = list("Light Blond","Blond","Dirty Blond")
					possible_e_list = list("Blue","Green")
					possible_s_range = list(15,28)
					give_languages()
				else if ("temperate" && y<420)
					add_language("Ainu",TRUE)
					remove_language("English")
					remove_note("Known Languages","English")
					for (var/datum/language/ainu/A in languages)
						default_language = A
					name = species.get_random_ainu_name(gender)
					real_name = name
					add_note("Known Languages", "Ainu")
					possible_h_list = list("Dark Brown","Black")
					possible_e_list = list("Brown","Black")
					possible_s_range = list(35,45)
					give_languages()
			else
				if ("temperate" && y<100)
					add_language("Japanese",TRUE)
					remove_language("Japanese")
					remove_note("Known Languages","Japanese")
					for (var/datum/language/japanese/A in languages)
						default_language = A
					name = species.get_random_japanese_name(gender)
					real_name = name
					add_note("Known Languages", "Japanese")
					possible_h_list = list("Dark Brown","Black")
					possible_e_list = list("Brown","Black")
					possible_s_range = list(25,35)
					give_languages()
				else if (y>100)
					add_language("Ainu",TRUE)
					remove_language("Ainu")
					remove_note("Known Languages","Ainu")
					for (var/datum/language/ainu/A in languages)
						default_language = A
					name = species.get_random_ainu_name(gender)
					real_name = name
					add_note("Known Languages", "Ainu")
					possible_h_list = list("Dark Brown","Black")
					possible_e_list = list("Brown","Black")
					possible_s_range = list(35,45)
					give_languages()
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map && (map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA))
		switch (mob_area.climate)
			if ("tundra","taiga")
				add_language("Old Norse",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/oldnorse/A in languages)
					default_language = A
				name = species.get_random_oldnorse_name(gender)
				real_name = name
				add_note("Known Languages", "Old Norse")
				possible_h_list = list("Dirty Blond","Light Brown","Dark Brown")
				possible_e_list = list("Blue","Green","Brown")
				possible_s_range = list(-25,-45)
			if ("temperate")
				add_language("Latin",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/latin/A in languages)
					default_language = A
				name = species.get_random_roman_name(gender)
				real_name = name
				add_note("Known Languages", "Latin")
				possible_h_list = list("Light Brown","Dark Brown")
				possible_e_list = list("Green","Brown","Black")
				possible_s_range = list(-40,-60)
			if ("semiarid","sea")
				add_language("Latin",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/latin/A in languages)
					default_language = A
				name = species.get_random_roman_name(gender)
				real_name = name
				add_note("Known Languages", "Latin")
				possible_h_list = list("Light Brown","Dark Brown")
				possible_e_list = list("Green","Brown","Black")
				possible_s_range = list(-40,-60)
			if ("desert")
				add_language("Egyptian",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/egyptian/A in languages)
					default_language = A
				name = species.get_random_egyptian_name(gender)
				real_name = name
				add_note("Known Languages", "Egyptian")
				possible_h_list = list("Dark Brown","Black")
				possible_e_list = list("Brown","Black")
				possible_s_range = list(-25,-35)
			if ("savanna","jungle")
				add_language("Japanese",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/japanese/A in languages)
					default_language = A
				name = species.get_random_japanese_name(gender)
				real_name = name
				add_note("Known Languages", "Japanese")
				possible_h_list = list("Dark Brown","Black")
				possible_e_list = list("Brown","Black")
				possible_s_range = list(-15,-25)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NOMADS_EUROPE)
		switch (mob_area.climate)
			if ("tundra","taiga")
				add_language("Old Norse",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/oldnorse/A in languages)
					default_language = A
				name = species.get_random_oldnorse_name(gender)
				real_name = name
				add_note("Known Languages", "Old Norse")
				possible_h_list = list("Light Blond","Blond","Dirty Blond")
				possible_e_list = list("Blue","Green","Red")
				possible_s_range = list(-10,-28)
			if ("temperate")
				add_language("Gaelic",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/gaelic/A in languages)
					default_language = A
				name = species.get_random_gaelic_name(gender)
				real_name = name
				add_note("Known Languages", "Gaelic")
				possible_h_list = list("Orange","Light Brown","Red","Brown")
				possible_e_list = list("Brown","Green")
				possible_s_range = list(-15,-30)
			if ("sea")
				add_language("Cherokee",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/cherokee/A in languages)
					default_language = A
				name = species.get_random_cherokee_name(gender)
				real_name = name
				add_note("Known Languages", "Cherokee")
				possible_h_list = list("Brown","Black")
				possible_e_list = list("Brown")
				possible_s_range = list(-49,-56)
			if ("semiarid","desert")
				add_language("Latin",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/latin/A in languages)
					default_language = A
				name = species.get_random_roman_name(gender)
				real_name = name
				add_note("Known Languages", "Latin")
				possible_h_list = list("Light Brown","Dark Brown")
				possible_e_list = list("Green","Brown","Black")
				possible_s_range = list(-45,-65)

		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NOMADS_UK || map.ID == MAP_NOMADS_OCEANIA)
		switch (mob_area.climate)
			if ("temperate")
				for (var/datum/language/english/A in languages)
					default_language = A
				name = species.get_random_english_name(gender)
				real_name = name
				add_note("Known Languages", "English")
				possible_h_list = list("Light Brown","Dark Brown","Black", "Blond")
				possible_e_list = list("Brown","Green","Blue")
				possible_s_range = list(-15,-30)

			if ("savanna")
				add_language("Gaelic",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/gaelic/A in languages)
					default_language = A
				name = species.get_random_gaelic_name(gender)
				real_name = name
				add_note("Known Languages", "Gaelic")
				possible_h_list = list("Orange","Light Brown","Red","Dark Brown")
				possible_e_list = list("Brown","Green", "Blue")
				possible_s_range = list(-15,-30)

			if ("taiga")
				add_language("Scottish Gaelic",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/scottishgaelic/A in languages)
					default_language = A
				name = species.get_random_scottishgaelic_name(gender)
				real_name = name
				add_note("Known Languages", "Scottish gaelic")
				possible_h_list = list("Orange","Light Brown","Red","Dark brown")
				possible_e_list = list("Brown","Green", "Blue")
				possible_s_range = list(-15,-30)

			if ("sea")
				add_language("Welsh",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/welsh/A in languages)
					default_language = A
				name = species.get_random_welsh_name(gender)
				real_name = name
				add_note("Known Languages", "Welsh")
				possible_h_list = list("Light Brown","Dark brown","Black")
				possible_e_list = list("Brown","Green")
				possible_s_range = list(-15,-30)

			if ("semiarid")
				add_language("Scots",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/scots/A in languages)
					default_language = A
				name = species.get_random_scots_name(gender)
				real_name = name
				add_note("Known Languages","Scots")
				possible_h_list = list("Orange","Light Brown","Red","Brown")
				possible_e_list = list("Brown","Green")
				possible_s_range = list(-15,-30)

		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NOMADS_NORTH_AMERICA)
		switch(y)
			if (1 to 120) // SOUTH
				if (map.ordinal_age >= 3 && prob(70))
					add_language("Spanish",TRUE)
					remove_language("English")
					remove_note("Known Languages","English")
					for (var/datum/language/spanish/A in languages)
						default_language = A
					name = species.get_random_spanish_name(gender)
					real_name = name
					add_note("Known Languages", "Spanish")
					possible_h_list = list("Black","Dark Brown","Light Brown")
					possible_e_list = list("Brown","Black")
					possible_s_range = list(-40,-90)
				else
					switch(x)
						if (1 to 90)
							add_language("Hawaiian",TRUE)
							remove_language("English")
							remove_note("Known Languages","English")
							for (var/datum/language/hawaiian/A in languages)
								default_language = A
							name = species.get_random_hawaiian_name(gender)
							real_name = name
							add_note("Known Languages", "Hawaiian")
							possible_h_list = list("Black","Dark Brown")
							possible_e_list = list("Brown","Black")
							possible_s_range = list(-90,-115)
						if (328 to 450)
							add_language("Carib",TRUE)
							remove_language("English")
							remove_note("Known Languages","English")
							for (var/datum/language/carib/A in languages)
								default_language = A
							name = species.get_random_carib_name(gender)
							real_name = name
							add_note("Known Languages", "Carib")
							possible_h_list = list("Black","Dark Brown")
							possible_e_list = list("Brown","Black")
							possible_s_range = list(-80,-115)
						else
							if (mob_area.climate == "semiarid")
								add_language("Aztec",TRUE)
								remove_language("English")
								remove_note("Known Languages","English")
								for (var/datum/language/aztec/A in languages)
									default_language = A
								name = species.get_random_aztec_name(gender)
								real_name = name
								add_note("Known Languages", "Aztec (Nahuatl)")
								possible_h_list = list("Black","Dark Brown")
								possible_e_list = list("Brown","Black")
								possible_s_range = list(-80,-115)
							else
								add_language("Mayan",TRUE)
								remove_language("English")
								remove_note("Known Languages","English")
								for (var/datum/language/mayan/A in languages)
									default_language = A
								name = species.get_random_mayan_name(gender)
								real_name = name
								add_note("Known Languages", "Mayan")
								possible_h_list = list("Black","Dark Brown")
								possible_e_list = list("Brown","Black")
								possible_s_range = list(-80,-115)
			if (121 to 300)
				if (mob_area.climate == "tundra")
					add_language("Inuit",TRUE)
					remove_language("English")
					remove_note("Known Languages","English")
					for (var/datum/language/inuit/A in languages)
						default_language = A
					name = species.get_random_inuit_name(gender)
					real_name = name
					add_note("Known Languages", "Inuit")
					possible_h_list = list("Black","Dark Brown","Light Brown")
					possible_e_list = list("Brown","Black")
					possible_s_range = list(-40,-90)
				else
					if (map.ordinal_age >= 3 && prob(70))
						for (var/datum/language/english/A in languages)
							default_language = A
						name = species.get_random_english_name(gender)
						real_name = name
						add_note("Known Languages", "English")
						possible_h_list = list("Light Brown","Dark Brown","Blond", "Red", "Orange")
						possible_e_list = list("Brown","Green","Blue")
						possible_s_range = list(-15,-30)
					else
						switch(x)
							if (100 to 200)
								if (mob_area.climate == "desert")
									add_language("Navajo",TRUE)
									remove_language("English")
									remove_note("Known Languages","English")
									for (var/datum/language/navajo/A in languages)
										default_language = A
									name = species.get_random_navajo_name(gender)
									real_name = name
									add_note("Known Languages", "Navajo")
									possible_h_list = list("Black","Dark Brown","Light Brown")
									possible_e_list = list("Brown","Black")
									possible_s_range = list(-40,-90)
								else
									add_language("Chinook",TRUE)
									remove_language("English")
									remove_note("Known Languages","English")
									for (var/datum/language/chinook/A in languages)
										default_language = A
									name = species.get_random_chinook_name(gender)
									real_name = name
									add_note("Known Languages", "Chinook")
									possible_h_list = list("Black","Dark Brown","Light Brown")
									possible_e_list = list("Brown","Black")
									possible_s_range = list(-40,-90)
							if (201 to 310)
								if (y < 165)
									add_language("Comanche",TRUE)
									remove_language("English")
									remove_note("Known Languages","English")
									for (var/datum/language/comanche/A in languages)
										default_language = A
									name = species.get_random_comanche_name(gender)
									real_name = name
									add_note("Known Languages", "Comanche")
									possible_h_list = list("Black","Dark Brown","Light Brown")
									possible_e_list = list("Brown","Black")
									possible_s_range = list(-40,-90)
								else
									add_language("Sioux",TRUE)
									remove_language("English")
									remove_note("Known Languages","English")
									for (var/datum/language/sioux/A in languages)
										default_language = A
									name = species.get_random_sioux_name(gender)
									real_name = name
									add_note("Known Languages", "Sioux")
									possible_h_list = list("Black","Dark Brown","Light Brown")
									possible_e_list = list("Brown","Black")
									possible_s_range = list(-40,-90)
							if (311 to 450)
								if (y < 150)
									add_language("Cherokee",TRUE)
									remove_language("English")
									remove_note("Known Languages","English")
									for (var/datum/language/cherokee/A in languages)
										default_language = A
									name = species.get_random_cherokee_name(gender)
									real_name = name
									add_note("Known Languages", "Cherokee")
									possible_h_list = list("Black","Dark Brown","Light Brown")
									possible_e_list = list("Brown","Black")
									possible_s_range = list(-40,-90)
								else
									add_language("Iroquois",TRUE)
									remove_language("English")
									remove_note("Known Languages","English")
									for (var/datum/language/iroquois/A in languages)
										default_language = A
									name = species.get_random_iroquois_name(gender)
									real_name = name
									add_note("Known Languages", "Iroquois")
									possible_h_list = list("Black","Dark Brown","Light Brown")
									possible_e_list = list("Brown","Black")
									possible_s_range = list(-40,-90)

		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NOMADS_MEDITERRANEAN)
		if (y<100) //SOUTH
			if (x<100) 			//SOUTH-WEST
				add_language("Arabic",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/spanish/A in languages)
					default_language = A
				name = species.get_random_spanish_name(gender)
				real_name = name
				add_note("Known Languages", "Spanish")
				possible_h_list = list("Light Brown","Dark Brown")
				possible_e_list = list("Green","Brown","Black")
				possible_s_range = list(-35,-60)
			else 				//SOUTH-EAST
				add_language("Latin",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/latin/A in languages)
					default_language = A
				name = species.get_random_roman_name(gender)
				real_name = name
				add_note("Known Languages", "Latin")
				possible_h_list = list("Light Brown","Dark Brown")
				possible_e_list = list("Green","Brown","Black")
				possible_s_range = list(-35,-60)
		else
			if (x<100)	//NORTH-WEST
				add_language("French",TRUE)
				remove_language("English")
				remove_note("Known Languages","French")
				for (var/datum/language/french/A in languages)
					default_language = A
				name = species.get_random_french_name(gender)
				real_name = name
				add_note("Known Languages", "French")
				possible_h_list = list("Light Brown")
				possible_e_list = list("Blue","Green","Brown")
				possible_s_range = list(-20,-45)
			else	//NORTH-EAST
				add_language("German",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/german/A in languages)
					default_language = A
				name = species.get_random_german_name(gender)
				real_name = name
				add_note("Known Languages", "German")
				possible_h_list = list("Light Brown","Blond","Dirty Blond")
				possible_e_list = list("Blue","Green")
				possible_s_range = list(-15,-30)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NOMADS_DIVIDE)
		//WEST (JUNGLE)
		if (x<125)
			add_language("Zulu",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/zulu/A in languages)
				default_language = A
			name = species.get_random_zulu_name(gender)
			real_name = name
			add_note("Known Languages", "Zulu")
			possible_h_list = list("Black")
			possible_e_list = list("Brown")
			possible_s_range = list(-175,-200)
		//EAST (DESERT)
		else
			add_language("Arabic",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/arab/A in languages)
				default_language = A
			name = species.get_random_arab_name(gender)
			real_name = name
			add_note("Known Languages", "Arabic")
			possible_h_list = list("Dark Brown","Black")
			possible_e_list = list("Black")
			possible_s_range = list(-85,-110)

		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NOMADS_AFRICA)
		switch (mob_area.climate)
			if ("jungle","savanna")
				add_language("Swahili",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/swahili/A in languages)
					default_language = A
				name = species.get_random_swahili_name(gender)
				real_name = name
				add_note("Known Languages", "Swahili")
				possible_h_list = list("Black")
				possible_e_list = list("Brown")
				possible_s_range = list(-145,-175)
			if ("temperate")
				add_language("Zulu",TRUE)
				remove_language("English")
				remove_note("Known Languages","Zulu")
				for (var/datum/language/zulu/A in languages)
					default_language = A
				name = species.get_random_zulu_name(gender)
				real_name = name
				add_note("Known Languages", "Zulu")
				possible_h_list = list("Black")
				possible_e_list = list("Black")
				possible_s_range = list(-145,-174)
			if ("desert")
				add_language("Egyptian",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/cherokee/A in languages)
					default_language = A
				name = species.get_random_cherokee_name(gender)
				real_name = name
				add_note("Known Languages", "Egyptian")
				possible_h_list = list("Dark Brown","Black")
				possible_e_list = list("Brown","Black")
				possible_s_range = list(-85,-110)
			if ("semiarid","sea")
				add_language("Arabic",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/arab/A in languages)
					default_language = A
				name = species.get_random_arab_name(gender)
				real_name = name
				add_note("Known Languages", "Arabic")
				possible_h_list = list("Dark Brown","Black")
				possible_e_list = list("Black")
				possible_s_range = list(-85,-110)

		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NOMADS_ASIA)
		switch (mob_area.climate)
			if ("temperate", "semiarid")
				add_language("Chinese",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/chinese/A in languages)
					default_language = A
				name = species.get_random_chinese_name(gender)
				real_name = name
				add_note("Known Languages", "Chinese")
				possible_h_list = list("Dark Brown","Black")
				possible_e_list = list("Brown","Black")
				possible_s_range = list(-15,-25)
			if ("tundra")
				add_language("Mongolian",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/mongolian/A in languages)
					default_language = A
				name = species.get_random_mongolian_name(gender)
				real_name = name
				add_note("Known Languages", "Mongolian")
				possible_h_list = list("Black", "Dark Brown","Light Brown","Red")
				possible_e_list = list("Black","Brown","Green")
				possible_s_range = list(-25,-60)
			if ("desert")
				add_language("Farsi",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/farsi/A in languages)
					default_language = A
				name = species.get_random_arab_name(gender)
				real_name = name
				add_note("Known Languages", "Farsi")
				possible_h_list = list("Black","Light Brown","Dark Brown")
				possible_e_list = list("Green","Brown","Black")
				possible_s_range = list(-35,-80)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_PEPELSIBIRSK)
		var/randpick = rand(1,100)
		switch(randpick)
			if (1 to 10)
				add_language("Polish",TRUE)
				add_language("Russian",TRUE)
				add_note("Known Languages", "Polish", "Russian")
				remove_language("English")
				remove_note("Known Languages","English")
				name = species.get_random_polish_name(gender)
				real_name = name
				for (var/datum/language/polish/A in languages)
					default_language = A
				src.nationality = "Polish"
				possible_h_list = list("Black", "Dark Brown","Light Brown","Red")
				possible_e_list = list("Black","Brown","Green")
				possible_s_range = list(-25,-60)
				give_languages()
			if (11 to 70)
				add_language("Russian",TRUE)
				add_note("Known Languages", "Russian")
				remove_language("English")
				remove_note("Known Languages","English")
				name = species.get_random_russian_name(gender)
				real_name = name
				for (var/datum/language/russian/A in languages)
					default_language = A
				src.nationality = "Russian"
				possible_h_list = list("Black", "Dark Brown","Light Brown","Red")
				possible_e_list = list("Black","Brown","Green")
				possible_s_range = list(-25,-60)
				give_languages()
			if (71 to 80)
				add_language("Russian",TRUE)
				add_language("German",TRUE)
				add_note("Known Languages", "German", "Russian")
				remove_language("English")
				remove_note("Known Languages","English")
				name = species.get_random_german_name(gender)
				real_name = name
				for (var/datum/language/german/A in languages)
					default_language = A
				src.nationality = "German"
				possible_h_list = list("Light Brown","Blond","Dirty Blond")
				possible_e_list = list("Blue","Green")
				possible_s_range = list(-15,-30)
				give_languages()
			if (81 to 100)
				add_language("Russian",TRUE)
				add_language("Ukrainian",TRUE)
				add_note("Known Languages", "Ukrainian", "Russian")
				remove_language("English")
				remove_note("Known Languages","English")
				name = species.get_random_ukrainian_name(gender)
				real_name = name
				src.nationality = "Ukrainian"
				for (var/datum/language/ukrainian/A in languages)
					default_language = A
				possible_h_list = list("Black", "Dark Brown","Light Brown","Red")
				possible_e_list = list("Black","Brown","Green")
				possible_s_range = list(-25,-60)
				give_languages()
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NATIONSRP)
		//west
		if (original_job_title == "Civilization A Citizen")
			add_language("Latin",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/latin/A in languages)
				default_language = A
			name = species.get_random_roman_name(gender)
			real_name = name
			add_note("Known Languages", "Latin")
			possible_h_list = list("Light Brown","Dark Brown","Black","Brown")
			possible_e_list = list("Green","Brown","Black")
			possible_s_range = list(-35,-60)
		//east
		else if (original_job_title == "Civilization B Citizen")
			add_language("Gaelic",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/gaelic/A in languages)
				default_language = A
			name = species.get_random_gaelic_name(gender)
			real_name = name
			add_note("Known Languages", "Gaelic")
			possible_h_list = list("Orange","Light Brown","Red","Brown")
			possible_e_list = list("Green","Blue")
			possible_s_range = list(-15,-30)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NATIONSRP_TRIPLE)
		//west
		if (original_job_title == "Civilization A Citizen")
			for (var/datum/language/english/A in languages)
				default_language = A
			name = species.get_random_english_name(gender)
			real_name = name
			possible_h_list = list("Orange","Light Brown","Red","Brown")
			possible_e_list = list("Green","Blue","Brown")
			possible_s_range = list(-15,-30)
		//east
		else if (original_job_title == "Civilization B Citizen")
			add_language("French",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/french/A in languages)
				default_language = A
			name = species.get_random_french_name(gender)
			real_name = name
			add_note("Known Languages", "French")
			possible_h_list = list("Light Brown","Dark Brown","Black","Brown")
			possible_e_list = list("Green","Brown","Black","Blue")
			possible_s_range = list(-15,-30)
		else if (original_job_title == "Civilization C Citizen")
			add_language("German",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/german/A in languages)
				default_language = A
			name = species.get_random_german_name(gender)
			real_name = name
			add_note("Known Languages", "German")
			possible_h_list = list("Light Brown","Blond","Dirty Blond")
			possible_e_list = list("Blue","Green")
			possible_s_range = list(-15,-30)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NATIONSRPMED)
		//west
		if(original_job_title == "Civilization A Citizen")
			add_language("Greek",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/greek/A in languages)
				default_language = A
			name = species.get_random_greek_name(gender)
			real_name = name
			add_note("Known Languages", "Greek")
			possible_h_list = list("Light Brown","Dark Brown")
			possible_e_list = list("Green","Brown","Black")
			possible_s_range = list(-45,-65)
		//east
		else if(original_job_title == "Civilization B Citizen")
			add_language("Arabic",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/arab/A in languages)
				default_language = A
			name = species.get_random_arab_name(gender)
			real_name = name
			add_note("Known Languages", "Arabic")
			possible_h_list = list("Dark Brown","Black")
			possible_e_list = list("Black")
			possible_s_range = list(-85,-110)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NATIONSRP_WW2)
		//east Russian
		if (original_job_title == "Civilization A Citizen")
			add_language("Russian",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/russian/A in languages)
				default_language = A
			name = species.get_random_russian_name(gender)
			real_name = name
			add_note("Known Languages", "Russian")
			possible_h_list = list("Red","Orange","Light Blond","Blond","Dirty Blond")
			possible_e_list = list("Blue","Green")
			possible_s_range = list(-10,-28)
		//west German
		else if (original_job_title == "Civilization B Citizen")
			add_language("German",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/german/A in languages)
				default_language = A
			name = species.get_random_german_name(gender)
			real_name = name
			add_note("Known Languages", "German")
			possible_h_list = list("Light Brown","Blond","Dirty Blond")
			possible_e_list = list("Blue","Green")
			possible_s_range = list(-15,-30)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if (map.ID == MAP_NATIONSRP_COLDWAR)
		//west American
		if (original_job_title == "Civilization A Citizen")
			add_language("English",TRUE)
			for (var/datum/language/english/A in languages)
				default_language = A
			add_note("Known Languages", "English")
			if(prob(80))
				name = species.get_random_english_name(gender)
				possible_h_list = list("Dark Brown","Light Brown","Dirty Blond","Black","Red","Orange")
				possible_e_list = list("Blue","Green","Brown","Black")
				possible_s_range = list(-25,-55)
			else
				name = species.get_random_afro_american_name(gender)
				possible_h_list = list("Black")
				possible_e_list = list("Black")
				possible_s_range = list(-110,-160)
				h_style = pick("Buzzcut", "Buzzcut Alt", "Crewcut", "Afro", "Father", "Afro 2", "Flat Top", "Skinhead", "Trimmed", "High Tight", "High Fade", "Low Fade", "Medium Fade", "Average Joe")
			real_name = name
		//east Russian
		else if (original_job_title == "Civilization B Citizen")
			add_language("Russian",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/russian/A in languages)
				default_language = A
			name = species.get_random_russian_name(gender)
			real_name = name
			add_note("Known Languages", "Russian")
			possible_h_list = list("Red","Orange","Light Blond","Blond","Dirty Blond")
			possible_e_list = list("Blue","Green")
			possible_s_range = list(-10,-30)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)

	else if ( map.ID == MAP_NATIONSRP_COLDWAR_CMP)
		//west Redmenian
		if (original_job_title == "Redmenian Civilian")
			add_language("Redmenian",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/redmenian/A in languages)
				default_language = A
			name = species.get_random_english_name(gender)
			real_name = name
			add_note("Known Languages", "Redmenian")
			possible_h_list = list("Light Brown","Dark Brown","Black","Brown")
			possible_e_list = list("Green","Brown","Blue")
			possible_s_range = list(-15,-30)
		//east Blugoslavian
		else if (original_job_title == "Blugoslavian Civilian")
			add_language("Blugoslavian",TRUE)
			remove_language("English")
			remove_note("Known Languages","English")
			for (var/datum/language/blugoslavian/A in languages)
				default_language = A
			name = species.get_random_english_name(gender)
			real_name = name
			add_note("Known Languages", "Blugoslavian")
			possible_h_list = list("Red","Orange","Light Blond","Blond","Dirty Blond")
			possible_e_list = list("Blue","Green")
			possible_s_range = list(-10,-28)
		update_character_appearance(possible_e_list, possible_h_list, possible_s_range)
	else
		if (faction_text == ARAB)
			if (original_job.title == "Wagner Group PMC")
				s_tone = rand(-35,-28)
			else
				s_tone = -90
		else if (faction_text == INDIANS)
			if ((map.ID == MAP_AFRICAN_WARLORDS)||(map.ID == MAP_TADOJSVILLE))
				s_tone = rand(-155,-185)
			else if (map.ID == MAP_EAST_LOS_SANTOS)
				s_tone = rand(-150,-120)
			else
				s_tone = -115
		else if (faction_text == CIVILIAN)
			if (map.ID == MAP_AFRICAN_WARLORDS)
				s_tone = rand(-155,-185)
			else if (map.ID == MAP_KANDAHAR || map.ID == MAP_MAGISTRAL || map.ID == MAP_HILL_3234)
				s_tone = rand(-75,-90)
		else if (faction_text == AMERICAN && map.ordinal_age >= 7)
			if (map.ID == MAP_EAST_LOS_SANTOS)
				s_tone = rand(-150,-120)
			else if (map.ID == MAP_SYRIA && original_job.title != "Delta Force Operator")
				s_tone = rand(-100,-60)
		else
			if (s_tone < -65)
				s_tone = -65

	force_update_limbs()
	update_body()

/mob/living/human/proc/update_character_appearance(var/list/possible_e_list, var/list/possible_h_list, var/list/possible_s_range)
	// Pick random options from the lists
	var/new_hair = pick(possible_h_list)
	var/new_eyes = pick(possible_e_list)
	var/new_skin_tone = rand(possible_s_range[2],possible_s_range[1])

	// Convert hexadecimal value of the color to RGB for hair
	var/hex_hair = hair_colors[new_hair]
	r_hair = hex2num(copytext(hex_hair, 2, 4))
	g_hair = hex2num(copytext(hex_hair, 4, 6))
	b_hair = hex2num(copytext(hex_hair, 6, 8))
	// Match the same color to facial hair
	r_facial = r_hair
	g_facial = g_hair
	b_facial = b_hair

	// Convert hexadecimal to RGB for eyes
	var/hex_eyes = eye_colors[new_eyes]
	r_eyes = hex2num(copytext(hex_eyes, 2, 4))
	g_eyes = hex2num(copytext(hex_eyes, 4, 6))
	b_eyes = hex2num(copytext(hex_eyes, 6, 8))
	// Update eye color
	change_eye_color(r_eyes, g_eyes, b_eyes)

	// Set the skin tone
	s_tone = new_skin_tone