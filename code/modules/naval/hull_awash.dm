// ============================================================
// A deck awash (docs/hull-ledger.md)
// ------------------------------------------------------------
// When the bilge of a hull is awash or worse, water is drawn washing over
// her planks, so the crew can see the state she is in without asking the
// tiller. The film lies on the planks themselves, under whatever stands on
// them, and goes when she is bailed below awash.
//
// The art is icons/effects/hull_awash.dmi, drawn by
// scripts/draw_hull_awash.py. Nothing here is saved.
// ============================================================

var/global/image/hull_awash_image = null

/proc/hull_awash_overlay()
	if (!hull_awash_image)
		hull_awash_image = image(icon = 'icons/effects/hull_awash.dmi', icon_state = "awash")
	return hull_awash_image

/datum/hull_ledger
	// The planks the film is drawn on now.
	var/tmp/list/awash_planks = list()

// TRUE when her deck should be drawn awash.
/datum/hull_ledger/proc/deck_awash()
	return craft && craft.body && craft.body.placed() && depth() >= HULL_DEPTH_AWASH

// Draws or clears the film to match her bilge. Returns the planks drawn on.
/datum/hull_ledger/proc/show_awash()
	var/want = deck_awash()
	if (!want && !awash_planks.len)
		return 0
	var/image/film = hull_awash_overlay()
	for (var/obj/covers/C in awash_planks)
		if (!QDELETED(C))
			C.overlays -= film
	awash_planks = list()
	if (!want)
		return 0
	for (var/turf/T in craft.body.cells())
		for (var/obj/covers/C in T)
			if (hull_floor_plank(C, T))
				C.overlays += film
				awash_planks += C
				break
	return awash_planks.len

/datum/hull_ledger/add_water(amount, cap = null, turf/at = null)
	. = ..()
	if (deck_awash() != (awash_planks.len > 0))
		show_awash()

/datum/hull_ledger/remove_water(amount, turf/at = null)
	. = ..()
	if (deck_awash() != (awash_planks.len > 0))
		show_awash()

// Each step lays the film again, for planks laid, lost or redrawn since.
/datum/hull_ledger/step_ledger(seconds)
	..()
	show_awash()

/datum/hull_ledger/Destroy()
	if (awash_planks && awash_planks.len)
		var/image/film = hull_awash_overlay()
		for (var/obj/covers/C in awash_planks)
			if (!QDELETED(C))
				C.overlays -= film
	awash_planks = null
	return ..()
