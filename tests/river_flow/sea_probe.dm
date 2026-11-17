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

	// Tiring, drowning and rest. (The first-swim lesson would raise the skill
	// a little; the training checks below cover it.)
	H.swim_kind_lessons = list("sea" = world.time)
	H.loc = calm
	H.handle_drowning()
	sea_check(!H.drowning && H.water_overlay && H.swim_tiredness == 2 && H.getOxyLoss() == 0, "a fresh swimmer stays afloat")
	var/ticks = 1
	while (!H.drowning && ticks < 100)
		H.handle_drowning()
		ticks++
	sea_check(ticks == 50 && H.drowning && H.swim_under && H.getOxyLoss() == 0, "a swimmer goes under after 50 life ticks of calm water and holds their breath ([ticks])")
	var/held = 1
	while (!H.getOxyLoss() && held < 100)
		H.handle_drowning()
		held++
	sea_check(held == 10, "an unskilled swimmer holds their breath for 10 seconds ([held])")
	H.loc = shore
	H.handle_drowning()
	sea_check(!H.drowning && H.swim_tiredness == 96, "rest on land brings strength back")
	for (var/i = 1, i <= 30, i++)
		H.handle_drowning()
	sea_check(H.swim_tiredness == 0 && !H.swim_under && H.swim_breath < 0, "a rested swimmer is fresh again, breath and all")
	H.adjustOxyLoss(-200)

	// A dropped connection: the body treads water, then is washed ashore.
	agent_characters -= H
	H.persistence_owner_ckey = "seaprobe"
	sea_check(!H.can_swim_deep() && !calm.CanPass(H), "an absent player's body on land keeps out of deep water")
	H.loc = calm
	H.handle_drowning()
	sea_check(!H.drowning && H.swim_tiredness == 0 && H.swim_grace_until == world.time + 1200 && H.can_swim_deep(), "a swimmer whose player dropped treads water without tiring")
	for (var/i = 1, i <= 80, i++)
		H.handle_drowning()
	sea_check(!H.drowning && !H.swim_under && H.swim_tiredness == 0 && !H.getOxyLoss() && H.loc == calm, "eighty seconds on, still afloat and fresh")
	H.swim_grace_until = world.time - 1
	H.handle_drowning()
	var/turf/washed = get_turf(H)
	sea_check(!istype(washed, /turf/floor/beach/water/deep) && washed.x == 10 && washed.y == 31 && H.swim_tiredness == 99 && !H.getOxyLoss(), "when the grace ends the sea carries them to the nearest shore, spent ([washed.x],[washed.y])")
	H.handle_drowning()
	sea_check(!H.drowning, "washed ashore, they rest")
	H.loc = calm
	H.handle_drowning()
	sea_check(H.drowning && !H.swim_grace_until, "the grace does not come twice within ten minutes")
	H.swim_under = FALSE
	H.swim_breath = -1
	H.swim_tiredness = 0
	H.swim_grace_next = 0
	H.stat = UNCONSCIOUS
	H.handle_drowning()
	sea_check(H.drowning && !H.swim_grace_until, "an unconscious body gets no grace")
	H.stat = CONSCIOUS
	H.persistence_owner_ckey = null
	H.handle_drowning()
	sea_check(H.drowning && !H.swim_grace_until, "a body nobody owns gets none either")
	H.loc = shore
	H.drowning = FALSE
	H.swim_under = FALSE
	H.swim_breath = -1
	H.swim_tiredness = 0
	H.adjustOxyLoss(-200)
	agent_characters[H] = new /datum/agent_character

	// The swimming skill: endurance, speed, breath and recovery.
	sea_check(H.swimming_skill() == 100 && H.swim_breath_max() == 10, "a new swimmer has skill 100 and 10 seconds of breath ([H.swimming_skill()] [json_encode(H.stats["swimming"])] [H.water_step_delay(calm)])")
	sea_check(H.water_step_delay(calm) == 20 && H.water_step_delay(shore) == 0, "an unskilled swimmer pays 20 ds a deep-water step")
	H.stats["swimming"] = list(200, 200)
	sea_check(H.water_step_delay(calm) == 10 && abs(H.swim_breath_max() - 130 / 3) < 0.01, "skill 200 halves the step and holds about 43 seconds of breath")
	H.stats["swimming"] = list(250, 250)
	sea_check(H.water_step_delay(calm) == 8 && H.swim_breath_max() == 60, "skill 250 reaches the 8 ds floor and 60 seconds of breath")
	H.stats["swimming"] = list(400, 400)
	sea_check(H.swimming_skill() == 250, "the skill reads no higher than 250")
	H.stats["swimming"] = list(200, 200)
	H.loc = calm
	ticks = 0
	while (!H.swim_under && ticks < 300)
		H.handle_drowning()
		ticks++
	sea_check(ticks == 100, "a skill-200 swimmer stays afloat 100 seconds in calm water ([ticks])")
	H.loc = shore
	for (var/i = 1, i <= 13, i++)
		H.handle_drowning()
	sea_check(H.swim_tiredness == 0 && H.swim_breath < 0, "a skill-200 swimmer rests twice as fast")
	H.adjustOxyLoss(-200)
	var/obj/item/clothing/suit/heavy = new
	heavy.slowdown = 2
	H.wear_suit = heavy
	sea_check(H.swim_effort_for(calm) == 2, "a heavy suit adds to the effort of swimming")
	H.wear_suit = null
	qdel(heavy)
	H.stats["swimming"] = list(100, 100)

	// Training: new water teaches; the same few tiles and the first swim do not repeat.
	H.swim_kind_lessons = null
	H.swim_recent = null
	H.swim_new_tiles = 0
	var/start = H.stats["swimming"][1]
	H.swim_train(calm)
	var/after_first = H.stats["swimming"][1]
	sea_check(after_first > start, "the first swim in the sea teaches something ([start] -> [after_first])")
	for (var/i = 1, i <= 30, i++)
		H.swim_train(i % 2 ? calm : locate(11, 25, 1))
	sea_check(H.stats["swimming"][1] == after_first, "paddling over the same two tiles teaches nothing")
	for (var/x = 1, x <= 20, x++)
		H.swim_train(locate(x, 15, 1))
	sea_check(H.stats["swimming"][1] > after_first, "twenty tiles of new water teach two lessons ([H.stats["swimming"][1]])")
	agent_characters -= H
	var/before_idle = H.stats["swimming"][1]
	for (var/x = 1, x <= 20, x++)
		H.swim_train(locate(x, 16, 1))
	sea_check(H.stats["swimming"][1] == before_idle, "nobody playing the character, nothing learned")
	agent_characters[H] = new /datum/agent_character
	sea_check(skill_mastery_disciplines["swimming"] == "natural_science" && ("swimming" in skill_master_stats), "swimming mastery pays Natural Science and a better swimmer can teach")
	H.stats["swimming"] = list(100, 100)
	H.swim_tiredness = 0

	// A storm sea is twice the work.
	sea_check(swim_effort_at(calm) == 2, "calm water costs 2 a tick")
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
	sea_check(swim_effort_at(calm) == 4, "a storm sea costs 4 a tick ([swim_effort_at(calm)])")
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

	// Flow lines: flowing water wears them, still water and ice do not.
	var/turf/lined = locate(30, 20, 1)
	var/image/line = water_flow_image(lined)
	sea_check(line && findtext(line.icon_state, "flow_east") == 1 && line.plane == FLOOR_PLANE && !line.mouse_opacity, "flowing sea has an eastward flow line")
	sea_check(icon_states('icons/turf/water_flow.dmi').Find(line.icon_state), "the flow line state exists in the icon")
	sea_check(water_flow_image(locate(31, 20, 1)) != line && water_flow_image(locate(32, 20, 1)) == line, "neighbouring tiles alternate two shared images")
	var/bare = lined.overlays.len
	lined.terrain_shade_refresh()
	sea_check(lined.terrain_shade_overlay == line && lined.overlays.len == bare + 1, "the turf wears its flow line")
	lined.terrain_shade_icon()
	lined.terrain_shade_refresh()
	sea_check(lined.overlays.len == bare + 1, "an icon rebuild or a refresh keeps one flow line")
	sea_check(isnull(water_flow_image(calm)) && isnull(water_flow_image(frozen)), "still water and ice have no flow line")
	calm.terrain_shade_refresh()
	sea_check(isnull(calm.terrain_shade_overlay), "still water wears nothing")

