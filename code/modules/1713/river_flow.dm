// River currents use reviewed, deterministic map sidecars. Water levels in the
// terrain-height files are flat, so their direction comes from outlet topology.

/obj/map_metadata
	var/tmp/datum/river_flow/river_flow_cache = null
	var/tmp/river_flow_loaded = FALSE

/datum/river_flow
	should_save = FALSE
	var/z_level = 0
	var/list/rows = list()

/proc/river_flow_read(text)
	if (!istext(text) || !length(text))
		return null
	var/list/lines = splittext(replacetext(text, ascii2text(13), ""), "\n")
	if (lines.len < world.maxy + 3 || lines[1] != "civ13-river-flow 1" || lines[2] != "size [world.maxx] [world.maxy]")
		return null
	var/list/zline = splittext(lines[3], " ")
	if (zline.len != 2 || zline[1] != "z")
		return null
	var/z = text2num(zline[2])
	if (!isnum(z) || z != round(z) || z < 1 || z > world.maxz)
		return null
	var/datum/river_flow/F = new
	F.z_level = z
	var/static/regex/bad = regex(@"[^.neswabcd]")
	for (var/i = 1, i <= world.maxy, i++)
		var/row = lines[i + 3]
		if (length(row) != world.maxx || bad.Find(row))
			qdel(F)
			return null
		F.rows += row
	return F

/obj/map_metadata/proc/river_flow()
	if (river_flow_loaded)
		return river_flow_cache
	river_flow_loaded = TRUE
	if (!terrain_height_file)
		return null
	var/path = replacetext(terrain_height_file, ".txt", ".flow.txt")
	if (fexists(path))
		river_flow_cache = river_flow_read(file2text(path))
		if (!river_flow_cache)
			log_debug("River flow [path] ignored: invalid sidecar")
	return river_flow_cache

/proc/river_current_direction(turf/T)
	// Ice holds what lies on it; the water under it is not this turf's affair.
	if (!istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/beach/water/ice) || !map)
		return 0
	var/datum/river_flow/F = map.river_flow()
	if (!F || F.z_level != T.z || T.x < 1 || T.x > world.maxx || T.y < 1 || T.y > world.maxy)
		return 0
	var/code = copytext(F.rows[world.maxy - T.y + 1], T.x, T.x + 1)
	switch (code)
		if ("n") return NORTH
		if ("e") return EAST
		if ("s") return SOUTH
		if ("w") return WEST
		if ("a") return NORTHEAST
		if ("b") return SOUTHEAST
		if ("c") return SOUTHWEST
		if ("d") return NORTHWEST
	return 0

var/global/list/river_active_water = list()
var/global/list/river_initial_scan = null
var/global/river_scan_index = 1
var/global/list/river_moved = list()

/proc/river_carryable(atom/movable/A)
	if (!A || QDELETED(A) || A.anchored)
		return FALSE
	if (istype(A, /obj/item))
		return TRUE
	// A carcass snags on the river bed: drifting one tile per pulse broke
	// butchering and carried kills into deep water, where they sink.
	if (istype(A, /mob/living/simple_animal))
		var/mob/living/simple_animal/carcass = A
		if (carcass.stat == DEAD)
			return FALSE
	if (istype(A, /mob/living))
		var/mob/living/L = A
		return !L.buckled && !L.captured && !L.pulling && !L.pulledby
	return FALSE

// An empty raft goes where the water takes it. One with anybody or anything aboard is
// being handled, and the wide boats keep their place.
/proc/river_adrift(atom/movable/A)
	if (!istype(A, /obj/structure/vehicle/raft) || QDELETED(A) || A.anchored)
		return FALSE
	var/obj/structure/vehicle/raft/R = A
	return !R.driver && !R.ontop.len && !R.ontop_o.len && !R.moving

/turf/floor/beach/water/Entered(atom/movable/A)
	. = ..()
	if ((river_carryable(A) || river_adrift(A)) && river_current_direction(src))
		river_active_water |= src

/turf/floor/beach/water/examine(mob/user)
	..()
	var/direction = river_current_direction(src)
	if (direction)
		if (salty)
			to_chat(user, "A sea current sets [dir2text(direction)] here. It will carry off anything left adrift.")
		else
			to_chat(user, "The current flows [dir2text(direction)].")

/turf/floor/beach/water/proc/river_wake_if_occupied()
	if (!river_current_direction(src))
		return
	for (var/atom/movable/A in src)
		if (river_carryable(A) || river_adrift(A))
			river_active_water |= src
			return

/turf/floor/beach/water/proc/river_current_step()
	var/direction = river_current_direction(src)
	var/turf/destination = direction ? get_step(src, direction) : null
	if (!direction || !istype(destination, /turf/floor/beach/water))
		river_active_water -= src
		return
	// Recheck occupied covered water: a bridge or boat may be removed later.
	var/occupied = FALSE
	// An empty raft drifts with whatever lies on it left behind in the water.
	for (var/obj/structure/vehicle/raft/R in contents)
		if (river_adrift(R) && !(R in river_moved))
			river_moved |= R
			occupied = TRUE
			step(R, direction)
	var/sheltered = iscovered()
	for (var/atom/movable/A in contents.Copy())
		if (!river_carryable(A))
			continue
		occupied = TRUE
		if (!sheltered && !(A in river_moved))
			river_moved |= A
			step(A, direction)
	if (!occupied)
		river_active_water -= src

