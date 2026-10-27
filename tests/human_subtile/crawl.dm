// Full production proning/scramble entry, native collision and timing. Explicit
// headless client-authority adapter: no client/rendering claim is made here.
var/human_subtile_crawl_checks = 0
var/list/human_subtile_crawl_changes = list()

/proc/human_subtile_crawl_assert(ok, label)
	human_subtile_crawl_checks++
	if (!ok)
		throw EXCEPTION(label)

/mob/living/human/subtile_fixture/crawl
	var/fixture_change
	var/fixture_change_after = 4
	var/obj/fixture_blocker
	var/obj/fixture_reach_target
	var/fixture_reach_before
	var/fixture_reach_during
	var/fixture_reentry_refused = FALSE
	var/list/fixture_displaced
	var/list/fixture_inserted

/mob/living/human/subtile_fixture/crawl/human_subtile_crawl_authority(client/owner)
	if (client)
		return ..()
	return fixture_authorized

/mob/living/human/subtile_fixture/crawl/Move()
	var/crawl_pulse = human_subtile_pulse && human_subtile_transaction && human_subtile_transaction.paid_posture
	. = ..()
	if (!crawl_pulse)
		return
	if (fixture_reach_target && fixture_pulses == 4)
		fixture_reach_during = bounds_dist(src, fixture_reach_target)
	if (fixture_pulses != fixture_change_after)
		return
	fixture_reentry_refused = !human_subtile_crawl_move(get_step(src, EAST), 9, "scramble")
	switch (fixture_change)
		if ("posture")
			prone = FALSE
			lying = FALSE
		if ("switch-prone")
			prone = TRUE
		if ("paralysis")
			paralysis = 1
		if ("limbs")
			has_limbs = FALSE
		if ("authority")
			fixture_authorized = FALSE
		if ("optout")
			human_subtile_enabled = FALSE
		if ("save")
			human_subtile_transaction.cancelled = TRUE
		if ("linked")
			fixture_blocker = new(loc)
			pulling = fixture_blocker
		if ("displaced")
			forceMove(locate(12, 10, 1))
			fixture_displaced = human_subtile_snapshot()
		if ("blocker")
			fixture_blocker = new(get_step(src, EAST))
			fixture_blocker.density = TRUE
			fixture_inserted = list("at" = world.time, "actor" = human_subtile_snapshot(), "blocker_x" = fixture_blocker.x, "blocker_y" = fixture_blocker.y, "blocker_width" = fixture_blocker.bound_width, "blocker_height" = fixture_blocker.bound_height, "blocker_density" = fixture_blocker.density, "bounds_distance" = bounds_dist(src, fixture_blocker), "already_overlapped_turf" = (fixture_blocker.loc in locs))
	return

/proc/human_subtile_crawl_actor()
	var/mob/living/human/subtile_fixture/crawl/H = new(locate(8, 7, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.persistence_owner_ckey = "fixture-owner"
	H.real_name = "Crawl subject"
	H.name = H.real_name
	H.m_intent = "walk"
	H.equip_to_slot(new /obj/item/clothing/under/squid_contestant(H), slot_w_uniform)
	return H

/proc/human_subtile_crawl_action(mob/living/human/H, posture, direction)
	if (posture == "prone")
		H.proning(get_step(H, direction))
	else
		H.scramble(get_step(H, direction))

/proc/human_subtile_fixture_crawl()
	human_subtile_fixture_phase = "crawl acceptance"
	human_subtile_crawl_assert(world.byond_version == 516 && world.byond_build == 1688, "crawl_current_engine")
	for (var/posture in list("prone", "scramble", "weakened"))
		for (var/direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
			var/mob/living/human/subtile_fixture/crawl/H = human_subtile_crawl_actor()
			H.prone = posture == "prone"
			H.lying = TRUE
			H.weakened = posture == "weakened" ? 1 : 0
			// Injury/weight slowdown is captured by get_prone_delay, not walking.
			H.run_delay_maximum = 2.4
			var/delay = H.prone ? H.get_prone_delay() : 9 * (H.weakened ? 1.5 : 1)
			var/food = H.nutrition
			var/water_before = H.water
			var/stamina_before = H.stats["stamina"][1]
			var/velocity_before = H.velocity
			var/start = world.time
			var/px = H.x * 32
			var/py = H.y * 32
			var/body_glide = H.glide_size
			if (direction == EAST)
				H.fixture_reach_target = new(locate(10, 7, 1))
				H.fixture_reach_before = bounds_dist(H, H.fixture_reach_target)
			human_subtile_crawl_action(H, posture, direction)
			var/dx = (direction & EAST) ? 32 : (direction & WEST) ? -32 : 0
			var/dy = (direction & NORTH) ? 32 : (direction & SOUTH) ? -32 : 0
			human_subtile_crawl_assert(H.fixture_pulses == 16 && H.x * 32 + H.step_x - px == dx && H.y * 32 + H.step_y - py == dy, "crawl_full_native_displacement")
			human_subtile_crawl_assert(world.time >= start + delay && world.time <= start + delay + world.tick_lag, "crawl_original_deadline_no_ordinal_multiplier")
			var/list/first = H.fixture_rows[1]
			var/list/last = H.fixture_rows[16]
			human_subtile_crawl_assert(first["at"] < start + delay && first["at"] >= start + delay / 16 && last["at"] >= start + delay, "crawl_progress_during_wait_final_arrival_paid")
			human_subtile_crawl_assert(H.fixture_living_completions == 1 && H.fixture_human_completions == 1 && H.fixture_reentry_refused, "crawl_hooks_once_reentry_refused")
			human_subtile_crawl_assert(H.nutrition == food && H.water == water_before && H.stats["stamina"][1] == stamina_before && H.velocity == velocity_before, "crawl_does_not_import_walking_costs")
			human_subtile_crawl_assert(!H.scrambling && !H.human_subtile_transaction && !H.human_subtile_pulse && !H.human_subtile_glide_owned && H.glide_size == body_glide && !H.human_subtile_default_pending && H.human_subtile_enabled, "crawl_first_input_default_and_cleanup")
			if (direction == EAST)
				human_subtile_crawl_assert(H.fixture_reach_during < H.fixture_reach_before, "crawl_intermediate_physical_reach_changes")
			human_subtile_fixture_rows += list(list("scene" = "crawl_[posture]_[direction]", "duration" = world.time - start, "rows" = H.fixture_rows))
			qdel(H.fixture_reach_target)
			qdel(H)

	for (var/change in list("posture", "switch-prone", "paralysis", "limbs", "authority", "optout", "save", "linked", "displaced", "blocker"))
		var/mob/living/human/subtile_fixture/crawl/C = human_subtile_crawl_actor()
		C.lying = TRUE
		C.fixture_change = change
		var/started = world.time
		human_subtile_crawl_action(C, "scramble", EAST)
		// Record before asserting, so failed native expectations retain the
		// physical trace and insertion geometry rather than only a check label.
		var/list/change_row = list("change" = change, "started" = started, "finished" = world.time, "pulses" = C.fixture_pulses, "position" = C.human_subtile_snapshot(), "inserted" = C.fixture_inserted, "rows" = C.fixture_rows)
		human_subtile_crawl_changes += list(change_row)
		text2file(json_encode(change_row), "crawl-changes.log")
		human_subtile_crawl_assert(C.fixture_pulses == (change == "blocker" ? 5 : 4), "crawl_dynamic_cancellation_or_collision_stops_pulses")
		human_subtile_crawl_assert(world.time >= started + 9 && world.time <= started + 9 + world.tick_lag && !C.scrambling && !C.human_subtile_transaction && !C.human_subtile_pulse && !C.human_subtile_glide_owned, "crawl_cancel_retains_deadline_cleans_visuals")
		if (change == "displaced")
			human_subtile_crawl_assert(human_subtile_same(C.fixture_displaced, C.human_subtile_snapshot()), "crawl_never_continues_from_external_teleport")
		else
			human_subtile_crawl_assert(C.x == 8 && C.step_x == 8 && C.human_subtile_offset_owned, "crawl_cancel_retains_collision_paid_partial_offset")
		human_subtile_crawl_assert(C.fixture_living_completions == 1 && C.fixture_human_completions == 1, "crawl_cancel_once_only_hooks")
		C.pulling = null
		qdel(C.fixture_blocker)
		qdel(C)

	var/mob/living/human/subtile_fixture/crawl/B = human_subtile_crawl_actor()
	B.lying = TRUE
	var/obj/blocker = new(get_step(B, EAST))
	blocker.density = TRUE
	var/blocked_started = world.time
	var/lock_observed = FALSE
	spawn(2)
		lock_observed = B.scrambling && B.human_subtile_transaction && !B.human_subtile_crawl_move(get_step(B, EAST), 9, "scramble") && !B.human_subtile_glide_owned
	human_subtile_crawl_action(B, "scramble", EAST)
	human_subtile_crawl_assert(world.time >= blocked_started + 9 && lock_observed && B.x == 8 && !B.step_x && B.fixture_pulses == 1, "crawl_blocked_attempt_retains_lock_entire_interval")
	human_subtile_crawl_assert(B.fixture_human_completions == 1 && B.fixture_living_completions == 1, "crawl_blocked_attempt_legacy_hooks_once")
	qdel(blocker)
	qdel(B)

	var/mob/living/human/subtile_fixture/crawl/O = human_subtile_crawl_actor()
	O.lying = TRUE
	O.set_human_subtile(FALSE)
	human_subtile_crawl_action(O, "scramble", EAST)
	human_subtile_crawl_assert(O.x == 9 && !O.step_x && !O.fixture_pulses && !O.human_subtile_enabled && !O.human_subtile_default_pending, "crawl_explicit_optout_legacy_path")
	qdel(O)
	var/mob/living/human/subtile_fixture/crawl/R = human_subtile_crawl_actor()
	R.lying = TRUE
	human_subtile_fixture_place(R, 2, 0)
	var/recovery_started = world.time
	human_subtile_crawl_action(R, "scramble", WEST)
	human_subtile_crawl_assert(R.x == 8 && !R.step_x && R.fixture_pulses == 1 && world.time >= recovery_started + 9, "crawl_owned_short_recovery_spans_paid_interval")
	qdel(R)
	// Adjacent floor clicks dispatch scramble even when deliberate prone is set.
	var/mob/living/human/subtile_fixture/crawl/P = human_subtile_crawl_actor()
	P.lying = TRUE
	P.prone = TRUE
	var/click_started = world.time
	P.scramble(get_step(P, EAST))
	human_subtile_crawl_assert(P.x == 9 && P.fixture_pulses == 16 && P.prone && P.lying, "crawl_prone_adjacent_click_uses_scramble_without_posture_change")
	human_subtile_crawl_assert(world.time >= click_started + 9 && world.time <= click_started + 9 + world.tick_lag, "crawl_prone_click_preserves_scramble_delay")
	qdel(P)
	return TRUE
