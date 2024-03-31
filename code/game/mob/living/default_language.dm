/mob/living/verb/set_default_language(datum/language/language as anything in languages)
    // Set the name and category of the verb
    set name = "Set Default Language"
    set category = "IC"

    // Check if the languages list is empty
    if (!languages.len)
        // If there are no languages available, return and do nothing
        return
	
    else if (language)
        // Count the number of languages the mob knows
        var/datum/language/lang
        var/num_languages = 0 // We set this to -1 to account for the 'other' languages that do not include the first.

        // Loop through each language in the mob's languages list
        for (lang in src.languages)
            // Increment the count of languages
            num_languages += 1

        // Display messages based on the selected language
        if (num_languages == 1)
            to_chat(src, SPAN_NOTICE("You can only speak [lowertext(languages[1].name)] by default."))
        else if (num_languages > 1)
            // If the mob knows more than one language, display the selected language and the number of other languages known
            to_chat(src, SPAN_NOTICE("You will now defaultly speak [lowertext(language.name)] and know [num_languages-1] other language(s)."))
        else
            // If the mob does not know any languages, display a message indicating so
            to_chat(src, SPAN_NOTICE("You do not know a language."))
	
	// Set the default language outside the if-else block
    default_language = language


/mob/living/verb/check_default_language()
	set name = "Check Default Language"
	set category = "IC"

	if (default_language)
		to_chat(src, SPAN_NOTICE("You are currently speaking [default_language] by default."))
	else
		to_chat(src, SPAN_NOTICE("Your current default language is your species or mob type default."))
