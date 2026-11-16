// Native probe for foul load carried downstream (river_foul.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/foul_probe.dm
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
/obj/map_metadata/foul_probe/New()
	return
var/foul_failures = 0
var/foul_runtime_error = FALSE
/proc/foul_check(condition, label)
	if (!condition)
		foul_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	foul_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/foul_probe
		foul_checks()
	catch(var/exception/e)
		foul_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = foul_failures, "runtime_error" = foul_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Reach 1 (west half of the middle row, small) drains into reach 2 (east
// half, big), which drains away. The middle row is water.
/proc/foul_probe_text()
	var/list/lines = list("civ13-river-flood 1", "size 6 3", "z 1", "reaches 2", "r 1 2 2 2 30 30 3", "r 2 0 5 2 3000 3030 3")
	lines += list("010101020202", "010101020202", "000000000000")
	lines += list("......", "......", "......")
	return jointext(lines, "\n")

/proc/foul_checks()
	var/datum/river_flood/F = river_flood_parse(foul_probe_text(), 6, 3, 1)
	foul_check(!F.error && F.count == 2, "parses reaches ([F.error])")
	map.terrain_height_file = "probe"
	map.river_flood_cache = F
	map.river_flood_loaded = TRUE
	map.river_flood_state = list()
	F.published = map.river_flood_state
	F.foul_ready()
	foul_check(F.foul.len == 2 && !F.foul[1] && !F.foul[2], "clean rivers carry no load")
	foul_check(river_foul_germs(locate(1, 2, 1)) == 0, "clean water adds no germs")

	// A load in the small upstream reach: some stays, some goes downstream, some breaks down.
	F.foul[1] = 10
	F.step_foul()
	foul_check(abs(F.foul[1] - 10 * 0.9 * 0.65) < 0.001, "a reach keeps what the water does not carry off")
	foul_check(abs(F.foul[2] - 10 * 0.9 * 0.35 * 0.65) < 0.001, "the load reaches the next reach in the same minute")
	var/g1 = river_foul_germs(locate(1, 2, 1))
	var/g2 = river_foul_germs(locate(5, 2, 1))
	foul_check(g1 > 0 && g2 > 0 && g2 < g1, "a big river dilutes what fouls a stream ([g1], [g2])")
	foul_check(g1 <= 2, "germs are capped")
	foul_check(river_foul_germs(locate(1, 1, 1)) == 0, "land outside a reach has no load")

	// Scum shows with some give, and clears once the load drops.
	F.foul[1] = 1000
	F.foul_update_shown()
	foul_check(F.foul_shown[1] == 3 && F.foul_scum_anywhere && river_fouled_at(locate(1, 2, 1)), "heavy load shows heavy scum")
	new /turf/floor/beach/water(locate(2, 2, 1))
	var/obj/structure/sink/hole = new(locate(2, 1, 1))
	hole.dug_depth = 2
	var/obj/structure/sink/mapped = new(locate(3, 1, 1))
	foul_check(hole.well_river_seepage() && !mapped.well_river_seepage(), "a well beside a fouled river draws its filth, a mapped sink does not")
	var/revision = river_scum_revision
	F.foul_update_shown()
	foul_check(river_scum_revision == revision, "no redraw while nothing changes")
	F.foul[1] = 0
	F.foul[2] = 0
	F.foul_update_shown()
	foul_check(!F.foul_shown[1] && !F.foul_scum_anywhere && river_scum_revision == revision + 1, "scum clears with the load")
	foul_check(!hole.well_river_seepage(), "a well draws clean once the river clears")

	// The load fades away within a quarter of an hour once nothing adds to it.
	F.foul[1] = 10
	for (var/i in 1 to 15)
		F.step_foul()
	foul_check(F.foul[1] < 0.01 && F.foul[2] < 0.05, "a one-off load clears ([F.foul[1]], [F.foul[2]])")

	// Saved with the river water and restored.
	F.foul[1] = 4.25
	F.foul[2] = 1.5
	var/list/state = F.snapshot()
	foul_check(state.len == 1 + 2 * 3 + 1 + 2 && state[state.len - 1] == 4.25 && state[state.len] == 1.5, "foul load is the last block of the saved state")
	var/datum/river_flood/G = river_flood_parse(foul_probe_text(), 6, 3, 1)
	foul_check(G.restore(state) && G.foul[1] == 4.25 && G.foul[2] == 1.5, "foul load restores")
	var/list/old_state = state.Copy(1, state.len - 1)
	var/datum/river_flood/H = river_flood_parse(foul_probe_text(), 6, 3, 1)
	foul_check(H.restore(old_state) && !H.foul[1] && !H.foul[2], "a state without foul load restores clean")

	// Water germ level adds the river's load to the water's own.
	var/turf/floor/beach/water/W = new /turf/floor/beach/water(locate(1, 2, 1))
	F.foul[1] = 0
	var/clean = W.water_germ_level()
	F.foul[1] = 2
	foul_check(W.water_germ_level() > clean, "fouled reach water carries more germs")
	foul_check(river_foul_rate_of(new /obj/item/weapon/reagent_containers/food/snacks/poo(locate(6, 1, 1))) > 0 && !river_foul_rate_of(new /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer(locate(6, 1, 1))), "waste fouls, compost does not")
