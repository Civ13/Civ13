// Draft only: isolated real mob-process scheduler scaffold for the paired
// ordinary-wildlife tests. Not in any DME or cloud suite; not acceptance.
// Its staged source adapter and host comparison live in the adjacent Python
// draft; neither is wired into a job and this covers insect contact only.
var/global/fixture_scheduler_running = FALSE
var/global/list/fixture_scheduler_events = list()
var/global/list/fixture_scheduler_test_subjects = list()
var/global/list/fixture_scheduler_choice_counts = list()
var/global/fixture_scheduler_scenario = null
var/global/fixture_scheduler_checks = 0
var/global/mob/living/simple_animal/fixture_scheduler_subject
var/global/mob/living/human/fixture_scheduler_target
var/global/list/fixture_scheduler_rows = list()

/proc/fixture_scheduler_assert(condition, label)
	fixture_scheduler_checks++
	if (!condition)
		throw EXCEPTION(label)

/proc/fixture_scheduler_record(label, mob/living/simple_animal/A, choice = null, raw = null, chance = null)
	if (fixture_scheduler_events.len >= 4096)
		throw EXCEPTION("scheduler_event_bound")
	var/datum/npc_subtile_wild_walk/W = A.npc_subtile_wild_walk
	fixture_scheduler_events += list(list("event" = label, "at" = world.time,
		"x" = A.x, "y" = A.y, "z" = A.z, "sx" = A.step_x, "sy" = A.step_y,
		"settled" = A.npc_subtile_contact_settled(), "transaction" = !!A.npc_subtile_transaction,
		"wild_owner" = !!W, "wild_due" = W ? W.due : null, "wild_idle_end" = W ? W.idle_window_end : null,
		"wild_revision" = W ? W.revision : null, "wild_generation" = W ? W.generation : null,
		"wild_mode" = W ? W.mode : null, "wild_target_matches" = W ? (W.target == fixture_scheduler_target) : null,
		"generation" = A.move_gen,
		"pending" = !!A.npc_subtile_pending_intent, "recovery" = !!A.npc_subtile_recovery,
		"choice" = choice, "native_choice" = raw, "chance" = chance,
		"target_x" = fixture_scheduler_target ? fixture_scheduler_target.x : null,
		"target_y" = fixture_scheduler_target ? fixture_scheduler_target.y : null,
		"target_z" = fixture_scheduler_target ? fixture_scheduler_target.z : null,
		"target_sx" = fixture_scheduler_target ? fixture_scheduler_target.step_x : null,
		"target_sy" = fixture_scheduler_target ? fixture_scheduler_target.step_y : null,
		"target_in_range" = fixture_scheduler_target && (fixture_scheduler_target in range(1, A)),
		"target_brute" = fixture_scheduler_target ? fixture_scheduler_target.getBruteLoss() : null,
		"target_disease" = fixture_scheduler_target ? fixture_scheduler_target.disease : null))

// Staged fixture replaces exact Life roll sites only. Consume the native RNG
// call at each original site, then apply an explicit bounded choice tape.
/proc/fixture_scheduler_prob(chance, mob/living/simple_animal/A, site)
	var/native_result = prob(chance)
	if (!(A in fixture_scheduler_test_subjects))
		return native_result
	fixture_scheduler_assert((site == "mosquito_seek" && chance == 70) || (site == "mosquito_water" && chance == 15) || (site == "mosquito_bite" && chance == 10) || (site == "bat_seek" && chance == 80) || ((site == "bat_cow" || site == "bat_bull") && chance == 20) || (site == "bat_bite" && chance == 5), "scheduler_exact_choice_site")
	var/previous = fixture_scheduler_choice_counts[site]
	var/ordinal = (isnum(previous) ? previous : 0) + 1
	fixture_scheduler_choice_counts[site] = ordinal
	var/list/tape
	if (site == "mosquito_seek" || site == "bat_seek")
		tape = fixture_scheduler_scenario == "chase" ? list(TRUE) : list(TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE)
	else if (site == "mosquito_bite" || site == "bat_bite")
		tape = list(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE)
	else
		tape = list(FALSE)
	var/choice = tape[((ordinal - 1) % tape.len) + 1]
	fixture_scheduler_record("roll_[site]", A, choice, native_result, chance)
	return choice

/proc/fixture_scheduler_infection_prob(chance, mob/living/simple_animal/A, mob/living/human/H, disease_name)
	var/native_result = prob(chance)
	if (!(A in fixture_scheduler_test_subjects))
		return native_result
	fixture_scheduler_assert(H == fixture_scheduler_target && disease_name == "malaria" && (chance == 20 || chance == 25), "scheduler_infection_site")
	var/previous = fixture_scheduler_choice_counts["infection"]
	var/ordinal = (isnum(previous) ? previous : 0) + 1
	fixture_scheduler_choice_counts["infection"] = ordinal
	var/list/tape = list(FALSE, TRUE)
	var/choice = tape[((ordinal - 1) % tape.len) + 1]
	fixture_scheduler_record("infection_roll", A, choice, native_result, chance)
	return choice

/proc/fixture_scheduler_infect(mob/living/simple_animal/A, mob/living/human/H, chance, disease_name)
	if (A in fixture_scheduler_test_subjects)
		fixture_scheduler_record("infection_before", A)
	var/result = A.try_infect(H, chance, disease_name)
	if (A && !isDeleted(A) && (A in fixture_scheduler_test_subjects))
		fixture_scheduler_record("infection_after", A, result)
	return result

// Replaces the exact bite damage call in staged species sources. It records
// around the unchanged actual adjustment; infection code remains untouched.
/proc/fixture_scheduler_bite(mob/living/human/H, mob/living/simple_animal/A)
	if (A in fixture_scheduler_test_subjects)
		fixture_scheduler_record("bite_before", A)
	H.adjustBruteLoss(1, 2)
	if (A && !isDeleted(A) && (A in fixture_scheduler_test_subjects))
		fixture_scheduler_record("bite_after", A)

/mob/living/human/subtile_fixture/scheduler_target

/mob/living/simple_animal/mosquito/scheduler_probe
	// Set by fixture setup before scheduler.start(); never inherited by wildlife.
	npc_subtile_enabled = FALSE
	npc_subtile_species_enabled = FALSE
	npc_subtile_recovery_enabled = FALSE

/mob/living/simple_animal/mosquito/scheduler_probe/Life()
	if (fixture_scheduler_running)
		fixture_scheduler_record("mosquito_life_before", src)
	. = ..()
	if (src && !isDeleted(src) && fixture_scheduler_running)
		fixture_scheduler_record("mosquito_life_after", src)

/mob/living/simple_animal/mosquito/scheduler_probe/Move()
	if (fixture_scheduler_running)
		fixture_scheduler_record("mosquito_move_before", src)
	. = ..()
	if (src && !isDeleted(src) && fixture_scheduler_running)
		fixture_scheduler_record("mosquito_move_after", src)

/mob/living/simple_animal/mosquito/scheduler_probe/npc_subtile_species_walk(mode, atom/target = null, lag = 0, direction = 0, distance_limit = 0)
	if (fixture_scheduler_running)
		fixture_scheduler_record("mosquito_intent_[mode]", src, target == fixture_scheduler_target, null, lag)
	return ..()

/mob/living/simple_animal/vampirebatblack/scheduler_probe
	npc_subtile_enabled = FALSE
	npc_subtile_species_enabled = FALSE
	npc_subtile_recovery_enabled = FALSE

/mob/living/simple_animal/vampirebatblack/scheduler_probe/Life()
	if (fixture_scheduler_running)
		fixture_scheduler_record("bat_life_before", src)
	. = ..()
	if (src && !isDeleted(src) && fixture_scheduler_running)
		fixture_scheduler_record("bat_life_after", src)

/mob/living/simple_animal/vampirebatblack/scheduler_probe/Move()
	if (fixture_scheduler_running)
		fixture_scheduler_record("bat_move_before", src)
	. = ..()
	if (src && !isDeleted(src) && fixture_scheduler_running)
		fixture_scheduler_record("bat_move_after", src)

/mob/living/simple_animal/vampirebatblack/scheduler_probe/npc_subtile_species_walk(mode, atom/target = null, lag = 0, direction = 0, distance_limit = 0)
	if (fixture_scheduler_running)
		fixture_scheduler_record("bat_intent_[mode]", src, target == fixture_scheduler_target, null, lag)
	return ..()

// One fresh daemon, one subject, one target, and only the real mob process.
// This produces observations, not a baseline/candidate equivalence verdict.
/proc/fixture_scheduler_observe(animal_type, enabled, observation_ds, scenario)
	fixture_scheduler_assert(animal_type in list(/mob/living/simple_animal/mosquito/scheduler_probe, /mob/living/simple_animal/vampirebatblack/scheduler_probe), "scheduler_exact_type")
	fixture_scheduler_assert(scenario in list("chase", "suppression"), "scheduler_exact_scenario")
	fixture_scheduler_assert(!processScheduler && !fixture_scheduler_running && !living_mob_list.len, "scheduler_fresh_world")
	fixture_scheduler_assert(observation_ds >= 20 && observation_ds <= 100, "scheduler_bounded_duration")
	rand_seed(741239)
	var/mob/living/simple_animal/A = new animal_type(locate(6, 6, 1))
	var/mob/living/human/subtile_fixture/scheduler_target/H = new(locate(9, 6, 1))
	H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H)
	H.persistence_owner_ckey = "fixture-owner"; H.real_name = "Movement subject"; H.name = H.real_name
	H.m_intent = "walk"
	H.equip_to_slot(new /obj/item/clothing/under/squid_contestant(H), slot_w_uniform)
	fixture_scheduler_assert(living_mob_list.len == 2 && (A in living_mob_list) && (H in living_mob_list), "scheduler_fixture_actor_list")
	fixture_scheduler_subject = A; fixture_scheduler_target = H
	fixture_scheduler_test_subjects = list(A)
	fixture_scheduler_choice_counts = list()
	fixture_scheduler_scenario = scenario
	A.npc_subtile_enabled = !!enabled
	A.npc_subtile_species_enabled = !!enabled
	A.npc_subtile_recovery_enabled = !!enabled
	var/processScheduler/S = new
	processScheduler = S
	var/process/mob/P = new(S)
	S.addProcess(P)
	fixture_scheduler_assert(S.processes.len == 1 && S.processes[1] == P && P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS, "scheduler_original_configuration")
	fixture_scheduler_events = list()
	fixture_scheduler_running = TRUE
	var/started = world.time
	S.start()
	// Three deterministic target steps, timed independently of actor Life.
	if (scenario == "chase")
		for (var/offset in list(20, 40, 60))
			spawn(offset)
				if (fixture_scheduler_running && fixture_scheduler_subject == A && fixture_scheduler_target == H && A && !isDeleted(A) && H && !isDeleted(H))
					fixture_scheduler_record("target_step_before", A)
					var/moved = step(H, EAST)
					fixture_scheduler_record("target_step_after", A, !!moved)
	while (world.time < started + observation_ds)
		fixture_scheduler_record("position_sample", A)
		sleep(world.tick_lag)
	S.stop()
	var/finish_deadline = world.time + 10
	while ((P.running || P.queued) && world.time < finish_deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!P.running && !P.queued && P.idle, "scheduler_process_quiesced")
	fixture_scheduler_assert(!P.exceptions.len, "scheduler_no_process_exceptions")
	fixture_scheduler_running = FALSE
	fixture_scheduler_assert(A && !isDeleted(A) && H && !isDeleted(H), "scheduler_subjects_survived")
	var/list/result = list("enabled" = !!enabled, "subject" = "[animal_type]", "started" = started,
		"ended" = world.time, "process_ticks" = P.ticks, "life_interval_ds" = P.schedule_interval,
		"initial_start_delay_ds" = P.start_delay, "actual_clients" = clients.len, "tick_lag_ds" = world.tick_lag,
		"seed" = 741239, "scenario" = scenario, "choice_tape" = "bite:10110110;secondary:0;infection:01",
		"subject_health" = A.health, "target_health" = H.health, "target_brute" = H.getBruteLoss(), "target_disease" = H.disease,
		"events" = fixture_scheduler_events.Copy())
	fixture_scheduler_assert(P.ticks > 0 && fixture_scheduler_events.len > 0, "scheduler_actual_fire_observed")
	walk(A, 0)
	A.npc_subtile_stop_wild_walk()
	fixture_scheduler_test_subjects = list()
	fixture_scheduler_scenario = null
	fixture_scheduler_subject = null; fixture_scheduler_target = null
	qdel(A); qdel(H); qdel(P)
	processes.mob = null
	processScheduler = null
	qdel(S)
	return result

/proc/fixture_scheduler_main()
	var/mode = world.params["scheduler_mode"]
	fixture_scheduler_assert(mode in list("legacy", "smooth"), "scheduler_mode_required")
	fixture_scheduler_rows = list()
	for (var/scenario in list("chase", "suppression"))
		fixture_scheduler_rows += list(fixture_scheduler_observe(/mob/living/simple_animal/mosquito/scheduler_probe, mode == "smooth", 80, scenario))
		fixture_scheduler_rows += list(fixture_scheduler_observe(/mob/living/simple_animal/vampirebatblack/scheduler_probe, mode == "smooth", 80, scenario))
	fixture_scheduler_assert(fixture_scheduler_rows.len == 4, "scheduler_both_subjects_observed")


// Source-only transition draft. Not called by fixture_scheduler_main and not
// selected by species05. A reviewed staging adapter and host oracle are still
// required before this can be compiled or run.
var/global/list/fixture_transition_rows = list()
var/global/fixture_transition_running = FALSE
var/global/fixture_transition_phase = null
var/global/list/fixture_transition_events = list()
var/global/list/fixture_transition_accepted = list()
var/global/fixture_transition_follow_moves = 0
var/global/fixture_transition_flee_moves = 0
var/global/fixture_transition_pet_moves = 0
var/global/fixture_transition_sequence = 0
var/global/fixture_transition_command_sequence = 0
var/global/fixture_transition_command_id = 0
var/global/fixture_transition_command_kind = null
var/global/fixture_transition_active_moves = 0
var/global/fixture_transition_move_entries = 0

/proc/fixture_transition_record(label, mob/living/simple_animal/A, kind = null, accepted = null, call_id = null)
	fixture_scheduler_assert(fixture_transition_events.len < 4096, "transition_event_bound")
	fixture_scheduler_assert(A && !isDeleted(A), "transition_live_actor")
	fixture_scheduler_assert(!A.npc_subtile_enabled && !A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_follow && !A.npc_subtile_flee && !A.npc_subtile_pet_walk && !A.npc_subtile_pursuit && !A.npc_subtile_wild_walk && !A.npc_subtile_recovery && !A.npc_subtile_pending_intent, "transition_no_staged_owner")
	fixture_transition_events += list(list("event" = label, "at" = world.time, "phase" = fixture_transition_phase,
		"kind" = kind, "accepted" = accepted, "call_id" = call_id,
		"command_id" = fixture_transition_command_id, "command_kind" = fixture_transition_command_kind,
		"x" = A.x, "y" = A.y, "z" = A.z,
		"sx" = A.step_x, "sy" = A.step_y, "generation" = A.move_gen,
		"follow_flag" = !!A.npc_subtile_follow_enabled, "flee_flag" = !!A.npc_subtile_flee_enabled,
		"pet_flag" = !!A.npc_subtile_pet_enabled, "base_flag" = !!A.npc_subtile_enabled,
		"transaction" = !!A.npc_subtile_transaction, "pulse" = !!A.npc_subtile_pulse,
		"follow_owner" = !!A.npc_subtile_follow, "flee_owner" = !!A.npc_subtile_flee,
		"pet_owner" = !!A.npc_subtile_pet_walk, "pursuit_owner" = !!A.npc_subtile_pursuit,
		"wild_owner" = !!A.npc_subtile_wild_walk, "pending" = !!A.npc_subtile_pending_intent,
		"recovery" = !!A.npc_subtile_recovery))


// Called immediately after exact staged native command sites return. Markers
// are test-only; non-subject actors do not record or alter command state.
/proc/fixture_transition_command_return(mob/living/simple_animal/A, kind)
	if (!fixture_transition_running || A != fixture_scheduler_subject)
		return
	fixture_scheduler_assert(kind in list("follow", "flee", "pet"), "transition_command_kind")
	fixture_scheduler_assert(!fixture_transition_active_moves, "transition_dispatch_overlapping_move")
	fixture_transition_command_sequence++
	fixture_transition_command_id = fixture_transition_command_sequence
	fixture_transition_command_kind = kind
	fixture_transition_record("command_return", A, kind)

// Called after a staged native stop site (cat scan or old flee timer) returns.
/proc/fixture_transition_native_stop_return(mob/living/simple_animal/A, kind)
	if (!fixture_transition_running || A != fixture_scheduler_subject)
		return
	fixture_scheduler_assert(!fixture_transition_active_moves, "transition_native_stop_overlapping_move")
	fixture_transition_command_id = 0
	fixture_transition_command_kind = null
	fixture_transition_record("native_stop_return", A, kind)

// Explicit fixture cancellation, not a claim that AI naturally stopped itself.
/proc/fixture_transition_explicit_stop(mob/living/simple_animal/A)
	fixture_scheduler_assert(!fixture_transition_active_moves, "transition_stop_overlapping_move")
	fixture_transition_sequence++
	var/call_id = fixture_transition_sequence
	fixture_transition_record("stop_before", A, null, null, call_id)
	walk(A, 0)
	fixture_transition_command_id = 0
	fixture_transition_command_kind = null
	fixture_transition_record("stop_after", A, null, null, call_id)

/mob/living/simple_animal/pet/cat/scheduler_transition

/mob/living/simple_animal/pet/cat/scheduler_transition/Life()
	var/call_id = null
	if (fixture_transition_running)
		fixture_transition_sequence++
		call_id = fixture_transition_sequence
		fixture_transition_record("life_before", src, null, null, call_id)
	. = ..()
	if (fixture_transition_running && src && !isDeleted(src))
		fixture_transition_record("life_after", src, null, null, call_id)

/mob/living/simple_animal/pet/cat/scheduler_transition/Move()
	var/old_x = x * world.icon_size + step_x
	var/old_y = y * world.icon_size + step_y
	var/call_id = null
	var/entry_command = fixture_transition_command_id
	var/entry_kind = fixture_transition_command_kind
	if (fixture_transition_running)
		fixture_transition_sequence++
		call_id = fixture_transition_sequence
		fixture_transition_active_moves++
		fixture_transition_move_entries++
		fixture_transition_record("move_before", src, null, null, call_id)
	. = ..()
	if (fixture_transition_running && src && !isDeleted(src))
		fixture_transition_active_moves--
		fixture_transition_record("move_after", src, null, . ? TRUE : FALSE, call_id)
		if (entry_command && entry_command == fixture_transition_command_id && entry_kind == fixture_transition_command_kind && (old_x != x * world.icon_size + step_x || old_y != y * world.icon_size + step_y))
			if (fixture_transition_phase == "follow" && entry_kind == "follow")
				fixture_transition_follow_moves++
			else if (fixture_transition_phase == "flee" && entry_kind == "flee")
				fixture_transition_flee_moves++
			else if (fixture_transition_phase == "pet" && entry_kind == "pet")
				fixture_transition_pet_moves++

/mob/living/simple_animal/pet/cat/scheduler_transition/npc_subtile_continuous_legacy_ready(kind)
	var/call_id = null
	if (fixture_transition_running)
		fixture_transition_sequence++
		call_id = fixture_transition_sequence
		fixture_transition_record("ready_before", src, kind, null, call_id)
	. = ..()
	if (fixture_transition_running && src && !isDeleted(src))
		fixture_transition_record("ready_after", src, kind, . ? TRUE : FALSE, call_id)
		if (.)
			var/previous = fixture_transition_accepted[kind]
			fixture_transition_accepted[kind] = (isnum(previous) ? previous : 0) + 1

// Explicit initial state and timed stimulus are fixture inputs. All Life,
// follow, flee, and pet commands still come from the real scheduler/AI routes.
/proc/fixture_scheduler_transition_observe(mode, scenario)
	fixture_scheduler_assert(mode in list("legacy", "mixed"), "transition_mode")
	fixture_scheduler_assert(scenario in list("follow_flee", "pet"), "transition_scenario")
	fixture_scheduler_assert(world.tick_lag == 0.5 && !clients.len && !processScheduler && !living_mob_list.len, "transition_fresh_world")
	rand_seed(741239)
	var/mob/living/simple_animal/pet/cat/scheduler_transition/A = new(locate(6, 6, 1))
	var/mob/living/human/subtile_fixture/scheduler_target/H = new(locate(10, 6, 1))
	var/mob/living/simple_animal/mouse/M = null
	H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H)
	H.persistence_owner_ckey = "fixture-owner"; H.real_name = "Movement subject"; H.name = H.real_name
	A.npc_subtile_enabled = FALSE
	A.npc_subtile_follow_enabled = mode == "mixed"
	A.npc_subtile_flee_enabled = mode == "mixed"
	A.npc_subtile_pet_enabled = mode == "mixed"
	A.npc_subtile_recovery_enabled = FALSE
	A.simplehunger = 1000; A.speak_chance = 0; A.behaviour = "none"
	A.turns_since_move = A.move_to_delay - 1; A.ai_tick_delay = A.ai_tick_delay_max - 1
	if (scenario == "follow_flee")
		A.npc_set_following(H)
		fixture_transition_phase = "follow"
	else
		M = new(locate(9, 6, 1))
		M.anchored = TRUE
		A.npc_set_movement_target(M)
		A.turns_since_scan = 5
		fixture_transition_phase = "pet"
	fixture_scheduler_test_subjects = list(A)
	fixture_scheduler_subject = A; fixture_scheduler_target = H
	fixture_transition_events = list(); fixture_transition_accepted = list()
	fixture_transition_follow_moves = 0; fixture_transition_flee_moves = 0; fixture_transition_pet_moves = 0; fixture_transition_sequence = 0
	fixture_transition_command_sequence = 0; fixture_transition_command_id = 0; fixture_transition_command_kind = null
	fixture_transition_active_moves = 0; fixture_transition_move_entries = 0
	var/processScheduler/S = new
	processScheduler = S
	var/process/mob/P = new(S)
	S.addProcess(P)
	fixture_scheduler_assert(S.processes.len == 1 && S.processes[1] == P && P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS, "transition_original_scheduler")
	fixture_transition_running = TRUE
	var/started = world.time
	var/changed = FALSE
	var/gap_started = FALSE
	var/gap_moves = 0
	S.start()
	while (world.time < started + (scenario == "follow_flee" ? 100 : 12))
		if (scenario == "follow_flee" && !gap_started && world.time >= started + 30)
			fixture_transition_record("stimulus_before", A)
			fixture_scheduler_assert(fixture_transition_accepted["follow"] && fixture_transition_follow_moves > 0, "transition_follow_observed")
			A.npc_set_following(null)
			A.stop_automated_movement = FALSE; A.behaviour = "none"
			fixture_transition_phase = "gap"; gap_started = TRUE
			fixture_transition_explicit_stop(A)
			gap_moves = fixture_transition_move_entries
		if (scenario == "follow_flee" && gap_started && !changed && world.time >= started + 40)
			fixture_scheduler_assert(!fixture_transition_active_moves && fixture_transition_move_entries == gap_moves, "transition_gap_quiet")
			A.behaviour = "scared"
			A.turns_since_move = A.move_to_delay - 1; A.ai_tick_delay = A.ai_tick_delay_max - 1
			fixture_transition_phase = "flee"; changed = TRUE
			fixture_transition_record("stimulus_after", A)
		fixture_transition_record("sample", A)
		sleep(world.tick_lag)
	fixture_transition_record("observation_end", A)
	S.stop()
	var/finish_deadline = world.time + 10
	while ((P.running || P.queued) && world.time < finish_deadline)
		sleep(world.tick_lag)
	fixture_scheduler_assert(P.ticks > 0 && !P.running && !P.queued && P.idle && !P.exceptions.len, "transition_scheduler_quiesced")
	if (scenario == "follow_flee")
		fixture_scheduler_assert(changed && fixture_transition_accepted["flee"] && fixture_transition_flee_moves > 0, "transition_flee_observed")
	else
		fixture_scheduler_assert(fixture_transition_accepted["pet"] && fixture_transition_pet_moves > 0, "transition_pet_observed")
	fixture_transition_phase = "quiet"
	fixture_transition_explicit_stop(A)
	var/quiet_moves = fixture_transition_move_entries
	var/quiet_started = world.time
	while (world.time < quiet_started + 4)
		fixture_transition_record("quiet_sample", A)
		sleep(world.tick_lag)
	fixture_scheduler_assert(!fixture_transition_active_moves && fixture_transition_move_entries == quiet_moves, "transition_final_quiet")
	fixture_transition_record("quiet_end", A)
	fixture_transition_record("end", A)
	fixture_transition_running = FALSE
	var/list/result = list("mode" = mode, "scenario" = scenario, "started" = started, "ended" = world.time,
		"process_ticks" = P.ticks, "life_interval_ds" = P.schedule_interval, "start_delay_ds" = P.start_delay,
		"tick_lag_ds" = world.tick_lag, "actual_clients" = clients.len, "events" = fixture_transition_events.Copy())
	fixture_scheduler_test_subjects = list(); fixture_scheduler_subject = null; fixture_scheduler_target = null
	qdel(A); qdel(H)
	if (M && !isDeleted(M))
		qdel(M)
	qdel(P); processes.mob = null; processScheduler = null; qdel(S)
	return result

// Called only by a future separately reviewed staging adapter.
/proc/fixture_scheduler_transition_main()
	var/mode = world.params["scheduler_mode"]
	fixture_transition_rows = list()
	fixture_transition_rows += list(fixture_scheduler_transition_observe(mode, "follow_flee"))
	fixture_transition_rows += list(fixture_scheduler_transition_observe(mode, "pet"))
	return fixture_transition_rows
