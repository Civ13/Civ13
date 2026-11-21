// ============================================================
// Anchors, mooring and drift (docs/hull-ledger.md)
// ------------------------------------------------------------
// "Anchor down" at the helm used to be a free flag. A boat or ship now
// needs something to lie to:
//
// - An anchor built on her deck. A killick, wood weighted with stone, holds
//   40 tiles of hull; an iron anchor holds 100. Their holding adds up, and
//   it has to cover every tile of her.
// - Or a mooring: a mooring post or a bollard within two tiles of her. Her
//   lines go to it when her anchor is called down beside one.
//
// The helm order is never refused: a hull with nothing to hold her lies to.
// Lying to, or with her anchor up and no way on, she drifts while anyone is
// aboard: a tile every half minute with the current where there is one, and
// otherwise before a wind of 2 or more. Nobody aboard, she stays where she
// was left. Shore and other hulls stop her.
//
// Small craft need no anchor. A hull that was afloat before anchors were
// things keeps the one she always had (saved as "old_anchor").
// ============================================================

#define HULL_ANCHOR_REACH 2
#define HULL_DRIFT_WIND 2

var/global/list/hull_anchors = list()

/obj/structure/hull_anchor
	name = "iron anchor"
	desc = "An iron anchor with its cable, for a boat or ship. Built on her deck it holds 100 tiles of hull when her anchor is called down at the helm."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "anchor"
	layer = 3.1
	density = FALSE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = FALSE
	// Tiles of hull it holds.
	var/holds = 100

/obj/structure/hull_anchor/stone
	name = "killick"
	desc = "A wooden anchor weighted with a stone, on a rope cable. Built on her deck it holds 40 tiles of hull when her anchor is called down at the helm."
	icon = 'icons/obj/hull_gear.dmi'
	icon_state = "killick"
	holds = 40

/obj/structure/hull_anchor/New()
	..()
	hull_anchors |= src

/obj/structure/hull_anchor/on_runtime_spawn()
	..()
	hull_anchors |= src

/obj/structure/hull_anchor/Destroy()
	hull_anchors -= src
	return ..()

/obj/structure/hull_anchor/hull_load()
	return holds / 100

/obj/structure/hull_anchor/examine(mob/user, distance = -1)
	. = ..()
	var/datum/hull_ledger/L = hull_ledger_at(get_turf(src))
	if (L && L.craft)
		to_chat(user, SPAN_NOTICE("Aboard the [L.craft.name]: [L.hold_text()]"))
	else
		to_chat(user, SPAN_NOTICE("It holds nothing here. An anchor has to be built on the deck of a commissioned hull."))

/datum/hull_ledger
	// She was afloat before anchors were things and keeps the one she had.
	var/old_anchor = FALSE
	var/tmp/drift_told = FALSE

// TRUE when she needs something to lie to.
/datum/hull_ledger/proc/needs_anchor()
	return hull_class() != HULL_CLASS_SMALL

// Tiles of hull her anchors hold.
/datum/hull_ledger/proc/holding()
	. = old_anchor ? tiles : 0
	for (var/obj/structure/hull_anchor/A in hull_anchors)
		if (!QDELETED(A) && deck_holds(get_turf(A)))
			. += A.holds

// The mooring post or bollard within reach of her, or null.
/datum/hull_ledger/proc/mooring()
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || !B.placed())
		return null
	var/min_x = world.maxx
	var/min_y = world.maxy
	var/max_x = 1
	var/max_y = 1
	for (var/turf/T in B.cells())
		min_x = min(min_x, T.x)
		min_y = min(min_y, T.y)
		max_x = max(max_x, T.x)
		max_y = max(max_y, T.y)
	if (max_x < min_x)
		return null
	min_x = max(1, min_x - HULL_ANCHOR_REACH)
	min_y = max(1, min_y - HULL_ANCHOR_REACH)
	max_x = min(world.maxx, max_x + HULL_ANCHOR_REACH)
	max_y = min(world.maxy, max_y + HULL_ANCHOR_REACH)
	for (var/obj/structure/berth/quay/Q in sea_harbours)
		if (!QDELETED(Q) && Q.z == B.z && Q.x >= min_x && Q.x <= max_x && Q.y >= min_y && Q.y <= max_y)
			return Q
	for (var/turf/T in block(locate(min_x, min_y, B.z), locate(max_x, max_y, B.z)))
		if (B.contains(T))
			continue
		var/obj/structure/bollard/post = locate() in T
		if (post)
			return post
	return null

// TRUE when she will stay where she is.
/datum/hull_ledger/proc/held()
	if (!needs_anchor() || grounded)
		return TRUE
	if (!craft || !craft.anchored)
		return FALSE
	return holding() >= tiles || mooring()

/datum/hull_ledger/proc/hold_text()
	if (!needs_anchor())
		return "a hull this small is held by a stone on a line."
	if (grounded)
		return "she sits on the bottom."
	var/power = holding()
	var/atom/post = mooring()
	if (craft && craft.anchored)
		if (power >= tiles)
			return "she lies to her anchor."
		if (post)
			return "she is made fast to \the [post]."
		return "<b>she lies to with nothing to hold her</b> and drifts while anyone is aboard: her anchors hold [power] of her [tiles] tiles. Build an anchor on her deck or lie within [HULL_ANCHOR_REACH] tiles of a mooring post or bollard."
	if (power >= tiles)
		return "her anchor is up; it will hold her when it is called down."
	if (post)
		return "her lines are in; \the [post] will hold her when her anchor is called down."
	return "her anchors hold [power] of her [tiles] tiles: called down they will not hold her."

// The way wind and water would carry her, or 0.
/datum/hull_ledger/proc/drift_dir()
	var/turf/at = craft && craft.body ? craft.body.origin() : null
	if (!at)
		return 0
	var/current = river_current_direction(at)
	if (current)
		return current
	if (weather_wind_at(at) >= HULL_DRIFT_WIND)
		return turn(weather_wind_dir_at(at), 180)
	return 0

// One step of drift. TRUE when she moved.
/datum/hull_ledger/proc/step_drift()
	if (!craft || !craft.body || !craft.body.placed() || sinking || under_way() || !crewed || held())
		drift_told = FALSE
		return FALSE
	if (persistence_save_in_progress || craft.turning_to)
		return FALSE
	var/way = drift_dir()
	if (!way)
		return FALSE
	var/turf/O = craft.body.origin()
	var/heading = craft.body.heading()
	var/nx = O.x + (way == EAST ? 1 : (way == WEST ? -1 : 0))
	var/ny = O.y + (way == NORTH ? 1 : (way == SOUTH ? -1 : 0))
	if (!craft.body.can_move_to(nx, ny, heading) || !craft.body.move_to(nx, ny, heading))
		return FALSE
	if (!drift_told)
		drift_told = TRUE
		craft.crew_message(SPAN_WARNING("The [craft.name] is adrift, setting [dir2text(way)]: nothing holds her. Get way on her, or call her anchor down where an anchor or a mooring will hold."))
	return TRUE

// Calling the anchor down beside nothing that holds is allowed, and said.
/datum/craft/set_anchor(down)
	. = ..()
	if (!down || !ledger || !ledger.needs_anchor() || !body || !body.placed())
		return
	if (ledger.holding() >= ledger.tiles)
		return
	var/atom/post = ledger.mooring()
	if (post)
		crew_message(SPAN_NOTICE("The [name] is made fast to \the [post]."))
	else if (!ledger.grounded)
		crew_message(SPAN_WARNING("The [name] has nothing to hold her: [ledger.hold_text()]"))

#undef HULL_ANCHOR_REACH
#undef HULL_DRIFT_WIND
