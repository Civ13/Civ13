// Native probe: suit radiation protection applies to every covered body part (#6276).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/radiation_armor/probe.dm
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
/obj/map_metadata/ra_probe/New()
	return

var/ra_failures = 0
var/ra_runtime_error = FALSE
/proc/ra_check(condition, label)
	if (!condition)
		ra_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ra_runtime_error = TRUE
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
		map = new /obj/map_metadata/ra_probe
		ra_dose_checks()
	catch(var/exception/e)
		ra_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ra_failures, "runtime_error" = ra_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ra_dose(mob/living/human/H, amount)
	H.radiation = 0
	H.rad_act(amount)
	return H.radiation

/proc/ra_dose_checks()
	var/mob/living/human/bare = new(locate(5, 5, 1))
	var/mob/living/human/suited = new(locate(6, 5, 1))
	var/obj/item/clothing/suit/hazmat/S = new(suited)
	suited.equip_to_slot_or_del(S, slot_wear_suit)
	ra_check(suited.wear_suit == S, "the hazmat suit is worn")
	ra_check(abs(ra_dose(bare, 110) - 110) < 0.01, "an unprotected person takes the whole pulse")
	ra_check(ra_dose(suited, 110) < 0.01, "a full-coverage rad 100 suit blocks every body part's share")
