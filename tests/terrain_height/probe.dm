// Full-source probe for terrain heights: real parser, lookup and slope cost,
// isolated startup. tests/terrain_height/fixture.txt: rows y 7-12 rise one
// level per tile eastward (height = x - 1), rows y 1-6 are flat 0.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/terrain_height_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/turf/floor/plating/terrain_height_probe
/turf/floor/plating/terrain_height_probe/other

/obj/map_metadata/terrain_height_probe
	terrain_height_file = "tests/terrain_height/fixture.txt"

// Skip the real metadata constructor (schedules, factions); only the map global matters.
/obj/map_metadata/terrain_height_probe/New()
	map = src

/obj/map_metadata/terrain_height_probe/flat
	terrain_height_file = null

var/terrain_height_probe_checks = 0

/proc/terrain_height_probe_assert(ok, label)
	terrain_height_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/terrain_height_probe_close(a, b)
	return abs(a - b) < 0.0001

/proc/terrain_height_probe_rejects(text, label)
	var/datum/terrain_heights/H = terrain_heights_parse(text, 2, 2, 1)
	terrain_height_probe_assert(H.error, "rejects_[label]")

/proc/terrain_height_probe_run()
	// No map, or a map without a file: flat and free.
	map = null
	terrain_height_probe_assert(terrain_height_at(locate(5, 9, 1)) == 0, "no_map_flat")
	map = new /obj/map_metadata/terrain_height_probe/flat
	terrain_height_probe_assert(terrain_height_at(locate(5, 9, 1)) == 0, "no_file_flat")
	terrain_height_probe_assert(terrain_slope_delay(locate(5, 9, 1), locate(6, 9, 1), 3) == 0, "no_file_no_cost")

	map = new /obj/map_metadata/terrain_height_probe
	terrain_height_probe_assert(map.terrain_heights(), "fixture_loads")
	terrain_height_probe_assert(terrain_height_at(locate(1, 12, 1)) == 0, "north_west_corner")
	terrain_height_probe_assert(terrain_height_at(locate(5, 9, 1)) == 4, "digit_level")
	terrain_height_probe_assert(terrain_height_at(locate(12, 7, 1)) == 11, "hex_level")
	terrain_height_probe_assert(terrain_height_at(locate(12, 6, 1)) == 0, "south_half_flat")

	// Uphill one level costs 1; downhill saves 0.5.
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(5, 9, 1), locate(6, 9, 1), 2.85), 1), "uphill_one_level")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(6, 9, 1), locate(5, 9, 1), 2.85), -0.5), "downhill_one_level")
	terrain_height_probe_assert(terrain_slope_delay(locate(5, 3, 1), locate(6, 3, 1), 2.85) == 0, "flat_no_cost")
	// Big drops are capped at four levels and a quarter of the step's delay.
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(10, 7, 1), locate(10, 6, 1), 2.85), -0.7125), "downhill_share_cap")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(10, 6, 1), locate(10, 7, 1), 2.85), 4), "uphill_level_cap")
	terrain_height_probe_assert(terrain_slope_delay(locate(10, 7, 1), locate(10, 6, 1), 0) == 0, "no_negative_delay")

	// Malformed files load flat instead of half-loaded.
	terrain_height_probe_rejects(null, "null")
	terrain_height_probe_rejects("civ13-terrain-heights 2\nsize 2 2\nz 1\n00\n00\n", "version")
	terrain_height_probe_rejects("civ13-terrain-heights 1\nsize 3 2\nz 1\n000\n000\n", "world_size")
	terrain_height_probe_rejects("civ13-terrain-heights 1\nsize 2 2\nz 1\n00\n", "short_rows")
	terrain_height_probe_rejects("civ13-terrain-heights 1\nsize 2 2\nz 1\n0g\n00\n", "bad_digit")
	terrain_height_probe_rejects("civ13-terrain-heights 1\nsize 2 2\nz 1\n0A\n00\n", "upper_case")
	terrain_height_probe_rejects("civ13-terrain-heights 1\nsize 2 2\nz 2\n00\n00\n", "z_outside_world")
	terrain_height_probe_rejects("civ13-terrain-heights 1\nsize 2 2\nz 1\n00\n00\nz 1\n00\n00\n", "repeated_z")
	var/CR = ascii2text(13)
	var/datum/terrain_heights/ok = terrain_heights_parse("civ13-terrain-heights 1[CR]\nsize 2 2[CR]\nz 1[CR]\n1f[CR]\n00[CR]\n", 2, 2, 1)
	terrain_height_probe_assert(!ok.error && ok.at(2, 2, 1) == 15 && ok.at(1, 2, 1) == 1 && ok.at(1, 1, 1) == 0, "crlf_accepted")
	terrain_height_probe_assert(ok.at(3, 1, 1) == 0 && ok.at(1, 1, 2) == 0, "outside_reads_zero")

	// Slope shading: corner lights are dumped for tests/terrain_height/run.py to
	// compare with scripts/terrain_heights.py corner_lights().
	var/datum/terrain_heights/fixture = map.terrain_heights()
	var/list/lights = fixture.light_rows(1)
	terrain_height_probe_assert(lights.len == 13 && length(lights[1]) == 13, "light_grid_size")
	text2file(jointext(lights, "\n"), "lights.txt")
	terrain_height_probe_assert(fixture.shade_key(1, 1, 1) == "cccc", "flat_tile_unshaded")
	var/turf/slope = locate(6, 9, 1)
	var/slope_key = fixture.shade_key(6, 9, 1)
	terrain_height_probe_assert(slope_key && slope_key != "cccc", "slope_tile_shaded")
	slope.terrain_shade_refresh()
	var/obj/effect/terrain_shade/shade = locate() in slope.vis_contents
	terrain_height_probe_assert(shade && shade.icon_state == slope_key && shade.mouse_opacity == 0, "slope_tile_shows_sprite")
	terrain_height_probe_assert(shade == terrain_shade_object(slope_key), "sprites_are_shared")
	slope.terrain_shade_refresh()
	var/shades = 0
	for (var/obj/effect/terrain_shade/S in slope.vis_contents)
		shades++
	terrain_height_probe_assert(shades == 1, "refresh_does_not_stack")
	terrain_height_probe_assert(terrain_shading_apply() > 0, "apply_places_shading")
	terrain_shading_applied = TRUE
	var/turf/flat = locate(2, 2, 1)
	terrain_height_probe_assert(!(locate(/obj/effect/terrain_shade) in flat.vis_contents), "flat_ground_left_alone")
	slope.ChangeTurf(/turf/floor/plating/terrain_height_probe/other)
	slope = locate(6, 9, 1)
	terrain_height_probe_assert(!terrain_shading_applied || (locate(/obj/effect/terrain_shade) in slope.vis_contents), "changeturf_keeps_shading")

	var/obj/map_metadata/terrain_height_probe/broken = new
	broken.terrain_height_file = "tests/terrain_height/missing.txt"
	map = broken
	terrain_height_probe_assert(terrain_height_at(locate(5, 9, 1)) == 0 && broken.terrain_heights_cache.error, "missing_file_flat")
	terrain_height_probe_assert(broken.persistence_runtime_var("terrain_height_file") && broken.persistence_runtime_var("terrain_heights_cache"), "not_saved")

/world/New()
	OpenPort("none")
	var/error = null
	try
		terrain_height_probe_run()
	catch (var/exception/probe_error)
		error = probe_error.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = terrain_height_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
