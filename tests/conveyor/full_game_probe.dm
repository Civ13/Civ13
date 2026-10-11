// Opt-in only. This file is not included by production civ13.dme.
var/global/datum/conveyor_game_probe/conveyor_game_probe = new
/datum/conveyor_game_probe
	var/obj/machinery/conveyor/visual_belt
	var/obj/machinery/conveyor_switch/visual_switch
	var/obj/item/visual_cargo
	var/obj/item/visual_fixed
	var/sequence_running = FALSE
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
		if(world.params["exercise_capture"] )
			prepare_visual()
			if(!capture_sequence(null))
				throw EXCEPTION("Offline capture sequence failed")
		text2file("PASS: real conveyor constructor, delayed movement, anchored cargo, stop, no retained snapshot field", "game_result.txt")
		world.log << "PASS: conveyor full-game probe"
	catch(var/exception/e)
		text2file("FAIL: [e]", "game_result.txt")
		world.log << "FAIL: conveyor full-game probe: [e]"
	if(world.params["visual"] && findtext(file2text("game_result.txt"), "PASS:") == 1)
		prepare_visual()
		if(world.params["auto_scene"] )
			spawn(10)
				wait_for_capture_client()
	else
		del(world)

/datum/conveyor_game_probe/proc/prepare_visual()
	for(var/x in 18 to 22)
		var/turf/T = locate(x,20,1)
		for(var/obj/O in T)
			qdel(O)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	visual_belt = new(locate(20,20,1), EAST, FALSE)
	visual_belt.id = "local_capture"
	visual_belt.set_light(6, 2, "#FFFFFF")
	visual_switch = new(locate(20,21,1), "local_capture")
	visual_cargo = new /obj/item/weapon/material/kitchen/utensil/knife(visual_belt.loc)
	visual_cargo.name = "movable conveyor test knife"
	visual_fixed = new /obj/item/weapon/material/kitchen/utensil/knife(visual_belt.loc)
	visual_fixed.name = "anchored conveyor test knife"
	visual_fixed.anchored = TRUE
	visual_fixed.pixel_y = 8

/datum/conveyor_game_probe/proc/capture_sequence(client/viewer)
	if(sequence_running || !visual_belt || !visual_switch)
		return
	sequence_running = TRUE
	. = FALSE
	try
		for(var/position in list(1, -1, 0))
			visual_cargo.loc = visual_belt.loc
			visual_switch.position = position
			visual_switch.operated = TRUE
			visual_switch.process()
			to_chat(viewer, "Capture stage: [position == 1 ? "FORWARD" : position == -1 ? "REVERSE" : "STOP"]. Cargo starts on the belt; anchored knife stays.")
			sleep(20)
			visual_belt.process()
			sleep(2)
			var/turf/expected = position ? get_step(visual_belt, position == 1 ? EAST : WEST) : visual_belt.loc
			if(visual_cargo.loc != expected || visual_fixed.loc != visual_belt.loc)
				throw EXCEPTION("Capture movement assertion failed at position [position]")
			to_chat(viewer, "PASS stage [position]: movable knife at ([visual_cargo.x],[visual_cargo.y]); anchored knife at ([visual_fixed.x],[visual_fixed.y]).")
			sleep(30)
		to_chat(viewer, "PASS: forward, reverse, stopped and anchored cargo. Commit [world.params["tested_commit"]].")
		. = TRUE
	catch(var/exception/e)
		to_chat(viewer, "FAIL: [e]")
	sequence_running = FALSE

/client/verb/inspect_conveyor_probe()
	set category = "Local Verification"
	set name = "Inspect conveyor probe"
	if(!world.params["visual"] || !conveyor_game_probe.visual_belt)
		return
	src << browse(null, "window=playersetup")
	screen.Cut()
	eye = conveyor_game_probe.visual_belt.loc
	perspective = EYE_PERSPECTIVE
	mob.sight = SEE_TURFS | SEE_OBJS | SEE_MOBS | SEE_SELF
	mob.see_in_dark = 8
	mob.see_invisible = SEE_INVISIBLE_OBSERVER_NOLIGHTING
	view = 7
	to_chat(src, "<b>[file2text("game_result.txt")]</b><br>Commit [world.params["tested_commit"]], map [map.ID] [world.maxx]x[world.maxy]x[world.maxz], BYOND [world.byond_version].[world.byond_build]. Local disposable world. Use Run conveyor capture sequence for forward/reverse/stop.")

/client/verb/run_conveyor_capture_sequence()
	set category = "Local Verification"
	set name = "Run conveyor capture sequence"
	if(world.params["visual"])
		conveyor_game_probe.capture_sequence(src)

// Visual-only convenience: no lobby clicks or timing-sensitive command entry.
/datum/conveyor_game_probe/proc/wait_for_capture_client()
	var/deadline = world.time + 5000
	while(world.time < deadline)
		for(var/client/C)
			if(C.mob)
				sleep(20)
				if(!C || !C.mob)
					continue
				C.inspect_conveyor_probe()
				sleep(80)
				capture_sequence(C)
				return
		sleep(10)
