// Wide portcullises (Val, 2026-11-16). Portcullis sections built next to each
// other in a straight line join into one grid: the ends carry the frame posts
// and the middle sections none. A winch works the whole run it reaches, however
// wide; a wider run takes longer to wind, and a second pair of hands at the
// winch halves the time.

#define PORTCULLIS_WIND_BASE 40		// ds to wind up one section
#define PORTCULLIS_WIND_EXTRA 15	// ds more for each extra section
#define PORTCULLIS_DROP_TIME 15

/obj/structure/castle_gate/portcullis
	var/tmp/join_suffix = ""

// The neighbouring section in a direction, if there is one.
/obj/structure/castle_gate/portcullis/proc/portcullis_neighbour(direction)
	var/turf/T = get_step(src, direction)
	if (!T)
		return null
	return locate(/obj/structure/castle_gate/portcullis) in T

// Which way this section's run goes: EAST for side by side, NORTH for stacked,
// 0 on its own. Side by side wins when a section touches both.
/obj/structure/castle_gate/portcullis/proc/portcullis_axis()
	if (portcullis_neighbour(EAST) || portcullis_neighbour(WEST))
		return EAST
	if (portcullis_neighbour(NORTH) || portcullis_neighbour(SOUTH))
		return NORTH
	return 0

// Every section in this one's straight run, this one included.
/obj/structure/castle_gate/portcullis/proc/portcullis_run()
	. = list(src)
	var/axis = portcullis_axis()
	if (!axis)
		return
	for (var/direction in list(axis, turn(axis, 180)))
		var/obj/structure/castle_gate/portcullis/P = portcullis_neighbour(direction)
		while (P && !(P in .))
			. += P
			P = P.portcullis_neighbour(direction)

/obj/structure/castle_gate/portcullis/proc/update_join()
	var/axis = portcullis_axis()
	join_suffix = ""
	if (axis == EAST)
		var/west = portcullis_neighbour(WEST)
		var/east = portcullis_neighbour(EAST)
		join_suffix = (west && east) ? "_c" : (east ? "_w" : "_e")
	else if (axis == NORTH)
		var/north = portcullis_neighbour(NORTH)
		var/south = portcullis_neighbour(SOUTH)
		join_suffix = (north && south) ? "_m" : (south ? "_n" : "_s")
	icon_state = "[open ? open_state : closed_state][join_suffix]"

/obj/structure/castle_gate/portcullis/update_state()
	density = !open
	update_join()

// Sections rejoin their neighbours when one is built, moved or destroyed.
/obj/structure/castle_gate/portcullis/proc/refresh_neighbours()
	for (var/direction in cardinal)
		var/obj/structure/castle_gate/portcullis/P = portcullis_neighbour(direction)
		if (P && !QDELETED(P))
			P.update_join()

/obj/structure/castle_gate/portcullis/New()
	..()
	spawn (1)
		if (!QDELETED(src))
			update_join()
			refresh_neighbours()

/obj/structure/castle_gate/portcullis/Destroy()
	var/turf/T = get_turf(src)
	. = ..()
	if (T)
		for (var/direction in cardinal)
			var/obj/structure/castle_gate/portcullis/P = locate() in get_step(T, direction)
			if (P && !QDELETED(P) && P != src)
				spawn (1)
					if (!QDELETED(P))
						P.update_join()

// The two kinds of iron barrier keep separate runs. The old arch sprites do
// not form portcullis frames, but adjacent sections can still share a winch.
/obj/structure/gate/proc/iron_grid_neighbour(direction)
	var/turf/T = get_step(src, direction)
	for (var/obj/structure/gate/G in T)
		if (!QDELETED(G) && G.is_iron_grid_gate())
			return G

/obj/structure/gate/proc/iron_grid_run()
	. = list(src)
	var/axis = 0
	if (iron_grid_neighbour(EAST) || iron_grid_neighbour(WEST))
		axis = EAST
	else if (iron_grid_neighbour(NORTH) || iron_grid_neighbour(SOUTH))
		axis = NORTH
	if (!axis)
		return
	for (var/direction in list(axis, turn(axis, 180)))
		var/obj/structure/gate/G = iron_grid_neighbour(direction)
		while (G && !(G in .))
			. += G
			G = G.iron_grid_neighbour(direction)

// ---- the winch works whole runs ----------------------------------------------------

// How long winding takes: longer for wider runs, halved by a helper at the winch.
/obj/structure/castle_winch/proc/wind_time(list/G, raise, mob/user)
	if (!raise)
		return PORTCULLIS_DROP_TIME
	var/sections = 0
	for (var/obj/structure/castle_gate/portcullis/P in G)
		sections++
	for (var/obj/structure/gate/I in G)
		sections++
	. = PORTCULLIS_WIND_BASE + PORTCULLIS_WIND_EXTRA * max(0, sections - 1)
	for (var/mob/living/human/H in range(1, src))
		if (H != user && H.stat == CONSCIOUS && !H.restrained() && !H.get_active_hand())
			return round(. / 2)

/obj/structure/castle_winch/examine(mob/user, distance = -1)
	. = ..()
	to_chat(user, SPAN_NOTICE("It also works arched iron gates. Build it within two tiles of any section in a straight run."))
	var/sections = 0
	for (var/obj/structure/castle_gate/portcullis/P in gates())
		sections++
	if (sections > 1)
		to_chat(user, SPAN_NOTICE("It works a portcullis [sections] sections wide. A second person at the winch makes winding it quicker."))

#undef PORTCULLIS_WIND_BASE
#undef PORTCULLIS_WIND_EXTRA
#undef PORTCULLIS_DROP_TIME
