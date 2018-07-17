/obj/item/assembly/voice
	name = "voice analyzer"
	desc = "A small electronic device able to record a voice sample, and send a signal when that sample is repeated."
	icon_state = "voice"
//	origin_tech = list(TECH_MAGNET = TRUE)
	matter = list(DEFAULT_WALL_MATERIAL = 500, "glass" = 50, "waste" = 10)
	var/listening = FALSE
	var/recorded	//the activation message

/obj/item/assembly/voice/hear_talk(mob/living/M as mob, msg)
	if (listening)
		recorded = msg
		listening = FALSE
		var/turf/T = get_turf(src)	//otherwise it won't work in hand
		T.visible_message("\icon[src] beeps, \"Activation message is '[recorded]'.\"")
	else
		if (findtext(msg, recorded))
			pulse(0)

/obj/item/assembly/voice/activate()
	if (secured)
		if (!holder)
			listening = !listening
			var/turf/T = get_turf(src)
			T.visible_message("\icon[src] beeps, \"[listening ? "Now" : "No longer"] recording input.\"")


/obj/item/assembly/voice/attack_self(mob/user)
	if (!user)	return FALSE
	activate()
	return TRUE


/obj/item/assembly/voice/toggle_secure()
	. = ..()
	listening = FALSE