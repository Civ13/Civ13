// Native probe for cool cellars
// (code/modules/1713/cool_cellars.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/cool_cellars/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/cc_probe/New()
	return
/mob/living/human/cc_fixture
	m_intent = "stealth"
	var/mood_gain = 0
/mob/living/human/cc_fixture/New()
	return
/mob/living/human/cc_fixture/adaptStat(stat, amount)
	return
/mob/living/human/cc_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/cc_fixture/update_icons()
	return
/mob/living/human/cc_fixture/regenerate_icons()
	return
/mob/living/human/cc_fixture/adjust_mood(amount, reason)
	mood_gain += amount
var/cc_failures = 0
var/cc_runtime_error = FALSE
/proc/cc_check(condition, label)
	if (!condition)
		cc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/cc_probe
		cc_checks()
	catch(var/exception/e)
		cc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cc_failures, "runtime_error" = cc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cc_checks()
	var/area/caribbean/void/caves/cave = new
	cave.contents += locate(2, 6, 1)
	var/turf/up = locate(8, 2, 1)
	var/turf/down = locate(2, 6, 1)
	cc_check(!turf_in_cool_cellar(up), "the surface is not a cellar")
	cc_check(turf_in_cool_cellar(down), "the caves are a cellar")

	// Temperature: near 12 C whatever the season, never above 18.
	cc_check(cool_cellar_temperature(-29) == 5, "a temperate winter cellar is cool, not frozen ([cool_cellar_temperature(-29)])")
	cc_check(cool_cellar_temperature(30) == 14, "a temperate summer cellar is cool ([cool_cellar_temperature(30)])")
	cc_check(cool_cellar_temperature(60) == 18, "even under a sandstorm a cellar stays below 18")
	season = "SUMMER"
	cc_check(get_temp(down) <= 18, "get_temp underground in summer is cool ([get_temp(down)])")
	season = "WINTER"
	cc_check(get_temp(down) >= 0, "get_temp underground in winter is above freezing ([get_temp(down)])")

	// Food: slower in a cellar, never slower than a cold ice house.
	var/obj/item/weapon/reagent_containers/food/snacks/S = new(down)
	cc_check(cool_cellar_decay_step(S, 600) == 360, "loose food in a cellar ages at 60%")
	cc_check(cool_cellar_decay_step(S, 300) == 180, "stored food in a cellar ages at 60%")
	cc_check(cool_cellar_decay_step(S, 75) == 60, "a fridge in a cellar is not better than an ice house")
	cc_check(cool_cellar_decay_step(S, 50) == 50, "a cold ice house step is unchanged")
	S.loc = up
	cc_check(cool_cellar_decay_step(S, 600) == 600, "food on the surface ages as before")
