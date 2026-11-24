// Whole-world production save/load for a commissioned ship; run the writer
// and reader in separate confined processes, sharing only the synthetic save.
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

/obj/map_metadata/salvage_roundtrip_fixture
	sea_layer_surface_z = 3
	building_levels = TRUE
/obj/map_metadata/salvage_roundtrip_fixture/New()
	return

/obj/item/salvage_roundtrip_cargo
	name = "salvage fixture manifest"
	var/manifest_serial = "original"

/obj/structure/salvage_roundtrip_blocker
	density = TRUE
	anchored = TRUE

/proc/salvage_roundtrip_check(condition, label)
	if (!condition)
		throw EXCEPTION(label)
	world.log << "PASS: [label]"

/proc/salvage_roundtrip_world()
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new
	movementMachine = new
	GLOB.nanomanager = new /datum/nanomanager
	job_master = new /datum/controller/occupations()
	ticker = new
	ticker.current_state = GAME_STATE_PLAYING
	processes.time_of_day = new
	processes.weather = new
	map = new /obj/map_metadata/salvage_roundtrip_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	map.times_of_day = list("Morning", "Evening")
	times_of_day = map.times_of_day
	season = "SUMMER"
	time_of_day = "Evening"
	game_id = "synthetic-salvage-roundtrip"
	var/area/caribbean/nomads/semiarid/base = new
	for (var/turf/T in world)
		base.contents += T
		T.ChangeTurf(T.z <= 2 ? /turf/floor/beach/water/deep/saltwater/underwater/sea_layer : (T.z == 3 ? /turf/floor/beach/water/deep/saltwater : /turf/sky/building), FALSE, FALSE)
	initialize_persistence_zones()
	map_storage.record_compiled_dimensions()
	seabed_zone_pass(1)
	seabed_zone_pass(2)
	hull_ledger_timer_off = TRUE
	salvage_roundtrip_check(multiz_level_below(3) == 2 && multiz_level_below(2) == 1 && sea_layer_cell(locate(4, 4, 2)) && sea_layer_open_surface(locate(4, 4, 3)) && building_open_turf(locate(4, 4, 4)) && seabed_zones_ready, "synthetic navigable shelf exists under the hull")

/proc/salvage_roundtrip_write(physical_only = FALSE)
	for (var/x = 3 to 6)
		for (var/y = 3 to 6)
			var/obj/covers/repairedfloor/ship/P = new(locate(x, y, 3))
			P.updateturf()
	new /obj/structure/roof_support(locate(4, 4, 3))
	var/obj/roof/roof = building_construct_roof(locate(4, 4, 3), /obj/roof/wood, null)
	salvage_roundtrip_check(roof && roof.building_floor(), "commissioned fixture has a real paired upper deck")
	var/obj/covers/hold = hull_hold_lay(locate(5, 5, 2))
	salvage_roundtrip_check(hold, "fixture has a real hold floor in linked sea terrain")
	var/obj/structure/hull_tiller/T = new(locate(3, 3, 3))
	salvage_roundtrip_check(isnull(T.commission("Sounder", EAST)) && T.craft, "fixture ship commissioned")
	var/datum/craft/C = T.craft
	var/datum/craft_body/built/B = C.body
	var/datum/hull_ledger/L = C.ledger
	var/obj/structure/closet/crate/chest = new(locate(5, 5, 2))
	var/obj/item/salvage_roundtrip_cargo/manifest = new(chest)
	manifest.manifest_serial = "unique-1452"
	var/mob/living/human/inside = new(locate(4, 4, 3))
	inside.real_name = "Sounder Cabin"
	inside.name = inside.real_name
	var/mob/living/human/above = new(locate(4, 4, 4))
	above.real_name = "Sounder Upper Deck"
	above.name = above.real_name
	var/obj/structure/salvage_roundtrip_blocker/blocker = new(locate(5, 4, 2))
	L.add_water(L.capacity(), L.capacity())
	salvage_roundtrip_check(L.sink(), "loss of buoyancy starts foundering")
	salvage_roundtrip_check(L.depth_disabled && B.z == 3 && chest.z == 2 && roof.z == 3 && inside.z == 3 && above.z == 4, "blocked footprint leaves hull, crew and cargo unchanged")
	salvage_roundtrip_check(manifest.loc == chest && roof.building_floor().z == 4 && craft_holding(locate(3, 3, 3)) == C, "blocked descent preserves containment, roof pairing and registration")
	qdel(blocker)
	salvage_roundtrip_check(L.step_hull_depth() && B.z == 2 && T.z == 2 && T.craft == C, "same commissioned body descends onto the seabed")
	salvage_roundtrip_check(inside.z == 2 && above.z == 3 && manifest.loc == chest && chest.z == 1 && B.lower_tile_count() == 1, "crew stay on their relative decks and nested cargo stays in the original hold chest")
	salvage_roundtrip_check(roof.z == 2 && roof.building_floor() && roof.building_floor().z == 3, "upper floor retains its roof pairing on the seabed")
	salvage_roundtrip_check(!L.step_hull_depth() && B.z == 2 && L.depth_disabled, "the next descent cannot strand her hold below the bottom")
	salvage_roundtrip_check(!C.order_turn(NORTH) && C.speed == VESSEL_SPEED_STOP, "ship cannot make way while it lacks buoyancy")
	if (physical_only)
		salvage_roundtrip_refloat(T, chest, manifest, roof, inside, above)
		return
	salvage_roundtrip_check(ticker.savemap() && fexists("map_saves/save_complete.txt"), "production saver publishes a complete submerged generation")

/proc/salvage_roundtrip_read()
	salvage_roundtrip_check(fexists("map_saves/save_complete.txt"), "fresh reader sees writer's complete generation")
	salvage_roundtrip_check(ticker.loadmap(), "production loader restores the previous process's generation: [map_storage.last_error]")
	var/obj/structure/hull_tiller/T = locate() in locate(3, 3, 2)
	salvage_roundtrip_check(T?.craft?.ledger, "restore republishes the original ship with one live tiller and ledger")
	var/datum/craft/C = T.craft
	var/datum/craft_body/built/B = C.body
	var/datum/hull_ledger/L = C.ledger
	var/obj/structure/closet/crate/chest = locate() in locate(5, 5, 1)
	var/obj/item/salvage_roundtrip_cargo/manifest = locate() in chest
	var/obj/roof/roof = locate() in locate(4, 4, 2)
	var/mob/living/human/inside = locate() in locate(4, 4, 2)
	var/mob/living/human/above = locate() in locate(4, 4, 3)
	salvage_roundtrip_check(C.name == "Sounder" && B.dir == EAST && B.z == 2 && B.tile_count() == 16 && L.depth_disabled && L.fill() >= 0.98, "identity, heading, footprint, buoyancy state and water survive reload")
	salvage_roundtrip_check(inside?.real_name == "Sounder Cabin" && above?.real_name == "Sounder Upper Deck" && manifest?.manifest_serial == "unique-1452", "crew and nested cargo survive in their original deck-relative slots")
	salvage_roundtrip_check(roof?.building_floor()?.z == 3 && B.upper_tile_count() == 1 && B.lower_tile_count() == 1 && craft_holding(locate(3, 3, 2)) == C, "cross-level roof pair and hull membership survive reload")
	var/marker_count = 0
	for (var/obj/item/salvage_roundtrip_cargo/M in world)
		if (M.manifest_serial == "unique-1452")
			marker_count++
	salvage_roundtrip_check(marker_count == 1, "persisted cargo was not duplicated")
	salvage_roundtrip_refloat(T, chest, manifest, roof, inside, above)
	salvage_roundtrip_check(ticker.savemap(), "production saver accepts the resurfaced generation")

/proc/salvage_roundtrip_refloat(obj/structure/hull_tiller/T, obj/structure/closet/crate/chest, obj/item/salvage_roundtrip_cargo/manifest, obj/roof/roof, mob/living/human/inside, mob/living/human/above)
	var/datum/craft/C = T.craft
	var/datum/craft_body/built/B = C.body
	var/datum/hull_ledger/L = C.ledger
	var/turf/leak = locate(5, 4, 2)
	var/obj/covers/P = locate() in leak
	salvage_roundtrip_check(P, "submerged hull contains its original floor")
	qdel(P)
	salvage_roundtrip_check(L.hole_at(leak), "loss of the original floor registers a real breach")
	L.remove_water(L.capacity())
	salvage_roundtrip_check(!L.step_hull_depth() && L.depth_disabled, "an unpatched breach cannot refloat the fully pumped hull")
	var/obj/item/stack/material/wood/timber = new(locate(4, 3, 2))
	timber.amount = 5
	var/obj/covers/patch = hull_patch_lay(C, timber, leak)
	salvage_roundtrip_check(patch && !L.holes && timber.amount == 3, "production patch closes breach and takes exactly two wood")
	salvage_roundtrip_check(L.step_hull_depth() && B.z == 3 && !L.depth_disabled && T.craft == C, "patched and pumped hull resurfaces without replacement")
	salvage_roundtrip_check(inside.z == 3 && above.z == 4 && chest.z == 2 && manifest.loc == chest && roof.building_floor().z == 4, "the original crew, cargo, and deck geometry rise with the hull")
	salvage_roundtrip_check(!craft_holding(locate(3, 3, 2)) && craft_holding(locate(3, 3, 3)) == C, "refloat leaves no ghost hull on the seabed")

/world/New()
	OpenPort("none")
	if (world.port)
		text2file("FAIL: fixture unexpectedly has a port", "result.txt")
		del(world)
		return
	var/mode = world.params["salvage_mode"]
	try
		salvage_roundtrip_world()
		if (mode == "writer")
			salvage_roundtrip_write()
		else if (mode == "physical")
			salvage_roundtrip_write(TRUE)
		else if (mode == "reader")
			salvage_roundtrip_read()
		else
			throw EXCEPTION("Expected writer, reader or physical mode")
		text2file("PASS: [mode]", "result.txt")
	catch (var/exception/e)
		world.log << "FAIL: [e] [e.file]:[e.line]"
		text2file("FAIL: [e] [e.file]:[e.line]", "result.txt")
	del(world)
