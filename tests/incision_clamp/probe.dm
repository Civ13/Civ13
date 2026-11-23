// Native probe: a clamped incision stays clamped after its healed wound expires (issue 6979).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/incision_clamp/probe.dm
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
/obj/map_metadata/incision_clamp_probe/New()
	return
var/ic_failures = 0
var/ic_runtime_error = FALSE
/proc/ic_check(condition, label)
	if (!condition)
		ic_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ic_runtime_error = TRUE
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
		map = new /obj/map_metadata/incision_clamp_probe
		ic_checks()
	catch(var/exception/e)
		ic_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ic_failures, "runtime_error" = ic_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ic_checks()
	var/mob/living/human/H = new(locate(4, 4, 1))
	var/obj/item/organ/external/E = H.get_organ("chest")
	E.open = 1
	E.createwound(CUT, 1)
	E.update_damages()
	ic_check(E.status & ORGAN_BLEEDING, "an open, unclamped incision bleeds")
	E.clamping()
	E.update_damages()
	ic_check(!(E.status & ORGAN_BLEEDING), "clamping stops the incision bleeding")
	for (var/datum/wound/W in E.wounds)
		W.damage = 0
		W.created = world.time - 10 * 10 * 60 - 1
	E.update_wounds()
	ic_check(!length(E.wounds), "the healed incision wound expires")
	ic_check(!(E.status & ORGAN_BLEEDING), "the open incision stays clamped after its wound expires")
	E.open = 0
	E.update_damages()
	E.open = 1
	E.update_damages()
	ic_check(E.status & ORGAN_BLEEDING, "a reopened incision needs clamping again")
