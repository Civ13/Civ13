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
/mob/living/human/dive_probe/update_hair(update_icons = 1)
	return
/mob/living/human/dive_probe/update_inv_head(update_icons = 1)
	return
/mob/living/human/dive_probe/handle_hud_list()
	return
/mob/living/human/dive_probe/update_inv_wear_mask(update_icons = 1)
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
	var/turf/shallows = locate(4, 10, 2)
	H.loc = shallows
	dive_check(H.updown_offer(H, DOWN) != "Dive", "the shallows offer no Dive")
	H.loc = shelf_top
	dive_check(!shelf.CanPass(H, shelf), "a surface swimmer cannot step onto the seabed")
	H.swim_tiredness = 90
	dive_check(H.updown_offer(H, DOWN) == "Dive" && isnull(H.updown_offer(H, UP)), "over the seabed the down button offers Dive")
	dive_check(!H.updown_press(H, DOWN) && H.loc == shelf_top, "a tired swimmer pressing down does not dive")
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
	dive_check(H.updown_offer(H, UP) == "Surface" && isnull(H.updown_offer(H, DOWN)), "on the seabed the up button offers Surface")
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

	// Scuba (scuba.dm): mask and set breathe for the diver, open water at any skill.
	H.stats["swimming"] = list(100, 100)
	var/obj/item/clothing/mask/dive_mask/mask = new
	var/obj/item/pressure_tank/scuba/scuba_set = new
	H.wear_mask = mask
	dive_check(!H.scuba_ready(), "a mask alone breathes nothing")
	H.back = scuba_set
	dive_check(H.scuba_ready() && H.free_dive_zone_limit() == SEA_ZONE_OPEN, "mask and scuba set reach open water at skill 100")
	dive_check(abs(H.scuba_air_rate() - 3) < 0.01 && round(scuba_set.air_seconds / H.scuba_air_rate(), 1) == 600, "a full set lasts ten minutes at skill 100 ([scuba_set.air_seconds] [H.scuba_air_rate()])")
	H.stats["swimming"] = list(200, 200)
	dive_check(round(scuba_set.air_seconds / H.scuba_air_rate(), 1) == 849, "a skill-200 swimmer makes it last about fourteen minutes ([scuba_set.air_seconds / H.scuba_air_rate()])")
	H.stats["swimming"] = list(100, 100)
	H.free_diving = TRUE
	H.loc = open
	H.swim_breath = -1
	for (var/i = 1, i <= 60, i++)
		H.handle_drowning()
	dive_check(H.free_diving && H.loc == open && H.swim_breath < 0 && !H.getOxyLoss(), "a scuba diver stays down a minute without holding their breath")
	dive_check(H.nitrogen_load == 90 && scuba_set.air_seconds == 1800 - 180, "a minute in open water: 90 nitrogen and three minutes of air")
	// Surfacing straight up from there gives the bends.
	H.loc = locate(20, 10, 1)
	dive_check(H.free_dive_surface(TRUE) && H.bends == 30 && !H.nitrogen_load, "surfacing with 90 nitrogen gives bends of 30")
	H.adjustOxyLoss(-200)
	var/stamina = H.stats["stamina"][1]
	H.handle_drowning()
	dive_check(H.bends == 29.5 && H.stats["stamina"][1] < stamina, "the bends sap strength and pass slowly ([H.bends])")
	H.bends = 0
	// (The fixture body has no organs, so the bends' harm reads as death here.)
	H.stat = CONSCIOUS
	H.health = H.maxHealth
	// A stop on the shelf clears the load.
	H.free_diving = TRUE
	H.loc = shelf
	H.nitrogen_load = 90
	for (var/i = 1, i <= 30, i++)
		H.handle_drowning()
	dive_check(H.nitrogen_load == 60, "thirty seconds on the shelf release 30 nitrogen ([H.nitrogen_load] [H.free_diving] [H.loc])")
	H.loc = shelf
	dive_check(H.free_dive_surface(TRUE) && !H.bends, "surfacing at the safe load gives no bends")
	// An empty set falls back on the held breath.
	scuba_set.air_seconds = 0
	H.free_diving = TRUE
	H.loc = shelf
	H.swim_breath = -1
	dive_check(!H.scuba_ready(), "an empty set breathes nothing")
	H.handle_drowning()
	dive_check(H.free_diving && H.swim_breath == 9, "with the set empty the diver holds their breath ([H.free_diving] [H.swim_breath])")
	// Holding their breath adds no nitrogen in open water (#6750), but the shelf still releases it.
	H.loc = open
	H.nitrogen_load = 60
	H.swim_breath = -1
	H.handle_drowning()
	dive_check(H.free_diving && H.nitrogen_load == 60, "a breath-holding diver in open water gains no nitrogen ([H.nitrogen_load])")
	H.loc = shelf
	H.handle_drowning()
	dive_check(H.nitrogen_load == 59, "a breath-holding diver on the shelf still releases nitrogen ([H.nitrogen_load])")
	H.nitrogen_load = 0
	H.free_diving = FALSE
	H.loc = shelf_top
	// Fins: faster swimming, clumsy on land.
	var/obj/item/clothing/shoes/swim_fins/fins = new
	H.shoes = fins
	dive_check(H.water_step_delay(locate(8, 10, 2)) == 12, "fins cut the unskilled swim step from 20 to 12 ds")
	dive_check(footwear_offsnow_slowdown(H, locate(2, 10, 2)) == 1.5 && footwear_offsnow_slowdown(H, locate(8, 10, 2)) == 0, "fins cost 1.5 ds a step on land and nothing in the water")
	H.stats["swimming"] = list(250, 250)
	dive_check(H.water_step_delay(locate(8, 10, 2)) == 8, "fins never beat the 8 ds floor")
	H.stats["swimming"] = list(100, 100)
