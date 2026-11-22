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

/proc/offline_sleep_protection_map_allowed()
	return map && map.ID != MAP_NOMADS_GAIA

/mob/living/human/offline_sleep_protected()
	if (!inducedSSD || client || stat == DEAD || gc_destroyed || gcDestroyed)
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
	to_chat(user, SPAN_WARNING("[src] is sound asleep in bed while away. You cannot disturb them until they return."))
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
