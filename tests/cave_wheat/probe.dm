// Native cave wheat and diet gate probe, included by
// tests/ecology_spawning/run_linux.py, never by the game DME. It drives the
// production procs in code/modules/1713/cave_wheat.dm and code/modules/diet/diet.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/cave_wheat_probe/New()
	map = src
/mob/living/cave_wheat_tester/New()
	return
var/cw_failures = 0
var/cw_runtime_error = FALSE
/proc/cw_check(condition, label)
	if (!condition)
		cw_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cw_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/cave_wheat_probe
		cave_wheat_checks()
		diet_gate_checks()
	catch(var/exception/e)
		cw_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cw_failures, "runtime_error" = cw_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cw_plot(x, y)
	var/turf/T = locate(x, y, 1)
	T.ChangeTurf(/turf/floor/dirt/ploughed, FALSE, FALSE)
	T.is_plowed = TRUE
	return T

/proc/cave_wheat_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.climate = "temperate"
	A.weather = WEATHER_NONE
	A.icon_state = ""
	var/turf/plot = cw_plot(5, 5)
	var/obj/item/stack/farming/seeds/cave_wheat/S = new(null, 3)

	// Planting admission: indoors or underground only, ploughed soil only.
	A.location = AREA_OUTSIDE
	cw_check(findtext(S.planting_error(plot), "sunlight"), "open sky refuses cave wheat")
	A.location = AREA_INSIDE
	cw_check(isnull(S.planting_error(plot)), "an indoor or underground plot accepts cave wheat")
	var/turf/bare = locate(7, 5, 1)
	bare.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	cw_check(findtext(S.planting_error(bare), "ploughed"), "unploughed ground refuses cave wheat")
	cw_check(findtext(S.icon_state, "cave_wheat-seeds") && S.icon == 'icons/farming/pocket_stronghold_cave_wheat.dmi', "seed sprite")

	// Forage: the seed joins every biome's bush pool like plump helmet spores.
	for (var/biome in list("temperate", "tundra", "taiga", "desert", "jungle", "savanna", "semiarid", "sea"))
		cw_check(biome in S.biomes, "cave wheat seeds can be foraged in [biome]")

	// Growth: every season, half speed, needs a roof, still needs water.
	var/obj/structure/farming/plant/cave_wheat/P = new(plot)
	cw_check(!findtext(P.name, "_"), "plant name reads cave wheat, not cave_wheat")
	for (var/s in list("WINTER", "SPRING", "SUMMER", "FALL", "Wet Season", "Dry Season"))
		cw_check(s in P.seasons, "grows in [s]")
	var/advanced = 0
	for (var/i in 1 to 400)
		P.stage = 1
		P.plant_nutrition = 100
		P.stageGrowth()
		advanced += P.stage - 1
	cw_check(advanced > 120 && advanced < 280, "grows about half as fast as well-fed surface wheat ([advanced]/400)")
	A.location = AREA_OUTSIDE
	P.stage = 2
	for (var/i in 1 to 50)
		P.stageGrowth()
	cw_check(P.stage == 2, "an unroofed plot stops an immature crop")
	A.location = AREA_INSIDE
	P.stage = 2
	P.water = P.max_water
	for (var/i in 1 to 10)
		P.water_proc()
	cw_check(P.stage == 11 && findtext(P.name, "dry"), "without water nearby the crop dries out")
	var/obj/structure/farming/plant/cave_wheat/W = new(cw_plot(10, 10))
	var/turf/well = locate(11, 10, 1)
	well.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	W.water = 1
	for (var/i in 1 to 10)
		W.water_proc()
	cw_check(W.stage < 11 && W.water == W.max_water, "fresh water within two tiles keeps it watered")

	// Harvest: grain is a wheat subtype, so mills, feed and recipes accept it.
	W.stage = W.readyStageMin
	var/mob/living/cave_wheat_tester/U = new(locate(9, 10, 1))
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(U)
	var/turf/field = W.loc
	W.attackby(K, U)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/cave_wheat/G = locate() in field
	var/obj/item/stack/farming/seeds/cave_wheat/back = locate() in field
	cw_check(QDELETED(W) && G && back && back.amount >= 2, "harvest gives cave wheat and at least two seeds")
	cw_check(istype(G, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat), "cave wheat is a wheat subtype (millable, animal feed)")
	cw_check(G.icon == 'icons/farming/pocket_stronghold_cave_wheat.dmi' && G.icon_state == "cave_wheat", "grain sprite")
	var/datum/reagent/N = diet_find_reagent(G.reagents, "nutriment")
	var/list/profile = diet_profile_for(N)
	cw_check(N && profile["carbohydrate"] == 1, "cave wheat counts as carbohydrate")

/proc/diet_gate_checks()
	cw_check(diet_penalties_enabled, "the global penalty switch is on")
	cw_check(!map.diet_penalties && !diet_penalties_active(), "maps without the gate stay penalty-free")
	var/obj/map_metadata/nomads/N = new
	cw_check(N.diet_penalties, "Nomads maps carry the penalty gate")
	map = N
	cw_check(diet_penalties_active(), "penalties apply on Nomads maps")
	diet_penalties_enabled = FALSE
	cw_check(!diet_penalties_active(), "the global switch still turns penalties off")
	diet_penalties_enabled = TRUE
	cw_check(N.persistence_runtime_var("diet_penalties"), "the map gate is not saved")
