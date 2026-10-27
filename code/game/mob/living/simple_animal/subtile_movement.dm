// Explicit AI admission, never client authority. One finite worker per actor.
// Vendors opt in; native walk()/walk_to(), vehicles and player bodies stay legacy.
/mob/living/simple_animal
	var/npc_subtile_enabled = FALSE
	var/tmp/datum/npc_subtile_transaction/npc_subtile_transaction
	var/tmp/datum/npc_subtile_pulse/npc_subtile_pulse
	var/tmp/npc_subtile_offset_owned = FALSE
	var/tmp/npc_subtile_import_owned = FALSE
	var/tmp/npc_subtile_until = 0
	var/tmp/npc_subtile_glide_owned = FALSE
	var/tmp/npc_subtile_previous_glide
	var/tmp/npc_subtile_applied_glide
	var/list/npc_subtile_position

/mob/living/simple_animal/proc/npc_subtile_snapshot()
	return list("x" = x, "y" = y, "z" = z, "sx" = step_x, "sy" = step_y)

/mob/living/simple_animal/proc/npc_subtile_shape()
	return isturf(loc) && world.icon_size == 32 && bound_x == 0 && bound_y == 0 && bound_width == 32 && bound_height == 32 && isnum(step_x) && isnum(step_y) && step_x == round(step_x) && step_y == round(step_y) && step_x >= 0 && step_x < 32 && step_y >= 0 && step_y < 32

/mob/living/simple_animal/proc/npc_subtile_ready()
	return !client && !stat && canmove && !anchored && !lying && !prone && !resting && !paralysis && !stunned && !weakened && !sleeping && !(status_flags & FAKEDEATH) && !buckled && !restrained() && !pulling && !pulledby && !ride && !rider && !control_object && !incorporeal_move && (!grab_list || !grab_list.len) && (!grabbed_by || !grabbed_by.len) && (!pinned || !pinned.len) && npc_subtile_shape()

/mob/living/simple_animal/proc/set_npc_subtile(enabled)
	if (npc_subtile_transaction || npc_subtile_pulse || !npc_subtile_shape() || ((!enabled || !npc_subtile_offset_owned) && (step_x || step_y)))
		return FALSE
	npc_subtile_enabled = !!enabled
	if (!enabled)
		npc_subtile_offset_owned = FALSE
		npc_subtile_release_glide()
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_release_glide()
	if (npc_subtile_glide_owned)
		if (glide_size == npc_subtile_applied_glide)
			glide_size = npc_subtile_previous_glide
		npc_subtile_glide_owned = FALSE

// The AI chooses a destination ONCE and retains its existing sleep/throttle.
// Return first physical progress synchronously, then finish within that interval.
// No AI, path search, RNG, client FPS changes or queued intents inside the worker.
/mob/living/simple_animal/proc/ai_step(turf/destination, interval)
	if (npc_subtile_transaction || world.time < npc_subtile_until)
		return FALSE
	var/direction = get_dir(src, destination)
	if (!npc_subtile_enabled || !npc_subtile_ready() || !(direction in alldirs) || destination != get_step(src, direction) || !isnum(interval) || interval < world.tick_lag || interval > 100)
		if (npc_subtile_offset_owned && (step_x || step_y))
			return FALSE
		return Move(destination, direction)
	if ((step_x || step_y) && !npc_subtile_offset_owned)
		return Move(destination, direction)
	var/datum/npc_subtile_transaction/T = new
	T.actor = src
	T.direction = direction
	T.start_time = world.time
	T.end_time = world.time + interval
	T.expected = npc_subtile_snapshot()
	T.generation = move_gen
	T.target = target_obj
	T.combat_target = target_mob
	T.following = following_mob
	T.stance = stance
	T.remaining_x = (direction & EAST) ? 32 - step_x : (direction & WEST) ? (step_x ? step_x : 32) : 0
	T.remaining_y = (direction & NORTH) ? 32 - step_y : (direction & SOUTH) ? (step_y ? step_y : 32) : 0
	npc_subtile_transaction = T
	npc_subtile_previous_glide = glide_size
	npc_subtile_glide_owned = TRUE
	glide_size = max(T.remaining_x, T.remaining_y) * world.tick_lag / interval
	if ((direction & (direction - 1)) && !(appearance_flags & LONG_GLIDE))
		glide_size *= ROOT2_FAST
	npc_subtile_applied_glide = glide_size
	var/continue_pulses = FALSE
	try
		continue_pulses = T.advance()
	catch (var/exception/npc_initial_error)
		T.finish()
		throw npc_initial_error
	if (!T.distance)
		T.finish()
		return FALSE
	npc_subtile_until = T.end_time
	spawn(0)
		T.perform_rest(continue_pulses)
	return TRUE

/datum/npc_subtile_pulse
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/turf/destination
	var/direction
	var/sx
	var/sy
	var/list/before
	var/armed = TRUE
	var/restoring = FALSE
	var/engine_return

/datum/npc_subtile_transaction
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/direction
	var/start_time
	var/end_time
	var/list/expected
	var/generation
	var/atom/target
	var/mob/living/combat_target
	var/mob/living/following
	var/stance
	var/remaining_x
	var/remaining_y
	var/distance = 0
	var/cancelled = FALSE
	var/completed = FALSE
	var/attempted = FALSE

/datum/npc_subtile_transaction/proc/valid()
	return !cancelled && actor && !isDeleted(actor) && actor.npc_subtile_transaction == src && actor.npc_subtile_enabled && actor.npc_subtile_ready() && !persistence_save_in_progress && world.time <= end_time + world.tick_lag && actor.move_gen == generation && actor.target_obj == target && actor.target_mob == combat_target && actor.following_mob == following && actor.stance == stance && human_subtile_same(expected, actor.npc_subtile_snapshot())

/datum/npc_subtile_transaction/proc/advance()
	if (!valid() || (!remaining_x && !remaining_y))
		return FALSE
	var/dx = (direction & EAST) ? min(2, remaining_x) : (direction & WEST) ? -min(2, remaining_x) : 0
	var/dy = (direction & NORTH) ? min(2, remaining_y) : (direction & SOUTH) ? -min(2, remaining_y) : 0
	var/sx = actor.step_x + dx
	var/sy = actor.step_y + dy
	var/tx = actor.x
	var/ty = actor.y
	if (sx < 0)
		tx--
		sx += 32
	if (sx >= 32)
		tx++
		sx -= 32
	if (sy < 0)
		ty--
		sy += 32
	if (sy >= 32)
		ty++
		sy -= 32
	var/turf/destination = locate(tx, ty, actor.z)
	if (!destination)
		return FALSE
	var/list/fronts = list(direction)
	if (direction & (direction - 1))
		fronts += direction & (NORTH | SOUTH)
		fronts += direction & (EAST | WEST)
	for (var/front_direction in fronts)
		var/turf/front = get_step(actor, front_direction)
		if (map && front && map.check_caribbean_block(actor, front))
			return FALSE
	for (var/obj/structure/noose/N in actor.loc)
		if (N.hanging == actor)
			return FALSE
	var/datum/npc_subtile_pulse/P = new
	P.actor = actor
	P.destination = destination
	P.direction = direction
	P.sx = sx
	P.sy = sy
	P.before = expected
	actor.npc_subtile_pulse = P
	attempted = TRUE
	actor.Move(destination, direction)
	if (!actor || isDeleted(actor) || actor.npc_subtile_transaction != src)
		return FALSE
	actor.npc_subtile_pulse = null
	var/list/after = actor.npc_subtile_snapshot()
	if (after["z"] != expected["z"])
		cancelled = TRUE
		return FALSE
	var/actual_x = (after["x"] - expected["x"]) * 32 + after["sx"] - expected["sx"]
	var/actual_y = (after["y"] - expected["y"]) * 32 + after["sy"] - expected["sy"]
	// External relocation must never become a new pulse anchor or owned offset.
	if (abs(actual_x) > abs(dx) || abs(actual_y) > abs(dy) || actual_x * dx < 0 || actual_y * dy < 0)
		cancelled = TRUE
		return FALSE
	expected = after
	if (actual_x || actual_y)
		distance += abs(actual_x) + abs(actual_y)
		actor.npc_subtile_offset_owned = TRUE
	remaining_x -= min(remaining_x, abs(actual_x))
	remaining_y -= min(remaining_y, abs(actual_y))
	return !P.armed && actual_x == dx && actual_y == dy

/datum/npc_subtile_transaction/proc/perform_rest(continue_pulses)
	try
		for (var/i = 2, i <= 16, i++)
			if (!continue_pulses || (!remaining_x && !remaining_y))
				break
			var/due = start_time + (i - 1) * (end_time - start_time) / 16
			if (due > world.time)
				sleep(due - world.time)
			if (!advance())
				break
		// Keep the original admission cadence, and let the last native glide end.
		if (valid() && end_time > world.time)
			sleep(end_time - world.time)
	catch (var/exception/npc_worker_error)
		finish()
		throw npc_worker_error
	finish()

/datum/npc_subtile_transaction/proc/finish()
	if (!completed && actor && !isDeleted(actor) && actor.npc_subtile_transaction == src)
		completed = TRUE
		actor.npc_subtile_pulse = null
		actor.npc_subtile_transaction = null
		actor.npc_subtile_release_glide()
		// Preserve one legacy living hook set even for a blocked native attempt.
		if (attempted)
			actor.living_movement_completed()
	actor = null
	target = null
	combat_target = null
	following = null

/mob/living/simple_animal/proc/npc_subtile_take_pulse(turf/destination, direction)
	var/datum/npc_subtile_pulse/P = npc_subtile_pulse
	if (!P || !P.armed || P.actor != src || P.destination != destination || P.direction != direction || !human_subtile_same(P.before, npc_subtile_snapshot()))
		return null
	if (!P.restoring && (!npc_subtile_transaction || !npc_subtile_transaction.valid()))
		return null
	P.armed = FALSE
	return P

/mob/living/simple_animal/persistence_runtime_var(key)
	if (key == "glide_size" && (npc_subtile_glide_owned || npc_subtile_import_owned || npc_subtile_position))
		return TRUE
	if ((key == "step_x" || key == "step_y") && (npc_subtile_import_owned || npc_subtile_position))
		return TRUE
	return (key in list("npc_subtile_enabled", "npc_subtile_transaction", "npc_subtile_pulse", "npc_subtile_offset_owned", "npc_subtile_import_owned", "npc_subtile_until", "npc_subtile_glide_owned", "npc_subtile_previous_glide", "npc_subtile_applied_glide")) || ..()

/mob/living/simple_animal/proc/npc_subtile_prepare_import(savefile/F)
	npc_subtile_import_owned = ("npc_subtile_position" in F.dir)
	if (!npc_subtile_import_owned)
		npc_subtile_position = null
		npc_subtile_offset_owned = FALSE

/mob/living/simple_animal/before_save()
	. = ..()
	if (npc_subtile_pulse)
		throw EXCEPTION("Cannot snapshot an in-flight NPC pulse")
	if (npc_subtile_transaction)
		npc_subtile_transaction.cancelled = TRUE
	if (npc_subtile_offset_owned && (step_x || step_y))
		if (!npc_subtile_shape() || pulling || pulledby || buckled)
			throw EXCEPTION("Unsupported NPC sub-tile save geometry")
		npc_subtile_position = npc_subtile_snapshot()
	else
		npc_subtile_position = null

/mob/living/simple_animal/after_load()
	. = ..()
	if (!npc_subtile_import_owned)
		return
	var/list/S = npc_subtile_position
	if (!human_subtile_same(S, S) || !npc_subtile_shape() || pulling || pulledby || buckled || x != S["x"] || y != S["y"] || z != S["z"] || S["sx"] < 0 || S["sx"] >= 32 || S["sy"] < 0 || S["sy"] >= 32)
		throw EXCEPTION("Malformed NPC sub-tile position")
	for (var/tx = x, tx <= x + (S["sx"] > 0), tx++)
		for (var/ty = y, ty <= y + (S["sy"] > 0), ty++)
			var/turf/T = locate(tx, ty, z)
			if (!T || T.density || T.vehicle_transforming)
				throw EXCEPTION("NPC sub-tile destination rejected")
			for (var/atom/movable/A in T)
				if (A != src && !A.CanPass(src, T, 1.5, FALSE))
					throw EXCEPTION("NPC sub-tile destination occupied")
	var/datum/npc_subtile_pulse/P = new
	P.actor = src
	P.destination = loc
	P.direction = dir
	P.sx = S["sx"]
	P.sy = S["sy"]
	P.before = npc_subtile_snapshot()
	P.restoring = TRUE
	npc_subtile_pulse = P
	try
		Move(loc, dir)
	catch (var/exception/npc_restore_error)
		npc_subtile_pulse = null
		throw npc_restore_error
	npc_subtile_pulse = null
	if (P.armed || !human_subtile_same(S, npc_subtile_snapshot()))
		throw EXCEPTION("Native NPC sub-tile restoration failed")
	npc_subtile_offset_owned = TRUE
	npc_subtile_import_owned = FALSE
	living_movement_completed()
