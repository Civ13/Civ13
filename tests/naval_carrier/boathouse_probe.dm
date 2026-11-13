// The boathouse (code/modules/naval/boathouse.dm): a modular boat, a submarine
// and small boats are put away from the 7x7 slip into the office with their
// deck cargo, leave the map and the boat lists, and come back on the same
// tiles; refusals for boats under way, crewed, outside the slip or with a
// blocked slip; capacity; the load hook; the wrench turn.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/boathouse_probe/New()
	return
/mob/living/human/boathouse_probe/New()
	return
var/boathouse_failures = 0
var/boathouse_runtime_error = FALSE
/proc/boathouse_check(condition, label)
	if (!condition)
		boathouse_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	boathouse_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/obj/structure/boathouse_probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// Sand ashore (x 1-10), deep sea beyond.
/proc/boathouse_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(x <= 10 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)

/proc/boathouse_frames_at(list/cells)
	. = 0
	for (var/turf/T in cells)
		for (var/obj/structure/vehicleparts/frame/F in T)
			.++

/proc/boathouse_contains(atom/outer, atom/movable/M)
	var/atom/A = M
	while (A)
		if (A == outer)
			return TRUE
		A = A.loc
	return FALSE

/proc/boathouse_checks()
	boathouse_fixture()
	if (!research_nodes.len)
		build_research_tree()
	boathouse_check(get_recipe_node_req("/obj/structure/boathouse") == "wagons_ships", "Wagons & Ships gates the boathouse (got [get_recipe_node_req("/obj/structure/boathouse")])")

	var/mob/living/human/boathouse_probe/H = new(locate(9, 5, 1))
	var/obj/structure/boathouse/house = new(locate(10, 5, 1))
	var/list/slip = house.slip()
	boathouse_check(slip.len == 49 && (list(locate(11, 6, 1)) & slip).len && (list(locate(17, 12, 1)) & slip).len && !(list(locate(18, 12, 1)) & slip).len && !(list(locate(10, 6, 1)) & slip).len, "the slip is the 7x7 square north-east of the office ([slip.len])")
	boathouse_check(!house.boats_in_slip().len, "an empty slip holds no boats")

	// ---- The Teal: a 3 by 2 boat of ship frames with a crate on her deck ----
	for (var/dx = 0, dx < 3, dx++)
		for (var/dy = 0, dy < 2, dy++)
			new /obj/structure/vehicleparts/frame/ship(locate(12 + dx, 7 + dy, 1))
	var/obj/structure/vehicleparts/axis/ship/teal = new(locate(12, 7, 1))
	teal.name = "Teal"
	var/why = teal.assemble(EAST)
	boathouse_check(isnull(why) && deck_berth_frames(teal).len == 6, "the Teal is assembled in the slip ([why])")
	var/obj/item/stack/material/rope/cargo = new(locate(13, 8, 1))
	var/list/boats = house.boats_in_slip()
	boathouse_check(boats.len == 1 && boats[1] == teal, "the boathouse finds her in the slip ([boats.len])")
	boathouse_check(findtext(boathouse_boat_name(teal), "Teal"), "and calls her by name ([boathouse_boat_name(teal)])")

	teal.moving = TRUE
	boathouse_check(findtext(house.store_problem(teal, H), "Stop the boat"), "a boat under way is refused")
	teal.moving = FALSE
	var/mob/living/human/boathouse_probe/sailor = new(locate(14, 7, 1))
	boathouse_check(findtext(house.store_problem(teal, H), "Get everyone off"), "a crewed boat is refused ([house.store_problem(teal, H)])")
	sailor.loc = locate(9, 4, 1)
	boathouse_check(isnull(house.store_problem(teal, H)), "an empty, stopped boat may be put away ([house.store_problem(teal, H)])")

	// A boat half out of the slip is not offered.
	for (var/dy = 0, dy < 2, dy++)
		new /obj/structure/vehicleparts/frame/ship(locate(17 + 0, 14 + dy, 1))
		new /obj/structure/vehicleparts/frame/ship(locate(18, 14 + dy, 1))
	var/obj/structure/vehicleparts/axis/ship/stray = new(locate(17, 14, 1))
	stray.name = "Stray"
	stray.assemble(EAST)
	boathouse_check(!(stray in house.boats_in_slip()), "a boat lying outside the slip is not offered")

	var/list/teal_tiles = list()
	for (var/obj/structure/vehicleparts/frame/F in teal.components)
		teal_tiles += F.loc
	house.store_boat(teal)
	boathouse_check(!boathouse_frames_at(teal_tiles) && !isturf(teal.loc) && boathouse_contains(house, teal), "she is put away: no frame is left in the slip and her axis is inside the office")
	boathouse_check(boathouse_contains(house, cargo), "her deck cargo goes with her")
	boathouse_check(!(teal in ship_axes) && !(teal in house.boats_in_slip()), "a stored boat is off the boat list")
	boathouse_check(house.stored_names().len == 1 && findtext(house.stored_names()[1], "Teal"), "the office lists her ([english_list(house.stored_names())])")

	// ---- A Scout submarine in the slip ----
	var/obj/structure/vehicleparts/axis/ship/submarine/sub = build_submarine(locate(11, 6, 1), "Minnow")
	boathouse_check(istype(sub) && (sub in house.boats_in_slip()), "a submarine lying in the slip is offered")
	boathouse_check(findtext(house.retrieve_problem(house.stored_boats()[1]), "Another boat"), "the Teal cannot come out over the submarine ([house.retrieve_problem(house.stored_boats()[1])])")
	sub.submerged = TRUE
	boathouse_check(findtext(house.store_problem(sub, H), "Surface"), "a submerged submarine is refused")
	sub.submerged = FALSE
	sub.floodlights = TRUE
	boathouse_check(findtext(house.store_problem(sub, H), "floodlights"), "a submarine with her floodlights on is refused")
	sub.floodlights = FALSE
	var/sub_battery = sub.battery - 100
	sub.battery = sub_battery
	var/obj/structure/boathouse_stored/sub_store = house.store_boat(sub)
	boathouse_check(sub_store && !(sub in ship_axes) && !(sub in player_submarines), "the submarine is put away and off the submarine lists")
	// A world load makes the axis again, which registers itself; the office forgets it.
	ship_axes |= sub
	player_submarines |= sub
	house.after_load()
	boathouse_check(!(sub in ship_axes) && !(sub in player_submarines) && house.stored_boats().len == 2, "after a load the stored submarine stays off the lists")

	// ---- Small boats ----
	var/obj/structure/vehicle/raft/raft = new(locate(17, 12, 1))
	var/obj/structure/vehicle/boat/outrigger = new(locate(11, 11, 1))
	boats = house.boats_in_slip()
	boathouse_check((raft in boats) && (outrigger in boats), "a raft and an outrigger in the slip are offered ([boats.len])")
	house.store_boat(outrigger)
	boathouse_check(boathouse_contains(house, outrigger) && house.stored_boats().len == 3, "the outrigger is put away")
	boathouse_check(findtext(house.store_problem(raft, H), "full"), "a full boathouse refuses a fourth boat")

	// ---- Taking them out ----
	var/obj/structure/boathouse_stored/teal_store = null
	for (var/obj/structure/boathouse_stored/B in house.stored_boats())
		if (findtext(B.boat_name, "Teal"))
			teal_store = B
	var/obj/structure/boathouse_probe_rock/rock = new(locate(13, 7, 1))
	boathouse_check(findtext(house.retrieve_problem(teal_store), "in the way"), "a rock in the slip keeps the Teal in ([house.retrieve_problem(teal_store)])")
	qdel(rock)
	boathouse_check(isnull(house.retrieve_problem(teal_store)), "with the rock gone the slip is clear for her ([house.retrieve_problem(teal_store)])")
	var/atom/movable/out = house.retrieve_boat(teal_store)
	var/back = TRUE
	for (var/obj/structure/vehicleparts/frame/F in teal.components)
		if (!(F.loc in teal_tiles))
			back = FALSE
	boathouse_check(out == teal && back && boathouse_frames_at(teal_tiles) == 6, "the Teal comes back on the same tiles")
	boathouse_check(cargo.loc == locate(13, 8, 1), "with her cargo where it lay")
	boathouse_check((teal in ship_axes) && (teal in house.boats_in_slip()) && house.stored_boats().len == 2, "and is a boat afloat again")
	boathouse_check(findtext(house.retrieve_problem(sub_store), "Another boat"), "the submarine cannot come out over the Teal")
	house.store_boat(teal)
	boathouse_check(isnull(house.retrieve_problem(sub_store)), "with the Teal stored again the submarine may come out")
	out = house.retrieve_boat(sub_store)
	boathouse_check(out == sub && (sub in ship_axes) && (sub in player_submarines) && sub.battery == sub_battery && sub.name == "Minnow", "the submarine comes back with her name and battery")
	boathouse_check(deck_berth_frames(sub).len == 15, "and every hull frame ([deck_berth_frames(sub).len])")

	// ---- The wrench turns an empty boathouse only ----
	var/obj/item/weapon/wrench/W = new(locate(9, 5, 1))
	house.attackby(W, H)
	boathouse_check(house.slip_dir == NORTHEAST, "a boathouse with boats stored does not turn")
	for (var/obj/structure/boathouse_stored/B in house.stored_boats())
		if (B.boat() == outrigger)
			house.retrieve_boat(B)
	// Clear the office for the turn: the stored Teal is simply dropped.
	for (var/obj/structure/boathouse_stored/B in house.stored_boats())
		qdel(B)
	boathouse_check(!house.stored_boats().len && outrigger.loc == locate(11, 11, 1), "the outrigger comes back where it lay ([outrigger.loc] [outrigger.x],[outrigger.y]; [house.stored_boats().len] left)")
	house.attackby(W, H)
	boathouse_check(house.slip_dir == SOUTHEAST && (list(locate(11, 4, 1)) & house.slip()).len, "an empty boathouse turns its slip to the next corner")

/proc/boathouse_run()
	try
		boathouse_checks()
	catch(var/exception/e)
		boathouse_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = boathouse_failures, "runtime_error" = boathouse_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/boathouse_probe
		boathouse_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		boathouse_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		boathouse_run()
