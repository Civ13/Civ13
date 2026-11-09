// Player submarines: the sea layer under deep ocean, diving, surfacing,
// submerged movement, the periscope, contacts and the submarine pen.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/submarine_probe
	sea_layer_surface_z = 2
/obj/map_metadata/submarine_probe/New()
	return
/mob/living/submarine_probe/New()
	return
/obj/covers/submarine_probe_raft
	name = "probe raft"
var/submarine_failures = 0
var/submarine_runtime_error = FALSE
/proc/submarine_check(condition, label)
	if (!condition)
		submarine_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	submarine_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/submarine_turf(x, y, z)
	var/turf/T = locate(x, y, z)
	return T

/proc/submarine_frames_z(obj/structure/vehicleparts/axis/ship/submarine/S, z)
	var/list/F = S.frames()
	if (!F.len)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		if (FR.z != z)
			return FALSE
	return TRUE

/proc/submarine_front_y(obj/structure/vehicleparts/axis/ship/submarine/S)
	. = 1000
	for (var/obj/structure/vehicleparts/frame/F in S.frames())
		. = min(., F.y)

/proc/submarine_checks()
	// Surface (z2): land at x 1-3, shallows at x 4, deep ocean from x 5.
	// Below (z1): solid rock, with an old tunnel dug at x 25-27, y 3.
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/S = locate(x, y, 2)
			if (x <= 3)
				S.ChangeTurf(/turf/floor/dirt)
			else if (x == 4)
				S.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
			else
				S.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/turf/B = locate(x, y, 1)
			B.ChangeTurf(/turf/wall/rockwall)
	for (var/x = 25, x <= 27, x++)
		locate(x, 3, 1).ChangeTurf(/turf/floor/dirt)

	// The sea layer opens only under open ocean, keeping a rock shell.
	submarine_check(sea_layer_z() == 1, "the sea layer lies on the level below the surface")
	var/opened = sea_layer_build(2, 1)
	submarine_check(opened > 300, "rock under the open ocean opens to the sea ([opened] cells)")
	submarine_check(sea_layer_cell(locate(15, 15, 1)), "a cell under open ocean is sea")
	submarine_check(submarine_turf(2, 15, 1).type == /turf/wall/rockwall, "rock under land stays rock")
	submarine_check(submarine_turf(5, 15, 1).type == /turf/wall/rockwall && sea_layer_cell(locate(6, 15, 1)), "a rock shell stays under the coast, sea starts one tile out")
	submarine_check(submarine_turf(24, 4, 1).type == /turf/wall/rockwall && submarine_turf(26, 4, 1).type == /turf/wall/rockwall && submarine_turf(26, 3, 1).type == /turf/floor/dirt, "an old tunnel keeps its rock shell and is not flooded")
	submarine_check(submarine_turf(1, 1, 1).type == /turf/wall/rockwall, "the map corner under land stays rock")
	submarine_check(sea_layer_build(2, 1) == 0, "a second pass changes nothing")

	// After a save load the pass waits for the world to settle first.
	sea_layer_ready_at = 0
	submarine_check(!sea_layer_settled() && sea_layer_ready_at == world.time, "the pass waits once the world is first seen ready")
	sea_layer_ready_at = world.time - 30 SECONDS
	submarine_check(!sea_layer_settled(), "the pass still waits half a minute after the world is ready")
	sea_layer_ready_at = world.time - 61 SECONDS
	submarine_check(sea_layer_settled(), "the pass starts a minute after the world is ready")

	// Nobody walks or swims into the sea layer.
	var/mob/living/submarine_probe/swimmer = new(locate(26, 3, 1))
	var/turf/sea = locate(15, 15, 1)
	submarine_check(!sea.CanPass(swimmer, sea), "a mob cannot enter open sea")
	submarine_check(!submarine_turf(5, 15, 2).CanPass(swimmer, submarine_turf(5, 15, 2)), "deep water on the surface still blocks a mob (unchanged)")

	// A submarine builds as a working ship: 15 hull frames, wheel, station, engine.
	var/obj/structure/vehicleparts/axis/ship/submarine/S = build_submarine(locate(10, 10, 2), "probe boat")
	submarine_check(istype(S) && S.frames().len == 15, "the submarine builds fifteen hull frames ([S ? S.frames().len : 0])")
	submarine_check(S && S.engine && S.engine.fueltank && (S in ship_axes), "an engine, a fuel tank and the ship registry are connected")
	var/obj/structure/vehicleparts/shipwheel/W = locate() in locate(13, 11, 2)
	submarine_check(W && W.ship == S, "the ship wheel steers this boat")
	var/obj/structure/vehicleparts/sub_station/station = locate() in locate(13, 12, 2)
	submarine_check(station && station.boat() == S, "the ballast and periscope station belongs to this boat")
	var/obj/structure/vehicleparts/frame/F1 = locate() in locate(12, 12, 2)
	submarine_check(F1 && !F1.noroof && F1.w_left[1] == "" && F1.w_right[1] == "", "the hull is roofed with open hatches amidships")
	submarine_check(!S.submerged && S.periscope_turf() == get_turf(S), "a new boat floats on the surface")

	// Crew and cargo aboard.
	var/mob/living/submarine_probe/crew = new(locate(13, 13, 2))
	var/obj/structure/closet/crate/cargo = new(locate(12, 13, 2))
	submarine_check(submarine_turf(15, 15, 1).CanPass(crew, submarine_turf(15, 15, 1)) == FALSE, "the sea refuses a mob with no hull over it")

	// Diving.
	S.moving = TRUE
	submarine_check(findtext(S.depth_refusal(TRUE), "stop"), "a moving boat must stop before it dives")
	S.moving = FALSE
	var/obj/covers/submarine_probe_raft/raft = new(locate(13, 14, 2))
	submarine_check(!S.depth_refusal(TRUE), "a stopped boat over open sea may dive")
	submarine_check(!S.change_depth(TRUE), "the boat dives")
	submarine_check(S.submerged && submarine_frames_z(S, 1), "every hull frame is on the sea layer")
	submarine_check(crew.z == 1 && cargo.z == 1 && station.z == 1 && W.z == 1 && S.engine.z == 1, "crew, cargo and machinery go down with the boat")
	var/turf/crew_here = get_turf(crew)
	submarine_check(crew_here.CanPass(crew, crew_here), "inside the hull the crew can move")
	submarine_check(!submarine_turf(15, 13, 1).CanPass(crew, crew_here), "the crew cannot leave a submerged boat")
	submarine_check(S.change_depth(TRUE) == "The boat is already submerged.", "a second dive is refused")
	var/turf/boat_here = get_turf(S)
	submarine_check(S.periscope_turf() == locate(boat_here.x, boat_here.y, 2), "the periscope looks at the surface straight above")

	// Surfacing is refused under anything floating.
	submarine_check(findtext(S.depth_refusal(FALSE), "probe raft"), "the boat cannot surface under a raft")
	qdel(raft)
	submarine_check(!S.depth_refusal(FALSE), "with the raft gone it may surface")
	var/turf/above_bow = submarine_turf(12, 10, 2)
	var/obj/structure/vehicle/raft/real_raft = new(above_bow)
	submarine_check(findtext(S.depth_refusal(FALSE), "[real_raft.name]"), "a moored raft above blocks surfacing too")
	qdel(real_raft)
	submarine_check(!S.depth_refusal(FALSE), "with both gone it may surface")

	// Contacts: ships and aircraft on the surface, submerged boats by sonar.
	var/obj/structure/vehicleparts/axis/ship/submarine/surface_ship = build_submarine(locate(20, 20, 2), "surface ship")
	var/obj/structure/vehicleparts/axis/ship/submarine/deep_boat = build_submarine(locate(18, 3, 2), "deep boat")
	submarine_check(deep_boat && !deep_boat.change_depth(TRUE), "a second boat dives")
	var/list/lines = S.contacts()
	var/text = jointext(lines, "\n")
	submarine_check(findtext(text, "Ship: surface ship"), "the periscope sees the surface ship ([text])")
	submarine_check(findtext(text, "Sonar: a submerged boat"), "sonar hears the other submerged boat")
	submarine_check(!findtext(text, "deep boat"), "sonar does not name the other boat")
	var/list/surface_lines = surface_ship.contacts()
	submarine_check(!findtext(jointext(surface_lines, "\n"), "submerged"), "a surface ship cannot see submerged boats ([jointext(surface_lines, "|")])")

	// Submerged movement follows the sea layer and stops at the seabed.
	var/obj/structure/engine/internal/E = S.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE
	S.anchor = FALSE
	S.moving = TRUE
	S.currentspeed = 1
	var/front = submarine_front_y(S)
	submarine_check(S.do_vehicle_check() && S.do_move(), "the submerged boat moves through open sea")
	submarine_check(submarine_front_y(S) == front - 1 && submarine_frames_z(S, 1) && crew.z == 1, "it moves a tile south on the sea layer with its crew")
	var/turf/ahead = locate(13, submarine_front_y(S) - 1, 1)
	ahead.ChangeTurf(/turf/wall/rockwall)
	submarine_check(!S.do_vehicle_check() && !S.moving, "rock ahead stops the boat")
	ahead.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
	E.on = FALSE

	// Surfacing brings everyone back up.
	S.moving = FALSE
	submarine_check(!S.change_depth(FALSE), "the boat surfaces")
	submarine_check(!S.submerged && submarine_frames_z(S, 2) && crew.z == 2 && cargo.z == 2, "the boat, crew and cargo are back on the surface")

	// Diving needs open sea under every frame: not beside the coast.
	var/obj/structure/vehicleparts/axis/ship/submarine/coaster = build_submarine(locate(2, 20, 2), "coaster")
	submarine_check(coaster && findtext(coaster.depth_refusal(TRUE), "seabed"), "a boat by the coast cannot dive ([coaster ? coaster.depth_refusal(TRUE) : "none"])")

	// Research and the submarine pen.
	if (!research_nodes.len)
		build_research_tree()
	var/datum/research_node/N = get_research_node("submarines")
	submarine_check(N && ("combustion" in N.prereqs) && ("wagons_ships" in N.prereqs) && N.era_tier == 6, "Submarines research follows ships and combustion")
	submarine_check(get_recipe_node_req("/obj/structure/car_workshop/submarine_pen") == "submarines", "Submarines research gates the pen (got [get_recipe_node_req("/obj/structure/car_workshop/submarine_pen")])")
	var/obj/structure/car_workshop/submarine_pen/pen = new(locate(3, 23, 2))
	submarine_check(pen.model_size("Submarine") == 5 && pen.costs("Submarine")["steel"] == 90 && !pen.allowed(null), "the pen builds only the submarine, after Submarines research")
	submarine_check(!pen.complete_assembly("Submarine"), "an empty pen builds nothing")
	pen.stock = list("steel" = 100, "glass" = 5, "cloth" = 0, "cable" = 12, "wheels" = 0)
	submarine_check(!pen.complete_assembly("Submarine"), "a pen whose bay reaches the shallows builds nothing")
	qdel(pen)
	pen = new(locate(20, 24, 2))
	pen.stock = list("steel" = 100, "glass" = 5, "cloth" = 0, "cable" = 12, "wheels" = 0)
	var/obj/structure/vehicleparts/axis/ship/submarine/built = pen.complete_assembly("Submarine")
	submarine_check(istype(built) && built.frames().len == 15, "the pen launches a submarine into its bay of deep sea")
	if (istype(built))
		var/obj/structure/engine/internal/BE = built.engine
		submarine_check(BE.fueltank && !BE.fueltank.reagents.total_volume, "the launched boat has an empty tank")
		submarine_check(built.keyed_vehicle_id && pen.stock["steel"] == 10 && pen.stock["cable"] == 0, "the pen issues keys and spends its inputs")

/proc/submarine_run()
	try
		submarine_checks()
	catch(var/exception/e)
		submarine_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = submarine_failures, "runtime_error" = submarine_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/submarine_probe
		submarine_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		submarine_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		submarine_run()
