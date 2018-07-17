/mob/living/carbon/human/say(var/message)

	// workaround for language bug that happens when you're spawned in
	if (!languages.len)
		languages[1] = default_language

	if (!message)
		return

	var/alt_name = ""

	if (name != rank_prefix_name(GetVoice()))
		alt_name = "(as [rank_prefix_name(get_id_name())])"

	message = capitalize_cp1251(sanitize(message))
	var/message_without_html = message

	if (!dd_hasprefix(message, ";") && !dd_hasprefix(message, ":b") && !dd_hasprefix(message, ":r") && !dd_hasprefix(message, ":l") && !dd_hasprefix(message, ":f"))
		if (dd_hassuffix(message, "!") && !dd_hassuffix(message, "!!"))
			message = "<span class = 'font-size: 1.1em;'>[message]</span>"
		else if (dd_hassuffix(message, "!!"))
			message = "<span class = 'font-size: 1.2em;'><b>[message]</b></span>"

	var/normal_message = message
	for (var/rp in radio_prefixes)
		if (dd_hasprefix(normal_message, rp))
			normal_message = copytext(normal_message, lentext(rp)+1, lentext(normal_message)+1)

	var/normal_message_without_html = message_without_html
	for (var/rp in radio_prefixes)
		if (dd_hasprefix(normal_message_without_html, rp))
			normal_message_without_html = copytext(normal_message_without_html, lentext(rp)+1, lentext(normal_message_without_html)+1)

	..(normal_message, alt_name = alt_name, alt_message = normal_message_without_html)

	for (var/mob/living/simple_animal/complex_animal/canine/dog/D in view(world.view, src))
		D.hear_command(message_without_html, src)

	message_without_html = handle_speech_problems(message_without_html)[1]

	// radio talk
	if ((!dd_hasprefix(message_without_html, ":t") && !dd_hasprefix(message_without_html, ":T")) || !istype(loc, /obj/tank))
		post_say(message_without_html)

	// tank talk
	else if ((dd_hasprefix(message_without_html, ":t") || dd_hasprefix(message_without_html, ":T")) && istype(loc, /obj/tank))
		var/obj/tank/my_tank = loc
		if (my_tank.radio)
			for (var/human in human_mob_list)
				var/mob/living/carbon/human/H = human
				if (H.loc == loc)
					H.on_hear_radio(my_tank.radio, "<span class = 'srvradio'><big><b>TANKCHAT</b>: [real_name] says, \"<span class = 'notice'>[capitalize(trim_left(copytext(message_without_html, 3, length(message_without_html)+1)))]</span>\"</big></span>")

/mob/living/carbon/human/proc/forcesay(list/append)
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

/mob/living/carbon/human/say_understands(var/mob/other,var/datum/language/speaking = null)

	if (has_brain_worms()) //Brain worms translate everything. Even mice and alien speak.
		return TRUE

	if (species.can_understand(other))
		return TRUE

	//These only pertain to common. Languages are handled by mob/say_understands()
	if (!speaking)
		if (istype(other, /mob/living/carbon/brain))
			return TRUE

	//This is already covered by mob/say_understands()
	//if (istype(other, /mob/living/simple_animal))
	//	if ((other.universal_speak && !speaking) || universal_speak || universal_understand)
	//		return TRUE
	//	return FALSE

	return ..()

/mob/living/carbon/human/GetVoice()
/*
	var/voice_sub
	for (var/obj/item/gear in list(wear_mask,wear_suit,head))
		if (!gear)
			continue
		var/obj/item/voice_changer/changer = locate() in gear
		if (changer && changer.active && changer.voice)
			voice_sub = changer.voice
	if (voice_sub)
		return voice_sub
	if (GetSpecialVoice())
		return GetSpecialVoice()*/
	return real_name

/mob/living/carbon/human/proc/SetSpecialVoice(var/new_voice)
	if (new_voice)
		special_voice = new_voice
	return

/mob/living/carbon/human/proc/UnsetSpecialVoice()
	special_voice = ""
	return

/mob/living/carbon/human/proc/GetSpecialVoice()
	return special_voice


/*
   ***Deprecated***
   let this be handled at the hear_say or hear_radio proc
   This is left in for robot speaking when humans gain binary channel access until I get around to rewriting
   robot_talk() proc.
   There is no language handling build into it however there is at the /mob level so we accept the call
   for it but just ignore it.
*/

/mob/living/carbon/human/say_quote(var/message, var/datum/language/speaking = null)
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

/mob/living/carbon/human/handle_speech_problems(var/message, var/verb)
	if (silent || (sdisabilities & MUTE))
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

/mob/living/carbon/human/handle_message_mode(message_mode, message, verb, speaking, used_radios, alt_name)
	switch(message_mode)
		if ("intercom")
			if (!restrained())
				for (var/obj/item/radio/intercom/I in view(1))
					I.talk_into(src, message, null, verb, speaking)
					I.add_fingerprint(src)
					used_radios += I
		if ("headset")
			if (l_ear && istype(l_ear,/obj/item/radio))
				var/obj/item/radio/R = l_ear
				R.talk_into(src,message,null,verb,speaking)
				used_radios += l_ear
			else if (r_ear && istype(r_ear,/obj/item/radio))
				var/obj/item/radio/R = r_ear
				R.talk_into(src,message,null,verb,speaking)
				used_radios += r_ear
		if ("right ear")
			var/obj/item/radio/R
			var/has_radio = FALSE
			if (r_ear && istype(r_ear,/obj/item/radio))
				R = r_ear
				has_radio = TRUE
			if (r_hand && istype(r_hand, /obj/item/radio))
				R = r_hand
				has_radio = TRUE
			if (has_radio)
				R.talk_into(src,message,null,verb,speaking)
				used_radios += R
		if ("left ear")
			var/obj/item/radio/R
			var/has_radio = FALSE
			if (l_ear && istype(l_ear,/obj/item/radio))
				R = l_ear
				has_radio = TRUE
			if (l_hand && istype(l_hand,/obj/item/radio))
				R = l_hand
				has_radio = TRUE
			if (has_radio)
				R.talk_into(src,message,null,verb,speaking)
				used_radios += R
		if ("harness")
			var/obj/item/radio/R
			var/has_radio = FALSE
			if (s_store && istype(s_store,/obj/item/radio))
				R = s_store
				has_radio = TRUE
			if (has_radio)
				R.talk_into(src,message,null,verb,speaking)
				used_radios += R
		if ("whisper")
			whisper_say(message, speaking, alt_name)
			return TRUE
		else
			if (message_mode)
				if (l_ear && istype(l_ear,/obj/item/radio))
					l_ear.talk_into(src,message, message_mode, verb, speaking)
					used_radios += l_ear
				else if (r_ear && istype(r_ear,/obj/item/radio))
					r_ear.talk_into(src,message, message_mode, verb, speaking)
					used_radios += r_ear

/mob/living/carbon/human/handle_speech_sound()
	if (species.speech_sounds && prob(species.speech_chance))
		var/list/returns[2]
		returns[1] = sound(pick(species.speech_sounds))
		returns[2] = 50
	return ..()
