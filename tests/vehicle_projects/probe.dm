// Vehicle projects: the automobile workshop and the aircraft hangar build a
// car or a plane piece by piece in their bay, like the slipway builds a ship.
// A project costs exactly what a one-go assembly does, takes a piece at a
// time from stacks and dragged wheels, shows the vehicle growing in the bay
// from the back row to the front, survives a reload from its three saved
// vars, and rolls out the same keyed vehicle the press builds in one go.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/vehicle_project_probe/New()
	return
/obj/map_metadata/vehicle_project_probe/is_node_done(faction, node_id)
	return TRUE
/mob/living/human/vehicle_project_probe/New()
	return
var/project_failures = 0
var/project_runtime_error = FALSE
/proc/project_check(condition, label)
	if (!condition)
		project_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	project_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Actor waits and the cable supply are adapters; the project code is real.
/obj/structure/car_workshop/project_probe/wait_for_piece(mob/living/human/H, atom/target)
	sleep(1)
	return TRUE
/obj/structure/car_workshop/project_probe/wait_for_assembly(mob/living/human/H)
	sleep(1)
	return TRUE
/obj/structure/car_workshop/project_probe/draw_cable_power()
	return TRUE
/obj/structure/car_workshop/hangar/project_probe/wait_for_piece(mob/living/human/H, atom/target)
	sleep(1)
	return TRUE
/obj/structure/car_workshop/hangar/project_probe/wait_for_assembly(mob/living/human/H)
	sleep(1)
	return TRUE
/obj/structure/car_workshop/hangar/project_probe/draw_cable_power()
	return TRUE

/proc/project_floor()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/dirt)

/proc/project_parts(obj/structure/car_workshop/W, text)
	. = 0
	for (var/obj/structure/vehicle_project_part/F in W.project_frames)
		if (!QDELETED(F) && (!text || findtext(F.name, text)))
			.++

/proc/project_bay_parts(obj/structure/car_workshop/W)
	. = 0
	for (var/dx = 1, dx <= 4, dx++)
		for (var/dy = 1, dy <= 4, dy++)
			for (var/obj/structure/vehicle_project_part/F in locate(W.x + dx, W.y + dy, W.z))
				.++

/proc/project_stack(path, amount, turf/T)
	var/obj/item/stack/S = new path(T)
	S.amount = amount
	return S

// Fits every remaining piece through the player paths: stacks hit the press,
// wheels are dragged onto the vehicle in the bay.
/proc/project_finish(obj/structure/car_workshop/W, mob/living/human/H)
	var/list/paths = list("steel" = /obj/item/stack/material/steel, "glass" = /obj/item/stack/material/glass, "cloth" = /obj/item/stack/material/cloth, "cable" = /obj/item/stack/cable_coil)
	var/guard = 0
	while (!W.project_finished() && guard++ < 100)
		var/list/needed = W.project_needed()
		for (var/key in needed)
			if (key == "wheels")
				var/obj/structure/vehicleparts/movement/M = new(get_turf(H))
				var/obj/structure/vehicle_project_part/F = W.project_frames[1]
				F.MouseDrop_T(M, H)
			else
				var/obj/item/stack/S = project_stack(paths[key], 100, get_turf(H))
				W.attackby(S, H)
				qdel(S)

/proc/project_checks()
	project_floor()
	var/mob/living/human/vehicle_project_probe/H = new(locate(6, 5, 1))

	// ---- A car ----
	var/obj/structure/car_workshop/project_probe/W = new(locate(5, 5, 1))
	W.stock = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
	var/datum/piece_plan/P = W.project_plan("ASNO Piccolino")
	var/list/total = P.total_cost()
	var/list/cost = W.costs("ASNO Piccolino")
	var/same = total.len == cost.len
	for (var/key in cost)
		same = same && total[key] == cost[key]
	project_check(same, "a car project costs what a one-go assembly does ([json_encode(total)] vs [json_encode(cost)])")
	project_check(P.total_pieces() == 11 && P.stages.len == 6, "a car takes 11 pieces in 6 stages ([P.total_pieces()], [P.stages.len])")
	var/list/large = W.project_plan("SMC Falcon").total_cost()
	project_check(large["steel"] == 60 && large["glass"] == 8, "a large car project costs the large car's steel and glass")
	var/list/options = W.project_options()
	project_check(options.len == W.models().len && options["Start a ASNO Piccolino piece by piece"] == "ASNO Piccolino", "the press offers a project for every model")
	var/obj/structure/car_workshop/shipyard/yard = new(null)
	project_check(!length(yard.project_options()), "the shipyard keeps its one-go assembly")
	qdel(yard)

	var/obj/item/crate = new /obj/item/stack/material/steel(locate(7, 7, 1))
	project_check(findtext(W.project_refusal("ASNO Piccolino", H), "Clear"), "a cluttered bay refuses a project")
	qdel(crate)
	project_check(!W.project_refusal("ASNO Piccolino", H), "a clear bay takes a project")
	W.project_action(H, "ASNO Piccolino")
	var/list/layout = W.project_layout("ASNO Piccolino")
	project_check(W.project == "ASNO Piccolino" && project_parts(W) == layout.len && project_parts(W, "jig") == layout.len, "the jig fills the car's [layout.len] cells")
	project_check(findtext(W.project_refusal("SMC Falcon", H), "already"), "one project at a time")
	project_check(!W.clear_footprint("ASNO Piccolino"), "the project keeps the bay from one-go builds and stored vehicles")

	var/obj/item/stack/material/glass/G = project_stack(/obj/item/stack/material/glass, 20, get_turf(H))
	W.attackby(G, H)
	project_check(G.amount == 20 && W.project_done == 0, "the chassis does not take glass")
	var/obj/item/stack/material/steel/S = project_stack(/obj/item/stack/material/steel, 5, get_turf(H))
	W.attackby(S, H)
	project_check(QDELETED(S) && W.project_paid["steel"] == 5 && W.project_done == 0, "a short stack is paid towards the piece")
	S = project_stack(/obj/item/stack/material/steel, 10, get_turf(H))
	W.attackby(S, H)
	project_check(W.project_done == 1 && S.amount == 7 && !length(W.project_paid), "the first chassis section is fitted and the rest of the stack kept")
	project_check(project_parts(W, "chassis") == 4, "half the chassis covers the back two of three rows ([project_parts(W, "chassis")])")
	var/back_rank = locate(/obj/structure/vehicle_project_part) in locate(7, 8, 1)
	project_check(back_rank && findtext(back_rank:name, "chassis"), "the chassis starts at the back of the car")
	W.attackby(S, H)
	project_check(W.project_done == 1 && QDELETED(S) && W.project_paid["steel"] == 7, "the leftover seven steel go towards the next section")
	S = project_stack(/obj/item/stack/material/steel, 10, get_turf(H))
	W.attackby(S, H)
	project_check(W.project_done == 2 && S.amount == 9 && project_parts(W, "chassis") == layout.len, "both chassis sections cover the car")
	var/obj/structure/vehicleparts/movement/M = new(get_turf(H))
	var/obj/structure/vehicle_project_part/F = W.project_frames[1]
	F.MouseDrop_T(M, H)
	project_check(QDELETED(M) && W.project_done == 3, "a wheel dragged onto the car is fitted")
	qdel(S)
	qdel(G)
	project_finish(W, H)
	project_check(W.project_finished() && W.project_done == 11, "every piece fitted ([W.project_done])")
	project_check(project_parts(W, "body") == layout.len, "the finished car shows its body in every cell")
	var/list/saved = W.get_saved_vars()
	project_check(("project" in saved) && ("project_done" in saved) && ("project_paid" in saved) && !("project_frames" in saved), "the project saves in three vars and its parts are not saved")
	for (var/obj/structure/vehicle_project_part/part in W.project_frames)
		project_check(!part.should_save, "project parts are never saved")
		break
	W.clear_project_frames()
	W.after_load()
	project_check(project_parts(W, "body") == layout.len && project_bay_parts(W) == layout.len, "a load rebuilds the parts from the saved project")
	options = W.project_options()
	project_check(options["Roll out the ASNO Piccolino"] == "roll out", "the finished car can be rolled out")
	var/obj/structure/vehicleparts/axis/car = W.roll_out_project(H)
	project_check(istype(car) && car.keyed_vehicle_id && car.components.len == 9 && car.wheels.len == 4, "the car rolls out keyed with four wheels")
	project_check(!W.project && !project_bay_parts(W) && W.stock["steel"] == 0 && W.stock["glass"] == 0 && W.stock["cable"] == 0, "the project is spent and the stock untouched")
	if (istype(car))
		project_check(car.engine && car.engine.fueltank && !car.engine.fueltank.reagents.total_volume, "the car leaves with an empty tank")

	// ---- A plane ----
	var/obj/structure/car_workshop/hangar/project_probe/A = new(locate(15, 5, 1))
	H.loc = locate(16, 5, 1)
	A.stock = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
	P = A.project_plan("Light plane")
	var/list/first = P.stages[1]
	project_check(first["name"] == "Airframe" && P.total_cost()["steel"] == 50 && P.total_cost()["wheels"] == 4, "the hangar's plane plan is an airframe of 50 steel on 4 wheels")
	A.project_action(H, "Light plane")
	project_check(project_parts(A) == 12, "the jig fills the plane's 12 cells")
	project_finish(A, H)
	project_check(A.project_finished() && project_parts(A, "body") == 12, "the finished plane shows its skin")
	var/obj/structure/vehicleparts/axis/aircraft/plane = A.roll_out_project(H)
	project_check(istype(plane) && plane.frames().len == 12 && plane.wheels.len == 4 && plane.keyed_vehicle_id, "the light plane rolls out whole and keyed")
	if (istype(plane))
		project_check(!plane.engine.fueltank.reagents.total_volume, "the plane leaves with an empty tank")
	project_check(!A.project && !project_bay_parts(A), "the hangar bay is clear for the next one")

	// ---- Abandoning ----
	qdel(plane)
	A.project_action(H, "Light plane")
	project_finish(A, H)
	A.abandon_project()
	project_check(!A.project && !project_bay_parts(A) && !A.project_done, "abandoning clears the jig")

/proc/project_run()
	try
		project_checks()
	catch(var/exception/e)
		project_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = project_failures, "runtime_error" = project_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/vehicle_project_probe
		project_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		project_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		project_run()
