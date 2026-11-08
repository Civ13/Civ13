// Electroplating: the plating bath and the coats it gives.
// Runs the production sources through the shared resource-extraction fixture
// with ordinary game startup disabled; the bath's process is called directly.
#define PLATING_PROBE_STEPS 5
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
/obj/map_metadata/plating_probe/New()
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
/proc/plate_power(obj/O, x, y)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = 50
	E.connections = list(C)
	C.connections = list(O, E)
	O.powersource = C
	C.rebuild_supply()
	return list(C, E)
/proc/plate_run(obj/structure/plating_bath/B, steps)
	var/result = null
	for (var/i in 1 to steps)
		result = B.process()
		if (result == PROCESS_KILL)
			break
	return result
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
		map = new /obj/map_metadata/plating_probe
		map.ordinal_age = 5
		map.age = "1873"
		for (var/x in 1 to 20)
			for (var/y in 1 to 20)
				var/turf/T = locate(x, y, 1)
				T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		plate_check(!world.port, "fixture has no listening port")
		plating_refusal_checks()
		plating_bath_checks()
		plating_wear_checks()
		plating_port_checks()
		plating_catalog_checks()
	catch(var/exception/e)
		plate_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = plate_failures, "runtime_error" = plate_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/plating_refusal_checks()
	var/turf/T = locate(15, 15, 1)
	var/obj/item/weapon/material/sword/S = new(T, "steel")
	plate_check(!plating_refusal(S), "a steel sword can take a coat")
	var/obj/item/stack/material/gold/G = new(T)
	plate_check(plating_refusal(G), "a stack is never plated")
	var/obj/item/weapon/material/sword/W = new(T, "wood")
	plate_check(plating_refusal(W) == "\The [W] is not metal.", "a wooden sword is refused as not metal")
	S.apply_plating("tin")
	plate_check(plating_refusal(S) == "\The [S] is already plated.", "an item takes only one coat")
	for (var/obj/O in list(S, G, W))
		qdel(O)

/proc/plating_bath_checks()
	var/turf/T = locate(3, 3, 1)
	var/obj/structure/plating_bath/B = new(T)
	var/obj/item/weapon/material/sword/S = new(locate(4, 4, 1), "steel")
	var/base_value = S.value
	var/base_name = S.name
	plate_check(B.start_refusal(S) == "Hang a sheet of gold, silver, copper or tin in \the [B] first.", "a bath without an anode refuses")
	var/obj/item/stack/material/gold/G = new(locate(4, 4, 1))
	G.amount = 3
	plate_check(B.hang_anode(G) && B.anode == "gold" && G.amount == 2, "hanging a gold sheet uses one sheet")
	plate_check(!B.hang_anode(G) && G.amount == 2, "only one sheet hangs at a time")
	plate_check(findtext(B.start_refusal(S), "sulphuric acid"), "a bath without acid refuses")
	B.reagents.add_reagent("sacid", 12)
	plate_check(!B.start_refusal(S), "with acid and an anode the bath starts")
	B.start_coat(S)
	plate_check(S.loc == B && (B in processing_objects), "the item goes into the bath and the bath processes")
	plate_check(plate_run(B, 6) != PROCESS_KILL && !S.plating && B.progress == 0, "an uncabled bath makes no progress")
	var/list/power = plate_power(B, 3, 3)
	plate_check(plate_run(B, 4) != PROCESS_KILL && B.powered && B.progress == 4, "a cabled bath draws power and makes progress")
	plate_check(plate_run(B, 1) == PROCESS_KILL, "the coat finishes after five powered steps")
	plate_check(S.plating == "gold" && S.loc == T && S.name == "gold-plated [base_name]", "the item comes out gold-plated beside the bath")
	plate_check(S.value == base_value + 30 && 30 < initial(G.value), "gold adds value, less than the sheet it used")
	plate_check(S.color == "#e8c547", "gold tints the item")
	plate_check(!B.anode && B.acid() == 7, "the coat used the anode and five units of acid")
	plate_check(!B.powered && !B.powersource.power_consumers[B], "a finished bath releases its power")
	plate_check(S.plating_wear(5) == 5, "gold does not resist wear")
	B.after_load()
	plate_check(!(B in processing_objects), "an empty bath stays out of the process after a load")
	var/obj/item/weapon/material/sword/S2 = new(locate(4, 4, 1), "iron")
	B.hang_anode(G)
	B.start_coat(S2)
	plate_run(B, 2)
	processing_objects -= B
	B.after_load()
	plate_check(B.progress == 0 && (B in processing_objects), "a coat in progress restarts after a load")
	plate_check(B.persistence_runtime_var("progress") && B.persistence_runtime_var("powered"), "progress and power are not saved")
	for (var/obj/O in list(B, S, S2, G) + power)
		if (!QDELETED(O))
			qdel(O)

/proc/plating_wear_checks()
	var/turf/T = locate(10, 10, 1)
	var/obj/item/weapon/material/sword/S = new(T, "steel")
	var/obj/item/weapon/material/sword/P = new(T, "steel")
	P.apply_plating("tin")
	plate_check(P.plating_wear(10) == 5 && S.plating_wear(10) == 10, "tin halves wear, an unplated item wears normally")
	var/obj/item/weapon/material/sword/C = new(T, "steel")
	C.apply_plating("copper")
	plate_check(C.plating_wear(4) == 3, "copper takes a quarter off wear")
	for (var/obj/O in list(S, P, C))
		qdel(O)

/proc/plating_port_checks()
	var/turf/T = locate(7, 7, 1)
	var/obj/structure/plating_bath/B = new(T)
	B.reagents.add_reagent("sacid", 5)
	plate_check(B.fluid_demand("sacid") == 95 && !B.fluid_demand("water") && B.fluid_demand_tier(), "pipes may fill only sulphuric acid")
	var/obj/item/stack/material/tin/Tin = new(locate(8, 8, 1))
	Tin.amount = 2
	plate_check(B.factory_accepts(Tin) == 1 && B.factory_insert(Tin) == 1 && B.anode == "tin" && Tin.amount == 1, "an arm can hang a sheet")
	plate_check(!B.factory_accepts(Tin), "an arm cannot hang a second sheet")
	var/obj/item/weapon/material/sword/S = new(locate(8, 8, 1), "steel")
	plate_check(B.factory_insert(S) == 1 && S.loc == B, "an arm can lower an item in")
	var/list/power = plate_power(B, 7, 7)
	plate_run(B, PLATING_PROBE_STEPS)
	plate_check(B.factory_offer() == S, "the coated item is offered to arms")
	var/obj/structure/closet/crate/C = new(locate(9, 9, 1))
	plate_check(B.factory_take(S, C) && S.loc == C, "an arm can take the coated item out")
	plate_check(!B.factory_offer(), "nothing else is offered")
	for (var/obj/O in list(B, Tin, S, C) + power)
		if (!QDELETED(O))
			qdel(O)

/proc/plating_catalog_checks()
	plate_check(get_recipe_node_req("/obj/structure/plating_bath") == "electricity", "the plating bath unlocks with Electricity")
	var/list/states = icon_states('icons/obj/chemical.dmi')
	plate_check(("centrifuge" in states) && ("centrifuge_powered" in states) && ("centrifuge_active" in states), "the bath reuses existing sprites")
	var/found = FALSE
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1 && findtext(line, ",/obj/structure/plating_bath,"))
			found = TRUE
	plate_check(found, "the plating bath has a global recipe")
