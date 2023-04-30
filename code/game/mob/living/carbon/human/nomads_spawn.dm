/mob/living/human/proc/nomads_spawn()
	if (map && map.is_zombie)
		add_note("Map Mechanics", "- Zombies will spawn in some areas <b>at night</b>.<br><br>- Bodies will turn into zombies after a while! To prevent this, <b>remove the head from the body</b>.<br><br>- Getting bit or scratched by a zombie will not automatically turn you into one. There is a small chance you get <b>infected with the zombie virus</b> from every strike a zombie lands on you. You will get high fevers, massive headaches, and eventually succumb to the disease; turning into a zombie. This can be cured by taking <b>Potassium Iodide</b>, which will kill the virus, even after symptoms have started.")

	if (map && (/*map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA || map.ID == MAP_NOMADS_NEW_WORLD*/map.is_fantrace))
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
		var/area/mob_area = get_area(src)
		var/new_hair = "Black"
		var/new_eyes = "Black"
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
				var/list/possible_h_list = list("Black")
				var/list/possible_e_list = list("Black")
				var/list/possible_s_list = list(-10,-60)
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
						possible_s_list = list(-10,-28)
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
						possible_s_list = list(-15,-30)
					if ("English")
						possible_h_list = list("Dark Brown","Light Brown","Dirty Blond")
						possible_e_list = list("Blue","Green","Brown")
						possible_s_list = list(-25,-38)
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
						possible_s_list = list(-15,-25)
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
						possible_s_list = list(-15,-25)
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
						possible_s_list = list(-165,-195)
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
						possible_s_list = list(-85,-110)
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
						possible_s_list = list(-75,-100)
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
						possible_s_list = list(-45,-65)
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
						possible_s_list = list(-40,-58)
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
						possible_s_list = list(-50,-70)

				possible_h_list += "Randomize"
				possible_e_list += "Randomize"
				new_hair = WWinput(src, "Choose the hair color:","Character Customization","Randomize",possible_h_list)
				if (new_hair == "Randomize")
					possible_h_list -= "Randomize"
					new_hair = pick(possible_h_list)
				new_eyes = WWinput(src, "Choose the eye color:","Character Customization","Randomize",possible_e_list)
				if (new_eyes == "Randomize")
					possible_e_list -= "Randomize"
					new_eyes = pick(possible_e_list)
				s_tone = input(src, "Choose the skin tone ([abs(possible_s_list[1])] to [abs(possible_s_list[2])]):","Character Customization") as num
				if (s_tone > abs(possible_s_list[2]))
					s_tone = abs(possible_s_list[2])
				else if (s_tone < abs(possible_s_list[1]))
					s_tone = abs(possible_s_list[1])
				s_tone = -s_tone
				var/list/sec_lang_list = list("Randomize","Russian","Zulu","Arabic","Latin")
				sec_lang_list -= choice1
				var/sec_lang = WWinput(src, "Choose your secondary language:","Character Customization","Randomize",sec_lang_list)
				if (sec_lang == "Randomize")
					sec_lang_list -= "Randomize"
					sec_lang = pick(sec_lang_list)
				add_language(sec_lang,TRUE)
				add_note("Known Languages", sec_lang)
		else if (choices == "Biome Appropriate")
			var/list/possible_h_list = list("Black")
			var/list/possible_e_list = list("Black")
			var/list/possible_s_list = list(10,60)
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
						possible_s_list = list(10,28)
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
						possible_s_list = list(15,30)
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
						possible_s_list = list(45,65)
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
						possible_s_list = list(50,70)
						choices = "Greek"

			new_hair = pick(possible_h_list)
			new_eyes = pick(possible_e_list)
			s_tone = -rand(possible_s_list[1],possible_s_list[2])
			var/list/sec_lang_list = list("Russian","Arabic","Zulu","Latin")
			sec_lang_list -= choices
			var/sec_lang = pick(sec_lang_list)
			add_language(sec_lang,FALSE)
			add_note("Known Languages", sec_lang)
/*
		else
			var/list/possible_h_list = list("Black")
			var/list/possible_e_list = list("Black")
			var/list/possible_s_list = list(10,60)
			var/choice1 = pick("Russian","Latin","Zulu","Arabic")
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
					possible_s_list = list(10,28)
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
					possible_s_list = list(15,30)
				if ("English")
					possible_h_list = list("Dark Brown","Light Brown","Dirty Blond")
					possible_e_list = list("Blue","Green","Brown")
					possible_s_list = list(25,38)
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
					possible_s_list = list(35,45)
				if ("Ainu")
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
					possible_s_list = list(35,55)
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
					possible_s_list = list(15,25)
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
					possible_s_list = list(165,195)
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
					possible_s_list = list(85,110)
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
					possible_s_list = list(75,100)
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
					possible_s_list = list(45,65)
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
					possible_s_list = list(40,58)
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
					possible_s_list = list(50,70)

			new_hair = pick(possible_h_list)
			new_eyes = pick(possible_e_list)
			s_tone = -rand(possible_s_list[1],possible_s_list[2])
			var/list/sec_lang_list = list("Russian","Arabic","Zulu","Latin")
			sec_lang_list -= choices
			var/sec_lang = pick(sec_lang_list)
			add_language(sec_lang,FALSE)
			add_note("Known Languages", sec_lang)
*/
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)
///////////////////////////////////////////////////////////////////
/////////////////////////Karafuta-Sakhalinsk///////////////////////
///////////////////////////////////////////////////////////////////
	else if (map && (map.ID == MAP_NOMADS_KARAFUTO))
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(10,60)
		var/area/mob_area = get_area(src)
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
					possible_s_list = list(15,28)
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
					possible_s_list = list(35,45)
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
					possible_s_list = list(25,35)
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
					possible_s_list = list(35,45)
					give_languages()
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map && (map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA))
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		var/area/mob_area = get_area(src)
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
				possible_s_list = list(-25,-45)
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
				possible_s_list = list(-40,-60)
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
				possible_s_list = list(-40,-60)
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
				possible_s_list = list(-25,-35)
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
				possible_s_list = list(-15,-25)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NOMADS_EUROPE)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		var/area/mob_area = get_area(src)
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
				possible_s_list = list(-10,-28)
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
				possible_s_list = list(-15,-30)
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
				possible_s_list = list(-49,-56)
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
				possible_s_list = list(-45,-65)

		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)
	else if (map.ID == MAP_NOMADS_MEDITERRANEAN)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		spawn(5)
			//SOUTH
			if (y<100)
				//SOUTH-WEST
				if (x<100)
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
					possible_s_list = list(-35,-60)
				//SOUTH-EAST
				else
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
					possible_s_list = list(-35,-60)
				//NORTH-WEST
			else
				if (x<100)
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
					possible_s_list = list(-20,-45)
				//NORTH-EAST
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
					possible_s_list = list(-15,-30)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NOMADS_DIVIDE)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		spawn(5)
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
				possible_s_list = list(-175,-200)
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
				possible_s_list = list(-85,-110)

		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NOMADS_AFRICA)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-85,-175)
		var/area/mob_area = get_area(src)
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
				possible_s_list = list(-145,-175)
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
				possible_s_list = list(-145,-174)
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
				possible_s_list = list(-85,-110)
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
				possible_s_list = list(-85,-110)

		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NATIONSRP)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		spawn(5)
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
				possible_s_list = list(-35,-60)
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
				possible_s_list = list(-15,-30)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NATIONSRP_TRIPLE)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		spawn(5)
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
				possible_s_list = list(-35,-60)
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
				possible_s_list = list(-15,-30)
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
				possible_s_list = list(-15,-30)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NATIONSRPMED)
		var/new_hair = "Dark Brown"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Light Brown","Dark Brown","Black")
		var/list/possible_e_list = list("Green","Brown","Black")
		var/list/possible_s_list = list(-45,-110)
		spawn(5)
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
				possible_s_list = list(-45,-65)
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
				possible_s_list = list(-85,-110)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NATIONSRP_WW2)
		var/new_hair = "Dark Brown"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Light Brown","Dark Brown","Black")
		var/list/possible_e_list = list("Green","Brown","Black")
		var/list/possible_s_list = list(-45,-110)
		spawn(5)
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
				possible_s_list = list(-10,-28)
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
				possible_s_list = list(-15,-30)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NATIONSRP_COLDWAR)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		spawn(5)
			//west English
			if (original_job_title == "Civilization A Citizen")
				add_language("English",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/english/A in languages)
					default_language = A
				name = species.get_random_english_name(gender)
				real_name = name
				add_note("Known Languages", "English")
				possible_h_list = list("Dark Brown","Light Brown","Dirty Blond")
				possible_e_list = list("Blue","Green","Brown")
				possible_s_list = list(-25,-38)
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
				possible_s_list = list(-10,-28)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)

	else if (map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		spawn(5)
			//west Redmenian
			if (original_job_title == "Civilization A Citizen")
				add_language("Redmenian",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/redmenian/A in languages)
					default_language = A
				name = species.get_random_chechen_name(gender)
				real_name = name
				add_note("Known Languages", "Redmenian")
				possible_h_list = list("Light Brown","Dark Brown","Black","Brown")
				possible_e_list = list("Green","Brown","Blue")
				possible_s_list = list(-15,-30)
			//east Blugoslavian
			else if (original_job_title == "Civilization B Citizen")
				add_language("Blugoslavian",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/blugoslavian/A in languages)
					default_language = A
				name = species.get_random_russian_name(gender)
				real_name = name
				add_note("Known Languages", "Blugoslavian")
				possible_h_list = list("Red","Orange","Light Blond","Blond","Dirty Blond")
				possible_e_list = list("Blue","Green")
				possible_s_list = list(-10,-28)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)
	else if (map.ID == MAP_NOMADS_PERSISTENCE_BETA)
		var/new_hair = "Black"
		var/new_eyes = "Black"
		var/list/possible_h_list = list("Black")
		var/list/possible_e_list = list("Black")
		var/list/possible_s_list = list(-10,-60)
		spawn(5)
			//west Redmenian
			if (original_job_title == "Redmenian Civilian")
				add_language("Redmenian",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/redmenian/A in languages)
					default_language = A
				name = species.get_random_chechen_name(gender)
				real_name = name
				add_note("Known Languages", "Redmenian")
				possible_h_list = list("Light Brown","Dark Brown","Black","Brown")
				possible_e_list = list("Green","Brown","Blue")
				possible_s_list = list(-15,-30)
			//east Blugoslavian
			else if (original_job_title == "Blugoslavian Civilian")
				add_language("Blugoslavian",TRUE)
				remove_language("English")
				remove_note("Known Languages","English")
				for (var/datum/language/blugoslavian/A in languages)
					default_language = A
				name = species.get_random_russian_name(gender)
				real_name = name
				add_note("Known Languages", "Blugoslavian")
				possible_h_list = list("Red","Orange","Light Blond","Blond","Dirty Blond")
				possible_e_list = list("Blue","Green")
				possible_s_list = list(-10,-28)
		new_hair = pick(possible_h_list)
		new_eyes = pick(possible_e_list)
		s_tone = rand(possible_s_list[2],possible_s_list[1])
		var/hex_hair = hair_colors[new_hair]
		r_hair = hex2num(copytext(hex_hair, 2, 4))
		g_hair = hex2num(copytext(hex_hair, 4, 6))
		b_hair = hex2num(copytext(hex_hair, 6, 8))
		r_facial = hex2num(copytext(hex_hair, 2, 4))
		g_facial = hex2num(copytext(hex_hair, 4, 6))
		b_facial = hex2num(copytext(hex_hair, 6, 8))
		var/hex_eyes = eye_colors[new_eyes]
		r_eyes = hex2num(copytext(hex_eyes, 2, 4))
		g_eyes = hex2num(copytext(hex_eyes, 4, 6))
		b_eyes = hex2num(copytext(hex_eyes, 6, 8))
		change_eye_color(r_eyes, g_eyes, b_eyes)
	else
		if (faction_text == ARAB)
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
			else if (map.ID == MAP_SOVAFGHAN || map.ID == MAP_MAGISTRAL || map.ID == MAP_HILL_3234)
				s_tone = rand(-75,-90)
		else if (faction_text == AMERICAN && map.ordinal_age >= 7)
			if (original_job.is_afro == TRUE || original_job.is_gta)
				s_tone = rand(-150,-120)
			else if (map.ID == MAP_EAST_LOS_SANTOS)
				s_tone = rand(-150,-120)
			else
				s_tone = rand(-40,-25)
		else
			if (s_tone < -65)
				s_tone = -65

	force_update_limbs()
	update_body()
