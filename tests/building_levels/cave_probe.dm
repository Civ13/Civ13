// ISOLATED TEST PROBE. A dig-down map that also opts into building levels: the
// dug cave and the open-air levels coexist in either order. Built with
// CAVE_PROBE_CAVE_FIRST the cave is dug before the standing level is added (a
// world saved before the map gained building levels); otherwise after it.
/world
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/cave_level_tester
	building_levels = 4
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
		cave_assert(rules.building_admitted(base + 5) && !rules.building_admitted(base + 6), "four building levels and the cave are the cap")
		var/cave
		var/air
		#ifdef CAVE_PROBE_CAVE_FIRST
		cave_assert(dug_underground_create(), "the cave is dug under the bare surface")
		cave = dug_underground_z()
		cave_assert(cave == base + 1 && !building_levels_built() && !building_standing_present(), "a cave is not the standing level")
		cave_assert(building_standing_try() && world.maxz == base + 2, "the standing level is added over a dug cave")
		air = base + 2
		#else
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
		cave_assert(map_storage.sparse_level_kind(cave) == null && map_storage.sparse_level_kind(air) == "building", "the cave saves whole, the air sparsely")
		cave_assert(!building_grows_from(base) && !building_grows_from(cave) && building_grows_from(air), "growth starts from the highest building level")
		// Three more storeys: the cave does not use up one of the four.
		for (var/storey = 2 to 4)
			var/target = world.maxz + 1
			cave_assert(!world_z_budget.error(target, "roof"), "storey [storey] is within the roof limit")
			cave_assert(building_allocate_level(target) && world.maxz == target, "storey [storey] is admitted")
			cave_assert(building_levels_built() == storey, "storey [storey] is counted")
		cave_assert(world.maxz == base + 5 && dug_underground_z() == cave, "five added levels, one of them the cave")
		var/second = air + 1 == cave ? air + 2 : air + 1
		cave_assert(multiz_level_above(air) == second && multiz_level_below(second) == air, "the second storey stands on the first, over the cave")
		cave_assert(multiz_level_below(world.maxz) == world.maxz - 1 && !multiz_level_above(world.maxz), "upper storeys stack plainly")
		cave_assert(!building_grows_from(world.maxz) && world_z_budget.error(world.maxz + 1, "roof"), "the map's cap stops growth")
		cave_assert(!rules.building_admitted(world.maxz + 1) && !rules.underground_admitted(world.maxz + 1), "nothing more is admitted")
		cave_assert(multiz_top_z() == base, "the surface is still the top ground level")
		text2file("PASS: cave with building levels", "result.txt")
	catch (var/exception/E)
		world.log << "CAVE exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
