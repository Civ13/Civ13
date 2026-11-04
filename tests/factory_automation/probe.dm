// Factory automation phase 0: saved belt state, mob-free factory ports and
// the cable reservation fast path. Runs the production sources through the
// shared resource-extraction fixture with ordinary game startup disabled.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/factory_probe/New()
	return
/mob/living/human/factory_probe/New()
	return
/mob/living/human/factory_probe/update_icons()
	return
var/factory_failures = 0
var/factory_runtime_error = FALSE
/proc/factory_check(condition, label)
	if (!condition)
		factory_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	factory_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/factory_count(atom/A, type)
	var/total = 0
	for (var/obj/item/stack/S in A)
		if (S.type == type)
			total += S.amount
	return total
/proc/factory_floor(x, y)
	var/turf/T = locate(x, y, 1)
	return T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		populate_material_list()
		map = new /obj/map_metadata/factory_probe
		map.ordinal_age = 8
		factory_check(!world.port, "fixture has no listening port")
		factory_belt_checks()
		factory_switch_checks()
		factory_crate_checks()
		factory_stamp_mill_checks()
		factory_power_checks()
	catch(var/exception/e)
		factory_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = factory_failures, "runtime_error" = factory_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Load builds a belt with new type(loc) and applies the saved dir afterwards.
/proc/factory_belt_checks()
	var/turf/T = factory_floor(2, 2)
	var/obj/machinery/conveyor/C = new(T)
	C.dir = EAST
	C.operating = 1
	factory_check(C.forwards == SOUTH, "constructor without a dir derives the default facing")
	C.after_load()
	factory_check(C.forwards == EAST && C.backwards == WEST, "load hook rederives directions from the saved dir")
	factory_check(C.movedir == EAST && C.icon_state == "conveyor1", "saved running belt resumes forward")
	C.dir = NORTHEAST
	C.operating = -1
	C.after_load()
	factory_check(C.forwards == turn(NORTHEAST, 135) && C.backwards == turn(NORTHEAST, 45) && C.movedir == C.backwards, "saved corner belt resumes in reverse along its curve")
	C.operating = 7
	C.after_load()
	factory_check(C.operating == 0 && !C.movedir, "invalid saved run state loads stopped")
	var/list/saved = C.get_saved_vars()
	factory_check(("operating" in saved) && ("dir" in saved) && ("id" in saved), "belt saves its run state, facing and switch id")
	var/obj/machinery/conveyor/fresh = new(factory_floor(3, 2), WEST, 1)
	factory_check(fresh.forwards == WEST && fresh.movedir == WEST, "constructed belts keep their placement direction")
	qdel(fresh)
	qdel(C)

/proc/factory_switch_checks()
	var/obj/machinery/conveyor/A = new(factory_floor(2, 4), EAST)
	var/obj/machinery/conveyor/B = new(factory_floor(3, 4), EAST)
	A.id = "probe-line"
	B.id = "probe-line"
	var/obj/machinery/conveyor_switch/S = new(factory_floor(2, 5), "probe-line")
	var/list/saved = S.get_saved_vars()
	factory_check(("position" in saved) && ("last_pos" in saved) && !("conveyors" in saved), "switch saves its position, not its belt list")
	S.position = 1
	S.operated = 0
	S.after_load()
	factory_check(S.icon_state == "switch-fwd" && S.operated, "reloaded switch shows and queues its saved position")
	S.process()
	factory_check(A.operating == 1 && B.operating == 1 && A.movedir == EAST, "reloaded switch restarts its belts")
	S.position = 3
	S.after_load()
	S.process()
	factory_check(S.position == 0 && S.icon_state == "switch-off" && A.operating == 0 && B.operating == 0, "invalid saved switch position stops its belts")
	qdel(S)
	qdel(A)
	qdel(B)

/proc/factory_crate_checks()
	var/turf/T = factory_floor(6, 2)
	var/obj/structure/closet/crate/C = new(T)
	C.opened = FALSE
	C.storage_capacity = 4
	for (var/obj/item/I in C)
		qdel(I)
	var/obj/item/stack/material/stone/S = new(T, 30, FALSE)
	factory_check(C.factory_accepts(S) == 30, "closed crate accepts a whole stack that fits")
	factory_check(C.factory_insert(S) == 30 && S.loc == C, "inserted stack moves into the crate")
	var/obj/item/stack/material/stone/more = new(T, 10, FALSE)
	factory_check(C.factory_insert(more) == 10 && QDELETED(more) && factory_count(C, /obj/item/stack/material/stone) == 40, "matching stack merges into the stored stack")
	var/stones = 0
	for (var/obj/item/stack/material/stone/stored in C)
		stones++
	factory_check(stones == 1, "merged stone uses one stack")
	var/obj/item/stack/material/wood/W = new(T, 5, FALSE)
	C.factory_insert(W)
	var/obj/item/stack/material/iron/iron = new(T, 5, FALSE)
	var/used = C.factory_used_capacity()
	var/fits = C.storage_capacity - used >= ceil(iron.w_class / 2)
	factory_check(fits ? C.factory_accepts(iron) == 5 : C.factory_accepts(iron) == 0, "capacity decides whether a new stack fits")
	factory_check(C.factory_offer(0, /obj/item/stack/material/wood) == W, "filtered offer returns the matching item")
	factory_check(C.factory_offer(0, /obj/item/stack/ore/coal) == null, "filtered offer ignores other items")
	factory_check(C.factory_take(W, T) && W.loc == T, "taken item leaves the crate")
	var/mob/living/human/factory_probe/H = new(factory_floor(6, 3))
	var/obj/item/stack/material/stone/held = new(H, 5, FALSE)
	factory_check(!C.factory_accepts(held) && !C.factory_insert(held) && held.loc == H, "ports never take items held by a person")
	C.opened = TRUE
	factory_check(!C.factory_accepts(iron) && !C.factory_offer(), "open crate has no port")
	qdel(held)
	qdel(H)
	qdel(iron)
	qdel(W)
	qdel(C)

/proc/factory_stamp_mill_checks()
	var/turf/T = factory_floor(9, 2)
	var/obj/structure/drill/stamp_mill/M = new(T)
	M.anchored = TRUE
	var/obj/item/stack/material/stone/S = new(factory_floor(9, 3), 50, FALSE)
	var/obj/item/stack/material/stone/S2 = new(S.loc, 20, FALSE)
	factory_check(M.factory_accepts(S) == 50 && M.factory_insert(S) == 50 && QDELETED(S), "mill hopper takes a stack from automation")
	factory_check(M.loaded_stone_amount() == 50 && !M.factory_accepts(S2) && !M.factory_insert(S2) && S2.amount == 20, "full hopper refuses more stone")
	var/obj/item/stack/material/stone/hopper = M.loaded_stone()
	hopper.amount = 45
	factory_check(M.factory_insert(S2) == 5 && S2.amount == 15 && M.loaded_stone_amount() == 50, "partial insert splits the stack")
	var/obj/item/stack/material/sandstone/sand = new(S2.loc, 5, FALSE)
	hopper.amount = 10
	factory_check(!M.factory_accepts(sand) && !M.factory_insert(sand) && sand.amount == 5, "mill refuses other materials")
	factory_check(!M.factory_offer(), "mill offers no output yet")
	qdel(sand)
	qdel(S2)
	qdel(M)

/proc/factory_power_checks()
	var/obj/structure/cable/C = new(locate(2, 9, 1))
	var/obj/structure/engine/E = new(locate(3, 9, 1))
	E.on = TRUE
	E.maxpower = 100
	E.connections = list(C)
	var/obj/consumer = new /obj(locate(2, 9, 1))
	consumer.powerneeded = 40
	consumer.powersource = C
	C.connections = list(E, consumer)
	factory_check(consumer.draw_cable_power() && C.currentflow == 40 && C.rebuild_time == world.time, "first draw reserves through a traversal")
	var/walked = C.rebuild_time
	sleep(3)
	factory_check(consumer.draw_cable_power() && C.rebuild_time == walked && C.currentflow == 40, "repeated draw under a second later reuses the reservation")
	sleep(10)
	factory_check(consumer.draw_cable_power() && C.rebuild_time == world.time, "a reservation older than a second takes a fresh traversal")
	E.maxpower = 30
	C.rebuild_supply()
	factory_check(C.currentflow > C.powerflow, "a source traversal publishes the overload")
	factory_check(!consumer.draw_cable_power() && C.currentflow == 0, "an overloaded grid refuses and releases the reservation")
	E.maxpower = 100
	C.rebuild_supply()
	factory_check(consumer.draw_cable_power() && C.currentflow == 40, "restored capacity admits the load again")
	E.on = FALSE
	factory_check(!consumer.draw_cable_power() && C.currentflow == 0, "an engine switched off without notifying the grid refuses the load at once")
	E.on = TRUE
	factory_check(consumer.draw_cable_power() && C.currentflow == 40, "the restarted engine admits the load again")
	E.on = FALSE
	C.rebuild_supply()
	factory_check(!consumer.draw_cable_power() && C.currentflow == 0, "a stopped source refuses the load at once")
	factory_check(C.persistence_runtime_var("rebuild_time") && C.persistence_runtime_var("rebuild_engines"), "traversal time and engines are runtime-only")
	E.on = TRUE
	consumer.powersource = null
	C.connections -= consumer
	qdel(consumer)
	qdel(E)
	qdel(C)
