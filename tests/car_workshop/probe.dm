// Full production sources. No normal world startup or external adapters.
/world
	hub = ""
	hub_password = ""
	maxx = 32
	maxy = 32
	maxz = 1
	turf = /turf
	area = /area
/obj/map_metadata/car_probe/New()
	return
// Actor startup and waits are adapters; construction/movement/serializer are real.
/mob/living/human/car_probe/New()
	return
/obj/structure/car_workshop/car_probe
	var/test_action = "complete"
/obj/structure/car_workshop/car_probe/wait_for_assembly(mob/living/human/H)
	sleep(1)
	if (test_action == "cancel") return FALSE
	if (test_action == "lose inputs") stock["steel"] = 0
	if (test_action == "obstruction") new /obj(locate(x+1,y+1,z))
	if (test_action == "move away") H.loc = locate(1,1,1)
	if (test_action == "power loss")
		for (var/obj/structure/engine/E in powersource.connections) E.on = FALSE
	return TRUE
var/car_probe_checks = 0
var/car_probe_error = FALSE
/world/Error(exception/E)
	car_probe_error = TRUE
	text2file("FAIL: runtime [E] at [E.file]:[E.line]", "car-result.txt")
	world.log << "CAR RUNTIME: [E] at [E.file]:[E.line]"
/proc/car_check(condition, label)
	if (!condition) throw EXCEPTION(label)
	car_probe_checks++
	world.log << "CAR PASS: [label]"
/proc/car_clear()
	for (var/obj/structure/vehicleparts/axis/A in world)
		A.stopmovementloop()
		if (A.engine) A.engine.on = FALSE
	for (var/atom/movable/M in world)
		if (!istype(M, /obj/map_metadata))
			qdel(M)
			if (M) del(M)
/proc/car_fill(obj/structure/car_workshop/W, model)
	W.stock = W.costs(model)
/proc/car_check_vehicle(obj/structure/vehicleparts/axis/A, size)
	car_check(A && istype(A.loc, /obj/structure/vehicleparts/frame), "controller nested in body")
	car_check(A.components.len == size*size && A.wheels.len == 4, "bounded footprint and four connected wheels")
	car_check(A.engine && A.engine.fueltank && A.wheel && A.wheel.control:axis == A, "engine, tank and steering linked")
	car_check(A.engine.fueltank.reagents.total_volume == 0, "no free fuel")
	car_check(!A.check_engine(), "unfuelled car stalls")
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE
	car_check(A.check_engine(), "fuelled engine starts")
	var/list/locations = list()
	for (var/atom/movable/P in A.components) locations[P] = P.loc
	for (var/side in list("left", "right"))
		for (var/i = 1, i <= 4, i++)
			car_check(A.do_matrix(A.dir, turn(A.dir, side == "left" ? 90 : -90), side), "constructed [side] turn [i]")
		for (var/atom/movable/P in locations)
			car_check(P.loc == locations[P], "full rotation restores component location")
	A.moving = TRUE
	A.currentspeed = 1
	var/turf/old_turf = get_turf(A)
	var/can_drive = A.do_vehicle_check()
	A.add_transporting()
	var/moved = A.do_move()
	var/turf/new_turf = get_turf(A)
	car_check(can_drive && moved && new_turf.y == old_turf.y - 1, "constructed car moves south")
	A.stopmovementloop()
	car_check(!A.moving && A.currentspeed == 0 && A.movement_processes == 0 && !A.transforming_vehicle, "movement stops without pending callback or transform state")
	E.on = FALSE
/world/New()
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/car_probe
		map.ordinal_age = 8
		for (var/turf/T in world) T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		var/obj/structure/car_workshop/W = new(locate(12,12,1))
		car_check("workbench" in icon_states(W.icon), "effective workshop sprite exists")
		car_check(get_recipe_node_req("/obj/structure/car_workshop") == "automobiles", "workshop research mapping")
		var/list/models = W.models()
		for (var/model in models)
			car_clear()
			W = new(locate(12,12,1))
			car_fill(W, model)
			var/obj/structure/vehicleparts/axis/A = W.complete_assembly(model)
			car_check(A && !W.stock["steel"] && !W.stock["wheels"], "[model] pays once")
			car_check(!W.complete_assembly(model), "no duplicate unpaid car")
			car_check_vehicle(A, W.model_size(model))
		for (var/action in list("cancel", "lose inputs", "obstruction", "move away", "power loss", "complete"))
			car_clear()
			var/obj/structure/car_workshop/car_probe/P = new(locate(12,12,1))
			P.test_action = action
			car_fill(P, "ASNO Piccolino")
			var/mob/living/human/car_probe/H = new(locate(11,12,1))
			H.civilization = "none"
			var/obj/structure/cable/C = new(locate(12,11,1))
			var/obj/structure/engine/E = new(locate(12,11,1))
			E.maxpower = 30
			E.on = TRUE
			C.connections = list(P,E)
			E.connections = list(C)
			P.MouseDrop_T(C, H)
			car_check(P.powersource == C && (P in C.connections), "player cable connection")
			var/obj/structure/vehicleparts/axis/A = P.assemble_for(H,"ASNO Piccolino")
			car_check((action == "complete") == !!A, "timed guard: [action]")
			car_check(!P.busy && P.powerneeded == 0 && C.currentflow == 0, "[action] releases busy/power")
			if (action != "complete") car_check(P.stock["wheels"] == 4 && P.stock["cable"] == 10 && P.stock["glass"] == 6, "[action] keeps remaining inputs")
		car_clear()
		W = new(locate(12,12,1))
		var/mob/living/human/car_probe/H = new(locate(11,12,1))
		H.civilization = "none"
		var/obj/item/stack/material/steel/S = new(locate(11,12,1), 45, FALSE)
		W.attackby(S,H)
		car_check(W.stock["steel"] == 45 && S.amount == 0, "material input paid exactly")
		var/obj/structure/vehicleparts/movement/paid_wheel = new(locate(11,12,1))
		W.MouseDrop_T(paid_wheel,H)
		W.MouseDrop_T(paid_wheel,H)
		car_check(W.stock["wheels"] == 1, "queued wheel deletion cannot pay twice")
		W.unload()
		var/refunded = 0
		var/refunded_wheels = 0
		for (var/obj/item/stack/material/steel/refund in W.loc) refunded += refund.amount
		for (var/obj/structure/vehicleparts/movement/refund in W.loc) refunded_wheels++
		car_check(refunded == 45 && refunded_wheels == 1 && !W.stock["steel"] && !W.stock["wheels"], "unload returns only paid inputs")
		for(var/obj/refund in W.loc)
			if(refund != W)
				qdel(refund)
				if(refund) del(refund)
		map.ordinal_age = 0
		car_check(!W.allowed(H), "primitive research denied")
		map.ordinal_age = 8
		car_check(W.allowed(H), "modern baseline granted")
		car_fill(W,"ASNO Piccolino")
		var/obj/O = new(locate(13,13,1))
		car_check(!W.complete_assembly("ASNO Piccolino") && W.stock["steel"] == 40, "obstruction prevents payment")
		qdel(O)
		if (O) del(O)
		var/obj/structure/vehicleparts/axis/A = W.complete_assembly("ASNO Piccolino")
		car_check(A, "save fixture assembled")
		car_fill(W,"ASNO Piccolino")
		W.busy = TRUE
		W.powerneeded = 20
		car_check(!("busy" in W.get_saved_vars()) && !("powerneeded" in W.get_saved_vars()), "runtime fields excluded")
		qdel(H)
		if (H) del(H)
		car_check(map_storage.Save_World(), "temporary world export")
		map_storage.ClearMap()
		car_check(map_storage.Load_World(), "temporary world import")
		W = locate(/obj/structure/car_workshop) in locate(12,12,1)
		car_check(W && W.stock["steel"] == 40 && W.stock["wheels"] == 4 && !W.busy && W.powerneeded == 0, "stock restored and work reset")
		A = locate(/obj/structure/vehicleparts/axis/car/piccolino) in world
		car_check(A && A.engine && A.wheel && A.wheels.len == 4 && A.components.len == 9, "constructed graph restored")
		car_check_vehicle(A,3)
		car_check(!car_probe_error, "no runtime errors")
		text2file("PASS: [car_probe_checks] construction, cancellation, footprint, power, vehicle, sprite and save assertions", "car-result.txt")
	catch(var/exception/E)
		text2file("FAIL: [E] at [E.file]:[E.line]", "car-result.txt")
	del(world)
