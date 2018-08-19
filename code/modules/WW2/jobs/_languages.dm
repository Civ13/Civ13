/datum/job
	var/default_language = "Common"
	var/list/additional_languages = list() // "Name" = probability between 1-100
	var/SL_check_independent = FALSE // we're important, so we can spawn even if SLs are needed

/datum/job/civilian
	default_language = "English"
	additional_languages = list("French" = 25, "Spanish" = 15, "Portuguese" = 10)

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
	additional_languages = list("French" = 15, "Spanish" = 15, "Portuguese" = 5)

/datum/job/indians
	default_language = "Carib"
	additional_languages = list("French" = 25, "Spanish" = 25, "Portuguese" = 25, "English" = 25)

/datum/job/portuguese
	default_language = "Portuguese"
	additional_languages = list("French" = 25, "Spanish" = 35, "English" = 10)

/datum/job/spanish
	default_language = "Spanish"
	additional_languages = list("Portuguese" = 15, "French" = 25, "English" = 10)

/datum/job/update_character(var/mob/living/carbon/human/H)
	. = ..()

	var/list/notes = list()

	H.languages.Cut()

	if (base_type_flag() == PIRATES)
		if (H.client && H.client.prefs)
			switch (H.client.prefs.pirate_ethnicity)
				if (SPANISH)
					H.add_language(SPANISH, TRUE)
					H.add_note("Known Languages", "Spanish")
					notes += "Spanish"
				if (PORTUGUESE)
					H.add_language(PORTUGUESE, TRUE)
					H.add_note("Known Languages", "Portuguese")
					notes += "Portuguese"
				if (FRENCH)
					H.add_language(FRENCH, TRUE)
					H.add_note("Known Languages", "French")
					notes += "French"

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
		if (PIRATES, BRITISH)
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