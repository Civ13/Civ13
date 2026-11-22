// Native probe for river stages and flood depth (river_flood.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/flood_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/flood_probe/New()
	return
var/flood_failures = 0
var/flood_runtime_error = FALSE
/proc/flood_check(condition, label)
	if (!condition)
		flood_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	flood_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/flood_probe
		flood_checks()
	catch(var/exception/e)
		flood_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = flood_failures, "runtime_error" = flood_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Two reaches: reach 1 (west half of the middle row) drains into reach 2
// (east half), which drains away. North row: banks at 0.5, 1, 2 and behind a
// ridge; south row belongs to no reach.
/proc/flood_probe_text(down1 = 2, cut = FALSE)
	var/list/lines = list("civ13-river-flood 1", "size 6 3", "z 1", "reaches 2", "r 1 [down1] 2 2 30 30 3", "r 2 0 5 2 3000 3030 3")
	lines += list("010101020202", "010101020202", "000000000000")
	if (!cut)
		lines += list("A12d..", "......", "......")
	return jointext(lines, "\n")

/proc/flood_checks()
	var/datum/river_flood/F = river_flood_parse(flood_probe_text(), 6, 3, 1)
	flood_check(!F.error && F.count == 2 && F.down[1] == 2 && F.down[2] == 0, "parses reaches ([F.error])")
	flood_check(river_flood_parse(flood_probe_text(down1 = 1), 6, 3, 1).error, "rejects a reach draining upstream")
	flood_check(river_flood_parse(flood_probe_text(cut = TRUE), 6, 3, 1).error, "rejects a cut file")
	flood_check(river_flood_parse(flood_probe_text(), 7, 3, 1).error, "rejects the wrong size")
	flood_check(F.reach_at(1, 3) == 1 && F.reach_at(4, 3) == 2 && F.reach_at(1, 1) == 0, "reach ids per tile")
	flood_check(F.threshold_at(1, 3) == 0.5 && F.threshold_at(3, 3) == 2 && F.threshold_at(4, 3) == 13 && isnull(F.threshold_at(5, 3)), "thresholds in half levels")
	flood_check(F.stage[2] < 0 && F.stage[1] < 0 && F.stage[2] < F.stage[1], "dry-spell rivers sit below normal, big ones lower")
	// Ground at the thresholds: these banks rise from the river, not behind a ridge.
	var/datum/terrain_heights/H = new
	H.maxx = 6
	H.maxy = 3
	H.rows_by_z["1"] = list("A12d00", "000000", "000000")
	map.terrain_height_file = "probe"
	map.terrain_heights_cache = H
	map.river_flood_cache = F
	map.river_flood_loaded = TRUE
	map.river_flood_state = list()
	F.published = map.river_flood_state
	flood_check(flood_depth_at(locate(1, 3, 1)) == 0, "low bank dry at low water")

	// Raise reach 1 to stage 1.5.
	F.flow[1] = F.upstream[1] * 0.04 * (2 ** (1.5 / (1.2 * F.amplitude(1))))
	F.stage[1] = F.stage_for(1, F.flow[1])
	flood_check(abs(F.stage[1] - 1.5) < 0.001, "stage follows the flow")
	flood_check(abs(flood_depth_at(locate(1, 3, 1)) - 1) < 0.001 && abs(flood_depth_at(locate(2, 3, 1)) - 0.5) < 0.001 && flood_depth_at(locate(3, 3, 1)) == 0, "depth is stage above threshold")
	flood_check(flood_depth_at(locate(4, 3, 1)) == 0 && flood_depth_at(locate(1, 1, 1)) == 0, "ridge and sea-side land stay dry")
	flood_check(river_stage_at(locate(1, 2, 1)) == F.stage[1], "water tile reports its reach")

	// Effects (flood_effects.dm) at stage 1.5: 1 level on the low bank, 0.5 on the next.
	flood_check(flood_band(0) == FLOOD_BAND_NONE && flood_band(0.1) == FLOOD_BAND_ANKLE && flood_band(0.3) == FLOOD_BAND_KNEE && flood_band(0.5) == FLOOD_BAND_WAIST && flood_band(1) == FLOOD_BAND_WAIST && flood_band(1.5) == FLOOD_BAND_DEEP, "depth bands")
	flood_check(standing_water_delay(locate(1, 3, 1)) == 6 && standing_water_delay(locate(4, 3, 1)) == 0, "floodwater slows a step like deck water")
	flood_check(footwear_wet_ground(locate(2, 3, 1)) && !footwear_wet_ground(locate(3, 3, 1)), "floodwater wets the feet")
	var/obj/douse_probe = new /obj(locate(1, 3, 1))
	flood_check(flood_douses(douse_probe) && !flood_douses(new /obj(locate(4, 3, 1))), "fires go out under floodwater")
	flood_check(river_current_steps(locate(1, 2, 1)) == 2 && abs(river_current_power_factor(locate(1, 2, 1)) - 1.5) < 0.001, "a river in flood runs faster")
	F.stages_changed()
	flood_check(F.flooding && flood_anywhere(), "a reach above stage 0 counts as flooding")
	var/obj/item/weapon/reagent_containers/food/condiment/flour/sack = new(locate(1, 3, 1))
	var/obj/item/drifter = new /obj/item(locate(2, 3, 1))
	drifter.w_class = ITEM_SIZE_SMALL
	flood_items_at(locate(1, 3, 1), flood_band_at(locate(1, 3, 1)))
	flood_items_at(locate(2, 3, 1), flood_band_at(locate(2, 3, 1)))
	flood_check(QDELETED(sack) || !sack.reagents || !sack.reagents.total_volume, "floodwater ruins flour on the floor")
	flood_check(drifter.loc == locate(1, 3, 1), "small things float toward deeper water")
	drifter.Move(locate(2, 3, 1))
	flood_items_at(locate(2, 3, 1), FLOOD_BAND_WAIST)
	flood_check(drifter.loc == locate(2, 3, 1), "each tile is visited once per river tick")
	var/revision = flood_draw_revision
	var/s1 = F.stage[1]
	var/s2 = F.stage[2]
	F.stage[1] = -0.5
	F.stage[2] = 0
	F.stages_changed()
	flood_check(!F.flooding && flood_draw_revision == revision + 1 && flood_depth_at(locate(1, 3, 1)) == 0, "rivers at or below normal flood nothing")
	// Flood marks: the high-water mark stays after the river falls, and fades.
	F.peak[1] = 1.5
	flood_check(abs(flood_mark_at(locate(1, 3, 1)) - 1) < 0.001 && flood_mark_at(locate(4, 3, 1)) == 0, "flood marks show the last high water")
	flood_check(findtext(flood_mark_text(locate(1, 3, 1)), "waist height"), "flood mark text names the height")
	F.stage[1] = s1
	F.stage[2] = s2
	F.stages_changed()
	flood_check(flood_soaks(locate(1, 3, 1)) && !flood_soaks(locate(3, 3, 1)), "waist-deep floodwater soaks clothes")
	F.step_minute()
	flood_check(F.peak[1] >= F.stage[1] && F.peak[1] <= 1.5, "flood marks fade toward the water")
	F.flow[1] = F.upstream[1] * 0.04 * 1000
	flood_check(F.stage_for(1, F.flow[1]) == 3, "stage is capped at 3")

	// Water moves downstream and recedes without rain.
	season = "SUMMER"
	F.storage[1] = 500
	var/before = F.storage[2]
	F.step_minute()
	flood_check(F.storage[2] > before + 50, "released water reaches the next reach in the same minute")
	var/high = F.stage[2]
	for (var/i in 1 to 30)
		F.step_minute()
	flood_check(F.stage[2] < high, "rivers fall after the rain")

	// Snow waits for spring.
	season = "WINTER"
	F.snow[2] = 2000
	F.step_minute()
	flood_check(F.snow[2] == 2000, "no melt in winter")
	var/winter_flow = F.flow[2]
	season = "SPRING"
	F.step_minute()
	flood_check(F.snow[2] < 2000 && F.flow[2] > winter_flow * 2, "spring melts the snowpack into the river")

	// Saved water comes back, and a loaded save replaces the live water.
	var/list/state = F.snapshot()
	flood_check(state.len == 12 && state[1] == 2 && state[8] == 0, "snapshot holds every reach, then no hollows, then the foul and bed mercury loads")
	var/datum/river_flood/G = river_flood_parse(flood_probe_text(), 6, 3, 1)
	flood_check(G.restore(state) && abs(G.storage[1] - F.storage[1]) < 0.01 && abs(G.snow[2] - F.snow[2]) < 0.01 && abs(G.peak[1] - F.peak[1]) < 0.01, "restore round trip")
	flood_check(G.restore(list(2, 10, 10, 0, 0)) && G.peak[1] == G.stage[1], "saves without flood marks still load")
	flood_check(!G.restore(list(3, 1, 2)) && !G.restore(list(2, -1, 0, 0, 0)), "restore refuses another map's or negative water")
	map.river_flood_state = list(2, 0, 0, 0, 77)
	next_river_flood_tick = 0
	river_flood_step()
	flood_check(F.snow[2] < 77 && F.snow[2] > 70 && map.river_flood_state == F.published, "a loaded save's water is taken up on the next tick")
