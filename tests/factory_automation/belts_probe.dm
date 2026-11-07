#define FACTORY_BLOCKED_TEST_STEPS 20
// Factory automation phase 1: belts, transfer arms and parts bins. Runs the
// production sources through the shared resource-extraction fixture with
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
/obj/map_metadata/belt_probe/New()
	return
/mob/living/human/belt_probe/New()
	return
/mob/living/human/belt_probe/update_icons()
	return
var/belt_failures = 0
var/belt_runtime_error = FALSE
/proc/belt_check(condition, label)
	if (!condition)
		belt_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	belt_runtime_error = TRUE
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
		map = new /obj/map_metadata/belt_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				belt_floor(x, y)
		belt_check(!world.port, "fixture has no listening port")
		// Phase 2 belts need a powered drive; one drive covers the whole fixture.
		belt_drive(16, 16, 30)
		belt_line_checks()
		belt_corner_checks()
		belt_capacity_checks()
		belt_load_checks()
		belt_arm_checks()
		belt_wrench_checks()
		belt_catalog_checks()
	catch(var/exception/e)
		belt_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = belt_failures, "runtime_error" = belt_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/belt_make(x, y, d)
	var/obj/structure/factory_belt/B = new(locate(x, y, 1))
	B.set_dir(d)
	return B

/proc/belt_line_checks()
	var/obj/structure/factory_belt/A = belt_make(2, 2, EAST)
	var/obj/structure/factory_belt/B = belt_make(3, 2, EAST)
	var/obj/structure/factory_belt/C = belt_make(4, 2, EAST)
	var/obj/structure/closet/crate/crate = belt_closed_crate(locate(5, 2, 1))
	belt_run(2)
	belt_check(!(A in factory_active_belts) && !(B in factory_active_belts), "empty belts leave the process")
	var/obj/item/stack/material/stone/S = new(locate(1, 2, 1), 20, FALSE)
	S.forceMove(A.loc)
	belt_check(A in factory_active_belts, "an item dropped on a belt wakes it")
	belt_run(1)
	belt_check(S.loc == B.loc && B.cargo[1] == S && S.pixel_x == -12 && S.pixel_y == 0, "cargo advances up to four slots a step and crosses to the next belt as a floor item")
	belt_run(4)
	belt_check(S.loc == crate && belt_count(crate, /obj/item/stack/material/stone) == 20, "the last belt hands cargo to the crate in front")
	belt_check(!S.pixel_x && !S.pixel_y, "stored cargo loses its belt offset")
	belt_run(2)
	belt_check(!(A in factory_active_belts) && !(B in factory_active_belts) && !(C in factory_active_belts), "belts sleep once empty")
	// Picking cargo up removes it from the belt.
	var/obj/item/stack/material/wood/W = new(A.loc, 5, FALSE)
	A.belt_wake()
	belt_run(1)
	var/mob/living/human/belt_probe/H = new(locate(2, 3, 1))
	W.forceMove(H)
	A.belt_scan()
	belt_check(!(W in A.cargo), "cargo picked up by a person leaves the belt")
	qdel(W)
	qdel(H)
	// A reverse-facing belt is never fed.
	var/obj/structure/factory_belt/R = belt_make(6, 4, WEST)
	var/obj/structure/factory_belt/F = belt_make(5, 4, EAST)
	var/obj/item/stack/material/stone/stuck = new(F.loc, 1, FALSE)
	F.belt_wake()
	belt_run(3)
	belt_check(stuck.loc == F.loc && F.cargo[4] == stuck && F.next_poll > factory_belt_tick, "a belt facing back blocks the exit and the belt polls slowly")
	for (var/obj/O in list(A, B, C, crate, R, F, stuck))
		qdel(O)

/proc/belt_corner_checks()
	var/obj/structure/factory_belt/A = belt_make(2, 6, EAST)
	var/obj/structure/factory_belt/up = belt_make(3, 6, NORTH)
	var/obj/structure/factory_belt/side = belt_make(3, 5, NORTH)
	var/obj/item/stack/material/stone/S = new(A.loc, 1, FALSE)
	A.belt_wake()
	belt_run(1)
	belt_check(S.loc == up.loc && up.cargo[2] == S && S.pixel_y == -4 && S.pixel_x == 0, "cargo turns the corner and enters partway along from the side")
	var/obj/item/stack/material/stone/T = new(side.loc, 1, FALSE)
	side.belt_wake()
	belt_run(4)
	belt_check(T.loc != side.loc, "a belt feeding from behind continues the same line")
	for (var/obj/O in list(A, up, side, S, T))
		qdel(O)

/proc/belt_capacity_checks()
	var/obj/structure/factory_belt/A = belt_make(2, 9, EAST)
	var/list/items = list()
	for (var/i in 1 to 6)
		items += new /obj/item/stack/material/stone(A.loc, 1, FALSE)
	A.belt_wake()
	belt_run(1)
	var/carried = 0
	for (var/obj/item/I in A.cargo)
		carried++
	belt_check(carried == 4, "a belt tile carries at most four items")
	var/obj/structure/closet/crate/full = belt_closed_crate(locate(3, 9, 1), 1)
	new /obj/item/stack/material/wood(full, 1, FALSE)
	belt_run(3)
	belt_check(A.cargo[4] && A.next_poll > factory_belt_tick, "a full crate blocks the belt")
	full.storage_capacity = 20
	belt_run(FACTORY_BLOCKED_TEST_STEPS)
	var/stored = 0
	for (var/obj/item/stack/material/stone/S in full)
		stored += S.amount
	belt_check(stored == 6, "the blocked belt resumes once the crate has room")
	for (var/obj/O in items)
		qdel(O)
	qdel(full)
	qdel(A)


/proc/belt_load_checks()
	var/obj/structure/factory_belt/A = belt_make(2, 12, EAST)
	var/obj/item/stack/material/stone/S = new(A.loc, 1, FALSE)
	S.pixel_x = 12
	belt_check(A.persistence_runtime_var("cargo") && A.persistence_runtime_var("belt_active") && A.persistence_runtime_var("next_poll"), "belt runtime state is excluded from saves")
	A.cargo = null
	A.belt_active = FALSE
	factory_active_belts -= A
	A.after_load()
	A.belt_scan()
	belt_check((A in factory_active_belts) && A.cargo[4] == S, "a reloaded belt adopts saved cargo in its saved slot")
	qdel(S)
	qdel(A)

/proc/belt_power(obj/structure/factory_arm/arm, x, y, maxpower = 50)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = maxpower
	E.connections = list(C)
	C.connections = list(arm, E)
	arm.powersource = C
	return list(C, E)

/proc/belt_drive(x, y, range)
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
	belt_check(D.powered && (D in factory_powered_drives), "a cabled drive powers the fixture's belts")
	return D

/proc/belt_swing(obj/structure/factory_arm/arm)
	arm.next_swing = 0
	factory_arms_step()

/proc/belt_arm_checks()
	// Crate -> arm -> belt.
	var/obj/structure/closet/crate/crate = belt_closed_crate(locate(8, 2, 1))
	var/obj/item/stack/material/stone/S = new(crate, 10, FALSE)
	var/obj/structure/factory_arm/arm = new(locate(9, 2, 1))
	arm.set_dir(EAST)
	var/obj/structure/factory_belt/B = belt_make(10, 2, EAST)
	belt_swing(arm)
	belt_check(!(arm in factory_active_arms) && S.loc == crate, "an arm that is off does nothing")
	arm.on = TRUE
	arm.arm_wake()
	belt_swing(arm)
	belt_check(S.loc == crate && !arm.powered, "an arm without power does nothing")
	var/list/power = belt_power(arm, 9, 3)
	belt_swing(arm)
	belt_check(arm.powered && S.loc == B.loc && B.cargo[1] == S, "a powered arm moves a crate item onto the belt entry")
	var/obj/structure/cable/C = power[1]
	belt_check(C.currentflow == 2, "the arm reserves its cable demand")
	arm.on = FALSE
	belt_swing(arm)
	belt_check(!(arm in factory_active_arms) && C.currentflow == 0, "switching off releases demand")
	qdel(S)
	// Sorting arm: no filter moves nothing; a filter moves only matching items.
	var/obj/structure/closet/crate/mixed = belt_closed_crate(locate(8, 6, 1))
	var/obj/item/stack/material/wood/wood = new(mixed, 3, FALSE)
	var/obj/item/stack/material/stone/stone = new(mixed, 3, FALSE)
	var/obj/structure/factory_arm/sorting/sorter = new(locate(9, 6, 1))
	sorter.set_dir(EAST)
	var/obj/structure/closet/crate/factory_bin/bin = new(locate(10, 6, 1))
	bin.opened = FALSE
	for (var/obj/item/I in bin)
		qdel(I)
	belt_power(sorter, 9, 7)
	sorter.on = TRUE
	sorter.arm_wake()
	belt_swing(sorter)
	belt_check(wood.loc == mixed && stone.loc == mixed, "a sorting arm without a filter moves nothing")
	sorter.filter_type = /obj/item/stack/material/stone
	belt_swing(sorter)
	belt_check(stone.loc == bin && wood.loc == mixed, "a sorting arm moves only filtered items")
	sorter.filter_type = /obj/item/stack/material/wood
	belt_swing(sorter)
	belt_check(wood.loc == mixed && !sorter.held_item() && !bin.factory_accepts(wood), "an arm leaves items that a parts bin of another kind would refuse")
	sorter.on = FALSE
	belt_swing(sorter)
	// Drill output -> arm -> stamp mill hopper, with a partial insert.
	var/obj/structure/drill/drill = new(locate(12, 10, 1))
	new /obj/item/stack/material/stone(drill.loc, 30, FALSE)
	var/obj/structure/factory_arm/feeder = new(locate(13, 10, 1))
	feeder.set_dir(EAST)
	var/obj/structure/drill/stamp_mill/mill = new(locate(14, 10, 1))
	mill.anchored = TRUE
	new /obj/item/stack/material/stone(mill, 40, FALSE)
	belt_power(feeder, 13, 11)
	feeder.on = TRUE
	feeder.arm_wake()
	belt_swing(feeder)
	belt_check(mill.loaded_stone_amount() == 50 && feeder.held_item() && belt_count(feeder, /obj/item/stack/material/stone) == 20, "an arm carries drill output into the mill and holds what does not fit")
	var/obj/item/stack/material/stone/hopper = mill.loaded_stone()
	hopper.amount = 10
	belt_swing(feeder)
	belt_check(mill.loaded_stone_amount() == 30 && !feeder.held_item(), "the held remainder goes in once there is room")
	belt_check(feeder.persistence_runtime_var("next_swing") && ("on" in feeder.get_saved_vars()), "arm timing is runtime-only and its switch is saved")
	feeder.next_swing = world.time + 1000
	feeder.after_load()
	belt_check(!feeder.next_swing && (feeder in factory_active_arms), "a reloaded running arm resumes without stored time")
	feeder.on = FALSE
	belt_swing(feeder)
	// Floor output is capped.
	var/obj/structure/factory_arm/dropper = new(locate(5, 14, 1))
	dropper.set_dir(EAST)
	for (var/i in 1 to 13)
		new /obj/item/weapon/wrench(locate(4, 14, 1))
	belt_power(dropper, 5, 15)
	dropper.on = TRUE
	dropper.arm_wake()
	for (var/i in 1 to 14)
		belt_swing(dropper)
	var/piled = 0
	for (var/obj/item/I in locate(6, 14, 1))
		piled++
	belt_check(piled == 12, "an arm stops piling on a bare floor at twelve items")
	dropper.on = FALSE
	belt_swing(dropper)

// Factory parts are fastened and unfastened with a wrench like other machines;
// arms turn by verb, and an unfastened arm or drive does no work.
/proc/belt_wrench_checks()
	var/list/fixed = list()
	for (var/path in list(/obj/structure/factory_arm, /obj/structure/factory_arm/sorting, /obj/structure/factory_arm/stack, /obj/structure/factory_drive, /obj/structure/factory_fabricator, /obj/structure/factory_fabricator/automated, /obj/structure/factory_fabricator/computerized, /obj/structure/factory_fabricator/printer, /obj/structure/factory_monitor))
		var/obj/structure/S = path
		if (initial(S.not_movable))
			fixed += "[path]"
	belt_check(!fixed.len, "arms, drives, fabricators and the monitor can be unwrenched[fixed.len ? " (fixed: [english_list(fixed)])" : ""]")
	var/mob/living/human/belt_probe/H = new(locate(2, 15, 1))
	var/obj/structure/factory_arm/arm = new(locate(3, 15, 1))
	arm.set_dir(EAST)
	belt_check(arm.arm_turn(H, 90) && arm.dir == NORTH && arm.arm_turn(H, -90) && arm.dir == EAST, "an arm that is off turns both ways")
	arm.on = TRUE
	belt_check(!arm.arm_turn(H, 90) && arm.dir == EAST, "a running arm refuses to turn")
	var/obj/item/weapon/wrench/wrench = new(H.loc)
	arm.attackby(wrench, H)
	belt_check(arm.anchored && arm.dir == EAST, "a running arm refuses the wrench")
	arm.anchored = FALSE
	arm.arm_wake()
	arm.arm_step()
	belt_check(!(arm in factory_active_arms) && arm.arm_status == "off", "an unfastened arm stops")
	var/obj/structure/factory_drive/D = locate() in locate(16, 16, 1)
	var/obj/structure/factory_belt/B = belt_make(14, 15, EAST)
	belt_check(D && D.drive_covers(B), "a fastened drive covers a nearby belt")
	D.anchored = FALSE
	belt_check(!D.drive_covers(B), "an unfastened drive powers no belts")
	D.anchored = TRUE
	for (var/obj/O in list(arm, wrench, B, H))
		qdel(O)

/proc/belt_catalog_checks()
	belt_check(get_recipe_node_req("/obj/item/factory_belt_assembly") == "factories" && get_recipe_node_req("/obj/structure/closet/crate/factory_bin") == "factories", "belts and parts bins unlock with Factories")
	belt_check(get_recipe_node_req("/obj/structure/factory_arm") == "factories" && get_recipe_node_req("/obj/structure/factory_arm/sorting") == "automation", "the feeder arm unlocks with Factories and the sorting arm with Automation")
	var/datum/research_node/factories = research_nodes["factories"]
	belt_check(factories && factories.era_tier == 4 && ("steam_power" in factories.prereqs) && get_recipe_node_req("/obj/structure/engine/external/steam") == "steam_power" && get_recipe_node_req("/obj/item/stack/cable_coil/white") == "paved_infrastructure", "the steam-era floor can be powered: Factories follows Steam Power and plain cable comes earlier")
	var/steel_arm = FALSE
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1 && findtext(line, "/obj/structure/factory_arm,"))
			if (findtext(line, "/material/electronics/"))
				steel_arm = FALSE
				break
			if (findtext(line, "/material/steel/"))
				steel_arm = TRUE
	belt_check(steel_arm, "the feeder arm is built from steel, without electronics")
	belt_check("conveyor1" in icon_states('icons/obj/recycling.dmi'), "belt sprite state exists")
	var/list/states = icon_states('icons/obj/modern_structures.dmi')
	belt_check(("loader0" in states) && ("loader1" in states) && ("unloader0" in states) && ("unloader1" in states), "arm sprite states exist")
	belt_check("map_arrow" in icon_states('icons/minimap_effects.dmi'), "arm direction arrow exists")
	var/list/found = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		for (var/path in list("/obj/item/factory_belt_assembly", "/obj/structure/factory_arm,", "/obj/structure/factory_arm/sorting", "/obj/structure/closet/crate/factory_bin"))
			if (findtext(line, "RECIPE: ") == 1 && findtext(line, path))
				found |= path
	belt_check(found.len == 4, "all four parts have global recipes")
