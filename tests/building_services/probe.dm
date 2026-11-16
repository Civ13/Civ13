// Native probe for cables and pipes through walls
// (code/game/objects/building_services.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/building_services/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 20
	maxz = 2
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/building_services_probe/New()
	return
var/vr_failures = 0
var/vr_runtime_error = FALSE
/proc/vr_check(condition, label)
	if (!condition)
		vr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
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
		map = new /obj/map_metadata/building_services_probe
		Master.start_timer_loop()
		vr_checks()
	catch(var/exception/e)
		vr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vr_failures, "runtime_error" = vr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/vr_checks()
	var/mob/living/human/U = new /mob/living/human(locate(5, 4, 1))
	U.a_intent = I_HELP
	var/obj/covers/wood_wall/W = new /obj/covers/wood_wall(locate(5, 5, 1))
	var/obj/item/stack/cable_coil/coil = new /obj/item/stack/cable_coil(U)
	coil.amount = 10

	// Nothing goes in before a chase is cut.
	vr_check(W.building_service_attackby(coil, U) && !W.service_cable() && coil.amount == 10, "a coil on an unchased wall only explains")

	// A chisel cannot cut stone; a pickaxe is needed there.
	var/obj/covers/stone_wall/S = new /obj/covers/stone_wall(locate(10, 5, 1))
	var/obj/item/weapon/chisel_probe = null
	for (var/path in typesof(/obj/item))
		var/obj/item/I = path
		if (initial(I.tool_flags) & TOOL_CHISEL)
			chisel_probe = new path(U)
			break
	vr_check(chisel_probe && S.building_service_attackby(chisel_probe, U) && !S.service_chase, "a chisel does not cut a chase in stone")

	// A chased wall takes a straight cable that joins both sides.
	W.service_chase = TRUE
	var/obj/structure/cable/south = new /obj/structure/cable(locate(5, 4, 1))
	south.set_cable_shape(NORTH, SOUTH)
	var/obj/structure/cable/north = new /obj/structure/cable(locate(5, 6, 1))
	north.set_cable_shape(NORTH, SOUTH)
	W.building_service_attackby(coil, U)
	var/obj/structure/cable/inside = W.service_cable()
	vr_check(inside && coil.amount == 9, "a coil feeds one cable through the chase")
	vr_check(inside && (south in inside.connections) && (north in inside.connections), "the cable in the wall joins the cables on both sides")
	W.building_service_attackby(coil, U)
	vr_check(coil.amount == 9, "only one cable fits in a chase")

	// A pipe on the user's tile slides into the wall and joins its neighbours.
	var/obj/covers/wood_wall/W2 = new /obj/covers/wood_wall(locate(15, 5, 1))
	W2.service_chase = TRUE
	var/obj/structure/aqueduct/pipe/P = new /obj/structure/aqueduct/pipe(locate(15, 4, 1))
	new /obj/structure/aqueduct/pipe(locate(15, 6, 1))
	building_service_move(P, get_turf(W2))
	vr_check(W2.service_pipe() == P, "the water pipe now runs inside the wall")
	vr_check(aqueduct_piece_at(get_step(P, NORTH)) && aqueduct_piece_at(get_turf(P)) == P, "the pipe in the wall sits next to the pipe beyond it")
	var/obj/structure/fluid_pipe/FP = new /obj/structure/fluid_pipe(locate(16, 4, 1))
	vr_check(building_service_pipe(FP) && !building_service_pipe(new /obj/structure/sewer_piece/drain(locate(17, 4, 1))), "factory pipes fit a chase, drains do not")

	// Breaking the wall cuts the cable and bursts the pipe.
	qdel(W)
	vr_check(QDELETED(inside), "the cable inside snaps when the wall breaks")
	qdel(W2)
	vr_check(QDELETED(P), "the pipe inside bursts when the wall breaks")
	vr_check(!QDELETED(south) && !QDELETED(north), "cables outside the wall survive")

	// Floor sleeves: pipes at the same spot on two levels join.
	var/turf/up_t = locate(20, 10, 2)
	var/turf/down_t = locate(20, 10, 1)
	var/obj/structure/fluid_pipe/FU = new /obj/structure/fluid_pipe(up_t)
	var/obj/structure/fluid_pipe/FD = new /obj/structure/fluid_pipe(down_t)
	vr_check(!(FD in fluid_pipe_neighbours(FU)), "pipes on two levels do not join without sleeves")
	new /obj/structure/floor_sleeve(up_t)
	vr_check(!floor_sleeve_link(up_t, FALSE), "one sleeve alone joins nothing")
	var/obj/structure/floor_sleeve/SD = new /obj/structure/floor_sleeve(down_t)
	vr_check(floor_sleeve_link(up_t, FALSE) == down_t && floor_sleeve_link(down_t, TRUE) == up_t, "a sleeve pair links the two levels")
	vr_check((FD in fluid_pipe_neighbours(FU)) && (FU in fluid_pipe_neighbours(FD)), "factory pipes join through sleeves both ways")

	// Aqueduct water falls through a sleeve but never climbs one.
	new /turf/floor/beach/water(locate(22, 12, 2))
	var/obj/structure/aqueduct_intake/IU = new /obj/structure/aqueduct_intake(locate(21, 12, 2))
	new /obj/structure/aqueduct/pipe(locate(21, 11, 2))
	new /obj/structure/aqueduct/pipe(locate(21, 10, 2))
	var/obj/structure/aqueduct/pipe/AU = new /obj/structure/aqueduct/pipe(locate(20, 10, 2))
	var/obj/structure/aqueduct/pipe/AD = new /obj/structure/aqueduct/pipe(locate(20, 10, 1))
	var/obj/structure/aqueduct/pipe/AD2 = new /obj/structure/aqueduct/pipe(locate(19, 10, 1))
	var/list/reached = aqueduct_walk(IU)
	vr_check(reached[AU] && reached[AD] && reached[AD2], "aqueduct water falls through the sleeve to the level below")
	new /turf/floor/beach/water(locate(17, 10, 1))
	var/obj/structure/aqueduct_intake/ID = new /obj/structure/aqueduct_intake(locate(18, 10, 1))
	reached = aqueduct_walk(ID)
	vr_check(reached[AD] && !reached[AU], "aqueduct water does not climb a sleeve")

	// Drains: waste falls through a sleeve, never up.
	var/obj/structure/sewer_piece/drain/DU = new /obj/structure/sewer_piece/drain(locate(25, 15, 2))
	var/obj/structure/sewer_piece/drain/DD = new /obj/structure/sewer_piece/drain(locate(25, 15, 1))
	new /obj/structure/floor_sleeve(locate(25, 15, 2))
	new /obj/structure/floor_sleeve(locate(25, 15, 1))
	var/datum/callback/never = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(building_probe_never))
	vr_check(DD in sewer_walk(list(DU), never), "waste falls through a sleeve to the drain below")
	vr_check(!(DU in sewer_walk(list(DD), never)), "waste does not climb a sleeve")

	// Taking a sleeve away parts the levels.
	qdel(SD)
	vr_check(!floor_sleeve_link(up_t, FALSE) && !(FD in fluid_pipe_neighbours(FU)), "removing a sleeve parts the pipes")

/proc/building_probe_never(obj/O)
	return FALSE
