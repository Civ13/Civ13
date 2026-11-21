// Native probe for wind chill and heat index (docs/feels-like.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/feels_like/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 96
	maxy = 64
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/fl_probe/New()
	return
/area/caribbean/fl_probe
var/fl_failures = 0
var/fl_runtime_error = FALSE
/proc/fl_check(condition, label)
	if (!condition)
		fl_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fl_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/fl_probe
		fl_checks()
	catch(var/exception/e)
		fl_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fl_failures, "runtime_error" = fl_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/fl_area(climate, x1, x2, location = AREA_OUTSIDE)
	var/area/caribbean/fl_probe/A = new
	A.climate = climate
	A.location = location
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

/proc/fl_checks()
	season = "WINTER"
	time_of_day = "Morning"
	map.winddirection = "West"
	map.windspeedvar = 3
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	fl_area("temperate", 1, 96)
	fl_area("temperate", 60, 70, AREA_INSIDE)
	weather_centres_clear()
	weather_systems_clear()
	weather_storm_count = 0
	var/turf/field = locate(24, 32, 1)
	var/turf/hall = locate(64, 32, 1)

	// The formulas.
	var/wc = feels_like_wind_chill(-10, 30 / 3.6)
	fl_check(abs(wc - 9.5) < 0.4, "-10 C in a 30 km/h wind feels about -19.5 C ([-10 - wc])")
	fl_check(!feels_like_wind_chill(15, 10) && !feels_like_wind_chill(-5, 1), "no wind chill in mild air or a calm")
	var/hi = feels_like_heat_index(32, 70)
	fl_check(abs(hi - 8.4) < 0.5, "32 C at 70% humidity feels about 40 C ([32 + hi])")
	fl_check(!feels_like_heat_index(32, 30) && !feels_like_heat_index(24, 90), "no heat index in dry or cool air")

	// A windy winter morning.
	weather_air_grid()
	weather_air.settle(TRUE)
	var/mob/living/human/H = new /mob/living/human(field)
	var/bare = H.feels_like_temperature(-2)
	fl_check(bare < -7, "a fresh wind makes -2 C feel much colder ([bare])")
	fl_check(abs(weather_feels_like_at(field) - (get_temp(field) - feels_like_wind_chill(get_temp(field), weather_wind_ms_at(field)))) < 0.01, "the reader agrees for bare skin")
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/oilskin_coat(H), slot_wear_suit)
	var/coated = H.feels_like_temperature(-2)
	fl_check(coated > bare + 4 && coated < -2, "an oilskin coat keeps most of it off ([coated])")
	var/mob/living/human/inside = new /mob/living/human(hall)
	fl_check(inside.feels_like_temperature(-2) == -2, "indoors the air is just the air")
	map.windspeedvar = 0
	weather_air.settle(TRUE)
	fl_check(H.feels_like_temperature(-2) == -2, "and in a calm there is no chill")

	// A hot afternoon in the sun.
	season = "SUMMER"
	time_of_day = "Afternoon"
	weather_air.settle(TRUE)
	var/mob/living/human/S = new /mob/living/human(locate(30, 32, 1))
	var/sunny = S.feels_like_temperature(25)
	fl_check(sunny == 28, "a clear afternoon sun adds 3 C ([sunny])")
	S.equip_to_slot_or_del(new /obj/item/clothing/head/sombrero(S), slot_head)
	var/hatted = S.feels_like_temperature(25)
	S.equip_to_slot_or_del(new /obj/item/clothing/suit/arabic_robe(S), slot_wear_suit)
	var/robed = S.feels_like_temperature(25)
	fl_check(hatted < sunny && robed == 25, "a brimmed hat shades it and a robe with it shades it all ([hatted], [robed])")
	var/datum/weather_air_grid/G = weather_air
	for (var/i = 1, i <= G.temp.len, i++)
		G.temp[i] = 33
		G.dew[i] = 27
	var/list/parts = feels_like_parts(locate(30, 32, 1), 33)
	fl_check(parts[2] > 5, "muggy air adds its heat index ([parts[2]])")
	var/humid_robed = S.feels_like_temperature(33)
	S.unEquip(S.wear_suit)
	var/humid_hatted = S.feels_like_temperature(33)
	fl_check(humid_robed < humid_hatted, "a loose robe lets some of the humid heat out ([humid_robed] vs [humid_hatted])")
