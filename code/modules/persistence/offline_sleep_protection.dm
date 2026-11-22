// Offline sleep protection: a character who used Sleep on a bed and waited out
// its two minutes, then logged off, cannot be harmed, stripped, moved or
// operated on until the player comes back. Durable Gaia is excluded: sleepers
// there stay as vulnerable as before. Protection is a live check, not a flag,
// so it ends by itself the moment a client returns to the body, if the body
// wakes, or if it is no longer lying on a bed. Logging off without Sleep never
// sets inducedSSD, so an improper logout is never protected.
//
// Anti-abuse: a protected sleeper never blocks movement, projectiles or thrown
// things (CanPass below), so a body on a bed in a doorway is not a wall, and
// its bed cannot be dismantled or unfastened to trap it (bed attackby).

/mob/living/proc/offline_sleep_protected()
	return FALSE

// Set by an administrator or a god who lifted this sleeper's protection after
// an adminhelp or prayer. Saved with the body; the next completed Sleep clears it.
/mob/living/human/var/offline_sleep_protection_lifted = FALSE

/proc/offline_sleep_protection_map_allowed()
	return map && map.ID != MAP_NOMADS_GAIA

/mob/living/human/offline_sleep_protected()
	if (!inducedSSD || client || offline_sleep_protection_lifted || stat == DEAD || gc_destroyed || gcDestroyed)
		return FALSE
	if (!isturf(loc) || !offline_sleep_protection_map_allowed())
		return FALSE
	for (var/obj/structure/bed/B in loc)
		if (B.anchored && B.buckle_lying)
			return TRUE
	return FALSE

// TRUE (and tells the actor why) when someone else tries to act on a protected sleeper.
/mob/living/proc/offline_sleep_refuses(mob/user)
	if (!user || user == src || !offline_sleep_protected())
		return FALSE
	to_chat(user, SPAN_WARNING("[src] is sound asleep in bed while away. You cannot disturb them until they return. If they are misusing this, adminhelp or pray to ask for it to be lifted."))
	return TRUE

// A protected sleeper never blocks a tile, so a bed cannot be used as a barricade.
/mob/living/human/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (mover && offline_sleep_protected())
		return TRUE
	return ..()

// The bed under a protected sleeper, which cannot be dismantled, unfastened or re-buckled.
/obj/structure/bed/proc/offline_sleeper_here()
	if (!isturf(loc))
		return null
	for (var/mob/living/human/H in loc)
		if (H.offline_sleep_protected())
			return H
	return null

/obj/structure/bed/proc/offline_sleeper_refuses(mob/user)
	var/mob/living/human/H = offline_sleeper_here()
	if (!H || H == user)
		return FALSE
	to_chat(user, SPAN_WARNING("[H] is sound asleep in \the [src] while away. Leave the bed alone until they return."))
	return TRUE

// Drops any pull or grab still on the body once its player has left, so a hold
// taken during the two-minute wait cannot be used to drag the sleeper away.
/mob/living/human/proc/offline_sleep_release_holds()
	if (!offline_sleep_protected())
		return
	if (pulledby)
		pulledby.stop_pulling()
	for (var/obj/item/weapon/grab/G in grabbed_by)
		qdel(G)

// Staff, and staff playing a god, lift one sleeper's protection on request.
/client/proc/cmd_admin_lift_sleep_protection()
	set category = "Admin"
	set name = "Lift Sleep Protection"
	set desc = "Remove a logged-off sleeper's protection after an adminhelp or prayer asks for it."
	if (!check_rights(R_ADMIN))
		return
	var/list/choices = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.offline_sleep_protected())
			var/turf/T = get_turf(H)
			choices["[H.real_name] ([H.ckey ? H.ckey : "no key"]) at [T.x],[T.y],[T.z]"] = H
	if (!choices.len)
		to_chat(src, SPAN_NOTICE("No logged-off sleeper is protected right now."))
		return
	var/picked = player_input(src.mob, "Lift whose sleep protection? It stays off until they next finish Sleep.", "Lift Sleep Protection", null, "anything", sortList(choices), TRUE)
	var/mob/living/human/H = choices[picked]
	if (!H || QDELETED(H) || !check_rights(R_ADMIN))
		return
	var/reason = sanitize(player_input(src.mob, "Why? This goes in the admin log.", "Lift Sleep Protection", null, "text", null, TRUE))
	if (!reason || QDELETED(H) || !check_rights(R_ADMIN))
		return
	if (!H.offline_sleep_protected())
		to_chat(src, SPAN_NOTICE("[H.real_name] is no longer protected."))
		return
	H.offline_sleep_protection_lifted = TRUE
	to_chat(src, SPAN_NOTICE("[H.real_name] is no longer protected while asleep."))
	log_admin("[key_name(src)] lifted the sleep protection of [key_name(H)]: [reason]")
	message_admins("[key_name_admin(src)] lifted the sleep protection of [key_name_admin(H)]: [reason]")

/mob/observer/ghost/proc/divine_lift_sleep_protection()
	set category = "Divine"
	set name = "Lift Sleep Protection"
	set desc = "Remove a logged-off sleeper's protection when a prayer asks for it."
	if (!divine_allowed())
		return
	client.cmd_admin_lift_sleep_protection()
