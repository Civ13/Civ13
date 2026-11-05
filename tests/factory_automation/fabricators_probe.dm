// Factory automation phase 3: fabricators and the curated factory recipe list.
// Runs the production sources through the shared resource-extraction fixture
// with ordinary game startup disabled; fabricator steps are called directly.
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
/obj/map_metadata/fabricator_probe/New()
	return
/mob/living/human/fabricator_probe/New()
	return
/mob/living/human/fabricator_probe/update_icons()
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
		map = new /obj/map_metadata/fabricator_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				belt_floor(x, y)
		machine_check(!world.port, "fixture has no listening port")
		machine_recipe_checks()
		machine_fabricator_checks()
		machine_fabricator_lifecycle_checks()
		machine_stack_arm_checks()
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


/proc/machine_recipe_checks()
	var/list/recipes = factory_load_recipes()
	machine_check(recipes.len == 30 && !factory_recipe_errors.len, "the curated factory recipe list loads thirty recipes without errors ([english_list(factory_recipe_errors)])")
	var/datum/factory_recipe/R = recipes["electronic circuits"]
	machine_check(R && R.output_type == /obj/item/stack/material/electronics && R.output_amount == 3 && R.inputs[/obj/item/stack/material/copper] == 2 && R.inputs[/obj/item/stack/material/plastic] == 1 && R.tier == 2 && R.node == "automation", "recipe rows parse output, inputs, tier and node")
	for (var/name in recipes)
		var/datum/factory_recipe/F = recipes[name]
		machine_check(get_research_node(F.node), "recipe [name] names a real research node")
	text2file("FACTORY: ok|/obj/item/stack/material/steel|1|/obj/item/stack/material/iron=1|10|1|automation\nFACTORY: bad output|/obj/nothing|1|/obj/item/stack/material/iron=1|10|1|automation\nFACTORY: bad input|/obj/item/stack/material/steel|1|/obj/item/stack/material/iron=0|10|1|automation\nFACTORY: short|/obj/item/stack/material/steel|1\nFACTORY: ok|/obj/item/stack/material/steel|1|/obj/item/stack/material/iron=1|10|1|automation\n", "bad_recipes.txt")
	var/list/bad = factory_load_recipes("bad_recipes.txt")
	machine_check(bad.len == 1 && factory_recipe_errors.len == 4, "invalid and duplicate rows are reported and skipped")
	factory_load_recipes()
	machine_check(factory_get_recipes().len == 30, "the real list reloads")
	var/list/node_map = recipe_node_requirements
	var/list/tiers = list("/obj/structure/factory_arm/stack" = "digital_computing", "/obj/structure/factory_fabricator" = "assembly_line", "/obj/structure/factory_fabricator/automated" = "automation", "/obj/structure/factory_fabricator/computerized" = "digital_computing", "/obj/structure/factory_fabricator/printer" = "additive_manufacturing")
	var/node_ok = TRUE
	for (var/path in tiers)
		if (node_map[path] != tiers[path])
			node_ok = FALSE
	machine_check(node_ok, "each fabricator tier is gated behind its research node")

/proc/machine_done(faction, node)
	var/list/entry = map.ensure_node_entry(faction, node)
	entry[RNODE_ENTRY_STATUS] = RNODE_DONE

/proc/machine_fabricator_checks()
	var/obj/structure/factory_fabricator/F = new(locate(2, 2, 1))
	var/obj/structure/factory_fabricator/computerized/C = new(locate(8, 2, 1))
	map.faction_baseline_era["probe_civ"] = 1 // founded before industry, so research is earned
	machine_check(!F.available_recipes("probe_civ").len, "a faction without the research gets no recipes")
	machine_done("probe_civ", "assembly_line")
	machine_done("probe_civ", "automation")
	machine_done("probe_civ", "digital_computing")
	var/list/basic = F.available_recipes("probe_civ")
	machine_check(basic.len == 15 && ("barbwire" in basic) && ("bronze" in basic) && ("wrench" in basic) && !("ammo belt" in basic) && !("electronic circuits" in basic), "a tier 1 fabricator lists only tier 1 recipes")
	machine_check(C.available_recipes("probe_civ").len == 18, "a tier 3 fabricator lists every researched non-printing recipe")
	machine_printer_checks()
	machine_check(!F.set_recipe("no such recipe") && !F.recipe_name, "unknown recipes are refused")
	var/obj/item/stack/material/iron/iron = new(locate(1, 2, 1), 10, FALSE)
	machine_check(!F.factory_accepts(iron), "a fabricator without a recipe takes nothing")
	machine_check(F.set_recipe("barbwire") && F.fab_active, "setting a recipe wakes the fabricator")
	var/obj/item/stack/material/copper/copper = new(locate(1, 3, 1), 5, FALSE)
	machine_check(!F.factory_accepts(copper), "a fabricator refuses what its recipe does not use")
	machine_check(F.factory_accepts(iron) == 4, "a fabricator buffers two cycles of each input")
	machine_check(F.factory_insert(iron) == 4 && F.buffered(/obj/item/stack/material/iron) == 4 && iron.amount == 6, "inserted inputs fill the buffer and the rest stays behind")
	machine_check(!F.factory_accepts(iron), "a full buffer refuses more")
	F.fab_step()
	machine_check(F.progress == 0 && !F.powered && F.fab_active, "no progress without power")
	var/list/power = machine_power(F, 2, 3)
	for (var/i in 1 to 3)
		F.fab_step()
	machine_check(F.progress == 30 && F.powered && F.buffered(/obj/item/stack/material/iron) == 4, "powered steps add progress without spending inputs early")
	F.fab_step()
	var/obj/item/stack/material/barbwire/wire = locate() in F.loc
	machine_check(F.progress == 0 && wire && wire.amount == 3 && F.buffered(/obj/item/stack/material/iron) == 2, "a finished cycle spends one cycle of inputs and leaves output on the tile")
	machine_check(F.factory_offer() == wire && !F.factory_offer(0, /obj/item/stack/material/steel), "the fabricator offers its output and honours arm filters")
	var/obj/structure/closet/crate/crate = belt_closed_crate(locate(3, 2, 1))
	machine_check(F.factory_take(wire, crate) && wire.loc == crate, "an arm can take the output away")
	F.fab_step()
	F.fab_step()
	var/obj/structure/engine/E = power[2]
	E.on = FALSE
	F.fab_step()
	machine_check(!F.powered && F.progress == 20 && F.buffered(/obj/item/stack/material/iron) == 2, "a power cut pauses the cycle without losing progress or inputs")
	E.on = TRUE
	F.fab_step()
	F.fab_step()
	var/obj/item/stack/material/barbwire/second = locate() in F.loc
	machine_check(second && second.amount == 3 && !F.buffered(/obj/item/stack/material/iron), "restored power finishes the paused cycle")
	F.fab_step()
	machine_check(!F.fab_active && !(F in factory_active_fabricators), "a fabricator without inputs sleeps")
	machine_check(F.factory_insert(iron) == 4 && F.fab_active, "new inputs wake it")
	for (var/i in 1 to 12)
		new /obj/item/stack/material/stone(F.loc, 1, FALSE)
	F.fab_step()
	machine_check(F.progress == 0, "a crowded output tile makes the fabricator wait")
	for (var/obj/item/stack/material/stone/S in F.loc)
		qdel(S)
	machine_item_output_checks()
	machine_check(C.cycle_time(factory_get_recipes()["electronic components"]) == 75, "a computerized fabricator runs at half the tier 1 time")
	for (var/obj/O in power + list(iron, copper, crate, second, C))
		qdel(O)
	qdel(F)

/proc/machine_fabricator_lifecycle_checks()
	var/obj/structure/factory_fabricator/automated/F = new(locate(2, 8, 1))
	F.set_recipe("electronic circuits")
	var/obj/item/stack/material/copper/copper = new(locate(1, 8, 1), 3, FALSE)
	var/obj/item/stack/material/plastic/plastic = new(locate(1, 9, 1), 3, FALSE)
	F.factory_insert(copper)
	F.factory_insert(plastic)
	machine_check(F.buffered(/obj/item/stack/material/copper) == 3 && F.buffered(/obj/item/stack/material/plastic) == 2, "every input of a recipe buffers on its own")
	F.progress = 999
	F.fab_active = FALSE
	F.after_load()
	machine_check(F.progress == 45 && F.fab_active && !F.powered, "load clamps progress to the cycle and resumes the fabricator unpowered")
	machine_check(!F.persistence_runtime_var("recipe_name") && !F.persistence_runtime_var("progress") && F.persistence_runtime_var("fab_active"), "the recipe and progress are saved; the active flag is not")
	F.recipe_name = "removed recipe"
	F.after_load()
	machine_check(!F.recipe_name && !F.progress, "load clears a recipe the list no longer has")
	F.recipe_name = "electronic circuits"
	var/turf/T = F.loc
	F.set_recipe("cable coil")
	var/ejected = 0
	for (var/obj/item/stack/material/copper/S in T)
		ejected += S.amount
	machine_check(!F.contents.len && ejected == 3, "changing the recipe returns the old buffer to the floor")
	F.factory_insert(locate(/obj/item/stack/material/copper) in T)
	qdel(F)
	var/left = 0
	for (var/obj/item/stack/material/copper/S in T)
		left += S.amount
	machine_check(left == 3 && !(F in factory_active_fabricators), "removing a fabricator drops its buffer")

/proc/machine_arm_swing(obj/structure/factory_arm/A)
	A.next_swing = 0
	A.arm_step()

/proc/machine_stack_arm_checks()
	var/obj/structure/closet/crate/source = belt_closed_crate(locate(1, 13, 1), 40)
	var/obj/structure/closet/crate/dest = belt_closed_crate(locate(3, 13, 1), 40)
	for (var/i in 1 to 12)
		new /obj/item/stack/material/steel(source, 1, FALSE)
	for (var/i in 1 to 2)
		new /obj/item/stack/material/copper(source, 1, FALSE)
	var/obj/structure/factory_arm/stack/A = new(locate(2, 13, 1))
	A.set_dir(EAST)
	var/list/power = machine_power(A, 2, 14)
	A.on = TRUE
	machine_check(A.powerneeded == 5 && A.batch == 10, "a stack arm draws five power units and lifts ten items")
	machine_arm_swing(A)
	machine_check(belt_count(dest, /obj/item/stack/material/steel) == 10 && belt_count(source, /obj/item/stack/material/steel) == 2 && belt_count(source, /obj/item/stack/material/copper) == 2 && !A.contents.len, "with no filter a stack arm moves ten items of the first kind in one swing")
	machine_arm_swing(A)
	machine_check(belt_count(dest, /obj/item/stack/material/steel) == 12 && belt_count(dest, /obj/item/stack/material/copper) == 0, "a batch never mixes kinds")
	for (var/i in 1 to 3)
		new /obj/item/stack/material/steel(source, 1, FALSE)
	A.filter_type = /obj/item/stack/material/copper
	machine_arm_swing(A)
	machine_check(belt_count(dest, /obj/item/stack/material/copper) == 2 && belt_count(source, /obj/item/stack/material/steel) == 3, "a filter limits a stack arm to one kind")
	var/obj/structure/factory_arm/sorting/S = new(locate(2, 15, 1))
	machine_check(!S.wanted(new /obj/item/stack/material/steel(locate(5, 15, 1), 1, FALSE)), "a sorting arm with no filter still moves nothing")
	var/obj/structure/factory_arm/F = new(locate(5, 13, 1))
	F.set_dir(EAST)
	var/obj/structure/closet/crate/fsource = belt_closed_crate(locate(4, 13, 1), 40)
	var/obj/structure/closet/crate/fdest = belt_closed_crate(locate(6, 13, 1), 40)
	for (var/i in 1 to 3)
		new /obj/item/stack/material/steel(fsource, 1, FALSE)
	var/list/fpower = machine_power(F, 5, 14)
	F.on = TRUE
	machine_arm_swing(F)
	machine_check(belt_count(fdest, /obj/item/stack/material/steel) == 1, "a feeder arm still moves one item a swing")
	for (var/obj/O in power + fpower + list(A, F, S, source, dest, fsource, fdest))
		qdel(O)

// Recipes whose output is a plain item make one item per unit of output.
/proc/machine_item_output_checks()
	var/obj/structure/factory_fabricator/T = new(locate(10, 2, 1))
	var/list/power = machine_power(T, 10, 3)
	T.set_recipe("screwdriver")
	var/obj/item/stack/material/iron/iron = new(locate(11, 2, 1), 4, FALSE)
	machine_check(T.factory_insert(iron) == 4, "a tool recipe buffers its iron")
	for (var/i in 1 to 4)
		T.fab_step()
	var/obj/item/weapon/screwdriver/S = locate() in T.loc
	machine_check(S && T.buffered(/obj/item/stack/material/iron) == 2 && T.factory_offer() == S, "a fabricator makes a screwdriver from two iron and offers it")
	T.set_recipe("rifle casings")
	var/obj/item/stack/material/copper/copper = new(locate(11, 2, 1), 2, FALSE)
	T.factory_insert(copper)
	T.fab_step()
	T.fab_step()
	var/obj/item/stack/ammopart/casing/rifle/casings = locate() in T.loc
	machine_check(casings && casings.amount == 3, "a fabricator makes three rifle casings from one copper")
	for (var/obj/O in power + list(T, S, casings))
		qdel(O)

// Digital Age 3D printer: prints only the tier 4 rows, from plastic.
/proc/machine_printer_checks()
	var/obj/structure/factory_fabricator/printer/P = new(locate(12, 5, 1))
	machine_check(!P.available_recipes("probe_civ").len, "a 3D printer lists nothing before 3D Printing is researched")
	machine_done("probe_civ", "additive_manufacturing")
	var/list/prints = P.available_recipes("probe_civ")
	var/only_prints = prints.len == 12
	for (var/name in prints)
		var/datum/factory_recipe/R = factory_recipes[name]
		if (R.tier != 4 || R.node != "additive_manufacturing")
			only_prints = FALSE
	machine_check(only_prints && !("barbwire" in prints), "a 3D printer lists only the twelve printing recipes")
	var/obj/structure/factory_fabricator/computerized/C = new(locate(14, 5, 1))
	machine_check(!("printed hardhat" in C.available_recipes("probe_civ")), "older fabricators cannot run printing recipes")
	machine_check(P.set_recipe("printed hardhat"), "a 3D printer takes a printing recipe")
	var/obj/item/stack/material/plastic/plastic = new(locate(13, 5, 1), 10, FALSE)
	machine_check(P.factory_insert(plastic) == 6 && plastic.amount == 4, "a 3D printer buffers two cycles of plastic")
	var/list/power = machine_power(P, 12, 6)
	for (var/i in 1 to 3)
		P.fab_step()
	var/obj/item/clothing/head/helmet/modern/hardhat/H = locate() in P.loc
	machine_check(H && P.buffered(/obj/item/stack/material/plastic) == 3 && P.icon_state == "autoclaveb", "a powered 3D printer prints a hardhat from three plastic in three seconds")
	for (var/obj/O in power + list(P, C, plastic, H))
		qdel(O)
