// Extraction kit on ore stacks (code/modules/1713/ores.dm, aluminium.dm):
// each use purifies ONE ore into the 5-unit kit and leaves the rest of the
// stack. A player report had a stack of 50 iron give 5 units and vanish.
// The production attackby bodies run; only the do_after wait is replaced.
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
/obj/map_metadata/ore_kit_probe/New()
	return
/mob/living/human/ore_kit_probe/New()
	return
/mob/living/human/ore_kit_probe/getStatCoeff(statname)
	return 1
var/ore_kit_failures = 0
var/ore_kit_runtime_error = FALSE
var/ore_kit_wait_ok = TRUE
var/ore_kit_waits = 0
/proc/ore_kit_check(condition, label)
	if (!condition)
		ore_kit_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ore_kit_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/item/stack/ore/kit_wait(mob/living/human/H, delay)
	ore_kit_waits++
	return ore_kit_wait_ok

/proc/ore_kit_stack(path, amount, turf/T)
	var/obj/item/stack/ore/O = new path(T)
	O.amount = amount
	O.update_icon()
	return O

/proc/ore_kit_checks(mob/living/human/H, turf/T)
	// The reported case: a full stack of iron.
	var/obj/item/weapon/reagent_containers/glass/extraction_kit/K = new(T)
	var/obj/item/stack/ore/iron/I = ore_kit_stack(/obj/item/stack/ore/iron, 50, T)
	I.attackby(K, H)
	ore_kit_check(!QDELETED(I) && I.amount == 49, "a stack of 50 iron loses one ore per use ([I.amount] left)")
	ore_kit_check(K.reagents.get_reagent_amount("iron") == 5, "and the kit gets 5 iron")
	I.attackby(K, H)
	ore_kit_check(I.amount == 49 && K.reagents.total_volume == 5, "a full kit takes nothing more from the stack")
	K.reagents.clear_reagents()
	ore_kit_wait_ok = FALSE
	I.attackby(K, H)
	ore_kit_wait_ok = TRUE
	ore_kit_check(I.amount == 49 && K.reagents.total_volume == 0, "an interrupted purification takes no ore")
	for (var/i in 1 to 3)
		K.reagents.clear_reagents()
		I.attackby(K, H)
	ore_kit_check(I.amount == 46 && K.reagents.get_reagent_amount("iron") == 5, "three more uses take three more ore ([I.amount] left)")
	// The last ore of a stack is used up.
	K.reagents.clear_reagents()
	var/obj/item/stack/ore/iron/last = ore_kit_stack(/obj/item/stack/ore/iron, 1, locate(6, 5, 1))
	last.attackby(K, H)
	ore_kit_check(last.amount == 0 && K.reagents.get_reagent_amount("iron") == 5, "a single ore is used up for its 5 units ([last.amount], [K.reagents.total_volume])")
	qdel(I)
	// Every ore the kit purifies keeps the rest of its stack.
	var/list/kinds = list(
		/obj/item/stack/ore/iron_sponge = "iron", /obj/item/stack/ore/iron_pig = "iron",
		/obj/item/stack/ore/silver = "silver", /obj/item/stack/ore/gold = "gold",
		/obj/item/stack/ore/copper = "copper", /obj/item/stack/ore/tin = "tin",
		/obj/item/stack/ore/zinc = "zinc", /obj/item/stack/ore/saltpeter = "potassium",
		/obj/item/stack/ore/coal = "carbon", /obj/item/stack/ore/charcoal = "charcoal",
		/obj/item/stack/ore/sulphur = "sulfur", /obj/item/stack/ore/lead = "lead",
		/obj/item/stack/ore/bauxite = "aluminum", /obj/item/stack/ore/uranium = "uranium")
	for (var/path in kinds)
		K.reagents.clear_reagents()
		var/obj/item/stack/ore/O = ore_kit_stack(path, 20, T)
		O.attackby(K, H)
		ore_kit_check(!QDELETED(O) && O.amount == 19 && K.reagents.get_reagent_amount(kinds[path]) > 0 && K.reagents.total_volume == 5, "[path]: 20 ore leave 19 and 5 units ([QDELETED(O) ? "gone" : O.amount], [K.reagents.total_volume])")
		qdel(O)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/ore_kit_probe
		map.ordinal_age = 5
		populate_material_list()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/ore_kit_probe/H = new(locate(5, 6, 1))
		H.a_intent = I_HELP
		ore_kit_check(!world.port, "fixture has no listening port")
		ore_kit_checks(H, T)
	catch(var/exception/e)
		ore_kit_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ore_kit_failures, "runtime_error" = ore_kit_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
