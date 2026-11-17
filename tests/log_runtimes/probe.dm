// Native probe of the runtime errors Gaia's logs repeated most (Nov 14-17 2026),
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
/obj/map_metadata/runtime_probe/New()
	map = src
/mob/living/human/runtime_tester/New()
	return
// The timer under test never joins the timer subsystem.
/datum/timedevent/runtime_probe/New()
	return
var/runtime_failures = 0
var/runtime_error_seen = FALSE
/proc/runtime_check(condition, label)
	if (!condition)
		runtime_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	runtime_error_seen = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		populate_material_list()
		new /obj/map_metadata/runtime_probe
		var/datum/timedevent/runtime_probe/T = new
		T.callBack = new /datum/callback(null, "nothing")
		T.callBack.object = null
		runtime_check(T.getcallingtype() == "null", "a timer whose target is gone still gets a name")
		T.callBack = new /datum/callback(GLOBAL_PROC, "nothing")
		runtime_check(T.getcallingtype() == "GLOBAL_PROC", "a global timer is still named as one")
		T.callBack = new /datum/callback(map, "nothing")
		runtime_check(T.getcallingtype() == "[map.type]", "a timer on an object is still named by its type")
		var/datum/reagent/water/W = new
		W.holder = null
		W.remove_self(1)
		runtime_check(TRUE, "a reagent with no holder removes nothing")
		var/mob/living/human/runtime_tester/H = new(locate(1,1,1))
		var/obj/item/stack/material/wood/S = new(locate(2,2,1))
		S.material = null
		S.default_type = "no such material"
		S.list_recipes(H)
		runtime_check(!S.material, "a stack of an unknown material lists nothing")
		S.default_type = "wood"
		S.list_recipes(H)
		runtime_check(S.material && S.material == get_material_by_name("wood"), "a stack that lost its material finds it again")
	catch(var/exception/e)
		runtime_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = runtime_failures, "runtime_error" = runtime_error_seen, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
