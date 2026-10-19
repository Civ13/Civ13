// Resource-free, standalone native assertions. Compilation/execution is separate.
/world
	maxx = 8
	maxy = 8
	maxz = 2
	icon_size = 32
	fps = 10
	movement_mode = LEGACY_MOVEMENT_MODE
	turf = /turf/probe
	hub = ""
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return 0

/world/Topic()
	return null

/client/New()
	del(src)
	return

/turf/probe
	var/entered_count = 0
	var/exited_count = 0

/turf/probe/Entered(atom/movable/mover)
	if (istype(mover, /obj/subtile_actor))
		entered_count++
	return ..()

/turf/probe/Exited(atom/movable/mover)
	if (istype(mover, /obj/subtile_actor))
		exited_count++
	return ..()

/obj/probe_marker
	var/crossed_count = 0

/obj/probe_marker/Crossed(atom/movable/mover)
	if (istype(mover, /obj/subtile_actor))
		crossed_count++
	return ..()

/obj/probe_blocker
	density = 1
	bound_x = 2
	bound_width = 30

var/probe_checks = 0
var/list/probe_failed = list()
var/list/probe_observations = list()

/proc/probe_assert(condition, name)
	probe_checks++
	if (!condition)
		probe_failed += name
		throw EXCEPTION(name)

/proc/probe_observe(name, list/row)
	row["name"] = name
	probe_observations += list(row)

/proc/probe_same(list/a, list/b)
	if (!islist(a) || !islist(b) || a.len != 5 || b.len != 5)
		return 0
	for (var/key in list("x", "y", "z", "sx", "sy"))
		if (!(key in a) || !(key in b) || !isnum(a[key]) || !isnum(b[key]))
			return 0
		if (a[key] != round(a[key]) || b[key] != round(b[key]) || a[key] != b[key])
			return 0
	return 1

/proc/probe_scalar_summary(value)
	var/list/summary = list("is_list" = islist(value))
	if (!islist(value))
		return summary
	var/list/L = value
	summary["length"] = L.len
	if (L.len <= 5)
		summary["json"] = copytext(json_encode(L), 1, 1025)
	var/list/fields = list()
	for (var/key in list("x", "y", "z", "sx", "sy"))
		var/present = (key in L)
		var/field = present ? L[key] : null
		fields += list(list("key" = key, "present" = present, "numeric" = isnum(field), "text" = istext(field), "null" = isnull(field), "value" = (isnum(field) || istext(field)) ? field : null))
	summary["fields"] = fields
	return summary

/proc/probe_run(control)
	probe_assert(world.byond_version == 516 && world.byond_build == 1681, "pinned_engine")
	probe_assert(control == "none" || control == "cosmetic", "known_control")
	var/obj/subtile_actor/A = new(locate(2, 2, 1))
	var/datum/subtile_kernel/K = new(A, control == "cosmetic")
	var/obj/probe_marker/marker = new(locate(3, 2, 1))
	var/turf/probe/next_tile = locate(3, 2, 1)
	var/turf/probe/old_tile = locate(2, 2, 1)
	var/list/R = K.attempt(4, 0, world.time + 1)
	probe_observe("first_east", R)
	// The cosmetic control MUST fail here, before any incidental assertion.
	probe_assert((A.x - 2) * 32 + A.step_x == 4 && (A.y - 2) * 32 + A.step_y == 0 && R["dx"] == 4 && R["dy"] == 0, "physical_east_four_pixels")
	probe_assert(R["engine_return"] == 4 && R["reached"], "native_slide_return_four")
	probe_assert(A.x == 2 && A.step_x == 4 && A.pixel_x == 0 && A.pixel_y == 0, "physical_offsets_not_visual")
	probe_assert(A.bound_width == 32 && A.bound_height == 32, "full_tile_bounds")
	probe_assert(A.locs.len == 2 && (old_tile in A.locs) && (next_tile in A.locs), "straddling_locs")
	probe_assert((A in old_tile.contents) && (A in next_tile.contents), "straddling_contents")
	probe_assert(next_tile.entered_count > 0 && marker.crossed_count > 0, "native_entry_cross_callbacks")
	for (var/i = 1, i <= 7, i++)
		R = K.attempt(4, 0, world.time + 1)
		probe_assert(R["dx"] == 4 && R["dy"] == 0, "east_substep_[i]")
	probe_observe("east_normalized", R)
	probe_assert(A.x == 3 && A.step_x == 0 && A.locs.len == 1 && old_tile.exited_count > 0, "east_normalization_exit")
	var/list/before = K.position()
	R = K.attempt(4, 0, world.time + 1)
	probe_assert(!R["accepted"] && R["reason"] == "budget" && probe_same(before, K.position()), "fixed_tick_work_bound")
	sleep(1)
	R = K.attempt(-4, 0, world.time + 1)
	probe_observe("reverse_west", R)
	probe_assert(R["dx"] == -4 && A.x == 2 && A.step_x == 28, "west_normalization")

	var/obj/subtile_actor/V = new(locate(6, 6, 1))
	var/datum/subtile_kernel/KV = new(V)
	R = KV.attempt(0, -4, world.time + 1)
	probe_observe("south", R)
	probe_assert(R["dy"] == -4 && V.y == 5 && V.step_y == 28, "south_normalization")
	R = KV.attempt(0, 4, world.time + 1)
	probe_assert(R["dy"] == 4 && V.y == 6 && V.step_y == 0, "north_normalization")

	// Dense turf blocks the full32px actor exactly at its edge.
	var/turf/wall = locate(4, 4, 1)
	wall.density = 1
	var/obj/subtile_actor/W = new(locate(3, 4, 1))
	var/datum/subtile_kernel/KW = new(W)
	R = KW.attempt(4, 0, world.time + 1)
	probe_observe("dense_turf", R)
	probe_assert(R["accepted"] && R["engine_return"] == 0 && R["dx"] == 0 && !R["reached"] && W.bumps > 0, "wall_blocks_with_bump")
	wall.density = 0
	R = KW.attempt(4, 0, world.time + 1)
	probe_assert(R["dx"] == 4 && R["reached"], "opened_boundary_passes")

	// A30px dense movable starts2px inside the adjacent turf: partial success.
	var/obj/probe_blocker/blocker = new(locate(4, 3, 1))
	var/obj/subtile_actor/B = new(locate(3, 3, 1))
	var/datum/subtile_kernel/KB = new(B)
	R = KB.attempt(4, 0, world.time + 1)
	probe_observe("dense_movable_partial", R)
	probe_assert(R["dx"] == 2 && R["engine_return"] == 2 && !R["reached"] && B.bumps > 0, "partial_success_is_not_full_success")
	R = KB.attempt(4, 0, world.time + 1)
	probe_assert(R["dx"] == 0 && R["engine_return"] == 0, "movable_boundary_stays_blocked")
	R = KB.attempt(-4, 0, world.time + 1)
	probe_assert(R["dx"] == -4, "reverse_away_from_obstacle")
	del(blocker)

	// Invalid requests must not consume work or alter physical/visual position.
	before = KV.position()
	var/calls_before = KV.calls
	for (var/list/input in list(list(0, 0), list(4, 4), list(5, 0), list(0.5, 0), list("4", 0)))
		R = KV.attempt(input[1], input[2], world.time + 1)
		probe_assert(!R["accepted"] && R["reason"] == "cardinal_step" && probe_same(before, KV.position()) && KV.calls == calls_before, "invalid_step_[probe_checks]")
	for (var/deadline in list(world.time - 1, world.time + 2, "later", null))
		R = KV.attempt(4, 0, deadline)
		probe_assert(!R["accepted"] && R["reason"] == "deadline" && probe_same(before, KV.position()) && KV.calls == calls_before, "invalid_deadline_[probe_checks]")
	var/obj/subtile_actor/E = new(locate(1, 1, 1))
	var/datum/subtile_kernel/KE = new(E)
	R = KE.attempt(-4, 0, world.time + 1)
	probe_assert(!R["accepted"] && R["reason"] == "map_edge" && E.x == 1 && E.step_x == 0 && KE.calls == 0, "world_edge_rejected")
	V.bound_width = 16
	R = KV.attempt(4, 0, world.time + 1)
	probe_assert(!R["accepted"] && R["reason"] == "owner", "smaller_footbox_not_opted_in")
	V.bound_width = 32

	// Disk-backed scalar policy demonstration; deliberately NOT the game codec.
	var/list/saved = K.position()
	var/savefile/F = new("offset-roundtrip.sav")
	F["position"] << saved
	F = null
	F = new("offset-roundtrip.sav")
	var/list/loaded
	F["position"] >> loaded
	F = null
	probe_observe("scalar_roundtrip_values", list("saved" = probe_scalar_summary(saved), "loaded" = probe_scalar_summary(loaded)))
	probe_assert(probe_same(saved, loaded), "scalar_disk_roundtrip")
	del(A)
	var/obj/subtile_actor/S = new(locate(2, 6, 1))
	var/datum/subtile_kernel/KS = new(S)
	R = KS.restore_position(loaded, world.time + 1)
	probe_observe("scalar_restore", R)
	probe_assert(R["reached"] && probe_same(saved, KS.position()), "scalar_offsets_restored_via_move")
	before = KS.position()
	var/turf/blocked_destination = locate(6, 2, 1)
	blocked_destination.density = 1
	R = KS.restore_position(list("x" = 6, "y" = 2, "z" = 1, "sx" = 0, "sy" = 0), world.time + 1)
	probe_observe("blocked_restore_destination", R)
	probe_assert(R["accepted"] && R["engine_return"] == 0 && !R["reached"] && probe_same(before, KS.position()), "blocked_placement_never_forces_loc")
	loaded["z"] = 2
	R = KS.restore_position(loaded, world.time + 1)
	probe_assert(!R["accepted"] && probe_same(before, KS.position()), "cross_z_restore_rejected")
	loaded["z"] = 1
	loaded["sx"] = "28"
	R = KS.restore_position(loaded, world.time + 1)
	probe_assert(!R["accepted"] && probe_same(before, KS.position()), "malformed_offset_rejected")

/world/New()
	..()
	OpenPort("none")
	if (world.port)
		return
	text2file("closed", "port-closed.txt")
	var/control = world.params["control"]
	if (isnull(control))
		control = "none"
	var/error = null
	try
		probe_run(control)
	catch (var/exception/E)
		error = E.name
		if (!probe_failed.len)
			probe_failed += "unexpected_exception"
	var/result = probe_failed.len ? "FAIL [probe_failed[1]]" : "PASS"
	text2file(result, "result.txt")
	text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "port" = world.port, "checks" = probe_checks, "failed" = probe_failed, "control" = control, "error" = error, "observations" = probe_observations)), "receipt.json")
	del(world)
	return
