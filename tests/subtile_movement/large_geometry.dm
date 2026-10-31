// Native geometry observations only. No Civ13 movement or wildlife acceptance.
/world
	maxx = 14
	maxy = 14
	maxz = 1
	icon_size = 32
	fps = 20
	movement_mode = LEGACY_MOVEMENT_MODE
	turf = /turf/large_geometry_floor
	hub = ""
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)
	return

/turf/large_geometry_floor
	density = FALSE

/obj/large_geometry_actor
	density = TRUE
	bound_width = 96
	bound_height = 96
	step_size = 2
	var/observed_bumps = 0

/obj/large_geometry_actor/Bump(atom/obstacle)
	observed_bumps++
	return ..()

/obj/large_geometry_blocker
	density = TRUE

/proc/large_geometry_snapshot(obj/large_geometry_actor/A)
	var/list/occupied = list()
	for (var/turf/T in A.locs)
		if (occupied.len >= 32)
			throw EXCEPTION("large_geometry_occupancy_bound")
		occupied += list(list("x" = T.x, "y" = T.y, "z" = T.z, "in_contents" = (A in T.contents)))
	return list("x" = A.x, "y" = A.y, "z" = A.z, "sx" = A.step_x, "sy" = A.step_y,
		"bound_x" = A.bound_x, "bound_y" = A.bound_y, "bound_width" = A.bound_width,
		"bound_height" = A.bound_height, "pixel_x" = A.pixel_x, "pixel_y" = A.pixel_y,
		"pixel_w" = A.vars["pixel_w"], "pixel_z" = A.vars["pixel_z"], "dir" = A.dir, "locs" = occupied)

/proc/large_geometry_observe()
	var/list/rows = list()
	var/obj/large_geometry_actor/reference = new(locate(7, 7, 1))
	reference.bound_x = 0
	var/list/zero = large_geometry_snapshot(reference)
	reference.bound_x = 64
	var/list/sixtyfour = large_geometry_snapshot(reference)
	rows += list(list("case" = "same_anchor_bound_change", "zero" = zero, "sixtyfour" = sixtyfour))
	del(reference)
	// Fresh no-blocker controls make a blocked result interpretable.
	for (var/control_variant in list(0, 64))
		var/obj/large_geometry_actor/C = new(locate(7, 7, 1))
		C.bound_x = control_variant
		var/list/control_before = large_geometry_snapshot(C)
		var/control_return = C.Move(C.loc, EAST, 2, 0)
		rows += list(list("case" = "east_2px_clear", "variant" = control_variant, "direction" = EAST,
			"native_return" = control_return, "bumps" = C.observed_bumps,
			"before" = control_before, "after" = large_geometry_snapshot(C)))
		del(C)
	// Each row has a fresh actor/blocker and exactly one native 2px Move.
	// Fixed cell coordinates avoid assuming which cells each footprint covers.
	for (var/bound_variant in list(0, 64))
		for (var/ox = -3, ox <= 4, ox++)
			for (var/oy = -2, oy <= 4, oy++)
				var/obj/large_geometry_actor/A = new(locate(7, 7, 1))
				A.bound_x = bound_variant
				var/turf/blocker_turf = locate(7 + ox, 7 + oy, 1)
				var/obj/large_geometry_blocker/B = new(blocker_turf)
				var/list/before = large_geometry_snapshot(A)
				var/before_distance = bounds_dist(A, B)
				var/already_occupied = (blocker_turf in A.locs)
				var/native_return = A.Move(A.loc, EAST, 2, 0)
				var/list/after = large_geometry_snapshot(A)
				rows += list(list("case" = "east_2px_blocker", "variant" = bound_variant, "direction" = EAST,
					"blocker_x" = B.x, "blocker_y" = B.y, "already_occupied" = already_occupied,
					"before_distance" = before_distance, "after_distance" = bounds_dist(A, B),
					"native_return" = native_return, "bumps" = A.observed_bumps,
					"before" = before, "after" = after))
				del(B)
				del(A)
	if (rows.len != 115)
		throw EXCEPTION("large_geometry_case_count")
	return rows

/world/New()
	..()
	var/initial_native_port = port
	OpenPort("none")
	if (port)
		return
	text2file("closed", "port-closed.txt")
	var/error = null
	var/list/rows = list()
	try
		rows = large_geometry_observe()
	catch (var/exception/E)
		error = E.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("head" = world.params["tested_commit"], "byond_version" = byond_version,
		"byond_build" = byond_build, "initial_native_port" = initial_native_port, "port" = port,
		"scope" = "standalone native geometry observations only; no Civ13 or wildlife acceptance",
		"error" = error, "observations" = rows)), "receipt.json")
	del(world)
	return
