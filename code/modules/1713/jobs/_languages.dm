/datum/job
	var/default_language = "Common"
	var/list/additional_languages = list() // "Name" = probability between 1-100
	var/male_tts_voice = "Matthew"
	var/female_tts_voice = "Joanna"

/datum/job/civilian
	default_language = "English"
	additional_languages = list()
	male_tts_voice = "Brian"
	female_tts_voice = "Amy"

/datum/job/civilian/portuguese
	default_language = "Portuguese"
	additional_languages = list("French" = 25, "Spanish" = 35, "English" = 10)
	male_tts_voice = "Cristiano"
	female_tts_voice = "Ines"

/datum/job/civilian/spanish
	default_language = "Spanish"
	additional_languages = list("Portuguese" = 15, "French" = 25, "English" = 10)
	male_tts_voice = "Enrique"
	female_tts_voice = "Lucia"

/datum/job/pirates
	default_language = "English"
	additional_languages = list("French" = 25, "Spanish" = 35, "Portuguese" = 25)

/datum/job/british
	default_language = "English"
	additional_languages = list("French" = 15, "Spanish" = 15, "Portuguese" = 5, "German" = 5)
	male_tts_voice = "Brian"
	female_tts_voice = "Amy"

/datum/job/indians
	default_language = "Carib"
	additional_languages = list("French" = 25, "Spanish" = 25, "Portuguese" = 25, "English" = 25)
	male_tts_voice = "Miguel"
	female_tts_voice = "Penelope"

/datum/job/portuguese
	default_language = "Portuguese"
	additional_languages = list("French" = 25, "Spanish" = 35, "English" = 10)
	male_tts_voice = "Cristiano"
	female_tts_voice = "Ines"

/datum/job/spanish
	default_language = "Spanish"
	additional_languages = list("Portuguese" = 15, "French" = 25, "English" = 10)
	male_tts_voice = "Enrique"
	female_tts_voice = "Lucia"

/datum/job/dutch
	default_language = "Dutch"
	additional_languages = list("French" = 15, "Spanish" = 10, "English" = 25)
	male_tts_voice = "Ruben"
	female_tts_voice = "Lotte"

/datum/job/french
	default_language = "French"
	additional_languages = list("English" = 10, "Spanish" = 15)
	male_tts_voice = "Mathieu"
	female_tts_voice = "Celine"

/datum/job/roman
	default_language = "Latin"
	additional_languages = list("Greek" = 10)
	male_tts_voice = "Giorgio" //italian
	female_tts_voice = "Bianca" //italian

/datum/job/greek
	default_language = "Greek"
	additional_languages = list("Latin" = 10)
	male_tts_voice = "Jacek" //polish
	female_tts_voice = "Maja" //polish

/datum/job/arab
	default_language = "Arabic"
	additional_languages = list("French" = 10)
	male_tts_voice = "Russell" //australian
	female_tts_voice = "Zeina"

/datum/job/japanese
	default_language = "Japanese"
	additional_languages = list("English" = 15, "Russian" = 10)
	male_tts_voice = "Takumi"
	female_tts_voice = "Mizuki"

/datum/job/japanese/ija_ww2ATunit
	default_language = "Japanese"
	additional_languages = list("Korean" = 100, "Russian" = 10)
	male_tts_voice = "Takumi"
	female_tts_voice = "Mizuki"

/datum/job/russian
	default_language = "Russian"
	additional_languages = list("English" = 15, "Japanese" = 5)
	male_tts_voice = "Maxim"
	female_tts_voice = "Tatyana"

/datum/job/german
	default_language = "German"
	additional_languages = list("French" = 15, "English" = 15)
	male_tts_voice = "Hans"
	female_tts_voice = "Vicki"

/datum/job/american
	default_language = "English"
	additional_languages = list("French" = 10, "Spanish" = 25, "Portuguese" = 5, "German" = 5)
	male_tts_voice = "Matthew"
	female_tts_voice = "Joanna"

/datum/job/vietnamese
	default_language = "Vietnamese"
	additional_languages = list("French" = 5, "English" = 5, "Chinese" = 10)
	male_tts_voice = "Takumi" //jap
	female_tts_voice = "Zhiyu" //chinese

/datum/job/chinese
	default_language = "Chinese"
	additional_languages = list("English" = 5, "Vietnamese" = 10, "Japanese" = 5)
	male_tts_voice = "Takumi" //jap
	female_tts_voice = "Zhiyu" //chinese

/datum/job/filipino
	default_language = "Filipino"
	additional_languages = list("English" = 20, "Chinese" = 5, "Japanese" = 15)
	male_tts_voice = "Takumi" //jap
	female_tts_voice = "Zhiyu" //chinese

/datum/job/civilian/businessman/green
	default_language = "English"
	additional_languages = list("Japanese" = 100, "Chinese" = 15)
	male_tts_voice = "Takumi"
	female_tts_voice = "Mizuki"

/datum/job/civilian/businessman/red
	default_language = "English"
	additional_languages = list("Russian" = 100, "Ukrainian" = 15)
	male_tts_voice = "Maxim"
	female_tts_voice = "Tatyana"

/datum/job/civilian/businessman/yellow
	default_language = "English"
	additional_languages = list("Hebrew" = 100, "Arabic" = 15)
	male_tts_voice = "Maxim"
	female_tts_voice = "Tatyana"

/datum/job/civilian/businessman/blue
	default_language = "English"
	additional_languages = list("Latin" = 100)
	male_tts_voice = "Giorgio" //italian
	female_tts_voice = "Bianca" //italian

/datum/job/npc
	default_language = "English"

/datum/job/update_character(var/mob/living/human/H)
	. = ..()

	var/list/notes = list()

	H.languages.Cut()

	if (!H.languages.len)
		H.add_language(default_language, FALSE)
		if (!notes.Find(default_language))
			if (map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA || map.ID == MAP_NOMADS_MEDITERRANEAN)
				H.add_note("Known Languages", default_language)
	else if (H.languages[1] != default_language)
		H.add_language(default_language, FALSE)
		if (map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA || map.ID == MAP_NOMADS_MEDITERRANEAN)
			if (!notes.Find(default_language))
				H.add_note("Known Languages", default_language)

	H.default_language = H.languages[1]

	if (additional_languages && additional_languages.len > 0)
		for (var/language_name in additional_languages)
			var/probability = additional_languages[language_name]

			if (prob(probability))
				H.add_language(language_name, FALSE)
				H.add_note("Known Languages", language_name)

	switch (base_type_flag())
		if (PIRATES, BRITISH)
			for (var/datum/language/english/E in H.languages)
				H.default_language = E
				break
		if (CIVILIAN)
			if (map.ID == MAP_TSARITSYN)
				for (var/datum/language/russian/RR in H.languages)
					H.default_language = RR
					break
			else
				for (var/datum/language/english/E in H.languages)
					H.default_language = E
					break
		if (SPANISH)
			for (var/datum/language/spanish/S in H.languages)
				H.default_language = S
				break
		if (PORTUGUESE)
			for (var/datum/language/portuguese/P in H.languages)
				H.default_language = P
				break
		if (FRENCH)
			for (var/datum/language/french/F in H.languages)
				H.default_language = F
				break
		if (INDIANS)
			for (var/datum/language/carib/C in H.languages)
				H.default_language = C
				break
		if (DUTCH)
			for (var/datum/language/dutch/D in H.languages)
				H.default_language = D
				break
		if (JAPANESE)
			for (var/datum/language/japanese/J in H.languages)
				H.default_language = J
				break
		if (RUSSIAN)
			for (var/datum/language/russian/R in H.languages)
				H.default_language = R
				break
		if (ROMAN)
			for (var/datum/language/latin/L in H.languages)
				H.default_language = L
				break
		if (GERMAN)
			for (var/datum/language/german/K in H.languages)
				H.default_language = K
				break
		if (GREEK)
			for (var/datum/language/greek/G in H.languages)
				H.default_language = G
				break
		if (ARAB)
			for (var/datum/language/arab/A in H.languages)
				H.default_language = A
				break
		if (VIETNAMESE)
			for (var/datum/language/vietnamese/V in H.languages)
				H.default_language = V
				break
				break
		if (CHINESE)
			for (var/datum/language/chinese/CH in H.languages)
				H.default_language = CH
				break
		if (AMERICAN)
			if (map.ID == MAP_ARAB_TOWN)
				for (var/datum/language/hebrew/HB in H.languages)
					H.default_language = HB
					break
			else
				for (var/datum/language/english/E in H.languages)
					H.default_language = E
					break
