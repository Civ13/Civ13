// Opt-in only. This file is not included by production civ13.dme.
var/global/datum/conveyor_game_probe/conveyor_game_probe = new
/datum/conveyor_game_probe/New()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(200)
		run_probe()
/datum/conveyor_game_probe/proc/run_probe()
	try
		if(!map || !ticker)
			throw EXCEPTION("Game startup did not create map/ticker")
		text2file(json_encode(list("commit"=world.params["tested_commit"], "map_id"=map.ID, "maxx"=world.maxx, "maxy"=world.maxy, "maxz"=world.maxz, "byond_version"=world.byond_version, "byond_build"=world.byond_build)), "probe_metadata.json")
		var/turf/T = locate(20,20,1)
		var/obj/machinery/conveyor/C = new(T, EAST, TRUE)
		var/obj/item/weapon/material/kitchen/utensil/knife/K = new(T)
		K.name = "conveyor regression knife"
		var/obj/item/weapon/material/kitchen/utensil/knife/F = new(T)
		F.anchored = TRUE
		// Move onto known passable turfs in this private test world.
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		get_step(C, EAST).ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		C.process()
		if(K.loc != C.loc)
			throw EXCEPTION("Cargo moved before the one-tick delay")
		sleep(2)
		if(K.loc != get_step(C, EAST) || F.loc != C.loc)
			throw EXCEPTION("Movement or anchored cargo contract failed")
		C.operating = FALSE
		C.process()
		sleep(2)
		if(K.loc != get_step(C, EAST))
			throw EXCEPTION("Stopped belt moved cargo")
		if("affecting" in C.vars)
			throw EXCEPTION("Conveyor retains a snapshot field")
		qdel(K)
		qdel(F)
		qdel(C)
		text2file("PASS: real conveyor constructor, delayed movement, anchored cargo, stop, no retained snapshot field", "game_result.txt")
		world.log << "PASS: conveyor full-game probe"
	catch(var/exception/e)
		text2file("FAIL: [e]", "game_result.txt")
		world.log << "FAIL: conveyor full-game probe: [e]"
	del(world)
