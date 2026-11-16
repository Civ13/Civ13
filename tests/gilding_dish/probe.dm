// Gilding dish: a jar cell's stored energy gilds small metal items without a cable.
// Runs the production sources through the shared resource-extraction fixture
// with ordinary game startup disabled; the dish's process is called directly.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/gilding_probe/New()
	return
var/plate_failures = 0
var/plate_runtime_error = FALSE
/proc/plate_check(condition, label)
	if (!condition)
		plate_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	plate_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
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
		map = new /obj/map_metadata/gilding_probe
		map.ordinal_age = 1
		map.age = "3000 B.C."
		for (var/x in 1 to 20)
			for (var/y in 1 to 20)
				var/turf/T = locate(x, y, 1)
				T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		plate_check(!world.port, "fixture has no listening port")
		gilding_dish_checks()
		gilding_catalog_checks()
	catch(var/exception/e)
		plate_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = plate_failures, "runtime_error" = plate_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/gild_run(obj/structure/gilding_dish/D, steps)
	var/result = null
	for (var/i in 1 to steps)
		result = D.process()
		if (result == PROCESS_KILL)
			break
	return result

/proc/gilding_dish_checks()
	var/turf/T = locate(5, 5, 1)
	var/obj/structure/gilding_dish/D = new(T)
	var/obj/item/weapon/material/kitchen/utensil/spoon/S = new(T, "bronze")
	var/base_value = S.value
	var/base_name = S.name
	plate_check(D.icon_state == "dish", "a new dish shows the dry empty dish")
	plate_check(D.start_refusal(S) == "Hang a sheet of gold or silver in \the [D] first.", "a dish without a sheet refuses")
	var/obj/item/stack/material/copper/Cu = new(T)
	plate_check(!D.hang_anode(Cu) && !D.anode, "a copper sheet will not hang in the dish")
	var/obj/item/stack/material/silver/Ag = new(T)
	Ag.amount = 2
	plate_check(D.hang_anode(Ag) && D.anode == "silver" && Ag.amount == 1, "hanging a silver sheet uses one sheet")
	plate_check(D.icon_state == "dish_silver", "the hung silver sheet shows in the dry dish")
	plate_check(findtext(D.start_refusal(S), "grape juice"), "a dry dish refuses")
	D.reagents.add_reagent("grapejuice", 12)
	D.update_icon()
	plate_check(D.icon_state == "dish_juice_silver", "the filled dish shows the juice and the sheet")
	plate_check(D.start_refusal(S) == "\The [D] needs a charged cell beside it.", "a dish without a cell refuses")
	var/obj/structure/battery/B = new(locate(6, 5, 1))
	B.assembled = TRUE
	plate_check(D.start_refusal(S) == "\The [D] needs a charged cell beside it.", "an empty jar cell does not count")
	B.commissioned = TRUE
	B.stored_energy = B.energy_capacity
	var/obj/item/weapon/material/sword/Big = new(T, "steel")
	plate_check(D.start_refusal(Big) == "\The [Big] is too big for \the [D].", "a sword is too big for the dish")
	plate_check(!D.start_refusal(S) && D.power_cell() == B, "an uncabled charged jar cell beside the dish powers it")
	plate_check(!B.powersource, "the jar cell has no cable")
	D.start_coat(S)
	plate_check(S.loc == D && (D in processing_objects), "the item goes into the dish and the dish processes")
	plate_check(D.icon_state == "dish_silver_on", "the dish bubbles while the coat goes on")
	plate_check(gild_run(D, 9) != PROCESS_KILL && D.progress == 9 && !S.plating, "the coat takes ten steps")
	plate_check(gild_run(D, 1) == PROCESS_KILL, "the coat finishes on the tenth step")
	plate_check(S.plating == "silver" && S.loc == T && S.name == "silver-plated [base_name]", "the spoon comes out silver-plated beside the dish")
	plate_check(S.value == base_value + 15, "silver adds value")
	plate_check(B.stored_energy == B.energy_capacity - 50, "the coat drew 50 PU s from the jar cell")
	plate_check(!D.anode && D.juice() == 7, "the coat used the sheet and five units of grape juice")
	plate_check(!(D in processing_objects), "a finished dish stops processing")
	plate_check(D.icon_state == "dish_juice", "a finished dish shows only the juice left")
	// A cell running dry pauses the coat until a charged one is back.
	var/obj/item/weapon/material/kitchen/utensil/fork/F = new(T, "iron")
	var/obj/item/stack/material/gold/Au = new(T)
	D.hang_anode(Au)
	D.start_coat(F)
	B.stored_energy = 49
	plate_check(gild_run(D, 12) != PROCESS_KILL && D.progress == 0 && !F.plating, "a nearly flat cell gives no progress")
	plate_check(D.icon_state == "dish_gold_wait", "a waiting dish shows the item but no bubbles")
	B.stored_energy = 100
	gild_run(D, 4)
	B.forceMove(locate(9, 9, 1))
	plate_check(gild_run(D, 10) != PROCESS_KILL && D.progress == 4, "a cell carried away pauses the coat")
	B.forceMove(locate(5, 6, 1))
	plate_check(gild_run(D, 6) == PROCESS_KILL && F.plating == "gold" && B.stored_energy == 50, "the coat finishes once the cell is back")
	// Progress is runtime state; a load restarts a coat.
	var/obj/item/weapon/material/kitchen/utensil/spoon/S2 = new(T, "copper")
	var/obj/item/stack/material/gold/Au2 = new(T)
	D.hang_anode(Au2)
	D.start_coat(S2)
	gild_run(D, 3)
	processing_objects -= D
	D.after_load()
	plate_check(D.progress == 0 && (D in processing_objects), "a coat in progress restarts after a load")
	plate_check(D.persistence_runtime_var("progress"), "progress is not saved")
	for (var/obj/O in list(D, S, S2, F, Cu, Ag, Au, Au2, B, Big))
		if (!QDELETED(O))
			qdel(O)

/proc/gilding_catalog_checks()
	plate_check(get_recipe_node_req("/obj/structure/gilding_dish") == "early_cells", "the gilding dish unlocks with Early Chemical Cells")
	var/list/drawn = icon_states('icons/obj/gilding_dish.dmi')
	var/missing = ""
	for (var/state in list("dish", "dish_gold", "dish_silver", "dish_juice", "dish_juice_gold", "dish_juice_silver", "dish_gold_wait", "dish_gold_on", "dish_silver_wait", "dish_silver_on"))
		if (!(state in drawn))
			missing += " [state]"
	plate_check(missing == "", "the dish sheet has every state the dish shows[missing]")
	var/found = FALSE
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: /material/copper/,gilding dish,/obj/structure/gilding_dish,") == 1)
			found = TRUE
	plate_check(found, "the gilding dish has a global copper recipe")
