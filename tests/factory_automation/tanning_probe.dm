// Industrial leather: the powered tanning drum. Runs the
// production sources through the shared resource-extraction fixture with
// ordinary game startup disabled; machine steps are called directly.
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
/obj/map_metadata/machine_probe/New()
	return
/mob/living/human/machine_probe/New()
	return
/mob/living/human/machine_probe/update_icons()
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
		map = new /obj/map_metadata/machine_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				belt_floor(x, y)
		machine_check(!world.port, "fixture has no listening port")
		tanning_catalog_checks()
		tanning_drum_checks()
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

/proc/tanning_catalog_checks()
	machine_check(get_recipe_node_req("/obj/structure/tanning_drum") == "factories", "the tanning drum unlocks with Factories")
	var/datum/research_node/factories = research_nodes["factories"]
	machine_check(factories && factories.era_tier == 4, "Factories is a steam-era node")
	var/steel = FALSE
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: /material/steel/,tanning drum,/obj/structure/tanning_drum,") == 1)
			steel = TRUE
	machine_check(steel, "the global catalogue builds the drum from steel")
	var/list/states = icon_states('icons/obj/tanning_drum.dmi')
	machine_check(("tanning_drum" in states) && ("tanning_drum_on" in states) && ("tanning_drum_off" in states), "the drum's sprite states exist")

/proc/tanning_leather(turf/T)
	var/total = 0
	for (var/obj/item/stack/material/leather/L in T)
		total += L.amount
	return total

/proc/tanning_drum_checks()
	var/obj/structure/tanning_drum/D = new(locate(2, 2, 1))
	var/obj/item/stack/material/pelt/pelts = new(locate(1, 2, 1), 40, FALSE)
	var/obj/item/stack/material/dryhide/dry = new(locate(1, 3, 1), 2, FALSE)
	var/obj/item/stack/bark/bark = new(locate(1, 4, 1), 25)
	var/obj/item/stack/material/stone/stone = new(locate(1, 5, 1), 5, FALSE)
	machine_check(D.factory_accepts(pelts) == 30, "the hopper takes up to thirty hides")
	machine_check(D.factory_accepts(bark) == 20, "the hopper takes up to twenty pieces of bark")
	machine_check(!D.factory_accepts(stone), "the drum refuses what it cannot tan")
	D.anchored = FALSE
	machine_check(!D.factory_accepts(pelts) && !D.factory_offer(), "an unfastened drum has no port")
	D.anchored = TRUE
	machine_check(D.factory_insert(dry) == 2 && QDELETED(dry) && D.hide_count() == 2, "dry hides load")
	machine_check(D.factory_insert(pelts) == 28 && D.hide_count() == 30 && pelts.amount == 12, "pelts share the hopper and the rest stays behind")
	machine_check(!D.factory_accepts(pelts), "a full hopper takes no more hides")
	machine_check(D.factory_insert(bark) == 20 && D.bark == 20 && bark.amount == 5, "bark fills its own hopper")
	machine_check(D in factory_active_tanning_drums, "loaded hides wake the drum")
	// Liquids.
	machine_check(D.fluid_demand_tier() == FLUID_TIER_SINK && D.fluid_demand("water") == 100 && D.fluid_demand("tannin") == 100, "the drum wants a hundred water and a hundred tannin from pipes")
	machine_check(!D.fluid_demand("petroleum") && !D.fluid_receive("petroleum", 50, null), "the drum takes no other liquid")
	machine_check(D.fluid_receive("water", 150, null) == 100 && D.fluid_demand("water") == 0, "piped water stops at a hundred")
	// Power.
	factory_tanning_drums_step()
	factory_tanning_drums_step()
	machine_check(!tanning_leather(D.loc) && D.hide_count() == 30 && D.wait_reason == "it has no power" && !D.working, "an unpowered drum tans nothing")
	var/list/power = machine_power(D, 2, 3)
	// Dry hides go first and need only tannin; bark is soaked for it.
	factory_tanning_drums_step()
	machine_check(D.working && D.icon_state == "tanning_drum_on" && D.bark == 19 && D.reagents.get_reagent_amount("tannin") == 10 && D.reagents.get_reagent_amount("water") == 90, "a powered drum turns and soaks one bark in ten water for ten tannin")
	factory_tanning_drums_step()
	machine_check(tanning_leather(D.loc) == 1 && D.hide_count() == 29 && D.reagents.get_reagent_amount("tannin") == 5 && D.reagents.get_reagent_amount("water") == 90, "a dry hide becomes leather in two powered seconds for five tannin")
	factory_tanning_drums_step()
	factory_tanning_drums_step()
	machine_check(tanning_leather(D.loc) == 2 && D.reagents.get_reagent_amount("water") == 90 && !(("[/obj/item/stack/material/dryhide]") in D.hides), "the second dry hide needs no water")
	factory_tanning_drums_step()
	factory_tanning_drums_step()
	machine_check(tanning_leather(D.loc) == 3 && D.hide_count() == 27 && D.reagents.get_reagent_amount("water") == 75 && D.reagents.get_reagent_amount("tannin") == 5, "a pelt is washed and tanned for five water and five tannin, merging with the leather on the tile")
	var/obj/item/stack/material/leather/L = locate() in D.loc
	machine_check(D.factory_offer() == L, "the drum offers its leather")
	var/obj/structure/closet/crate/C = belt_closed_crate(locate(3, 2, 1))
	machine_check(D.factory_take(L, C) && L.loc == C, "an arm can take the leather away")
	// Out of water: it waits and says why.
	D.reagents.remove_reagent("water", D.reagents.get_reagent_amount("water"))
	D.bark = 0
	factory_tanning_drums_step()
	factory_tanning_drums_step()
	machine_check(D.hide_count() == 27 && D.wait_reason == "it needs water" && !D.working && D.icon_state == "tanning_drum_off", "without water an unwashed hide waits")
	// Saving.
	machine_check(!D.persistence_runtime_var("hides") && !D.persistence_runtime_var("bark") && D.persistence_runtime_var("work_steps") && D.persistence_runtime_var("working"), "the hoppers are saved and progress is not")
	D.hides["/obj/item/stack/material/stone"] = 4
	D.hides["[/obj/item/stack/material/pelt]"] = 99
	D.bark = 50
	factory_active_tanning_drums -= D
	D.after_load()
	machine_check(D.hide_count() == 30 && !("/obj/item/stack/material/stone" in D.hides) && D.bark == 20 && (D in factory_active_tanning_drums), "load drops unknown entries, clamps the hoppers and resumes")
	// Emptying returns what was loaded, as it was loaded.
	var/turf/T = D.loc
	qdel(D)
	var/obj/item/stack/material/pelt/back = locate() in T
	var/obj/item/stack/bark/back_bark = locate() in T
	machine_check(back && back.amount == 30 && back_bark && back_bark.amount == 20 && !(D in factory_active_tanning_drums), "removing the drum returns its hides and bark")
	for (var/obj/O in list(pelts, bark, stone, C, back, back_bark) + power)
		qdel(O)
