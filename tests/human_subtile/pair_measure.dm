// Measurement only. Two isolated fresh daemons use legacy or pair-first mode.
// Direct loc assignments intentionally bypass normal movement and are not a fix.
var/global/list/pair_rows = list()
var/global/list/pair_events = list()
var/global/list/pair_action_result = list()
var/global/pair_case
var/global/pair_mode
var/global/pair_phase
var/global/pair_running = FALSE
var/global/pair_overflow = FALSE
var/global/pair_action_seen = FALSE
var/global/pair_checks = 0
var/global/mob/living/human/subtile_fixture/pair_probe/pair_human
var/global/mob/living/simple_animal/goat/pair_probe/pair_animal
var/global/datum/npc_subtile_transaction/pair_admission

/proc/pair_assert(ok, label)
	pair_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/pair_record(label, detail = null)
	if (!pair_running)
		return
	if (pair_events.len >= 256)
		pair_overflow = TRUE
		return
	var/h_live = pair_human && !isDeleted(pair_human)
	var/a_live = pair_animal && !isDeleted(pair_animal)
	var/list/event = list("ordinal" = pair_events.len + 1, "at" = world.time,
		"case" = pair_case, "mode" = pair_mode, "phase" = pair_phase,
		"label" = label, "detail" = detail, "human_lifetime" = 1,
		"animal_lifetime" = 2, "human_live" = !!h_live, "animal_live" = !!a_live,
		"human_tx" = h_live ? !!pair_human.human_subtile_transaction : FALSE,
		"animal_tx" = a_live ? !!pair_animal.npc_subtile_transaction : FALSE,
		"admission_recorded" = !!pair_admission,
		"admission_finished" = pair_admission ? !!pair_admission.finished : null)
	if (h_live)
		event["human_x"] = pair_human.x; event["human_y"] = pair_human.y
		event["human_z"] = pair_human.z; event["human_sx"] = pair_human.step_x; event["human_sy"] = pair_human.step_y
	if (a_live)
		event["animal_x"] = pair_animal.x; event["animal_y"] = pair_animal.y
		event["animal_z"] = pair_animal.z; event["animal_sx"] = pair_animal.step_x; event["animal_sy"] = pair_animal.step_y
		event["animal_generation"] = pair_animal.move_gen
		event["admission_is_current"] = pair_admission && pair_animal.npc_subtile_transaction == pair_admission
	pair_events += list(event)

/proc/pair_observe_actor(label, atom/movable/subject)
	if (subject == pair_human)
		pair_record(label, "human")
	else if (subject == pair_animal)
		pair_record(label, "animal")

/proc/pair_apply_action(origin)
	if (pair_action_seen)
		pair_record("repeated_action_suppressed", origin)
		return
	pair_action_seen = TRUE
	pair_action_result = list("action" = pair_case, "origin" = origin)
	pair_record("action_before", origin)
	switch (pair_case)
		if ("none")
			pair_action_result["returned"] = TRUE
		if ("relocate")
			pair_action_result["returned"] = !!pair_human.persistence_set_loc(locate(8, 8, 1))
		if ("delete")
			pair_record("delete_requested")
			qdel(pair_animal)
			pair_action_result["returned"] = TRUE
		if ("owner")
			var/list/receipt = list()
			var/dir = pair_mode == "legacy" ? EAST : WEST
			var/admitted = pair_animal.ai_step(get_step(pair_animal, dir), 4, TRUE, receipt)
			pair_admission = receipt["transaction"]
			pair_action_result["returned"] = !!admitted
			pair_action_result["admission_recorded"] = !!pair_admission
			pair_action_result["current_at_return"] = pair_animal && !isDeleted(pair_animal) && pair_admission && pair_animal.npc_subtile_transaction == pair_admission
			pair_record("owner_admission_return")
		if ("yield")
			pair_record("yield_before")
			sleep(world.tick_lag)
			pair_record("yield_after")
			pair_action_result["returned"] = TRUE
		if ("throw")
			pair_record("throw_requested")
			throw EXCEPTION("pair_fixture_callback_throw")
	pair_record("action_after", origin)

/mob/living/human/subtile_fixture/pair_probe/Uncrossed(atom/movable/AM)
	pair_observe_actor("human_uncrossed_before", AM)
	. = ..()
	pair_observe_actor("human_uncrossed_after", AM)

/mob/living/human/subtile_fixture/pair_probe/Crossed(atom/movable/AM)
	pair_observe_actor("human_crossed_before", AM)
	. = ..()
	pair_observe_actor("human_crossed_after", AM)

/mob/living/simple_animal/goat/pair_probe/Uncrossed(atom/movable/AM)
	pair_observe_actor("animal_uncrossed_before", AM)
	. = ..()
	pair_observe_actor("animal_uncrossed_after", AM)

/mob/living/simple_animal/goat/pair_probe/Crossed(atom/movable/AM)
	pair_observe_actor("animal_crossed_before", AM)
	. = ..()
	if (pair_running && AM == pair_human && src == pair_animal)
		pair_apply_action("native_crossed")
	pair_observe_actor("animal_crossed_after", AM)

/mob/living/simple_animal/goat/pair_probe/Move()
	pair_record("animal_move_before")
	. = ..()
	pair_record("animal_move_after")

/turf/floor/plating/subtile_fixture/Exited(atom/movable/AM, atom/newloc)
	pair_observe_actor("turf_exited_before", AM)
	. = ..()
	pair_observe_actor("turf_exited_after", AM)

/proc/pair_run()
	pair_mode = world.params["pair_mode"]
	pair_assert(pair_mode in list("legacy", "pair_first"), "pair_invalid_mode")
	pair_assert(world.byond_version == 516 && world.byond_build == 1688 && world.tick_lag == 0.5 && !processScheduler, "pair_environment")
	var/startup_time = world.time
	sleep(world.tick_lag)
	pair_assert(world.time > startup_time && world.tick_usage >= 0 && world.tick_usage < 100, "pair_readiness")
	pair_rows = list()
	for (var/action in list("none", "owner", "relocate", "delete", "yield", "throw"))
		pair_case_run(action)
	pair_assert(pair_rows.len == 6, "pair_case_count")

/proc/pair_case_run(action)
	pair_case = action
	pair_phase = "setup"
	pair_running = FALSE
	pair_events = list()
	pair_action_result = list()
	pair_action_seen = FALSE
	pair_overflow = FALSE
	pair_human = null
	pair_animal = null
	pair_admission = null
	var/mob/living/human/subtile_fixture/pair_probe/H = new(locate(5, 5, 1))
	var/mob/living/simple_animal/goat/pair_probe/A = new(locate(6, 5, 1))
	pair_human = H; pair_animal = A
	pair_assert(H && A && !H.client && !A.client && H.loc == locate(5, 5, 1) && A.loc == locate(6, 5, 1), "pair_fresh")
	H.canmove = TRUE; H.stat = CONSCIOUS; H.lastarea = get_area(H)
	A.canmove = TRUE; A.wander = FALSE; A.npc_subtile_enabled = TRUE
	pair_assert(H.human_subtile_shape() && A.npc_subtile_shape() && H.density && A.density, "pair_shape")
	pair_assert(!H.human_subtile_transaction && !A.npc_subtile_transaction && !H.step_x && !H.step_y && !A.step_x && !A.step_y, "pair_unowned")
	var/turf/origin = H.loc
	var/turf/destination = A.loc
	for (var/mob/living/M in origin)
		pair_assert(M == H || M == A, "pair_origin_contaminated")
	for (var/mob/living/M in destination)
		pair_assert(M == H || M == A, "pair_destination_contaminated")
	pair_running = TRUE
	pair_phase = "before_first"
	pair_record("start")
	var/error = null
	try
		pair_phase = "first_leg"
		pair_record("first_before")
		if (pair_mode == "legacy")
			H.forceMove(destination)
		else
			H.loc = destination
		pair_record("first_after")
		pair_phase = "second_leg"
		pair_record("second_before")
		if (A && !isDeleted(A))
			if (pair_mode == "legacy")
				A.forceMove(origin)
			else
				A.loc = origin
			pair_record("second_after")
		else
			pair_record("second_skipped_deleted")
		pair_phase = "after_commit"
		if (pair_mode == "pair_first" && !pair_action_seen)
			pair_record("fixture_injection_before")
			pair_apply_action("fixture_post_commit")
	catch (var/exception/E)
		error = E.name
		pair_record("caught_exception", error)
	pair_phase = "settling"
	var/deadline = world.time + 8
	while (A && !isDeleted(A) && A.npc_subtile_transaction && world.time < deadline)
		sleep(world.tick_lag)
	pair_record("terminal")
	pair_assert(!pair_overflow, "pair_event_overflow")
	pair_assert(pair_action_seen, "pair_action_missing")
	if (pair_case == "owner")
		pair_assert(pair_action_result["returned"] && pair_action_result["admission_recorded"] && pair_action_result["current_at_return"], "pair_owner_not_admitted")
		pair_assert(!A || isDeleted(A) || !A.npc_subtile_transaction, "pair_owner_not_retired")
	pair_rows += list(list("case" = pair_case, "mode" = pair_mode, "error" = error,
		"action" = pair_action_result.Copy(), "events" = pair_events.Copy(), "overflow" = !!pair_overflow))
	pair_running = FALSE
	if (H && !isDeleted(H))
		qdel(H)
	if (A && !isDeleted(A))
		qdel(A)
	sleep(world.tick_lag)
