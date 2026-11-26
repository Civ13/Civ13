// Native probe for lows, highs and fronts (docs/weather-fronts.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_fronts/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 96
	maxy = 64
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wf_probe/New()
	return
/area/caribbean/wf_probe
var/wf_failures = 0
var/wf_runtime_error = FALSE
/proc/wf_check(condition, label)
	if (!condition)
		wf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		movementMachine = new
		map = new /obj/map_metadata/wf_probe
		wf_checks()
		wf_tornado_checks()
	catch(var/exception/e)
		wf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wf_failures, "runtime_error" = wf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wf_area(climate, x1, x2)
	var/area/caribbean/wf_probe/A = new
	A.climate = climate
	A.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

/proc/wf_still(datum/weather_centre/C, x, y)
	C.origin_x = x
	C.origin_y = y
	C.origin_time = world.time
	C.vel_x = 0.01
	C.vel_y = 0
	C.born = world.time - 6000
	C.lifetime = 30000

/proc/wf_checks()
	season = "SPRING"
	time_of_day = "Morning"
	map.winddirection = "West"
	map.windspeedvar = 1
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	wf_area("temperate", 1, 96)
	weather_air = null
	weather_air_grid()

	// A low pulls the pressure down round it, a high pushes it up.
	var/datum/weather_centre/L = weather_centre_spawn(WEATHER_CENTRE_LOW)
	wf_check(L && L.kind == WEATHER_CENTRE_LOW, "a low can form")
	wf_check(L.vel_x > 0 && L.vel_y == 0, "it drifts with a west wind")
	wf_check(L.centre_x() <= 1, "it forms on the upwind edge ([L.centre_x()])")
	wf_still(L, 48, 32)
	L.depth = 20
	L.radius = 60
	wf_check(abs(weather_centres_pressure_at(48, 32) + 20) < 0.01, "its heart is 20 hPa low")
	wf_check(weather_centres_pressure_at(90, 32) > weather_centres_pressure_at(60, 32), "pressure recovers away from it")
	wf_check(weather_centres_temperature_at(70, 32) > 0 && weather_centres_temperature_at(26, 32) < 0, "warm air ahead of a low, cold air behind its front")
	wf_check(weather_centres_temperature_at(48, 32) == 0, "no front at its heart")
	for (var/i = 1, i <= 60, i++)
		weather_air.settle()
	wf_check(weather_pressure_at(locate(48, 32, 1)) < 1000, "the air grid feels the low ([weather_pressure_at(locate(48, 32, 1))] hPa)")
	wf_check(weather_air_temp_at(locate(20, 32, 1)) < weather_air_temp_at(locate(76, 32, 1)), "and is colder behind it than ahead")

	// A rolled storm forms on the low's front, not on a random spot.
	var/list/fronts = list()
	for (var/i = 1, i <= 20, i++)
		fronts += list(L.front_point())
	var/near = TRUE
	for (var/list/P in fronts)
		if (abs(P[1] - (48 + 24)) > 2 || abs(P[2] - 32) > 31)
			near = FALSE
	wf_check(near, "front points lie ahead of the low, across its course")
	weather_storm_count = 0
	weather_systems.Cut()
	var/datum/weather_system/S = weather_front_storm(FALSE)
	wf_check(S && S.kind == WEATHER_SYSTEM_STORM, "a roll sends a storm along the low")
	var/aim_ok = FALSE
	for (var/t = 0, t <= 40000, t += 100)
		var/sx = S.origin_x + S.vel_x * t
		if (abs(sx - 72) <= 3)
			aim_ok = abs((S.origin_y + S.vel_y * t) - 32) <= 31
			break
	wf_check(aim_ok, "its path crosses the front")
	weather_system_end(S)
	L.depth = 30
	var/severe = 0
	for (var/i = 1, i <= 40, i++)
		var/datum/weather_system/D = weather_front_storm(FALSE)
		if (D)
			if (D.severe)
				severe++
			weather_system_end(D)
	wf_check(severe > 0 && severe < 40, "a deep low sometimes makes a storm severe ([severe]/40)")

	// With no low about, a roll brings one.
	weather_centres_clear()
	S = weather_front_storm(TRUE)
	wf_check(S && S.severe && weather_deepest_low(), "a roll with no low forms one to carry the storm")
	weather_system_end(S)

	// Highs, seasons and the step.
	weather_centres_clear()
	var/datum/weather_centre/H = weather_centre_spawn(WEATHER_CENTRE_HIGH)
	wf_still(H, 48, 32)
	H.depth = 15
	wf_check(abs(weather_centres_pressure_at(48, 32) - 15) < 0.01 && weather_centres_temperature_at(70, 32) == 0, "a high raises the pressure and brings no front")
	season = "SUMMER"
	wf_check(weather_centre_low_chance() < 50, "summer favours highs")
	season = "WINTER"
	wf_check(weather_centre_low_chance() > 50, "winter favours lows")
	weather_centres_clear()
	weather_centres_step()
	wf_check(weather_centres.len == 1, "the weather tick forms a centre when the sky has none")
	for (var/i = 1, i <= 2000, i++)
		weather_centres_step()
	wf_check(weather_centres.len <= 3, "never more than three centres ([weather_centres.len])")
	map.valid_weather_types = list(WEATHER_NONE)
	weather_centres_clear()
	weather_centres_step()
	wf_check(!weather_centres.len, "a map without rain forms no centres")
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	var/datum/weather_centre/old = weather_centre_spawn(WEATHER_CENTRE_LOW)
	old.born = world.time - old.lifetime
	weather_centres_step()
	wf_check(!(old in weather_centres), "a spent centre is retired")

	// Thunderstorms build on hot, humid afternoons, in place.
	weather_centres_clear()
	weather_systems.Cut()
	weather_storm_count = 0
	season = "SUMMER"
	time_of_day = "Afternoon"
	var/datum/weather_air_grid/G = weather_air
	for (var/i = 1, i <= G.temp.len, i++)
		G.temp[i] = 20
		G.dew[i] = 10
		G.cloud[i] = 0
	G.temp[8] = 32
	G.dew[8] = 26
	var/formed = null
	for (var/i = 1, i <= 400 && !formed, i++)
		weather_convection_step()
		if (weather_systems.len)
			formed = weather_systems[1]
	wf_check(formed, "a hot humid cell throws up a thunderstorm")
	if (formed)
		var/datum/weather_system/T = formed
		wf_check(abs(T.centre_x() - 24) <= 1 && abs(T.centre_y() - 24) <= 1, "over that cell ([T.centre_x()], [T.centre_y()])")
		wf_check(T.radius_x <= 32 && T.lifetime <= 12000 && T.severe, "small, short and severe in air this hot and wet")
		weather_system_end(T)
	time_of_day = "Night"
	for (var/i = 1, i <= 200, i++)
		weather_convection_step()
	wf_check(!weather_systems.len, "no thunderstorms build at night")
	time_of_day = "Afternoon"
	G.temp[8] = 20
	for (var/i = 1, i <= 200, i++)
		weather_convection_step()
	wf_check(!weather_systems.len, "nor in cool air")

	// The weather map sees them.
	weather_centre_spawn(WEATHER_CENTRE_LOW)
	var/list/data = weather_centres_map_data()
	wf_check(data.len == 1 && data[1][2] == "low", "the weather map lists the centres")

/obj/roof/thatch/wf_test/New()
	return

/mob/living/wf_tornado_fixture/New(newloc)
	loc = newloc
	status_flags |= CANWEAKEN

/proc/wf_tornado_checks()
	weather_systems_clear()
	map.persistence = TRUE
	map.underground_compiled_z = 2
	underground_levels_refresh()
	wf_area("temperate", 1, 96)
	for (var/turf/T in block(locate(50, 22, 1), locate(80, 38, 1)))
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/datum/weather_air_grid/G = weather_air
	for (var/i in 1 to G.temp.len)
		G.temp[i] = 27
		G.dew[i] = 18
		G.wind_x[i] = 3
		G.wind_y[i] = 8

	var/datum/weather_system/S = weather_convective_storm(60, 30, TRUE)
	S.set_course(0.02, 0)
	S.born = world.time - 1200
	var/turf/forming = locate(69, 30, 1)
	wf_check(S.strength_at(69, 30) >= WEATHER_BAND_HEAVY && weather_tornado_shear(S, forming) < 0, "strong mature moist convection with crosswind shear qualifies")
	var/area/formation_area = forming.loc
	formation_area.climate = "desert"
	wf_check(!weather_tornado_shear(S, forming), "an extreme sand sky does not qualify even with warm air and shear")
	formation_area.climate = "temperate"
	var/list/surface = weather_wind_vector_at(forming)
	var/list/gusting = weather_effective_wind_vector_at(forming)
	wf_check(surface[1] == 3 && surface[2] == 8 && (gusting[1] != surface[1] || gusting[2] != surface[2]), "a severe gust changes the effective vector without feeding it into environmental shear")
	S.convective = FALSE
	wf_check(!weather_tornado_shear(S, forming), "ordinary severe fronts and non-convective storms cannot qualify")
	S.convective = TRUE
	S.severe = FALSE
	wf_check(!weather_tornado_shear(S, forming), "ordinary thunderstorms cannot qualify")
	S.severe = TRUE
	for (var/i in 1 to G.temp.len)
		G.dew[i] = 10
	wf_check(!weather_tornado_shear(S, forming), "dry air cannot qualify")
	for (var/i in 1 to G.temp.len)
		G.dew[i] = 18
		G.wind_x[i] = 15
		G.wind_y[i] = 0
	wf_check(!weather_tornado_shear(S, forming), "uniform winds without shear cannot qualify")
	for (var/i in 1 to G.temp.len)
		G.wind_x[i] = 3
		G.wind_y[i] = 8
	var/turf/water = locate(69, 31, 1)
	water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	wf_check(!weather_tornado_shear(S, water), "does not form over water")
	water.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	map.weather_transitions = list("ANY" = list("WET"))
	weather_tornado_consider(0)
	wf_check(!S.tornado_support, "map policy can disallow extremes")
	map.weather_transitions = null
	weather_tornado_consider(0)
	weather_tornado_consider(0)
	wf_check(!weather_tornado && S.tornado_support == 2, "two qualifying samples cannot spawn a tornado")
	weather_tornado_consider(99)
	wf_check(!weather_tornado && S.tornado_support == 3, "sustained support is not a guaranteed spawn")
	weather_tornado_consider(0)
	var/datum/weather_tornado/V = weather_tornado
	wf_check(V && V.parent_storm == S && V.landfall - world.time == 450 && S.tornado_spawned, "one storm-owned funnel forms with a 45-second lead")
	if (!V)
		return
	wf_check(!V.should_save, "the active tornado is not a saved world object")
	wf_check(V.threatens(forming, world.time) && !V.threatens(locate(69, 38, 1), world.time) && !V.threatens(locate(69, 30, 2), world.time), "warns on the corridor but not eight tiles sideways or below ground")
	wf_check(!V.gust(forming, world.time), "the warning phase has no impact gust")
	var/active_at = V.landfall + 200
	// Keep the parent over the test during this injected future step.
	S.origin_x = 71
	S.origin_y = 30
	S.origin_time = world.time
	var/turf/upper = locate(73, 32, 1)
	var/turf/lower = locate(73, 28, 1)
	var/list/up_wind = V.gust(upper, active_at)
	var/list/down_wind = V.gust(lower, active_at)
	wf_check(up_wind && down_wind && up_wind[1] * down_wind[1] < 0, "opposite sides of the funnel blow in opposite directions")

	var/area/caribbean/wf_probe/inside = new
	inside.location = AREA_INSIDE
	var/turf/protected = locate(71, 30, 1)
	inside.contents += protected
	wf_check(!weather_tornado_sheltered(protected), "a roof alone does not shelter")
	for (var/direction in cardinal)
		var/turf/boundary = get_step(protected, direction)
		boundary.ChangeTurf(/turf/wall, FALSE, FALSE)
	wf_check(weather_tornado_sheltered(protected) && V.gust(protected, active_at), "four sealed walls and a roof give shelter inside the active gust")
	wf_check(weather_tornado_sheltered(locate(73, 30, 2)), "compiled underground terrain is sheltered even with an outdoor area flag")
	var/obj/item/loose = new(lower)
	loose.w_class = ITEM_SIZE_SMALL
	var/obj/item/heavy = new(lower)
	heavy.w_class = ITEM_SIZE_LARGE
	var/obj/item/anchored_item = new(lower)
	anchored_item.w_class = ITEM_SIZE_SMALL
	anchored_item.anchored = TRUE
	var/mob/living/wf_tornado_fixture/exposed = new(upper)
	var/mob/living/wf_tornado_fixture/covered = new(protected)
	var/obj/structure/farming/plant/crop = new(lower)
	var/obj/roof/thatch/wf_test/roof = new(upper)

	weather_tornado_step(V.landfall - 1)
	wf_check(!exposed.weakened && loose.loc == lower && roof.health == 100, "warning phase does not move or damage anything")
	weather_tornado_step(active_at)
	wf_check(exposed.weakened == 2 && exposed.loc != upper, "gust moves and weakens the exposed mob (moved [exposed.loc != upper], weakened [exposed.weakened])")
	wf_check(loose.loc != lower, "gust displaces small loose debris along a clear route")
	wf_check(!covered.weakened && covered.loc == protected && anchored_item.loc == lower && heavy.loc == lower, "sheltered player, anchored item and heavy item stay untouched")
	wf_check(crop.stage > crop.readyStageMax && roof.health == 92, "strong gusts batter crops and damage light roofs without collapse")
	weather_tornado_step(active_at)
	wf_check(roof.health == 92, "the same track does not repeatedly damage the same roof")
	var/turf/gap = get_step(protected, WEST)
	gap.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	wf_check(!weather_tornado_sheltered(protected), "an opening removes protection immediately")
	weather_system_end(S)
	wf_check(!weather_tornado && weather_tornado_cooldown_until > world.time, "removing the parent immediately cleans up the funnel but keeps cooldown")

	S = weather_convective_storm(73, 30, TRUE)
	S.born = world.time - 1200
	V = weather_tornado_form(S, locate(75, 30, 1), 4)
	persistence_save_in_progress = TRUE
	weather_tornado_step(V.landfall)
	persistence_save_in_progress = FALSE
	wf_check(!weather_tornado, "a persistence hold dissipates the tornado rather than replaying impacts after a save")
	weather_systems_clear()
	wf_check(!weather_tornado && !weather_tornado_cooldown_until, "clearing the sky also clears the tornado cooldown")
