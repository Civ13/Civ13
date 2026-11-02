// Source-only draft. Not included by the DME or a workflow.
// Reuse scheduler_transition_stage's subject-only clients.len adapter.
var/global/fixture_handoff_running = FALSE
var/global/fixture_handoff_phase = "initial"
var/global/list/fixture_handoff_events = list()
var/global/datum/npc_subtile_flee/fixture_handoff_old_owner
var/global/datum/npc_subtile_transaction/fixture_handoff_old_tx
var/global/datum/npc_subtile_follow/fixture_handoff_new_owner
var/global/list/fixture_handoff_old_ticket
var/global/fixture_handoff_old_hook_count = 0
var/global/fixture_handoff_old_timer_count = 0
var/global/fixture_handoff_follow_moves = 0
var/global/fixture_handoff_move_sequence = 0

/proc/fixture_handoff_record(label, mob/living/simple_animal/A, result = null, call_id = null)
	fixture_scheduler_assert(fixture_handoff_events.len < 4096, "handoff_event_bound")
	fixture_scheduler_assert(A && !isDeleted(A), "handoff_actor_alive")
	var/datum/npc_subtile_transaction/T = A.npc_subtile_transaction
	var/owner_kind = null
	if (T)
		if (T.intent_owner == fixture_handoff_old_owner && fixture_handoff_old_owner)
			owner_kind = "old_flee"
		else if (T.intent_owner == fixture_handoff_new_owner && fixture_handoff_new_owner)
			owner_kind = "new_follow"
		else if (T.intent_owner && T.intent_owner == A.npc_subtile_recovery)
			owner_kind = "recovery"
		else if (T.intent_owner && T.intent_owner == A.npc_subtile_follow)
			owner_kind = "follow_before_capture"
		else
			owner_kind = "other"
	fixture_handoff_events += list(list("event" = label, "phase" = fixture_handoff_phase,
		"at" = world.time, "x" = A.x, "y" = A.y, "z" = A.z, "sx" = A.step_x, "sy" = A.step_y,
		"generation" = A.move_gen, "base_enabled" = !!A.npc_subtile_enabled,
		"offset_owned" = !!A.npc_subtile_offset_owned, "transaction" = !!T,
		"transaction_old" = !!(T && T == fixture_handoff_old_tx), "transaction_owner" = owner_kind,
		"transaction_generation" = T ? T.generation : null, "pulse" = !!A.npc_subtile_pulse,
		"flee_old" = !!(fixture_handoff_old_owner && A.npc_subtile_flee == fixture_handoff_old_owner),
		"follow_new" = !!(fixture_handoff_new_owner && A.npc_subtile_follow == fixture_handoff_new_owner),
		"follow_any" = !!A.npc_subtile_follow, "recovery" = !!A.npc_subtile_recovery,
		"pursuit" = !!A.npc_subtile_pursuit, "wild" = !!A.npc_subtile_wild_walk, "pet" = !!A.npc_subtile_pet_walk,
		"pending" = !!A.npc_subtile_pending_intent,
		"old_cancelled" = !!(fixture_handoff_old_owner && fixture_handoff_old_owner.cancelled),
		"old_owner_retired" = !!(fixture_handoff_old_owner && !fixture_handoff_old_owner.actor),
		"old_finished" = !!(fixture_handoff_old_tx && fixture_handoff_old_tx.finished),
		"old_arrived" = !!(fixture_handoff_old_tx && fixture_handoff_old_tx.arrived),
		"old_hooks" = fixture_handoff_old_hook_count, "old_timer_count" = fixture_handoff_old_timer_count,
		"ticket_deadline" = fixture_handoff_old_ticket ? fixture_handoff_old_ticket["expires_at"] : null,
		"follow_moves" = fixture_handoff_follow_moves, "result" = result, "call_id" = call_id))

/mob/living/simple_animal/pet/cat/scheduler_enabled_handoff/Life()
	if (fixture_handoff_running)
		fixture_handoff_record("life_before", src)
	. = ..()
	if (fixture_handoff_running && src && !isDeleted(src))
		fixture_handoff_record("life_after", src)

/mob/living/simple_animal/pet/cat/scheduler_enabled_handoff/Move()
	var/old_x = x * world.icon_size + step_x
	var/old_y = y * world.icon_size + step_y
	fixture_handoff_move_sequence++
	var/call_id = fixture_handoff_move_sequence
	var/datum/npc_subtile_transaction/entry_tx = npc_subtile_transaction
	var/datum/entry_owner = entry_tx ? entry_tx.intent_owner : null
	if (fixture_handoff_running)
		fixture_handoff_record("move_before", src, null, call_id)
	. = ..()
	if (fixture_handoff_running && src && !isDeleted(src))
		if (entry_owner && entry_owner == fixture_handoff_new_owner && (old_x != x * world.icon_size + step_x || old_y != y * world.icon_size + step_y))
			fixture_handoff_follow_moves++
		fixture_handoff_record("move_after", src, . ? TRUE : FALSE, call_id)

/mob/living/simple_animal/pet/cat/scheduler_enabled_handoff/living_movement_completed()
	if (fixture_handoff_running && fixture_handoff_old_tx && fixture_handoff_old_tx.completed && !fixture_handoff_old_tx.finished)
		fixture_handoff_old_hook_count++
		fixture_handoff_record("old_completion_hook", src)
	. = ..()

/mob/living/simple_animal/pet/cat/scheduler_enabled_handoff/npc_subtile_stop_flee_ticket(list/ticket)
	var/is_old = fixture_handoff_running && ticket && ticket == fixture_handoff_old_ticket
	if (is_old)
		fixture_handoff_record("old_timer_before", src)
	. = ..()
	if (is_old && src && !isDeleted(src))
		fixture_handoff_old_timer_count++
		fixture_handoff_record("old_timer_after", src, !!.)

// Starts one real mob process. Neither Life nor any producer start is called manually.
// The test stimulus explicitly stops one active flee and requests follow by its
// normal relationship setter; subsequent admission comes from scheduled Life.
/proc/fixture_scheduler_enabled_handoff_observe()
	fixture_scheduler_assert(world.tick_lag == 0.5 && !clients.len && !processScheduler && !living_mob_list.len, "handoff_fresh_world")
	rand_seed(741239)
	var/mob/living/simple_animal/pet/cat/scheduler_enabled_handoff/A = new(locate(6, 6, 1))
	var/mob/living/human/subtile_fixture/scheduler_target/H = new(locate(10, 6, 1))
	H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H)
	H.persistence_owner_ckey = "fixture-owner"; H.real_name = "Movement subject"; H.name = H.real_name
	A.npc_subtile_enabled = TRUE; A.npc_subtile_flee_enabled = TRUE
	A.npc_subtile_follow_enabled = TRUE; A.npc_subtile_recovery_enabled = TRUE
	A.simplehunger = 1000; A.speak_chance = 0; A.behaviour = "scared"
	A.turns_since_move = A.move_to_delay - 1; A.ai_tick_delay = A.ai_tick_delay_max - 1
	fixture_scheduler_test_subjects = list(A)
	fixture_scheduler_subject = A; fixture_scheduler_target = H
	fixture_handoff_events = list(); fixture_transition_events = fixture_handoff_events; fixture_handoff_phase = "flee"
	fixture_handoff_old_owner = null; fixture_handoff_old_tx = null; fixture_handoff_new_owner = null
	fixture_handoff_old_ticket = null; fixture_handoff_old_hook_count = 0
	fixture_handoff_old_timer_count = 0; fixture_handoff_follow_moves = 0; fixture_handoff_move_sequence = 0
	var/processScheduler/S = new
	processScheduler = S
	var/process/mob/P = new(S)
	S.addProcess(P)
	fixture_scheduler_assert(S.processes.len == 1 && S.processes[1] == P && P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS, "handoff_original_scheduler")
	fixture_handoff_running = TRUE
	var/started = world.time
	var/switched = FALSE
	S.start()
	while (world.time < started + 100)
		if (!switched && A.npc_subtile_flee && A.npc_subtile_transaction && A.npc_subtile_transaction.intent_owner == A.npc_subtile_flee && A.npc_subtile_offset_owned && (A.step_x || A.step_y))
			fixture_handoff_old_owner = A.npc_subtile_flee
			fixture_handoff_old_tx = A.npc_subtile_transaction
			fixture_handoff_old_ticket = A.npc_subtile_flee_ticket
			fixture_scheduler_assert(fixture_handoff_old_ticket && fixture_handoff_old_ticket == fixture_handoff_old_owner.flee_ticket, "handoff_old_ticket")
			fixture_handoff_record("stop_before", A)
			A.npc_subtile_stop_flee()
			fixture_scheduler_assert(!A.npc_subtile_flee && A.npc_subtile_offset_owned && (A.step_x || A.step_y), "handoff_partial_retained")
			fixture_handoff_record("stop_after", A)
			A.behaviour = "none"; A.stop_automated_movement = FALSE
			A.npc_set_following(H)
			A.turns_since_move = A.move_to_delay - 1
			fixture_handoff_phase = "replacement"; switched = TRUE
			fixture_handoff_record("replacement_requested", A)
		if (switched && !fixture_handoff_new_owner && A.npc_subtile_follow)
			fixture_handoff_new_owner = A.npc_subtile_follow
			fixture_handoff_record("follow_owner_observed", A)
		fixture_handoff_record("sample", A)
		if (fixture_handoff_old_timer_count && fixture_handoff_new_owner && fixture_handoff_follow_moves > 0)
			break
		sleep(world.tick_lag)
	fixture_scheduler_assert(switched && fixture_handoff_old_tx.finished && !fixture_handoff_old_tx.arrived, "handoff_old_retired")
	fixture_scheduler_assert(fixture_handoff_old_hook_count == 1, "handoff_old_completion_once")
	fixture_scheduler_assert(fixture_handoff_new_owner && A.npc_subtile_follow == fixture_handoff_new_owner && fixture_handoff_follow_moves > 0, "handoff_follow_progress")
	fixture_scheduler_assert(fixture_handoff_old_timer_count == 1, "handoff_old_timer_observed")
	fixture_handoff_record("final_stop_before", A)
	A.npc_subtile_stop_follow()
	A.npc_set_following(null)
	S.stop()
	var/deadline = world.time + 10
	while ((P.running || P.queued || A.npc_subtile_transaction || A.npc_subtile_pulse) && world.time < deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(P.ticks > 0 && !P.running && !P.queued && P.idle && !P.exceptions.len, "handoff_scheduler_quiesced")
	fixture_scheduler_assert(!A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_follow && !A.npc_subtile_flee && !A.npc_subtile_recovery && !A.npc_subtile_pending_intent && !A.npc_subtile_pursuit && !A.npc_subtile_wild_walk && !A.npc_subtile_pet_walk, "handoff_final_owner_quiesced")
	fixture_handoff_phase = "quiet"
	fixture_handoff_record("final_stop_after", A)
	var/quiet_started = world.time
	while (world.time < quiet_started + 4)
		fixture_handoff_record("quiet_sample", A)
		sleep(world.tick_lag)
	fixture_handoff_record("quiet_end", A)
	fixture_handoff_running = FALSE
	var/list/result = list("started" = started, "ended" = world.time, "process_ticks" = P.ticks,
		"life_interval_ds" = P.schedule_interval, "start_delay_ds" = P.start_delay,
		"tick_lag_ds" = world.tick_lag, "actual_clients" = clients.len, "events" = fixture_handoff_events.Copy())
	fixture_scheduler_test_subjects = list(); fixture_scheduler_subject = null; fixture_scheduler_target = null
	qdel(A); qdel(H); qdel(P); processes.mob = null; processScheduler = null; qdel(S)
	return result

// A future test-only adapter may bind the existing probe receipt to this entry.
/proc/fixture_scheduler_enabled_handoff_main()
	fixture_transition_rows = list()
	fixture_transition_rows += list(fixture_scheduler_enabled_handoff_observe())
	fixture_transition_phase = "quiet"
	return fixture_transition_rows
