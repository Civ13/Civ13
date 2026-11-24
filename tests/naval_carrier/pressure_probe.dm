// Native pressure-pocket assertions on a synthetic sea shelf, with no clients.
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 4
	turf = /turf
	visibility = 0
	sleep_offline = FALSE

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/pressure_probe_fixture
	sea_layer_surface_z = 3
	building_levels = TRUE
/obj/map_metadata/pressure_probe_fixture/New()
	return

/proc/pressure_probe_check(condition, label)
	if (!condition)
		throw EXCEPTION(label)
	world.log << "PASS: [label]"

/proc/pressure_probe_world()
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.nanomanager = new /datum/nanomanager
	job_master = new /datum/controller/occupations()
	ticker = new
	ticker.current_state = GAME_STATE_PLAYING
	processes.time_of_day = new
	processes.weather = new
	map = new /obj/map_metadata/pressure_probe_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	map.times_of_day = list("Morning", "Evening")
	times_of_day = map.times_of_day
	season = "SUMMER"
	time_of_day = "Evening"
	game_id = "synthetic-salvage-pressure"
	var/area/caribbean/nomads/semiarid/base = new
	for (var/turf/T in world)
		base.contents += T
		T.ChangeTurf(T.z <= 2 ? /turf/floor/beach/water/deep/saltwater/underwater/sea_layer : (T.z == 3 ? /turf/floor/beach/water/deep/saltwater : /turf/sky/building), FALSE, FALSE)
	initialize_persistence_zones()
	map_storage.record_compiled_dimensions()
	seabed_zone_pass(1)
	seabed_zone_pass(2)
	hull_ledger_timer_off = TRUE
	pressure_probe_check(multiz_level_below(3) == 2 && multiz_level_below(2) == 1 && sea_layer_cell(locate(4, 4, 2)) && sea_layer_open_surface(locate(4, 4, 3)) && building_open_turf(locate(4, 4, 4)) && seabed_zones_ready, "synthetic navigable shelf exists under the hull")


/proc/pressure_probe()
	pressure_probe_world()
	var/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/D
	// Cabin roof has a walkable upper face. The south hatch opens onto
	// unroofed deck, and the west corner has only ordinary wooden cover.
	for (var/x = 3 to 8)
		for (var/y = 3 to 7)
			var/turf/T = locate(x, y, 3)
			var/obj/covers/steelplating/F = new(T)
			F.updateturf()
			if (x == 3 && y == 3)
				new /obj/structure/roof_support(T)
				var/obj/roof/wood/ordinary = building_construct_roof(T, /obj/roof/wood, null)
				pressure_probe_check(ordinary?.building_floor(), "a plain roof has a genuine upper face")
			if (x < 4 || x > 7 || y < 4 || y > 6)
				continue
			new /obj/structure/roof_support(T)
			var/obj/roof/concrete/R = building_construct_roof(T, /obj/roof/concrete, null)
			pressure_probe_check(R?.building_floor(), "concrete slab has a genuine upper face at [x],[y]")
			if (x == 5 && y == 4)
				D = new(T)
			else if (x == 4 || x == 7 || y == 4 || y == 6)
				new /obj/structure/hull_bulkhead(T)
	var/obj/structure/hull_tiller/H = new(locate(3, 3, 3))
	pressure_probe_check(isnull(H.commission("Cabin test", NORTH)) && H.craft, "steel hull commissions")
	var/datum/hull_ledger/L = H.craft.ledger
	pressure_probe_check(L.pressure_room_intact(locate(5, 5, 3)), "intact watertight cabin is detected afloat")
	pressure_probe_check(!L.pressure_room_intact(locate(3, 3, 3)), "ordinary paired wooden roof is not a pressure shelter")
	L.add_water(L.capacity() * 0.80, L.capacity())
	pressure_probe_check(L.sink() && H.z == 2 && D.z == 2, "original cabin and door descend into the sea")
	var/turf/A = locate(5, 5, 2)
	var/turf/B = locate(6, 5, 2)
	pressure_probe_check(sunken_hull_pressure_sheltered(A) && sunken_hull_pressure_breath(A), "genuine sealed cabin protects and supplies a breath")
	pressure_probe_check(!sunken_hull_pressure_sheltered(locate(3, 3, 2)), "submerged plain cover is not protection")
	// Keep both fixture supports in place for the roofs but exercise an
	// unobstructed floor, then prove a dense object still blocks that step.
	var/obj/structure/roof_support/start_support = locate() in A
	var/obj/structure/roof_support/landing_support = locate() in B
	start_support.density = FALSE
	landing_support.density = FALSE
	var/turf/flooded = locate(6, 7, 2)
	var/turf/door_tile = get_turf(D)
	var/mob/living/human/walker = new(A)
	var/mob/living/human/outsider = new(flooded)
	pressure_probe_check(!walker.can_walk_seabed() && B.Enter(walker), "unsuited crew can step within their sealed pressure pocket")
	landing_support.density = TRUE
	pressure_probe_check(!B.Enter(walker), "a dense obstruction still blocks walking in the sealed pocket")
	landing_support.density = FALSE
	pressure_probe_check(!flooded.CanPass(walker, flooded) && !B.CanPass(outsider, B), "sealed-pocket movement does not give inside crew or outsiders permission to swim through flooded deck")
	pressure_probe_check(!door_tile.Enter(walker), "same-hull movement cannot bypass the closed pressure door")
	for (var/i = 1 to 32)
		pressure_probe_check(sunken_hull_pressure_breath(i % 2 ? A : B, TRUE), "shared room granted breath [i]")
	var/list/saved = L.pressure_to_list()
	L.pressure_from_list(null)
	pressure_probe_check(!sunken_hull_pressure_breath(A), "old submerged save without air never gains fresh air")
	L.pressure_from_list(saved)
	for (var/i = 33 to 60)
		pressure_probe_check(sunken_hull_pressure_breath(i % 2 ? A : B, TRUE), "restored room granted remaining breath [i]")
	pressure_probe_check(!sunken_hull_pressure_breath(A) && !sunken_hull_pressure_breath(B) && sunken_hull_pressure_sheltered(A), "room air is exhausted, but the intact room still blocks seawater")
	pressure_probe_check(B.Enter(walker), "unsuited crew can still walk inside an intact but oxygen-exhausted pocket")
	var/list/exhausted = L.pressure_to_list()
	L.pressure_clear()
	L.pressure_from_list(exhausted)
	pressure_probe_check(sunken_hull_pressure_sheltered(A) && !sunken_hull_pressure_breath(B), "restored zero budget still distinguishes exhausted shelter from a vented room")
	L.pressure_from_list(saved)
	pressure_probe_check(sunken_hull_pressure_breath(B), "restore reestablishes an unvented control")
	// CGI never runs the door animation timer. Apply its state and call
	// the real completion hooks, used by the timer after it changes state.
	D.state = TRUE
	D.door_opened()
	pressure_probe_check(D.state && !sunken_hull_pressure_sheltered(A), "opening the original door vents the cabin")
	pressure_probe_check(!B.Enter(walker), "unsuited crew lose dry walking access once the pocket vents")
	D.state = FALSE
	D.door_closed()
	pressure_probe_check(!D.state && L.pressure_room_intact(A) && !sunken_hull_pressure_breath(A) && !sunken_hull_pressure_sheltered(A), "resealing repairs the shell but does not generate fresh air")
	// An earlier query cached a dry pocket this tick, but a full bilge
	// before the pump ran must still vent it. Block the next depth move so
	// we cannot mistake a change of deck for a loss of air.
	L.pressure_from_list(saved)
	pressure_probe_check(sunken_hull_pressure_breath(A), "dry look caches a pocket with real air before the flooding")
	var/bay = L.bay_at(A)
	var/brim = L.bay_capacity(bay)
	L.add_water(brim, L.capacity(), A)
	pressure_probe_check(brim > 0 && L.water_at(A) >= brim * 0.98, "submerged compartment really reaches the vent threshold")
	new /obj/structure/roof_support(locate(5, 5, 1))
	var/obj/structure/cellar_pump/sump/P = new(A)
	L.step_ledger(30)
	pressure_probe_check(P.running && H.z == 2 && L.depth_disabled && L.water_at(A) < brim * 0.98, "a real powered pump lowers the water on the same submerged deck")
	pressure_probe_check(!sunken_hull_pressure_breath(A) && !sunken_hull_pressure_sheltered(A), "same-step pumping cannot restore air that flooding displaced")

/world/New()
	OpenPort("none")
	if (world.port)
		text2file("FAIL: fixture unexpectedly has a port", "result.txt")
		del(world)
		return
	try
		pressure_probe()
		text2file("PASS: pressure probe", "result.txt")
	catch (var/exception/e)
		world.log << "FAIL: [e] [e.file]:[e.line]"
		text2file("FAIL: [e] [e.file]:[e.line]", "result.txt")
	del(world)
