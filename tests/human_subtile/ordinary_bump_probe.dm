// Source-only draft for PR #3493. Not staged, compiled, or run.
// Uses current-master tests/human_subtile/probe.dm, not the experimental NPC walker.
var/global/list/ordinary_bump_rows = list()
var/global/list/ordinary_bump_events = list()
var/global/ordinary_bump_case
var/global/mob/living/human/subtile_fixture/ordinary_bump_human
var/global/mob/living/simple_animal/goat/ordinary_bump_goat
var/global/datum/human_subtile_transaction/ordinary_bump_admission
var/global/ordinary_bump_callbacks = 0
var/global/ordinary_bump_overflow = FALSE

/proc/ordinary_bump_event(label, mob/living/actor, atom/movable/other)
	if (ordinary_bump_events.len >= 128)
		ordinary_bump_overflow = TRUE
		return
	var/mob/living/human/subtile_fixture/H = ordinary_bump_human
	var/mob/living/simple_animal/goat/A = ordinary_bump_goat
	ordinary_bump_events += list(list("ordinal" = ordinary_bump_events.len + 1, "at" = world.time, "case" = ordinary_bump_case, "label" = label,
		"actor" = actor == H ? "human" : (actor == A ? "goat" : "other"), "other" = other == H ? "human" : (other == A ? "goat" : "other"),
		"hx" = H.x, "hy" = H.y, "hsx" = H.step_x, "hsy" = H.step_y, "human_owned" = !!H.human_subtile_offset_owned,
		"human_transaction" = !!H.human_subtile_transaction, "same_admission" = ordinary_bump_admission && H.human_subtile_transaction == ordinary_bump_admission,
		"human_pulse" = !!H.human_subtile_pulse, "human_completions" = H.fixture_human_completions, "living_completions" = H.fixture_living_completions,
		"ax" = A.x, "ay" = A.y, "asx" = A.step_x, "asy" = A.step_y, "human_pushing" = !!H.now_pushing, "goat_pushing" = !!A.now_pushing))

/mob/living/human/subtile_fixture/ordinary_bump_probe/Bump(atom/movable/other, yes)
	if (other == ordinary_bump_goat)
		ordinary_bump_callbacks++
		ordinary_bump_event("human_bump_before", src, other)
	. = ..()
	if (other == ordinary_bump_goat)
		ordinary_bump_event("human_bump_return", src, other)

/mob/living/simple_animal/goat/ordinary_bump_probe/Bump(atom/movable/other, yes)
	if (other == ordinary_bump_human)
		ordinary_bump_callbacks++
		ordinary_bump_event("goat_bump_before", src, other)
	. = ..()
	if (other == ordinary_bump_human)
		ordinary_bump_event("goat_bump_return", src, other)

/proc/ordinary_bump_run_case(name)
	ordinary_bump_case = name
	ordinary_bump_events = list()
	ordinary_bump_callbacks = 0
	ordinary_bump_overflow = FALSE
	ordinary_bump_admission = null
	var/mob/living/human/subtile_fixture/ordinary_bump_probe/H = new(locate(10, 10, 1))
	var/mob/living/simple_animal/goat/ordinary_bump_probe/A = new(locate(11, 10, 1))
	ordinary_bump_human = H
	ordinary_bump_goat = A
	H.canmove = TRUE
	H.lastarea = get_area(H)
	H.m_intent = "walk"
	H.a_intent = I_HELP
	A.a_intent = I_HELP
	A.wander = FALSE
	human_subtile_fixture_assert(H && A && !H.client && !A.client && H.density && A.density, "ordinary_bump_fresh")
	human_subtile_fixture_assert(!H.riding && !H.riding_mob && !H.buckled && !A.ride && !A.rider && !A.buckled && !H.pulling && !H.pulledby && !A.pulling && !A.pulledby, "ordinary_bump_unlinked")
	human_subtile_fixture_assert(!H.restrained() && !A.restrained() && (!H.grab_list || !H.grab_list.len) && (!H.grabbed_by || !H.grabbed_by.len) && (!A.grab_list || !A.grab_list.len) && (!A.grabbed_by || !A.grabbed_by.len), "ordinary_bump_no_grab")
	if (name == "goat_idle_permitted" || name == "goat_active_permitted")
		// Explicit fixture-only opt-in: default goat swap flags are asymmetric.
		A.mob_swap_flags |= HUMAN
	var/list/call_state = list("done" = FALSE, "result" = null)
	ordinary_bump_event("initial", H, A)
	if (name == "goat_active_permitted")
		human_subtile_fixture_assert(H.set_human_subtile(TRUE), "ordinary_bump_enable_human")
		spawn(0)
			call_state["result"] = H.SelfMove(get_step(H, NORTH), NORTH, world.time + 20)
			call_state["done"] = TRUE
			ordinary_bump_event("human_call_return", H, A)
		var/active_until = world.time + 6
		while ((!H.human_subtile_transaction || !H.human_subtile_offset_owned || !H.step_y) && world.time < active_until)
			sleep(world.tick_lag)
		human_subtile_fixture_assert(H.human_subtile_transaction && H.human_subtile_offset_owned && H.step_y, "ordinary_bump_active_partial")
		ordinary_bump_admission = H.human_subtile_transaction
		ordinary_bump_event("active_before_goat", H, A)
		step(A, WEST)
	else
		human_subtile_fixture_assert(H.set_human_subtile(FALSE), "ordinary_bump_disable_human")
		if (name == "human_idle")
			call_state["result"] = step(H, EAST)
		else
			call_state["result"] = step(A, WEST)
		call_state["done"] = TRUE
	ordinary_bump_event("after_attempt", H, A)
	sleep(2 * world.tick_lag)
	ordinary_bump_event("post_deferred", H, A)
	var/terminal_deadline = world.time + 30
	while ((!ordinary_bump_callbacks || !call_state["done"] || H.human_subtile_transaction || H.now_pushing || A.now_pushing) && world.time < terminal_deadline && !ordinary_bump_overflow)
		sleep(world.tick_lag)
	sleep(2 * world.tick_lag)
	ordinary_bump_event("terminal", H, A)
	human_subtile_fixture_assert(ordinary_bump_callbacks >= 1 && call_state["done"] && !H.human_subtile_transaction && !H.now_pushing && !A.now_pushing && !ordinary_bump_overflow, "ordinary_bump_quiesced")
	var/list/row = list("case" = name, "callbacks" = ordinary_bump_callbacks, "call_result" = call_state["result"], "events" = ordinary_bump_events.Copy(), "human_pulses" = H.fixture_rows.Copy(), "overflow" = !!ordinary_bump_overflow)
	ordinary_bump_human = null
	ordinary_bump_goat = null
	ordinary_bump_admission = null
	qdel(H)
	qdel(A)
	return row

/proc/ordinary_bump_run()
	human_subtile_fixture_assert(world.byond_version == 516 && world.byond_build == 1688 && world.tick_lag == 0.5 && !processScheduler, "ordinary_bump_engine")
	sleep(world.tick_lag)
	ordinary_bump_rows = list()
	for (var/name in list("human_idle", "goat_idle_default", "goat_idle_permitted", "goat_active_permitted"))
		ordinary_bump_rows += list(ordinary_bump_run_case(name))
	human_subtile_fixture_assert(ordinary_bump_rows.len == 4, "ordinary_bump_cases")
// Calls inserted only into the two existing paired forceMove paths in the staged fixture.
/proc/ordinary_bump_trace_leg(label, mob/living/actor, mob/living/other)
	if (ordinary_bump_human && ordinary_bump_goat && ((actor == ordinary_bump_human && other == ordinary_bump_goat) || (actor == ordinary_bump_goat && other == ordinary_bump_human)))
		ordinary_bump_event(label, actor, other)