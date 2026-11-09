// Isolated production-path probe. No client, listening socket, or game startup.
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/jungle_hiding_probe/New()
	return
/mob/living/human/jungle_hiding_probe/New()
	return
var/jungle_failures = 0
var/jungle_runtime_error = FALSE
/proc/jungle_check(condition, label)
	if (!condition)
		jungle_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	jungle_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/jungle_hiding_probe
		var/turf/T = locate(5, 5, 1)
		var/obj/structure/wild/jungle/tree = new(locate(6, 5, 1))
		var/mob/living/human/jungle_hiding_probe/first = new(T)
		var/mob/living/human/jungle_hiding_probe/second = new(T)
		first.faction_text = "VIETNAMESE"
		second.faction_text = "VIETNAMESE"
		var/datum/epoch = persistence_admission_identity
		var/datum/stale = new
		jungle_check(!tree.finish_hiding(first, stale) && first.loc == T, "stale save identity refuses entry")
		jungle_check(tree.finish_hiding(first, epoch) && first.loc == tree, "first player hides")
		jungle_check(!tree.finish_hiding(second, epoch) && second.loc == T && tree.stored_unit == first, "competing player cannot replace occupant")
		tree.release_stored()
		jungle_check(first.loc == get_turf(tree) && !tree.stored_unit, "disconnected occupant is released")
		jungle_check(tree.finish_hiding(second, epoch), "another player can hide after release")
		var/turf/tree_turf = get_turf(tree)
		qdel(tree)
		jungle_check(second.loc == tree_turf, "tree destruction releases disconnected occupant")
	catch(var/exception/e)
		jungle_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = jungle_failures, "runtime_error" = jungle_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
