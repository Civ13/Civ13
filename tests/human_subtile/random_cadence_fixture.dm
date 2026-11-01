// Fixture-only observation. This file is not included by a production DME.
// Observer procs only read actor state and append bounded records; no sleep,
// probability draw, movement, command, or ownership change occurs in them.
var/global/list/fixture_random_rows = list()
var/global/list/fixture_random_events = list()
var/global/fixture_random_count = 0
var/global/fixture_random_phase_count = 0
var/global/fixture_random_life_count = 0
var/global/fixture_random_tx_count = 0
var/global/fixture_random_move_enter_count = 0
var/global/fixture_random_move_exit_count = 0
var/global/fixture_random_overflow = FALSE
var/global/fixture_random_running = FALSE
var/global/fixture_random_policy
var/global/fixture_random_calls = 0
var/global/fixture_random_case
var/global/fixture_random_life_depth = 0

/proc/fixture_random_observe(label, mob/living/simple_animal/A, detail = null, datum/npc_subtile_transaction/T = null)
	if (!fixture_random_running || !(A in fixture_scheduler_test_subjects))
		return
	// Reserve 420 events for 210 paired Move callbacks (including nested),
	// 48 for 12 full transaction lifecycles, 42 for three Life callbacks,
	// and two for phase boundaries. Exceeding any bound is a visible failure.
	if (fixture_random_phase_count >= 512 || fixture_random_count >= 4096 || \
		(label in list("contact_mosquito_life_before", "contact_bat_life_before") && fixture_random_life_count >= 3) || \
		(label == "tx_admitted" && fixture_random_tx_count >= 12) || \
		(label == "move_enter" && fixture_random_move_enter_count >= 210) || \
		(label == "move_exit" && fixture_random_move_exit_count >= 210))
		fixture_random_overflow = TRUE
		return
	fixture_random_phase_count++
	fixture_random_count++
	if (label in list("contact_mosquito_life_before", "contact_bat_life_before"))
		fixture_random_life_count++
	else if (label == "tx_admitted")
		fixture_random_tx_count++
	else if (label == "move_enter")
		fixture_random_move_enter_count++
	else if (label == "move_exit")
		fixture_random_move_exit_count++
	var/datum/npc_subtile_wild_walk/W = A.npc_subtile_wild_walk
	var/datum/npc_subtile_pending_intent/P = A.npc_subtile_pending_intent
	fixture_random_events += list(list("event" = label, "at" = world.time, "tick_usage" = world.tick_usage,
		"life_depth" = fixture_random_life_depth, "detail" = detail,
		"x" = A.x, "y" = A.y, "z" = A.z, "sx" = A.step_x, "sy" = A.step_y,
		"dir" = A.dir, "step_size" = A.step_size, "enabled" = A.npc_subtile_species_enabled,
		"settled" = A.npc_subtile_contact_settled(), "transaction" = !!A.npc_subtile_transaction,
		"pulse" = !!A.npc_subtile_pulse,
		"owner" = W ? "\ref[W]" : null, "generation" = A.move_gen,
		"revision" = W ? W.revision : null, "due" = W ? W.due : null,
		"pending" = P ? "\ref[P]" : null,
		"active_tx" = A.npc_subtile_transaction ? "\ref[A.npc_subtile_transaction]" : null,
		"tx" = T ? "\ref[T]" : null, "arrived" = T ? T.arrived : null,
		"tx_finished" = T ? !!T.finished : null, "tx_actor_present" = T ? !!T.actor : null,
		"tx_target_present" = T ? !!T.target : null, "tx_combat_present" = T ? !!T.combat_target : null,
		"tx_following_present" = T ? !!T.following : null, "tx_intent_present" = T ? !!T.intent_owner : null,
		"tx_dir" = T ? T.direction : null, "remaining_x" = T ? T.remaining_x : null,
		"remaining_y" = T ? T.remaining_y : null,
		"range" = fixture_scheduler_target && (fixture_scheduler_target in range(1, A)),
		"target_x" = fixture_scheduler_target ? fixture_scheduler_target.x : null,
		"target_y" = fixture_scheduler_target ? fixture_scheduler_target.y : null,
		"target_z" = fixture_scheduler_target ? fixture_scheduler_target.z : null,
		"target_sx" = fixture_scheduler_target ? fixture_scheduler_target.step_x : null,
		"target_sy" = fixture_scheduler_target ? fixture_scheduler_target.step_y : null,
		"target_brute" = fixture_scheduler_target ? fixture_scheduler_target.getBruteLoss() : null,
		"target_disease" = fixture_scheduler_target ? fixture_scheduler_target.disease : null,
		"target_disease_type" = fixture_scheduler_target ? fixture_scheduler_target.disease_type : null))

/mob/living/simple_animal/mosquito/scheduler_probe/random_probe/Move()
	fixture_random_observe("move_enter", src, args.len >= 2 ? args[2] : null)
	. = ..()
	fixture_random_observe("move_exit", src, .)

/mob/living/simple_animal/mosquito/scheduler_probe/random_probe/Life()
	fixture_random_life_depth++
	. = ..()
	fixture_random_life_depth--

/mob/living/simple_animal/vampirebatblack/scheduler_probe/random_probe/Move()
	fixture_random_observe("move_enter", src, args.len >= 2 ? args[2] : null)
	. = ..()
	fixture_random_observe("move_exit", src, .)

/mob/living/simple_animal/vampirebatblack/scheduler_probe/random_probe/Life()
	fixture_random_life_depth++
	. = ..()
	fixture_random_life_depth--

// These wrappers are deliberate fixture controls, not observers: held mode
// issues the first Life command and suppresses later identical commands;
// reissue mode forwards every actual Life command to production unchanged.
/mob/living/simple_animal/mosquito/scheduler_probe/random_probe/npc_subtile_species_walk(mode, atom/target = null, lag = 0, direction = 0, distance_limit = 0)
	fixture_random_observe("command_before", src, list("mode" = mode, "lag" = lag, "speed_argument" = 0))
	fixture_random_calls++
	if (fixture_random_policy == "held" && fixture_random_calls > 1)
		fixture_random_observe("command_suppressed", src)
		return
	. = ..()
	fixture_random_observe("command_after", src, .)

/mob/living/simple_animal/vampirebatblack/scheduler_probe/random_probe/npc_subtile_species_walk(mode, atom/target = null, lag = 0, direction = 0, distance_limit = 0)
	fixture_random_observe("command_before", src, list("mode" = mode, "lag" = lag, "speed_argument" = 0))
	fixture_random_calls++
	if (fixture_random_policy == "held" && fixture_random_calls > 1)
		fixture_random_observe("command_suppressed", src)
		return
	. = ..()
	fixture_random_observe("command_after", src, .)

/proc/fixture_random_phase(animal_type, enabled, policy, phase_ticks)
	fixture_scheduler_assert(animal_type in list(/mob/living/simple_animal/mosquito/scheduler_probe/random_probe, /mob/living/simple_animal/vampirebatblack/scheduler_probe/random_probe), "random_type")
	fixture_scheduler_assert(policy in list("held", "reissue") && phase_ticks in list(0, 2), "random_case")
	fixture_scheduler_assert(!processScheduler && !fixture_random_running && !living_mob_list.len, "random_fresh_phase")
	var/mob/living/simple_animal/A = new animal_type(locate(33, 33, 1))
	var/mob/living/human/subtile_fixture/scheduler_target/H = new(locate(33, 34, 1))
	H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H)
	H.persistence_owner_ckey = "fixture-owner"; H.real_name = "Movement subject"; H.name = H.real_name
	H.m_intent = "walk"
	H.equip_to_slot(new /obj/item/clothing/under/squid_contestant(H), slot_w_uniform)
	fixture_scheduler_assert(living_mob_list.len == 2 && (A in living_mob_list) && (H in living_mob_list), "random_actor_list")
	fixture_scheduler_subject = A; fixture_scheduler_target = H
	fixture_scheduler_test_subjects = list(A)
	fixture_scheduler_choice_counts = list()
	fixture_scheduler_scenario = "random"
	A.npc_subtile_enabled = !!enabled
	A.npc_subtile_species_enabled = !!enabled
	A.npc_subtile_recovery_enabled = !!enabled
	var/processScheduler/S = new
	processScheduler = S
	var/process/mob/P = new(S)
	S.addProcess(P)
	fixture_scheduler_assert(S.processes.len == 1 && S.processes[1] == P && P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS, "random_mob_scheduler")
	fixture_scheduler_events = list()
	fixture_random_events = list()
	fixture_random_phase_count = 0
	fixture_random_life_count = 0
	fixture_random_tx_count = 0
	fixture_random_move_enter_count = 0
	fixture_random_move_exit_count = 0
	fixture_random_policy = policy
	fixture_random_calls = 0
	fixture_random_case = "[animal_type]:[policy]:[phase_ticks]"
	rand_seed(741239)
	if (phase_ticks)
		sleep(phase_ticks * world.tick_lag)
	var/started = world.time
	fixture_scheduler_running = TRUE
	fixture_random_running = TRUE
	fixture_random_observe("phase_start", A)
	S.start()
	while (world.time < started + 28 && !fixture_random_overflow)
		sleep(world.tick_lag)
	S.stop()
	var/finish_deadline = world.time + 10
	while ((P.running || P.queued) && world.time < finish_deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!P.running && !P.queued && P.idle && !P.exceptions.len, "random_scheduler_stopped")
	fixture_scheduler_assert(!fixture_random_life_depth, "random_life_quiesced")
	walk(A, 0)
	A.npc_subtile_stop_wild_walk()
	while (A.npc_subtile_transaction && world.time < finish_deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!A.npc_subtile_transaction && !A.npc_subtile_pulse, "random_owner_quiesced")
	fixture_random_observe("phase_end", A)
	fixture_scheduler_assert(!fixture_random_overflow, "random_event_bound")
	fixture_random_running = FALSE
	fixture_scheduler_running = FALSE
	var/list/result = list("case" = fixture_random_case, "subject" = "[animal_type]", "policy" = policy,
		"phase_ticks" = phase_ticks, "started" = started, "ended" = world.time, "tick_lag_ds" = world.tick_lag, "observation_ds" = 28,
		"enabled" = !!enabled, "step_size" = A.step_size, "speed_argument" = 0, "process_ticks" = P.ticks,
		"life_interval_ds" = P.schedule_interval, "initial_start_delay_ds" = P.start_delay,
		"actual_clients" = clients.len, "seed" = 741239, "event_count" = fixture_random_phase_count,
		"life_count" = fixture_random_life_count, "tx_count" = fixture_random_tx_count,
		"move_enter_count" = fixture_random_move_enter_count, "move_exit_count" = fixture_random_move_exit_count,
		"events" = fixture_random_events.Copy())
	fixture_scheduler_test_subjects = list()
	fixture_scheduler_scenario = null
	fixture_scheduler_subject = null; fixture_scheduler_target = null
	qdel(A); qdel(H); qdel(P)
	processes.mob = null; processScheduler = null
	qdel(S)
	return result

/proc/fixture_random_main()
	var/mode = world.params["random_mode"]
	var/requested_tick = text2num(world.params["random_tick"])
	fixture_scheduler_assert(mode in list("legacy", "parent", "candidate") && requested_tick in list(0.5, 1), "random_mode_tick")
	world.tick_lag = requested_tick
	fixture_scheduler_assert(world.tick_lag == requested_tick, "random_tick_readback")
	fixture_random_rows = list()
	for (var/policy in list("held", "reissue"))
		for (var/phase_ticks in list(0, 2))
			fixture_random_rows += list(fixture_random_phase(/mob/living/simple_animal/mosquito/scheduler_probe/random_probe, mode != "legacy", policy, phase_ticks))
			fixture_random_rows += list(fixture_random_phase(/mob/living/simple_animal/vampirebatblack/scheduler_probe/random_probe, mode != "legacy", policy, phase_ticks))
	fixture_scheduler_assert(fixture_random_rows.len == 8, "random_all_cases")
