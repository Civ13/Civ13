// Current-engine acceptance in the existing isolated, full-source fixture.
var/human_subtile_diagonal_checks = 0

/proc/human_subtile_diagonal_assert(ok, label)
	human_subtile_diagonal_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/human_subtile_fixture_diagonal()
	human_subtile_fixture_phase = "diagonal acceptance"
	human_subtile_diagonal_assert(world.byond_version == 516 && world.byond_build == 1688, "diagonal_current_engine")
	for (var/direction in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(8, 7)
		human_subtile_diagonal_assert(!H.human_subtile_enabled && H.human_subtile_default_pending, "default_waits_for_safe_input")
		human_subtile_diagonal_assert(H.human_subtile_input_supported(direction) && H.human_subtile_eligible(direction) && !H.human_subtile_default_pending, "default_uses_safe_setter")
		var/start = world.time
		var/px = H.x * 32
		var/py = H.y * 32
		H.SelfMove(get_step(H, direction), direction, start + 4)
		var/dx = (direction & EAST) ? 2 : -2
		var/dy = (direction & NORTH) ? 2 : -2
		human_subtile_diagonal_assert(H.fixture_pulses == 16 && H.x * 32 + H.step_x - px == dx * 16 && H.y * 32 + H.step_y - py == dy * 16, "diagonal_32px_per_axis")
		var/last_x = px
		var/last_y = py
		for (var/list/row in H.fixture_rows)
			var/next_x = row["x"] * 32 + row["sx"]
			var/next_y = row["y"] * 32 + row["sy"]
			human_subtile_diagonal_assert(next_x - last_x == dx && next_y - last_y == dy, "diagonal_each_pulse_two_pixels_both_axes")
			last_x = next_x
			last_y = next_y
		human_subtile_diagonal_assert(world.time <= start + 4 + world.tick_lag && H.fixture_human_completions == 1 && H.fixture_living_completions == 1 && !H.human_subtile_transaction && !H.human_subtile_pulse, "diagonal_interval_hooks_cleanup")
		human_subtile_diagonal_assert(abs(H.glide_size - 4 * ROOT2_FAST) < 0.001 && H.human_subtile_glide_owned, "diagonal_interpolation_matches_physical_interval")
		human_subtile_fixture_rows += list(list("scene" = "diagonal_[direction]", "rows" = H.fixture_rows))
		qdel(H)

	var/mob/living/human/subtile_fixture/C = human_subtile_fixture_actor(8, 7)
	C.human_subtile_input_supported(EAST)
	C.fixture_cancel_after = 1
	C.SelfMove(get_step(C, EAST), EAST, world.time + 4)
	C.fixture_authorized = TRUE
	C.fixture_cancel_after = 0
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, WEST), WEST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 8 && C.y == 7 && !C.step_x && !C.step_y && C.fixture_pulses == 1, "cancel_stop_reverse_realigns_without_snap")
	human_subtile_diagonal_assert(C.set_human_subtile(FALSE) && !C.human_subtile_enabled, "recovered_player_can_opt_out")
	C.set_human_subtile(TRUE)
	C.fixture_cancel_after = 1
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, EAST), EAST, world.time + 4)
	C.fixture_authorized = TRUE
	C.fixture_cancel_after = 0
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, NORTHEAST), NORTHEAST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 9 && C.y == 8 && !C.step_x && !C.step_y && C.fixture_pulses == 16, "cardinal_offset_to_diagonal")
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, WEST), WEST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 8 && C.y == 8 && !C.step_x && C.fixture_pulses == 16, "diagonal_offset_to_cardinal")
	C.fixture_cancel_after = 1
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, NORTHWEST), NORTHWEST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 7 && C.y == 8 && C.step_x == 30 && C.step_y == 2 && C.fixture_pulses == 1 && !C.human_subtile_transaction && !C.human_subtile_pulse, "diagonal_cancel_retains_physical_position")
	human_subtile_diagonal_assert(!C.set_human_subtile(FALSE), "offset_optout_refused_without_snapping")
	C.fixture_authorized = TRUE
	C.fixture_cancel_after = 0
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, SOUTHEAST), SOUTHEAST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 8 && C.y == 8 && !C.step_x && !C.step_y && C.fixture_pulses == 1, "reverse_diagonal_realigns_both_axes")
	human_subtile_diagonal_assert(C.set_human_subtile(FALSE) && C.human_subtile_input_supported(NORTHEAST) && !C.human_subtile_enabled && !C.human_subtile_default_pending, "explicit_optout_survives_input")
	qdel(C)
	for (var/posture in list("prone", "lying"))
		var/mob/living/human/subtile_fixture/P = human_subtile_fixture_actor(8, 7)
		P.human_subtile_input_supported(EAST)
		P.fixture_cancel_after = 1
		P.SelfMove(get_step(P, EAST), EAST, world.time + 4)
		P.fixture_authorized = TRUE
		P.fixture_cancel_after = 0
		if (posture == "prone")
			P.prone = TRUE
		else
			P.lying = TRUE
		human_subtile_diagonal_assert(P.human_subtile_input_supported(WEST) && !P.human_subtile_eligible(WEST), "owned_offset_can_enter_paid_[posture]_path")
		human_subtile_fixture_reset(P)
		var/started = world.time
		var/delay = posture == "prone" ? P.get_prone_delay() : 9
		if (posture == "prone")
			P.proning(get_step(P, WEST))
		else
			P.scramble(get_step(P, WEST))
		human_subtile_diagonal_assert(P.x == 8 && !P.step_x && !P.step_y && P.fixture_pulses == 1 && P.lying && !P.scrambling, "actual_[posture]_path_realigns_without_forced_standing")
		human_subtile_diagonal_assert(world.time - started >= delay - world.tick_lag && P.fixture_human_completions == 1 && P.fixture_living_completions == 1, "[posture]_retains_paid_wait_and_once_only_hooks")
		qdel(P)

	// Normal state release followed by an ordinary admitted reverse input.
	// No capsule/forceMove/direct offset write participates in recovery.
	for (var/state in list("pulling", "restrained"))
		var/mob/living/human/subtile_fixture/R = human_subtile_fixture_actor(8, 7)
		R.human_subtile_input_supported(EAST)
		R.fixture_cancel_after = 1
		R.SelfMove(get_step(R, EAST), EAST, world.time + 4)
		R.fixture_authorized = TRUE
		R.fixture_cancel_after = 0
		var/obj/item/weapon/handcuffs/cuffs
		var/obj/held
		if (state == "prone")
			R.prone = TRUE
		else if (state == "pulling")
			held = new(R.loc)
			R.pulling = held
			held.pulledby = R
		else
			cuffs = new(R)
			R.handcuffed = cuffs
		var/list/stopped = R.human_subtile_snapshot()
		human_subtile_diagonal_assert(!R.human_subtile_input_supported(WEST) && !R.SelfMove(get_step(R, WEST), WEST, world.time + 4) && human_subtile_same(stopped, R.human_subtile_snapshot()), "restricted_offset_does_not_bypass_[state]")
		if (state == "prone")
			R.prone = FALSE
		else if (state == "pulling")
			R.stop_pulling()
		else
			R.u_equip(cuffs)
		human_subtile_fixture_reset(R)
		R.SelfMove(get_step(R, WEST), WEST, world.time + 4)
		human_subtile_diagonal_assert(!R.step_x && !R.step_y && R.fixture_pulses == 1 && R.set_human_subtile(FALSE), "state_release_then_reverse_recovers_[state]")
		if (cuffs)
			qdel(cuffs)
		if (held)
			qdel(held)
		qdel(R)
	var/mob/living/human/subtile_fixture/B = human_subtile_fixture_actor(8, 7)
	B.human_subtile_input_supported(EAST)
	B.fixture_cancel_after = 1
	B.SelfMove(get_step(B, EAST), EAST, world.time + 4)
	B.fixture_authorized = TRUE
	B.fixture_cancel_after = 0
	var/obj/obstacle = new(B.loc)
	obstacle.density = TRUE
	obstacle.bound_width = 1
	B.SelfMove(get_step(B, WEST), WEST, world.time + 4)
	human_subtile_diagonal_assert(B.x == 8 && B.step_x >= 1 && B.step_x <= 2 && !B.set_human_subtile(FALSE), "realignment_cannot_push_through_obstacle")
	B.SelfMove(get_step(B, EAST), EAST, world.time + 4)
	human_subtile_diagonal_assert(B.x == 9 && !B.step_x && B.set_human_subtile(FALSE), "blocked_reverse_can_realign_away_from_obstacle")
	qdel(obstacle)
	qdel(B)

	// Native footprint collision must stop both-axis corner penetration. A
	// partial native slide is permitted, but cannot continue as a tile fallback.
	for (var/wall_direction in list(NORTH, EAST, NORTHEAST))
		var/mob/living/human/subtile_fixture/W = human_subtile_fixture_actor(8, 7)
		W.human_subtile_input_supported(NORTHEAST)
		var/turf/wall = get_step(W, wall_direction)
		wall.density = TRUE
		W.SelfMove(get_step(W, NORTHEAST), NORTHEAST, world.time + 4)
		human_subtile_diagonal_assert(W.x == 8 && W.y == 7 && W.step_x <= 2 && W.step_y <= 2 && W.fixture_pulses == 1 && !W.human_subtile_transaction && !W.human_subtile_pulse, "corner_native_collision_no_tile_fallback")
		wall.density = FALSE
		qdel(W)

	var/mob/living/human/subtile_fixture/G = human_subtile_fixture_actor(8, 7)
	G.stat = DEAD
	G.human_subtile_input_supported(NORTHEAST)
	human_subtile_diagonal_assert(!G.human_subtile_enabled && G.human_subtile_default_pending, "dead_body_not_default_enabled")
	G.stat = CONSCIOUS
	G.canmove = TRUE
	human_subtile_diagonal_assert(G.human_subtile_input_supported(NORTHEAST) && G.human_subtile_enabled, "revived_body_default_on_first_safe_input")
	qdel(G)
	var/mob/living/human/subtile_fixture/L = human_subtile_fixture_actor(8, 7)
	human_subtile_fixture_place(L, 4, 4)
	var/savefile/F = new("diagonal-roundtrip.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, L, 1)
	F.cd = map_storage.entry_path(F, ref)
	human_subtile_diagonal_assert(!("human_subtile_default_pending" in F.dir), "default_initialization_is_runtime_only")
	F.Flush()
	F = null
	qdel(L)
	F = new("diagonal-roundtrip.sav")
	map_storage.clear_bookkeeping()
	var/mob/living/human/subtile_fixture/loaded = map_storage.Load_Entry(F, ref, starting_loc = locate(8, 7, 1))
	loaded.after_load()
	human_subtile_diagonal_assert(!loaded.human_subtile_enabled && loaded.human_subtile_default_pending && loaded.step_x == 4 && loaded.step_y == 4 && !loaded.human_subtile_transaction, "diagonal_codec_restores_both_axes_without_worker")
	human_subtile_diagonal_assert(loaded.human_subtile_input_supported(SOUTHWEST) && loaded.human_subtile_enabled && loaded.step_x == 4 && loaded.step_y == 4, "owned_restore_default_without_snap")
	qdel(loaded)
	var/mob/living/human/subtile_fixture/O = human_subtile_fixture_actor(8, 7)
	O.bound_width = 16
	O.human_subtile_input_supported(NORTHEAST)
	human_subtile_diagonal_assert(!O.human_subtile_enabled && O.human_subtile_default_pending, "ineligible_geometry_keeps_legacy")
	O.bound_width = 32
	O.human_subtile_transaction = new
	human_subtile_diagonal_assert(!O.human_subtile_initialize_default(NORTHEAST) && O.human_subtile_default_pending, "default_cannot_bypass_busy_setter")
	O.human_subtile_transaction = null
	human_subtile_diagonal_assert(O.human_subtile_deadline(104, 100, TRUE) == 100 + 4 * ROOT2_FAST && O.human_subtile_deadline(104, 100, FALSE) == 104, "diagonal_legacy_ordinal_cooldown")
	O.human_subtile_update_visuals(4, EAST, null)
	O.glide_size = 7
	O.human_subtile_release_glide()
	human_subtile_diagonal_assert(O.glide_size == 7 && !O.human_subtile_glide_owned, "external_body_glide_preference_survives_release")
	qdel(O)
	return TRUE

// Optional real-client acceptance entry. It is never called by headless CI.
// Requires explicit authorization and a separately attached fixture client.
/proc/human_subtile_fixture_client_visuals(client/C)
	var/mob/living/human/subtile_fixture/H = C.mob
	human_subtile_fixture_assert(istype(H) && H.client == C && !C.moving, "visual_real_client_required")
	var/original_fps = C.fps
	var/original_client_glide = C.glide_size
	var/original_body_glide = H.glide_size
	H.human_subtile_update_visuals(4, EAST, C)
	human_subtile_fixture_assert(C.fps >= 60 && C.human_subtile_visual_actor == H && C.human_subtile_visual_owned && H.human_subtile_glide_owned, "visual_settings_acquired_for_exact_body")
	C.fps = 72
	C.glide_size = 3.25
	H.glide_size = 5
	C.human_subtile_release_visuals()
	human_subtile_fixture_assert(C.fps == 72 && C.glide_size == 3.25 && H.glide_size == 5 && !C.human_subtile_visual_owned, "external_preferences_survive_release")
	H.human_subtile_update_visuals(4, NORTHEAST, C)
	var/mob/living/human/subtile_fixture/replacement = human_subtile_fixture_actor(12, 7)
	C.mob = replacement
	human_subtile_fixture_assert(C.mob == replacement && !C.human_subtile_visual_owned && C.fps == 72 && C.glide_size == 3.25 && H.glide_size == 5 && !H.human_subtile_glide_owned, "native_body_handoff_releases_previous_owner")
	replacement.human_subtile_update_visuals(4, EAST, C)
	human_subtile_fixture_assert(C.human_subtile_visual_actor == replacement && C.human_subtile_visual_owned, "replacement_body_acquires_own_visual_settings")
	replacement.set_human_subtile(FALSE)
	human_subtile_fixture_assert(!C.human_subtile_visual_owned && C.fps == 72 && C.glide_size == 3.25, "replacement_optout_restores_external_preferences")
	C.mob = H
	qdel(replacement)
	C.fps = original_fps
	C.glide_size = original_client_glide
	H.glide_size = original_body_glide
	return TRUE
