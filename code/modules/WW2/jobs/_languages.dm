/datum/job
	var/default_language = "Common"
	var/list/additional_languages = list() // "Name" = probability between 1-100
	var/SL_check_independent = FALSE // we're important, so we can spawn even if SLs are needed

/datum/job/german
	default_language = "German"
	additional_languages = list("Russian" = 5, "Italian" = 10)

/datum/job/italian
	default_language = "Italian"
	additional_languages = list("German" = 100 )

/datum/job/soviet
	default_language = "Russian"
	additional_languages = list("German" = 5)

/datum/job/soviet/partisan
	default_language = "Polish"
	additional_languages = list("Russian" = 15)

/datum/job/partisan
	default_language = "Ukrainian"
	additional_languages = list("German" = 50, "Russian" = 75)

/datum/job/partisan/civilian
	default_language = "Ukrainian"
	additional_languages = list("German" = 50, "Russian" = 75)

/datum/job/usa
	default_language = "English"
	additional_languages = list("German" = 15, "Japanese" = 5)

/datum/job/japanese
	default_language = "Japanese"
	additional_languages = list("English" = 20)

/datum/job/polish
	default_language = "Polish"
	additional_languages = list("German" = 35, "Russian" = 25)

/datum/job/british
	default_language = "English"
/datum/job/pirates
	default_language = "English"

/datum/job/update_character(var/mob/living/carbon/human/H)
	. = ..()

	var/list/notes = list()

	H.languages.Cut()
	if (base_type_flag() == SOVIET)
		if (H.client && H.client.prefs)
			switch (H.client.prefs.soviet_ethnicity)
				if (RUSSIAN)
					H.add_language(RUSSIAN, TRUE)
					H.add_note("Known Languages", "Russian")
					notes += "Russian"
				if (UKRAINIAN)
					H.add_language(UKRAINIAN, TRUE)
					H.add_note("Known Languages", "Ukrainian")
					notes += "Ukrainian"
				if (POLISH)
					H.add_language(POLISH, TRUE)
					H.add_note("Known Languages", "Polish")
					notes += "Polish"

	if (!H.languages.len)
		H.add_language(default_language, TRUE)
		if (!notes.Find(default_language))
			H.add_note("Known Languages", default_language)
	else if (H.languages[1] != default_language)
		H.add_language(default_language, FALSE)
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
		if (SOVIET)
			for (var/datum/language/russian/R in H.languages)
				H.default_language = R
				break
		if (GERMAN, ITALIAN)
			for (var/datum/language/german/G in H.languages)
				H.default_language = G
				break