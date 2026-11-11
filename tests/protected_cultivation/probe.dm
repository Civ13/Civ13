// Native greenhouse probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/ecology/protected_cultivation.dm.
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
/obj/map_metadata/greenhouse_probe/New()
	map = src
/mob/living/greenhouse_tester/New()
	return
var/gh_failures = 0
var/gh_runtime_error = FALSE
/proc/gh_check(condition, label)
	if (!condition)
		gh_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	gh_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/greenhouse_probe
		greenhouse_checks()
	catch(var/exception/e)
		gh_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = gh_failures, "runtime_error" = gh_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/gh_plot(x, y)
	var/turf/T = locate(x, y, 1)
	T.ChangeTurf(/turf/floor/dirt/ploughed, FALSE, FALSE)
	T.is_plowed = TRUE
	return T

// Trials of the paused path: growth() passes FALSE when the season is wrong.
/proc/gh_trials(obj/structure/farming/plant/P, allow = FALSE)
	. = 0
	for (var/i in 1 to 200)
		P.stage = 1
		P.plant_nutrition = 100
		P.advance_stage_if_allowed(allow)
		. += P.stage - 1

/proc/greenhouse_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	A.weather = WEATHER_NONE
	season = "WINTER"
	var/obj/structure/farming/plant/wheat/open = new(gh_plot(3, 3))
	gh_check(!("WINTER" in open.seasons), "wheat is out of season in winter")
	gh_check(gh_trials(open) == 0, "open-sky wheat does not grow in winter")
	var/turf/wood_plot = gh_plot(6, 3)
	new /obj/roof/wood(wood_plot)
	var/obj/structure/farming/plant/wheat/barn = new(wood_plot)
	gh_check(gh_trials(barn) == 0, "an opaque roof does not extend the season")
	var/turf/glass_plot = gh_plot(9, 3)
	new /obj/roof/glass(glass_plot)
	gh_check(get_area(glass_plot) != A, "a glass roof makes the plot sheltered")
	var/obj/structure/farming/plant/wheat/green = new(glass_plot)
	var/grown = gh_trials(green)
	gh_check(grown > 60 && grown < 140, "glass-roofed wheat grows out of season at half speed ([grown]/200)")
	gh_check(gh_trials(green, TRUE) == 200, "in season the roof changes nothing")
	var/found = FALSE
	for (var/line in green.farming_diagnostics(1))
		if (findtext(line, "glass roof"))
			found = TRUE
	gh_check(found, "examine explains the greenhouse")
	season = "SUMMER"
	gh_check(!green.greenhouse_extends_season(), "no greenhouse effect in season")
	season = "WINTER"

	// No universal biome growth: the climate must still suit the crop.
	var/area/G = get_area(glass_plot)
	G.climate = "jungle"
	gh_check(!("jungle" in green.biomes) && gh_trials(green) == 0, "glass does not grow a crop outside its climate")
	G.climate = "temperate"

	// Pollution still blocks greenhouse growth.
	glass_plot.pollution = 60 // POLLUTION_BLOCK, undefined after pollution.dm
	gh_check(gh_trials(green) == 0, "pollution still blocks greenhouse growth")
	glass_plot.pollution = 0

	// No free water: there is no rain under a roof, and the crop still dries.
	green.stage = 2
	green.water = green.max_water
	for (var/i in 1 to 10)
		green.water_proc()
	gh_check(green.stage == 11 && findtext(green.name, "dry"), "a greenhouse crop still needs watering")

	// Dead, static and tree plants are excluded.
	var/obj/structure/farming/plant/wheat/dead = new(gh_plot(12, 3))
	new /obj/roof/glass(dead.loc)
	dead.stage = 11
	gh_check(!dead.greenhouse_extends_season(), "dead crops are excluded")
	dead.stage = 2
	dead.vstatic = TRUE
	gh_check(!dead.greenhouse_extends_season(), "display-only crops are excluded")
