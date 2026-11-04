// Factory automation phase 4a: fast belts and train wagon / cart ports. Runs
// the production sources through the shared resource-extraction fixture with
// ordinary game startup disabled; belt and arm steps are called directly.
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
/obj/map_metadata/logistics_probe/New()
	return
/mob/living/human/logistics_probe/New()
	return
/mob/living/human/logistics_probe/update_icons()
	return
var/machine_failures = 0
var/machine_runtime_error = FALSE
/proc/machine_check(condition, label)
	if (!condition)
		machine_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	machine_runtime_error = TRUE
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
		map = new /obj/map_metadata/logistics_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				belt_floor(x, y)
		machine_check(!world.port, "fixture has no listening port")
		machine_drive()
		machine_fast_belt_checks()
		machine_wagon_checks()
	catch(var/exception/e)
		machine_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = machine_failures, "runtime_error" = machine_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/machine_power(obj/O, x, y)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = 50
	E.connections = list(C)
	C.connections = list(O, E)
	O.powersource = C
	return list(C, E)



/proc/machine_drive()
	var/obj/structure/factory_drive/D = new(locate(16, 16, 1))
	D.drive_range = 30
	var/obj/structure/cable/C = new(locate(16, 16, 1))
	var/obj/structure/engine/E = new(locate(16, 16, 1))
	E.on = TRUE
	E.maxpower = 100
	E.connections = list(C)
	C.connections = list(D, E)
	D.powersource = C
	D.on = TRUE
	D.drive_wake()
	factory_drives_step()
	machine_check(D.powered, "a cabled drive powers the fixture's belts")

/proc/machine_line(y, list/types, obj/structure/closet/crate/end)
	var/x = 2
	for (var/type in types)
		var/obj/structure/factory_belt/B = new type(locate(x, y, 1))
		B.set_dir(EAST)
		x++

/proc/machine_fast_belt_checks()
	var/obj/structure/closet/crate/plain_end = belt_closed_crate(locate(8, 2, 1))
	var/obj/structure/closet/crate/fast_end = belt_closed_crate(locate(8, 4, 1))
	var/obj/structure/closet/crate/mixed_end = belt_closed_crate(locate(8, 6, 1))
	var/plain = /obj/structure/factory_belt
	var/fast = /obj/structure/factory_belt/fast
	machine_line(2, list(plain, plain, plain, plain, plain, plain))
	machine_line(4, list(fast, fast, fast, fast, fast, fast))
	machine_line(6, list(fast, fast, fast, plain, plain, plain))
	new /obj/item/stack/material/steel(locate(2, 2, 1), 1, FALSE)
	new /obj/item/stack/material/steel(locate(2, 4, 1), 1, FALSE)
	new /obj/item/stack/material/steel(locate(2, 6, 1), 1, FALSE)
	var/obj/structure/factory_belt/first_fast = locate() in locate(2, 4, 1)
	machine_check(first_fast.belt_passes == 2 && (first_fast in factory_active_fast_belts), "a fast belt takes two steps a tick and joins the fast list")
	var/plain_steps = 0
	var/fast_steps = 0
	var/mixed_steps = 0
	for (var/i in 1 to 12)
		belt_run(1)
		if (!fast_steps && belt_count(fast_end, /obj/item/stack/material/steel))
			fast_steps = i
		if (!plain_steps && belt_count(plain_end, /obj/item/stack/material/steel))
			plain_steps = i
		if (!mixed_steps && belt_count(mixed_end, /obj/item/stack/material/steel))
			mixed_steps = i
	world.log << "steps to the crate: plain [plain_steps], fast [fast_steps], mixed [mixed_steps]"
	machine_check(plain_steps && fast_steps && fast_steps * 2 <= plain_steps + 1, "cargo on fast belts reaches the crate in about half the steps")
	machine_check(mixed_steps && mixed_steps > fast_steps && mixed_steps < plain_steps, "fast belts hand cargo on to plain belts")
	belt_run(2)
	machine_check(!(first_fast in factory_active_fast_belts) && !first_fast.belt_active, "an empty fast belt sleeps and leaves the fast list")
	var/obj/item/factory_belt_assembly/fast/A = new(locate(10, 2, 1))
	machine_check(A.belt_type == fast && first_fast.assembly_type == /obj/item/factory_belt_assembly/fast, "the fast belt assembly lays and returns a fast belt")
	machine_check(recipe_node_requirements["/obj/item/factory_belt_assembly/fast"] == "automation", "fast belts are gated behind Automation")
	qdel(A)

/proc/machine_arm(x, y)
	var/obj/structure/factory_arm/A = new(locate(x, y, 1))
	A.set_dir(EAST)
	A.on = TRUE
	machine_power(A, x, y + 1)
	return A

/proc/machine_swing(obj/structure/factory_arm/A)
	A.next_swing = 0
	A.arm_step()

/proc/machine_wagon_checks()
	var/obj/structure/closet/crate/source = belt_closed_crate(locate(1, 10, 1), 40)
	for (var/i in 1 to 10)
		new /obj/item/stack/material/steel(source, 1, FALSE)
	var/obj/structure/trains/storage/closed/W = new(locate(3, 10, 1))
	var/obj/structure/closet/crate/dest = belt_closed_crate(locate(5, 10, 1), 40)
	var/obj/structure/factory_arm/load = machine_arm(2, 10)
	var/obj/structure/factory_arm/unload = machine_arm(4, 10)
	unload.on = FALSE
	machine_swing(load)
	machine_check(belt_count(W.storage, /obj/item/stack/material/steel) == 1, "an arm loads a train wagon")
	for (var/i in 1 to 9)
		machine_swing(load)
	machine_check(W.storage.contents.len == W.max_storage && belt_count(source, /obj/item/stack/material/steel) == 2, "a wagon takes only what fits, as by hand")
	var/obj/item/stack/material/steel/extra = locate() in source
	machine_check(!W.factory_accepts(extra), "a full wagon refuses more")
	unload.on = TRUE
	machine_swing(unload)
	machine_check(belt_count(dest, /obj/item/stack/material/steel) == 1 && W.storage.contents.len == W.max_storage - 1, "an arm unloads a train wagon")
	unload.filter_type = /obj/item/stack/material/copper
	machine_check(!W.factory_offer(0, /obj/item/stack/material/copper), "a wagon offers only what a filter asks for")
	var/obj/structure/trains/storage/tender/T = new(locate(3, 12, 1))
	var/obj/item/stack/ore/coal/coal = new(locate(4, 12, 1), 5)
	machine_check(!T.factory_accepts(extra) && T.factory_accepts(coal) == 5, "a tender takes only fuel")
	machine_check(T.factory_insert(coal) == 5 && coal.loc == T.storage, "a tender loads coal from automation")
	var/obj/structure/shopping_cart/cart = new(locate(6, 12, 1))
	var/obj/item/stack/material/steel/loose = new(locate(7, 12, 1), 3, FALSE)
	machine_check(cart.factory_insert(loose) == 3 && loose.loc == cart.storage, "a shopping cart loads from automation")
	var/obj/structure/closet/crate/out = belt_closed_crate(locate(8, 13, 1))
	machine_check(cart.factory_offer() == loose && cart.factory_take(loose, out) && loose.loc == out, "a shopping cart unloads to automation")
