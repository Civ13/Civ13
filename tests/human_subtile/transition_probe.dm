// Fixture-only draft. Requires the cardinal probe's map/readiness setup and
// existing random recorder + terminal instrumentation. No production include.
// Run each case with a new actor, no mob process, lag=4 and a single tick rate.
var/global/list/fixture_transition_rows = list()
var/global/fixture_transition_count_old = FALSE
var/global/fixture_transition_old_completions = 0
var/global/list/fixture_transition_setup = list()
var/global/fixture_transition_case

/proc/fixture_transition_main()
	fixture_scheduler_assert(world.params["transition_tick"] == "0.5", "transition_requested_tick")
	world.tick_lag = 0.5
	fixture_scheduler_assert(world.tick_lag == 0.5 && !processScheduler && !living_mob_list.len, "transition_startup")
	fixture_transition_setup = list("requested_tick" = 0.5, "actual_tick" = world.tick_lag, "startup_time" = world.time, "startup_usage" = world.tick_usage)
	sleep(world.tick_lag)
	fixture_transition_setup["ready_time"] = world.time
	fixture_transition_setup["ready_usage"] = world.tick_usage
	fixture_scheduler_assert(world.time > fixture_transition_setup["startup_time"] && world.tick_lag == 0.5 && \
		isnum(world.tick_usage) && world.tick_usage >= 0 && world.tick_usage < 100, "transition_ready")
	fixture_random_count = 0
	fixture_random_overflow = FALSE
	fixture_transition_rows = list()
	for (var/case_name in list("blocked", "cancel_replace"))
		fixture_transition_rows += list(fixture_transition_phase(case_name))
	fixture_scheduler_assert(fixture_transition_rows.len == 2 && !fixture_random_overflow, "transition_complete")

/mob/living/simple_animal/mosquito/scheduler_probe/random_probe/living_movement_completed()
	. = ..()
	if (fixture_transition_count_old && src == fixture_scheduler_subject)
		fixture_transition_old_completions++
		fixture_random_observe("transition_old_completion", src)

/proc/fixture_transition_phase(case_name)
	fixture_transition_case = case_name
	fixture_scheduler_assert(case_name in list("blocked", "cancel_replace"), "transition_case")
	fixture_scheduler_assert(!processScheduler && !fixture_random_running && !living_mob_list.len, "transition_fresh")
	var/mob/living/simple_animal/mosquito/scheduler_probe/random_probe/A = new(locate(12, 32, 1))
	var/turf/wall = locate(13, 32, 1)
	fixture_scheduler_assert(A && wall && !wall.density && !A.client && !A.stat, "transition_setup")
	for (var/x = 11, x <= 15, x++)
		for (var/y = 31, y <= 36, y++)
			var/turf/check = locate(x, y, 1)
			fixture_scheduler_assert(check && !check.density, "transition_open_turf")
			for (var/atom/movable/M in check)
				fixture_scheduler_assert(M == A || !M.density, "transition_open_contents")
	fixture_scheduler_subject = A
	fixture_scheduler_target = null
	fixture_scheduler_test_subjects = list(A)
	fixture_random_events = list()
	fixture_random_phase_count = 0
	fixture_random_life_count = 0
	fixture_random_tx_count = 0
	fixture_random_move_enter_count = 0
	fixture_random_move_exit_count = 0
	fixture_random_policy = "reissue"
	fixture_random_calls = 0
	A.npc_subtile_enabled = TRUE
	A.npc_subtile_species_enabled = TRUE
	A.npc_subtile_recovery_enabled = TRUE
	fixture_transition_count_old = FALSE
	fixture_transition_old_completions = 0
	if (case_name == "blocked")
		wall.density = TRUE
	fixture_random_running = TRUE
	var/start = world.time
	fixture_random_observe("transition_start", A, list("case" = case_name, "wall_dense" = !!wall.density, \
		"bound_x" = A.bound_x, "bound_y" = A.bound_y, "bound_width" = A.bound_width, "bound_height" = A.bound_height))
	var/accepted = A.npc_subtile_species_walk("direction", null, 4, EAST)
	fixture_scheduler_assert(accepted, "transition_initial_admission")
	if (case_name == "blocked")
		// Two native walker deadlines, plus a tick for cleanup.
		while (world.time < start + 9 && !fixture_random_overflow)
			sleep(world.tick_lag)
		fixture_random_observe("transition_blocked_end", A, list("wall_dense" = !!wall.density))
		fixture_scheduler_assert(A.x == 12 && A.y == 32 && !A.step_x && !A.step_y && \
			fixture_random_tx_count >= 2 && fixture_random_tx_count <= 3, "transition_blocked_bounded")
		A.npc_subtile_stop_wild_walk()
	else
		var/deadline = start + 8
		while (!A.npc_subtile_transaction && world.time < deadline && !fixture_random_overflow)
			sleep(world.tick_lag)
		var/datum/npc_subtile_transaction/T = A.npc_subtile_transaction
		fixture_scheduler_assert(T && !T.finished && T.direction == EAST, "transition_active_east")
		// Sample one tick before the transaction deadline. No manual pulse or
		// position change is used to obtain this state.
		while (world.time < T.end_time - world.tick_lag && !T.finished && !fixture_random_overflow)
			sleep(world.tick_lag)
		fixture_scheduler_assert(!T.finished && A.npc_subtile_transaction == T && world.time < T.end_time && \
			A.npc_subtile_offset_owned && (A.step_x || A.step_y), "transition_preterminal_offset")
		fixture_random_observe("transition_before", A, list("case" = case_name, "old_end" = T.end_time, \
			"offset_owned" = !!A.npc_subtile_offset_owned), T)
		fixture_transition_count_old = TRUE
		A.npc_subtile_stop_wild_walk()
		fixture_random_observe("transition_after", A, list("case" = case_name, "old_end" = T.end_time), T)
		var/stop_at = world.time
		var/old_x = A.x * 32 + A.step_x
		var/old_y = A.y * 32 + A.step_y
		deadline = stop_at + 10
		while ((!T.finished || A.npc_subtile_transaction || world.time < A.npc_subtile_until) && world.time < deadline && !fixture_random_overflow)
			sleep(world.tick_lag)
		fixture_transition_count_old = FALSE
		fixture_scheduler_assert(T.finished && fixture_transition_old_completions == 1 && !A.npc_subtile_transaction && \
			world.time >= A.npc_subtile_until && A.x * 32 + A.step_x == old_x && A.y * 32 + A.step_y == old_y && \
			!A.npc_subtile_wild_walk, "transition_cancel_terminal")
		fixture_random_observe("transition_old_terminal", A, list("case" = case_name, "completions" = fixture_transition_old_completions), T)
		// Use the same paid recovery admission that Life would request. Its
		// worker owns alignment; the newer command enters the bounded pending slot.
		var/recovery_accepted = A.npc_subtile_request_recovery()
		fixture_scheduler_assert(recovery_accepted && A.npc_subtile_recovery, "transition_recovery_admission")
		fixture_random_observe("transition_recovery", A, list("case" = case_name, "recovery" = !!A.npc_subtile_recovery))
		var/replaced = A.npc_subtile_species_walk("direction", null, 4, NORTH)
		fixture_scheduler_assert(replaced && A.npc_subtile_pending_intent, "transition_replacement_pending")
		fixture_random_observe("transition_replacement", A, list("case" = case_name, "recovery" = !!A.npc_subtile_recovery, "pending" = !!A.npc_subtile_pending_intent))
		deadline = world.time + 32
		while (world.time < deadline && A.y * 32 + A.step_y <= 32 * 32 && !fixture_random_overflow)
			sleep(world.tick_lag)
		fixture_scheduler_assert(A.y * 32 + A.step_y > 32 * 32, "transition_replacement_progress")
		fixture_random_observe("transition_wait_end", A, list("case" = case_name), T)
		A.npc_subtile_stop_wild_walk()
	var/finish_deadline = world.time + 10
	while (A.npc_subtile_transaction && world.time < finish_deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_wild_walk && !fixture_random_overflow, "transition_quiesced")
	fixture_random_observe("transition_end", A, list("case" = case_name))
	fixture_random_running = FALSE
	var/list/row = list("case" = case_name, "tick" = world.tick_lag, "lag" = 4,
		"start" = start, "end" = world.time, "events" = fixture_random_events.Copy(),
		"event_count" = fixture_random_phase_count, "move_enter_count" = fixture_random_move_enter_count,
		"move_exit_count" = fixture_random_move_exit_count, "tx_count" = fixture_random_tx_count,
		"life_count" = fixture_random_life_count, "overflow" = fixture_random_overflow)
	wall.density = FALSE
	fixture_scheduler_test_subjects = list()
	fixture_scheduler_subject = null
	qdel(A)
	return row
