// Factory automation phase 2: belt drives, sorting gates, splitters and belt
// tunnels. Runs the production sources through the shared resource-extraction
// fixture with ordinary game startup disabled; belt steps are called directly.
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/route_probe/New()
	return
/mob/living/human/route_probe/New()
	return
/mob/living/human/route_probe/update_icons()
	return
var/route_failures = 0
var/route_runtime_error = FALSE
/proc/route_check(condition, label)
	if (!condition)
		route_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	route_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/belt_floor(x, y)
	var/turf/T = locate(x, y, 1)
	return T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
/proc/belt_run(steps)
	for (var/i in 1 to steps)
		factory_belts_step()
/proc/belt_count(atom/A, type)
	var/total = 0
	for (var/obj/item/stack/S in A)
		if (S.type == type)
			total += S.amount
	return total
/proc/belt_closed_crate(turf/T, capacity = 20)
	var/obj/structure/closet/crate/C = new(T)
	C.opened = FALSE
	C.storage_capacity = capacity
	for (var/obj/item/I in C)
		qdel(I)
	return C
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/route_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				belt_floor(x, y)
		route_check(!world.port, "fixture has no listening port")
		route_drive_checks()
		var/obj/structure/factory_drive/D = route_drive(16, 16, 30)
		route_gate_checks()
		route_splitter_checks()
		route_tunnel_checks()
		route_save_checks(D)
		route_catalog_checks()
	catch(var/exception/e)
		route_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = route_failures, "runtime_error" = route_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/belt_make(x, y, d, type = /obj/structure/factory_belt)
	var/obj/structure/factory_belt/B = new type(locate(x, y, 1))
	B.set_dir(d)
	return B

/proc/route_drive(x, y, range)
	var/obj/structure/factory_drive/D = new(locate(x, y, 1))
	D.drive_range = range
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = 100
	E.connections = list(C)
	C.connections = list(D, E)
	D.powersource = C
	D.on = TRUE
	D.drive_wake()
	factory_drives_step()
	return D

/proc/route_drive_checks()
	var/obj/structure/factory_belt/A = belt_make(2, 2, EAST)
	var/obj/structure/factory_belt/B = belt_make(3, 2, EAST)
	var/obj/structure/factory_belt/C = belt_make(4, 2, EAST)
	var/obj/structure/factory_belt/far = belt_make(14, 2, EAST)
	var/obj/item/stack/material/stone/S = new(A.loc, 1, FALSE)
	var/obj/item/stack/material/stone/S2 = new(far.loc, 1, FALSE)
	A.belt_wake()
	far.belt_wake()
	belt_run(2)
	route_check(S.loc == A.loc && !(A in factory_active_belts) && !A.belt_powered(), "a belt without a powered drive in range stands still and sleeps")
	var/obj/structure/factory_drive/D = new(locate(2, 4, 1))
	belt_run(1)
	route_check(!D.powered && S.loc == A.loc, "a drive that is off powers nothing")
	var/obj/structure/cable/cable = new(locate(2, 4, 1))
	var/obj/structure/engine/E = new(locate(2, 4, 1))
	E.on = TRUE
	E.maxpower = 10
	E.connections = list(cable)
	cable.connections = list(D, E)
	D.powersource = cable
	D.on = TRUE
	D.drive_wake()
	belt_run(1)
	route_check(D.powered && cable.currentflow == 4, "a cabled drive reserves 4 PU")
	route_check(S.loc == B.loc, "the drive wakes the belts in its range and they move cargo")
	route_check(S2.loc == far.loc && !far.belt_powered(), "a belt beyond the drive's seven tiles stays still")
	E.on = FALSE
	belt_run(1)
	route_check(!D.powered && !(D in factory_powered_drives), "a drive loses power when its engine stops")
	var/at = S.loc
	belt_run(2)
	route_check(S.loc == at && !(B in factory_active_belts) && !(C in factory_active_belts), "belts stop and sleep when their drive loses power")
	E.on = TRUE
	belt_run(2)
	route_check(D.powered && S.loc != at, "belts resume when the drive regains power")
	D.attack_hand(new /mob/living/human/route_probe(locate(1, 1, 1)))
	route_check(!D.on && !D.powered && !(D in factory_active_drives) && cable.currentflow == 0, "switching a drive off releases its power")
	for (var/obj/O in list(A, B, C, far, S, S2, D, cable, E))
		qdel(O)
	for (var/mob/M in locate(1, 1, 1))
		qdel(M)

/proc/route_gate_checks()
	var/obj/structure/factory_belt/in_belt = belt_make(2, 6, EAST)
	var/obj/structure/factory_belt/routing/gate/G = belt_make(3, 6, EAST, /obj/structure/factory_belt/routing/gate)
	var/obj/structure/closet/crate/straight = belt_closed_crate(locate(4, 6, 1))
	var/obj/structure/closet/crate/side = belt_closed_crate(locate(3, 5, 1))
	route_check(G.side_dir() == SOUTH, "a gate's side output starts on its right")
	var/obj/item/stack/material/stone/stone = new(in_belt.loc, 1, FALSE)
	var/obj/item/stack/material/wood/wood = new(in_belt.loc, 1, FALSE)
	in_belt.belt_wake()
	belt_run(4)
	route_check(stone.loc == straight && wood.loc == straight, "a gate without a filter sends everything straight on")
	G.filter_type = /obj/item/stack/material/wood
	new /obj/item/stack/material/stone(in_belt.loc, 1, FALSE)
	var/obj/item/stack/material/wood/wood2 = new(in_belt.loc, 1, FALSE)
	in_belt.belt_wake()
	belt_run(4)
	route_check(wood2.loc == side && belt_count(straight, /obj/item/stack/material/stone) == 2 && belt_count(side, /obj/item/stack/material/stone) == 0, "a gate sends matching items to the side and the rest straight on")
	G.side_left = TRUE
	route_check(G.side_dir() == NORTH, "a screwdriver swap points the side output left")
	var/obj/structure/factory_belt/branch = belt_make(3, 7, NORTH)
	var/obj/item/stack/material/wood/wood3 = new(in_belt.loc, 1, FALSE)
	in_belt.belt_wake()
	belt_run(2)
	route_check(wood3.loc == branch.loc, "a gate hands side items onto a branch belt")
	for (var/obj/O in list(in_belt, G, straight, side, branch, wood3))
		qdel(O)

/proc/route_splitter_checks()
	var/obj/structure/factory_belt/in_belt = belt_make(2, 9, EAST)
	var/obj/structure/factory_belt/routing/splitter/P = belt_make(3, 9, EAST, /obj/structure/factory_belt/routing/splitter)
	var/obj/structure/closet/crate/straight = belt_closed_crate(locate(4, 9, 1))
	var/obj/structure/closet/crate/side = belt_closed_crate(locate(3, 8, 1))
	for (var/i in 1 to 4)
		new /obj/item/stack/material/stone(in_belt.loc, 1, FALSE)
	in_belt.belt_wake()
	belt_run(8)
	route_check(belt_count(straight, /obj/item/stack/material/stone) == 2 && belt_count(side, /obj/item/stack/material/stone) == 2, "a splitter alternates straight and side")
	side.opened = TRUE
	for (var/i in 1 to 3)
		new /obj/item/stack/material/stone(in_belt.loc, 1, FALSE)
	in_belt.belt_wake()
	belt_run(8)
	route_check(belt_count(straight, /obj/item/stack/material/stone) == 5, "a splitter with a blocked side sends everything straight on")
	for (var/obj/O in list(in_belt, P, straight, side))
		qdel(O)
	for (var/obj/item/I in locate(3, 8, 1))
		qdel(I)

/proc/route_tunnel_checks()
	var/obj/structure/factory_belt/tunnel/T = belt_make(2, 12, EAST, /obj/structure/factory_belt/tunnel)
	var/obj/structure/factory_belt/cross = belt_make(4, 12, NORTH)
	var/obj/structure/factory_belt/tunnel_exit/X = belt_make(7, 12, EAST, /obj/structure/factory_belt/tunnel_exit)
	var/obj/structure/closet/crate/out = belt_closed_crate(locate(8, 12, 1))
	route_check(T.tunnel_exit() == X, "a tunnel entrance finds the exit facing the same way ahead")
	var/obj/item/stack/material/stone/S = new(T.loc, 1, FALSE)
	T.belt_wake()
	belt_run(1)
	route_check(S.loc == X.loc && X.cargo[1] == S, "a tunnel carries cargo under a crossing belt to its exit")
	belt_run(2)
	route_check(S.loc == out, "the tunnel exit continues the line")
	X.set_dir(WEST)
	route_check(!T.tunnel_exit(), "an exit facing another way is not connected")
	var/obj/item/stack/material/stone/S2 = new(T.loc, 1, FALSE)
	T.belt_wake()
	belt_run(3)
	route_check(S2.loc == T.loc && T.cargo[4] == S2, "an entrance without an exit holds its cargo")
	X.set_dir(EAST)
	belt_run(4)
	route_check(S2.loc != T.loc, "the entrance resumes once its exit is back")
	var/obj/structure/factory_belt/tunnel_exit/too_far = belt_make(10, 14, EAST, /obj/structure/factory_belt/tunnel_exit)
	var/obj/structure/factory_belt/tunnel/T2 = belt_make(2, 14, EAST, /obj/structure/factory_belt/tunnel)
	route_check(!T2.tunnel_exit(), "an exit more than six tiles ahead is out of reach")
	for (var/obj/O in list(T, cross, X, out, too_far, T2))
		qdel(O)

/proc/route_save_checks(obj/structure/factory_drive/D)
	route_check(D.persistence_runtime_var("powered") && !D.persistence_runtime_var("on"), "a drive saves its switch but not its power state")
	var/obj/structure/factory_belt/B = belt_make(12, 6, EAST)
	route_check(B.persistence_runtime_var("drive"), "a belt's cached drive is runtime-only")
	var/obj/structure/factory_belt/routing/gate/G = belt_make(12, 8, EAST, /obj/structure/factory_belt/routing/gate)
	route_check(!G.persistence_runtime_var("filter_type") && !G.persistence_runtime_var("side_left"), "a gate saves its filter and side")
	var/obj/structure/factory_belt/routing/splitter/P = belt_make(12, 10, EAST, /obj/structure/factory_belt/routing/splitter)
	route_check(P.persistence_runtime_var("side_next"), "a splitter's alternation is runtime-only")
	D.powered = FALSE
	D.after_load()
	route_check((D in factory_active_drives) && !(D in factory_powered_drives), "a reloaded running drive resumes unpowered")
	factory_drives_step()
	route_check(D.powered, "the reloaded drive regains power on its next step")
	for (var/obj/O in list(B, G, P))
		qdel(O)

/proc/route_catalog_checks()
	route_check(get_recipe_node_req("/obj/structure/factory_drive") == "factories", "belt drives unlock with Factories alongside belts")
	route_check(get_recipe_node_req("/obj/item/factory_belt_assembly/gate") == "automation" && get_recipe_node_req("/obj/item/factory_belt_assembly/splitter") == "automation" && get_recipe_node_req("/obj/item/factory_belt_assembly/tunnel") == "automation" && get_recipe_node_req("/obj/item/factory_belt_assembly/tunnel_exit") == "automation", "routing belts unlock with Automation")
	var/list/states = icon_states('icons/obj/modern_structures.dmi')
	route_check(("circuit0" in states) && ("circuit1" in states), "drive sprite states exist")
	var/list/belt_states = icon_states('icons/obj/recycling.dmi')
	route_check(("diverter0" in belt_states) && ("diverter1" in belt_states), "gate and splitter overlay states exist")
	var/list/found = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		for (var/path in list("/obj/structure/factory_drive,", "/obj/item/factory_belt_assembly/gate,", "/obj/item/factory_belt_assembly/splitter,", "/obj/item/factory_belt_assembly/tunnel,", "/obj/item/factory_belt_assembly/tunnel_exit,"))
			if (findtext(line, "RECIPE: ") == 1 && findtext(line, path))
				found |= path
	route_check(found.len == 5, "the drive and four routing parts have global recipes")
