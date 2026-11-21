// ============================================================
// Rigging and sail handling (docs/hull-ledger.md)
// ------------------------------------------------------------
// A mast standing on a built hull carries its sail one of three ways:
// furled, reefed or full. Full is how every sail was always carried and is
// what a mast starts with, so a hull nobody touches sails as she did.
//
// - Click a rigged mast to set full sail, reef or furl. It takes four
//   seconds and can be done under way.
// - A reefed sail pushes six tenths of a full one. A furled sail pushes
//   nothing.
// - In a strong wind (3 and up) a full sail may tear: about one chance in
//   seven each half minute under way. In a gale (4) a reefed sail may tear
//   too, one in twenty. A furled sail is safe.
// - A torn sail pushes three tenths of what it did until it is mended: two
//   pieces of cloth used on the mast, six seconds.
//
// Tearing is rolled in the ledger step from her drives, with no deck walk.
// Small craft are left out of the tearing. Masts fitted to a modular ship's
// frame are not touched by any of this.
// ============================================================

#define SAIL_FURLED 0
#define SAIL_REEFED 1
#define SAIL_FULL 2

#define SAIL_REEF_PUSH 0.6
#define SAIL_TORN_PUSH 0.3
#define SAIL_HANDLE_TIME 40
#define SAIL_MEND_TIME 60
#define SAIL_MEND_CLOTH 2
#define SAIL_TEAR_WIND 3
#define SAIL_GALE_WIND 4
// Chances in a hundred a half minute.
#define SAIL_TEAR_FULL 15
#define SAIL_TEAR_REEFED 5

/obj/structure/vehicleparts/movement/sail
	// How her sail is carried, and whether it is torn.
	var/canvas = SAIL_FULL
	var/torn = FALSE
	var/tmp/handling = FALSE

/obj/structure/vehicleparts/movement/sail/persistence_runtime_var(key)
	return key == "handling" || key == "tree_climber" || ..()

// TRUE for a mast standing free on a deck with a sail rigged.
/obj/structure/vehicleparts/movement/sail/proc/handled_here()
	return isturf(loc) && !axis && sails && !broken

/obj/structure/vehicleparts/movement/sail/proc/canvas_name()
	switch (canvas)
		if (SAIL_FURLED)
			return "furled"
		if (SAIL_REEFED)
			return "reefed"
	return "set full"

// A furled sail is drawn as a sail that is not drawing.
/obj/structure/vehicleparts/movement/sail/update_icon()
	..()
	if (sails && sails_on && canvas == SAIL_FURLED && !axis)
		icon_state = base_icon

/obj/structure/vehicleparts/movement/sail/examine(mob/user, distance = -1)
	. = ..()
	aloft_examine(user) // hull_masts.dm
	if (handled_here())
		to_chat(user, SPAN_NOTICE("Her sail is [canvas_name()][torn ? " and <b>torn</b>: [SAIL_MEND_CLOTH] pieces of cloth used on the mast mend it" : ""]. Click the mast to set, reef or furl it."))

// A furled sail drives nothing.
/datum/craft_drive/fitted/sail/ready()
	. = ..()
	if (.)
		var/obj/structure/vehicleparts/movement/sail/M = source
		return M.canvas != SAIL_FURLED

/datum/craft_drive/fitted/sail/push()
	. = ..()
	if (!.)
		return
	var/obj/structure/vehicleparts/movement/sail/M = source
	if (M.canvas == SAIL_REEFED)
		. *= SAIL_REEF_PUSH
	if (M.torn)
		. *= SAIL_TORN_PUSH
	return round(.)

// A wait that a step of the hull under the worker does not spoil: the hull
// carries worker and work together, so the wait starts again.
/proc/hull_wait(mob/living/H, time, atom/target)
	for (var/tries = 1, tries <= 20, tries++)
		var/off_x = H.x - target.x
		var/off_y = H.y - target.y
		var/began = world.time
		if (do_after(H, time, target))
			return TRUE
		if (QDELETED(H) || QDELETED(target) || world.time <= began || H.x - target.x != off_x || H.y - target.y != off_y || H.stat || H.lying)
			return FALSE
		var/datum/hull_ledger/L = hull_ledger_at(get_turf(target))
		if (!L || !L.under_way())
			return FALSE
	return FALSE

// H carries her sail a new way. TRUE when it was done.
/obj/structure/vehicleparts/movement/sail/proc/handle_sail(mob/living/H, new_canvas)
	if (!handled_here() || handling || new_canvas == canvas)
		return FALSE
	if (!istype(H) || H.stat || H.lying || H.restrained() || get_dist(H, src) > 1)
		return FALSE
	handling = TRUE
	var/list/doing = list("furling", "reefing", "setting")
	H.visible_message(SPAN_NOTICE("[H] starts [doing[new_canvas + 1]] the sail of \the [src]."), SPAN_NOTICE("You start [doing[new_canvas + 1]] the sail."))
	var/done = hull_wait(H, SAIL_HANDLE_TIME, src)
	handling = FALSE
	if (!done || QDELETED(src) || !handled_here())
		return FALSE
	set_canvas(new_canvas)
	to_chat(H, SPAN_NOTICE("The sail is [canvas_name()]."))
	return TRUE

// Carries the sail a new way and tells the hull under it.
/obj/structure/vehicleparts/movement/sail/proc/set_canvas(new_canvas)
	canvas = clamp(new_canvas, SAIL_FURLED, SAIL_FULL)
	update_icon()
	var/datum/craft/C = isturf(loc) ? craft_at(loc) : null
	if (C && C.ledger)
		C.sail_trim()

/obj/structure/vehicleparts/movement/sail/attack_hand(mob/living/human/H)
	if (mast_grab_climb(H)) // grab intent climbs her (hull_masts.dm)
		return
	if (!istype(H) || !handled_here() || !hull_ledger_at(get_turf(src)))
		return ..()
	var/list/choices = list()
	if (canvas != SAIL_FULL)
		choices += "Set full sail"
	if (canvas != SAIL_REEFED)
		choices += "Reef"
	if (canvas != SAIL_FURLED)
		choices += "Furl"
	var/picked = player_input(H, "Her sail is [canvas_name()][torn ? " and torn" : ""]. A reefed sail pushes less and stands a strong wind; a furled sail pushes nothing and is safe in a gale.", name, null, "list", choices, TRUE)
	if (!picked || QDELETED(src) || get_dist(H, src) > 1)
		return
	switch (picked)
		if ("Set full sail")
			handle_sail(H, SAIL_FULL)
		if ("Reef")
			handle_sail(H, SAIL_REEFED)
		if ("Furl")
			handle_sail(H, SAIL_FURLED)

// Cloth on a torn sail mends it.
/obj/structure/vehicleparts/movement/sail/attackby(obj/item/I, mob/living/human/H)
	if (fit_crows_nest(I, H)) // wood builds a crow's nest (hull_masts.dm)
		return TRUE
	if (torn && handled_here() && istype(I, /obj/item/stack/material/cloth) && istype(H))
		var/obj/item/stack/material/cloth/S = I
		if (S.amount < SAIL_MEND_CLOTH)
			to_chat(H, SPAN_WARNING("Mending the sail takes [SAIL_MEND_CLOTH] pieces of cloth."))
			return TRUE
		if (handling)
			return TRUE
		handling = TRUE
		H.visible_message(SPAN_NOTICE("[H] starts mending the sail of \the [src]."), SPAN_NOTICE("You start stitching a patch into the sail."))
		var/done = hull_wait(H, SAIL_MEND_TIME, src)
		handling = FALSE
		if (done && !QDELETED(src) && !QDELETED(S) && torn && S.use(SAIL_MEND_CLOTH))
			mend_sail()
			to_chat(H, SPAN_NOTICE("The sail is whole again."))
		return TRUE
	return ..()

/obj/structure/vehicleparts/movement/sail/proc/mend_sail()
	torn = FALSE
	var/datum/craft/C = isturf(loc) ? craft_at(loc) : null
	if (C && C.ledger)
		C.sail_trim()

/datum/hull_ledger
	var/tmp/gale_told = FALSE

// The chance in a hundred that this canvas tears in this wind in a half minute.
/proc/sail_tear_chance(canvas, wind)
	if (wind < SAIL_TEAR_WIND || canvas == SAIL_FURLED)
		return 0
	if (canvas == SAIL_FULL)
		return SAIL_TEAR_FULL
	return wind >= SAIL_GALE_WIND ? SAIL_TEAR_REEFED : 0

// One step of what the wind does to her sails. Returns the sails torn.
/datum/hull_ledger/proc/step_rigging(seconds)
	. = 0
	if (!craft || !craft.body || hull_class() == HULL_CLASS_SMALL || !under_way())
		gale_told = FALSE
		return
	var/turf/at = craft.body.origin()
	var/wind = at ? weather_wind_at(at) : 0
	if (wind < SAIL_TEAR_WIND)
		gale_told = FALSE
		return
	var/at_risk = 0
	for (var/datum/craft_drive/fitted/sail/D in craft.drives)
		var/obj/structure/vehicleparts/movement/sail/M = D.source
		if (!istype(M) || QDELETED(M) || M.torn || !D.ready())
			continue
		var/chance = sail_tear_chance(M.canvas, wind)
		if (!chance)
			continue
		at_risk++
		if (prob(chance * seconds / 30))
			M.torn = TRUE
			.++
			craft.crew_message(SPAN_DANGER("A sail of the [craft.name] tears in the wind! It pushes little until it is mended with [SAIL_MEND_CLOTH] pieces of cloth used on its mast."))
	if (at_risk && !gale_told)
		gale_told = TRUE
		craft.crew_message(SPAN_WARNING("The wind is strong enough to tear the sails of the [craft.name]. Click her masts to reef or furl them."))
	if (.)
		craft.sail_trim()

// How her sails are carried, for the tiller.
/datum/hull_ledger/proc/rigging_text()
	if (!craft)
		return ""
	var/full = 0
	var/reefed = 0
	var/furled = 0
	var/ripped = 0
	for (var/datum/craft_drive/fitted/sail/D in craft.drives)
		var/obj/structure/vehicleparts/movement/sail/M = D.source
		if (!istype(M) || QDELETED(M) || !M.sails || M.broken)
			continue
		switch (M.canvas)
			if (SAIL_FURLED)
				furled++
			if (SAIL_REEFED)
				reefed++
			else
				full++
		if (M.torn)
			ripped++
	if (!reefed && !furled && !ripped)
		return ""
	var/list/parts = list()
	if (full)
		parts += "[full] set full"
	if (reefed)
		parts += "[reefed] reefed"
	if (furled)
		parts += "[furled] furled"
	return " Her sails: [english_list(parts)][ripped ? ", <b>[ripped] torn</b>" : ""]."

#undef SAIL_REEF_PUSH
#undef SAIL_TORN_PUSH
#undef SAIL_HANDLE_TIME
#undef SAIL_MEND_TIME
#undef SAIL_MEND_CLOTH
#undef SAIL_TEAR_WIND
#undef SAIL_GALE_WIND
#undef SAIL_TEAR_FULL
#undef SAIL_TEAR_REEFED
