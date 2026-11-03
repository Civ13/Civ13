// One controlled insect idle-slot observation; no scheduler, Life, or damage.
/proc/fixture_scheduler_hostile_main()
	fixture_scheduler_assert(world.tick_lag == 0.5 && !clients.len && !processScheduler && !living_mob_list.len, "insect_idle_fresh_world")
	var/mob/living/simple_animal/mosquito/scheduler_probe/A = new(locate(6, 6, 1))
	var/mob/living/human/subtile_fixture/scheduler_target/H = new(locate(6, 6, 1))
	H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H); H.density = FALSE
	H.persistence_owner_ckey = "fixture-owner"; H.real_name = "Movement subject"; H.name = H.real_name
	fixture_scheduler_subject = A; fixture_scheduler_target = H; fixture_scheduler_test_subjects = list(A)
	A.npc_subtile_enabled = TRUE; A.npc_subtile_species_enabled = TRUE; A.npc_subtile_recovery_enabled = TRUE
	fixture_scheduler_assert(A.npc_subtile_ready() && get_turf(A) == get_turf(H), "insect_idle_shape")
	fixture_scheduler_events = list(); fixture_transition_events = fixture_scheduler_events
	fixture_scheduler_running = TRUE
	var/started = world.time
	fixture_scheduler_record("command_before", A)
	var/accepted = A.npc_subtile_species_walk("towards", H, 3)
	fixture_scheduler_assert(accepted && A.npc_subtile_wild_walk, "insect_idle_admitted")
	var/datum/npc_subtile_wild_walk/W = A.npc_subtile_wild_walk
	var/original_generation = W.generation
	var/original_revision = W.revision
	var/original_due = W.due
	fixture_scheduler_record("command_after", A, !!accepted)
	sleep(3.5)
	fixture_scheduler_record("idle_before_target", A)
	fixture_scheduler_assert(W == A.npc_subtile_wild_walk && W.valid() && W.generation == original_generation && W.revision == original_revision && W.due == original_due && W.idle_window_end == original_due + 3 && world.time < W.idle_window_end && !A.npc_subtile_transaction && !(A.step_x || A.step_y), "insect_idle_slot_preserved")
	fixture_scheduler_record("target_step_before", A)
	H.forceMove(locate(7, 6, 1))
	fixture_scheduler_assert(H.x == 7 && H.y == 6 && H.z == 1, "insect_idle_target_moved")
	fixture_scheduler_record("target_step_after", A)
	var/target_moved_at = world.time
	while (world.time < target_moved_at + 10 && !(A.x == 7 && A.y == 6 && !A.step_x && !A.step_y && !A.npc_subtile_transaction && !A.npc_subtile_pulse))
		fixture_scheduler_record("travel_sample", A)
		sleep(world.tick_lag)
	fixture_scheduler_assert(A.x == 7 && A.y == 6 && !A.step_x && !A.step_y && !A.npc_subtile_transaction && !A.npc_subtile_pulse && W == A.npc_subtile_wild_walk && W.generation == original_generation && W.revision == original_revision, "insect_idle_arrived")
	fixture_scheduler_record("arrived", A)
	A.npc_subtile_stop_wild_walk()
	fixture_scheduler_record("stop", A)
	var/quiet_started = world.time
	while (world.time < quiet_started + 4)
		fixture_scheduler_record("quiet_sample", A)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!A.npc_subtile_wild_walk && !A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_pending_intent && A.x == 7 && A.y == 6 && !A.step_x && !A.step_y, "insect_idle_stop_quiet")
	fixture_scheduler_record("quiet_end", A)
	fixture_scheduler_running = FALSE
	fixture_transition_rows = list(list("started" = started, "ended" = world.time, "tick_lag_ds" = world.tick_lag, "actual_clients" = clients.len, "events" = fixture_scheduler_events.Copy()))
	fixture_transition_phase = "quiet"
	fixture_scheduler_test_subjects = list(); fixture_scheduler_subject = null; fixture_scheduler_target = null
	qdel(A); qdel(H)
	return fixture_transition_rows
