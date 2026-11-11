// Run with the existing ecology constructor fixture, after maintainer approval.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/foraging_probe/New()
	return
/client/New()
	del(src)

// Production forage() with the client and do_after seams replaced. Each wait
// mode stages one event that happens while the 30-second search runs.
/mob/living/human/forage_tester
	var/wait_mode = "complete"
	var/connected = TRUE
	var/waits = 0
/mob/living/human/forage_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
/mob/living/human/forage_tester/religion_check()
	return "none"
/mob/living/human/forage_tester/foraging_connected()
	return connected
/mob/living/human/forage_tester/foraging_wait(delay, turf/T)
	waits++
	switch (wait_mode)
		if ("cancel")
			return FALSE
		if ("disconnect")
			connected = FALSE
		if ("save_completed")
			persistence_admission_identity = new /datum
		if ("save_running")
			persistence_save_in_progress = TRUE
		if ("step_away")
			loc = locate(T.x + 1, T.y, T.z)
		if ("terrain")
			T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		if ("roof")
			new /obj/roof(T)
		if ("rival")
			// A second searcher on the same patch finishes first.
			foraging_check(foraging_commit(locate(T.x + 2, T.y + 2, T.z), persistence_admission_identity), "rival takes the last unit during the wait")
	return TRUE
/proc/foraging_count(turf/T)
	var/n = 0
	for (var/obj/item/stack/material/M in T)
		if (istype(M, /obj/item/stack/material/stone) || istype(M, /obj/item/stack/material/wood_piece))
			n += M.amount
	return n
/proc/foraging_clear(turf/T)
	for (var/obj/item/stack/material/M in T)
		qdel(M)
var/foraging_failures = 0
var/foraging_runtime_error = FALSE
/proc/foraging_check(condition, label)
	if (!condition)
		foraging_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	foraging_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/foraging_probe
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		var/turf/T = locate(3, 3, 1)
		foraging_check(!foraging_commit(T, persistence_admission_identity), "disabled by default")
		map.foraging_enabled = TRUE
		foraging_check(foraging_anchor(T) == locate(1, 1, 1), "stable cell anchor")
		foraging_check(foraging_available(T) == 4, "initial stock")
		for (var/i in 1 to 4)
			foraging_check(foraging_commit(T, persistence_admission_identity), "finite award [i]")
		foraging_check(!foraging_commit(T, persistence_admission_identity), "exhaustion")
		foraging_check(!foraging_commit(locate(8, 8, 1), persistence_admission_identity), "neighbor shares exhaustion")
		foraging_check(foraging_available(locate(9, 8, 1)) == 4, "next cell independent")
		T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		foraging_check(foraging_available(T) == 0, "terraforming does not replenish")
		var/obj/foraging_cell/C = foraging_record(foraging_anchor(T))
		var/turf/anchor = foraging_anchor(T)
		foraging_check(!C.forceMove(locate(9, 9, 1)), "forced relocation refused")
		foraging_check(!C.persistence_set_loc(locate(9, 9, 1)), "raw relocation refused")
		foraging_check(!C.Move(locate(9, 9, 1)), "movement refused")
		foraging_check(C.loc == anchor, "record retains coordinate")
		foraging_check("remaining" in C.get_saved_vars(), "depletion field exported")
		persistence_admission_identity = new /datum
		var/epoch = persistence_admission_identity
		persistence_save_in_progress = TRUE
		foraging_check(!foraging_persistence_ready(epoch), "active save fenced")
		persistence_save_in_progress = FALSE
		foraging_check(!foraging_persistence_ready(null), "stale epoch fenced")
		C.remaining = -1
		foraging_check(foraging_available(T) == 0, "invalid ledger fails closed")
		C.remaining = 2
		var/obj/foraging_cell/dup = new(anchor)
		foraging_check(!foraging_record(anchor) && foraging_available(T) == 0 && !foraging_commit(T, persistence_admission_identity), "duplicate records fail closed")
		qdel(dup)
		foraging_check(foraging_available(T) == 2, "single record restored")
		C.remaining = 1.5
		foraging_check(foraging_available(T) == 0, "fractional stock fails closed")
		C.remaining = 2

		// Phase 2: production disk round trip of a partly spent record.
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		fdel("foraging-state.sav")
		var/savefile/F = new("foraging-state.sav")
		F["/format_version"] << 2
		var/cell_id = map_storage.BuildVarDirectory(F, C, 1)
		F.Flush()
		F = null
		qdel(C)
		foraging_check(isnull(foraging_record(anchor)), "record removed before reload")
		F = new("foraging-state.sav")
		map_storage.clear_bookkeeping()
		var/obj/foraging_cell/restored = map_storage.Load_Entry(F, cell_id, starting_loc = anchor)
		foraging_check(istype(restored) && restored.loc == anchor && restored.remaining == 2, "disk round trip keeps spent stock")
		foraging_check(foraging_available(T) == 2, "reloaded patch keeps depletion")
		// Exhausted records must survive too, or a reload would refill the patch.
		restored.remaining = 0
		map_storage.clear_bookkeeping()
		fdel("foraging-empty.sav")
		F = new("foraging-empty.sav")
		F["/format_version"] << 2
		cell_id = map_storage.BuildVarDirectory(F, restored, 1)
		F.Flush()
		F = null
		qdel(restored)
		F = new("foraging-empty.sav")
		map_storage.clear_bookkeeping()
		restored = map_storage.Load_Entry(F, cell_id, starting_loc = anchor)
		foraging_check(istype(restored) && restored.remaining == 0 && foraging_available(T) == 0, "exhausted record survives reload")
		F = null
		map_storage.clear_bookkeeping()

		// Phase 2: the production search with staged events during the wait.
		persistence_save_in_progress = FALSE
		persistence_active_operation = null
		persistence_load_recovery_required = FALSE
		var/turf/site = locate(19, 19, 1) // fresh cell anchored at 17,17
		var/mob/living/human/forage_tester/U = new(site)
		foraging_check(U.forage() && foraging_count(site) == 1 && foraging_available(site) == 3, "completed search finds one unit")
		foraging_clear(site)
		U.wait_mode = "cancel"
		foraging_check(!U.forage() && !foraging_count(site) && foraging_available(site) == 3, "cancelled search spends nothing")
		U.wait_mode = "disconnect"
		foraging_check(!U.forage() && !foraging_count(site) && foraging_available(site) == 3, "disconnect during search spends nothing")
		U.connected = TRUE
		U.wait_mode = "save_completed"
		foraging_check(!U.forage() && !foraging_count(site) && foraging_available(site) == 3, "save or load completed during search spends nothing")
		U.wait_mode = "save_running"
		foraging_check(!U.forage() && foraging_available(site) == 3, "save running at completion spends nothing")
		persistence_save_in_progress = FALSE
		U.wait_mode = "step_away"
		foraging_check(!U.forage() && foraging_available(site) == 3, "leaving the tile spends nothing")
		U.loc = site
		U.wait_mode = "roof"
		foraging_check(!U.forage() && foraging_available(site) == 3, "roof built during search spends nothing")
		for (var/obj/roof/R in site)
			qdel(R)
		U.wait_mode = "terrain"
		foraging_check(!U.forage() && foraging_available(site) == 3, "ground replaced during search spends nothing")
		site = locate(19, 19, 1)
		site.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		site = locate(19, 19, 1)
		U.loc = site
		// Two searchers on the last unit: exactly one is paid.
		U.wait_mode = "complete"
		foraging_check(U.forage() && U.forage(), "two more finds")
		foraging_check(foraging_available(site) == 1, "one unit left")
		foraging_clear(site)
		U.wait_mode = "rival"
		foraging_check(!U.forage() && foraging_available(site) == 0, "late finisher on the last unit gets nothing")
		foraging_check(foraging_count(site) == 0 && foraging_count(locate(21, 21, 1)) == 1, "only the rival was paid")
		U.wait_mode = "complete"
		var/before = U.waits
		foraging_check(!U.forage() && U.waits == before, "exhausted patch refuses before waiting")
		map.foraging_enabled = FALSE
		var/turf/open = locate(35, 35, 1)
		U.loc = open
		foraging_check(!U.forage() && isnull(foraging_record(foraging_anchor(open))), "disabled map neither searches nor records")
		map.persistence = TRUE
		foraging_check(map.foraging_active() && U.forage(), "Persistence turns foraging on")
		map.persistence = FALSE
		foraging_check(foraging_count(locate(35, 35, 1)) == 1, "single unit per search")
	catch(var/exception/e)
		foraging_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = foraging_failures, "runtime_error" = foraging_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
