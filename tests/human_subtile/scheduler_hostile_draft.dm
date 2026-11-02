// UNWIRED source draft.  Uses the existing scheduler_core/transition probe
// and its test-subject-only clients.len gate.  No production proc is replaced.
var/global/fixture_hostile_running = FALSE
var/global/fixture_hostile_phase = "initial"
var/global/list/fixture_hostile_events = list()
var/global/mob/living/simple_animal/hostile/panther/scheduler_hostile/fixture_hostile_actor
var/global/mob/living/human/subtile_fixture/scheduler_target/fixture_hostile_target
var/global/datum/npc_subtile_pursuit/fixture_hostile_lost_owner
var/global/datum/npc_subtile_transaction/fixture_hostile_lost_tx
var/global/fixture_hostile_move_id = 0
var/global/fixture_hostile_wander_moves = 0
var/global/fixture_hostile_attack_calls = 0
var/global/fixture_hostile_positive_attacks = 0
var/global/fixture_hostile_old_completions = 0

/proc/fixture_hostile_record(label, mob/living/simple_animal/A, result = null, call_id = null, damage_before = null)
	fixture_scheduler_assert(fixture_hostile_events.len < 2048, "hostile_event_bound")
	fixture_scheduler_assert(A && !isDeleted(A), "hostile_actor_alive")
	var/datum/npc_subtile_transaction/T = A.npc_subtile_transaction
	var/transaction_owner = null
	if (T)
		if (fixture_hostile_lost_owner && T.intent_owner == fixture_hostile_lost_owner)
			transaction_owner = "lost_pursuit"
		else if (T.intent_owner && T.intent_owner == A.npc_subtile_pursuit)
			transaction_owner = "pursuit"
		else if (T.intent_owner && T.intent_owner == A.npc_subtile_recovery)
			transaction_owner = "recovery"
		else if (T.intent_owner)
			transaction_owner = "other"
		else
			transaction_owner = "wander_or_direct"
	var/list/event_row = list(
		"event" = label, "phase" = fixture_hostile_phase, "at" = world.time,
		"x" = A.x, "y" = A.y, "z" = A.z, "sx" = A.step_x, "sy" = A.step_y,
		"bx" = A.bound_x, "by" = A.bound_y, "bw" = A.bound_width, "bh" = A.bound_height,
		"generation" = A.move_gen, "stance" = A.stance,
		"owned" = !!A.npc_subtile_offset_owned, "transaction" = !!T,
		"transaction_old" = !!(T && T == fixture_hostile_lost_tx),
		"transaction_generation" = T ? T.generation : null, "transaction_owner" = transaction_owner,
		"pulse" = !!A.npc_subtile_pulse, "pursuit" = !!A.npc_subtile_pursuit,
		"pursuit_old" = !!(fixture_hostile_lost_owner && A.npc_subtile_pursuit == fixture_hostile_lost_owner),
		"wild" = !!A.npc_subtile_wild_walk, "follow" = !!A.npc_subtile_follow,
		"flee" = !!A.npc_subtile_flee, "pet" = !!A.npc_subtile_pet_walk,
		"recovery" = !!A.npc_subtile_recovery, "pending" = !!A.npc_subtile_pending_intent,
		"target_matches" = !!(fixture_hostile_target && A.target_mob == fixture_hostile_target),
		"actor_faction" = A.faction, "target_faction" = fixture_hostile_target ? fixture_hostile_target.faction_text : null,
		"target_x" = fixture_hostile_target ? fixture_hostile_target.x : null,
		"target_y" = fixture_hostile_target ? fixture_hostile_target.y : null,
		"target_z" = fixture_hostile_target ? fixture_hostile_target.z : null,
		"target_sx" = fixture_hostile_target ? fixture_hostile_target.step_x : null,
		"target_sy" = fixture_hostile_target ? fixture_hostile_target.step_y : null,
		"target_bx" = fixture_hostile_target ? fixture_hostile_target.bound_x : null,
		"target_by" = fixture_hostile_target ? fixture_hostile_target.bound_y : null,
		"target_bw" = fixture_hostile_target ? fixture_hostile_target.bound_width : null,
		"target_bh" = fixture_hostile_target ? fixture_hostile_target.bound_height : null,
		"target_damage" = fixture_hostile_target ? fixture_hostile_target.getBruteLoss() : null,
		"target_adjacent" = !!(fixture_hostile_target && A.Adjacent(fixture_hostile_target)),
		"old_finished" = !!(fixture_hostile_lost_tx && fixture_hostile_lost_tx.finished),
		"old_completions" = fixture_hostile_old_completions,
		"wander_moves" = fixture_hostile_wander_moves, "attacks" = fixture_hostile_attack_calls,
		"positive_attacks" = fixture_hostile_positive_attacks,
		"damage_before" = damage_before, "result" = result, "call_id" = call_id)
	fixture_scheduler_assert(length(json_encode(event_row)) <= 900, "hostile_event_size")
	fixture_hostile_events += list(event_row)

/mob/living/simple_animal/hostile/panther/scheduler_hostile/Life()
	if (fixture_hostile_running)
		fixture_hostile_record("life_before", src)
	. = ..()
	if (fixture_hostile_running && src && !isDeleted(src))
		fixture_hostile_record("life_after", src)

/mob/living/simple_animal/hostile/panther/scheduler_hostile/Move()
	var/old_x = x * world.icon_size + step_x
	var/old_y = y * world.icon_size + step_y
	fixture_hostile_move_id++
	var/call_id = fixture_hostile_move_id
	if (fixture_hostile_running)
		fixture_hostile_record("move_before", src, null, call_id)
	. = ..()
	if (fixture_hostile_running && src && !isDeleted(src))
		if (fixture_hostile_phase == "wander" && !target_mob && (old_x != x * world.icon_size + step_x || old_y != y * world.icon_size + step_y))
			fixture_hostile_wander_moves++
		fixture_hostile_record("move_after", src, !!., call_id)

/mob/living/simple_animal/hostile/panther/scheduler_hostile/AttackingTarget()
	var/before = fixture_hostile_target ? fixture_hostile_target.getBruteLoss() : null
	if (fixture_hostile_running)
		fixture_hostile_attack_calls++
		fixture_hostile_record("attack_before", src, null, null, before)
	. = ..()
	if (fixture_hostile_running && src && !isDeleted(src))
		if (fixture_hostile_target && isnum(before) && fixture_hostile_target.getBruteLoss() > before)
			fixture_hostile_positive_attacks++
		fixture_hostile_record("attack_after", src, null, null, before)

/mob/living/simple_animal/hostile/panther/scheduler_hostile/living_movement_completed()
	if (fixture_hostile_running && fixture_hostile_lost_tx && fixture_hostile_lost_tx.completed && !fixture_hostile_lost_tx.finished)
		fixture_hostile_old_completions++
		fixture_hostile_record("lost_completion_hook", src)
	. = ..()

// One scheduler; no direct Life, pursuit or attack calls. The fixture supplies
// target introduction, relocation, and target-loss stimuli at observed boundaries.
/proc/fixture_scheduler_hostile_observe()
	fixture_scheduler_assert(world.tick_lag == 0.5 && !clients.len && !processScheduler && !living_mob_list.len, "hostile_fresh_world")
	rand_seed(741239)
	var/mob/living/simple_animal/hostile/panther/scheduler_hostile/A = new(locate(8, 7, 1))
	fixture_hostile_actor = A
	fixture_hostile_target = null
	fixture_hostile_lost_owner = null
	fixture_hostile_lost_tx = null
	fixture_hostile_move_id = 0; fixture_hostile_wander_moves = 0
	fixture_hostile_attack_calls = 0; fixture_hostile_positive_attacks = 0; fixture_hostile_old_completions = 0
	fixture_hostile_events = list(); fixture_transition_events = fixture_hostile_events
	fixture_scheduler_test_subjects = list(A); fixture_scheduler_subject = A; fixture_scheduler_target = null
	A.npc_subtile_enabled = TRUE; A.npc_subtile_pursuit_enabled = TRUE; A.npc_subtile_recovery_enabled = TRUE
	A.simplehunger = 1000; A.speak_chance = 0
	A.turns_since_move = A.move_to_delay - 1; A.ai_tick_delay = A.ai_tick_delay_max - 1
	fixture_scheduler_assert(A.behaviour == "hunt" && A.faction == "neutral" && A.npc_subtile_ready(), "hostile_actual_inheritance_and_shape")
	var/processScheduler/S = new
	processScheduler = S
	var/process/mob/P = new(S)
	S.addProcess(P)
	fixture_scheduler_assert(S.processes.len == 1 && S.processes[1] == P && P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS, "hostile_original_scheduler")
	fixture_hostile_running = TRUE; fixture_hostile_phase = "wander"
	var/started = world.time
	var/introduction_done = FALSE
	var/relocation_done = FALSE
	var/loss_done = FALSE
	S.start()
	while (world.time < started + 200)
		if (!introduction_done && fixture_hostile_wander_moves > 0 && !A.npc_subtile_transaction && !A.npc_subtile_pulse && !(A.step_x || A.step_y))
			fixture_hostile_record("target_intro_before", A)
			var/target_x = A.x <= 9 ? A.x + 4 : A.x - 4
			fixture_scheduler_assert(target_x >= 2 && target_x <= 17 && A.y >= 2 && A.y <= 13, "hostile_target_intro_geometry")
			var/mob/living/human/subtile_fixture/scheduler_target/H = new(locate(target_x, A.y, 1))
			H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H)
			H.faction_text = "fixture-human"; H.persistence_owner_ckey = "fixture-owner"
			H.real_name = "Movement subject"; H.name = H.real_name
			fixture_hostile_target = H; fixture_scheduler_target = H
			introduction_done = TRUE; fixture_hostile_phase = "acquire"
			fixture_hostile_record("target_intro_after", A)
		if (introduction_done && !relocation_done && fixture_hostile_positive_attacks > 0 && !A.npc_subtile_transaction && !A.npc_subtile_pulse)
			fixture_hostile_record("target_relocate_before", A)
			var/next_x = A.x <= 9 ? A.x + 4 : A.x - 4
			fixture_scheduler_assert(next_x >= 2 && next_x <= 17, "hostile_target_relocation_geometry")
			fixture_hostile_target.forceMove(locate(next_x, A.y, 1))
			fixture_scheduler_assert(fixture_hostile_target.x == next_x && fixture_hostile_target.y == A.y, "hostile_target_relocated")
			relocation_done = TRUE; fixture_hostile_phase = "reacquire"
			fixture_hostile_record("target_relocate_after", A)
		if (relocation_done && !loss_done && A.npc_subtile_pursuit && A.npc_subtile_transaction && A.npc_subtile_transaction.intent_owner == A.npc_subtile_pursuit && A.npc_subtile_offset_owned && (A.step_x || A.step_y))
			fixture_hostile_lost_owner = A.npc_subtile_pursuit
			fixture_hostile_lost_tx = A.npc_subtile_transaction
			fixture_hostile_record("target_loss_before", A)
			fixture_hostile_target.faction_text = A.faction
			A.npc_set_combat_target(null)
			loss_done = TRUE; fixture_hostile_phase = "lost"
			fixture_hostile_record("target_loss_after", A)
		fixture_hostile_record("sample", A)
		if (loss_done && fixture_hostile_lost_tx.finished && !A.npc_subtile_pursuit && !A.npc_subtile_pulse)
			break
		sleep(world.tick_lag)
	fixture_scheduler_assert(introduction_done && relocation_done && loss_done, "hostile_stimuli_completed")
	fixture_scheduler_assert(fixture_hostile_wander_moves > 0 && fixture_hostile_positive_attacks > 0, "hostile_wander_and_contact")
	fixture_scheduler_assert(fixture_hostile_lost_tx.finished && !fixture_hostile_lost_tx.arrived && fixture_hostile_old_completions == 1, "hostile_lost_transaction_retired")
	fixture_hostile_phase = "quiet"
	fixture_hostile_record("quiet_start", A)
	var/quiet_started = world.time
	while (world.time < quiet_started + 4)
		fixture_hostile_record("quiet_sample", A)
		sleep(world.tick_lag)
	fixture_hostile_record("quiet_end", A)
	S.stop()
	var/deadline = world.time + 10
	while ((P.running || P.queued || A.npc_subtile_transaction || A.npc_subtile_pulse || A.npc_subtile_pursuit || A.npc_subtile_wild_walk || A.npc_subtile_recovery || A.npc_subtile_pending_intent) && world.time < deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(P.ticks > 0 && !P.running && !P.queued && P.idle && !P.exceptions.len, "hostile_scheduler_quiesced")
	fixture_scheduler_assert(!A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_pursuit && !A.npc_subtile_wild_walk && !A.npc_subtile_follow && !A.npc_subtile_flee && !A.npc_subtile_pet_walk && !A.npc_subtile_recovery && !A.npc_subtile_pending_intent, "hostile_ownership_quiesced")
	fixture_hostile_record("cleanup", A)
	fixture_hostile_running = FALSE
	var/list/result = list("started" = started, "ended" = world.time, "process_ticks" = P.ticks,
		"life_interval_ds" = P.schedule_interval, "start_delay_ds" = P.start_delay,
		"tick_lag_ds" = world.tick_lag, "actual_clients" = clients.len, "events" = fixture_hostile_events.Copy())
	fixture_scheduler_test_subjects = list(); fixture_scheduler_subject = null; fixture_scheduler_target = null
	qdel(A); qdel(fixture_hostile_target); qdel(P); processes.mob = null; processScheduler = null; qdel(S)
	return result

/proc/fixture_scheduler_hostile_main()
	fixture_transition_rows = list()
	fixture_transition_rows += list(fixture_scheduler_hostile_observe())
	fixture_transition_phase = "quiet"
	return fixture_transition_rows