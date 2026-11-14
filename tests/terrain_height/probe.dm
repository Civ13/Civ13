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
	turf = /turf/floor/rocky/terrain_height_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/turf/floor/rocky/terrain_height_probe
/turf/floor/rocky/terrain_height_probe/other
/turf/floor/plating/terrain_height_probe_built

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

/mob/living/human/terrain_height_probe_climber/New()
	return

// Shading is an overlay; overlays hold appearances, so read them untyped.
/proc/terrain_height_probe_shade(turf/T)
	for (var/O in T.overlays)
		if (O:icon == 'icons/turf/terrain_shade.dmi')
			return O:icon_state
	return null

/proc/terrain_height_probe_shades(turf/T)
	. = 0
	for (var/O in T.overlays)
		if (O:icon == 'icons/turf/terrain_shade.dmi')
			.++

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

	// Uphill one level costs half the step again; downhill saves 31%.
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(5, 9, 1), locate(6, 9, 1), 2.85), 1.425), "uphill_one_level")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(6, 9, 1), locate(5, 9, 1), 2.85), 2.85 / 1.45 - 2.85), "downhill_one_level")
	// The curve: each extra level climbed costs more than the last; descents
	// are fastest at two levels and picked down more carefully past that.
	terrain_height_probe_assert(terrain_height_probe_close(terrain_grade_factor(2), 2.2) && terrain_height_probe_close(terrain_grade_factor(3), 3.1), "uphill_curve")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_grade_factor(-2), 0.55) && terrain_height_probe_close(terrain_grade_factor(-3), 0.65) && terrain_height_probe_close(terrain_grade_factor(-0.5), 1 / 1.225), "downhill_curve")
	terrain_height_probe_assert(terrain_slope_delay(locate(5, 3, 1), locate(6, 3, 1), 2.85) == 0, "flat_no_cost")
	// Big drops are capped at four levels.
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(10, 7, 1), locate(10, 6, 1), 2.85), -0.7125), "steep_descent_careful")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(10, 6, 1), locate(10, 7, 1), 2.85), 2.85 * 3.2), "uphill_level_cap")
	terrain_height_probe_assert(terrain_slope_delay(locate(10, 7, 1), locate(10, 6, 1), 0) == 0, "no_negative_delay")
	// Steep steps: signed capped level change; climbing spends stamina, with one chat message per window.
	terrain_height_probe_assert(terrain_step_levels(locate(10, 6, 1), locate(10, 7, 1)) == 4 && terrain_step_levels(locate(10, 7, 1), locate(10, 6, 1)) == -4, "step_levels_capped")
	terrain_height_probe_assert(terrain_step_levels(locate(5, 9, 1), locate(6, 9, 1)) == 1, "step_levels_one")
	var/mob/living/human/terrain_height_probe_climber/C = new(locate(10, 6, 1))
	C.stats["stamina"][1] = 50
	terrain_height_probe_assert(terrain_climb_effects(C, locate(5, 9, 1), locate(6, 9, 1)) == 0 && C.stats["stamina"][1] == 50 && C.next_slope_message == -1, "gentle_step_no_effects")
	terrain_height_probe_assert(terrain_climb_effects(C, locate(10, 6, 1), locate(10, 7, 1)) == 4 && terrain_height_probe_close(C.stats["stamina"][1], 48), "steep_climb_spends_stamina")
	var/first_message = C.next_slope_message
	terrain_height_probe_assert(first_message == world.time + 100, "steep_climb_messages")
	terrain_climb_effects(C, locate(10, 6, 1), locate(10, 7, 1), 0.0625)
	terrain_height_probe_assert(terrain_height_probe_close(C.stats["stamina"][1], 47.875) && C.next_slope_message == first_message, "nudge_scaled_and_message_throttled")
	terrain_height_probe_assert(terrain_climb_effects(C, locate(10, 7, 1), locate(10, 6, 1)) == -4 && terrain_height_probe_close(C.stats["stamina"][1], 47.875), "steep_descent_free")
	C.stats["stamina"][1] = 0
	terrain_climb_effects(C, locate(10, 6, 1), locate(10, 7, 1))
	terrain_height_probe_assert(C.stats["stamina"][1] == 0, "no_negative_stamina")
	// Running down a steep step can trip; walking, gentle steps and nudges never do.
	C.stats["stamina"][1] = 50
	C.m_intent = "run"
	terrain_height_probe_assert(terrain_trip_chance(C, locate(10, 7, 1), locate(10, 6, 1)) == 20, "steep_run_trip_chance")
	terrain_height_probe_assert(!terrain_trip_chance(C, locate(6, 9, 1), locate(5, 9, 1)) && !terrain_trip_chance(C, locate(10, 6, 1), locate(10, 7, 1)), "gentle_or_uphill_no_trip")
	terrain_height_probe_assert(!terrain_trip_chance(C, locate(10, 7, 1), locate(10, 6, 1), 0.0625), "nudge_no_trip")
	C.terrain_momentum = 1
	C.stats["stamina"][1] = 0
	terrain_height_probe_assert(terrain_trip_chance(C, locate(10, 7, 1), locate(10, 6, 1)) == 40, "momentum_and_tiredness_raise_trip")
	C.m_intent = "walk"
	terrain_height_probe_assert(!terrain_trip_chance(C, locate(10, 7, 1), locate(10, 6, 1)), "walking_never_trips")
	C.terrain_momentum = 0
	// A fall rolls down the steepest drop while it stays 2 levels a tile.
	var/list/roll = terrain_tumble_path(locate(10, 7, 1))
	terrain_height_probe_assert(roll.len == 1 && roll[1] == locate(10, 6, 1), "tumble_rolls_down_the_drop")
	terrain_height_probe_assert(!length(terrain_tumble_path(locate(6, 9, 1))) && !length(terrain_tumble_path(locate(3, 3, 1))), "gentle_or_flat_no_roll")
	qdel(C)

	// Free slides read the hill at the body's exact spot, blended between tile
	// centres, so half a tile short of a rise only feels half of it.
	var/mob/living/human/terrain_height_probe_climber/F = new(locate(6, 6, 1))
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_grade(F, locate(6, 7, 1), NORTH), 4), "free_grade_capped_at_centre")
	F.step_y = -16
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_grade(F, locate(6, 7, 1), NORTH), 2.5), "free_grade_blends_offsets")
	F.step_y = 0
	F.loc = locate(6, 9, 1)
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_grade(F, locate(7, 10, 1), NORTHEAST), 1 / 1.4142), "free_grade_diagonal_per_tile")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_slope_delay(F, locate(7, 9, 1), EAST, 2.85, FALSE), 1.425) && F.terrain_momentum == 0, "nudge_no_momentum")
	// Held slides downhill gather momentum, which speeds the next steps...
	F.loc = locate(8, 9, 1)
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_factor(F, locate(7, 9, 1), WEST, 2.85), 1 / 1.45) && terrain_height_probe_close(F.terrain_momentum, 0.25), "downhill_builds_momentum")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_factor(F, locate(7, 9, 1), WEST, 2.85), 0.95 / 1.45) && terrain_height_probe_close(F.terrain_momentum, 0.5), "momentum_speeds_descent")
	// ...carries on onto flat ground, fading...
	F.loc = locate(5, 3, 1)
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_factor(F, locate(4, 3, 1), WEST, 2.85), 0.9) && terrain_height_probe_close(F.terrain_momentum, 0.16), "momentum_carries_on_flat")
	// ...is lost turning back or pausing...
	terrain_height_probe_assert(terrain_free_factor(F, locate(6, 3, 1), EAST, 2.85) == 1 && F.terrain_momentum == 0, "reverse_loses_momentum")
	F.terrain_momentum = 1
	F.terrain_momentum_at = world.time - 50
	terrain_height_probe_assert(terrain_free_factor(F, locate(6, 3, 1), EAST, 2.85) == 1 && F.terrain_momentum == 0, "pause_loses_momentum")
	// ...and pays part of the next climb.
	F.loc = locate(5, 9, 1)
	F.terrain_momentum = 1
	F.terrain_momentum_at = world.time
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_factor(F, locate(6, 9, 1), EAST, 2.85), 1.2) && terrain_height_probe_close(F.terrain_momentum, 0.5), "momentum_pays_climb")
	F.terrain_momentum = 1
	F.terrain_momentum_at = world.time
	F.loc = locate(10, 9, 1)
	F.terrain_momentum_dir = WEST
	terrain_height_probe_assert(terrain_height_probe_close(terrain_free_factor(F, locate(9, 9, 1), WEST, 2.85), 0.8 / 1.45), "full_momentum_descent")
	// Held slides are paced in whole ticks; the leftover carries over, so the
	// average pace over a climb is the curve's 1.5 x the flat pace, and flat
	// ground keeps the flat pace exactly.
	F.loc = locate(5, 3, 1)
	F.terrain_momentum = 0
	F.terrain_pace_carry = 0
	terrain_height_probe_assert(terrain_free_slope_delay(F, locate(6, 3, 1), EAST, 2.85) == 0, "flat_free_pace_unchanged")
	F.loc = locate(5, 9, 1)
	var/tick = world.tick_lag
	var/flat_pace = (ceil(2.85 / tick) + 1) * tick
	var/total = 0
	for (var/i in 1 to 20)
		var/delay = 2.85 + terrain_free_slope_delay(F, locate(6, 9, 1), EAST, 2.85)
		total += (max(1, ceil(round(delay / tick, 0.001))) + 1) * tick
	terrain_height_probe_assert(abs(total / 20 - flat_pace * 1.5) <= tick / 20 + 0.0001, "climb_pace_follows_curve")
	// A straight slide along a level row ignores the hillside beside it, even
	// with the body a quarter tile off the row's centre line.
	F.loc = locate(5, 6, 1)
	F.step_y = 8
	terrain_height_probe_assert(terrain_free_grade(F, locate(6, 6, 1), EAST) == 0, "level_row_ignores_side_hill")
	F.step_y = 0
	qdel(F)

	// Check Movement describes the hill around a tile.
	var/list/hill = movement_check_hill_lines(locate(6, 9, 1))
	terrain_height_probe_assert(hill.len == 2 && findtext(hill[1], "east: up 1 level, about 50% slower") && findtext(hill[2], "west: down 1 level, about 31% faster"), "check_movement_hill_lines")
	terrain_height_probe_assert(!length(movement_check_hill_lines(locate(3, 3, 1))), "check_movement_flat_no_hill_lines")

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
	terrain_height_probe_assert(terrain_height_probe_shade(slope) == slope_key, "slope_tile_shows_sprite")
	var/image/shade = terrain_shade_image(slope_key)
	terrain_height_probe_assert(slope.terrain_shade_overlay == shade && shade.mouse_opacity == 0 && shade.plane == FLOOR_PLANE && shade.layer > 2.03 && shade.layer < 2.04, "sprites_are_shared_floor_overlays")
	terrain_height_probe_assert(!length(slope.vis_contents), "shading_is_not_vis_contents")
	slope.terrain_shade_refresh()
	terrain_height_probe_assert(terrain_height_probe_shades(slope) == 1, "refresh_does_not_stack")
	var/turf/floor/slope_floor = slope
	slope_floor.update_icon()
	terrain_height_probe_assert(terrain_height_probe_shade(slope) == slope_key && terrain_height_probe_shades(slope) == 1, "floor_icon_rebuild_keeps_shading")
	terrain_height_probe_assert(terrain_shading_apply() > 0, "apply_places_shading")
	terrain_shading_applied = TRUE
	var/turf/flat = locate(2, 2, 1)
	terrain_height_probe_assert(!terrain_height_probe_shade(flat), "flat_ground_left_alone")
	slope.ChangeTurf(/turf/floor/rocky/terrain_height_probe/other)
	slope = locate(6, 9, 1)
	terrain_height_probe_assert(!terrain_shading_applied || terrain_height_probe_shade(slope), "changeturf_keeps_shading")

	// Built floors are laid level: no slope cost onto, off or across them, and no shading.
	var/turf/built = locate(7, 9, 1)
	built.ChangeTurf(/turf/floor/plating/terrain_height_probe_built)
	built = locate(7, 9, 1)
	terrain_height_probe_assert(built.terrain_smoothed() && !slope.terrain_smoothed(), "built_vs_natural")
	terrain_height_probe_assert(terrain_slope_delay(locate(6, 9, 1), built, 2.85) == 0 && terrain_slope_delay(built, locate(8, 9, 1), 2.85) == 0, "built_floor_no_slope_cost")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(8, 9, 1), locate(9, 9, 1), 2.85), 1.425), "natural_ground_keeps_cost")
	terrain_height_probe_assert(!terrain_height_probe_shade(built), "built_floor_unshaded")
	built.ChangeTurf(/turf/floor/rocky/terrain_height_probe)
	built = locate(7, 9, 1)
	terrain_height_probe_assert(terrain_height_probe_shade(built), "removed_floor_shaded_again")

	// Road tamping: only bare dirt can be packed; tamped earth never turns to mud.
	var/turf/road = locate(7, 9, 1)
	terrain_height_probe_assert(road_tamping_problem(road), "tamping_needs_dirt")
	road.ChangeTurf(/turf/floor/grass)
	road = locate(7, 9, 1)
	terrain_height_probe_assert(findtext(road_tamping_problem(road), "grass"), "tamping_grass_hint")
	road.ChangeTurf(/turf/floor/dirt)
	road = locate(7, 9, 1)
	terrain_height_probe_assert(!road_tamping_problem(road) && !road.terrain_smoothed(), "dirt_can_be_tamped")
	road.weather_snow = 1
	terrain_height_probe_assert(road_tamping_problem(road), "tamping_needs_clear_snow")
	road.weather_snow = 0
	road.ChangeTurf(/turf/floor/tamped_earth)
	road = locate(7, 9, 1)
	var/turf/floor/tamped_earth/tamped = road
	// Packed, not levelled: the hill and shading stay, climbing onto it costs half.
	terrain_height_probe_assert(istype(tamped) && tamped.terrain_packed() && !tamped.terrain_smoothed() && !tamped.may_become_muddy, "tamped_earth_packed_and_firm")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(locate(6, 9, 1), road, 2.85), 0.7125), "tamped_earth_half_climb")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(road, locate(6, 9, 1), 2.85), 2.85 / 1.45 - 2.85), "tamped_earth_downhill_unchanged")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(road, locate(8, 9, 1), 2.85), 1.425), "leaving_tamped_earth_full_climb")
	terrain_height_probe_assert(terrain_height_probe_shade(road), "tamped_earth_still_shaded")
	terrain_height_probe_assert(road_tamping_problem(road), "tamped_earth_not_retamped")
	road.ChangeTurf(/turf/floor/rocky/terrain_height_probe)

	// Floor and road covers laid on natural ground level it; cover walls do not.
	var/turf/covered = locate(8, 9, 1)
	var/obj/covers/wood/floor_cover = new(covered)
	floor_cover.updateturf()
	terrain_height_probe_assert(covered.terrain_smoothed() && terrain_slope_delay(locate(7, 9, 1), covered, 2.85) == 0, "floor_cover_no_slope_cost")
	terrain_height_probe_assert(!terrain_height_probe_shade(covered), "floor_cover_unshaded")
	qdel(floor_cover)
	terrain_height_probe_assert(!covered.terrain_smoothed() && terrain_height_probe_close(terrain_slope_delay(locate(7, 9, 1), covered, 2.85), 1.425), "removed_cover_slope_back")
	terrain_height_probe_assert(terrain_height_probe_shade(covered), "removed_cover_shaded_again")
	var/obj/covers/wood_wall/wall_cover = new(covered)
	terrain_height_probe_assert(!covered.terrain_smoothed(), "cover_wall_not_a_floor")
	qdel(wall_cover)

	// Grading: one level at a time, at most two from the map's height, saved with the turf.
	var/turf/graded = locate(7, 9, 1)
	graded.ChangeTurf(/turf/floor/dirt)
	graded = locate(7, 9, 1)
	terrain_height_probe_assert(!terrain_grade_problem(graded, -1) && !terrain_grade_problem(graded, 1), "dirt_can_be_graded")
	terrain_height_probe_assert(terrain_grade_problem(locate(6, 9, 1), -1), "rock_cannot_be_graded")
	var/turf/flat_dirt = locate(5, 3, 1)
	flat_dirt.ChangeTurf(/turf/floor/dirt)
	flat_dirt = locate(5, 3, 1)
	terrain_height_probe_assert(findtext(terrain_grade_problem(flat_dirt, -1), "as low"), "grade_floor_is_zero")
	graded.terrain_grade = -1
	graded.terrain_grade_apply()
	terrain_height_probe_assert(terrain_height_at(graded) == 5 && fixture.base_at(7, 9, 1) == 6, "cut_lowers_one_level")
	terrain_height_probe_assert(terrain_height_probe_close(terrain_slope_delay(graded, locate(8, 9, 1), 2.85), 2.85 * 1.2), "cut_steepens_next_step")
	graded.terrain_grade = -2
	graded.terrain_grade_apply()
	terrain_height_probe_assert(terrain_height_at(graded) == 4, "cut_twice")
	terrain_height_probe_assert(findtext(terrain_grade_problem(graded, -1), "any lower"), "cut_limit_two_levels")
	terrain_height_probe_assert(!terrain_grade_problem(graded, 1), "can_fill_back")
	// Patched lights match a full recompute of the graded rows.
	var/list/patched = fixture.light_rows(1).Copy()
	fixture.light_rows_by_z -= "1"
	terrain_height_probe_assert(jointext(patched, "|") == jointext(fixture.light_rows(1), "|"), "graded_lights_match_full_pass")
	terrain_height_probe_assert((terrain_height_probe_shade(graded) || "cccc") == fixture.shade_key(7, 9, 1), "graded_tile_reshaded")
	// The grade survives turf changes and is saved only when set.
	graded.ChangeTurf(/turf/floor/tamped_earth)
	graded = locate(7, 9, 1)
	terrain_height_probe_assert(graded.terrain_grade == -2 && terrain_height_at(graded) == 4, "grade_kept_on_changeturf")
	terrain_height_probe_assert("terrain_grade" in graded.get_saved_vars(), "grade_saved")
	terrain_height_probe_assert(!("terrain_grade" in flat_dirt.get_saved_vars()), "ungraded_not_saved")
	// A load re-applies the saved grade over a fresh height file.
	fixture.set_level(7, 9, 1, fixture.base_at(7, 9, 1))
	terrain_height_probe_assert(terrain_height_at(graded) == 6, "reset_to_file_height")
	graded.after_load()
	terrain_height_probe_assert(terrain_height_at(graded) == 4, "load_reapplies_grade")
	// Water nearby and built covers block grading.
	var/turf/shore = locate(3, 3, 1)
	shore.ChangeTurf(/turf/floor/dirt)
	shore = locate(3, 3, 1)
	var/turf/water = locate(4, 3, 1)
	water.ChangeTurf(/turf/floor/beach/water)
	terrain_height_probe_assert(findtext(terrain_grade_problem(shore, 1), "water"), "no_grading_by_water")
	graded.terrain_grade = 0
	graded.terrain_grade_apply()
	terrain_height_probe_assert(terrain_height_at(graded) == 6, "grade_undone")
	// The rammer levels toward the user's own tile: a higher tile is pounded
	// down a level, stays tamped and drops its dirt at the user's feet.
	var/turf/high = locate(8, 10, 1)
	var/turf/feet = locate(7, 10, 1)
	high.ChangeTurf(/turf/floor/dirt)
	high = locate(8, 10, 1)
	terrain_height_probe_assert(stone_rammer_level_direction(high, feet) == -1, "rammer_cuts_higher_tile")
	terrain_height_probe_assert(stone_rammer_level_direction(feet, high) == 0, "rammer_never_cuts_lower_tile")
	terrain_height_probe_assert(stone_rammer_level_direction(high, high) == 0 && stone_rammer_level_direction(locate(5, 3, 1), locate(4, 2, 1)) == 0, "rammer_level_ground_only_tamps")
	var/obj/item/weapon/stone_rammer/rammer = new
	high = terrain_grade_finish(high, -1, rammer, feet)
	terrain_height_probe_assert(istype(high, /turf/floor/tamped_earth) && terrain_height_at(high) == 6 && high.terrain_grade == -1, "rammer_cut_lowers_and_packs")
	terrain_height_probe_assert((locate(/obj/item/weapon/barrier) in feet) && !(locate(/obj/item/weapon/barrier) in high), "rammer_cut_pile_at_feet")
	terrain_height_probe_assert(stone_rammer_level_direction(high, feet) == 0, "rammer_stops_at_your_level")
	var/obj/item/weapon/barrier/fill_pile = locate(/obj/item/weapon/barrier) in feet
	fill_pile.forceMove(high)
	high = terrain_grade_finish(high, 1, rammer, null, fill_pile)
	terrain_height_probe_assert(terrain_height_at(high) == 7 && !high.terrain_grade && QDELETED(fill_pile), "rammer_fill_raises")
	high = terrain_grade_finish(high, -1, null)
	terrain_height_probe_assert(istype(high, /turf/floor/dirt) && terrain_height_at(high) == 6 && (locate(/obj/item/weapon/barrier) in high), "shovel_cut_pile_on_tile")
	high.terrain_grade = 0
	high.terrain_grade_apply()
	qdel(rammer)

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
