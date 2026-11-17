// Native probe of code/modules/research_tree/the examine use hints,
// included by tests/ecology_spawning/run_linux.py, never by the game DME.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/obj/map_metadata/hint_probe/New()
	map = src
/mob/living/human/hint_tester/New()
	return
var/hint_failures = 0
var/hint_runtime_error = FALSE
/proc/hint_check(condition, label)
	if (!condition)
		hint_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hint_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		var/obj/structure/wild/tree/live_tree/T = new(locate(2, 2, 1))
		T.branches = 2
		T.max_branches = 3
		var/hint = T.use_hint(null)
		hint_check(findtext(hint, "Harm intent to break off a branch (2 left") && findtext(hint, "chops it down for wood"), "a tree says how to take a branch and fell it")
		hint_check(!!findtext(hint, "Grab intent to climb it") == !!(T.density && T.holds_climber), "a tree offers climbing only when it can be climbed")
		T.branches = 0
		hint_check(findtext(T.use_hint(null), "branches have all been taken") && !findtext(T.use_hint(null), "break off"), "a stripped tree says its branches grow back")
		var/obj/structure/wild/palm/P = new(locate(3, 2, 1))
		hint = P.use_hint(null)
		hint_check(P.branches == 2 && P.max_branches == 2 && findtext(hint, "break off a branch (2 left"), "a palm gives branches too")
		hint_check(findtext(hint, "palm leaves") && findtext(hint, "taps its sap"), "a palm says what else it gives")
		var/obj/structure/wild/bush/B = new(locate(4, 2, 1))
		hint_check(isnull(B.use_hint(null)) || !findtext(B.use_hint(null), "chops"), "a bush is not described as a tree")
		var/obj/structure/multiz/ladder/down = new(locate(2, 4, 1))
		var/obj/structure/multiz/ladder/up/up = new(locate(3, 4, 1))
		hint_check(findtext(down.use_hint(null), "climb [down.istop ? "down" : "up"]") && findtext(up.use_hint(null), "climb up"), "a ladder says which way it goes")
		var/obj/structure/multiz/ladder/ww2/tunneltop/pit/hole = new(locate(4, 4, 1))
		hint_check(findtext(hole.use_hint(null), "Climb Up in the IC tab"), "a dug hole says how to get out")
		hole.leaf_covered = TRUE
		hint_check(isnull(hole.use_hint(null)), "a hole disguised with leaves gives nothing away")
		var/mob/living/human/hint_tester/H = new(locate(1, 1, 1))
		hint_check(isnull(H.use_hint(null)), "other things have no hint")
	catch(var/exception/e)
		hint_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hint_failures, "runtime_error" = hint_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
