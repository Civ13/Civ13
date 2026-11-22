// All mobs should have custom emote, really..
//m_type == TRUE --> visual.
//m_type == 2 --> audible
// TRUE for animals the server runs. Ghosts can mute their emotes from afar
// with the Ghost animal noises preference. Player-run mobs never count.
/mob/proc/makes_animal_noises()
	return FALSE

/mob/living/simple_animal/makes_animal_noises()
	return !client

// Human NPCs, hostages and wizards are people, not animals.
/mob/living/simple_animal/hostile/human/makes_animal_noises()
	return FALSE

/mob/living/simple_animal/hostage/makes_animal_noises()
	return FALSE

/mob/living/simple_animal/wizard/makes_animal_noises()
	return FALSE

/mob/proc/custom_emote(var/m_type=1,var/message = null,var/span_class = null)

	if (usr && stat || !use_me && usr == src)
		if (usr.stat != DEAD && usr.stat != UNCONSCIOUS) // fixes spam when you die? - Kachnov
			to_chat(src, "You are unable to emote.")
		return

	var/muzzled = istype(wear_mask, /obj/item/clothing/mask/muzzle) || istype(wear_mask, /obj/item/weapon/grenade)
	if (m_type == 2 && muzzled) return

	var/input
	if (!message)
		input = sanitize(player_input(src, "Choose an emote to display.", null, null, "text", null, TRUE))
	else
		input = message
	if (input)
		message = "<b>[src]</b> [input]"
	else
		return

	if (span_class)
		message = "<span class = '[span_class]'>[message]</span>"
	var/chat_message = CHAT_TYPED(CHAT_IC, message)

	if (message)
		if (client)
			log_emote("[name]/[key] : [message]")

 //Hearing gasp and such every five seconds is not good, emotes were not global for a reason.
 // Maybe some people are okay with that.

		var/animal_noise = makes_animal_noises()
		for (var/mob/M in player_list)
			if (!M.client)
				continue //skip monkeys and leavers
			if (istype(M, /mob/new_player))
				continue
			if (findtext(message," snores.")) //Because we have so many sleeping people.
				break
			if (M.ghost_hears_everywhere(/datum/client_preference/ghost_sight) && !(M in viewers(src,null)))
				if (animal_noise && !M.is_preference_enabled(/datum/client_preference/ghost_animals))
					continue
				M.show_message(chat_message, m_type)
				M.show_chat_overlay(src, message, "#FFC0CB")

		if (m_type & TRUE)
			var/list/see = get_mobs_or_objects_in_view(7,src) | viewers(get_turf(src), null)
			var/list/seen_objs = list()
			for (var/I in see)
				if (isobj(I))
					seen_objs += I
				else if (ismob(I))
					var/mob/M = I
					M.show_message(chat_message, TRUE)
					M.show_chat_overlay(src, message, "#FFC0CB")
			emote_notify_objects(seen_objs, message, TRUE)

		else if (m_type & 2)
			var/list/hear = get_mobs_or_objects_in_view(7,src)
			var/list/seen_objs = list()
			for (var/I in hear)
				if (isobj(I))
					seen_objs += I
				else if (ismob(I))
					var/mob/M = I
					M.show_message(chat_message, 2)
					M.show_chat_overlay(src, message, "#FFC0CB")
			emote_notify_objects(seen_objs, message, 2)

// One deferred pass over the objects that saw or heard an emote, rather than
// one spawned proc per object: a crowded view queued thousands of them.
/mob/proc/emote_notify_objects(list/objs, message, m_type)
	if (!length(objs))
		return
	spawn(0)
		for (var/obj/O in objs)
			if (!QDELETED(O)) //It's possible that it could be deleted in the meantime.
				O.see_emote(src, message, m_type)

/mob/proc/emote_dead(var/message)

	if (client.prefs.muted & MUTE_DEADCHAT)
		to_chat(src, "<span class='danger'>You cannot send deadchat emotes (muted).</span>")
		return

	if (!is_preference_enabled(/datum/client_preference/show_dsay))
		to_chat(src, "<span class='danger'>You have deadchat muted.</span>")
		return

	if (!client.holder)
		if (!config.dsay_allowed)
			to_chat(src, "<span class='danger'>Deadchat is globally muted.</span>")
			return


	var/input
	if (!message)
		input = sanitize(player_input(src, "Choose an emote to display.", null, null, "text", null, TRUE))
	else
		input = message

	if (input)
		log_emote("Ghost/[key] : [input]")
		say_dead_direct(input, src)
