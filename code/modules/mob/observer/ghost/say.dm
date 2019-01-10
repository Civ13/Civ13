/mob/observer/ghost/say(var/message)
	message = sanitize(message)

	if (!message)
		return

	log_say("Ghost/[key] : [message]")

	if (client)
		if (client.prefs.muted & MUTE_DEADCHAT)
			src << "<span class = 'red'>You cannot talk in deadchat (muted).</span>"
			return

		if (client.handle_spam_prevention(message,MUTE_DEADCHAT))
			return
		if (client && client.quickBan_isbanned("OOC"))
			src << "<span class = 'danger'>You're banned from OOC.</span>"
			return
	. = say_dead(message)


/mob/observer/ghost/emote(var/act, var/type, var/message)
	//message = sanitize(message) - already sanitized in verb/me_verb()

	if (!message)
		return

	if (act != "me")
		return

	log_emote("Ghost/[key] : [message]")

	if (client)
		if (client.prefs.muted & MUTE_DEADCHAT)
			src << "<span class = 'red'>You cannot emote in deadchat (muted).</span>"
			return

		if (client.handle_spam_prevention(message, MUTE_DEADCHAT))
			return

	. = emote_dead(message)

/*
	for (var/mob/M in hearers(null, null))
		if (!M.stat)
			if (M.job == "Monochurch Preacher")
				if (prob (49))
					M.show_message("<span class='game'><i>You hear muffled speech... but nothing is there...</i></span>", 2)
					if (prob(20))
						playsound(loc, pick('sound/effects/ghost.ogg','sound/effects/ghost2.ogg'), 10, TRUE)
				else
					M.show_message("<span class='game'><i>You hear muffled speech... you can almost make out some words...</i></span>", 2)
//				M.show_message("<span class='game'><i>[stutter(message)]</i></span>", 2)
					if (prob(30))
						playsound(loc, pick('sound/effects/ghost.ogg','sound/effects/ghost2.ogg'), 10, TRUE)
			else
				if (prob(50))
					return
				else if (prob (95))
					M.show_message("<span class='game'><i>You hear muffled speech... but nothing is there...</i></span>", 2)
					if (prob(20))
						playsound(loc, pick('sound/effects/ghost.ogg','sound/effects/ghost2.ogg'), 10, TRUE)
				else
					M.show_message("<span class='game'><i>You hear muffled speech... you can almost make out some words...</i></span>", 2)
//				M.show_message("<span class='game'><i>[stutter(message)]</i></span>", 2)
					playsound(loc, pick('sound/effects/ghost.ogg','sound/effects/ghost2.ogg'), 10, TRUE)
*/
