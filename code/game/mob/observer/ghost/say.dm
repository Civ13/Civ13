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
