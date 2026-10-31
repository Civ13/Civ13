// Test-only integration cases for the disabled authenticated large-exit bridge.
// Include after large_native_observe.dm; this file never enters the game DME.
var/list/large_bridge_rows = list()
var/list/large_bridge_controls = list()
var/large_bridge_checks = 0
var/list/large_bridge_exception_sentinel = list()

/mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge
	npc_subtile_large_exit_enabled = TRUE

/mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe/bridge
	npc_subtile_large_exit_enabled = TRUE

/obj/large_native_border/bridge
	var/fixture_allow = FALSE
	var/fixture_checks = 0
	var/fixture_direction = null
	var/fixture_fault = null
	var/fixture_nested_result = null
	var/fixture_throw_attempted = FALSE
	var/fixture_boundary_caught = FALSE
	var/fixture_boundary_name = null
	var/datum/npc_subtile_transaction/fixture_replacement
	var/fixture_token = null
	var/obj/large_native_border/bridge/fixture_mutation_target
	var/datum/npc_subtile_large_frame/fixture_deleted_actor_frame
	var/fixture_actor_deleted = FALSE
	var/list/fixture_retired_state

/obj/large_native_border/bridge/CheckExit(atom/movable/mover, turf/target, exit_direction = null)
	large_native_log("CheckExit:bridge", src)
	if (fixture_token)
		large_native_log("CheckExit:[fixture_token]", src)
	fixture_checks++
	fixture_direction = exit_direction
	if (fixture_mutation_target)
		fixture_mutation_target.fixture_allow = FALSE
		large_native_log("policy_mutated", src)
	if (fixture_fault && istype(mover, /mob/living/simple_animal))
		var/mob/living/simple_animal/A = mover
		switch (fixture_fault)
			if ("callback_invalidate")
				A.move_gen++
			if ("callback_cancel")
				A.npc_subtile_transaction.cancelled = TRUE
			if ("callback_finish")
				A.npc_subtile_transaction.finished = TRUE
			if ("callback_delete")
				qdel(A.npc_subtile_transaction)
			if ("callback_blocker_delete")
				qdel(src)
			if ("callback_actor_delete")
				fixture_deleted_actor_frame = A.npc_subtile_large_frame
				qdel(A)
				fixture_actor_deleted = !A || isDeleted(A)
				var/datum/npc_subtile_large_frame/F = fixture_deleted_actor_frame
				if (F && !isDeleted(F))
					fixture_retired_state = list("exists" = TRUE, "active" = !!F.active, "valid" = !!F.valid(),
						"actor" = !!F.actor, "pulse" = !!F.pulse, "transaction" = !!F.transaction,
						"intent" = !!F.intent_owner, "fault" = !!F.fault, "start" = !!F.start,
						"destination" = !!F.destination, "path_target" = !!F.path_target,
						"combat_target" = !!F.combat_target, "following" = !!F.following)
					F.retire()
					F.retire()
			if ("callback_incapacitate")
				A.stunned = 1
			if ("callback_reassign")
				fixture_replacement = new
				A.npc_subtile_transaction = fixture_replacement
			if ("callback_control")
				A.control_object = src
			if ("callback_disable")
				A.npc_subtile_enabled = FALSE
			if ("callback_nested")
				fixture_nested_result = A.Move(A.npc_subtile_pulse.destination, A.npc_subtile_pulse.direction)
			if ("callback_throw")
				fixture_throw_attempted = TRUE
				large_native_log("fixture_throw_attempt", src)
				throw EXCEPTION("fixture_bridge_exception")
	return fixture_allow

// This tests an object's own native Uncross rejection. It does not inject or
// claim to test a FALSE return from /obj/Uncross's native parent.
/obj/large_native_border/bridge/reject_uncross/Uncross(atom/movable/mover, atom/newloc)
	large_native_log("Uncross:fixture_reject", src)
	return FALSE

// Dedicated throw case: report the last DM wrapper before native Move and
// rethrow unchanged. This does not invoke any callback outside native Move.
/obj/large_native_border/bridge/throw_boundary/Uncross(atom/movable/mover, atom/newloc)
	large_native_log("Uncross:throw_enter", src)
	try
		. = ..()
	catch (var/exception/fixture_boundary_error)
		fixture_boundary_caught = TRUE
		fixture_boundary_name = fixture_boundary_error.name
		large_native_log("Uncross:throw_catch", src)
		throw fixture_boundary_error
	large_native_log("Uncross:throw_return", src)
	return .

// Fixture-only parent seam: native parent is still called, and only the
// dedicated test object changes a successful parent result into rejection.
/obj/large_native_border/bridge/parent_reject

/atom/movable/Uncross(atom/movable/mover, atom/newloc)
	. = ..()
	if (. && istype(src, /obj/large_native_border/bridge/parent_reject))
		large_native_log("Uncross:parent_reject", src)
		return FALSE

// These wrappers observe the real production directional implementations.
/obj/structure/window/bridge_fixture
	var/fixture_checks = 0
	var/fixture_direction = null
/obj/structure/window/bridge_fixture/Uncross(atom/movable/mover, atom/newloc)
	large_native_log("Uncross:window", src)
	return ..()
/obj/structure/window/bridge_fixture/CheckExit(atom/movable/mover, turf/target, exit_direction = null)
	fixture_checks++; fixture_direction = exit_direction
	large_native_log("CheckExit:window", src)
	return ..()

/obj/structure/railing/bridge_fixture
	var/fixture_checks = 0
	var/fixture_direction = null
/obj/structure/railing/bridge_fixture/Uncross(atom/movable/mover, atom/newloc)
	large_native_log("Uncross:railing", src)
	return ..()
/obj/structure/railing/bridge_fixture/CheckExit(atom/movable/mover, turf/target, exit_direction = null)
	fixture_checks++; fixture_direction = exit_direction
	large_native_log("CheckExit:railing", src)
	return ..()

/obj/structure/table/bridge_fixture
	flags = ON_BORDER
	flipped = TRUE
	var/fixture_checks = 0
	var/fixture_direction = null
/obj/structure/table/bridge_fixture/Uncross(atom/movable/mover, atom/newloc)
	large_native_log("Uncross:table", src)
	return ..()
/obj/structure/table/bridge_fixture/CheckExit(atom/movable/mover, turf/target, exit_direction = null)
	fixture_checks++; fixture_direction = exit_direction
	large_native_log("CheckExit:table", src)
	return ..()

/proc/large_bridge_assert(ok, label)
	large_bridge_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/large_bridge_capability_control(case_name)
	var/mob/living/simple_animal/A = new /mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge(locate(9, 7, 1))
	A.dir = EAST
	A.bound_x = 0
	var/list/before = A.npc_subtile_snapshot()
	var/datum/npc_subtile_transaction/large_native_observe/T = new
	T.actor = A; T.expected = before.Copy()
	T.generation = A.move_gen; T.end_time = world.time + 100
	T.fixture_bound_x = A.bound_x; T.fixture_bound_y = A.bound_y
	T.fixture_width = A.bound_width; T.fixture_height = A.bound_height
	T.fixture_dir = EAST; T.fixture_destination = A.loc
	T.fixture_sx = 2; T.fixture_sy = 0
	var/datum/npc_subtile_pulse/P = new
	P.actor = A; P.before = before.Copy(); P.destination = A.loc
	P.direction = EAST; P.sx = 2; P.sy = 0
	A.npc_subtile_transaction = T; A.npc_subtile_pulse = P
	if (case_name == "stale")
		P.before["sx"] = 1
	else if (case_name == "wrong_actor")
		P.actor = null
	else if (case_name == "unarmed")
		P.armed = FALSE
	else if (case_name == "wrong_destination")
		P.destination = locate(A.x + 1, A.y, A.z)
	else if (case_name == "replay")
		A.Move(A.loc, EAST)
		large_bridge_assert(!P.armed && A.step_x == 2, "bridge_replay_first_move")
		before = A.npc_subtile_snapshot()
	large_native_trace = list()
	var/result = A.Move(A.loc, EAST)
	var/list/after = A.npc_subtile_snapshot()
	large_bridge_assert(!result && human_subtile_same(before, after) && !A.npc_subtile_large_frame, "bridge_capability_rejected")
	large_bridge_controls += list(list("case" = case_name, "before" = before, "after" = after,
		"result" = result, "armed" = P.armed, "frame_cleared" = !A.npc_subtile_large_frame, "trace" = large_native_trace.Copy()))
	A.npc_subtile_pulse = null; A.npc_subtile_transaction = null
	qdel(P); qdel(T); qdel(A)

/proc/large_bridge_ordinary_control()
	var/mob/living/simple_animal/A = new /mob/living/simple_animal/hostile/mammoth/large_native_observe(locate(9, 7, 1))
	A.dir = EAST; A.bound_x = 0; A.bound_y = 0; A.bound_width = 32; A.bound_height = 32
	var/list/before = large_native_snapshot(A)
	large_native_trace = list()
	var/list/auth = large_native_pulse(A, EAST, 2, 0)
	var/list/after = large_native_snapshot(A)
	large_bridge_assert(!A.npc_subtile_large_exit_enabled && !A.npc_subtile_large_frame && after["sx"] == before["sx"] + 2, "bridge_ordinary_32_progress")
	large_bridge_controls += list(list("case" = "ordinary_32", "before" = before, "after" = after,
		"auth" = auth, "frame_cleared" = !A.npc_subtile_large_frame, "trace" = large_native_trace.Copy()))
	qdel(A)

/proc/large_bridge_missing_control()
	var/mob/living/simple_animal/A = new /mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge(locate(9, 7, 1))
	A.dir = EAST; A.bound_x = 0
	large_native_pulse(A, EAST, 2, 0)
	A.npc_subtile_offset_owned = TRUE
	var/list/before = A.npc_subtile_snapshot()
	large_native_trace = list()
	var/result = A.Move(A.loc, EAST)
	var/list/after = A.npc_subtile_snapshot()
	large_bridge_assert(!result && human_subtile_same(before, after) && !A.npc_subtile_large_frame, "bridge_missing_capability_rejected")
	large_bridge_controls += list(list("case" = "missing", "before" = before, "after" = after,
		"result" = result, "frame_cleared" = !A.npc_subtile_large_frame, "trace" = large_native_trace.Copy()))
	qdel(A)

// Deleting a mob can invalidate every reference to it immediately. Retain
// the pulse, transaction and admitted frame separately; never read its final
// position or imply that an actor which was deleted completed the movement.
/proc/large_bridge_actor_delete_control(turf/exiting)
	var/mob/living/simple_animal/A = large_bridge_setup(/mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge, 0, WEST, FALSE)
	var/obj/large_native_border/bridge/B = new(exiting)
	B.fixture_allow = TRUE; B.fixture_fault = "callback_actor_delete"
	var/list/before = large_native_snapshot(A)
	var/datum/npc_subtile_transaction/large_native_observe/T = new
	T.actor = A; T.expected = A.npc_subtile_snapshot()
	T.generation = A.move_gen; T.end_time = world.time + 100
	T.fixture_bound_x = A.bound_x; T.fixture_bound_y = A.bound_y
	T.fixture_width = A.bound_width; T.fixture_height = A.bound_height
	T.fixture_dir = WEST; T.fixture_destination = A.loc; T.fixture_sx = 0; T.fixture_sy = A.step_y
	var/datum/npc_subtile_pulse/P = new
	P.actor = A; P.before = T.expected.Copy(); P.destination = A.loc
	P.direction = WEST; P.sx = 0; P.sy = A.step_y
	A.npc_subtile_transaction = T; A.npc_subtile_pulse = P
	large_native_trace = list()
	var/result = null
	var/error = null
	try
		result = A.Move(P.destination, WEST)
	catch (var/exception/fixture_error)
		error = fixture_error.name
	var/actor_deleted = !A || isDeleted(A)
	var/frame_cleared = !B.fixture_deleted_actor_frame || !B.fixture_deleted_actor_frame.active
	var/pulse_consumed = P && !P.armed
	large_bridge_controls += list(list("case" = "callback_actor_delete", "before" = before, "actor_deleted" = actor_deleted,
		"frame_cleared" = frame_cleared, "pulse_consumed" = pulse_consumed, "checks" = B.fixture_checks,
		"retired_state" = B.fixture_retired_state, "error" = error, "result" = result, "trace" = large_native_trace.Copy()))
	large_bridge_assert(!error && actor_deleted && B.fixture_actor_deleted, "bridge_actor_deleted")
	large_bridge_assert(B.fixture_checks == 1 && pulse_consumed, "bridge_delete_callback_consumed")
	large_bridge_assert(frame_cleared, "bridge_delete_frame_cleared")
	var/list/retired = B.fixture_retired_state
	large_bridge_assert(retired && retired["exists"] && !retired["active"] && !retired["valid"] && !retired["actor"] && !retired["pulse"] && !retired["transaction"] && !retired["intent"] && !retired["fault"] && !retired["start"] && !retired["destination"] && !retired["path_target"] && !retired["combat_target"] && !retired["following"], "bridge_delete_frame_retired")
	if (B.fixture_deleted_actor_frame) qdel(B.fixture_deleted_actor_frame)
	qdel(P); qdel(T); qdel(B)

// An invalid cross-actor pointer must not let one animal retire another's
// frame. The fixture itself closes the retained frame only after callbacks end.
/proc/large_bridge_retirement_control()
	var/mob/living/simple_animal/other = new(locate(6, 6, 1))
	var/mob/living/simple_animal/dying = new(locate(7, 6, 1))
	var/datum/npc_subtile_large_frame/F = new
	var/datum/npc_subtile_pulse/P = new
	var/datum/npc_subtile_transaction/T = new
	var/datum/owner = new
	F.actor = other; F.pulse = P; F.transaction = T; F.intent_owner = owner
	F.start = list("x" = 6); F.destination = other.loc; F.path_target = other.loc
	F.combat_target = other; F.following = other; F.fault = EXCEPTION("fixture_retire_fault")
	other.npc_subtile_large_frame = F; dying.npc_subtile_large_frame = F
	qdel(dying)
	var/preserved = F.active && F.actor == other && other.npc_subtile_large_frame == F
	F.retire(); F.retire()
	var/cleared = !F.active && !F.valid() && !F.actor && !F.pulse && !F.transaction && !F.intent_owner && !F.fault && !F.start && !F.destination && !F.path_target && !F.combat_target && !F.following && !other.npc_subtile_large_frame
	F.close()
	if (F && !isDeleted(F)) F.close()
	var/mob/living/simple_animal/plain = new(locate(8, 6, 1))
	qdel(plain)
	var/plain_deleted = !plain || isDeleted(plain)
	large_bridge_controls += list(list("case" = "retirement_ownership", "preserved" = !!preserved,
		"cleared" = !!cleared, "plain_deleted" = !!plain_deleted, "frame_cleared" = !other.npc_subtile_large_frame))
	large_bridge_assert(preserved, "bridge_other_actor_frame_preserved")
	large_bridge_assert(cleared, "bridge_retire_idempotent_refs")
	large_bridge_assert(!other.npc_subtile_large_frame, "bridge_repeat_close_safe")
	large_bridge_assert(plain_deleted, "bridge_plain_destroy")
	qdel(P); qdel(T); qdel(owner); qdel(other)

/proc/large_bridge_setup(animal_type, variant, direction, orthogonal, pulse_count = 15)
	var/mob/living/simple_animal/A = new animal_type(locate(9, 7, 1))
	A.dir = direction
	A.bound_x = variant
	if (orthogonal)
		var/orthogonal_direction = (direction == EAST || direction == WEST) ? NORTH : EAST
		A.dir = orthogonal_direction
		large_native_pulse(A, orthogonal_direction, orthogonal_direction == EAST ? 2 : 0, orthogonal_direction == NORTH ? 2 : 0)
		A.dir = direction
		A.bound_x = variant
	for (var/i = 1, i <= pulse_count, i++)
		large_native_trace = list()
		var/list/before = A.npc_subtile_snapshot()
		large_native_pulse(A, direction, direction == EAST ? 2 : (direction == WEST ? -2 : 0), direction == NORTH ? 2 : (direction == SOUTH ? -2 : 0))
		var/dx = (A.x - before["x"]) * 32 + A.step_x - before["sx"]
		var/dy = (A.y - before["y"]) * 32 + A.step_y - before["sy"]
		large_bridge_assert(dx == (direction == EAST ? 2 : (direction == WEST ? -2 : 0)) && dy == (direction == NORTH ? 2 : (direction == SOUTH ? -2 : 0)), "bridge_clear_setup_progress")
		large_bridge_assert(A.bound_x == variant && A.dir == direction && A.bound_width == 96 && A.bound_height == 96, "bridge_setup_geometry")
	return A

/proc/large_bridge_fixture()
	var/direct_caught = FALSE
	var/direct_name = null
	try
		throw EXCEPTION("fixture_bridge_exception")
	catch (var/exception/direct_error)
		direct_name = direct_error.name
		direct_caught = direct_name == "fixture_bridge_exception"
	large_bridge_exception_sentinel = list("caught" = direct_caught, "name" = direct_name)
	large_bridge_assert(direct_caught, "bridge_direct_exception_sentinel")
	for (var/animal_type in list(/mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge, /mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe/bridge))
		for (var/variant in list(0, 64))
			for (var/direction in list(EAST, WEST, NORTH, SOUTH))
				for (var/orthogonal in list(FALSE, TRUE))
					var/mob/living/simple_animal/reference = large_bridge_setup(animal_type, variant, direction, orthogonal)
					var/list/old_turfs = large_native_turfs(reference)
					var/turf/old_anchor = reference.loc
					large_native_pulse(reference, direction, direction == EAST ? 2 : (direction == WEST ? -2 : 0), direction == NORTH ? 2 : (direction == SOUTH ? -2 : 0))
					var/list/new_turfs = large_native_turfs(reference)
					var/turf/exiting = null
					for (var/turf/T in old_turfs)
						if (!(T in new_turfs) && T != old_anchor && !exiting)
							exiting = T
					large_bridge_assert(exiting, "bridge_remote_exit_observed")
					qdel(reference)
					for (var/allow in list(FALSE, TRUE))
						var/mob/living/simple_animal/A = large_bridge_setup(animal_type, variant, direction, orthogonal)
						large_bridge_assert(exiting in A.locs, "bridge_remote_exit_same_setup")
						var/obj/large_native_border/bridge/B = new(exiting)
						B.fixture_allow = allow
						large_native_trace = list()
						var/list/before = large_native_snapshot(A)
						var/list/auth = large_native_pulse(A, direction, direction == EAST ? 2 : (direction == WEST ? -2 : 0), direction == NORTH ? 2 : (direction == SOUTH ? -2 : 0))
						var/list/after = large_native_snapshot(A)
						var/dx = (after["x"] - before["x"]) * 32 + after["sx"] - before["sx"]
						var/dy = (after["y"] - before["y"]) * 32 + after["sy"] - before["sy"]
						var/native_exits = 0
						for (var/list/event in large_native_trace)
							if (event["event"] == "Uncross")
								native_exits++
						large_bridge_assert(native_exits > 0 && B.fixture_checks == native_exits && B.fixture_direction == direction, "bridge_direction_and_each_check")
						large_bridge_assert(dx == (allow ? (direction == EAST ? 2 : (direction == WEST ? -2 : 0)) : 0) && dy == (allow ? (direction == NORTH ? 2 : (direction == SOUTH ? -2 : 0)) : 0), "bridge_allowed_or_blocked")
						large_bridge_assert(!A.npc_subtile_large_frame, "bridge_frame_cleared")
						sleep(world.tick_lag)
						var/list/after_async = large_native_snapshot(A)
						large_bridge_assert(after_async["x"] == after["x"] && after_async["y"] == after["y"] && after_async["sx"] == after["sx"] && after_async["sy"] == after["sy"], "bridge_no_late_displacement")
						large_bridge_rows += list(list("animal" = "[animal_type]", "variant" = variant,
							"direction" = direction, "orthogonal" = orthogonal, "allow" = allow,
							"edge_x" = exiting.x, "edge_y" = exiting.y, "before" = before,
							"after" = after, "after_async" = after_async, "auth" = auth, "trace" = large_native_trace.Copy(),
							"checks" = B.fixture_checks, "exit_direction" = B.fixture_direction, "frame_cleared" = !A.npc_subtile_large_frame))
						qdel(B)
						qdel(A)
					if (animal_type == /mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge && variant == 0 && direction == WEST && !orthogonal)
						for (var/control in list("callback_invalidate", "callback_cancel", "callback_finish", "callback_delete", "callback_blocker_delete", "callback_incapacitate", "callback_reassign", "callback_control", "callback_disable", "callback_nested", "callback_throw", "object_uncross_reject", "parent_uncross_reject"))
							var/mob/living/simple_animal/C = large_bridge_setup(animal_type, variant, direction, orthogonal)
							if (control == "callback_disable")
								C.npc_subtile_enabled = TRUE
							var/obj/large_native_border/bridge/B
							if (control == "object_uncross_reject")
								B = new /obj/large_native_border/bridge/reject_uncross(exiting)
							else if (control == "parent_uncross_reject")
								B = new /obj/large_native_border/bridge/parent_reject(exiting)
							else if (control == "callback_throw")
								B = new /obj/large_native_border/bridge/throw_boundary(exiting)
								B.fixture_allow = TRUE
								B.fixture_fault = control
							else
								B = new(exiting)
								B.fixture_allow = TRUE
								B.fixture_fault = control
							large_native_trace = list()
							var/list/control_before = large_native_snapshot(C)
							var/list/control_auth
							var/caught = FALSE
							var/caught_name = null
							var/helper_returned = FALSE
							if (control == "callback_throw")
								try
									control_auth = large_native_pulse(C, WEST, -2, 0)
									helper_returned = TRUE
								catch (var/exception/fixture_error)
									caught_name = fixture_error.name
									caught = caught_name == "fixture_bridge_exception"
								if (!helper_returned)
									var/datum/npc_subtile_pulse/P = C.npc_subtile_pulse
									var/datum/npc_subtile_transaction/T = C.npc_subtile_transaction
									control_auth = list("consumed" = (P && !P.armed),
										"actor_pulse_present" = !!C.npc_subtile_pulse,
										"actor_transaction_present" = !!C.npc_subtile_transaction,
										"actor_frame_present" = !!C.npc_subtile_large_frame)
									C.npc_subtile_pulse = null; C.npc_subtile_transaction = null
									qdel(P); qdel(T)
							else
								control_auth = large_native_pulse(C, WEST, -2, 0)
							var/list/control_after = large_native_snapshot(C)
							var/control_dx = (control_after["x"] - control_before["x"]) * 32 + control_after["sx"] - control_before["sx"]
							// Preserve the exact observation even when the next assertion fails.
							large_bridge_controls += list(list("case" = control, "before" = control_before, "after" = control_after,
								"auth" = control_auth, "checks" = B.fixture_checks, "caught" = caught, "caught_name" = caught_name,
								"helper_returned" = helper_returned, "throw_attempted" = B.fixture_throw_attempted,
								"boundary_caught" = B.fixture_boundary_caught, "boundary_name" = B.fixture_boundary_name,
								"nested_result" = B.fixture_nested_result, "frame_cleared" = !C.npc_subtile_large_frame,
								"trace" = large_native_trace.Copy()))
							large_bridge_assert(control_dx == (control == "callback_nested" ? -2 : 0) && !C.npc_subtile_large_frame && (control != "callback_nested" || !B.fixture_nested_result) && (control != "callback_throw" || (caught && control_auth["consumed"])), "bridge_callback_rejected")
							large_bridge_assert(B.fixture_checks == ((control == "object_uncross_reject" || control == "parent_uncross_reject") ? 0 : 1), "bridge_callback_check_count")
							C.control_object = null
							if (B.fixture_replacement)
								qdel(B.fixture_replacement)
							qdel(B); qdel(C)
						var/mob/living/simple_animal/policy_actor = large_bridge_setup(animal_type, variant, direction, orthogonal)
						var/obj/large_native_border/bridge/mutator = new(exiting)
						var/obj/large_native_border/bridge/subject = new(exiting)
						mutator.fixture_allow = TRUE; mutator.fixture_token = "policy_mutator"
						mutator.fixture_mutation_target = subject
						subject.fixture_allow = TRUE; subject.fixture_token = "policy_subject"
						large_native_trace = list()
						var/list/policy_before = large_native_snapshot(policy_actor)
						var/list/policy_auth = large_native_pulse(policy_actor, WEST, -2, 0)
						var/list/policy_after = large_native_snapshot(policy_actor)
						large_bridge_assert(mutator.fixture_checks > 0 && subject.fixture_checks > 0 && !subject.fixture_allow, "bridge_policy_mutation_observed")
						large_bridge_assert(policy_before["x"] == policy_after["x"] && policy_before["sx"] == policy_after["sx"], "bridge_mutated_policy_denied")
						large_bridge_assert(!policy_actor.npc_subtile_large_frame, "bridge_mutated_policy_frame_cleared")
						large_bridge_controls += list(list("case" = "policy_mutation", "before" = policy_before, "after" = policy_after,
							"auth" = policy_auth, "mutator_checks" = mutator.fixture_checks, "subject_checks" = subject.fixture_checks,
							"subject_allow" = subject.fixture_allow, "frame_cleared" = !policy_actor.npc_subtile_large_frame, "trace" = large_native_trace.Copy()))
						mutator.fixture_mutation_target = null
						qdel(mutator); qdel(subject); qdel(policy_actor)
						large_bridge_actor_delete_control(exiting)
						for (var/lifecycle_mode in list("first_fault", "later_fault", "ordinary_denial", "replace_fault"))
							large_bridge_lifecycle_case(exiting, lifecycle_mode)
					if (animal_type == /mob/living/simple_animal/hostile/mammoth/large_native_observe/bridge && !orthogonal && ((variant == 0 && direction == WEST) || (variant == 64 && direction == EAST)))
						for (var/border_type in list(/obj/structure/window/bridge_fixture, /obj/structure/railing/bridge_fixture, /obj/structure/table/bridge_fixture))
							for (var/allow in list(FALSE, TRUE))
								var/mob/living/simple_animal/C = large_bridge_setup(animal_type, variant, direction, orthogonal)
								var/obj/B = new border_type(exiting)
								B.dir = allow ? (direction == WEST ? EAST : WEST) : direction
								B.anchored = TRUE
								B.flags |= ON_BORDER
								if (istype(B, /obj/structure/table))
									B.vars["flipped"] = TRUE
								large_native_trace = list()
								var/list/real_before = large_native_snapshot(C)
								var/list/real_auth = large_native_pulse(C, direction, direction == WEST ? -2 : 2, 0)
								var/list/real_after = large_native_snapshot(C)
								var/real_dx = (real_after["x"] - real_before["x"]) * 32 + real_after["sx"] - real_before["sx"]
								large_bridge_assert(B.vars["fixture_checks"] > 0 && B.vars["fixture_direction"] == direction, "bridge_real_direction")
								large_bridge_assert(real_dx == (allow ? (direction == WEST ? -2 : 2) : 0), "bridge_real_directional_outcome")
								large_bridge_assert(!C.npc_subtile_large_frame, "bridge_real_frame_cleared")
								large_bridge_controls += list(list("case" = "real_[border_type]_[direction]_[allow]", "allow" = allow, "direction" = direction, "variant" = variant,
									"border_type" = "[border_type]", "before" = real_before, "after" = real_after, "auth" = real_auth,
									"checks" = B.vars["fixture_checks"], "exit_direction" = B.vars["fixture_direction"],
									"frame_cleared" = !C.npc_subtile_large_frame, "trace" = large_native_trace.Copy()))
								qdel(B); qdel(C)
	large_bridge_assert(large_bridge_rows.len == 64, "bridge_matrix_complete")
	for (var/control in list("stale", "wrong_actor", "unarmed", "wrong_destination", "replay"))
		large_bridge_capability_control(control)
	large_bridge_missing_control()
	large_bridge_ordinary_control()
	large_bridge_retirement_control()
	large_bridge_assert(large_bridge_controls.len == 39, "bridge_controls_complete")
