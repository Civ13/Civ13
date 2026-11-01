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
