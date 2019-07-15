/datum/job
	var/default_language = "Common"
	var/list/additional_languages = list() // "Name" = probability between 1-100
	var/SL_check_independent = FALSE // we're important, so we can spawn even if SLs are needed

/datum/job/civilian
	default_language = "English"
	additional_languages = list()

/datum/job/civilian/portuguese
	default_language = "Portuguese"
	additional_languages = list("French" = 25, "Spanish" = 35, "English" = 10)

/datum/job/civilian/spanish
	default_language = "Spanish"
	additional_languages = list("Portuguese" = 15, "French" = 25, "English" = 10)

/datum/job/pirates
	default_language = "English"
	additional_languages = list("French" = 25, "Spanish" = 35, "Portuguese" = 25)

/datum/job/british
	default_language = "English"
	additional_languages = list("French" = 15, "Spanish" = 15, "Portuguese" = 5, "German" = 5)

/datum/job/indians
	default_language = "Carib"
	additional_languages = list("French" = 25, "Spanish" = 25, "Portuguese" = 25, "English" = 25)

/datum/job/portuguese
	default_language = "Portuguese"
	additional_languages = list("French" = 25, "Spanish" = 35, "English" = 10)

/datum/job/spanish
	default_language = "Spanish"
	additional_languages = list("Portuguese" = 15, "French" = 25, "English" = 10)

/datum/job/dutch
	default_language = "Dutch"
	additional_languages = list("French" = 15, "Spanish" = 10, "English" = 25)

/datum/job/french
	default_language = "French"
	additional_languages = list("English" = 10, "Spanish" = 15)

/datum/job/roman
	default_language = "Latin"
	additional_languages = list("Greek" = 10)

/datum/job/greek
	default_language = "Greek"
	additional_languages = list("Latin" = 10)

/datum/job/arab
	default_language = "Arabic"
	additional_languages = list("French" = 10)

/datum/job/japanese
	default_language = "Japanese"
	additional_languages = list("English" = 15, "Russian" = 10)

/datum/job/russian
	default_language = "Russian"
	additional_languages = list("English" = 15, "Japanese" = 5)

/datum/job/german
	default_language = "German"
	additional_languages = list("French" = 15, "English" = 15)

/datum/job/american
	default_language = "English"
	additional_languages = list("French" = 10, "Spanish" = 25, "Portuguese" = 5, "German" = 5)

/datum/job/vietnamese
	default_language = "Vietnamese"
	additional_languages = list("French" = 5, "English" = 5, "Chinese" = 10)
/datum/job/update_character(var/mob/living/carbon/human/H)
	. = ..()

	var/list/notes = list()

	H.languages.Cut()

	if (!H.languages.len)
		H.add_language(default_language, FALSE)
		if (!notes.Find(default_language))
			if (map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA)
				H.add_note("Known Languages", default_language)
	else if (H.languages[1] != default_language)
		H.add_language(default_language, FALSE)
		if (map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_PANGEA)
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
		if (AMERICAN)
			if (map.ID == MAP_ARAB_TOWN)
				for (var/datum/language/hebrew/HB in H.languages)
					H.default_language = HB
					break
			else
				for (var/datum/language/english/E in H.languages)
					H.default_language = E
					break
