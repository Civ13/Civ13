// ============================================================
// Grappling and boarding (docs/craft-core.md)
// ------------------------------------------------------------
// A ship lying within GRAPPLE_REACH tiles of water from another throws her
// lines from the helm. While they hold, neither ship hops, turns or makes
// for a berth, and boarding lines lie across the gap for the crews to walk.
// The ship that threw them casts them off at once; the ship that was caught
// cuts them at her helm or at any of the lines, which takes a moment. A ship
// whose lines were let go coils them for GRAPPLE_COOLDOWN before she can
// throw them again. Nothing of it is saved.
// ============================================================

#define GRAPPLE_REACH 3
#define GRAPPLE_COOLDOWN 600
#define GRAPPLE_CUT_TIME 50
#define GRAPPLE_SEARCH_RANGE 60

/datum/craft
	var/tmp/datum/craft_grapple/grapple
	var/tmp/grapple_ready_at = 0

/datum/craft_grapple
	var/datum/craft/thrower
	var/datum/craft/caught
	var/list/lines = list()

/datum/craft_grapple/Destroy()
	for (var/obj/covers/repairedfloor/rope/boarding/L in lines)
		L.grapple = null
		qdel(L)
	lines = list()
	for (var/datum/craft/C in list(thrower, caught))
		if (C.grapple == src)
			C.grapple = null
			if (C.body && !QDELETED(C.body))
				C.body.hold(0)
	thrower = null
	caught = null
	return ..()

// The other ship on the lines.
/datum/craft_grapple/proc/other(datum/craft/C)
	return C == thrower ? caught : thrower

// Lets the lines go. by is the craft whose crew did it, or null.
/datum/craft_grapple/proc/release(datum/craft/by = null, mob/who = null)
	var/datum/craft/A = thrower
	var/datum/craft/B = caught
	if (A)
		A.grapple_ready_at = world.time + GRAPPLE_COOLDOWN
	var/how = "The grappling lines part"
	if (by == A)
		how = "[who ? "[who] casts" : "The [A.name] casts"] off the grappling lines"
	else if (by)
		how = "[who ? "[who] cuts" : "The [by.name] cuts"] the grappling lines"
	else if (who)
		how = "[who] cuts the grappling lines"
	qdel(src)
	for (var/datum/craft/C in list(A, B))
		if (!QDELETED(C))
			C.crew_message(SPAN_NOTICE("[how]: the [C.name] is free to sail."))

// A boarding line: rope across the water between two grappled ships.
/obj/covers/repairedfloor/rope/boarding
	name = "boarding line"
	desc = "Grappling lines hauled taut between two ships, sound enough to cross on. Click one to cut the ships apart."
	afloat = TRUE
	should_save = FALSE
	not_movable = TRUE
	var/tmp/datum/craft_grapple/grapple

/obj/covers/repairedfloor/rope/boarding/Destroy()
	var/datum/craft_grapple/G = grapple
	grapple = null
	if (G && !QDELETED(G))
		G.lines -= src
		// A line shot or burnt away parts the ships.
		G.release()
	return ..()

/obj/covers/repairedfloor/rope/boarding/attack_hand(mob/living/human/H)
	if (!istype(H) || !grapple)
		return ..()
	to_chat(H, SPAN_NOTICE("You start cutting the boarding lines..."))
	if (!do_after(H, GRAPPLE_CUT_TIME, src) || QDELETED(src) || !grapple)
		return
	log_game("[key_name(H)] cut the grapple between the [grapple.thrower.name] and the [grapple.caught.name] at [x],[y],[z].")
	grapple.release(craft_at(get_turf(H)), H)

// TRUE when this turf holds a real floor, not only boarding lines.
/proc/hull_floor_in(turf/T)
	for (var/obj/covers/C in T)
		if (!istype(C, /obj/covers/repairedfloor/rope/boarding))
			return TRUE
	return FALSE

// TRUE when a boarder can step onto this tile of the other ship.
/datum/craft/proc/boardable(turf/T)
	if (!T || T.density)
		return FALSE
	for (var/obj/O in T)
		if (O.density && O.anchored)
			return FALSE
	return TRUE

// Where her lines would run to the other ship: list(gap, direction, turf of
// hers, turf of the other's), or null when she is out of reach. The shortest
// gap wins, and a tile a boarder can step onto beats one they cannot.
/datum/craft/proc/grapple_plan(datum/craft/other)
	var/turf/here = centre()
	var/turf/there = other ? other.centre() : null
	if (!here || !there || other == src || here.z != there.z)
		return null
	var/list/best = null
	var/best_score = INFINITY
	for (var/turf/A in body.cells())
		if (A.z != here.z)
			continue
		for (var/d in cardinal)
			var/turf/T = A
			for (var/n = 0, n <= GRAPPLE_REACH, n++)
				T = get_step(T, d)
				if (!T || body.contains(T))
					break
				if (other.body.contains(T))
					var/score = n * 4 + (other.boardable(T) ? 0 : 2) + (boardable(A) ? 0 : 1)
					if (score < best_score)
						best_score = score
						best = list(n, d, A, T)
					break
				if (!istype(T, /turf/floor/beach/water) || T.density || (locate(/obj/covers) in T) || craft_at(T))
					break
	return best

// Ships she could grapple now: label = craft.
/datum/craft/proc/grapple_candidates()
	. = list()
	var/turf/here = centre()
	if (!here)
		return
	for (var/datum/craft/C in crafts)
		if (C == src)
			continue
		var/turf/P = C.centre()
		if (!P || P.z != here.z || get_dist(here, P) > GRAPPLE_SEARCH_RANGE || !grapple_plan(C))
			continue
		var/label = "[capitalize(name_of(C))], [get_dist(here, P)] tile\s [submarine_bearing(here, P)]"
		while (.[label])
			label += " "
		.[label] = C

// Throws her lines. TRUE when they hold; FALSE with last_refusal set.
/datum/craft/proc/order_grapple(datum/craft/other)
	if (!centre())
		last_refusal = "she is not afloat"
		return FALSE
	if (grapple)
		last_refusal = "her lines are already out"
		return FALSE
	if (turning_to || docking)
		last_refusal = "she is coming about"
		return FALSE
	if (grapple_ready_at && world.time < grapple_ready_at)
		last_refusal = "her lines are still being coiled"
		return FALSE
	if (!other || QDELETED(other) || other == src || !other.centre())
		last_refusal = "there is no ship to grapple"
		return FALSE
	if (other.grapple)
		last_refusal = "another ship already has lines on her"
		return FALSE
	if (other.turning_to || other.docking)
		last_refusal = "she is coming about and the lines fall short"
		return FALSE
	var/list/plan = grapple_plan(other)
	if (!plan)
		last_refusal = "she lies more than [GRAPPLE_REACH] tiles of open water off"
		return FALSE
	var/datum/craft_grapple/G = new
	G.thrower = src
	G.caught = other
	grapple = G
	other.grapple = G
	var/turf/T = plan[3]
	for (var/n = 1, n <= plan[1], n++)
		T = get_step(T, plan[2])
		var/obj/covers/repairedfloor/rope/boarding/L = new(T)
		L.dir = plan[2]
		L.grapple = G
		L.updateturf()
		G.lines += L
	body.hold(body.heading())
	other.body.hold(other.body.heading())
	return TRUE

// Why she will not answer a sailing order while the lines hold, or null.
/datum/craft/proc/grapple_refusal()
	if (!grapple)
		return null
	var/datum/craft/other = grapple.other(src)
	return "The [name] is grappled to [other ? "the [name_of(other)]" : "another ship"]. [grapple.thrower == src ? "Cast off" : "Cut"] the grapple first."

// The helm's grapple menu.
/datum/craft/proc/grapple_menu(mob/living/human/H, atom/at)
	if (!istype(H) || QDELETED(at))
		return
	if (grapple)
		var/datum/craft_grapple/G = grapple
		if (G.thrower != src)
			to_chat(H, SPAN_NOTICE("You start cutting the grappling lines..."))
			if (!do_after(H, GRAPPLE_CUT_TIME, at) || QDELETED(src) || grapple != G)
				return
		log_game("[key_name(H)] let go the grapple between the [G.thrower.name] and the [G.caught.name].")
		G.release(src, H)
		return
	var/list/choices = grapple_candidates()
	if (!choices.len)
		to_chat(H, SPAN_WARNING("No ship lies within [GRAPPLE_REACH] tiles of open water of the [name]'s side."))
		return
	var/choice = WWinput(H, "Grapple which ship? Neither of you sails while the lines hold, and the crews can cross on them.", "Grapple", "Cancel", choices + list("Cancel"))
	var/datum/craft/other = choices[choice]
	if (!istype(other) || QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1)
		return
	if (!order_grapple(other))
		to_chat(H, SPAN_WARNING("The lines do not hold: [last_refusal]."))
		return
	log_game("[key_name(H)] grappled the [other.name] from the [name].")
	crew_message(SPAN_NOTICE("[H] at the [at.name]: grapple! Lines hold the [name_of(other)] fast alongside. Neither ship sails until they are let go."))
	other.crew_message(SPAN_DANGER("<b>Grappling lines from [other.knows(src) ? "the [name]" : "an unknown ship"] bite into the rail!</b> The [other.name] is held fast. Cut the lines at the helm or at the lines themselves."))
