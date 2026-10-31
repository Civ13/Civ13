// Fixture-only large shape admission; production's 32x32 guard is unchanged.
// This is included only by the isolated bridge fixture, never the game DME.
/mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge/lifecycle
	npc_subtile_enabled = TRUE

/mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge/lifecycle/npc_subtile_shape()
	return isturf(loc) && world.icon_size == 32 && bound_x == 0 && bound_y == 0 && bound_width == 96 && bound_height == 96 && isnum(step_x) && isnum(step_y) && step_x >= 0 && step_x < 32 && step_y >= 0 && step_y < 32

/obj/large_native_border/bridge/lifecycle
	var/datum/npc_subtile_pulse/seen_pulse
	var/datum/npc_subtile_transaction/seen_transaction
	var/list/at_callback
	var/replace_then_throw = FALSE

/obj/large_native_border/bridge/lifecycle/CheckExit(atom/movable/mover, turf/target, exit_direction = null)
	var/mob/living/simple_animal/A = mover
	seen_pulse = A.npc_subtile_pulse
	seen_transaction = A.npc_subtile_transaction
	at_callback = A.npc_subtile_snapshot()
	if (replace_then_throw)
		fixture_replacement = new
		A.npc_subtile_transaction = fixture_replacement
		throw EXCEPTION("fixture_bridge_exception")
	return ..()

// Invoked by the isolated bridge lane using its already measured remote
// exiting turf. Tests real ai_step admission on the first-pulse cases and the
// inherited transaction advance/perform_rest/finish on the later-pulse case.
/proc/large_bridge_lifecycle_case(turf/exiting, mode)
	large_bridge_assert(mode in list("first_fault", "later_fault", "ordinary_denial", "replace_fault"), "lifecycle_mode")
	var/mob/living/simple_animal/A = large_bridge_setup(/mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge/lifecycle, 0, WEST, FALSE, mode == "later_fault" ? 14 : 15)
	A.npc_subtile_offset_owned = TRUE
	var/original_glide = A.glide_size
	var/obj/large_native_border/bridge/lifecycle/B = new(exiting)
	B.fixture_allow = FALSE
	if (mode == "first_fault" || mode == "later_fault") B.fixture_fault = "callback_throw"
	if (mode == "replace_fault") B.replace_then_throw = TRUE
	var/list/before = A.npc_subtile_snapshot()
	var/list/receipt = list()
	var/datum/npc_subtile_transaction/T
	var/caught = FALSE
	var/caught_name = null
	var/result = null
	try
		if (mode == "later_fault")
			// This is the same transaction type and state ai_step admits. Its
			// first advance and remaining worker loop are inherited unchanged.
			T = new
			T.actor = A; T.direction = WEST; T.start_time = world.time; T.end_time = world.time + 8
			T.expected = A.npc_subtile_snapshot(); T.generation = A.move_gen
			T.target = A.target_obj; T.combat_target = A.target_mob; T.following = A.following_mob; T.stance = A.stance
			T.remaining_x = A.step_x; T.remaining_y = 0
			A.npc_subtile_transaction = T
			A.npc_subtile_previous_glide = A.glide_size
			A.npc_subtile_glide_owned = TRUE
			A.glide_size = max(T.remaining_x, T.remaining_y) * world.tick_lag / 8
			A.npc_subtile_applied_glide = A.glide_size
			large_bridge_assert(T.advance() && T.distance == 2, "lifecycle_later_first_progress")
			T.perform_rest(TRUE)
		else
			result = A.ai_step(get_step(A, WEST), 8, TRUE, receipt)
	catch (var/exception/lifecycle_error)
		caught = TRUE; caught_name = lifecycle_error.name
	if (!T) T = receipt["transaction"]
	var/list/after = A.npc_subtile_snapshot()
	var/pulse_consumed = B.seen_pulse && !B.seen_pulse.armed
	var/owner_preserved = mode == "replace_fault" ? A.npc_subtile_transaction == B.fixture_replacement : !A.npc_subtile_transaction
	var/pulse_preserved = mode == "replace_fault" ? A.npc_subtile_pulse == B.seen_pulse : !A.npc_subtile_pulse
	var/frame_cleared = !A.npc_subtile_large_frame
	var/completed = T && T.finished
	var/attempted = T && T.attempted
	var/arrived = T && T.arrived
	var/glide_valid = mode == "replace_fault" ? (A.npc_subtile_glide_owned && A.glide_size == A.npc_subtile_applied_glide) : (!A.npc_subtile_glide_owned && A.glide_size == original_glide)
	sleep(world.tick_lag * 2)
	var/list/after_wait = A.npc_subtile_snapshot()
	large_bridge_controls += list(list("case" = "lifecycle_[mode]", "before" = before, "at_callback" = B.at_callback,
		"after" = after, "after_wait" = after_wait, "caught" = caught, "caught_name" = caught_name,
		"pulse_consumed" = !!pulse_consumed, "owner_preserved" = !!owner_preserved, "pulse_preserved" = !!pulse_preserved,
		"frame_cleared" = !!frame_cleared, "finished" = !!completed, "attempted" = !!attempted, "arrived" = !!arrived, "glide_valid" = !!glide_valid,
		"distance" = T ? T.distance : null, "checks" = B.fixture_checks))
	large_bridge_assert(B.fixture_checks == (mode == "replace_fault" ? 0 : 1) && pulse_consumed && frame_cleared && completed && attempted, "lifecycle_consumed_and_finished")
	large_bridge_assert(owner_preserved && pulse_preserved && human_subtile_same(after, after_wait), "lifecycle_ownership_and_no_late_move")
	large_bridge_assert(B.at_callback && human_subtile_same(B.at_callback, after), "lifecycle_no_fault_displacement")
	large_bridge_assert(mode == "ordinary_denial" ? (!caught && !result) : (caught && caught_name == "fixture_bridge_exception"), "lifecycle_outcome")
	large_bridge_assert(!arrived && glide_valid, "lifecycle_not_arrived_and_glide_ownership")
	// Only the fixture removes the deliberately installed replacement after the
	// assertions; the old production owner is not allowed to do so.
	if (mode == "replace_fault")
		A.npc_subtile_pulse = null; A.npc_subtile_transaction = null
		A.npc_subtile_release_glide()
		qdel(B.fixture_replacement)
	qdel(B); qdel(A)
