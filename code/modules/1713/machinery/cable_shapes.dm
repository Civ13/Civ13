// Smart cable shapes and map-placed wiring.
//
// A cable piece has two ends: horizontal (EAST, WEST), vertical (NORTH,
// SOUTH) or a corner (tiledir "corner", ends d1 and d2, drawn "d1-d2").
// An end joins a cable on the next tile whose end points back, whatever its
// shape. Pieces on the same tile still join only through a secured connector,
// so a straight crossing stays insulated.
//
// Laying a cable picks a corner by itself when it would continue a loose end
// from the side and nothing waits behind it, so a line can turn without a
// connector. Maps can place cables (icon_state "horizontal", "vertical" or a
// corner such as "1-4"), secured connectors and powered machines on a cable:
// everything joins once when the map has loaded. None of this runs per tick.

/proc/cable_reverse_dir(dir)
	return turn(dir, 180)

/obj/structure/cable/proc/cable_ends()
	if (tiledir == "horizontal")
		return list(EAST, WEST)
	if (tiledir == "vertical")
		return list(NORTH, SOUTH)
	if (tiledir == "corner" && d1 && d2)
		return list(d1, d2)
	return list()

// Sets the shape from two end directions and redraws it.
/obj/structure/cable/proc/set_cable_shape(end_a, end_b)
	if ((end_a | end_b) == (EAST | WEST))
		tiledir = "horizontal"
		d1 = 0
		d2 = end_a
	else if ((end_a | end_b) == (NORTH | SOUTH))
		tiledir = "vertical"
		d1 = 0
		d2 = end_a
	else
		tiledir = "corner"
		d1 = min(end_a, end_b)
		d2 = max(end_a, end_b)
	update_icon()

// Reads a shape a mapper chose by icon_state. Returns FALSE when it names none.
/obj/structure/cable/proc/shape_from_icon_state()
	if (icon_state == "horizontal" || icon_state == "vertical")
		tiledir = icon_state
		return TRUE
	var/dash = findtext(icon_state, "-")
	if (!dash)
		return FALSE
	var/a = text2num(copytext(icon_state, 1, dash))
	var/b = text2num(copytext(icon_state, dash + 1))
	if (!(a in list(NORTH, SOUTH, EAST, WEST)) || !(b in list(NORTH, SOUTH, EAST, WEST)) || a == b)
		return FALSE
	set_cable_shape(a, b)
	return TRUE

// TRUE if some cable on the next tile in dir is already joined to this end.
/obj/structure/cable/proc/end_linked(dir)
	var/turf/T = get_step(src, dir)
	if (!T)
		return FALSE
	for (var/obj/structure/cable/N in connections)
		if (N.loc == T)
			return TRUE
	return FALSE

// Joins each end to the cables on the next tile whose end points back.
// Symmetric and idempotent; it never rebuilds supply, because placement must
// finish same-tile junctions first.
/obj/structure/cable/proc/link_end_neighbors(mob/user, notify = TRUE)
	if (!isturf(loc))
		return 0
	var/joined = 0
	for (var/dir in cable_ends())
		var/turf/T = get_step(src, dir)
		if (!T)
			continue
		var/back = cable_reverse_dir(dir)
		for (var/obj/structure/cable/neighbor in T)
			if (neighbor == src || !(back in neighbor.cable_ends()))
				continue
			neighbor.connections |= src
			connections |= neighbor
			joined++
	if (user && notify && joined)
		to_chat(user, joined == 1 ? "You connect the two cables." : "You connect the cables.")
	return joined

// A cable on the tile next to T in dir with a loose end pointing at T.
/proc/cable_loose_end_toward(turf/T, dir)
	var/turf/N = get_step(T, dir)
	if (!N)
		return FALSE
	var/back = cable_reverse_dir(dir)
	for (var/obj/structure/cable/C in N)
		if ((back in C.cable_ends()) && !C.end_linked(back))
			return TRUE
	return FALSE

// The corner a cable laid on T facing dirn should be, as its two ends, or
// null for the usual straight piece. A corner only when nothing waits behind
// and exactly one side has a loose end: it turns from that side into dirn.
// A corner that would overlap a cable already on T stays straight.
/proc/cable_corner_for(turf/T, dirn)
	if (!T || !(dirn in list(NORTH, SOUTH, EAST, WEST)))
		return null
	if (cable_loose_end_toward(T, cable_reverse_dir(dirn)))
		return null
	var/side = 0
	for (var/p in list(turn(dirn, 90), turn(dirn, -90)))
		if (cable_loose_end_toward(T, p))
			if (side)
				return null
			side = p
	if (!side)
		return null
	for (var/obj/structure/cable/existing in T)
		var/list/ends = existing.cable_ends()
		if ((side in ends) || (dirn in ends))
			return null
	return list(side, dirn)

// Map-placed wiring joins once the map is in. Holds are nested: the compiled
// map holds until world/New, and each runtime map read holds while it runs.
var/global/cable_autolink_holds = 1
var/global/list/cable_autolink_queue = list()

/proc/hold_cable_autolink()
	cable_autolink_holds++

/proc/release_cable_autolink()
	cable_autolink_holds = max(0, cable_autolink_holds - 1)
	if (!cable_autolink_holds)
		return autolink_queued_cables()
	return 0

/obj/structure/cable/on_runtime_spawn()
	..()
	shape_from_icon_state()
	if (cable_autolink_holds)
		cable_autolink_queue += src

/obj/item/connector/secured
	name = "cable connector"
	anchored = TRUE

/obj/item/connector/secured/on_runtime_spawn()
	..()
	if (cable_autolink_holds)
		cable_autolink_queue += src
	else
		connect_cables()

// Cables first, then same-tile junctions, then machines on the cable tiles.
/proc/autolink_queued_cables()
	var/list/queue = cable_autolink_queue
	cable_autolink_queue = list()
	var/count = 0
	for (var/obj/structure/cable/C in queue)
		if (QDELETED(C) || !isturf(C.loc))
			continue
		C.link_end_neighbors()
		count++
	for (var/obj/item/connector/J in queue)
		if (!QDELETED(J) && J.anchored && isturf(J.loc))
			J.connect_cables()
	for (var/obj/structure/cable/C in queue)
		if (QDELETED(C) || !isturf(C.loc))
			continue
		for (var/obj/O in C.loc)
			if (O != C && !istype(O, /obj/structure/cable) && !istype(O, /obj/item))
				O.map_cable_attach(C)
	return count

// Joins a machine standing on a map-placed cable, the way laying a cable
// under it would. Returns TRUE when it attached.
/obj/proc/map_cable_attach(obj/structure/cable/C)
	if (powerneeded <= 0 || powersource || !anchored)
		return FALSE
	powersource = C
	C.connections |= src
	return TRUE

/obj/structure/civ_generator/map_cable_attach(obj/structure/cable/C)
	if (powersource || !anchored || !registered)
		return FALSE
	powersource = C
	C.connections |= src
	return TRUE

/obj/structure/battery/map_cable_attach(obj/structure/cable/C)
	if (powersource || !anchored)
		return FALSE
	powersource = C
	C.connections |= src
	return TRUE

/obj/structure/engine/map_cable_attach(obj/structure/cable/C)
	if (!anchored || connections.len)
		return FALSE
	connections |= C
	C.connections |= src
	return TRUE
