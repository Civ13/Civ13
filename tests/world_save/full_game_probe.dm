var/global/datum/world_save_game_probe/world_save_game_probe = new
/datum/world_save_game_probe/New()
	// This compiled test world has no external adapters configured. Explicitly
	// disable optional outbound hooks before the ordinary startup spawns run.
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(200)
		run_probe()
/datum/world_save_game_probe/proc/run_probe()
	try
		if(!map || !ticker)
			throw EXCEPTION("Game startup did not create map/ticker")
		text2file(json_encode(list("commit" = world.params["tested_commit"], "map_id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "probe_metadata.json")
		if(world.params["player_identity"])
			check_player_identity()
			text2file("PASS: real human constructors preserve owned and legacy identity after deferred spawn", "full_game_result.txt")
			if(!world.params["visual"])
				del(world)
			return
		world.name = "Civ13 LOCAL full-game world-save probe"
		var/turf/T = locate(20,20,1)
		var/saved_turf_type = T.type
		var/obj/structure/closet/crate/C = new(T)
		C.name = "world-save regression crate"
		var/obj/item/weapon/material/kitchen/utensil/knife/K = new(C)
		K.name = "world-save regression knife"
		// Freeze only this named crop to make the full-world persistence assertion
		// independent of normal elapsed growth and ongoing season processing.
		var/turf/floor/dirt/ploughed/soil = new(locate(21,20,1))
		var/obj/structure/farming/plant/tomato/crop = new(soil)
		crop.name = "world-save regression tomato"
		crop.vstatic = TRUE
		crop.stage = 3
		crop.water = 42
		crop.plant_nutrition = 87
		crop.radiation = 3
		soil.soil_nutrition = 123
		var/saved_biomes = jointext(crop.biomes, ",")
		var/saved_seasons = jointext(crop.seasons, ",")
		var/obj/item/stack/farming/seeds/tomato/seeds = new(C, 7)
		seeds.name = "world-save regression seed stock"
		var/obj/map_metadata/original_map = map
		if(!ticker.savemap())
			throw EXCEPTION("Full-game export failed: [map_storage.last_error]")
		crop.stage = 9
		crop.water = 1
		soil.soil_nutrition = 1
		seeds.amount = 1
		var/obj/structure/farming/plant/tomato/original_crop = crop
		T.ChangeTurf(saved_turf_type == /turf/floor/dirt ? /turf/floor/grass : /turf/floor/dirt, FALSE, FALSE)
		if(!ticker.loadmap())
			throw EXCEPTION("Full-game import failed: [map_storage.last_error]")
		sleep(20)
		C = null
		for(var/obj/structure/closet/crate/candidate in locate(20,20,1))
			if(candidate.name == "world-save regression crate")
				C = candidate
		if(!C)
			throw EXCEPTION("Real crate missing after import")
		K = null
		for(var/obj/item/weapon/material/kitchen/utensil/knife/candidate in C)
			if(candidate.name == "world-save regression knife")
				K = candidate
		if(!K || map != original_map || !locate(world.maxx,world.maxy,world.maxz) || locate(20,20,1):type != saved_turf_type)
			throw EXCEPTION("Nested item, metadata identity or boundary turf lost")
		soil = locate(21,20,1)
		if(!istype(soil) || soil.soil_nutrition != 123)
			throw EXCEPTION("Ploughed crop soil or nutrition lost: type=[soil.type], nutrition=[soil.soil_nutrition], expected=123")
		crop = null
		var/crop_count = 0
		for(var/obj/structure/farming/plant/tomato/candidate in soil)
			if(candidate.name == "world-save regression tomato")
				crop = candidate
				crop_count++
		if(crop_count != 1 || crop == original_crop || crop.stage != 3 || crop.water != 42 || crop.plant_nutrition != 87 || crop.radiation != 3 || !crop.vstatic)
			throw EXCEPTION("Crop replacement, unique placement or scalar state lost")
		if(jointext(crop.biomes, ",") != saved_biomes || jointext(crop.seasons, ",") != saved_seasons)
			throw EXCEPTION("Crop climate or season lists lost")
		seeds = null
		for(var/obj/item/stack/farming/seeds/tomato/candidate in C)
			if(candidate.name == "world-save regression seed stock")
				seeds = candidate
		if(!seeds || seeds.amount != 7 || persistence_save_in_progress)
			throw EXCEPTION("Nested seed stock or persistence operation lock lost")
		text2file("PASS: full game constructors, crate, nested knife and seed stock, crop and soil state, metadata, boundary turf", "full_game_result.txt")
		world.log << "PASS: full-game world-save probe"
	catch(var/exception/e)
		text2file(e.name, "full_game_failure.txt")
		text2file("FAIL: [e]", "full_game_result.txt")
		world.log << "FAIL: full-game world-save probe: [e]"
	if(!world.params["visual"])
		del(world)

/datum/world_save_game_probe/proc/check_player_identity()
	if(map.ID != MAP_NOMADS_GAIA)
		throw EXCEPTION("Identity probe requires Gaia")
	var/turf/T = locate(145,71,2)
	var/mob/living/human/fresh = new(T)
	sleep(10)
	// A fresh body must still take the ordinary biome naming path.
	fresh.name = "fresh identity sentinel"
	fresh.nomads_spawn()
	if(fresh.name == "fresh identity sentinel")
		throw EXCEPTION("Fresh human spawn customization skipped")
	for(var/owned in list(FALSE, TRUE))
		fresh.name = "saved identity sentinel"
		fresh.real_name = "saved real identity sentinel"
		fresh.r_hair = 17
		fresh.g_hair = 23
		fresh.b_hair = 31
		fresh.s_tone = -33
		fresh.persistence_owner_ckey = owned ? "testaccount" : null
		var/list/saved_languages = list()
		for(var/datum/language/L in fresh.languages)
			saved_languages += "[L.type]"
		var/savefile/F = new(owned ? "identity-owned.sav" : "identity-legacy.sav")
		F["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 2
		var/ref = map_storage.BuildVarDirectory(F, fresh, 1)
		F.cd = map_storage.entry_path(F, ref)
		if("persistence_restored" in F.dir)
			throw EXCEPTION("Restoration marker exported")
		// Even a crafted old field cannot turn off the runtime marker on import.
		F["persistence_restored"] << list("kind" = "value", "value" = FALSE)
		map_storage.clear_bookkeeping()
		var/mob/living/human/restored = map_storage.Load_Entry(F, ref, starting_loc = T)
		if(restored.name != "saved identity sentinel" || restored.real_name != "saved real identity sentinel")
			throw EXCEPTION("Saved human identity not decoded")
		// Exercise the real constructor's five-tick callback, not a synchronous stub.
		sleep(20)
		if(restored.name != "saved identity sentinel" || restored.real_name != "saved real identity sentinel")
			throw EXCEPTION("Deferred spawn overwrote saved identity")
		if(!restored.persistence_restored || restored.r_hair != 17 || restored.g_hair != 23 || restored.b_hair != 31 || restored.s_tone != -33)
			throw EXCEPTION("Deferred spawn overwrote saved appearance")
		var/list/restored_languages = list()
		for(var/datum/language/L in restored.languages)
			restored_languages += "[L.type]"
		if(jointext(saved_languages, ";") != jointext(restored_languages, ";"))
			throw EXCEPTION("Deferred spawn overwrote saved languages")
		var/savefile/exported = new(owned ? "identity-owned-reexport.sav" : "identity-legacy-reexport.sav")
		exported["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 2
		var/export_ref = map_storage.BuildVarDirectory(exported, restored, 1)
		exported.cd = map_storage.entry_path(exported, export_ref)
		if("persistence_restored" in exported.dir)
			throw EXCEPTION("True restoration marker exported")
		qdel(restored)
	qdel(fresh)
	map_storage.clear_bookkeeping()

/client/verb/inspect_restored_save()
	set category = "Local Verification"
	set name = "Inspect restored save"
	var/result = file2text("full_game_result.txt")
	if(findtext(result, "PASS:") != 1)
		to_chat(src, "Probe has not passed: [result]")
		return
	screen.Cut()
	mob.loc = locate(20,20,1)
	mob.sight = SEE_TURFS | SEE_OBJS | SEE_MOBS | SEE_SELF
	mob.see_in_dark = 8
	eye = mob.loc
	perspective = EYE_PERSPECTIVE
	view = 7
	winset(src, null, "mainwindow.title='Civ13 LOCAL full-game world-save probe'")
	to_chat(src, "<b>[result]</b><br>Commit: [world.params["tested_commit"]]<br>Map: [map.ID], [world.maxx]x[world.maxy]x[world.maxz]. Actual restored crate at (20,20,1), containing the named knife. Local temporary storage, no production services.")
