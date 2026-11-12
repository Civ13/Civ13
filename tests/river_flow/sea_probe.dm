// Native probe for sea currents and swimming: tiring, drowning, rest, and what drifts.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/sea_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/sea_probe/New()
	return
/mob/living/human/sea_probe/update_icons()
	return
/mob/living/human/sea_probe/New()
	species = new /datum/species/human
	return
var/sea_failures = 0
var/sea_runtime_error = FALSE
/proc/sea_check(condition, label)
	if (!condition)
		sea_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sea_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/sea_probe
		sea_checks()
	catch(var/exception/e)
		sea_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sea_failures, "runtime_error" = sea_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/sea_checks()
	for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	// Rows 10 to 30 are deep sea; row 20 carries a current east.
	for (var/turf/T in block(locate(1, 10, 1), locate(40, 30, 1)))
		T.ChangeTurf(/turf/floor/beach/water/deep/saltwater, FALSE, FALSE)
	var/datum/river_flow/flow = new
	flow.z_level = 1
	for (var/y = 40, y >= 1, y--)
		flow.rows += (y == 20) ? "..eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee.." : "........................................"
	map.river_flow_cache = flow
	map.river_flow_loaded = TRUE
	var/turf/floor/beach/water/deep/sea = locate(10, 20, 1)
	var/turf/calm = locate(10, 25, 1)
	var/turf/shore = locate(10, 5, 1)
	sea_check(river_current_direction(sea) == EAST && !river_current_direction(calm), "the fixture sea has one current")

	// Who may swim.
	var/mob/living/human/sea_probe/H = new(shore)
	map.nomads = TRUE
	sea_check(!H.can_swim_deep() && !calm.CanPass(H), "a person with nobody behind them keeps out of deep water")
	agent_characters[H] = new /datum/agent_character
	sea_check(H.can_swim_deep() && calm.CanPass(H), "a played person may swim out of their depth")
	map.nomads = FALSE
	sea_check(!calm.CanPass(H), "battle maps keep deep water closed")
	map.nomads = TRUE

	// Tiring, drowning and rest.
	H.loc = calm
	H.handle_drowning()
	sea_check(!H.drowning && H.water_overlay && H.swim_tiredness == 4 && H.getOxyLoss() == 0, "a fresh swimmer stays afloat")
	var/ticks = 1
	while (!H.drowning && ticks < 100)
		H.handle_drowning()
		ticks++
	sea_check(ticks == 25 && H.drowning && H.getOxyLoss() > 0, "a swimmer goes under after 25 life ticks of calm water ([ticks])")
	H.loc = shore
	H.handle_drowning()
	sea_check(!H.drowning && H.swim_tiredness == 92, "rest on land brings strength back")
	for (var/i = 1, i <= 20, i++)
		H.handle_drowning()
	sea_check(H.swim_tiredness == 0, "a rested swimmer is fresh again")
	H.adjustOxyLoss(-200)

	// A storm sea is twice the work.
	sea_check(swim_effort_at(calm) == 4, "calm water costs 4 a tick")
	var/area/caribbean/sky = new
	sky.climate = "temperate"
	sky.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
		sky.contents += T
	var/datum/weather_system/storm = weather_system_spawn(WEATHER_SYSTEM_STORM, TRUE, 10, 25)
	storm.origin_x = 10
	storm.origin_y = 25
	storm.origin_time = world.time
	storm.born = world.time - 3000
	storm.peak = 1
	weather_sample_time = -1
	sea_check(swim_effort_at(calm) == 8, "a storm sea costs 8 a tick ([swim_effort_at(calm)])")
	weather_systems_clear()

	// The current carries a swimmer, an item and an empty raft, not a manned one.
	H.loc = sea
	var/obj/structure/vehicle/raft/empty = new(locate(12, 20, 1))
	var/obj/structure/vehicle/raft/manned = new(locate(14, 20, 1))
	var/mob/living/human/sea_probe/rider = new(locate(14, 20, 1))
	manned.ontop += rider
	sea_check(river_adrift(empty) && !river_adrift(manned), "only an empty raft is adrift")
	river_moved.Cut()
	for (var/x in list(14, 12, 10))
		var/turf/floor/beach/water/W = locate(x, 20, 1)
		W.river_current_step()
	sea_check(H.loc == locate(11, 20, 1), "the sea current carries a swimmer")
	sea_check(empty.loc == locate(13, 20, 1), "the sea current carries an empty raft")
	sea_check(manned.loc == locate(14, 20, 1), "a manned raft holds its place")
	// Sea ice holds what lies on it.
	var/turf/frozen = locate(20, 20, 1)
	frozen = frozen.ChangeTurf(/turf/floor/beach/water/ice/salty, FALSE, FALSE)
	sea_check(!river_current_direction(frozen), "no current moves things on sea ice")
