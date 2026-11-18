// Native probe for rain pooling in hollows (flood_hollows.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/flood_hollow_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 6
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/flood_hollow_probe/New()
	return
var/hollow_failures = 0
var/hollow_runtime_error = FALSE
/proc/hollow_check(condition, label)
	if (!condition)
		hollow_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hollow_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/flood_hollow_probe
		hollow_checks()
	catch(var/exception/e)
		hollow_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hollow_failures, "runtime_error" = hollow_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A river along the south row; north of it a rim at level 3 around a basin at
// level 1 with one tile at 1.5. Ground outside the rim is at level 1.
/proc/hollow_heights()
	return list("11111111", "13333311", "13111311", "1311B311", "13333311", "00000000")

/proc/hollow_probe_text(hollow_lines = TRUE)
	var/list/lines = list("civ13-river-flood 2", "size 8 6", "z 1", "reaches 1", "r 1 0 4 1 40 40 8")
	for (var/r in 1 to 6)
		lines += "0101010101010101"
	lines += list("11111111", "13333311", "13333311", "13333311", "13333311", "........")
	if (hollow_lines)
		lines += list("hollows 1", "h 1 3 1 4 3 6 30 5,1,0,0", "hollow_rows 2")
		lines += list("3 0000010101000000", "4 0000010101000000")
	return jointext(lines, "\n")

/proc/hollow_checks()
	var/datum/terrain_heights/H = new
	H.maxx = 8
	H.maxy = 6
	H.rows_by_z["1"] = hollow_heights()
	map.terrain_height_file = "probe"
	map.terrain_heights_cache = H
	hollow_check(terrain_height_at(locate(5, 3, 1)) == 1.5 && terrain_height_at(locate(2, 4, 1)) == 3, "probe heights load")

	var/datum/river_flood/F = river_flood_parse(hollow_probe_text(), 8, 6, 1)
	hollow_check(!F.error && F.hollow_count == 1, "parses a hollow ([F.error])")
	hollow_check(F.hollow_at(3, 4) == 1 && F.hollow_at(5, 3) == 1 && F.hollow_at(2, 4) == 0 && F.hollow_at(3, 5) == 0, "hollow ids per tile")
	var/datum/river_flood/old = river_flood_parse(replacetext(hollow_probe_text(FALSE), "flood 2", "flood 1"), 8, 6, 1)
	hollow_check(!old.error && old.hollow_count == 0 && !old.hollow_at(3, 4), "a version 1 file has no hollows ([old.error])")
	hollow_check(river_flood_parse(replacetext(hollow_probe_text(), "5,1,0,0", "5,1"), 8, 6, 1).error, "rejects a hollow with the wrong height list")
	hollow_check(abs(F.hollow_capacity(1) - 11.5) < 0.001, "capacity to the spill ([F.hollow_capacity(1)])")
	hollow_check(abs(F.hollow_level_for(1, 2.5) - 1.5) < 0.001 && abs(F.hollow_level_for(1, 5.5) - 2) < 0.001 && F.hollow_level_for(1, 99) == 3, "the water stands level in the hollow")

	map.river_flood_cache = F
	map.river_flood_loaded = TRUE
	map.river_flood_state = list()
	F.published = map.river_flood_state
	F.stage[1] = 0
	hollow_check(!flood_depth_at(locate(3, 4, 1)), "a dry hollow is dry")
	F.restore_hollows(list(1, 2.5))
	hollow_check(abs(flood_depth_at(locate(3, 4, 1)) - 0.5) < 0.001 && !flood_depth_at(locate(5, 3, 1)) && !flood_depth_at(locate(2, 4, 1)), "rain stands in the bottom of the hollow")
	F.restore_hollows(list(1, 5.5))
	hollow_check(abs(flood_depth_at(locate(5, 3, 1)) - 0.5) < 0.001 && flood_band_at(locate(3, 4, 1)) == FLOOD_BAND_WAIST, "a fuller hollow is waist-deep at the bottom")
	F.stages_changed()
	hollow_check(F.flooding, "a hollow with water counts as flooding for drawing")

	var/list/state = F.snapshot()
	hollow_check(state.len == 1 * 3 + 2 + 1 + 1 + 1 && state[5] == 1 && abs(state[6] - 5.5) < 0.001, "the hollow's water is saved ([json_encode(state)])")
	var/datum/river_flood/G = river_flood_parse(hollow_probe_text(), 8, 6, 1)
	hollow_check(G.restore(state) && abs(G.hollow_volume[1] - 5.5) < 0.001 && abs(G.hollow_level[1] - 2) < 0.001, "and loads back")
	hollow_check(G.restore(list(1, state[2], state[3], state[4])) && G.hollow_volume[1] == 0, "a save from before hollows loads them dry")
	hollow_check(!G.restore(list(1, state[2], state[3], state[4], 3, 1)), "a malformed save is refused")

	F.step_hollows()
	hollow_check(F.hollow_volume[1] < 5.5 && F.hollow_volume[1] > 5, "water soaks away slowly without rain ([F.hollow_volume[1]])")

	// The river: below the rim the basin keeps only its rain; over it, the
	// water stands on the ground behind it.
	F.restore_hollows(list(1, 0))
	F.stage[1] = 2.5
	hollow_check(abs(flood_depth_at(locate(1, 4, 1)) - 1.5) < 0.001 && !flood_depth_at(locate(3, 4, 1)), "the rim keeps a lower river out")
	F.stage[1] = 3.5
	hollow_check(abs(flood_depth_at(locate(3, 4, 1)) - 2.5) < 0.001 && abs(flood_depth_at(locate(2, 4, 1)) - 0.5) < 0.001, "a river over the rim fills the basin to its own level")
