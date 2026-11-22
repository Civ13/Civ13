// ============================================================
// Gangways and the gangplank (docs/ship-edges.md)
// ------------------------------------------------------------
// A gangway is a gate in her gunwale (or bulwark). Like any railing it closes
// her side. Alt-click it, or use "Run out the gangplank", to run a plank from
// it across up to HULL_GANGPLANK_MAX tiles of water to a pier, the shore or
// another ship. A gangway on her upper deck runs it over open air to a quay
// or pier floor on that level. While the plank is out she is held: she will not get under
// way, turn, make for a berth or leave these waters until it is taken in. The
// plank is not saved, and falls in if she is moved anyway.
// ============================================================

#define HULL_GANGPLANK_MAX 3
#define HULL_GANGPLANK_TIME 20 // ds to run it out or take it in

var/global/list/hull_gangways_out = list()

/obj/structure/railing/built/gunwale/gangway
	name = "wooden gangway"
	desc = "A gate in a boat's gunwale, with a gangplank stowed beside it."
	icon_state = "gunwale_gate"
	gate = TRUE
	var/tmp/list/planks = list()

/obj/structure/railing/built/gunwale/bulwark/gangway
	name = "steel gangway"
	desc = "A hinged section of a ship's bulwark, with a gangplank stowed beside it."
	icon_state = "bulwark_gate"
	gate = TRUE
	var/tmp/list/planks = list()

/obj/covers/repairedfloor/rope/boarding/gangplank
	name = "gangplank"
	desc = "A stout plank run out from a ship's gangway. Take it in at the gangway."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/tmp/obj/structure/railing/built/gunwale/from

/obj/covers/repairedfloor/rope/boarding/gangplank/Destroy()
	var/obj/structure/railing/built/gunwale/G = from
	from = null
	if (G && !QDELETED(G))
		hull_gangplank_lost(G, src)
	return ..()

/obj/covers/repairedfloor/rope/boarding/gangplank/attack_hand(mob/living/human/H)
	if (from && !QDELETED(from))
		to_chat(H, SPAN_NOTICE("Take the gangplank in at \the [from]."))
		return
	return ..()

// The gangway's list of planks: both gangway kinds keep one.
/proc/hull_gangway_planks(obj/structure/railing/built/gunwale/G)
	if (istype(G, /obj/structure/railing/built/gunwale/gangway))
		var/obj/structure/railing/built/gunwale/gangway/W = G
		return W.planks
	if (istype(G, /obj/structure/railing/built/gunwale/bulwark/gangway))
		var/obj/structure/railing/built/gunwale/bulwark/gangway/S = G
		return S.planks
	return null

/proc/hull_is_gangway(atom/A)
	return istype(A, /obj/structure/railing/built/gunwale/gangway) || istype(A, /obj/structure/railing/built/gunwale/bulwark/gangway)

// One plank was broken or burnt: the rest are taken in.
/proc/hull_gangplank_lost(obj/structure/railing/built/gunwale/G, obj/covers/P)
	var/list/planks = hull_gangway_planks(G)
	if (planks)
		planks -= P
	hull_take_in_gangplank(G)

// Where the plank from gangway G would run: list of water (or, a level up,
// open air) turfs to lay it over, or a refusal text.
/proc/hull_gangplank_plan(obj/structure/railing/built/gunwale/G)
	var/turf/T = get_turf(G)
	var/aloft = building_open_turf(T)
	var/list/over = list()
	for (var/n = 1, n <= HULL_GANGPLANK_MAX + 1, n++)
		T = get_step(T, G.dir)
		if (!T)
			return "There is nothing to run the gangplank out to."
		if (T.density)
			return "Something solid is in the way of the gangplank."
		for (var/obj/O in T)
			if (O.density && O.anchored && !istype(O, /obj/structure/railing))
				return "\The [O] is in the way of the gangplank."
		// From a gangway on her upper deck the plank runs over open air to
		// a quay or pier built up a level, so she can be boarded from above.
		if (hull_floor_in(T) || (!istype(T, /turf/floor/beach/water) && !(aloft && building_open_turf(T))))
			if (!over.len)
				return "She lies right alongside here: step across."
			return over
		if (locate(/obj/covers) in T)
			return "Lines or another plank already cross that water."
		over += T
	return "There is no pier, quay, shore or ship within [HULL_GANGPLANK_MAX] tiles to run the gangplank out to."

// Runs the gangplank out from gangway G. Returns null, or why not.
/proc/hull_run_out_gangplank(obj/structure/railing/built/gunwale/G, mob/living/human/H = null)
	var/list/planks = hull_gangway_planks(G)
	if (!planks)
		return "That is not a gangway."
	if (planks.len)
		return "The gangplank is already out."
	var/datum/craft/C = craft_holding(get_turf(G))
	if (C && C.speed != VESSEL_SPEED_STOP)
		return "She must be stopped before the gangplank goes out."
	var/plan = hull_gangplank_plan(G)
	if (istext(plan))
		return plan
	G.set_gate_open(TRUE)
	for (var/turf/T in plan)
		var/obj/covers/repairedfloor/rope/boarding/gangplank/P = new(T)
		P.dir = G.dir
		P.from = G
		P.updateturf()
		planks += P
	hull_gangways_out |= G
	if (C && C.body)
		C.body.hold(C.body.heading())
	if (H)
		log_game("[key_name(H)] ran out the gangplank of [G] at [G.x],[G.y],[G.z].")
	return null

// Takes in the gangplank of gangway G.
/proc/hull_take_in_gangplank(obj/structure/railing/built/gunwale/G)
	var/list/planks = hull_gangway_planks(G)
	hull_gangways_out -= G
	if (!planks || !planks.len)
		return FALSE
	var/list/old = planks.Copy()
	planks.Cut()
	for (var/obj/covers/repairedfloor/rope/boarding/gangplank/P in old)
		P.from = null
		qdel(P)
	var/datum/craft/C = craft_holding(get_turf(G))
	if (C && C.body && !C.grapple && !C.gangplank_refusal())
		C.body.hold(0)
	return TRUE

// Why she will not answer a sailing order while a gangplank is out, or null.
/datum/craft/proc/gangplank_refusal()
	for (var/obj/structure/railing/built/gunwale/G in hull_gangways_out)
		if (QDELETED(G))
			hull_gangways_out -= G
			continue
		var/list/planks = hull_gangway_planks(G)
		var/obj/covers/first = planks && planks.len ? planks[1] : null
		if (!first || get_dist(G, first) != 1 || G.z != first.z)
			// She moved anyway (a crossing, a shove): the plank fell in.
			hull_take_in_gangplank(G)
			continue
		if (craft_holding(get_turf(G)) == src)
			return "Her gangplank is out at \the [G]. Take it in first."
	return null

// ---- At the gangway ----

/proc/hull_gangway_use(obj/structure/railing/built/gunwale/G, mob/living/human/H)
	if (!istype(H) || H.incapacitated() || !G.Adjacent(H))
		return
	var/list/planks = hull_gangway_planks(G)
	var/out = planks && planks.len
	to_chat(H, SPAN_NOTICE("You start [out ? "taking in" : "running out"] the gangplank..."))
	if (!do_after(H, HULL_GANGPLANK_TIME, G) || QDELETED(G))
		return
	if (out)
		hull_take_in_gangplank(G)
		H.visible_message(SPAN_NOTICE("[H] takes in the gangplank at \the [G]."), SPAN_NOTICE("You take in the gangplank."))
		return
	var/why = hull_run_out_gangplank(G, H)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	H.visible_message(SPAN_NOTICE("[H] runs out the gangplank from \the [G]."), SPAN_NOTICE("You run out the gangplank. She is held until it is taken in."))

/obj/structure/railing/built/gunwale/gangway/AltClick(mob/user)
	if (ishuman(user) && Adjacent(user))
		hull_gangway_use(src, user)
		return
	return ..()

/obj/structure/railing/built/gunwale/bulwark/gangway/AltClick(mob/user)
	if (ishuman(user) && Adjacent(user))
		hull_gangway_use(src, user)
		return
	return ..()

/obj/structure/railing/built/gunwale/gangway/verb/gangplank_verb()
	set name = "Run out or take in the gangplank"
	set category = null
	set src in view(1)
	hull_gangway_use(src, usr)

/obj/structure/railing/built/gunwale/bulwark/gangway/verb/gangplank_verb()
	set name = "Run out or take in the gangplank"
	set category = null
	set src in view(1)
	hull_gangway_use(src, usr)

/obj/structure/railing/built/gunwale/gangway/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE(planks.len ? "Her gangplank is out. Alt-click to take it in." : "Alt-click to run out the gangplank, up to [HULL_GANGPLANK_MAX] tiles to a pier, the shore or another ship."))

/obj/structure/railing/built/gunwale/bulwark/gangway/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE(planks.len ? "Her gangplank is out. Alt-click to take it in." : "Alt-click to run out the gangplank, up to [HULL_GANGPLANK_MAX] tiles to a pier, the shore or another ship."))

// A gangway that goes takes its plank in.
/obj/structure/railing/built/gunwale/gangway/Destroy()
	hull_take_in_gangplank(src)
	return ..()

/obj/structure/railing/built/gunwale/bulwark/gangway/Destroy()
	hull_take_in_gangplank(src)
	return ..()

#undef HULL_GANGPLANK_MAX
#undef HULL_GANGPLANK_TIME
