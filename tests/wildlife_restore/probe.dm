// Native probe (#4207): wildlife saved between tiles under automatic admission
// restores through the real save codec and can move again.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/wildlife_restore/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wr_probe/New()
	return

/mob/living/simple_animal/wr_probe
	icon_state = null

var/wr_failures = 0
var/wr_runtime_error = FALSE
/proc/wr_check(condition, label)
	if (!condition)
		wr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/wr_probe
		ecology_world_unwatched = FALSE
		wr_checks()
	catch(var/exception/e)
		wr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wr_failures, "runtime_error" = wr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wr_watch(mob/living/simple_animal/A, watched)
	A.npc_subtile_watch_checked = world.time
	A.npc_subtile_watch_cached = watched

// Admit the animal the way a nearby player does, then leave it between tiles.
/proc/wr_saved_entry(savefile/F, turf/T)
	var/mob/living/simple_animal/wr_probe/A = new(T)
	wr_watch(A, TRUE)
	A.npc_subtile_auto_admit()
	A.step_x = 6
	A.npc_subtile_offset_owned = TRUE
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, A, 1)
	F.Flush()
	qdel(A)
	return ref

/proc/wr_load(savefile/F, ref, turf/T)
	map_storage.clear_bookkeeping()
	var/mob/living/simple_animal/wr_probe/L = map_storage.Load_Entry(F, ref, starting_loc = T)
	L.after_load()
	return L

/proc/wr_checks()
	var/turf/T = locate(5, 5, 1)
	var/savefile/F = new("wildlife-restore.sav")
	F["/format_version"] << 2
	var/ref = wr_saved_entry(F, T)

	// Nobody near after the load: the animal still walks back onto a tile.
	var/mob/living/simple_animal/wr_probe/L = wr_load(F, ref, T)
	wr_check(L.x == 5 && L.step_x == 6 && L.npc_subtile_offset_owned, "the saved offset restores")
	wr_check(L.npc_subtile_enabled && L.npc_subtile_auto_owned, "automatic admission is restored with the owned offset")
	wr_watch(L, FALSE)
	wr_check(L.ai_step(get_step(L, WEST), 4), "an unwatched restored animal accepts a step")
	sleep(5)
	wr_check(!L.step_x && L.x == 5 && !L.npc_subtile_transaction, "the unwatched animal settles on its tile")
	L.npc_subtile_auto_admit()
	wr_check(!L.npc_subtile_enabled && !L.npc_subtile_auto_owned, "aligned and unwatched, the admission is released")
	wr_check(L.ai_step(get_step(L, EAST), 4) && L.x == 6, "it then walks a legacy tile step")
	qdel(L)

	// A player nearby after the load: free movement continues.
	L = wr_load(F, ref, T)
	wr_watch(L, TRUE)
	wr_check(L.npc_subtile_pulse_px() == 8, "a restored animal keeps wildlife-sized pulses")
	wr_check(L.ai_step(get_step(L, WEST), 4), "a watched restored animal accepts a step")
	sleep(5)
	wr_check(L.x == 5 && !L.step_x && !L.npc_subtile_transaction, "the watched animal finishes its step")
	L.npc_subtile_auto_admit()
	wr_check(L.npc_subtile_enabled && L.npc_subtile_auto_owned, "watched, it keeps free movement on its tile")
	qdel(L)

	// A blocked offset restores aligned and moves without free movement.
	var/turf/blocked = locate(6, 5, 1)
	blocked.density = TRUE
	L = wr_load(F, ref, T)
	wr_check(L.x == 5 && !L.step_x && !L.npc_subtile_offset_owned && !L.npc_subtile_enabled, "a blocked offset restores aligned and unadmitted")
	blocked.density = FALSE
	wr_watch(L, FALSE)
	wr_check(L.ai_step(get_step(L, NORTH), 4) && L.y == 6, "the aligned animal walks")
	qdel(L)

	// Transient workers are not saved.
	F.cd = map_storage.entry_path(F, ref)
	wr_check(!("npc_subtile_transaction" in F.dir) && !("npc_subtile_pulse" in F.dir) && !("npc_subtile_auto_owned" in F.dir) && !("npc_subtile_watch_checked" in F.dir) && !("npc_subtile_watch_cached" in F.dir), "no ephemeral worker or admission state is saved")

