// Uncompiled fixture draft. Staging, isolation, receipts and runner are NOT wired.
// Four fresh human/goat cases. No Life scheduler or synthetic Bump calls.
var/global/list/fixture_bump_rows = list()
var/global/list/fixture_bump_setup = list()
var/global/fixture_bump_case
var/global/fixture_bump_assertions = 0

/proc/fixture_bump_assert(ok, name)
	fixture_bump_assertions++
	if (!ok)
		throw EXCEPTION(name)

/proc/fixture_bump_run()
	fixture_bump_assert(world.byond_version == 516 && world.byond_build == 1688 && world.tick_lag == 0.5 && !processScheduler, "bump_startup")
	fixture_bump_setup = list("tick" = world.tick_lag, "startup_time" = world.time, "startup_usage" = world.tick_usage)
	sleep(world.tick_lag)
	fixture_bump_setup["ready_time"] = world.time
	fixture_bump_setup["ready_usage"] = world.tick_usage
	fixture_bump_assert(world.tick_lag == 0.5 && world.time > fixture_bump_setup["startup_time"] && isnum(world.tick_usage) && world.tick_usage >= 0 && world.tick_usage < 100, "bump_ready")
	fixture_bump_rows = list()
	for (var/name in list("human_active", "animal_active", "human_idle", "animal_idle"))
		fixture_bump_rows += list(fixture_bump_case_run(name))
	fixture_bump_assert(fixture_bump_rows.len == 4, "bump_case_count")

/proc/fixture_bump_case_run(name)
	fixture_bump_case = name
	fixture_bump_assert(name in list("human_active", "animal_active", "human_idle", "animal_idle"), "bump_case_name")
	var/mob/living/human/subtile_fixture/bump_probe/H = new(locate(10, 10, 1))
	var/mob/living/simple_animal/goat/bump_probe/A = new(locate(11, 10, 1))
	fixture_bump_assert(H && A && !H.client && !A.client && !H.stat && !A.stat, "bump_fresh_actors")
	H.canmove = TRUE
	H.lastarea = get_area(H)
	H.m_intent = "walk"
	H.a_intent = I_HELP
	A.a_intent = I_HELP
	A.wander = FALSE
	fixture_bump_human = H
	fixture_bump_animal = A
	fixture_bump_events = list()
	fixture_bump_human_admissions = list()
	fixture_bump_animal_admissions = list()
	fixture_bump_collision_id = 0
	fixture_bump_overflow = FALSE
	fixture_bump_assert(H.density && A.density && H.human_subtile_shape() && A.npc_subtile_shape(), "bump_shape")
	fixture_bump_assert(!H.riding && !H.riding_mob && !H.buckled && !A.ride && !A.rider && !A.buckled && !H.pulling && !H.pulledby && !A.pulling && !A.pulledby, "bump_unlinked")
	fixture_bump_assert(H.canmove && A.canmove && !H.restrained() && !A.restrained() && !H.now_pushing && !A.now_pushing && (!H.grab_list || !H.grab_list.len) && (!H.grabbed_by || !H.grabbed_by.len) && (!A.grab_list || !A.grab_list.len) && (!A.grabbed_by || !A.grabbed_by.len), "bump_ordinary_eligibility")
	fixture_bump_assert((H.mob_bump_flag == HUMAN) && (A.mob_bump_flag == SIMPLE_ANIMAL) && !(A.mob_swap_flags & HUMAN) && (H.mob_swap_flags & SIMPLE_ANIMAL), "bump_default_flags")
	for (var/x = 9, x <= 13, x++)
		for (var/y = 9, y <= 12, y++)
			var/turf/T = locate(x, y, 1)
			fixture_bump_assert(T && !T.density, "bump_clear_floor")
			for (var/atom/movable/M in T)
				fixture_bump_assert(M == H || M == A || !M.density, "bump_clear_contents")
	var/active = (name == "human_active" || name == "animal_active")
	var/list/call_state = list("done" = FALSE, "result" = null)
	var/start = world.time
	var/deadline
	fixture_bump_running = TRUE
	if (active)
		fixture_bump_assert(H.set_human_subtile(TRUE), "bump_human_enable")
		A.npc_subtile_enabled = TRUE
		A.npc_subtile_species_enabled = TRUE
		A.npc_subtile_recovery_enabled = TRUE
		if (name == "human_active")
			// Real pulse movement creates a gap with a fractional animal offset.
			// The human is already next to the goat; the goat moves east away.
			fixture_bump_observe("prime_before", A, H)
			fixture_bump_assert(A.npc_subtile_species_walk("direction", null, 4, EAST), "bump_goat_prime_admission")
			deadline = world.time + 10
			while ((!A.npc_subtile_offset_owned || !A.step_x) && world.time < deadline)
				sleep(world.tick_lag)
			fixture_bump_assert(A.npc_subtile_offset_owned && A.step_x > 0 && A.step_x < 30, "bump_goat_prime_partial")
			A.npc_subtile_stop_wild_walk()
			deadline = world.time + 10
			while (A.npc_subtile_transaction && world.time < deadline)
				sleep(world.tick_lag)
			fixture_bump_assert(!A.npc_subtile_transaction && A.npc_subtile_offset_owned && A.step_x > 0, "bump_goat_prime_terminal")
			fixture_bump_observe("prime_after", A, H)
			spawn(0)
				call_state["result"] = H.SelfMove(get_step(H, EAST), EAST, world.time + 20)
				call_state["done"] = TRUE
		else
			spawn(0)
				call_state["result"] = H.SelfMove(get_step(H, NORTH), NORTH, world.time + 20)
				call_state["done"] = TRUE
			deadline = world.time + 6
			while ((!H.human_subtile_transaction || !H.human_subtile_offset_owned || !H.step_y) && world.time < deadline)
				sleep(world.tick_lag)
			fixture_bump_assert(H.human_subtile_transaction && H.human_subtile_offset_owned && H.step_y, "bump_human_partial")
			fixture_bump_assert(A.npc_subtile_species_walk("direction", null, 4, WEST), "bump_goat_admission")
	else
		fixture_bump_assert(H.set_human_subtile(FALSE), "bump_human_disable")
		if (name == "human_idle")
			call_state["result"] = step(H, EAST)
		else
			call_state["result"] = step(A, WEST)
		call_state["done"] = TRUE
	if (name == "animal_active")
		deadline = world.time + 12
		while (!fixture_bump_collision_id && world.time < deadline && !fixture_bump_overflow)
			sleep(world.tick_lag)
		fixture_bump_assert(fixture_bump_collision_id == 1, "bump_goat_collision")
		fixture_bump_observe("animal_stop_before", A, H)
		A.npc_subtile_stop_wild_walk()
		fixture_bump_observe("animal_stop_after", A, H)
	deadline = world.time + 28
	while ((!fixture_bump_collision_id || !call_state["done"]) && world.time < deadline && !fixture_bump_overflow)
		sleep(world.tick_lag)
	fixture_bump_assert(fixture_bump_collision_id == 1 && call_state["done"] && !fixture_bump_overflow, "bump_collision_and_completion")
	deadline = world.time + 10
	while ((H.human_subtile_transaction || A.npc_subtile_transaction) && world.time < deadline)
		sleep(world.tick_lag)
	fixture_bump_assert(!H.human_subtile_transaction && !A.npc_subtile_transaction, "bump_owner_terminal")
	// Allow the real asynchronous Bump branches to run before taking the receipt.
	sleep(2 * world.tick_lag)
	fixture_bump_assert(!fixture_bump_overflow && !H.human_subtile_pulse && !A.npc_subtile_pulse && !A.npc_subtile_wild_walk && !A.npc_subtile_pending_intent && !A.npc_subtile_recovery && !H.now_pushing && !A.now_pushing, "bump_quiescent")
	fixture_bump_observe("terminal", H, A)
	fixture_bump_assert(!fixture_bump_overflow, "bump_terminal_recorded")
	var/list/result = list("human_x" = H.x, "human_y" = H.y, "human_sx" = H.step_x, "human_sy" = H.step_y,
		"animal_x" = A.x, "animal_y" = A.y, "animal_sx" = A.step_x, "animal_sy" = A.step_y)
	var/list/row = list("case" = name, "actual_tick" = world.tick_lag, "headless_authority" = TRUE,
		"human_lifetime" = 1, "animal_lifetime" = 2, "start" = start, "end" = world.time,
		"overflow" = !!fixture_bump_overflow, "quiesced" = TRUE, "legacy_result" = result,
		"events" = fixture_bump_events.Copy())
	fixture_bump_running = FALSE
	fixture_bump_human = null
	fixture_bump_animal = null
	fixture_bump_human_admissions = list()
	fixture_bump_animal_admissions = list()
	qdel(H)
	qdel(A)
	return row
