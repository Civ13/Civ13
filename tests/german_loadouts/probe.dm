// Native probe: Teutoburg German Jarl and spearman keep their whole loadout (issues 6988, 6989).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/german_loadouts/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/german_loadouts_probe/New()
	return
var/gl_failures = 0
var/gl_runtime_error = FALSE
/proc/gl_check(condition, label)
	if (!condition)
		gl_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	gl_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/german_loadouts_probe
		gl_checks()
	catch(var/exception/e)
		gl_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = gl_failures, "runtime_error" = gl_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/gl_count(mob/living/human/H, path)
	. = 0
	for (var/obj/item/I in H.contents)
		if (I.type == path)
			.++

/proc/gl_checks()
	var/mob/living/human/J = new(locate(4, 4, 1))
	var/datum/job/german/chieftain/jarl = new
	jarl.equip(J)
	gl_check(istype(J.r_hand, /obj/item/weapon/shield/scutum), "the Jarl holds a scutum")
	gl_check(gl_count(J, /obj/item/weapon/material/sword/gaelic/iron) == 2, "the Jarl keeps both swords")
	var/mob/living/human/S = new(locate(8, 4, 1))
	var/datum/job/german/spearman/spear = new
	spear.equip(S)
	gl_check(gl_count(S, /obj/item/weapon/material/spear/sarissa/pike) == 2, "the spearman keeps both pikes")
	gl_check(istype(S.back, /obj/item/weapon/shield/scutum), "the spearman keeps the shield on the back")
