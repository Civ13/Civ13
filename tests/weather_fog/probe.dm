// Native probe for fog, mist, dew and frost (docs/weather-fog.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_fog/probe.dm
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
/obj/map_metadata/wg_probe/New()
	return
/area/caribbean/wg_probe
var/wg_failures = 0
var/wg_runtime_error = FALSE
/proc/wg_check(condition, label)
	if (!condition)
		wg_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wg_runtime_error = TRUE
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
		map = new /obj/map_metadata/wg_probe
		wg_checks()
	catch(var/exception/e)
		wg_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wg_failures, "runtime_error" = wg_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wg_area(climate, x1, x2, location = AREA_OUTSIDE)
	var/area/caribbean/wg_probe/A = new
	A.climate = climate
	A.location = location
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

// The air settled straight to the hour, and a few ticks more.
/proc/wg_settle(ticks = 0)
	weather_air.settle(TRUE)
	for (var/i = 1, i <= ticks, i++)
		weather_air.settle()
	weather_sample_time = -1

/proc/wg_checks()
	season = "SPRING"
	time_of_day = "Early Morning"
	map.winddirection = "West"
	map.windspeedvar = 0
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	wg_area("temperate", 1, 64)
	wg_area("desert", 65, 96)
	var/turf/field = locate(24, 32, 1)
	var/turf/sand = locate(88, 32, 1)
	weather_centres_clear()
	weather_systems_clear()
	weather_storm_count = 0

	// Before the air grid exists there is no fog, and nothing breaks.
	weather_air = null
	wg_check(weather_fog_at(field) == 0 && weather_fog_level(field) == "" && !weather_frost_at(field) && !weather_dew_at(field), "no grid, no fog")

	// A clear, calm spring dawn: the air cools to its dew point.
	var/datum/weather_air_grid/G = weather_air_grid()
	wg_settle()
	wg_check(weather_humidity_at(field) > 97, "at dawn the air reaches saturation ([weather_humidity_at(field)]%)")
	wg_check(weather_cloud_at(field) < 0.1, "and lies on the ground, not in the sky ([weather_cloud_at(field)])")
	wg_check(weather_fog_level(field) == "fog", "a clear, calm dawn brings fog ([weather_fog_at(field)])")
	wg_check(weather_fog_level(sand) == "", "but the dry desert stays clear ([weather_fog_at(sand)])")
	wg_check(weather_dew_at(field) && !weather_frost_at(field), "dew lies on the grass above freezing")

	// The afternoon is drier than the mean, and the sun burns the fog off.
	time_of_day = "Midday"
	weather_air.settle()
	var/first = weather_fog_at(field)
	wg_check(first > 0.5 && first < 1, "the fog thins gradually, not at once ([first])")
	wg_settle(40)
	wg_check(weather_fog_level(field) == "" && !weather_dew_at(field), "by midday it has burned off")

	// A breeze keeps it from forming; a light one leaves mist.
	time_of_day = "Early Morning"
	map.windspeedvar = 2
	wg_settle()
	wg_check(weather_fog_level(field) == "", "a fresh breeze keeps the fog away ([weather_fog_at(field)])")
	map.windspeedvar = 1
	wg_settle()
	wg_check(weather_fog_level(field) == "mist", "a light air leaves mist ([weather_fog_at(field)])")
	map.windspeedvar = 0

	// Rain washes it out.
	var/datum/weather_system/S = weather_system_spawn(WEATHER_SYSTEM_STORM, FALSE, 24, 32)
	S.origin_x = 24
	S.origin_y = 32
	S.origin_time = world.time
	S.vel_x = 0
	S.vel_y = 0
	S.radius_x = 50
	S.radius_y = 50
	S.peak = 1
	S.born = world.time - 6000
	S.lifetime = 60000
	wg_settle()
	wg_check(weather_fog_level(field) == "" && !weather_dew_at(field), "no fog or dew under the rain ([weather_fog_at(field)])")
	weather_system_end(S)

	// Valleys fill first.
	wg_settle()
	var/i = G.index(1, 2)
	var/flat = G.fog_target(i)
	G.temp[i] = G.dew[i] + 1.2
	var/thin = G.fog_target(i)
	for (var/row = 0, row < G.rows, row++)
		for (var/col = 0, col < G.cols, col++)
			G.heights[G.index(col, row)] = abs(col - 1) * 3
	G.survey_wind()
	wg_check(flat >= 0.99 && G.fog_target(i) > thin + 0.2, "a valley holds thicker fog than open ground ([thin] -> [G.fog_target(i)])")
	for (var/k = 1, k <= G.heights.len, k++)
		G.heights[k] = 0
	G.survey_wind()

	// Sea fog along the shore.
	time_of_day = "Afternoon"
	for (var/row = 0, row < G.rows, row++)
		G.water[G.index(0, row)] = TRUE
	G.survey_wind()
	wg_settle()
	var/w = G.index(0, 2)
	G.temp[w] = 14
	G.dew[w] = 13.8
	wg_check(G.fog_target(w) > 0.3, "near-saturated air over the water makes sea fog even by day ([G.fog_target(w)])")
	G.temp[w] = 14
	G.dew[w] = 9
	wg_check(G.fog_target(w) == 0, "drier sea air does not ([G.fog_target(w)])")
	for (var/row = 0, row < G.rows, row++)
		G.water[G.index(0, row)] = FALSE
	G.survey_wind()

	// Frost on a winter dawn.
	season = "WINTER"
	time_of_day = "Early Morning"
	wg_settle()
	wg_check(weather_frost_at(field) && !weather_dew_at(field), "a clear winter dawn is frosty ([weather_precip_temp(field)] C)")
	time_of_day = "Afternoon"
	wg_settle()
	wg_check(!weather_frost_at(field), "and the frost has gone by afternoon")
	season = "SPRING"

	// Indoors, none of it.
	time_of_day = "Early Morning"
	wg_area("temperate", 30, 34, AREA_INSIDE)
	wg_settle()
	var/turf/hall = locate(32, 32, 1)
	wg_check(weather_fog_level(field) == "fog" && weather_fog_at(hall) == 0 && !weather_dew_at(hall), "no fog or dew under a roof")

	// What fog does.
	var/list/alphas = weather_fog_view_alphas(1)
	wg_check(alphas[1] == 255 && alphas[2] == 255, "thick fog draws both hazes")
	alphas = weather_fog_view_alphas(0.4)
	wg_check(alphas[1] > 0 && alphas[2] == 0, "mist only the light one")
	alphas = weather_fog_view_alphas(0.1)
	wg_check(!alphas[1] && !alphas[2], "a trace none")
	var/list/states = icon_states('icons/effects/weather_fog.dmi')
	wg_check(("fog_view" in states) && ("mist_view" in states), "the haze has its art")
	wg_check(sea_murk_at(field) >= 25 && sea_murk_name(field) == "fog", "fog takes from a lookout's range ([sea_murk_at(field)])")
	var/mob/living/human/H = new /mob/living/human(field)
	var/list/find = find_weather(H)
	wg_check(find && find[1] == "weather:fog:spring", "a naturalist can record the fog ([find ? find[1] : "nothing"])")
	var/list/data = weather_air_map_data()
	wg_check(data.len == 10 && length(data[10]) == G.cols * G.rows, "the Admin Map gets each cell's fog")

	// Dew collects in an open barrel.
	var/obj/item/weapon/reagent_containers/glass/barrel/B = new(locate(20, 20, 1))
	B.flags |= OPENCONTAINER
	wg_check(B.collection_rate() >= 2, "an open barrel catches dew out of the fog ([B.collection_rate()])")
	time_of_day = "Midday"
	wg_settle()
	wg_check(B.collection_rate() == 0, "but none by day")
