#define SCRAMBLE_CACHE_LEN 20

/*
	Datum based languages. Easily editable and modular.
*/

/datum/language
	var/name = "an unknown language"  // Fluff name of language if any.
	var/desc = "A language."		  // Short description for 'Check Languages'.
	var/difficulty = 175			  // Difficulty of a language. If you wanted Japanese to be harder than English, for example
	var/speech_verb = "says"		  // 'says', 'hisses', 'farts'.
	var/ask_verb = "asks"			 // Used when sentence ends in a ?
	var/exclaim_verb = "exclaims"	 // Used when sentence ends in a !
	var/whisper_verb = "whispers"	 // Optional. When not specified speech_verb + quietly/softly is used instead.
	var/signlang_verb = list("signs") // list of emotes that might be displayed if this language has NONVERBAL or SIGNLANG flags
	var/colour = "body"			   // CSS style to use for strings in this language.
	var/key = "x"					 // Character used to speak in language eg. :o for Unathi.
	var/flags = 0					 // Various language flags.
	var/native						// If set, non-native speakers will have trouble speaking.
	var/list/syllables				// Used when scrambling text for a non-speaker.
	var/list/mutual_intelligibility = list()

/datum/language/proc/get_random_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female)) + " " + capitalize(pick(last_names))
		else
			return capitalize(pick(first_names_male)) + " " + capitalize(pick(last_names))

	var/full_name = "John Doe"
	return full_name

/datum/language/proc/get_random_english_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_english)) + " " + capitalize(pick(last_names_english))
		else
			return capitalize(pick(first_names_male_english)) + " " + capitalize(pick(last_names_english))

	var/full_name = "John Adams"
	return full_name

/datum/language/proc/get_random_portuguese_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_portuguese)) + " " + capitalize(pick(last_names_portuguese))
		else
			return capitalize(pick(first_names_male_portuguese)) + " " + capitalize(pick(last_names_portuguese))

	var/full_name = "Pedro Alves"
	return full_name

/datum/language/proc/get_random_spanish_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_spanish)) + " " + capitalize(pick(last_names_spanish))
		else
			return capitalize(pick(first_names_male_spanish)) + " " + capitalize(pick(last_names_spanish))

	var/full_name = "Juan Garcia"
	return full_name

/datum/language/proc/get_random_french_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_french)) + " " + capitalize(pick(last_names_french))
		else
			return capitalize(pick(first_names_male_french)) + " " + capitalize(pick(last_names_french))

	var/full_name = "Mathieu Bertrand"
	return full_name



/datum/language/proc/get_random_dutch_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_dutch)) + " " + capitalize(pick(last_names_dutch))
		else
			return capitalize(pick(first_names_male_dutch)) + " " + capitalize(pick(last_names_dutch))

	var/full_name = "Daan Visser"
	return full_name

/datum/language/proc/get_random_afrikaans_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_afrikaans) + " " + capitalize(pick(last_names_afrikaans)))
		else
			return capitalize(pick(first_names_male_afrikaans) + " " + capitalize(pick(last_names_afrikaans)))
	
	var/full_name = "Jan Botha"
	return full_name

/datum/language/proc/get_random_japanese_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_japanese)) + " " + capitalize(pick(last_names_japanese))
		else
			return capitalize(pick(first_names_male_japanese)) + " " + capitalize(pick(last_names_japanese))

	var/full_name = "Hideki Tojo"
	return full_name

/datum/language/proc/get_random_chinese_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_chinese)) + " " + capitalize(pick(last_names_chinese))
		else
			return capitalize(pick(first_names_male_chinese)) + " " + capitalize(pick(last_names_chinese))

	var/full_name = "Sun Tzu"
	return full_name

/datum/language/proc/get_random_russian_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_russian)) + " " + capitalize(pick(last_names_russian) + "a")
		else
			return capitalize(pick(first_names_male_russian)) + " " + capitalize(pick(last_names_russian))

	var/full_name = "Victor Reznof"
	return full_name

/datum/language/proc/get_random_polish_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_polish)) + " " + capitalize(pick(last_names_polish))
		else
			return capitalize(pick(first_names_male_polish)) + " " + capitalize(pick(last_names_polish))

	var/full_name = "Mikolaj Gudowicz"
	return full_name

/datum/language/proc/get_random_ukrainian_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_ukrainian)) + " " + capitalize(pick(last_names_ukrainian))
		else
			return capitalize(pick(first_names_male_ukrainian)) + " " + capitalize(pick(last_names_ukrainian))

	var/full_name = "Yuri Davidenko"
	return full_name

/datum/language/proc/get_random_gaelic_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_gaelic)) + " " + capitalize(pick(last_names_gaelic))
		else
			return capitalize(pick(first_names_male_gaelic)) + " " + capitalize(pick(last_names_gaelic))

	var/full_name = "Sean Mcloughlin"
	return full_name

/datum/language/proc/get_random_irish_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_irish)) + " " + capitalize(pick(last_names_irish))
		else
			return capitalize(pick(first_names_male_irish)) + " " + capitalize(pick(last_names_irish))

	var/full_name = "Patrick McKellen"
	return full_name

/datum/language/proc/get_random_italian_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_italian)) + " " + capitalize(pick(last_names_italian))
		else
			return capitalize(pick(first_names_male_italian)) + " " + capitalize(pick(last_names_italian))

	var/full_name = "Giovanni Basso"
	return full_name


/datum/language/proc/get_random_oldnorse_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))

	var/full_name = "Dovahkiin"
	return full_name

/datum/language/proc/get_random_finnish_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_finnish)) + " " + capitalize(pick(last_names_finnish))
		else
			return capitalize(pick(first_names_male_finnish)) + " " + capitalize(pick(last_names_finnish))

	var/full_name = "Nokia Kuoma"
	return full_name

/datum/language/proc/get_random_norwegian_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))//To do: implement proper Norwegian names
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))//To do: implement proper Norwegian names

	var/full_name = "Bjorn Hansen"
	return full_name

/datum/language/proc/get_random_swedish_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))//To do: implement proper Swedish names
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))//To do: implement proper Swedish names

	var/full_name = "Lars Andersson"
	return full_name

/datum/language/proc/get_random_danish_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))//To do: implement proper Danish names
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))//To do: implement proper Danish names

	var/full_name = "Karl Jensen"
	return full_name

/datum/language/proc/get_random_inuit_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_inuit))
		else
			return capitalize(pick(first_names_male_inuit))

	var/full_name = "Epawig"
	return full_name

/datum/language/proc/get_random_cherokee_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_cherokee))
		else
			return capitalize(pick(first_names_male_cherokee))

	var/full_name = "Tatanka"
	return full_name

/datum/language/proc/get_random_carib_name(var/gender, name_count=1, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_carib))
		else
			return capitalize(pick(first_names_male_carib))

	var/full_name = "Mojowai"
	return full_name

/datum/language/proc/get_random_greek_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_male_greek)) + " " + capitalize(pick(last_names_greek))

	var/full_name = "Philokrates"
	return full_name

/datum/language/proc/get_random_orc_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_orc))

	var/full_name = "Morgoth"
	return full_name

/datum/language/proc/get_random_ant_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_ant))

	var/full_name = "Kch-ak"
	return full_name

/datum/language/proc/get_random_gorilla_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_gorilla))

	var/full_name = "Oog"
	return full_name
/datum/language/proc/get_random_wolf_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_wolf)) + " " + capitalize(pick(last_names_wolf))

	var/full_name = "Wooowa"
	return full_name

/datum/language/proc/get_random_crab_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_crab)) + " " + capitalize(pick(last_names_crab))

	var/full_name = "Mr. Krabs"
	return full_name
/datum/language/proc/get_random_lizard_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_lizard))

	var/full_name = "Hass"
	return full_name
/datum/language/proc/get_random_roman_name(name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_male_roman)) + " " + capitalize(pick(middle_names_roman)) + " " + capitalize(pick(last_names_roman))

	var/full_name = "Decius Salvius Primulus"
	return full_name

/datum/language/proc/get_random_arab_name(name_count=1, syllable_count=4, syllable_divisor=2)//removed var/gender
	if (!syllables || !syllables.len)
		return capitalize(pick(first_names_male_arab)) + " ibn " + capitalize(pick(first_names_male_arab))

	var/full_name = "Ibrahim Ibn Osama"
	return full_name

/datum/language/proc/get_random_chechen_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_male_chechen)) + " " + capitalize(pick(last_names_chechen) + "a")
		else
			return capitalize(pick(first_names_male_chechen)) + " " + capitalize(pick(last_names_chechen))

	var/full_name = "Dzokhar Kadyrov"
	return full_name


/datum/language/proc/get_random_egyptian_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_egyptian)) + " " + capitalize(pick(last_names_egyptian))
		else
			return capitalize(pick(first_names_male_egyptian)) + " " + capitalize(pick(last_names_egyptian))

	var/full_name = "Isis"
	return full_name

/datum/language/proc/get_random_mongolian_name(var/gender, name_count=1, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(names_mongolian_female))
		else
			return capitalize(pick(names_mongolian_male))

	var/full_name = "Chinggis"
	return full_name

/datum/language/proc/get_random_korean_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_korean)) + " " + capitalize(pick(last_names_korean))
		else
			return capitalize(pick(first_names_male_korean)) + " " + capitalize(pick(last_names_korean))

	var/full_name = "Hyung Do Seong"
	return full_name

/datum/language/proc/get_random_iroquois_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_iroquois)) + " " + capitalize(pick(last_names_iroquois))
		else
			return capitalize(pick(first_names_male_iroquois)) + " " + capitalize(pick(last_names_iroquois))

	var/full_name = "At'tawig"
	return full_name

/datum/language/proc/get_random_filipino_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_filipino)) + " " + capitalize(pick(last_names_filipino))
		else
			return capitalize(pick(first_names_male_filipino)) + " " + capitalize(pick(last_names_filipino))

	var/full_name = "Hyung Do Seong"
	return full_name

/datum/language/proc/get_random_afro_american_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if (!syllables || !syllables.len)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_english)) + " " + capitalize(pick(last_names_afro_american))
		else
			return capitalize(pick(first_names_male_afro_american)) + " " + capitalize(pick(last_names_afro_american))

	var/full_name = "Tyrone Jenkins"
	return full_name



/datum/language
	var/list/scramble_cache = list()

// hearer only needs to be specified for mutual intelligibility code to work - Kachnov
/datum/language/proc/scramble(var/input, var/mob/hearer = null)

	if (!syllables || !syllables.len)
		return stars(input)

	// If the input is cached already, move it to the end of the cache and return it
	if (input in scramble_cache && !hearer)
		var/n = scramble_cache[input]
		scramble_cache -= input
		scramble_cache[input] = n
		return n

	var/scrambled_text = ""
	var/list/original_words = splittext(input, " ")

	var/mob/living/human/H = hearer
	if (!ishuman(H))
		return
	var/capitalize = TRUE
	var/capitalize_next = TRUE
	if (original_words.len)
		var/next = ""
		for (var/v in 1 to original_words.len)
			if (original_words[v] == null)
				break
			next = original_words[v]
			// Save the ending character in case it's punctuation
			var/ending = copytext(next, length(next))
			var/add_ending = FALSE
			// Check if the beginning of the word is capitalized
			var/beginning = (copytext(next, 1, 2))
			var/beginning_cap = (beginning == uppertext(beginning))
			// Check if the word is in all caps
			var/allcaps = (next == uppertext(next))
			capitalize_next = FALSE
			if (findtext(next, "...", length(next)-3))
				// It's an ellipsis ...
				ending = "..."
			// Partial language skill / language difficulty * 100
			if (prob(H.partial_languages[name] / difficulty * 100))
				// Make the word appear slightly weird: "hello" = "hsllo"
				next = replacetext(next, pick(alphabet_lowercase), pick(alphabet_lowercase))
			else
				// Produce a foreign word of sufficient length
				var/foreign_word = ""
				while (length(foreign_word) < length(next))
					foreign_word += pick(syllables)
				// Strip leading single quotes
				if (copytext(foreign_word, 1, 2) == "'")
					foreign_word = copytext(foreign_word, 2)
				next = foreign_word
				// Preserve punctuation
				if (ending in list("!","?",".",",","..."))
					add_ending = TRUE
					// Capitalize the next word, unless it's a comma or ellipsis
					if (ending in list(",","..."))
						capitalize_next = FALSE
					else
						capitalize_next = TRUE
				else
					capitalize_next = FALSE
			if (allcaps)
				next = uppertext(next)
			else if (capitalize || beginning_cap)
				next = capitalize(next)
			if (add_ending)
				next += ending
			if (next)
				scrambled_text += "[next] "
			capitalize = capitalize_next
			original_words[v] = null

	// Clean up whitespace
	scrambled_text = trim(scrambled_text)

	// Add it to cache, cutting old entries if the list is too long
	scramble_cache[input] = scrambled_text
	if (scramble_cache.len > SCRAMBLE_CACHE_LEN)
		scramble_cache.Cut(1, scramble_cache.len-SCRAMBLE_CACHE_LEN-1)

	return scrambled_text

/datum/language/proc/format_message(message, verb)
	return "[verb], <span class='[colour]'>\"[capitalize(message)]\"</span>"

/datum/language/proc/format_message_plain(message, verb)
	return "[verb], \"[capitalize(message)]\""

/datum/language/proc/format_message_overlay(message)
	return "[capitalize(message)]"


/datum/language/proc/format_message_radio(message, verb)
	return "[verb], <span class='[colour]'>\"[capitalize(message)]\"</span>"

/datum/language/proc/get_talkinto_msg_range(message)
	// if you yell, you'll be heard from two tiles over instead of one
	return (copytext(message, length(message)) == "!") ? 2 : TRUE

/datum/language/proc/broadcast(var/mob/living/speaker,var/message,var/speaker_mask)
	log_say("[key_name(speaker)] : ([name]) [message]")

	if (!speaker_mask) speaker_mask = speaker.name
	message = format_message(message, get_spoken_verb(message))

	for (var/mob/player in player_list)
		player.hear_broadcast(src, speaker, speaker_mask, message)

/mob/proc/hear_broadcast(var/datum/language/language, var/mob/speaker, var/speaker_name, var/message)
	if ((language in languages) && language.check_special_condition(src))
		var/msg = "<i><span class='game say'>[language.name], <span class='name'>[speaker_name]</span> [message]</span></i>"
		src << msg

/mob/new_player/hear_broadcast(var/datum/language/language, var/mob/speaker, var/speaker_name, var/message)
	return

/mob/observer/ghost/hear_broadcast(var/datum/language/language, var/mob/speaker, var/speaker_name, var/message)
	if (speaker.name == speaker_name)
		src << "<i><span class='game say'>[language.name], <span class='name'>[speaker_name]</span> ([ghost_follow_link(speaker, src)]) [message]</span></i>"
	else
		src << "<i><span class='game say'>[language.name], <span class='name'>[speaker_name]</span> [message]</span></i>"

/datum/language/proc/check_special_condition(var/mob/other)
	return TRUE

/datum/language/proc/get_spoken_verb(var/msg_end)
	switch(msg_end)
		if ("!")
			return pick("exclaims", "shouts", "yells")//exclaim_verb
		if ("?")
			return ask_verb
	return speech_verb

// Language handling.
/mob/proc/add_language(var/language, var/allow_name_changing = FALSE)
	if (language == uppertext(language))
		language = capitalize(lowertext(language))

	var/datum/language/new_language = null
	if (isdatum(language))
		new_language = language
	else
		new_language = all_languages[language]
	var/cname_check = TRUE

	for (var/v in 1 to languages.len)
		var/datum/language/l = languages[v]
		if (l)
			if (istype(l, /datum/language/english))
				cname_check = FALSE
			else if (istype(l, /datum/language/carib))
				cname_check = FALSE
			else if (istype(l, /datum/language/spanish))
				cname_check = FALSE
			else if (istype(l, /datum/language/portuguese))
				cname_check = FALSE
			else if (istype(l, /datum/language/french))
				cname_check = FALSE
			else if (istype(l, /datum/language/dutch))
				cname_check = FALSE
			else if (istype(l, /datum/language/arab))
				cname_check = FALSE
			else if (istype(l, /datum/language/latin))
				cname_check = FALSE
			else if (istype(l, /datum/language/greek))
				cname_check = FALSE
			else if (istype(l, /datum/language/russian))
				cname_check = FALSE
			else if (istype(l, /datum/language/japanese))
				cname_check = FALSE
			else if (istype(l, /datum/language/chinese))
				cname_check = FALSE
			else if (istype(l, /datum/language/polish))
				cname_check = FALSE
			else if (istype(l, /datum/language/ukrainian))
				cname_check = FALSE
			else if (istype(l, /datum/language/gaelic))
				cname_check = FALSE
			else if (istype(l, /datum/language/oldnorse))
				cname_check = FALSE
			else if (istype(l, /datum/language/inuit))
				cname_check = FALSE
			else if (istype(l, /datum/language/cherokee))
				cname_check = FALSE
	if (cname_check && allow_name_changing)
		if (istype(new_language, /datum/language/english))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_english_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender
		if (istype(new_language, /datum/language/spanish))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_spanish_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/portuguese))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_portuguese_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/french))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_french_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/dutch))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_dutch_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/japanese))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_japanese_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/chinese))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_chinese_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/russian))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_russian_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/carib))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_carib_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/latin))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_roman_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/greek))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_greek_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/arab))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_arab_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/polish))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_polish_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/ukrainian))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_ukrainian_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/gaelic))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_gaelic_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/oldnorse))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_oldnorse_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/inuit))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_inuit_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/cherokee))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_cherokee_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

		if (istype(new_language, /datum/language/mongolian))
			if (ishuman(src))
				var/mob/living/human/H = src
				if (H.species && H.client)
					H.real_name = H.species.get_random_mongolian_name(H.gender, FALSE)
					H.name = H.real_name
					H.gender = H.client.prefs.gender

	if (!istype(new_language) || (new_language in languages))
		return FALSE

	// If they don't have a default language, set it
	if (ishuman(src))
		var/mob/living/human/H = src
		if (!H.default_language)
			H.default_language = new_language

	// Set partial_language values to mutual_intelligibility scores for the added language
	// Someone who knows Russian understands N% of Ukrainian
	if (ishuman(src))
		var/mob/living/human/H = src
		var/list/m_int = new_language.mutual_intelligibility
		for (var/lname in all_languages)
			var/datum/language/L = all_languages[lname]
			if (L.type in m_int)
				H.partial_languages[lname] = max((H.partial_languages[lname]), m_int[L.type]*L.difficulty/100)
	languages.Add(new_language)
	return TRUE

/mob/proc/remove_language(var/rem_language)
	var/datum/language/L = all_languages[rem_language]
	. = (L in languages)
	languages.Remove(L)

/mob/living/remove_language(var/rem_language)
	var/datum/language/L = all_languages[rem_language]
	if (default_language == L)
		default_language = null
	if (ishuman(src))
		var/mob/living/human/H = src
		// Remove partial_language values
		H.partial_languages[rem_language] = 0
		var/list/m_int = L.mutual_intelligibility
		for (var/lname in all_languages)
			var/datum/language/R = all_languages[lname]
			if (R.type in m_int)
				H.partial_languages[lname] = max((H.partial_languages[lname]-m_int[R.type]*R.difficulty/100), 0)
	return ..()

// Can we speak this language, as opposed to just understanding it?
/mob/proc/can_speak(datum/language/speaking)
	return (universal_speak || (speaking && speaking.flags & INNATE) || speaking in languages)

/mob/proc/get_language_prefix()
	return config.language_prefixes[1]

/mob/proc/is_language_prefix(var/prefix)
	return prefix in config.language_prefixes

//TBD
/mob/verb/check_languages()
	set name = "Check Known Languages"
	set category = "IC"
	set src = usr

	var/dat = "<b><font size = 5>Known Languages</font></b><br/><br/>"

	for (var/datum/language/L in languages)
		if (!(L.flags & NONGLOBAL))
			dat += "<b>[L.name] ([get_language_prefix()][L.key])</b><br/>[L.desc]<br/><br/>"

	src << browse(dat, "window=checklanguage")
	return

/mob/living/check_languages()
	var/dat = "<b><font size = 5>Known Languages</font></b><br/><br/>"

	if (default_language)
		dat += "Current default language: [default_language]<br/><br/>"

	for (var/datum/language/L in languages)
		if (!(L.flags & NONGLOBAL))
			if (L == default_language)
				dat += "<b>[L.name] ([get_language_prefix()][L.key])</b> - default<br/>[L.desc]<br/><br/>"
			else
				dat += "<b>[L.name] ([get_language_prefix()][L.key])</b><br/>[L.desc]<br/><br/>"

	src << browse(dat, "window=checklanguage")

/mob/living/Topic(href, href_list)
	if (href_list["default_lang"])
		if (href_list["default_lang"] == "reset")
			set_default_language(null)
		else
			var/datum/language/L = locate(href_list["default_lang"])
			if (L && (L in languages))
				set_default_language(L)
		check_languages()
		return TRUE
	else
		return ..()

/proc/transfer_languages(var/mob/source, var/mob/target, var/except_flags)
	for (var/datum/language/L in source.languages)
		if (L.flags & except_flags)
			continue
		target.add_language(L.name)

#undef SCRAMBLE_CACHE_LEN
