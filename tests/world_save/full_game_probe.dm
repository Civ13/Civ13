var/global/datum/world_save_game_probe/world_save_game_probe = new

// Keep targets stable during the yielding serializer. Constructors, movement,
// exclusion hooks and the exporter/importer are production implementations.
/mob/living/simple_animal/frog/persistence_pointer_probe/Life()
	return

/mob/living/human/persistence_action_probe/Life()
	return

/datum/world_save_game_probe/proc/check_action_restore()
	var/turf/home = locate(24,20,1)
	var/mob/living/human/persistence_action_probe/holder = new(home)
	holder.persistence_restored = TRUE
	holder.stunned = 7
	holder.mouth_covered = TRUE
	var/obj/item/weapon/attachment/scope/adjustable/binoculars/scope = new(holder)
	holder.l_hand = scope
	scope.on_changed_slot()
	var/obj/item/turret_controls/controls = new(holder)
	holder.r_hand = controls
	controls.azoom.Grant(holder)
	var/obj/item/garrote/garrote = new(holder)
	garrote.garroting = TRUE
	garrote.next_garrote = world.time + 400
	garrote.update_icon()
	var/obj/item/flashlight/light = new(holder)
	light.action_button_name = "fixture flashlight"
	holder.handle_actions()
	var/map_storage/storage = new("action-fixture")
	storage.saving_z = 1
	var/savefile/F = new("runtime-actions.sav")
	F["/format_version"] << 3
	var/ref = storage.BuildVarDirectory(F, holder, 1)
	for(var/obj/item/I in list(scope, controls, garrote, light))
		var/item_ref = storage.saving_references["\ref[I]"]
		if(!item_ref) throw EXCEPTION("Action fixture item was not saved")
		F.cd = storage.entry_path(F, item_ref)
		if("actions" in F.dir || "action" in F.dir || (I == controls && "azoom" in F.dir))
			throw EXCEPTION("Constructor action graph was exported")
		// Legacy null action entries must never replace constructor graphs.
		F["actions"] << list("kind" = "entry", "ref" = 999996)
		F["action"] << list("kind" = "entry", "ref" = 999997)
		if(I == controls) F["azoom"] << list("kind" = "entry", "ref" = 999998)
		if(I == garrote)
			F["garroting"] << list("kind" = "value", "value" = TRUE)
	F.cd = storage.entry_path(F, ref)
	F["mouth_covered"] << list("kind" = "value", "value" = TRUE)
	storage.clear_bookkeeping()
	storage.loading_z = 1
	var/mob/living/human/restored = storage.Load_Entry(F, ref, null, home)
	for(var/datum/loaded in storage.all_loaded.Copy()) loaded.after_load()
	var/obj/item/weapon/attachment/scope/restored_scope = restored.l_hand
	var/obj/item/turret_controls/restored_controls = restored.r_hand
	if(!istype(restored_scope) || !restored_scope.azoom || !(restored_scope.azoom in restored_scope.actions) || restored_scope.azoom.owner != restored || !(restored_scope.azoom in restored.actions))
		throw EXCEPTION("Restored held binoculars lost constructor action or grant")
	if(!istype(restored_controls) || !restored_controls.azoom || restored_controls.azoom.scope != restored_controls.optics || restored_controls.azoom.owner != restored || !(restored_controls.azoom in restored_controls.actions))
		throw EXCEPTION("Restored turret controls lost action, optics binding or grant")
	var/obj/item/garrote/restored_garrote = locate() in restored
	var/obj/item/flashlight/restored_light = locate() in restored
	if(!restored_garrote || restored_garrote.garroting || restored_garrote.next_garrote || restored_garrote.icon_state != initial(restored_garrote.icon_state) || restored.mouth_covered || restored.stunned != 7)
		throw EXCEPTION("Discarded grab/garrote state survived or unrelated restriction changed")
	if(!restored_light || !restored_light.action || restored_light.action.owner != restored || restored_light.action.target != restored_light)
		throw EXCEPTION("Generic restored item action was not regenerated")
	if(!holder.mouth_covered || !garrote.garroting || controls.azoom.owner != holder || scope.azoom.owner != holder)
		throw EXCEPTION("Export/import mutated original live owners")
	qdel(holder)
	qdel(restored)
	storage.clear_bookkeeping()
	text2file("PASS: constructor scope/turret/generic action graphs and grants restored; grab dependents discarded", "runtime_action_result.txt")

/datum/world_save_game_probe/proc/check_runtime_pointers()
	if(world.maxz < 2)
		throw EXCEPTION("Pointer regression requires two isolated levels")
	var/turf/home = locate(23,20,1)
	var/mob/living/simple_animal/frog/persistence_pointer_probe/actor = new(home)
	var/mob/living/simple_animal/frog/persistence_pointer_probe/target = new(home)
	actor.LAssailant = target
	actor.target_mob = target
	actor.target_obj = target
	actor.pathfind_target = target
	actor.stance = HOSTILE_STANCE_ATTACK
	actor.moving = TRUE
	actor.found_path = list(home)
	if(!target.forceMove(locate(23,20,2)) || target.z != 2)
		throw EXCEPTION("Pointer regression could not move target across z")
	if(!ticker.savemap())
		throw EXCEPTION("Cross-z AI pointer blocked world save: [map_storage.last_error]")
	var/map_storage/storage = new("pointer-fixture")
	storage.saving_z = 1
	var/savefile/F = new("runtime-pointers.sav")
	F["/format_version"] << 3
	var/ref = storage.BuildVarDirectory(F, actor, 1)
	F.cd = storage.entry_path(F, ref)
	for(var/key in list("LAssailant", "target_mob", "target_obj", "pathfind_target", "stance", "moving", "found_path"))
		if(key in F.dir)
			throw EXCEPTION("Runtime pointer or dependent AI state was exported: [key]")
	if(actor.target_mob != target || actor.target_obj != target || actor.pathfind_target != target || actor.LAssailant != target || actor.stance != HOSTILE_STANCE_ATTACK || !actor.moving)
		throw EXCEPTION("Export mutated live AI pointers or stance")
	// Historical payloads must be skipped before decoding a dangling reference.
	F["target_mob"] << list("kind" = "entry", "ref" = 999999)
	F["stance"] << list("kind" = "value", "value" = HOSTILE_STANCE_ATTACK)
	storage.clear_bookkeeping()
	storage.loading_z = 1
	var/mob/living/simple_animal/restored = storage.Load_Entry(F, ref, null, home)
	if(!restored || restored.target_mob || restored.stance != initial(restored.stance) || restored.moving)
		throw EXCEPTION("Historical pointer import restored orphaned AI state")
	qdel(actor)
	qdel(target)
	qdel(restored)
	storage.clear_bookkeeping()
	text2file("PASS: real frog cross-z pointers omitted without live mutation; legacy AI state ignored", "runtime_pointer_result.txt")

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
		check_action_restore()
		check_runtime_pointers()
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
