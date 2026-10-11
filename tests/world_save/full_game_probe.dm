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
		world.name = "Civ13 LOCAL full-game world-save probe"
		var/turf/T = locate(20,20,1)
		var/obj/structure/closet/crate/C = new(T)
		C.name = "world-save regression crate"
		var/obj/item/weapon/material/kitchen/utensil/knife/K = new(C)
		K.name = "world-save regression knife"
		var/obj/map_metadata/original_map = map
		if(!ticker.savemap())
			throw EXCEPTION("Full-game export failed: [map_storage.last_error]")
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
		if(!K || map != original_map || !locate(world.maxx,world.maxy,world.maxz))
			throw EXCEPTION("Nested item, metadata identity or boundary turf lost")
		text2file("PASS: full game constructors, crate, nested knife, metadata, boundary turf", "full_game_result.txt")
		world.log << "PASS: full-game world-save probe"
	catch(var/exception/e)
		text2file("FAIL: [e]", "full_game_result.txt")
		world.log << "FAIL: full-game world-save probe: [e]"
	if(!world.params["visual"])
		del(world)

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
	to_chat(src, "<b>[result]</b><br>Actual restored crate at (20,20,1), containing the named knife. Local temporary storage, no production services.")
