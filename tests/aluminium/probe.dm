// Aluminium (code/modules/1713/aluminium.dm): bauxite from mining and
// crushing, the alumina digester and the reduction pot on cable power, the
// aluminium material and its research gate. Machine processes are called
// directly; no client connects.
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
/obj/map_metadata/alu_probe/New()
	return
var/alu_failures = 0
var/alu_runtime_error = FALSE
/proc/alu_check(condition, label)
	if (!condition)
		alu_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	alu_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// A cable and a running engine of power strength feeding O.
/proc/alu_power(obj/O, x, y, strength = 50)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = strength
	E.connections = list(C)
	C.connections = list(O, E)
	O.powersource = C
	C.rebuild_supply()
	return list(C, E)

/proc/alu_run(obj/structure/aluminium_works/W, steps)
	. = null
	for (var/i in 1 to steps)
		. = W.process()
		if (. == PROCESS_KILL)
			break

/proc/alu_count(turf/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (S.type == path)
			. += S.amount

/proc/alu_source_checks()
	map.ordinal_age = 3
	alu_check(mining_bauxite_chance(null) == 0, "no bauxite before the Industrial age")
	map.ordinal_age = 4
	var/area/A = new
	A.climate = "temperate"
	alu_check(mining_bauxite_chance(A) == 6, "6% of mined walls give bauxite in the Industrial age")
	A.climate = "jungle"
	alu_check(mining_bauxite_chance(A) == 12, "twice that under jungle")
	A.climate = "savanna"
	alu_check(mining_bauxite_chance(A) == 12, "and savanna")
	var/obj/item/stack/quarry_rubble/bauxite/quarry_bauxite = new(null, 2, FALSE)
	alu_check(!(/obj/item/stack/ore/bauxite in legacy_gaia_stone_crushing_table(4)) && stone_crush_result(quarry_bauxite, FALSE, 10000) == /obj/item/stack/ore/bauxite, "bauxite recovery requires source-bearing rubble, not Gaia fallback")
	qdel(quarry_bauxite)

/proc/alu_material_checks()
	var/material/M = get_material_by_name("aluminium")
	var/material/S = get_material_by_name("steel")
	alu_check(M && M.stack_type == /obj/item/stack/material/aluminium, "aluminium is a material with ingots")
	alu_check(M && S && M.density * 2 < S.density && !M.magnetic && !M.sparks && M.corrosion < S.corrosion, "it is far lighter than steel, not magnetic, does not spark or rust")
	var/obj/item/stack/material/aluminium/I = new(locate(18, 18, 1))
	I.amount = 30
	I.update_icon()
	alu_check(I.icon_state == "sheet-aluminium_3", "a pile of 30 ingots shows the third pile ([I.icon_state])")
	var/list/states = icon_states('icons/obj/aluminium.dmi')
	var/list/missing = list()
	for (var/state in list("ore_bauxite", "alumina", "sheet-aluminium", "sheet-aluminium_4", "digester", "digester_on", "reduction_pot", "reduction_pot_on", "red_mud"))
		if (!(state in states))
			missing += state
	alu_check(!missing.len, "every sprite the code names exists ([missing.Join(", ")])")
	qdel(I)

/proc/alu_digester_checks()
	var/turf/T = locate(5, 5, 1)
	var/obj/structure/aluminium_works/digester/D = new(T)
	var/obj/item/stack/ore/bauxite/B = new(T)
	B.amount = 9
	alu_check(D.load_bauxite(B) == 9 && D.bauxite == 9, "bauxite loads into the digester")
	alu_check(!D.can_work(), "without caustic it does nothing")
	D.reagents.add_reagent("sodium_hydroxide", 3)
	D.reagents.add_reagent("lye", 1)
	alu_check(D.can_work(), "with sodium hydroxide or lye it can work")
	D.wake()
	alu_run(D, 10)
	alu_check(!alu_count(T, /obj/item/stack/ore/alumina) && D.bauxite == 9, "unpowered it waits")
	var/list/power = alu_power(D, 4, 4, 50)
	alu_run(D, 5)
	alu_check(alu_count(T, /obj/item/stack/ore/alumina) == 1 && D.bauxite == 7 && D.caustic() == 3, "powered, 2 bauxite and 1 caustic make 1 alumina")
	alu_check(D.powered && D.icon_state == "digester_on", "it shows it is running")
	D.alumina_made = 9
	alu_run(D, 5)
	alu_check(locate(/obj/effect/decal/cleanable/red_mud) in T, "every tenth alumina leaves red mud")
	var/result = alu_run(D, 30)
	alu_check(result == PROCESS_KILL && alu_count(T, /obj/item/stack/ore/alumina) == 4 && D.caustic() == 0 && D.bauxite == 1, "it stops when the caustic runs out, lye used too ([alu_count(T, /obj/item/stack/ore/alumina)], [D.bauxite])")
	alu_check(!D.powered && D.icon_state == "digester", "and goes quiet")
	alu_check(D.factory_accepts(B) == 0 || QDELETED(B), "the used-up bauxite stack is gone")
	var/obj/item/stack/ore/bauxite/B2 = new(T)
	B2.amount = 5
	alu_check(D.factory_accepts(B2) == 1 && D.factory_insert(B2) == 1 && D.bauxite == 6, "factory arms load bauxite")
	for (var/obj/O in power)
		qdel(O)
	qdel(D)

/proc/alu_pot_checks()
	var/turf/T = locate(10, 10, 1)
	var/obj/structure/aluminium_works/reduction_pot/P = new(T)
	var/obj/item/stack/ore/alumina/A = new(T)
	A.amount = 3
	var/obj/item/stack/ore/coal/C = new(T)
	C.amount = 1
	alu_check(P.load(A) == 3 && P.load(C) == 1 && P.alumina == 3 && P.carbon == 1, "alumina and coal load into the pot")
	var/list/weak = alu_power(P, 9, 9, 20)
	alu_run(P, 10)
	alu_check(!alu_count(T, /obj/item/stack/material/aluminium) && !P.powered, "a small engine cannot drive it ([P.powerneeded] needed)")
	for (var/obj/O in weak)
		qdel(O)
	P.powersource = null
	var/list/power = alu_power(P, 11, 11, 60)
	alu_run(P, 5)
	alu_check(alu_count(T, /obj/item/stack/material/aluminium) == 1 && P.alumina == 2 && P.carbon == 0, "a big engine makes an ingot, burning an anode")
	alu_run(P, 5)
	alu_check(alu_count(T, /obj/item/stack/material/aluminium) == 2 && P.alumina == 1, "the anode lasts a second ingot")
	alu_check(!P.can_work(), "then it needs more carbon")
	var/obj/item/stack/ore/charcoal/Ch = new(T)
	Ch.amount = 1
	alu_check(P.factory_accepts(Ch) == 1 && P.factory_insert(Ch) == 1 && P.can_work(), "charcoal does too, loaded by an arm")
	alu_run(P, 5)
	alu_check(alu_count(T, /obj/item/stack/material/aluminium) == 3, "three alumina made three ingots")
	for (var/obj/O in power)
		qdel(O)
	qdel(P)

/proc/alu_ceramic_checks()
	var/turf/T = locate(15, 5, 1)
	var/obj/structure/furnace/kiln/K = new(T)
	var/obj/item/stack/ore/alumina/A = new(T)
	A.amount = 6
	alu_check(K.accept_alumina(A, null) && !K.accept_alumina(new /obj/item/stack/ore/bauxite(T), null), "the kiln takes alumina, not bauxite")
	alu_check(K.fire_alumina() == 6 && alu_count(T, /obj/item/stack/ceramic_tile) == 6, "a firing turns each alumina into a ceramic tile")
	var/list/states = icon_states('icons/obj/aluminium.dmi')
	alu_check(("ceramic_tile_4" in states) && ("composite_panel_4" in states), "tile and panel piles have sprites")
	var/datum/research_node/N = get_research_node("composite_armour")
	alu_check(N && ("modern_armor" in N.prereqs) && ("mechanized_war" in N.prereqs), "Composite Armour builds on Modern Armor and Mechanized Warfare")
	qdel(K)

/proc/alu_catalog_checks()
	alu_check(get_recipe_node_req("/obj/structure/aluminium_works/digester") == "aluminium_refining" && get_recipe_node_req("/obj/structure/aluminium_works/reduction_pot") == "aluminium_refining", "both machines unlock with Aluminium Refining")
	var/datum/research_node/N = get_research_node("aluminium_refining")
	alu_check(N && ("electricity" in N.prereqs) && ("alloys" in N.prereqs), "which needs Electricity and Alloys")
	var/found = 0
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1 && (findtext(line, ",/obj/structure/aluminium_works/digester,") || findtext(line, ",/obj/structure/aluminium_works/reduction_pot,")))
			found++
	alu_check(found == 2, "both have steel recipes")

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
		map = new /obj/map_metadata/alu_probe
		map.ordinal_age = 5
		for (var/x in 1 to 20)
			for (var/y in 1 to 20)
				var/turf/T = locate(x, y, 1)
				T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		alu_check(!world.port, "fixture has no listening port")
		alu_source_checks()
		alu_material_checks()
		alu_digester_checks()
		alu_pot_checks()
		alu_ceramic_checks()
		alu_catalog_checks()
	catch(var/exception/e)
		alu_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = alu_failures, "runtime_error" = alu_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
