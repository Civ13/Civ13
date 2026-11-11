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
/proc/foraging_count(turf/T, path = /obj/item)
	var/n = 0
	for (var/obj/item/I in T)
		if (!istype(I, path))
			continue
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			n += S.amount
		else
			n++
	return n
/proc/foraging_clear(turf/T)
	for (var/obj/item/I in T)
		qdel(I)
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

		// Phases 3 and 4: what each focus finds, seasons, time and the panel.
		map.foraging_enabled = TRUE
		season = "SPRING"
		var/turf/meadow = locate(27, 3, 1) // cell anchored at 25,1
		U.loc = meadow
		var/list/seeds = foraging_finds(meadow, "seeds")
		foraging_check(foraging_finds(meadow, "stone").len == 1 && foraging_finds(meadow, "wood").len == 1 && (/obj/item/stack/farming/seeds/wheat in seeds) && !(/obj/item/stack/farming/seeds/rice in seeds), "temperate spring grass offers stone, sticks and its own wild seeds")
		foraging_check(/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom in foraging_finds(meadow, "food"), "temperate spring grass offers mushrooms")
		foraging_check(U.forage("seeds") && foraging_count(meadow, /obj/item/stack/farming/seeds) == 1, "seed focus finds one seed")
		foraging_check(U.forage("food") && foraging_count(meadow, /obj/item/weapon/reagent_containers/food/snacks/grown/mushroom) == 1, "food focus finds one mushroom")
		foraging_check(U.forage("wood") && foraging_count(meadow, /obj/item/stack/material/wood_piece) == 1, "wood focus finds one stick")
		foraging_check(foraging_available(meadow) == 1, "every focused find costs one unit")
		var/html = U.foraging_panel_html(meadow)
		text2file(html, "panel.html") // evidence for review renders
		foraging_check(findtext(html, "almost bare") && findtext(html, "forage_focus=seeds") && findtext(html, "Temperate grass"), "panel shows habitat, abundance and focus links")
		foraging_check(U.forage("stone") && findtext(U.foraging_panel_html(meadow), "picked clean") && !findtext(U.foraging_panel_html(meadow), "forage_focus="), "empty patch panel offers no search")
		foraging_check(!U.forage("nonsense"), "unknown focus refused")
		season = "WINTER"
		var/turf/winter = locate(27, 11, 1)
		U.loc = winter
		before = U.waits
		foraging_check(!foraging_finds(winter, "seeds").len && !foraging_finds(winter, "food").len && !U.forage("food") && U.waits == before && foraging_available(winter) == 4, "no seeds or mushrooms in winter, refused before waiting")
		foraging_check(U.forage("anything") && !foraging_count(winter, /obj/item/stack/farming/seeds) && !foraging_count(winter, /obj/item/weapon/reagent_containers/food), "winter open search finds only stone or sticks")
		season = "SPRING"
		var/turf/shore = locate(27, 19, 1)
		shore = shore.ChangeTurf(/turf/floor/beach/sand, FALSE, FALSE)
		U.loc = shore
		foraging_check(foraging_offers(shore, "stone") && !foraging_offers(shore, "wood") && !foraging_offers(shore, "seeds") && !foraging_offers(shore, "food"), "beach sand offers only stones")
		before = U.waits
		foraging_check(!U.forage("wood") && U.waits == before && foraging_available(shore) == 4, "unoffered focus refused before waiting")
		foraging_check(U.forage("anything") && foraging_count(shore, /obj/item/stack/material/stone) == 1, "beach open search finds a stone")
		var/time = U.foraging_search_time(meadow)
		foraging_check(time >= 200 && time <= 450, "search time within bounds ([time])")
		var/list/counts = list()
		for (var/i in 1 to 400)
			var/path = foraging_roll(meadow, "anything")
			counts["[path]"] = (counts["[path]"] || 0) + 1
		foraging_check(counts["[/obj/item/stack/material/stone]"] > 60 && counts["[/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom]"] > 30, "open search spreads across categories")

		// Phase 5: lazy renewal on the durable active-server clock.
		round_start_time = 0
		round_elapsed_offset = 100000
		var/t0 = foraging_clock()
		var/turf/grove = locate(35, 3, 1) // cell anchored at 33,1
		foraging_check(foraging_commit(grove, persistence_admission_identity, "stone"), "first find at full stock")
		var/obj/foraging_cell/R = foraging_record(foraging_anchor(grove))
		foraging_check(R.remaining == 3 && R.renew_from == t0, "spending from full starts the renewal clock")
		round_elapsed_offset = 100000 + FORAGING_RENEW_TIME - 10
		foraging_check(foraging_available(grove) == 3, "nothing grows back before a full period")
		round_elapsed_offset = 100000 + FORAGING_RENEW_TIME
		foraging_check(foraging_available(grove) == 4 && R.remaining == 3, "one unit back after a period, read without writing")
		foraging_check(foraging_commit(grove, persistence_admission_identity, "stone") && R.remaining == 3 && R.renew_from == foraging_clock(), "search settles renewal then spends")
		for (var/i in 1 to 3)
			foraging_commit(grove, persistence_admission_identity, "stone")
		foraging_check(R.remaining == 0 && !foraging_commit(grove, persistence_admission_identity, "stone"), "patch exhausted again")
		var/stamp = R.renew_from
		round_elapsed_offset = stamp + 2 * FORAGING_RENEW_TIME + 5
		foraging_check(foraging_available(grove) == 2, "two periods give two units")
		round_elapsed_offset = stamp + 40 * FORAGING_RENEW_TIME
		foraging_check(foraging_available(grove) == 4, "renewal caps at full stock")
		foraging_check(foraging_commit(grove, persistence_admission_identity, "stone") && R.remaining == 3 && R.renew_from == foraging_clock(), "full patch after a long wait restarts from now, no banked units")
		// Downtime: the saved clock comes back where it stopped, so a reload grants nothing.
		var/before_clock = round_elapsed_offset
		map_storage.clear_bookkeeping()
		fdel("foraging-renew.sav")
		F = new("foraging-renew.sav")
		F["/format_version"] << 2
		cell_id = map_storage.BuildVarDirectory(F, R, 1)
		F.Flush()
		F = null
		var/turf/grove_anchor = foraging_anchor(grove)
		var/saved_stamp = R.renew_from
		qdel(R)
		F = new("foraging-renew.sav")
		map_storage.clear_bookkeeping()
		R = map_storage.Load_Entry(F, cell_id, starting_loc = grove_anchor)
		F = null
		map_storage.clear_bookkeeping()
		round_elapsed_offset = before_clock
		foraging_check(istype(R) && R.remaining == 3 && R.renew_from == saved_stamp && foraging_available(grove) == 3, "renewal stamp survives a disk round trip; downtime grants nothing")
		// A clock behind the stamp (legacy save without its round clock) restamps, never grants.
		round_elapsed_offset = 50
		foraging_check(foraging_available(grove) == 3, "clock behind stamp grants nothing")
		foraging_check(foraging_commit(grove, persistence_admission_identity, "stone") && R.remaining == 2 && R.renew_from == foraging_clock(), "clock behind stamp restamps on the next search")
		// A record saved before renewal existed starts its clock when first looked at.
		R.remaining = 0
		R.renew_from = null
		round_elapsed_offset = 9000
		foraging_check(foraging_available(grove) == 0 && R.renew_from == foraging_clock(), "legacy exhausted record starts its clock on first look")
		persistence_save_in_progress = TRUE
		R.renew_from = null
		foraging_check(foraging_available(grove) == 0 && isnull(R.renew_from), "no stamping while a save runs")
		persistence_save_in_progress = FALSE
		R.renew_from = "soon"
		foraging_check(!foraging_record(grove_anchor) && foraging_available(grove) == 0, "malformed renewal stamp fails closed")
		R.renew_from = -5
		foraging_check(!foraging_record(grove_anchor), "negative renewal stamp fails closed")
		R.renew_from = null
		foraging_check("renew_from" in R.get_saved_vars(), "renewal stamp exported")
		// Terrain and season changes leave the stock alone.
		R.remaining = 1
		R.renew_from = foraging_clock()
		grove = grove.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		season = "WINTER"
		foraging_check(foraging_available(grove) == 1, "ground and season changes do not refill")
		season = "SPRING"
		// Phase 6 cost note: one look touches only two turfs. Logged, not asserted.
		var/started = world.timeofday
		for (var/i in 1 to 20000)
			foraging_available(locate(1 + (i % 40), 1 + round(i / 40) % 40, 1))
		world.log << "COST: 20000 patch looks took [(world.timeofday - started) / 10] s"
	catch(var/exception/e)
		foraging_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = foraging_failures, "runtime_error" = foraging_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
