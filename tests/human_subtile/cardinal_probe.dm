// Fixture-only draft. Requires the existing random cadence recorder and mob
// probe. This proc starts no mob scheduler and makes one movement request.
var/global/list/fixture_cardinal_setup = list()
var/global/list/fixture_cardinal_rows = list()
var/global/fixture_cardinal_mode
var/global/fixture_cardinal_tick

/proc/fixture_interval_cardinal_main()
	fixture_cardinal_mode = world.params["cardinal_mode"]
	var/raw_tick = world.params["cardinal_tick"]
	fixture_cardinal_tick = text2num(raw_tick)
	fixture_scheduler_assert((fixture_cardinal_mode in list("legacy", "smooth")) && (fixture_cardinal_tick in list(0.5, 1)), "cardinal_mode_tick")
	world.tick_lag = fixture_cardinal_tick
	fixture_scheduler_assert(world.tick_lag == fixture_cardinal_tick && !processScheduler && !living_mob_list.len, "cardinal_startup")
	fixture_cardinal_setup = list("requested_tick" = fixture_cardinal_tick, "actual_tick" = world.tick_lag,
		"startup_time" = world.time, "startup_usage" = world.tick_usage)
	sleep(world.tick_lag)
	fixture_cardinal_setup["ready_time"] = world.time
	fixture_cardinal_setup["ready_usage"] = world.tick_usage
	fixture_scheduler_assert(world.time > fixture_cardinal_setup["startup_time"] && world.tick_lag == fixture_cardinal_tick && \
		isnum(world.tick_usage) && world.tick_usage >= 0 && world.tick_usage < 100, "cardinal_ready")
	fixture_random_count = 0
	fixture_random_overflow = FALSE
	fixture_cardinal_rows = list()
	for (var/lag in list(3, 4))
		fixture_cardinal_rows += list(fixture_interval_cardinal_phase(fixture_cardinal_mode == "smooth", lag))
	fixture_scheduler_assert(fixture_cardinal_rows.len == 2 && !fixture_random_overflow, "cardinal_complete")

/proc/fixture_interval_cardinal_phase(enabled, lag)
	fixture_scheduler_assert(lag in list(3, 4), "cardinal_lag")
	fixture_scheduler_assert(!processScheduler && !fixture_random_running && !living_mob_list.len, "cardinal_fresh")
	var/mob/living/simple_animal/mosquito/scheduler_probe/random_probe/A = new(locate(12, 32, 1))
	fixture_scheduler_assert(A && A.loc && !A.client && !A.stat, "cardinal_subject")
	// Validate a clear, bounded route, including the actor's starting tile.
	for (var/x = 12, x <= 28, x++)
		var/turf/T = locate(x, 32, 1)
		fixture_scheduler_assert(T && !T.density, "cardinal_open_turf")
		for (var/atom/movable/M in T)
			fixture_scheduler_assert(M == A || !M.density, "cardinal_open_contents")
	fixture_scheduler_subject = A
	fixture_scheduler_target = null
	fixture_scheduler_test_subjects = list(A)
	fixture_scheduler_events = list()
	fixture_random_events = list()
	fixture_random_phase_count = 0
	fixture_random_life_count = 0
	fixture_random_tx_count = 0
	fixture_random_move_enter_count = 0
	fixture_random_move_exit_count = 0
	fixture_random_policy = "held"
	fixture_random_calls = 0
	A.npc_subtile_enabled = !!enabled
	A.npc_subtile_species_enabled = !!enabled
	A.npc_subtile_recovery_enabled = !!enabled
	var/started = world.time
	fixture_random_running = TRUE
	fixture_random_observe("phase_start", A)
	A.npc_subtile_species_walk("direction", null, lag, EAST)
	while (world.time < started + 16 && !fixture_random_overflow)
		sleep(world.tick_lag)
	fixture_random_observe("observation_end", A)
	// Stop both possible owners; never let a later phase inherit a command.
	walk(A, 0)
	A.npc_subtile_stop_wild_walk()
	var/deadline = world.time + 10
	while (A.npc_subtile_transaction && world.time < deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!A.npc_subtile_transaction && !A.npc_subtile_pulse, "cardinal_quiesced")
	fixture_random_observe("phase_end", A)
	fixture_scheduler_assert(!fixture_random_overflow, "cardinal_event_bound")
	fixture_random_running = FALSE
	var/list/result = list("enabled" = !!enabled, "lag_ticks" = lag, "tick_lag_ds" = world.tick_lag,
		"converted_ds" = A.npc_subtile_native_interval(lag), "started" = started, "ended" = world.time,
		"observation_ds" = 16, "step_size" = A.step_size, "event_count" = fixture_random_phase_count,
		"move_enter_count" = fixture_random_move_enter_count, "move_exit_count" = fixture_random_move_exit_count,
		"tx_count" = fixture_random_tx_count, "life_count" = fixture_random_life_count,
		"events" = fixture_random_events.Copy())
	fixture_scheduler_test_subjects = list()
	fixture_scheduler_subject = null
	qdel(A)
	return result
