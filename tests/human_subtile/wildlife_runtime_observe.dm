// Explicit full-source fixture only. No production gate or existing smoke change.
// Life calls below are manually scheduled, not the production subsystem scheduler.
var/wildlife_runtime_checks = 0
var/list/wildlife_runtime_rows = list()

/proc/wildlife_runtime_assert(ok, label)
	wildlife_runtime_checks++
	if (!ok)
		throw EXCEPTION(label)

// Test-only instrumentation. The parent Life methods and their prob() calls run
// unchanged; the observer adds no random roll and does not manufacture a bite.
/mob/living/simple_animal/mosquito/wildlife_runtime_observe
	npc_subtile_enabled = TRUE
	npc_subtile_species_enabled = TRUE
	npc_subtile_recovery_enabled = TRUE
	var/fixture_manual_life = FALSE
	var/fixture_life_calls = 0
	var/fixture_contact_ticks = 0
	var/fixture_settled_windows = 0

/mob/living/simple_animal/mosquito/wildlife_runtime_observe/Life()
	fixture_manual_life = TRUE
	fixture_life_calls++
	. = ..()
	fixture_manual_life = FALSE

/mob/living/simple_animal/mosquito/wildlife_runtime_observe/npc_subtile_contact_tick()
	if (fixture_manual_life)
		fixture_contact_ticks++
		if (npc_subtile_contact_settled())
			fixture_settled_windows++
	return ..()

/mob/living/simple_animal/vampirebatblack/wildlife_runtime_observe
	npc_subtile_enabled = TRUE
	npc_subtile_species_enabled = TRUE
	npc_subtile_recovery_enabled = TRUE
	var/fixture_manual_life = FALSE
	var/fixture_life_calls = 0
	var/fixture_contact_ticks = 0
	var/fixture_settled_windows = 0

/mob/living/simple_animal/vampirebatblack/wildlife_runtime_observe/Life()
	fixture_manual_life = TRUE
	fixture_life_calls++
	. = ..()
	fixture_manual_life = FALSE

/mob/living/simple_animal/vampirebatblack/wildlife_runtime_observe/npc_subtile_contact_tick()
	if (fixture_manual_life)
		fixture_contact_ticks++
		if (npc_subtile_contact_settled())
			fixture_settled_windows++
	return ..()

/mob/living/simple_animal/npc_vendor/smuggler/wildlife_recovery_observe
	npc_subtile_enabled = TRUE
	npc_subtile_flee_enabled = TRUE
	npc_subtile_recovery_enabled = TRUE
	var/fixture_flee_dispatches = 0
	var/fixture_max_pulse_dx = 0
	var/fixture_max_pulse_dy = 0

/mob/living/simple_animal/npc_vendor/smuggler/wildlife_recovery_observe/npc_subtile_start_flee(atom/target, max_distance, interval)
	if (npc_subtile_ready() && !(step_x || step_y))
		fixture_flee_dispatches++
	return ..()

/mob/living/simple_animal/npc_vendor/smuggler/wildlife_recovery_observe/Move()
	var/owns = npc_subtile_pulse && npc_subtile_pulse.armed
	var/list/before = npc_subtile_snapshot()
	. = ..()
	if (owns && src && !isDeleted(src))
		var/dx = (x - before["x"]) * 32 + step_x - before["sx"]
		var/dy = (y - before["y"]) * 32 + step_y - before["sy"]
		fixture_max_pulse_dx = max(fixture_max_pulse_dx, abs(dx))
		fixture_max_pulse_dy = max(fixture_max_pulse_dy, abs(dy))

/mob/living/simple_animal/hostile/bear/wildlife_pursuit_observe
	npc_subtile_enabled = TRUE
	npc_subtile_pursuit_enabled = TRUE
	npc_subtile_recovery_enabled = TRUE
	stop_automated_movement = TRUE
	var/fixture_side_requests = 0
	var/fixture_attacks = 0

/mob/living/simple_animal/hostile/bear/wildlife_pursuit_observe/npc_subtile_start_pursuit(mob/living/target, side_direction = 0)
	if (side_direction)
		fixture_side_requests++
	return ..()

// Count handoff only; this test does not claim actual damage or limb behavior.
/mob/living/simple_animal/hostile/bear/wildlife_pursuit_observe/AttackingTarget()
	fixture_attacks++
	return TRUE

/proc/wildlife_sustained_life_case(animal_type, label)
	var/mob/living/simple_animal/M = new animal_type(locate(6, 6, 1))
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(8, 6)
	wildlife_runtime_assert(M.npc_subtile_species_walk("direction", null, 3, EAST), "[label]_initial_walk")
	var/deadline = world.time + 12
	while ((!M.npc_subtile_wild_walk || !M.npc_subtile_wild_walk.await_contact) && world.time < deadline)
		sleep(world.tick_lag)
	wildlife_runtime_assert(M.npc_subtile_wild_walk && M.npc_subtile_wild_walk.await_contact && M.npc_subtile_contact_settled(), "[label]_first_arrival_window")
	for (var/i = 1, i <= 14, i++)
		var/before_calls = M.vars["fixture_life_calls"]
		var/before_ticks = M.vars["fixture_contact_ticks"]
		M.Life()
		wildlife_runtime_assert(M.vars["fixture_life_calls"] == before_calls + 1 && M.vars["fixture_contact_ticks"] == before_ticks + 1, "[label]_one_contact_tick_per_life_[i]")
		sleep(4)
	wildlife_runtime_rows += list(list("case" = label, "life_calls" = M.vars["fixture_life_calls"],
		"contact_ticks" = M.vars["fixture_contact_ticks"], "settled_windows" = M.vars["fixture_settled_windows"],
		"target_health" = H.health, "target_disease" = H.disease))
	// This tests repeated opportunity, not a prescribed random bite count. An
	// unlucky/random path that never yields two windows is an inconclusive failure.
	wildlife_runtime_assert(M.vars["fixture_settled_windows"] >= 2, "[label]_sustained_contact_windows")
	M.npc_subtile_stop_wild_walk()
	qdel(M)
	qdel(H)

/proc/wildlife_recovery_case(invalidate)
	var/mob/living/simple_animal/npc_vendor/smuggler/wildlife_recovery_observe/A = new(locate(7, 7, 1))
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(10, 7)
	wildlife_runtime_assert(A.ai_step(get_step(A, WEST), 8), "recovery_initial_partial_admission")
	wildlife_runtime_assert(A.npc_subtile_transaction && A.npc_subtile_offset_owned && (A.step_x || A.step_y), "recovery_owned_partial")
	A.stunned = 1
	var/list/held = A.npc_subtile_snapshot()
	wildlife_runtime_assert(A.npc_subtile_start_flee(H, 8, 4), "recovery_deferred_flee")
	wildlife_runtime_assert(A.npc_subtile_pending_intent && A.npc_subtile_pending_intent.kind == "flee", "recovery_one_pending_flee")
	var/deadline = world.time + 12
	while (A.npc_subtile_transaction && world.time < deadline)
		sleep(world.tick_lag)
	wildlife_runtime_assert(!A.npc_subtile_transaction && human_subtile_same(held, A.npc_subtile_snapshot()), "recovery_no_ineligible_motion")
	if (invalidate)
		A.behaviour = "wildlife_fixture_changed"
	A.stunned = 0
	deadline = world.time + 35
	var/terminal_observed = FALSE
	while (world.time < deadline)
		A.Life()
		if (invalidate && !A.npc_subtile_pending_intent && !A.npc_subtile_recovery && !(A.step_x || A.step_y))
			terminal_observed = TRUE
			break
		if (!invalidate && A.fixture_flee_dispatches)
			break
		sleep(world.tick_lag)
	wildlife_runtime_assert(A.fixture_max_pulse_dx <= 2 && A.fixture_max_pulse_dy <= 2, "recovery_no_snap_or_large_pulse")
	if (invalidate)
		wildlife_runtime_assert(!A.npc_subtile_pending_intent && !A.fixture_flee_dispatches, "recovery_invalidated_flee_not_replayed")
		wildlife_runtime_assert(terminal_observed && !A.npc_subtile_pending_intent && !A.npc_subtile_recovery && !(A.step_x || A.step_y), "recovery_invalidated_settled_before_deadline")
	else
		wildlife_runtime_assert(A.fixture_flee_dispatches == 1 && !A.npc_subtile_pending_intent, "recovery_valid_flee_dispatched_once")
	wildlife_runtime_rows += list(list("case" = invalidate ? "invalidated_recovery" : "valid_recovery",
		"position" = A.npc_subtile_snapshot(), "flee_dispatches" = A.fixture_flee_dispatches,
		"terminal_observed" = terminal_observed, "pending" = !!A.npc_subtile_pending_intent,
		"recovering" = !!A.npc_subtile_recovery,
		"max_dx" = A.fixture_max_pulse_dx, "max_dy" = A.fixture_max_pulse_dy))
	A.npc_subtile_stop_flee()
	qdel(A)
	qdel(H)

/proc/wildlife_pursuit_tick_case()
	var/mob/living/simple_animal/hostile/bear/wildlife_pursuit_observe/A = new(locate(6, 8, 1))
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(10, 8)
	A.npc_set_combat_target(H)
	A.stance = HOSTILE_STANCE_ATTACK
	A.last_loc = A.loc
	A.stuck_ticks = 0
	var/datum/npc_subtile_pursuit/first_owner
	for (var/i = 1, i <= 3, i++)
		A.MoveToTarget()
		if (i == 1)
			first_owner = A.npc_subtile_pursuit
		wildlife_runtime_assert(first_owner && A.npc_subtile_pursuit == first_owner, "pursuit_single_owner_ai_tick_[i]")
	wildlife_runtime_assert(A.fixture_side_requests == 1 && A.stuck_ticks == 0, "pursuit_third_stuck_tick_selects_one_side")
	wildlife_runtime_rows += list(list("case" = "pursuit_ai_ticks", "side_requests" = A.fixture_side_requests,
		"stuck_ticks" = A.stuck_ticks, "owner_stable" = (A.npc_subtile_pursuit == first_owner)))
	A.npc_subtile_stop_pursuit()
	qdel(A)
	qdel(H)

/proc/wildlife_attack_handoff_case()
	var/mob/living/simple_animal/hostile/bear/wildlife_pursuit_observe/A = new(locate(8, 6, 1))
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(7, 6)
	H.density = FALSE
	A.npc_set_combat_target(H)
	A.stance = HOSTILE_STANCE_ATTACK
	wildlife_runtime_assert(A.ai_step(get_step(A, WEST), 8), "attack_partial_west_admitted")
	wildlife_runtime_assert(A.npc_subtile_pursuit_unsettled(), "attack_partial_owned_offset")
	wildlife_runtime_assert(!A.AttackTarget() && !A.fixture_attacks, "attack_handoff_blocks_partial_contact")
	var/deadline = world.time + 20
	while ((A.npc_subtile_transaction || A.npc_subtile_pursuit_unsettled()) && world.time < deadline)
		sleep(world.tick_lag)
	wildlife_runtime_assert(!A.npc_subtile_transaction && !A.npc_subtile_pursuit_unsettled(), "attack_handoff_settles_first")
	wildlife_runtime_assert(A.AttackTarget() && A.fixture_attacks == 1, "attack_handoff_on_later_ai_tick")
	wildlife_runtime_rows += list(list("case" = "attack_handoff", "attacks" = A.fixture_attacks,
		"position" = A.npc_subtile_snapshot(), "target_x" = H.x, "target_y" = H.y))
	A.npc_subtile_stop_pursuit()
	qdel(A)
	qdel(H)

/proc/wildlife_runtime_fixture()
	wildlife_sustained_life_case(/mob/living/simple_animal/mosquito/wildlife_runtime_observe, "mosquito_life")
	wildlife_sustained_life_case(/mob/living/simple_animal/vampirebatblack/wildlife_runtime_observe, "bat_life")
	wildlife_recovery_case(FALSE)
	wildlife_recovery_case(TRUE)
	wildlife_pursuit_tick_case()
	wildlife_attack_handoff_case()
