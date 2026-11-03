// Paired diagnostic: the same controlled target step under native and smooth
// species-walk adapters. No mob scheduler, Life, attacks, or disease changes.
/proc/fixture_insect_chase_case(enabled)
	fixture_scheduler_assert(world.tick_lag == 0.5 && !clients.len && !processScheduler && !living_mob_list.len, "chase_control_fresh_world")
	var/mob/living/simple_animal/mosquito/scheduler_probe/A = new(locate(6, 6, 1))
	var/mob/living/human/subtile_fixture/scheduler_target/H = new(locate(6, 6, 1))
	H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H); H.density = FALSE
	H.persistence_owner_ckey = "fixture-owner"; H.real_name = "Movement subject"; H.name = H.real_name
	fixture_scheduler_subject = A; fixture_scheduler_target = H; fixture_scheduler_test_subjects = list(A)
	A.npc_subtile_enabled = !!enabled; A.npc_subtile_species_enabled = !!enabled; A.npc_subtile_recovery_enabled = !!enabled
	fixture_scheduler_assert(A.npc_subtile_ready() && get_turf(A) == get_turf(H), "chase_control_shape")
	fixture_scheduler_events = list(); fixture_transition_events = fixture_scheduler_events; fixture_scheduler_running = TRUE
	var/started = world.time
	fixture_scheduler_record("command_before", A)
	var/accepted = A.npc_subtile_species_walk("towards", H, 3)
	var/datum/npc_subtile_wild_walk/W = A.npc_subtile_wild_walk
	var/original_generation = W ? W.generation : null
	var/original_revision = W ? W.revision : null
	var/original_due = W ? W.due : null
	fixture_scheduler_assert(enabled ? (accepted && W) : (!W && !A.npc_subtile_transaction), "chase_control_command")
	fixture_scheduler_record("command_after", A, !!accepted)
	sleep(5)
	fixture_scheduler_record("idle_before_target", A)
	if (enabled)
		fixture_scheduler_assert(W == A.npc_subtile_wild_walk && W.valid() && W.generation == original_generation && W.revision == original_revision && W.due == original_due && W.idle_window_end == original_due + 3 && world.time < W.idle_window_end && !A.npc_subtile_transaction && !(A.step_x || A.step_y), "chase_control_smooth_idle")
	else
		fixture_scheduler_assert(!A.npc_subtile_wild_walk && !A.npc_subtile_transaction && !(A.step_x || A.step_y), "chase_control_native_idle")
	fixture_scheduler_record("target_step_before", A)
	H.forceMove(locate(7, 6, 1))
	fixture_scheduler_assert(H.x == 7 && H.y == 6 && H.z == 1, "chase_control_target_moved")
	fixture_scheduler_record("target_step_after", A)
	var/target_moved_at = world.time
	while (world.time < target_moved_at + 12 && !(A.x == 7 && A.y == 6 && !A.step_x && !A.step_y && !A.npc_subtile_transaction && !A.npc_subtile_pulse))
		fixture_scheduler_record("travel_sample", A)
		sleep(world.tick_lag)
	fixture_scheduler_assert(A.x == 7 && A.y == 6 && !A.step_x && !A.step_y && !A.npc_subtile_transaction && !A.npc_subtile_pulse, "chase_control_arrived")
	if (enabled)
		fixture_scheduler_assert(W == A.npc_subtile_wild_walk && W.generation == original_generation && W.revision == original_revision, "chase_control_owner_retained")
	fixture_scheduler_record("arrived", A)
	A.npc_subtile_stop_continuous_walk()
	fixture_scheduler_record("stop", A)
	var/quiet_started = world.time
	while (world.time < quiet_started + 4)
		fixture_scheduler_record("quiet_sample", A)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!A.npc_subtile_wild_walk && !A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_pending_intent && A.x == 7 && A.y == 6 && !A.step_x && !A.step_y, "chase_control_stop_quiet")
	fixture_scheduler_record("quiet_end", A)
	fixture_scheduler_running = FALSE
	var/list/result = list("mode" = enabled ? "smooth" : "legacy", "started" = started, "ended" = world.time, "tick_lag_ds" = world.tick_lag, "actual_clients" = clients.len, "events" = fixture_scheduler_events.Copy())
	fixture_scheduler_test_subjects = list(); fixture_scheduler_subject = null; fixture_scheduler_target = null
	qdel(A); qdel(H)
	return result

/proc/fixture_scheduler_hostile_main()
	fixture_transition_rows = list()
	fixture_transition_rows += list(fixture_insect_chase_case(FALSE))
	sleep(2)
	fixture_transition_rows += list(fixture_insect_chase_case(TRUE))
	fixture_transition_phase = "quiet"
	return fixture_transition_rows
