/datum/job
	var/default_language = "Common"
	var/list/additional_languages = list() // "Name" = probability between 1-100
	var/SL_check_independent = FALSE // we're important, so we can spawn even if SLs are needed

/datum/job/partisan
	default_language = "Ukrainian"
	additional_languages = list("German" = 50, "Russian" = 75)

/datum/job/partisan/civilian
	default_language = "Ukrainian"
	additional_languages = list("German" = 50, "Russian" = 75)

/datum/job/pirates
	default_language = "English"
	additional_languages = list("German" = 15, "Japanese" = 5)

/datum/job/british
	default_language = "English"
	additional_languages = list("German" = 20)


/datum/job/update_character(var/mob/living/carbon/human/H)
	. = ..()

	var/list/notes = list()

	H.languages.Cut()

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