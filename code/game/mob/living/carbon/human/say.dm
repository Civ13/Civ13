/mob/living/human/say(var/message, var/howling = FALSE)
	var/verb = "says"

	// workaround for language bug that happens when you're spawned in
	if (!languages.len)
		languages = list(default_language)

	if (!message)
		return
	var/alt_name = ""

	if (name != GetVoice())
		alt_name = get_visible_name()
	var/animalistic = FALSE
	if ((werewolf || gorillaman) && body_build.name != "Default")
		if (werewolf)
			message = pick("grrrr!","woof", "wooof!", "rrrrr!")
			animalistic = TRUE
		else if (gorillaman)
			if (map && map.ID != MAP_TRIBES && map.ID != MAP_THREE_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID != MAP_NOMADS_NEW_WORLD && !map.is_fantrace)
				message = pick("uh uh uh!","UH UH", "OOGA", "BOOGA")
				animalistic = TRUE
	message = capitalize(sanitize(message))

	for (var/i in dictionary_list)
		message = replacetext(message,i[1],i[2])

	var/message_without_html = message

	if (dd_hassuffix(message, "!") && !dd_hassuffix(message, "!!"))
		message = "<span class = 'font-size: 1.1em;'>[message]</span>"
	else if (dd_hassuffix(message, "!!"))
		message = "<span class = 'font-size: 1.2em;'><b>[message]</b></span>"

	var/normal_message = message
	for (var/rp in radio_prefixes)
		if (dd_hasprefix(normal_message, rp))
			normal_message = copytext(normal_message, length(rp)+1, length(normal_message)+1)

	var/normal_message_without_html = message_without_html
	for (var/rp in radio_prefixes)
		if (dd_hasprefix(normal_message_without_html, rp))
			normal_message_without_html = copytext(normal_message_without_html, length(rp)+1, length(normal_message_without_html)+1)
	if (wolfman && howling)
		..(normal_message, alt_name = alt_name, alt_message = normal_message_without_html, animal = animalistic, howl = TRUE, original_message = message_without_html)
	else
		..(normal_message, alt_name = alt_name, alt_message = normal_message_without_html, animal = animalistic, howl = FALSE, original_message = message_without_html)

	for (var/mob/living/simple_animal/complex_animal/dog/D in view(7, src))
		D.hear_command(message_without_html, src)

	message_without_html = handle_speech_problems(message_without_html)[1]
	if (!animalistic)
		for (var/obj/structure/radio/RD in range(2,src))
			if (RD.transmitter && RD.transmitter_on && (RD.check_power() || RD.powerneeded == 0))
				RD.broadcast(message_without_html, src, verb)

		for (var/obj/item/weapon/radio/PRD in range(1,src))
			if (PRD.transmitter && PRD.transmitter_on)
				if (PRD in contents)
					if (dd_hasprefix(message_without_html, ";"))
						message_without_html = replacetext(message_without_html,";","",1,2)
						PRD.broadcast(message_without_html, src, verb)
				else
					PRD.broadcast(message_without_html, src, verb)

		for (var/obj/item/weapon/telephone/TL in range(2,src))
			if (TL.connected)
				TL.broadcast(message_without_html, src, , verb)

		for (var/obj/structure/voyage/voicepipe/VP in range(1,src))
			if (VP.vp_reference)
				if (VP.directional)
					switch(VP.dir)
						if(NORTH,EAST)
							if(src in get_turf(get_step(VP,EAST)))
								VP.broadcast(message_without_html, src, verb)
						if(SOUTH,WEST)
							if(src in get_turf(get_step(VP,WEST)))
								VP.broadcast(message_without_html, src, verb)
				else
					VP.broadcast(message_without_html, src, verb)

/mob/living/human/proc/forcesay(list/append)
	if (stat == CONSCIOUS)
		if (client)
			var/virgin = TRUE	//has the text been modified yet?
			var/temp = winget(client, "input", "text")
			if (findtextEx(temp, "Say \"", TRUE, 7) && length(temp) > 5)	//case sensitive means

				temp = replacetext(temp, ";", "")	//general radio

				if (findtext(trim_left(temp), ":", 6, 7))	//dept radio
					temp = copytext(trim_left(temp), 8)
					virgin = FALSE

				if (virgin)
					temp = copytext(trim_left(temp), 6)	//normal speech
					virgin = FALSE

				while (findtext(trim_left(temp), ":", TRUE, 2))	//dept radio again (necessary)
					temp = copytext(trim_left(temp), 3)

				if (findtext(temp, "*", TRUE, 2))	//emotes
					return
				temp = copytext(trim_left(temp), TRUE, rand(5,8))

				var/trimmed = trim_left(temp)
				if (length(trimmed))
					if (append)
						temp += pick(append)

					say(temp)
				winset(client, "input", "text=[null]")

/mob/living/human/say_understands(var/mob/other,var/datum/language/speaking = null)

	if (species.can_understand(other))
		return TRUE

	return ..()

/mob/living/human/GetVoice()
	return real_name

/mob/living/human/proc/SetSpecialVoice(var/new_voice)
	if (new_voice)
		special_voice = new_voice
	return

/mob/living/human/proc/UnsetSpecialVoice()
	special_voice = ""
	return

/mob/living/human/proc/GetSpecialVoice()
	return special_voice


/mob/living/human/say_quote(var/message, var/datum/language/speaking = null)
	var/verb = "says"
	var/ending = copytext(message, length(message))

	if (speaking)
		verb = speaking.get_spoken_verb(ending)
	else
		if (ending == "!")
			verb=pick("exclaims","shouts","yells")
		else if (ending == "?")
			verb="asks"

	return verb

/mob/living/human/handle_speech_problems(var/message, var/verb)
	if (silent || (sdisabilities & MUTE) || find_trait("Mute"))
		message = ""
		speech_problem_flag = TRUE
	else if (istype(wear_mask, /obj/item/clothing/mask))
		var/obj/item/clothing/mask/M = wear_mask
		if (M.voicechange)
			message = pick(M.say_messages)
			verb = pick(M.say_verbs)
			speech_problem_flag = TRUE

	if (message != "")
		var/list/parent = ..()
		message = parent[1]
		verb = parent[2]
		if (parent[3])
			speech_problem_flag = TRUE

	var/list/returns[3]
	returns[1] = message
	returns[2] = verb
	returns[3] = speech_problem_flag
	return returns

/mob/living/human/handle_speech_sound()
	if (species.speech_sounds && prob(species.speech_chance))
		var/list/returns[2]
		returns[1] = sound(pick(species.speech_sounds))
		returns[2] = 50
	return ..()
