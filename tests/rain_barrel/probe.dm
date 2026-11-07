/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

// Actor startup only; barrels, reagents, temperature, area/roof eligibility,
// the legacy collector conversion and persistence remain production code.
/mob/living/human/rain_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build

/mob/living/human/rain_tester/religion_check()
	return "none"

/obj/map_metadata/rain_tester/New()
	return

// Roof presence is checked by production code; its area/lighting constructor
// is outside this isolated fixture and area exposure is tested separately.
/obj/roof/rain_tester/New()
	return

/proc/rain_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "RAIN PASS: [message]"

// Advance the clock adapter by one normal interval while retaining production
// throttling. This is nominal game time, not a wall-time performance measurement.
/proc/rain_step(obj/item/weapon/reagent_containers/glass/barrel/B, count = 1)
	for (var/i in 1 to count)
		B.last_collection_tick = world.time - 20
		if (B.process_interval(2) == PROCESS_KILL)
			processing_objects -= B

/proc/rain_registrations(atom/A)
	. = 0
	for (var/obj/O in processing_objects)
		if (O == A)
			.++

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "dimensions" = "8x8x1", "network" = "closed", "startup" = "disabled")), "fixture.json")
		var/turf/site = locate(3,3,1)
		var/area/A = get_area(site)
		A.location = AREA_OUTSIDE
		A.weather = WEATHER_NONE
		A.icon_state = ""
		season = "SPRING"
		time_of_day = "Night"
		map = new /obj/map_metadata/rain_tester
		map.ordinal_age = 0
		var/mob/living/human/rain_tester/U = new(site)
		var/legacy_recipe = FALSE
		for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
			if (findtext(line, "reagent_dispensers/dew_collector"))
				legacy_recipe = TRUE
		rain_assert(!legacy_recipe, "dew collector recipe retired")
		var/obj/item/weapon/reagent_containers/glass/barrel/B = new(site)
		rain_assert(B.is_open_container() && B.reagents.total_volume == 0 && rain_registrations(B) == 1, "new open barrel registered once")
		rain_assert(B.collection_rate() == 2, "clear night dew rate")
		B.last_collection_tick = world.time - 6000
		B.process_interval(600)
		rain_assert(B.reagents.total_volume == 0 && B.collection_seconds <= 2, "delayed tick cannot replay backlog")
		B.collection_seconds = 0
		rain_step(B, 29)
		rain_assert(B.reagents.total_volume == 0, "no early yield")
		rain_step(B)
		rain_assert(B.reagents.get_reagent_amount("water") == 2, "one minute dew yield")
		B.process_interval(2)
		rain_assert(B.collection_seconds == 0, "same tick no duplicate credit")
		A.location = AREA_INSIDE
		rain_assert(B.collection_rate() == 0, "indoors rejected")
		A.location = AREA_OUTSIDE
		var/obj/roof/rain_tester/R = new(site)
		rain_assert(B.collection_rate() == 0, "roof rejected")
		// This adapter has no roof overlays/area transition to tear down.
		R.loc = null
		B.radiation = 1
		rain_assert(B.collection_rate() == 0, "radiation rejected")
		B.radiation = 0
		time_of_day = "Midday"
		rain_assert(B.collection_rate() == 0, "daylight dew rejected")
		A.weather = WEATHER_WET
		A.icon_state = "snow1"
		rain_assert(B.collection_rate() == 0, "wet snow is not rain")
		A.icon_state = "rain2"
		rain_assert(B.collection_rate() == 10, "rain collection rate")
		B.collection_seconds = 58
		rain_step(B)
		rain_assert(B.reagents.total_volume == 2 && B.collection_seconds == 2, "rate change cancels partial minute")
		rain_step(B, 29)
		rain_assert(B.reagents.get_reagent_amount("water") == 12, "one minute rain yield")
		B.reagents.clear_reagents()
		B.reagents.add_reagent("water", B.volume - 1)
		rain_step(B, 30)
		rain_assert(B.reagents.total_volume == B.volume, "capacity bounds collection")
		rain_step(B, 60)
		rain_assert(B.reagents.total_volume == B.volume && B.collection_seconds == 0, "full barrel has no backlog")
		B.reagents.remove_reagent("water", 50)
		B.loc = U
		rain_assert(B.collection_rate() == 0, "carried barrel collects nothing")
		B.loc = site
		map.heat_wave = TRUE
		rain_assert(B.collection_rate() == 0, "heatwave rejected")
		map.heat_wave = FALSE
		season = "WINTER"
		rain_assert(B.collection_rate() == 0, "frozen collection rejected")
		season = "SPRING"
		B.collection_seconds = 58
		B.attack_self(U)
		rain_assert(!B.is_open_container() && B.collection_seconds == 0 && B.collection_rate() == 0, "lid stops collection")
		rain_step(B)
		rain_assert(!rain_registrations(B), "closed barrel leaves the object loop")
		var/before = B.reagents.total_volume
		rain_step(B, 60)
		rain_assert(B.reagents.total_volume == before, "closed barrel collects nothing")
		B.attack_self(U)
		rain_assert(B.is_open_container() && rain_registrations(B) == 1, "opening the lid re-registers once")
		B.attack_self(U)
		var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/J = new(site)
		J.flags |= OPENCONTAINER
		rain_assert(!J.collection_rate(), "open jerrycan collects nothing")
		rain_step(J)
		rain_assert(!rain_registrations(J), "jerrycan leaves the object loop")
		var/obj/item/weapon/reagent_containers/glass/barrel/water/W = new(site)
		rain_assert(!W.is_open_container() && W.collection_rate() == 0, "sealed water barrel stays sealed")
		var/obj/item/weapon/reagent_containers/glass/barrel/modern/S = new(site)
		rain_assert(S.collection_rate() == 10, "open steel barrel collects rain")
		B.collection_seconds = 58
		for (var/key in list("collection_seconds", "collection_mode", "last_collection_tick"))
			rain_assert(!(key in B.get_saved_vars()) && B.persistence_runtime_var(key), "runtime field excluded: [key]")
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("rain-state.sav")
		F["/format_version"] << 2
		var/id = map_storage.BuildVarDirectory(F, B, 1)
		var/obj/structure/reagent_dispensers/dew_collector/D = new(site)
		D.reagents.add_reagent("water", 120)
		D.collecting = FALSE
		var/legacy_id = map_storage.BuildVarDirectory(F, D, 1)
		F.Flush()
		F = null
		F = new("rain-state.sav")
		map_storage.clear_bookkeeping()
		var/obj/item/weapon/reagent_containers/glass/barrel/loaded = map_storage.Load_Entry(F, id, starting_loc = site)
		rain_assert(loaded && !loaded.is_open_container() && loaded.reagents.get_reagent_amount("water") == before && loaded.collection_seconds == 0, "real reagent contents and lid disk round trip")
		rain_assert(rain_registrations(loaded) == 1, "loaded barrel registered exactly once")
		rain_step(loaded)
		rain_assert(!rain_registrations(loaded), "loaded closed barrel leaves the object loop")
		map_storage.clear_bookkeeping()
		var/obj/structure/reagent_dispensers/dew_collector/legacy = map_storage.Load_Entry(F, legacy_id, starting_loc = site)
		rain_assert(legacy && !legacy.collecting && legacy.reagents.get_reagent_amount("water") == 120 && rain_registrations(legacy) == 1, "legacy collector loads from disk")
		for (var/obj/item/weapon/reagent_containers/glass/barrel/old in site)
			if (old != B && old != J && old != W && old != S && old != loaded)
				throw EXCEPTION("unexpected barrel before conversion")
		rain_assert(legacy.process_interval(2) == PROCESS_KILL && QDELETED(legacy), "legacy collector retires on its first tick")
		var/obj/item/weapon/reagent_containers/glass/barrel/converted
		for (var/obj/item/weapon/reagent_containers/glass/barrel/candidate in site)
			if (candidate != B && candidate != J && candidate != W && candidate != S && candidate != loaded)
				converted = candidate
		rain_assert(converted && converted.type == /obj/item/weapon/reagent_containers/glass/barrel && converted.reagents.get_reagent_amount("water") == 120, "legacy collector keeps its water")
		rain_assert(!converted.is_open_container(), "closed legacy collector becomes a closed barrel")
		var/obj/structure/reagent_dispensers/dew_collector/open_legacy = new(site)
		open_legacy.reagents.add_reagent("water", 30)
		open_legacy.process_interval(2)
		var/obj/item/weapon/reagent_containers/glass/barrel/open_converted
		for (var/obj/item/weapon/reagent_containers/glass/barrel/candidate in site)
			if (candidate.is_open_container() && candidate.reagents.get_reagent_amount("water") == 30)
				open_converted = candidate
		rain_assert(open_converted && rain_registrations(open_converted) == 1 && open_converted.collection_rate() == 10, "open legacy collector becomes a collecting barrel")
		map_storage.clear_bookkeeping()
		text2file("PASS: rain barrel and native disk round trips", "result.txt")
	catch (var/exception/E)
		world.log << "RAIN exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
