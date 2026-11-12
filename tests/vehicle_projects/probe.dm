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
var/project_deny_node = null
/obj/map_metadata/vehicle_project_probe/is_node_done(faction, node_id)
	return node_id != project_deny_node
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
// wheels and tracks are dragged onto the press.
/proc/project_finish(obj/structure/car_workshop/W, mob/living/human/H)
	var/list/paths = list("steel" = /obj/item/stack/material/steel, "glass" = /obj/item/stack/material/glass, "cloth" = /obj/item/stack/material/cloth, "cable" = /obj/item/stack/cable_coil)
	var/guard = 0
	while (!W.project_finished() && guard++ < 100)
		var/list/needed = W.project_needed()
		for (var/key in needed)
			if (key == "tracks")
				var/obj/structure/vehicleparts/movement/tracks/M = new(get_turf(H))
				W.MouseDrop_T(M, H)
			else if (key == "wheels")
				var/obj/structure/vehicleparts/movement/M = new(get_turf(H))
				// The press is always in reach; a narrow body's cells may not be.
				W.MouseDrop_T(M, H)
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

	// ---- Works vehicles: a truck, carriers and tanks ----
	project_check(W.one_go("ASNO Piccolino") && !W.one_go("Medium tank") && !W.one_go("No such model"), "works vehicles are not one-go models")
	var/obj/structure/car_workshop/hangar/project_probe/no_works = new(null)
	project_check(!no_works.works_spec("Medium tank") && !("Medium tank" in no_works.models()), "the hangar builds no works vehicles")
	qdel(no_works)
	W.stock = W.costs("Medium tank")
	project_check(!W.assemble_for(H, "Medium tank") && W.stock["steel"] == 300, "a tank cannot be assembled in one go")
	W.stock = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
	var/datum/piece_plan/TP = W.project_plan("Medium tank")
	var/list/tank_total = TP.total_cost()
	var/list/tank_cost = W.costs("Medium tank")
	same = tank_total.len == tank_cost.len
	for (var/key in tank_cost)
		same = same && tank_total[key] == tank_cost[key]
	var/list/stage_names = list()
	for (var/list/stage in TP.stages)
		stage_names += stage["name"]
	project_check(same && ("Tracks" in stage_names) && ("Turret" in stage_names) && !("Wheels" in stage_names) && !("Windows" in stage_names), "a tank plan costs its listed price, on tracks, with a turret stage ([json_encode(stage_names)])")
	var/list/truck_names = list()
	for (var/list/stage in W.project_plan("Cargo truck").stages)
		truck_names += stage["name"]
	project_check(("Wheels" in truck_names) && ("Windows" in truck_names) && !("Turret" in truck_names), "a truck plan has wheels and windows and no turret")
	project_deny_node = "mechanized_war"
	var/obj/structure/car_workshop/project_probe/R = new(locate(5, 20, 1))
	project_check(findtext(R.project_refusal("Medium tank", H), "research is required"), "a tank needs Mechanized Warfare ([R.project_refusal("Medium tank", H)])")
	project_check(!R.project_refusal("Cargo truck", H), "a truck needs only the press's research")
	project_deny_node = null
	project_check(!R.project_refusal("Medium tank", H), "with the research the tank can start")
	qdel(R)
	var/list/spots = list("Cargo truck" = list(5, 12), "Armoured car" = list(12, 12), "Tracked carrier" = list(19, 12), "Light tank" = list(5, 20), "Medium tank" = list(12, 20))
	for (var/model in spots)
		var/list/spot = spots[model]
		var/obj/structure/car_workshop/project_probe/V = new(locate(spot[1], spot[2], 1))
		V.stock = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
		H.loc = locate(spot[1] + 1, spot[2], 1)
		V.project_action(H, model)
		var/list/cells = V.project_layout(model)
		project_check(V.project == model && project_parts(V) == cells.len, "[model]: the jig fills its [cells.len] cells")
		var/datum/piece_plan/VP = V.get_project_plan()
		if (VP.total_cost()["tracks"])
			var/obj/structure/vehicleparts/movement/wrong = new(get_turf(H))
			V.project_done = 2
			V.update_project_frames()
			var/obj/structure/vehicle_project_part/jig = V.project_frames[1]
			jig.MouseDrop_T(wrong, H)
			project_check(!QDELETED(wrong) && V.project_done == 2, "[model]: a rubber wheel is not a track")
			qdel(wrong)
			V.project_done = 0
			V.update_project_frames()
		project_finish(V, H)
		project_check(V.project_finished(), "[model]: every piece fitted ([V.project_done] of [VP.total_pieces()])")
		var/obj/structure/vehicleparts/axis/made = V.roll_out_project(H)
		var/size = V.model_size(model)
		project_check(istype(made) && made.keyed_vehicle_id && made.name == lowertext(model), "[model]: rolls out keyed and named")
		if (!istype(made))
			continue
		project_check(made.components.len == size * size && made.wheels.len == 4, "[model]: fills its [size]x[size] square on four wheels or tracks ([made.components.len], [made.wheels.len])")
		project_check(made.engine && made.engine.fueltank && !made.engine.fueltank.reagents.total_volume && made.wheel, "[model]: engine, empty tank and steering linked")
		var/extras = 0
		var/shells = 0
		var/turrets = 0
		var/frames = 0
		for (var/dx = 1, dx <= 4, dx++)
			for (var/dy = 1, dy <= 4, dy++)
				var/turf/T = locate(V.x + dx, V.y + dy, 1)
				for (var/atom/movable/O in T)
					if (istype(O, /obj/item/weapon/gun) || istype(O, /obj/item/ammo_magazine) || istype(O, /obj/structure/supply_crate) || istype(O, /obj/structure/bed/chair/mgunner))
						extras++
					if (istype(O, /obj/structure/shellrack))
						var/obj/structure/shellrack/rack = O
						shells += rack.storage.contents.len
					if (istype(O, /obj/structure/turret))
						turrets++
					if (istype(O, /obj/structure/vehicleparts/frame))
						frames++
		project_check(!extras && !shells, "[model]: no free guns, ammunition, shells or supplies ([extras], [shells])")
		project_check(frames == cells.len, "[model]: every layout cell has its frame ([frames] of [cells.len])")
		project_check(turrets == (findtext(model, "tank") ? 1 : 0), "[model]: [findtext(model, "tank") ? "has its turret" : "has no turret"]")
		var/list/locations = list()
		for (var/atom/movable/part in made.components)
			locations[part] = part.loc
		var/turned = TRUE
		for (var/i = 1, i <= 4, i++)
			turned = made.do_matrix(made.dir, turn(made.dir, 90), "left") && turned
		var/back_home = TRUE
		for (var/atom/movable/part in locations)
			back_home = back_home && part.loc == locations[part]
		project_check(turned && back_home, "[model]: turns a full circle in place")
		project_check(!V.project && V.stock["steel"] == 0 && !V.stock["tracks"], "[model]: the project is spent")
	H.loc = locate(6, 5, 1)

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
