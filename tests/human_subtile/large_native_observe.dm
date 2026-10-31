// Test-only capabilities drive one actual production NPC Move at a time.
// They do NOT admit 96x96 wildlife in production or simulate persistence.
var/list/large_native_trace = list()
var/list/large_native_rows = list()
var/large_native_checks = 0

/proc/large_native_log(event, atom/A)
	if (large_native_trace.len >= 256)
		throw EXCEPTION("large_native_trace_bound")
	large_native_trace += list(list("event" = event, "x" = A ? A.x : null, "y" = A ? A.y : null, "at" = world.time))

/proc/large_native_snapshot(mob/living/simple_animal/A)
	var/list/covered = list()
	for (var/turf/T in A.locs)
		covered += list(list("x" = T.x, "y" = T.y, "z" = T.z, "in_contents" = (A in T.contents)))
	return list("x" = A.x, "y" = A.y, "z" = A.z, "sx" = A.step_x, "sy" = A.step_y,
		"dir" = A.dir, "bound_x" = A.bound_x, "bound_y" = A.bound_y,
		"bound_width" = A.bound_width, "bound_height" = A.bound_height,
		"pixel_w" = A.vars["pixel_w"], "pixel_z" = A.vars["pixel_z"], "locs" = covered)

/datum/npc_subtile_transaction/large_native_observe
	var/fixture_bound_x
	var/fixture_bound_y
	var/fixture_width
	var/fixture_height
	var/fixture_dir
	var/turf/fixture_destination
	var/fixture_sx
	var/fixture_sy

/datum/npc_subtile_transaction/large_native_observe/valid()
	var/datum/npc_subtile_pulse/P = actor ? actor.npc_subtile_pulse : null
	return actor && !isDeleted(actor) && !actor.client && (!actor.npc_subtile_enabled || actor.npc_subtile_large_exit_enabled) && actor.npc_subtile_transaction == src && P && P.armed && !P.restoring && P.actor == actor && P.destination == fixture_destination && P.direction == fixture_dir && P.sx == fixture_sx && P.sy == fixture_sy && actor.bound_x == fixture_bound_x && actor.bound_y == fixture_bound_y && actor.bound_width == fixture_width && actor.bound_height == fixture_height && actor.dir == fixture_dir && human_subtile_same(expected, actor.npc_subtile_snapshot())

/mob/living/simple_animal/hostile/mammoth/large_native_observe
	npc_subtile_enabled = FALSE
	stop_automated_movement = TRUE
	var/fixture_native_trace = TRUE

/mob/living/simple_animal/hostile/mammoth/large_native_observe/Move()
	large_native_log("Move:before", src)
	. = ..()
	large_native_log("Move:after", src)

/mob/living/simple_animal/hostile/mammoth/large_native_observe/Bump(atom/A, yes)
	large_native_log("Bump", A)
	return ..()

/mob/living/simple_animal/hostile/mammoth/large_native_observe/living_movement_completed()
	large_native_log("completion", src)
	return ..()

/mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe
	npc_subtile_enabled = FALSE
	stop_automated_movement = TRUE
	var/fixture_native_trace = TRUE

/mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe/Move()
	large_native_log("Move:before", src)
	. = ..()
	large_native_log("Move:after", src)

/mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe/Bump(atom/A, yes)
	large_native_log("Bump", A)
	return ..()

/mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe/living_movement_completed()
	large_native_log("completion", src)
	return ..()

/proc/large_native_traced(atom/movable/mover)
	return istype(mover, /mob/living/simple_animal/hostile/mammoth/large_native_observe) || istype(mover, /mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe)

/turf/floor/plating/subtile_fixture/Enter(atom/movable/mover, atom/forget)
	if (large_native_traced(mover))
		large_native_log("Enter", src)
	return ..()

/turf/floor/plating/subtile_fixture/Exit(atom/movable/mover, atom/newloc)
	if (large_native_traced(mover))
		large_native_log("Exit", src)
	return ..()

/obj/large_native_border
	flags = ON_BORDER
	anchored = TRUE
	density = FALSE

/obj/large_native_border/CheckExit(atom/movable/mover as mob|obj, target as turf)
	large_native_log("CheckExit", src)
	return FALSE

/obj/large_native_border/CanPass(atom/movable/mover, turf/target, height = 0, air_group = FALSE)
	large_native_log("CanPass", src)
	return ..()

/obj/large_native_border/Cross(atom/movable/mover)
	large_native_log("Cross", src)
	return ..()

/obj/large_native_border/Uncross(atom/movable/mover, atom/newloc)
	large_native_log("Uncross", src)
	return ..()

/proc/large_native_assert(ok, label)
	large_native_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/large_native_pulse(mob/living/simple_animal/A, direction, dx, dy)
	var/sx = A.step_x + dx
	var/sy = A.step_y + dy
	var/tx = A.x
	var/ty = A.y
	if (sx < 0)
		tx--; sx += 32
	if (sx >= 32)
		tx++; sx -= 32
	if (sy < 0)
		ty--; sy += 32
	if (sy >= 32)
		ty++; sy -= 32
	var/turf/destination = locate(tx, ty, A.z)
	large_native_assert(destination && !A.npc_subtile_pulse && !A.npc_subtile_transaction, "native_pulse_fresh_destination")
	var/datum/npc_subtile_transaction/large_native_observe/T = new
	T.actor = A
	T.expected = A.npc_subtile_snapshot()
	T.generation = A.move_gen; T.end_time = world.time + 100
	T.fixture_bound_x = A.bound_x; T.fixture_bound_y = A.bound_y
	T.fixture_width = A.bound_width; T.fixture_height = A.bound_height
	T.fixture_dir = direction; T.fixture_destination = destination
	T.fixture_sx = sx; T.fixture_sy = sy
	var/datum/npc_subtile_pulse/P = new
	P.actor = A; P.before = T.expected; P.destination = destination
	P.direction = direction; P.sx = sx; P.sy = sy
	A.npc_subtile_transaction = T
	A.npc_subtile_pulse = P
	// A callback may qdel T during the native Move; retain the admitted
	// immutable evidence before entering it, without retaining deleted state.
	var/list/admitted_before = T.expected.Copy()
	var/admitted_bx = T.fixture_bound_x; var/admitted_by = T.fixture_bound_y
	var/admitted_width = T.fixture_width; var/admitted_height = T.fixture_height
	var/native_result = A.Move(destination, direction)
	var/consumed = !P.armed
	// Observe ownership immediately after native Move, before fixture cleanup.
	var/actor_pulse_present = !!A.npc_subtile_pulse
	var/actor_transaction_present = !!A.npc_subtile_transaction
	var/actor_frame_present = !!A.npc_subtile_large_frame
	A.npc_subtile_pulse = null
	A.npc_subtile_transaction = null
	large_native_assert(consumed && !P.restoring, "native_pulse_consumed_once")
	var/list/result = list("native_return" = native_result, "engine_return" = P.engine_return,
		"consumed" = consumed, "restoring" = P.restoring, "destination_x" = destination.x,
		"actor_pulse_present" = actor_pulse_present, "actor_transaction_present" = actor_transaction_present,
		"actor_frame_present" = actor_frame_present,
		"destination_y" = destination.y, "sx" = sx, "sy" = sy, "direction" = direction,
		"before" = admitted_before, "bound_x" = admitted_bx, "bound_y" = admitted_by,
		"width" = admitted_width, "height" = admitted_height)
	qdel(P)
	qdel(T)
	return result

/proc/large_native_turfs(mob/living/simple_animal/A)
	var/list/result = list()
	for (var/turf/T in A.locs)
		result += T
	return result

/proc/large_native_setup(animal_type, variant, direction, orthogonal, warmup = 15)
	large_native_trace = list()
	var/mob/living/simple_animal/A = new animal_type(locate(9, 7, 1))
	A.dir = direction
	A.bound_x = variant
	if (orthogonal)
		A.dir = NORTH
		large_native_pulse(A, NORTH, 0, 2)
		A.dir = direction
		A.bound_x = variant
	for (var/i = 1, i <= warmup, i++)
		large_native_trace = list()
		var/list/before = A.npc_subtile_snapshot()
		large_native_pulse(A, direction, direction == EAST ? 2 : -2, 0)
		var/delta = (A.x - before["x"]) * 32 + A.step_x - before["sx"]
		large_native_assert(delta == (direction == EAST ? 2 : -2), "native_clear_setup_progress")
		large_native_assert(A.bound_x == variant && A.dir == direction && A.bound_width == 96 && A.bound_height == 96,
			"native_setup_geometry_stable")
	return A

/proc/large_native_fixture()
	for (var/animal_type in list(/mob/living/simple_animal/hostile/mammoth/large_native_observe, /mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe))
		for (var/variant in list(0, 64))
			for (var/direction in list(EAST, WEST))
				for (var/orthogonal in list(FALSE, TRUE))
					var/mob/living/simple_animal/reference = large_native_setup(animal_type, variant, direction, orthogonal)
					var/list/old_turfs = large_native_turfs(reference)
					var/turf/reference_anchor = reference.loc
					large_native_trace = list()
					var/list/clear_before = large_native_snapshot(reference)
					var/list/clear_auth = large_native_pulse(reference, direction, direction == EAST ? 2 : -2, 0)
					var/list/new_turfs = large_native_turfs(reference)
					var/turf/exiting = null
					for (var/turf/T in old_turfs)
						if (!(T in new_turfs) && T != reference_anchor && !exiting)
							exiting = T
					large_native_assert(exiting, "native_remote_exiting_edge_observed")
					var/list/clear_after = large_native_snapshot(reference)
					sleep(world.tick_lag)
					large_native_rows += list(list("case" = "clear", "animal" = "[animal_type]", "variant" = variant,
						"direction" = direction, "orthogonal" = orthogonal, "edge_x" = exiting.x, "edge_y" = exiting.y,
						"before" = clear_before, "after" = clear_after, "after_async" = large_native_snapshot(reference),
						"auth" = clear_auth, "trace" = large_native_trace.Copy()))
					qdel(reference)
					for (var/control in list("remote", "anchor"))
						var/mob/living/simple_animal/A = large_native_setup(animal_type, variant, direction, orthogonal)
						var/turf/blocker_location = control == "remote" ? exiting : A.loc
						large_native_assert(control != "remote" || (blocker_location in A.locs), "native_remote_edge_same_setup")
						var/obj/large_native_border/B = new(blocker_location)
						large_native_trace = list()
						var/list/before = large_native_snapshot(A)
						var/list/auth = large_native_pulse(A, direction, direction == EAST ? 2 : -2, 0)
						var/list/after = large_native_snapshot(A)
						sleep(world.tick_lag)
						large_native_rows += list(list("case" = control, "animal" = "[animal_type]", "variant" = variant,
							"direction" = direction, "orthogonal" = orthogonal, "edge_x" = exiting.x, "edge_y" = exiting.y,
							"before" = before, "after" = after, "after_async" = large_native_snapshot(A),
							"auth" = auth, "trace" = large_native_trace.Copy()))
						qdel(B)
						qdel(A)
					// A separate aligned-to-partial pulse observes an entering edge.
					// Its anchor blocker is a positive CheckExit control only if the
					// real engine actually invokes Enter for this pulse.
					for (var/enter_control in list("clear_enter", "anchor_enter"))
						var/mob/living/simple_animal/enter_actor = large_native_setup(animal_type, variant, direction, orthogonal, 16)
						var/obj/large_native_border/enter_blocker = null
						if (enter_control == "anchor_enter")
							enter_blocker = new(enter_actor.loc)
						large_native_trace = list()
						var/list/enter_before = large_native_snapshot(enter_actor)
						var/list/enter_auth = large_native_pulse(enter_actor, direction, direction == EAST ? 2 : -2, 0)
						var/list/enter_after = large_native_snapshot(enter_actor)
						sleep(world.tick_lag)
						large_native_rows += list(list("case" = enter_control, "animal" = "[animal_type]", "variant" = variant,
							"direction" = direction, "orthogonal" = orthogonal, "edge_x" = exiting.x, "edge_y" = exiting.y,
							"before" = enter_before, "after" = enter_after, "after_async" = large_native_snapshot(enter_actor),
							"auth" = enter_auth, "trace" = large_native_trace.Copy()))
						if (enter_blocker)
							qdel(enter_blocker)
						qdel(enter_actor)
	large_native_assert(large_native_rows.len == 80, "native_case_matrix_complete")
