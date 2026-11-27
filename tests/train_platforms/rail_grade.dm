// Grade fixture: inject a height profile without using live map state or assets.
/obj/map_metadata/train_grade_probe
	terrain_height_file = "train-grade-fixture"

/obj/map_metadata/train_grade_probe/New()
	return

/proc/platform_rail_grade_run()
	var/turf/low = platform_turf(443, 14)
	var/turf/high = platform_turf(444, 14)
	var/turf/higher = platform_turf(445, 14)
	var/obj/map_metadata/original = map
	platform_check("grade/no_height_map_is_flat", train_rail_grade(low, high) == 0)
	var/obj/map_metadata/train_grade_probe/M = new
	var/datum/terrain_heights/H = new
	H.maxx = world.maxx
	H.maxy = world.maxy
	var/list/rows = new /list(H.maxy)
	var/row = ""
	for (var/x in 1 to H.maxx)
		row += (x == 444 ? "6" : (x == 445 ? "c" : "2"))
	for (var/i in 1 to H.maxy)
		rows[i] = row
	H.rows_by_z["1"] = rows
	M.terrain_heights_cache = H
	map = M

	var/up = train_rail_grade(low, high)
	var/down = train_rail_grade(high, low)
	var/diagonal = train_rail_grade(low, platform_turf(444, 15))
	platform_check("grade/signed_and_diagonal", abs(up - 0.4) < 0.001 && up == -down && diagonal < up && diagonal > 0)
	platform_check("grade/unequal_heights_clamped", train_rail_grade(high, higher) == up)
	var/obj/covers/bridge/deck = new(high)
	var/obj/covers/bridge/approach = new(low)
	platform_check("grade/level_bridge_over_uneven_ground", train_rail_grade(high, low) == 0 && train_rail_grade(higher, high) == 0)
	qdel(deck)
	qdel(approach)

	var/level_target = 5
	var/tractive = 0.5
	var/uphill_target = train_grade_cruise(level_target, tractive, up)
	platform_check("grade/uphill_spends_pull", uphill_target > 0 && uphill_target < level_target && train_grade_cruise(level_target, 0.25, up) == 0)
	var/flat_start = train_grade_speed(0, level_target, tractive, 0.2, 0, 5, FALSE)
	var/uphill_start = train_grade_speed(0, uphill_target, tractive, 0.2, up, 5, FALSE)
	var/heavy_start = train_grade_speed(0, level_target, 0.25, 0.2, 0, 5, FALSE)
	platform_check("grade/flat_and_loaded_start", flat_start == train_speed_gain(0, tractive) && flat_start > heavy_start && flat_start > uphill_start && uphill_start > 0)
	var/flat_coast = train_grade_speed(2, 0, 0, 0.2, 0, 5, FALSE)
	var/heavy_coast = train_grade_speed(2, 0, 0, 0.1, 0, 5, FALSE)
	var/downhill_coast = train_grade_speed(2, 0, 0, 0.2, down, 5, FALSE)
	platform_check("grade/coast_follows_grade_and_mass", flat_coast < heavy_coast && heavy_coast < 2 && downhill_coast > 2 && train_grade_speed(2, 0, 0, 0.2, up, 5, FALSE) < flat_coast)
	platform_check("grade/downhill_respects_brake_and_speed_cap", train_grade_speed(2, 0, 0, 0.2, down, 5, TRUE) < 2 && train_grade_speed(5, 0, 0, 0.2, down, 5, FALSE) == 5)
	platform_check("grade/no_idle_rollback", train_grade_speed(0, 0, 0, 0.2, down, 5, FALSE) == 0)

	for (var/x in 438 to 447)
		platform_track(x, 14, EAST)
	var/obj/structure/trains/locomotive/L = new(high)
	L.set_dir(EAST)
	L.reverser = -1
	L.rail_speed = 2
	L.locomotive()
	sleep(2)
	platform_check("grade/reverse_coast_uses_routed_destination", L.loc == low && L.rail_speed > 2)
	qdel(L)
	map = original
	qdel(M)
