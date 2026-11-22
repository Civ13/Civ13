// ============================================================
// Emergency exits from land vehicles (docs/vessel-entries.md, phase 5)
// ------------------------------------------------------------
// A locked door opens from inside: a car's inside handle, a bus's emergency
// release. The lock keeps people out, never in. It takes a moment, and the
// door is then unlocked and open, the way the key leaves it.
//
// A tank (a vehicle on a heavy axis) has an escape hatch in her belly. From
// inside, a crewman can drop through it and crawl out from under her onto
// the nearest clear ground beside her, while she is stopped. It is an exit
// only: it is secured from inside and cannot be opened from under her.
// ============================================================

#define VEHICLE_RELEASE_TIME (1.5 SECONDS)
#define VEHICLE_BELLY_HATCH_TIME (6 SECONDS)

// Inside a locked door: work the handle or the emergency release.
/obj/structure/vehicleparts/frame/proc/inside_release(mob/living/human/user)
	user.visible_message(SPAN_NOTICE("[user] works the release of the door of \the [src]."), SPAN_NOTICE("The door is locked. You work the inside release..."))
	if (!do_after(user, VEHICLE_RELEASE_TIME, src))
		return FALSE
	if (QDELETED(src) || !door_inside(user) || doors_open())
		return FALSE
	door_unlocked = TRUE
	set_doors_open(TRUE)
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 40)
	user.visible_message("[user] opens the door of \the [src] from inside.", "The release gives and the door swings open.")
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	return TRUE

// TRUE on a frame of a tank: a vehicle on a heavy axis.
/obj/structure/vehicleparts/frame/proc/has_belly_hatch()
	return istype(axis, /obj/structure/vehicleparts/axis/heavy)

// The nearest clear ground beside her that is not under her, or null.
/obj/structure/vehicleparts/frame/proc/belly_hatch_exit(mob/user)
	var/turf/here = get_turf(user)
	if (!here)
		return null
	var/best = null
	var/best_dist = 1000
	for (var/turf/T in range(3, here))
		if (T.density || T.z != here.z || istype(T, /turf/floor/beach/water/deep))
			continue
		var/blocked = FALSE
		for (var/obj/O in T)
			if (istype(O, /obj/structure/vehicleparts) || (O.density && O.anchored))
				blocked = TRUE
				break
		if (blocked)
			continue
		var/d = get_dist(here, T)
		if (d < best_dist)
			best = T
			best_dist = d
	return best

// Why the escape hatch cannot be used now, or null.
/obj/structure/vehicleparts/frame/proc/belly_hatch_refusal(mob/living/human/H)
	if (!has_belly_hatch())
		return "She has no escape hatch."
	if (!door_inside(H))
		return "The escape hatch opens only from inside her."
	if (H.travel_held())
		return "You cannot do that now."
	if (axis && (axis.moving || axis.currentspeed > 0))
		return "She must be stopped before you drop through the escape hatch."
	if (!belly_hatch_exit(H))
		return "There is no clear ground beside her to crawl out onto."
	return null

// Drops H through the escape hatch and out from under her. Returns the turf
// they crawled out onto, or null.
/obj/structure/vehicleparts/frame/proc/use_belly_hatch(mob/living/human/H, instant = FALSE)
	var/why = belly_hatch_refusal(H)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return null
	if (!instant)
		H.visible_message(SPAN_NOTICE("[H] knocks open the escape hatch in the floor of \the [src]."), SPAN_NOTICE("You knock open the escape hatch and start squeezing down through it..."))
		if (!do_after(H, VEHICLE_BELLY_HATCH_TIME, src))
			return null
		why = belly_hatch_refusal(H)
		if (why)
			to_chat(H, SPAN_WARNING(why))
			return null
	var/turf/T = belly_hatch_exit(H)
	H.forceMove(T)
	H.Weaken(2)
	H.visible_message(SPAN_NOTICE("[H] crawls out from under \the [src]."), SPAN_NOTICE("You drop through the escape hatch and crawl out from under her."))
	log_game("[key_name(H)] left [src] through its escape hatch at [T.x],[T.y],[T.z].")
	return T

/obj/structure/vehicleparts/frame/verb/escape_hatch_verb()
	set name = "Drop through the escape hatch"
	set category = null
	set src in view(0)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated())
		return
	use_belly_hatch(H)

#undef VEHICLE_RELEASE_TIME
#undef VEHICLE_BELLY_HATCH_TIME
