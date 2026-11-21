// Ramps: a sloped way up to the next storey, laid as a straight run of
// sections in the climb direction. A ramp is longer than stairs, and wants
// open air over its whole length, but takes what stairs can't:
//   earth ramp (4 sections)          - what stairs take; too steep for wheels
//   timber ramp (4 sections)         - and carts, wheelbarrows, wheelchairs
//   stone or concrete ramp (8)       - and, with a helper, a hoist-only load
// The section at the high end of a full run acts as the stairs do
// (edge_climbing.dm): walking onto it along the run steps up onto the floor
// beyond the open air over it, and walking off that floor into the opening
// steps down onto it. Loads: level_change_load_problem (lifting_machines.dm).
// Art: icons/obj/ramps.dmi, drawn by tests/sprites/create_ramps.py.

/obj/covers/var/ramp_sections = 0 // sections in a full run; 0 is not a ramp
/obj/covers/var/ramp_carries = 0 // RAMP_FOOT, RAMP_WHEELS or RAMP_HEAVY

/obj/covers/cobblestone/ramp_earth
	name = "earth ramp"
	desc = "Packed earth held in by set stones, sloping up to the next storey. Lay four in a straight line, facing the way they climb, with open air above them and a floor at the top. Too steep and rough for wheels."
	icon = 'icons/obj/ramps.dmi'
	icon_state = "earth_ramp"
	ramp_sections = 4
	ramp_carries = RAMP_FOOT

/obj/covers/wood/ramp
	name = "timber ramp"
	desc = "Planks on a frame with cleats across them, sloping up to the next storey. Lay four in a straight line, facing the way they climb, with open air above them and a floor at the top. Carts and wheelchairs roll up it."
	icon = 'icons/obj/ramps.dmi'
	icon_state = "timber_ramp"
	ramp_sections = 4
	ramp_carries = RAMP_WHEELS

/obj/covers/cobblestone/ramp_gentle
	name = "stone ramp"
	desc = "A long, gentle slope of dressed stone up to the next storey. Lay eight in a straight line, facing the way they climb, with open air above them and a floor at the top. Wheels roll up it, and two people can haul even a machine or an anvil."
	icon = 'icons/obj/ramps.dmi'
	icon_state = "stone_ramp"
	ramp_sections = 8
	ramp_carries = RAMP_HEAVY

/obj/covers/concretefloor/ramp
	name = "concrete ramp"
	desc = "A long, gentle concrete slope up to the next storey. Lay eight in a straight line, facing the way they climb, with open air above them and a floor at the top. Wheels roll up it, and two people can haul even a machine or an anvil."
	icon = 'icons/obj/ramps.dmi'
	icon_state = "concrete_ramp"
	ramp_sections = 8
	ramp_carries = RAMP_HEAVY

/obj/covers/concretefloor/ramp/New()
	..()
	icon_state = initial(icon_state)
	base_icon_state = icon_state

// A section in T that continues a run of like: the same kind of ramp, facing
// the same way. Stone and concrete gentle ramps join each other.
/proc/ramp_section_in(turf/T, obj/covers/like)
	if (!T || !like)
		return null
	for (var/obj/covers/C in T)
		if (C.ramp_sections && C.ramp_sections == like.ramp_sections && C.ramp_carries == like.ramp_carries && C.dir == like.dir && !C.gc_destroyed && !C.gcDestroyed)
			return C
	return null

// Sections in the run ending at R, counted down the slope from R, at most a
// full run.
/proc/ramp_run_length(obj/covers/R)
	. = 0
	var/turf/T = get_turf(R)
	while (T && . < R.ramp_sections && ramp_section_in(T, R))
		.++
		T = get_step(T, turn(R.dir, 180))

// Why R does not lead up a storey, or null when it is the high end of a full
// run with headroom all the way up. Only that one section climbs.
/proc/ramp_problem(obj/covers/R)
	if (!R || !R.ramp_sections)
		return "That isn't a ramp."
	if (!(R.dir in list(NORTH, SOUTH, EAST, WEST)))
		return "\The [R] has to face straight along the way it climbs."
	var/turf/T = get_turf(R)
	if (!T)
		return "\The [R] isn't laid anywhere."
	if (ramp_section_in(get_step(T, R.dir), R))
		return "Walk on up \the [R]: it climbs from its top section."
	var/sections = ramp_run_length(R)
	if (sections < R.ramp_sections)
		return "\The [R] is [sections] section\s long. It needs [R.ramp_sections] in a straight line, facing the way it climbs, to reach the next storey."
	var/level = multiz_level_above(T.z)
	if (!level)
		return "There is no storey above \the [R] to reach."
	var/turf/step_turf = T
	for (var/i in 1 to R.ramp_sections)
		var/turf/over = locate(step_turf.x, step_turf.y, level)
		if (!ramp_headroom(over))
			return "There is a floor or ceiling over \the [R]. Leave open air above every section of it."
		step_turf = get_step(step_turf, turn(R.dir, 180))
	return null

// Open air over a section: no floor, trapdoor or solid thing, though people
// may be walking through it (onto the ramp from above, or falling).
/proc/ramp_headroom(turf/over)
	if (!over || over.density || !building_open_turf(over) || trapdoor_shut_at(over))
		return FALSE
	for (var/atom/movable/A in over)
		if (istype(A, /obj/covers) || (A.density && !isliving(A)))
			return FALSE
	return TRUE

// The top section of a ramp in T that leads up a storey, or null.
/proc/ramp_top_in(turf/T)
	if (!T)
		return null
	for (var/obj/covers/C in T)
		if (C.ramp_sections && !C.gc_destroyed && !C.gcDestroyed && !ramp_problem(C))
			return C
	return null

// A wheelchair goes where a wheels ramp goes; stairs and an earth ramp throw
// it out.
/proc/ramp_takes_chair(mob/living/human/H, obj/covers/S)
	return H && S && istype(H.buckled, /obj/structure/bed/chair/wheelchair) && S.ramp_carries >= RAMP_WHEELS

// Examining a section says whether the ramp reaches the storey above.
/proc/ramp_examine(obj/covers/R, mob/user)
	if (!R || !user || !R.ramp_sections)
		return
	var/problem = ramp_problem(R)
	if (!problem)
		to_chat(user, SPAN_NOTICE("This is the top of \the [R]. Walk onto it up the slope to reach the floor above."))
	else if (!ramp_section_in(get_step(get_turf(R), R.dir), R))
		to_chat(user, SPAN_NOTICE(problem))

/obj/covers/cobblestone/ramp_earth/examine(mob/user)
	. = ..()
	ramp_examine(src, user)

/obj/covers/wood/ramp/examine(mob/user)
	. = ..()
	ramp_examine(src, user)

/obj/covers/cobblestone/ramp_gentle/examine(mob/user)
	. = ..()
	ramp_examine(src, user)

/obj/covers/concretefloor/ramp/examine(mob/user)
	. = ..()
	ramp_examine(src, user)
