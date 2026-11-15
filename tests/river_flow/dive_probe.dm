// Native probe for free diving: diving rules, breath on the seabed, depth by
// skill, forced surfacing and the seabed swim speed (free_diving.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/dive_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 20
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/dive_probe
	sea_layer_surface_z = 2
/obj/map_metadata/dive_probe/New()
	return
/mob/living/human/dive_probe/update_icons()
	return
/mob/living/human/dive_probe/New()
	species = new /datum/species/human
	return
/obj/covers/dive_probe_raft
	name = "probe raft"
var/dive_failures = 0
var/dive_runtime_error = FALSE
/proc/dive_check(condition, label)
	if (!condition)
		dive_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	dive_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/dive_probe
		dive_checks()
	catch(var/exception/e)
		dive_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = dive_failures, "runtime_error" = dive_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/dive_checks()
	// Surface (z2): land x 1-3, shallows x 4, open sea from x 5. Below: rock.
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/S = locate(x, y, 2)
			if (x <= 3)
				S.ChangeTurf(/turf/floor/dirt)
			else if (x == 4)
				S.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
			else
				S.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			locate(x, y, 1).ChangeTurf(/turf/wall/rockwall)
	sea_layer_build(2, 1)
	seabed_zone_pass(1)
	var/turf/shelf_top = locate(8, 10, 2)
	var/turf/shelf = locate(8, 10, 1)
	var/turf/open = locate(20, 10, 1)
	dive_check(sea_layer_cell(shelf) && sea_zone_of(shelf) == SEA_ZONE_SHELF && sea_zone_of(open) == SEA_ZONE_OPEN, "the fixture seabed has shelf and open water")

	map.nomads = TRUE
	var/mob/living/human/dive_probe/H = new(locate(2, 10, 2))
	agent_characters[H] = new /datum/agent_character
	dive_check(!H.free_dive(), "nobody dives from dry land")
	H.loc = shelf_top
	dive_check(free_dive_target(shelf_top) == shelf, "the seabed straight below the open sea is the dive target")
	dive_check(isnull(free_dive_target(locate(4, 10, 2))), "nobody dives from the shallows")
	dive_check(!shelf.CanPass(H, shelf), "a surface swimmer cannot step onto the seabed")
	H.swim_tiredness = 90
	dive_check(!H.free_dive() && H.loc == shelf_top, "a tired swimmer cannot dive")
	H.swim_tiredness = 0
	H.swim_breath = 2
	dive_check(!H.free_dive() && H.loc == shelf_top, "a swimmer still catching their breath cannot dive")
	H.swim_breath = -1
	H.loc = locate(20, 10, 2)
	dive_check(!H.free_dive() && H.loc == locate(20, 10, 2), "an ordinary swimmer cannot reach open water on a breath")

	// On the seabed (the dive itself is a two-second wait; its end state here).
	H.free_diving = TRUE
	H.swim_breath = H.swim_breath_max()
	H.loc = shelf
	dive_check(H.can_walk_seabed() && locate(9, 10, 1).CanPass(H, locate(9, 10, 1)), "a free diver swims the shelf")
	dive_check(!open.CanPass(H, open), "an ordinary diver cannot swim out to open water")
	dive_check(H.water_step_delay(shelf) == 20, "an unskilled free diver swims the seabed at the surface speed, not the 3 ds walk")
	dive_check(!H.outside_exposure_step(shelf) && H.getOxyLoss() == 0, "a free diver does not suffocate in the outside air checks")
	H.handle_drowning()
	dive_check(H.free_diving && H.loc == shelf && H.swim_breath == 9 && !H.getOxyLoss(), "a held breath ticks down on the seabed")
	for (var/i = 1, i <= 8, i++)
		H.handle_drowning()
	dive_check(H.free_diving && H.swim_breath == 1, "nine seconds down, one second of breath left")
	H.handle_drowning()
	dive_check(!H.free_diving && H.loc == shelf_top && H.getOxyLoss() == 20, "out of breath, the diver claws for the surface half drowned")
	H.adjustOxyLoss(-200)

	// Under a hull there is no way up.
	var/obj/covers/dive_probe_raft/R = new(shelf_top)
	R.density = FALSE
	dive_check(shelf_top.iscovered(), "the probe raft covers the water above")
	H.free_diving = TRUE
	H.swim_breath = 1
	H.loc = shelf
	H.handle_drowning()
	dive_check(H.free_diving && H.loc == shelf && H.drowning && H.getOxyLoss() == 10, "a breathless diver under a hull drowns in place")
	dive_check(!H.free_dive_surface(), "nobody surfaces into a hull")
	qdel(R)
	H.adjustOxyLoss(-200)
	H.swim_breath = H.swim_breath_max()

	// A strong swimmer reaches open water, and swims the seabed faster.
	H.stats["swimming"] = list(200, 200)
	dive_check(open.CanPass(H, open) && H.water_step_delay(open) == 10, "a skill-200 diver reaches open water at half the step cost")
	dive_check(!locate(30, 10, 1).CanPass(H, locate(30, 10, 1)) || sea_zone_of(locate(30, 10, 1)) <= SEA_ZONE_OPEN, "the deep stays shut to free divers")
	H.stats["swimming"] = list(100, 100)

	// Leaving the sea layer ends the dive.
	H.loc = shelf_top
	H.handle_drowning()
	dive_check(!H.free_diving && !H.drowning, "a diver back on the surface swims again")
	dive_check(swim_water_kind(shelf) == "dive", "the seabed counts as its own kind of water for the first-swim lesson")
