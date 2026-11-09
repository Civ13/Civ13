// Train platform fixture: real train_platforms.dm, trains.dm and track laying
// procs on a small map. A locomotive pulls platform cars along straight track
// and round a curve; decks, walls and cargo must stay with each segment.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 26
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed train platform fixture"

/mob/living/human/platform_rider/New()
	return
/mob/living/human/platform_rider/update_icons()
	return

var/global/list/platform_probe_checks = list()
var/global/list/platform_probe_failed = list()
var/global/platform_probe_runtime_error = FALSE

/world/Error(exception/E)
	platform_probe_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/platform_check(label, passed)
	platform_probe_checks += list(list("label" = label, "passed" = !!passed))
	if (!passed)
		platform_probe_failed += label

/proc/platform_turf(x, y)
	return locate(x, y, 1)

/proc/platform_track(x, y, facing)
	var/obj/structure/rail_bed/B = track_place_bed(platform_turf(x, y), facing)
	B.place_rails()
	return B.spike()

/proc/platform_car(kind, x, y, heading)
	var/obj/structure/train_car_kit/K = new(platform_turf(x, y))
	K.set_kind(kind)
	var/problem = K.assembly_problem(heading)
	if (problem)
		world.log << "assembly problem: [problem]"
		return null
	return K.assemble(heading)

/proc/platform_segments(obj/structure/trains/platform/front)
	var/list/segs = list()
	var/obj/structure/trains/car = front
	while (istype(car, /obj/structure/trains/platform) && segs.len < 8)
		segs += car
		car = car.connected
	return segs

// Every deck part sits on its segment's tile for the segment's heading.
/proc/platform_parts_placed(list/segs)
	for (var/obj/structure/trains/platform/P in segs)
		if (!P.deck_parts || P.deck_parts.len < 2)
			return FALSE
		var/list/tiles = train_platform_tiles(P.loc, P.dir)
		for (var/obj/structure/train_part/part in P.deck_parts)
			if (part.loc != tiles[part.side + 2] || part.dir != part.facing(P.dir))
				return FALSE
	return TRUE

/proc/platform_car_tiles(list/segs)
	var/list/tiles = list()
	for (var/obj/structure/trains/platform/P in segs)
		tiles += train_platform_tiles(P.loc, P.dir)
	return tiles

/proc/platform_last(list/segs)
	if (segs.len < TRAIN_CAR_LENGTH)
		return null
	var/obj/structure/trains/platform/P = segs[TRAIN_CAR_LENGTH]
	return P.loc

/proc/platform_step(obj/structure/trains/locomotive/L, count)
	for (var/i in 1 to count)
		L.automovement = TRUE
		if (!L.process_rail_movement())
			return i - 1
	return count

/proc/platform_probe_run()
	// Track: north along x = 10, then east along y = 20.
	for (var/y in 2 to 20)
		platform_track(10, y, NORTH)
	for (var/x in 11 to 26)
		platform_track(x, 20, EAST)
	platform_check("track/corner", locate(/obj/structure/rails/turn) in platform_turf(10, 20))

	// Assembly needs straight track and room for the deck.
	var/obj/structure/train_car_kit/bad = new(platform_turf(10, 19))
	platform_check("assembly/needs_straight_track", bad.assembly_problem(EAST))
	qdel(bad)
	var/obj/structure/trains/platform/front = platform_car("flatbed", 10, 10, NORTH)
	var/list/segs = platform_segments(front)
	platform_check("assembly/four_segments", segs.len == TRAIN_CAR_LENGTH && !(locate(/obj/structure/train_car_kit) in platform_turf(10, 10)))
	platform_check("assembly/segments_on_track", front && front.loc == platform_turf(10, 10) && platform_last(segs) == platform_turf(10, 7))
	platform_check("assembly/decks_placed", platform_parts_placed(segs))
	platform_check("assembly/walkable", front && !front.density)
	var/obj/structure/train_part/sample = front.deck_parts[1]
	platform_check("parts/not_saved", !sample.should_save)
	var/obj/structure/train_car_kit/blocked = new(platform_turf(10, 12))
	platform_check("assembly/refuses_overlap", blocked.assembly_problem(NORTH))
	qdel(blocked)

	// Hitch: only the front of a car couples.
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(10, 11))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	L.connected = front

	// Load the deck: a crate on the left of section 2, a rider on the right of section 3.
	var/obj/structure/closet/crate/crate = new(platform_turf(9, 9))
	var/mob/living/human/platform_rider/rider = new(platform_turf(11, 8))
	var/obj/structure/wild/bush/bush = new(platform_turf(11, 12))

	platform_check("move/straight_steps", platform_step(L, 2) == 2)
	platform_check("move/segments_follow", front.loc == platform_turf(10, 12) && platform_last(segs) == platform_turf(10, 9))
	platform_check("move/crate_rides", crate.loc == platform_turf(9, 11))
	platform_check("move/rider_rides", rider.loc == platform_turf(11, 10))
	platform_check("move/decks_follow", platform_parts_placed(segs))

	// Round the corner and on to the end of the line.
	var/steps = platform_step(L, 40)
	platform_check("curve/reaches_end", L.loc == platform_turf(26, 20) && steps < 40)
	platform_check("curve/segments_on_track", front.loc == platform_turf(25, 20) && platform_last(segs) == platform_turf(22, 20))
	var/all_east = TRUE
	for (var/obj/structure/trains/platform/P in segs)
		if (P.dir != EAST)
			all_east = FALSE
	platform_check("curve/segments_face_east", all_east)
	platform_check("move/flora_left_behind", bush.loc == platform_turf(11, 12))
	platform_check("curve/decks_follow", platform_parts_placed(segs))
	var/list/car_tiles = platform_car_tiles(segs)
	platform_check("curve/crate_aboard", crate.loc in car_tiles)
	platform_check("curve/rider_aboard", rider.loc in car_tiles)

	// Taking the car apart needs it uncoupled and empty.
	platform_check("dismantle/coupled", findtext(front.dismantle_problem(), "Uncouple"))
	L.connected = null
	platform_check("dismantle/cargo", findtext(front.dismantle_problem(), "Clear everything"))
	qdel(crate)
	qdel(rider)
	platform_check("dismantle/ready", !front.dismantle_problem())
	var/obj/structure/train_car_kit/K = front.pack_car()
	platform_check("dismantle/kit", istype(K) && K.car_kind == "flatbed" && !K.furnished && K.loc == platform_turf(25, 20))
	var/leftovers = 0
	for (var/obj/structure/train_part/part in world)
		if (!QDELETED(part) && part.loc)
			leftovers++
	for (var/obj/structure/trains/platform/P in world)
		if (!QDELETED(P) && P.loc)
			leftovers++
	platform_check("dismantle/no_leftovers", !leftovers)

	// A coach on a second line: seats, doors and walls.
	for (var/y in 2 to 20)
		platform_track(32, y, NORTH)
	var/obj/structure/trains/platform/coach = platform_car("coach", 32, 10, NORTH)
	var/list/coach_segs = platform_segments(coach)
	var/chairs = 0
	for (var/turf/T in platform_car_tiles(coach_segs))
		for (var/obj/structure/bed/chair/C in T)
			chairs++
	platform_check("coach/seats", chairs == 6)
	var/obj/structure/train_part/edge/door = null
	for (var/obj/structure/train_part/edge/E in coach.deck_parts)
		if (E.style == "door" && E.side == TRAIN_LEFT && E.edge_kind == "out")
			door = E
	platform_check("coach/side_door", door && door.density && door.loc == platform_turf(31, 10))
	var/obj/item/weapon/hammer/probe_item = new(platform_turf(30, 9))
	var/turf/window_deck = platform_turf(31, 9)
	platform_check("coach/window_blocks", !window_deck.Enter(probe_item))
	probe_item.loc = platform_turf(30, 10)
	var/turf/door_deck = platform_turf(31, 10)
	platform_check("coach/closed_door_blocks", !door_deck.Enter(probe_item))
	door.set_open(TRUE)
	coach.open_doors |= 1 << (door.edge_index - 1)
	platform_check("coach/open_door_passes", door_deck.Enter(probe_item))
	coach.apply_layout()
	var/reopened = FALSE
	for (var/obj/structure/train_part/edge/E in coach.deck_parts)
		if (E.edge_index == door.edge_index && E.open && !E.density)
			reopened = TRUE
	platform_check("coach/door_state_rebuilt", reopened)

	// A wall beside the line stops the train before the deck scrapes it.
	var/obj/structure/trains/locomotive/coal/L2 = new(platform_turf(32, 11))
	L2.dir = NORTH
	L2.fuel = 100
	L2.on = TRUE
	L2.connected = coach
	var/turf/wall = platform_turf(33, 11)
	wall.density = TRUE
	platform_check("clearance/stops", platform_step(L2, 1) == 0 && L2.loc == platform_turf(32, 11) && !L2.automovement)
	platform_check("clearance/car_unmoved", coach.loc == platform_turf(32, 10) && platform_parts_placed(coach_segs))
	wall.density = FALSE
	platform_check("clearance/clear_again", platform_step(L2, 1) == 1 && coach.loc == platform_turf(32, 11))

	// Interior segments refuse to be unhitched.
	var/obj/structure/trains/platform/middle = coach_segs[2]
	platform_check("hitch/middle_kept", middle.connected == coach_segs[3])

	// Every kind builds.
	var/kinds_ok = TRUE
	var/x = 2
	for (var/kind in list("sleeper", "dining", "storage"))
		for (var/y in 2 to 6)
			platform_track(x + 1, y, NORTH)
		if (!platform_car(kind, x + 1, 6, NORTH))
			kinds_ok = FALSE
		x += 3
	platform_check("kinds/all_assemble", kinds_ok)

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new
	try
		platform_probe_run()
	catch (var/exception/E)
		platform_probe_runtime_error = TRUE
		world.log << "Fixture aborted: [E] at [E.file]:[E.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = platform_probe_checks.len, "failed_labels" = platform_probe_failed, "runtime_error" = platform_probe_runtime_error, "checks" = platform_probe_checks)), "result.json")
	world.log << "COMPLETE train platform fixture"
	del(world)
