var/list/department_radio_keys = list(
	  //":r" = "right ear",	".r" = "right ear",
	//  ":l" = "left ear",	".l" = "left ear",
	  ":i" = "intercom",	".i" = "intercom",
	//  ":b" = "harness", 	".b" = "harness",
	  ":h" = "department",	".h" = "department",
	  ":+" = "special",		".+" = "special", //activate radio-specific special functions
	  ":c" = "Command",		".c" = "Command",
	  ":n" = "Science",		".n" = "Science",
	  ":m" = "Medical",		".m" = "Medical",
	  ":e" = "Engineering", ".e" = "Engineering",
	  ":s" = "Security",	".s" = "Security",
	  ":w" = "whisper",		".w" = "whisper",
	  ":t" = "Mercenary",	".t" = "Mercenary",
	  ":u" = "Supply",		".u" = "Supply",
	  ":v" = "Service",		".v" = "Service",
	  ":p" = "AI Private",	".p" = "AI Private",
	  ":z" = "Entertainment",".z" = "Entertainment",

	  ":R" = "right ear",	".R" = "right ear",
	  ":L" = "left ear",	".L" = "left ear",
	  ":I" = "intercom",	".I" = "intercom",
	  ":B" = "harness", 	".B" = "harness",
	  ":H" = "department",	".H" = "department",
	  ":C" = "Command",		".C" = "Command",
	  ":N" = "Science",		".N" = "Science",
	  ":M" = "Medical",		".M" = "Medical",
	  ":E" = "Engineering",	".E" = "Engineering",
	  ":S" = "Security",	".S" = "Security",
	  ":W" = "whisper",		".W" = "whisper",
	  ":T" = "Mercenary",	".T" = "Mercenary",
	  ":U" = "Supply",		".U" = "Supply",
	  ":V" = "Service",		".V" = "Service",
	  ":P" = "AI Private",	".P" = "AI Private",
	  ":Z" = "Entertainment",".Z" = "Entertainment",

	  //kinda localization -- rastaf0
	  //same keys as above, but on russian keyboard layout. This file uses cp1251 as encoding.
	  ":ê" = "right ear",	".ê" = "right ear",
	  ":ä" = "left ear",	".ä" = "left ear",
	  ":ø" = "intercom",	".ø" = "intercom",
	 // ":b" = "harness", 	".b" = "harness", someone russian needs to handle this
	  ":ð" = "department",	".ð" = "department",
	  ":ñ" = "Command",		".ñ" = "Command",
	  ":ò" = "Science",		".ò" = "Science",
	  ":ü" = "Medical",		".ü" = "Medical",
	  ":ó" = "Engineering",	".ó" = "Engineering",
	  ":û" = "Security",	".û" = "Security",
	  ":ö" = "whisper",		".ö" = "whisper",
	  ":å" = "Mercenary",	".å" = "Mercenary",
	  ":ã" = "Supply",		".ã" = "Supply",
	  ":ì" = "Service",		".ì" = "Service",
	  ":ç" = "AI Private",	".ç" = "AI Private",
	  ":z" = "Entertainment",".z" = "Entertainment",
)

var/list/radio_prefixes = list(";", ":b", ":l", ":r", ":t", ":f",
	":B", ":L", ":R", ":T", ":F")

var/list/channel_to_radio_key = new
proc/get_radio_key_from_channel(var/channel)
	var/key = channel_to_radio_key[channel]
	if (!key)
		for (var/radio_key in department_radio_keys)
			if (department_radio_keys[radio_key] == channel)
				key = radio_key
				break
		if (!key)
			key = ""
		channel_to_radio_key[channel] = key

	return key

/mob/living/proc/binarycheck()
	return FALSE

/mob/living/proc/get_default_language()
	return default_language

/mob/living/proc/is_muzzled()
	return FALSE

/mob/living/proc/handle_speech_problems(var/message, var/verb)

	var/prefix = ""
	for (var/rp in radio_prefixes)
		if (dd_hasprefix(message, rp))
			prefix = copytext(message, 1, lentext(rp)+1)
			message = copytext(message, lentext(rp)+1, lentext(message)+1)

	var/list/returns[3]
	var/speech_problem_flag = FALSE

	if ((HULK in mutations) && health >= 25 && length(message))
		message = "[uppertext(message)]!!!"
		verb = pick("yells","roars","hollers")
		speech_problem_flag = TRUE

	if (slurring)
		message = slur(message)
		verb = pick("slobbers","slurs")
		speech_problem_flag = TRUE
	if (stuttering)
		message = stutter(message)
		verb = pick("stammers","stutters")
		speech_problem_flag = TRUE
	if (lisp)
		message = lisp(message, lisp)
		speech_problem_flag = TRUE

	returns[1] = prefix + message
	returns[2] = verb
	returns[3] = speech_problem_flag
	return returns

/mob/living/proc/handle_message_mode(message_mode, message, verb, speaking, used_radios, alt_name)
	if (message_mode == "intercom")
		for (var/obj/item/radio/intercom/I in view(1, null))
			I.talk_into(src, message, verb, speaking)
			used_radios += I
	return FALSE

/mob/living/proc/handle_speech_sound()
	var/list/returns[2]
	returns[1] = null
	returns[2] = null
	return returns

/mob/living/proc/get_speech_ending(verb, var/ending)
	if (ending=="!")
		return pick("exclaims","shouts","yells")
	if (ending=="?")
		return "asks"
	return verb

/mob/living/say(var/message, var/datum/language/speaking = null, var/verb="says", var/alt_name="", var/alt_message=null)
	if (client)
		if (client.prefs.muted & MUTE_IC)
			src << "<span class = 'red'>You cannot speak in IC (Muted).</span>"
			return

	if (stat)
		if (stat == 2)
			return say_dead(message)
		return

	var/message_mode = parse_message_mode(message, "headset")

	switch(copytext(message,1,2))
		if ("*") return emote(copytext(message,2))
		if ("^") return custom_emote(1, copytext(message,2))

	//parse the radio code and consume it
	if (message_mode)
		if (message_mode == "headset")
			message = copytext(message,2)	//it would be really nice if the parse procs could do this for us.
		else
			message = copytext(message,3)

	message = trim_left(message)

	//parse the language code and consume it
	if (!speaking)
		speaking = parse_language(message)

	if (speaking)
		message = copytext(message,2+length(speaking.key))
	else
		speaking = get_default_language()

	// This is broadcast to all mobs with the language,
	// irrespective of distance or anything else.
	if (speaking && (speaking.flags & HIVEMIND))
		speaking.broadcast(src,trim(message))
		return TRUE

	verb = say_quote(message, speaking)

	if (is_muzzled())
		src << "<span class='danger'>You're muzzled and cannot speak!</span>"
		return

	message = trim_left(message)

	if (!(speaking && (speaking.flags & NO_STUTTER)))

		if (slurring || stuttering || lisp)
			if (alt_message)
				message = alt_message // use the message with no HTML, because it gets fucked up

		var/list/handle_s = handle_speech_problems(message, verb)
		message = handle_s[1]
		verb = handle_s[2]

	if (!message || message == "")
		return FALSE

	var/list/obj/item/used_radios = new
	if (handle_message_mode(message_mode, message, verb, speaking, used_radios, alt_name))
		return TRUE

	var/list/handle_v = handle_speech_sound()
	var/sound/speech_sound = handle_v[1]
	var/sound_vol = handle_v[2]

	var/italics = FALSE
	var/message_range = world.view

	var/turf/T = get_turf(src)

	//handle nonverbal and sign languages here
	if (speaking)
		if (speaking.flags & NONVERBAL)
			if (prob(30))
				custom_emote(1, "[pick(speaking.signlang_verb)].")

		if (speaking.flags & SIGNLANG)
			return say_signlang(message, pick(speaking.signlang_verb), speaking)

	var/list/listening = list()
	var/list/listening_obj = list()

	if (T)
		//DO NOT FUCKING CHANGE THIS TO GET_OBJ_OR_MOB_AND_BULLSHIT() -- Hugs and Kisses ~Ccomp
		var/list/hear = hear(message_range,T)
		var/list/hearturfs = list()

		for (var/I in hear)
			if (ismob(I))
				var/mob/M = I
				listening += M
				hearturfs += M.locs[1]
			else if (isobj(I))
				var/obj/O = I
				hearturfs += O.locs[1]
				listening_obj |= O

		for (var/mob/M in player_list)
			if (M.stat == DEAD && M.is_preference_enabled(/datum/client_preference/ghost_ears))
				listening |= M
				continue
			if (M.loc && M.locs[1] in hearturfs)
				listening |= M

	var/speech_bubble_test = say_test(message)
	var/image/speech_bubble = image('icons/mob/talk.dmi',src,"h[speech_bubble_test]")
	spawn(30) qdel(speech_bubble)

	for (var/mob/M in listening)
		M << speech_bubble
		M.hear_say(message, verb, speaking, alt_name, italics, src, speech_sound, sound_vol)

	for (var/obj/O in listening_obj)
		spawn(0)
			if (O) //It's possible that it could be deleted in the meantime.
				O.hear_talk(src, message, verb, speaking)

	log_say("[name]/[key] : [message]")
	return TRUE

/mob/living/proc/say_signlang(var/message, var/verb="gestures", var/datum/language/language)
	for (var/mob/O in viewers(src, null))
		O.hear_signlang(message, verb, language, src)
	return TRUE

/obj/effect/speech_bubble
	var/mob/parent

/mob/living/proc/GetVoice()
	return name
