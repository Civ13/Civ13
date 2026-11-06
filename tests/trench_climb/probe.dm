// Full-source probe: real humans, trench turfs and smooth movement, isolated
// startup. Headless authority is an explicit adapter, not a client.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/trench_climb_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/trench_climb_probe/New()
	map = src

/turf/floor/plating/trench_climb_probe

/mob/living/human/trench_climb_probe/human_subtile_authority(client/owner)
	return TRUE

var/trench_climb_probe_checks = 0

/proc/trench_climb_probe_assert(ok, label)
	trench_climb_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/trench_climb_probe_actor(tx, ty)
	var/mob/living/human/trench_climb_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Climber"
	H.name = H.real_name
	H.m_intent = "walk"
	H.set_human_subtile(TRUE)
	return H

/proc/trench_climb_probe_at(mob/living/human/H, tx, ty)
	return H.x == tx && H.y == ty && !H.step_x && !H.step_y

/proc/trench_climb_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/trench_climb_probe
	trench_climb_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")
	// A trench line along row 5, open ground around it.
	for (var/tx in 2 to 10)
		new /turf/floor/trench(locate(tx, 5, 1))

	// A body already left at the trench edge by a smooth step can still climb
	// out: its own overlap no longer blocks the exit, and it lands aligned.
	var/mob/living/human/trench_climb_probe/E = trench_climb_probe_actor(7, 5)
	E.human_subtile_position = list("x" = 7, "y" = 5, "z" = 1, "sx" = 0, "sy" = 30)
	E.human_subtile_import_owned = TRUE
	E.after_load()
	trench_climb_probe_assert(E.y == 5 && E.step_y == 30 && E.human_subtile_eligible(NORTH), "edge_offset_fixture")
	E.dir = NORTH
	E.SelfMove(get_step(E, NORTH), NORTH, world.time + 4)
	sleep(25)
	trench_climb_probe_assert(trench_climb_probe_at(E, 7, 6) && !E.human_subtile_offset_owned, "edge_offset_climbs_out_aligned")

	// Leaving a trench from the tile centre takes the tile path and its climb.
	var/mob/living/human/trench_climb_probe/A = trench_climb_probe_actor(3, 5)
	trench_climb_probe_assert(!A.human_subtile_eligible(NORTH) && !A.human_subtile_eligible(NORTHEAST), "climb_out_uses_tile_path")
	trench_climb_probe_assert(A.human_subtile_eligible(EAST), "walking_along_trench_stays_smooth")
	A.dir = NORTH
	A.SelfMove(get_step(A, NORTH), NORTH)
	sleep(25)
	trench_climb_probe_assert(trench_climb_probe_at(A, 3, 6), "climbs_out_of_trench")

	// Climbing in from the ground also takes the tile path.
	var/mob/living/human/trench_climb_probe/D = trench_climb_probe_actor(4, 6)
	trench_climb_probe_assert(!D.human_subtile_eligible(SOUTH) && D.human_subtile_eligible(EAST), "climb_in_uses_tile_path")
	D.dir = SOUTH
	D.SelfMove(get_step(D, SOUTH), SOUTH)
	sleep(10)
	trench_climb_probe_assert(trench_climb_probe_at(D, 4, 5), "climbs_into_trench")

	// Smooth walking along the trench is unchanged.
	var/mob/living/human/trench_climb_probe/C = trench_climb_probe_actor(8, 5)
	C.SelfMove(get_step(C, EAST), EAST, world.time + 4)
	trench_climb_probe_assert(trench_climb_probe_at(C, 9, 5), "smooth_walk_along_trench")


/world/New()
	OpenPort("none")
	var/error = null
	try
		trench_climb_probe_run()
	catch (var/exception/probe_error)
		error = probe_error.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = trench_climb_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
