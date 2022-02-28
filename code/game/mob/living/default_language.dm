/mob/living/verb/set_default_language(language as anything in languages)
	set name = "Set Default Language"
	set category = "IC"

	if (!languages.len)
		return

	if (language)
		src << "<span class='notice'>You will now speak [language] if you do not specify a language when speaking.</span>"
	else
		src << "<span class='notice'>You will now speak whatever your standard default language is if you do not specify one when speaking.</span>"
	default_language = language

/mob/living/verb/check_default_language()
	set name = "Check Default Language"
	set category = "IC"

	if (default_language)
		src << "<span class='notice'>You are currently speaking [default_language] by default.</span>"
	else
		src << "<span class='notice'>Your current default language is your species or mob type default.</span>"
