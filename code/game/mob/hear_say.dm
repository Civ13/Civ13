// At minimum every mob has a hear_say proc.
/mob/var/next_language_learn = -1
/mob/proc/hear_say(var/message, var/verb = "says", var/datum/language/language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null, var/sound/speech_sound, var/sound_vol, var/alt_message = null, var/animal = FALSE, var/original_message = "")
	if (!client)
		return

	if (speaker && !speaker.client && isghost(src) && is_preference_enabled(/datum/client_preference/ghost_ears) && !(speaker in view(src)))
			//Does the speaker have a client?  It's either random stuff that observers won't care about (Experiment 97B says, 'EHEHEHEHEHEHEHE')
			//Or someone snoring.  So we make it where they won't hear it.
		return

	//make sure the air can transmit speech - hearer's side
	original_message = message

	if (sleeping || stat == TRUE)
		hear_sleep(message)
		return

	//non-verbal languages are garbled if you can't see the speaker. Yes, this includes if they are inside a closet.
	if (language && (language.flags & NONVERBAL))
		if (!speaker || ((sdisabilities & BLIND) || blinded || find_trait("Blind")) || !(speaker in view(src)))
			message = stars(message)

	if (!(language && (language.flags & INNATE))) // skip understanding checks for INNATE languages
		if (!say_understands(speaker,language))
			if (istype(speaker,/mob/living/simple_animal))
				var/mob/living/simple_animal/S = speaker
				if (S && S.speak.len)
					message = pick(S.speak)
			else
				if (language)
					alt_message = language.scramble(alt_message, src)
					message = alt_message
				else
					message = stars(message)

	var/speaker_name = speaker.name
	if (istype(speaker, /mob/living/human))
		var/mob/living/human/H = speaker
		if (H.special_job_title != null)
			speaker_name = H.GetVoice()
		else
			speaker_name = "[H.GetVoice()] (N/A)"
		for(var/obj/structure/vehicleparts/frame/F1 in speaker.loc)
			for(var/obj/structure/vehicleparts/frame/F2 in src.loc)
				if (F1.axis == F2.axis)
					speaker_name = "<font color='yellow'>[speaker_name] (CREW)</font>"
					for (var/obj/structure/bed/chair/commander/D in speaker.loc)
						speaker_name = "<big><font color='yellow'>[speaker_name] (COMMANDER)</font></big>"
					for (var/obj/structure/bed/chair/drivers/D in speaker.loc)
						speaker_name = "<font color='yellow'>[speaker_name] (DRIVER)</font>"
					for (var/obj/structure/bed/chair/gunner/D in speaker.loc)
						speaker_name = "<font color='yellow'>[speaker_name] (GUNNER)</font>"
					for (var/obj/structure/bed/chair/loader/D in speaker.loc)
						speaker_name = "<font color='yellow'>[speaker_name] (LOADER)</font>"
	if (italics)
		message = "<i>[message]</i>"
	alt_name = speaker_name
	if (ishuman(speaker))
		var/mob/living/human/H = speaker
		if (istype(H.original_job, /datum/job/civilian/prisoner))
			alt_name = speaker.name

	if (animal)
		language = null
	var/track = null
	if (isghost(src))
		if (italics && is_preference_enabled(/datum/client_preference/ghost_radio))
			return
		if (speaker_name != speaker.real_name && speaker.real_name)
			speaker_name = "[speaker.real_name] ([speaker_name])"
		track = "([ghost_follow_link(speaker, src)]) "
		if (is_preference_enabled(/datum/client_preference/ghost_ears) && (speaker in view(src)))
			message = "<b>[message]</b>"

	if ((sdisabilities & DEAF) || ear_deaf || find_trait("Deaf"))
		if (!language || !(language.flags & INNATE)) // INNATE is the flag for audible-emote-language, so we don't want to show an "x talks but you cannot hear them" message if it's set
			if (speaker == src)
				src << "<span class='warning'>You cannot hear yourself speak!</span>"
			else
				src << "<span class='name'>[alt_name]</span> talks but you cannot hear."
	else
		if (language)
			on_hear_say("<span class='name'>[alt_name] <span class = 'small_message'>([language.name])</span> </span> [track][language.format_message(message, verb)]",speaker, alt_message)
		else
			on_hear_say("<span class='name'>[alt_name]</span> [track][verb], \"[message]\"",speaker, alt_message)
		if (speech_sound && (get_dist(speaker, src) <= 7 && z == speaker.z))
			var/turf/source = speaker? get_turf(speaker) : get_turf(src)
			playsound_local(source, speech_sound, sound_vol, TRUE)

	if (language && ishuman(src))
		var/mob/living/human/H = src
		if (!H.languages.Find(language) && world.time >= src.next_language_learn)
			src.next_language_learn = world.time + 10 // Cooldown is 10 ticks seconds = 1 seconds
			var/lname = capitalize(language.name)
			H.partial_languages[lname] += 1
			if (H.partial_languages[lname] >= language.difficulty)
				H.add_language("[lname]", FALSE)
				H.add_note("Known Languages", "[language.name]")
				H << "<span class = 'notice'>You've learned how to speak <b>[language.name]</b> from hearing it so much.</span>"

/mob/proc/on_hear_say(var/message, var/mob/speaker = null, var/message2 = "")
	to_chat(src, message)
	if (speaker && message2 != "")
		if (client && speaker.client && (speaker in view(7,src) || speaker == src))

			if (client.is_preference_enabled(/datum/client_preference/show_chat_overlays))
				var/obj/chat_text/CT = new/obj/chat_text(speaker,message2,src)
				client.seen_chat_text += CT
				if(speaker.client)
					speaker.client.stored_chat_text += CT

			if (config.tts_on && ishuman(src) && client.is_preference_enabled(/datum/client_preference/play_chat_tts))
				play_tts(message2, speaker)

/mob/proc/hear_radio(var/message, var/verb="says", var/datum/language/language=null, var/mob/speaker = null, var/obj/destination=null, var/obj/origin=null)

	if (!client || !message)
		return

	if (!destination && origin)
		destination = origin
	
	message = capitalize(message)
	message = replacetext(message, "&#39", "'")

	if (sleeping || stat== UNCONSCIOUS) //If unconscious or sleeping
		hear_sleep(message)
		return

	var/track = null

	//non-verbal languages are garbled if you can't see the speaker. Yes, this includes if they are inside a closet.
	if (language && (language.flags & NONVERBAL))
		if (!speaker || (sdisabilities & BLIND) || blinded || find_trait("Blind") || !(speaker in view(src)))
			message = stars(message)

	if (!(language && (language.flags & INNATE))) // skip understanding checks for INNATE languages
		if (!say_understands(speaker,language))
			if (istype(speaker,/mob/living/simple_animal))
				var/mob/living/simple_animal/S = speaker
				if (S.speak && S.speak.len)
					message = pick(S.speak)
				else
					return
			else
				if (language)
					message = language.scramble(message, src)
				else
					message = stars(message)

	var/speaker_name = speaker.name

	if (isghost(src))
		if (speaker_name != speaker.real_name) //Announce computer and various stuff that broadcasts doesn't use it's real name but AI's can't pretend to be other mobs.
			speaker_name = "[speaker.real_name] ([speaker_name])"
		track = "[speaker_name] ([ghost_follow_link(speaker, src)])"

	/*
	var/formatted
	if(language)
		formatted = language.format_message_radio(message, verb)
	else
		formatted = "[verb], <span class=\"body\">\"[message]\"</span>"
	*/

	if (dd_hasprefix(message, " "))
		message = copytext(message, 2)
	if (findtext(message,"10-") || findtext(message," 10-"))
		message = ten_code(message, speaker)
	if (findtext(message,"reploc") || findtext(message," reploc"))
		message = reploc(message, speaker)

	if ((sdisabilities & DEAF) || ear_deaf || find_trait("Deaf"))
		if (prob(20))
			src << "<span class='warning'>You feel the radio vibrate but can hear nothing from it!</span>"
	else
		var/fontsize = 2
		var/full_message = ""
		if (destination)
			if (istype(destination, /obj/structure/radio))
				var/obj/structure/radio/RD = destination
				var/khz = "([RD.freq] kHz)"
				if (RD)
					if(!isnum(RD.freq))
						khz = "([RD.freq])"
				if (RD)
					full_message = "<font size = [fontsize] color=#FFAE19><b>[destination.name], <i>[khz]</i>:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
					if (track)
						full_message = "<font size = [fontsize] color=#FFAE19><b>[destination.name], <i>[khz]</i>:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> [track] <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
			else
				var/obj/item/weapon/radio/RD = destination
				var/khz = "([RD.freq] kHz)"
				if (RD)
					if(!isnum(RD.freq))
						khz = "([RD.freq])"
				if (RD)
					full_message = "<font size = [fontsize] color=#FFAE19><b>[destination.name], <i>[khz]</i>:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
					if (track)
						full_message = "<font size = [fontsize] color=#FFAE19><b>[destination.name], <i>[khz]</i>:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> [track] <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
		else
			full_message = "<font size = [fontsize] color=#FFAE19><b>Radio:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
			if (track)
				full_message = "<font size = [fontsize] color=#FFAE19><b>Radio:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> [track] <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"


		on_hear_radio(destination, full_message)

/mob/proc/hear_phone(var/message, var/verb="says", var/datum/language/language=null, var/mob/speaker = null, var/obj/item/weapon/telephone/origin, var/obj/item/weapon/telephone/destination)

	if (!client || !message)
		return

	if (!destination && origin)
		destination = origin

	message = capitalize(message)
	message = replacetext(message, "&#39", "'")

	if (sleeping || stat==1) //If unconscious or sleeping
		hear_sleep(message)
		return

	var/track = null

	//non-verbal languages are garbled if you can't see the speaker. Yes, this includes if they are inside a closet.
	if (language && (language.flags & NONVERBAL))
		if (!speaker || (sdisabilities & BLIND) || blinded || find_trait("Blind") || !(speaker in view(src)))
			message = stars(message)

	if (!(language && (language.flags & INNATE))) // skip understanding checks for INNATE languages
		if (!say_understands(speaker,language))
			if (istype(speaker,/mob/living/simple_animal))
				var/mob/living/simple_animal/S = speaker
				if (S.speak && S.speak.len)
					message = pick(S.speak)
				else
					return
			else
				if (language)
					message = language.scramble(message, src)
				else
					message = stars(message)

	var/speaker_name = speaker.name

	if (isghost(src))
		if (speaker_name != speaker.real_name) //Announce computer and various stuff that broadcasts doesn't use it's real name but AI's can't pretend to be other mobs.
			speaker_name = "[speaker.real_name] ([speaker_name])"
		track = /*"[speaker_name] */"([ghost_follow_link(speaker, src)])"

	if (dd_hasprefix(message, " "))
		message = copytext(message, 2)

	if ((sdisabilities & DEAF) || ear_deaf || find_trait("Deaf"))
		if (prob(20))
			src << "<span class='warning'>You feel the telephone vibrate but can hear nothing from it!</span>"
	else
		var/fontsize = 2
		var/contactname = " "
		for (var/list/L in origin.contacts)
			if (L[2] == origin.phonenumber)
				contactname = "[L[1]] "
				break
		var/full_message = "<font size = [fontsize] color=#FFAE19><b>[contactname]([destination.phonenumber]):</font></b><font size = [fontsize]> <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
		if (track)
			full_message = "<font size = [fontsize] color=#FFAE19><b>[contactname]([destination.phonenumber]):</font></b><font size = [fontsize]> [track] <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
		on_hear_radio(destination, full_message)

/mob/proc/hear_voicepipe(var/message, var/verb="says", var/datum/language/language=null, var/mob/speaker = null, var/obj/structure/voyage/voicepipe/destination=null, var/obj/structure/voyage/voicepipe/origin=null)

	if (!client || !message)
		return

	if (!destination && origin)
		destination = origin
	
	message = capitalize(message)
	message = replacetext(message, "&#39", "'")

	if (sleeping || stat==1) //If unconscious or sleeping
		hear_sleep(message)
		return

	var/track = null

	//non-verbal languages are garbled if you can't see the speaker. Yes, this includes if they are inside a closet.
	if (language && (language.flags & NONVERBAL))
		if (!speaker || (sdisabilities & BLIND) || blinded || find_trait("Blind") || !(speaker in view(src)))
			message = stars(message)

	if (!(language && (language.flags & INNATE))) // skip understanding checks for INNATE languages
		if (!say_understands(speaker,language))
			if (istype(speaker,/mob/living/simple_animal))
				var/mob/living/simple_animal/S = speaker
				if (S.speak && S.speak.len)
					message = pick(S.speak)
				else
					return
			else
				if (language)
					message = language.scramble(message, src)
				else
					message = stars(message)

	var/speaker_name = speaker.name

	if (isghost(src))
		if (speaker_name != speaker.real_name) //Announce computer and various stuff that broadcasts doesn't use it's real name but AI's can't pretend to be other mobs.
			speaker_name = "[speaker.real_name] ([speaker_name])"
		track = /*"[speaker_name] */"([ghost_follow_link(speaker, src)])"

	if (dd_hasprefix(message, " "))
		message = copytext(message, 2)

	message = replacetext(message,";","")
	if ((sdisabilities & DEAF) || ear_deaf || find_trait("Deaf"))
		if (prob(20))
			src << "<span class='warning'>You feel the voicepipe vibrate but can hear nothing from it!</span>"
	else
		var/fontsize = 2
		var/full_message = ""
		if (destination)
			var/obj/structure/voyage/voicepipe/RD = destination
			if (RD)
				full_message = "<font size = [fontsize] color=#FFAE19><b>[destination.vp_reference]:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
				if (track)
					full_message = "<font size = [fontsize] color=#FFAE19><b>[destination.vp_reference]:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> [track] <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
		else
			full_message = "<font size = [fontsize] color=#FFAE19><b>Voicepipe:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"
			if (track)
				full_message = "<font size = [fontsize] color=#FFAE19><b>Voicepipe:</font></b><font size = [fontsize]> <b>[speaker.real_name]</b> [track] <span class = 'small_message'>([language.name])</span> \"[message]\"</font>"


		on_hear_radio(destination, full_message)

/proc/say_timestamp()
	return "<span class='say_quote'>\[[stationtime2text()]\]</span>"

/mob/proc/on_hear_radio(var/obj/destination = null, var/fullmessage)
	if (destination)
		src << "\icon[getFlatIcon(destination)] [fullmessage]"
	else
		src << fullmessage

/mob/proc/hear_signlang(var/message, var/verb = "gestures", var/datum/language/language, var/mob/speaker = null)
	if (!client)
		return

	if(say_understands(speaker, language))
		message = "<B>[speaker]</B> [verb], \"[message]\""
	else
		var/adverb
		var/length = length(message) * pick(0.8, 0.9, 1.0, 1.1, 1.2)	//Inserts a little fuzziness.
		switch(length)
			if(0 to 12) 	adverb = " briefly"
			if(12 to 30)	adverb = " a short message"
			if(30 to 48)	adverb = " a message"
			if(48 to 90)	adverb = " a lengthy message"
			else        	adverb = " a very lengthy message"
		message = "<B>[speaker]</B> [verb][adverb]."

	if (status_flags & PASSEMOTES)
		for (var/mob/living/M in contents)
			M.show_message(message)
	show_message(message)

/mob/proc/hear_sleep(var/message)
	var/heard = ""
	if (prob(15))
		var/list/punctuation = list(",", "!", ".", ";", "?")
		var/list/messages = splittext(message, " ")
		var/R = rand(1, messages.len)
		var/heardword = messages[R]
		if (copytext(heardword,1, TRUE) in punctuation)
			heardword = copytext(heardword,2)
		if (copytext(heardword,-1) in punctuation)
			heardword = copytext(heardword,1,length(heardword))
		heard = "<span class = 'game_say'>...You hear something about...[heardword]</span>"

	else
		heard = "<span class = 'game_say'>...<i>You almost hear someone talking</i>...</span>"

	to_chat(src, heard)

/* How this works:
 * just like in real life, some languages have mutual intelligibility
 * for example:
   * a guy who knows only Polish understands ~75% Ukrainian
   * a guy who knows Polish + Russian understands ~88% Ukrainian
   * a guy who knows only Russian understands ~66% Ukrainian

	- Kachnov
*/

/mob/proc/get_mutual_intelligibility(var/datum/language/reference)
	. = 0
	var/best_language = null
	for (var/datum/language/L in languages)
		if (L.mutual_intelligibility.Find(reference.type))
			var/_new = L.mutual_intelligibility[reference.type]
			if (_new > .)
				. = _new
				best_language = L
	for (var/datum/language/L in languages)
		if (L != best_language)
			if (L.mutual_intelligibility.Find(reference.type))
				. += L.mutual_intelligibility[reference.type]/5
	. = round(.)
	return .