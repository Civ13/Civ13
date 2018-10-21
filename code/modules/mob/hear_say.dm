// At minimum every mob has a hear_say proc.

/mob/proc/hear_say(var/message, var/verb = "says", var/datum/language/language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null, var/sound/speech_sound, var/sound_vol)
	if (!client)
		return

	if (speaker && !speaker.client && isghost(src) && is_preference_enabled(/datum/client_preference/ghost_ears) && !(speaker in view(src)))
			//Does the speaker have a client?  It's either random stuff that observers won't care about (Experiment 97B says, 'EHEHEHEHEHEHEHE')
			//Or someone snoring.  So we make it where they won't hear it.
		return

	//make sure the air can transmit speech - hearer's side

	if (sleeping || stat == TRUE)
		hear_sleep(message)
		return

	//non-verbal languages are garbled if you can't see the speaker. Yes, this includes if they are inside a closet.
	if (language && (language.flags & NONVERBAL))
		if (!speaker || (sdisabilities & BLIND || blinded) || !(speaker in view(src)))
			message = stars(message)

	if (!(language && (language.flags & INNATE))) // skip understanding checks for INNATE languages
		if (!say_understands(speaker,language))
			if (istype(speaker,/mob/living/simple_animal))
				var/mob/living/simple_animal/S = speaker
				message = pick(S.speak)
			else
				if (language)
					message = language.scramble(message, src)
				else
					message = stars(message)

	var/speaker_name = speaker.name
	if (istype(speaker, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = speaker
		if (H.special_job_title != null)
			speaker_name = H.rank_prefix_name(H.GetVoice())
		else
			speaker_name = "[H.GetVoice()] (N/A)"

	if (italics)
		message = "<i>[message]</i>"

	var/track = null
	if (isghost(src))
		if (italics && is_preference_enabled(/datum/client_preference/ghost_radio))
			return
		if (speaker_name != speaker.real_name && speaker.real_name)
			speaker_name = "[speaker.real_name] ([speaker_name])"
		track = "([ghost_follow_link(speaker, src)]) "
		if (is_preference_enabled(/datum/client_preference/ghost_ears) && (speaker in view(src)))
			message = "<b>[message]</b>"

	if (sdisabilities & DEAF || ear_deaf)
		if (!language || !(language.flags & INNATE)) // INNATE is the flag for audible-emote-language, so we don't want to show an "x talks but you cannot hear them" message if it's set
			if (speaker == src)
				src << "<span class='warning'>You cannot hear yourself speak!</span>"
			else
				src << "<span class='name'>[speaker_name]</span>[alt_name] talks but you cannot hear \him."
	else
		if (language)
			on_hear_say("<span class='name'>[speaker_name] <span class = 'small_message'>([language.name])</span> </span>[alt_name] [track][language.format_message(message, verb)]")
		else
			on_hear_say("<span class='name'>[speaker_name]</span>[alt_name] [track][verb], \"[message]\"")
		if (speech_sound && (get_dist(speaker, src) <= world.view && z == speaker.z))
			var/turf/source = speaker? get_turf(speaker) : get_turf(src)
			playsound_local(source, speech_sound, sound_vol, TRUE)

	if (language && ishuman(src))
		var/mob/living/carbon/human/H = src
		if (!H.languages.Find(language))
			var/lname = capitalize(language.name)
			H.partial_languages[lname] += 1
			if (H.partial_languages[lname] > rand(200,250))
				H.add_language(language, TRUE)
				H.add_note("Known Languages", "[language.name]")
				H << "<span class = 'notice'>You've learned how to speak <b>[language.name]</b> from hearing it so much.</span>"

/mob/proc/on_hear_say(var/message)
	src << message


/proc/say_timestamp()
	return "<span class='say_quote'>\[[stationtime2text()]\]</span>"

/mob/proc/hear_signlang(var/message, var/verb = "gestures", var/datum/language/language, var/mob/speaker = null)
	if (!client)
		return

	if (say_understands(speaker, language))
		message = "<b>[src]</b> [verb], \"[message]\""
	else
		message = "<b>[src]</b> [verb]."

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
			heardword = copytext(heardword,1,lentext(heardword))
		heard = "<span class = 'game_say'>...You hear something about...[heardword]</span>"

	else
		heard = "<span class = 'game_say'>...<i>You almost hear someone talking</i>...</span>"

	src << heard

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