// ISOLATED TEST PROBE. A dig-down map that also opts into building levels: the
// dug cave and the open-air levels coexist in either order. Built with
// CAVE_PROBE_CAVE_FIRST the cave is dug before the standing level is added (a
// world saved before the map gained building levels); otherwise after it.
/world
	maxx = 10
	maxy = 10
	maxz = 1
	// The production native fill: an added cave level is unformed rock.
	turf = /turf/sky/building
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/cave_level_tester
	building_levels = 10
	building_level_standing = TRUE
	dig_down_underground = TRUE

/obj/map_metadata/cave_level_tester/New()
	return

/proc/cave_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/world/New()
	OpenPort("none")
	try
		for (var/turf/T in block(locate(1, 1, 1), locate(world.maxx, world.maxy, 1)))
			new /turf/floor/dirt(T)
		world_z_budget = new /datum/world_z_budget/fixture_admission
		// The production admission rules, asked directly: the fixture budget
		// above admits everything so the allocator paths can run.
		var/datum/world_z_budget/rules = new
		var/base = world.maxz
		map = new /obj/map_metadata/cave_level_tester
		ticker = new /datum/controller/gameticker
		ticker.current_state = GAME_STATE_PLAYING
		cave_assert(dug_underground_supported() && building_standing_wanted(), "a dig-down map still wants its standing level")
		cave_assert(rules.underground_admitted(base + 1) && rules.building_admitted(base + 1), "either level may come first")
		cave_assert(rules.building_admitted(base + 14) && !rules.building_admitted(base + 15), "ten building levels and four underground levels are the cap")
		var/cave
		var/air
		#ifdef CAVE_PROBE_CAVE_FIRST
		cave_assert(dug_underground_create(), "the cave is dug under the bare surface")
		cave = dug_underground_z()
		cave_assert(cave == base + 1 && !building_levels_built() && !building_standing_present(), "a cave is not the standing level")
		cave_assert(building_standing_try() && world.maxz == base + 2, "the standing level is added over a dug cave")
		air = base + 2
		#else
		cave_assert(!building_standing_try() && world.maxz == base, "the standing level waits for the cave")
		// A world whose cave was refused at boot, then allowed later.
		dug_underground_boot_done = TRUE
		cave_assert(building_standing_try() && world.maxz == base + 1, "the standing level is added first")
		air = base + 1
		cave_assert(rules.underground_admitted(base + 2) && !rules.underground_admitted(base + 1), "the cave is the next level")
		cave_assert(dug_underground_create(), "the cave is dug with the standing level present")
		cave = dug_underground_z()
		cave_assert(cave == base + 2, "the cave is appended above the open air")
		#endif
		cave_assert(istype(locate(1, 1, cave), /turf/wall/rockwall/bedrock) && istype(locate(1, 1, air), /turf/sky/building), "bedrock rim and open air")
		cave_assert(building_levels_built() == 1 && building_standing_present(), "one building level stands")
		cave_assert(multiz_level_below(base) == cave && multiz_level_above(cave) == base && !multiz_level_below(cave), "the cave lies under the surface")
		cave_assert(multiz_level_above(base) == air && multiz_level_below(air) == base && !multiz_level_above(air), "the open air lies over the surface")
		cave_assert(multiz_top_z() == base, "the surface stays the top ground level")
		cave_assert(!building_upper_z(cave) && building_upper_z(base) == air, "roofs never pair with the cave")
		cave_assert(map_storage.sparse_level_kind(cave) == "building" && map_storage.sparse_level_kind(air) == "building", "the cave and the air save sparsely")
		// Unformed rock: the cave is native fill except its bedrock marker.
		var/turf/inner = locate(5, 5, cave)
		cave_assert(dug_underground_unformed(inner) && building_cell_asleep(inner) && !dug_underground_unformed(locate(5, 5, air)), "the cave starts unformed and asleep")
		cave_assert(!inner.Enter(new /obj/item(locate(5, 5, base))), "nothing enters unformed rock")
		var/turf/opened = dug_underground_form(inner)
		cave_assert(!dug_underground_unformed(opened) && dug_underground_form(opened) == opened, "a cell forms once")
		opened = opened.ChangeTurf(/turf/floor/dirt)
		for (var/d in alldirs)
			cave_assert(!dug_underground_unformed(get_step(opened, d)), "an opened cell forms its neighbours ([d])")
		cave_assert(dug_underground_unformed(locate(8, 8, cave)), "cells beyond the opening stay unformed")
		var/turf/blasted = locate(8, 2, cave)
		blasted.ex_act(3)
		cave_assert(!dug_underground_unformed(locate(8, 2, cave)), "an explosion forms the rock it reaches")
		cave_assert(dug_underground_cell(5, 5) == dug_underground_cell(5, 5) && dug_underground_cell(1, 4) == /turf/wall/rockwall/bedrock, "the generator is repeatable and rims the level")
		// Water above (docs/underground-level.md): the surface over a cell picks its rock.
		locate(3, 3, base).ChangeTurf(/turf/floor/beach/water/deep)
		locate(3, 4, base).ChangeTurf(/turf/floor/beach/water/deep/saltwater)
		locate(3, 5, base).ChangeTurf(/turf/floor/beach/water)
		locate(3, 6, base).ChangeTurf(/turf/floor/beach/water/swamp)
		cave_assert(dug_underground_cell(3, 3) == /turf/floor/dirt/underground/wet, "a lake forms wet rock below")
		cave_assert(dug_underground_cell(3, 4) == /turf/wall/rockwall, "the sea forms seabed rock below")
		cave_assert(dug_underground_cell(3, 5) == /turf/floor/dirt/underground/mud && dug_underground_cell(3, 6) == /turf/floor/dirt/underground/mud, "shallows and swamp form wet earth below")
		var/turf/wet = dug_underground_form(locate(3, 3, cave))
		cave_assert(istype(wet, /turf/floor/dirt/underground/wet) && !(wet in tunnel_breaches), "wet rock holds until it is broken")
		wet = wet.ChangeTurf(/turf/floor/dirt)
		cave_assert(wet in tunnel_breaches, "breaking wet rock lets the lake in")
		tunnel_breaches.Cut()
		cave_assert(underground_breach_scan(cave) == 1 && (wet in tunnel_breaches), "a load finds the breach again")
		var/turf/hot = dug_underground_form(locate(7, 3, cave)).ChangeTurf(/turf/floor/dirt/underground/hot)
		cave_assert(!hot.is_mineable && underground_excavation_problem(hot), "hot rock cannot be dug")
		cave_assert(!building_grows_from(base) && !building_grows_from(cave) && building_grows_from(air), "growth starts from the highest building level")
		// Nine more storeys: the cave does not use up one of the ten.
		for (var/storey = 2 to 10)
			var/target = world.maxz + 1
			cave_assert(!world_z_budget.error(target, "roof"), "storey [storey] is within the roof limit")
			cave_assert(building_allocate_level(target) && world.maxz == target, "storey [storey] is admitted")
			cave_assert(building_levels_built() == storey, "storey [storey] is counted")
		cave_assert(world.maxz == base + 11 && dug_underground_z() == cave, "eleven added levels, one of them the cave")
		var/second = air + 1 == cave ? air + 2 : air + 1
		cave_assert(multiz_level_above(air) == second && multiz_level_below(second) == air, "the second storey stands on the first, over the cave")
		cave_assert(multiz_level_below(world.maxz) == world.maxz - 1 && !multiz_level_above(world.maxz), "upper storeys stack plainly")
		cave_assert(!building_grows_from(world.maxz) && world_z_budget.error(world.maxz + 1, "roof"), "the map's cap stops growth")
		cave_assert(multiz_top_z() == base, "the surface is still the top ground level")
		// Deeper levels (docs/underground-level.md): three more under the cave,
		// each appended above the open air but lying under the one before.
		cave_assert(underground_depth_limit() == 4 && underground_depth_of(cave) == 1 && !underground_depth_of(air), "the cave is depth one of four")
		cave_assert(!underground_create(3) && underground_dig_error(3), "a level is dug only under the deepest one")
		var/list/deep = list(cave)
		for (var/depth = 2 to 4)
			cave_assert(rules.underground_admitted(world.maxz + 1) && !building_grows_from(world.maxz), "depth [depth] is admitted, no more storeys")
			cave_assert(!world_z_budget.error(world.maxz + 1, "underground"), "depth [depth] fits the level ceiling")
			cave_assert(underground_create(depth) && world.maxz == base + 10 + depth, "depth [depth] is dug")
			var/z = world.maxz
			deep += z
			cave_assert(underground_depth_of(z) == depth && underground_z_at(depth) == z && underground_added(z), "depth [depth] is recognised")
			cave_assert(multiz_level_below(deep[depth - 1]) == z && multiz_level_above(z) == deep[depth - 1] && !multiz_level_below(z), "depth [depth] lies under depth [depth - 1]")
			cave_assert(istype(locate(1, 1, z), /turf/wall/rockwall/bedrock) && dug_underground_unformed(locate(5, 5, z)), "depth [depth] starts unformed")
			cave_assert(map_storage.sparse_level_kind(z) == "building", "depth [depth] saves sparsely")
			cave_assert(!building_upper_z(z) && !building_stack_room(z) && !building_level_lazy(z), "depth [depth] is never a building level")
		cave_assert(building_levels_built() == 10 && underground_added_count() == 4, "ten storeys, four underground levels")
		cave_assert(!rules.underground_admitted(world.maxz + 1) && underground_dig_error(5) && !rules.building_admitted(world.maxz + 1), "nothing more is admitted")
		cave_assert(multiz_top_z() == base && underground_surface_z() == base && multiz_level_above(air) == second, "the surface and the storeys keep their places")
		// The deep levels form from their own seed and feel only sea and lava.
		var/turf/deep_cell = dug_underground_form(locate(3, 3, deep[2]))
		cave_assert(!istype(deep_cell, /turf/floor/dirt/underground/wet) && !underground_above_cell(deep_cell), "a lake does not wet the second level")
		cave_assert(dug_underground_cell(3, 4, base, 2) == /turf/wall/rockwall, "the sea floor reaches every depth")
		var/turf/deep_open = dug_underground_form(locate(6, 6, deep[3])).ChangeTurf(/turf/floor/dirt)
		for (var/d in alldirs)
			cave_assert(!dug_underground_unformed(get_step(deep_open, d)), "an opened deep cell forms its neighbours ([d])")
		cave_assert(dug_underground_unformed(locate(6, 6, deep[4])) && dug_underground_unformed(locate(6, 6, deep[2])), "other depths stay unformed")
		cave_assert(underground_breach_scan(deep[2]) == 0, "only the cave takes water from above")
		cave_assert(level_report_name(deep[2]) == "underground 2 (added)", "the level report names the depth")
		// Each depth has its own ore table (underground_ores.dm).
		cave_assert(underground_ore_factor("gold", locate(3, 3, base)) == 1 && underground_ore_factor("gold", locate(3, 3, cave)) == 1, "the surface and the cave keep today's ores")
		cave_assert(underground_ore_factor("coal", locate(3, 3, deep[2])) == 2 && underground_ore_factor("gold", locate(3, 3, deep[3])) == 2.5 && underground_ore_factor("diamond", locate(3, 3, deep[4])) == 4, "each depth has its own riches")
		cave_assert(underground_ore_factor("flint", locate(3, 3, deep[3])) == 0 && underground_ore_factor("bauxite", locate(3, 3, deep[4])) == 0.25 && underground_ore_factor("unknown", locate(3, 3, deep[4])) == 1, "shallow ores thin out with depth")
		cave_assert(continent_ore_factor("gold", locate(3, 3, deep[4])) == 3 * continent_ore_factor("gold", locate(3, 3, base)), "the depth multiplies the land's own rate")
		cave_assert(underground_surface_over(locate(3, 3, deep[4])) == locate(3, 3, base) && !underground_surface_over(locate(3, 3, base)), "a deep cell finds the land above")
		// A restore cannot see its underground yet: it counts every level the map may add.
		cave_assert(rules.free_planes(world.maxz, "restore") == 4 && rules.free_planes(world.maxz, "roof") == 4 && rules.ground_planes() == rules.base_z + 4, "a restore counts the whole underground")
		underground_levels_refresh()
		cave_assert(underground_depth_of(deep[4]) == 4 && multiz_level_below(deep[3]) == deep[4], "the levels are found again from their markers")
		var/list/report = level_report_counts(cave)
		cave_assert(level_report_name(cave) == "cave (added)" && level_report_name(air) == "open air" && level_report_name(base) == "ground" && report[1] > 1 && report[2] >= 1, "the level report counts the dug cave")
		text2file("PASS: cave with building levels", "result.txt")
	catch (var/exception/E)
		world.log << "CAVE exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
