// One client admission/cost interval, native cardinal or diagonal pulses.
// Runtime ownership is explicitly excluded from the custom saver below.
/mob/living/human
	var/tmp/human_subtile_enabled = FALSE
	var/tmp/human_subtile_default_pending = TRUE
	var/tmp/datum/human_subtile_transaction/human_subtile_transaction
	var/tmp/datum/human_subtile_pulse/human_subtile_pulse
	var/tmp/human_subtile_import_owned = FALSE
	var/tmp/human_subtile_offset_owned = FALSE
	var/tmp/human_subtile_glide_owned = FALSE
	var/tmp/human_subtile_previous_glide = 0
	var/tmp/human_subtile_applied_glide = 0
	var/tmp/client/human_subtile_visual_owner
	var/list/human_subtile_position

/client
	var/tmp/mob/living/human/human_subtile_visual_actor
	var/tmp/human_subtile_visual_owned = FALSE
	var/tmp/human_subtile_previous_fps
	var/tmp/human_subtile_previous_glide
	var/tmp/human_subtile_applied_fps
	var/tmp/human_subtile_applied_glide

/client/proc/human_subtile_release_visuals()
	if (!human_subtile_visual_owned)
		return
	if (human_subtile_visual_actor)
		human_subtile_visual_actor.human_subtile_release_glide()
		if (human_subtile_visual_actor.human_subtile_visual_owner == src)
			human_subtile_visual_actor.human_subtile_visual_owner = null
	human_subtile_visual_actor = null
	human_subtile_visual_owned = FALSE
	if (fps == human_subtile_applied_fps)
		fps = human_subtile_previous_fps
	if (glide_size == human_subtile_applied_glide)
		glide_size = human_subtile_previous_glide

/mob/living/human/proc/human_subtile_release_glide()
	if (human_subtile_glide_owned)
		if (glide_size == human_subtile_applied_glide)
			glide_size = human_subtile_previous_glide
		human_subtile_glide_owned = FALSE

/mob/living/human/proc/human_subtile_update_visuals(duration, direction, client/owner)
	release_carriage_glide()
	if (owner && human_subtile_visual_owner && human_subtile_visual_owner != owner)
		human_subtile_visual_owner.human_subtile_release_visuals()
	if (!human_subtile_glide_owned)
		human_subtile_previous_glide = glide_size
		human_subtile_glide_owned = TRUE
	else if (glide_size != human_subtile_applied_glide)
		human_subtile_previous_glide = glide_size
	// Native interpolation follows physical motion, including normalization at
	// tile edges. Legacy pixel movement needs client FPS above server FPS.
	glide_size = 32 * world.tick_lag / max(duration, world.tick_lag)
	if ((direction & (direction - 1)) && !(appearance_flags & LONG_GLIDE))
		glide_size *= ROOT2_FAST
	human_subtile_applied_glide = glide_size
	if (owner)
		if (owner.human_subtile_visual_actor != src)
			owner.human_subtile_release_visuals()
			owner.human_subtile_previous_fps = owner.fps
			owner.human_subtile_previous_glide = owner.glide_size
			owner.human_subtile_visual_actor = src
			owner.human_subtile_visual_owned = TRUE
			human_subtile_visual_owner = owner
		else
			if (owner.fps != owner.human_subtile_applied_fps)
				owner.human_subtile_previous_fps = owner.fps
			if (owner.glide_size != owner.human_subtile_applied_glide)
				owner.human_subtile_previous_glide = owner.glide_size
		owner.fps = max(owner.human_subtile_previous_fps, world.fps + 1, 60)
		owner.glide_size = glide_size
		owner.human_subtile_applied_fps = owner.fps
		owner.human_subtile_applied_glide = owner.glide_size

/datum/human_subtile_pulse
	should_save = FALSE
	var/mob/living/human/actor
	var/turf/destination
	var/direction
	var/sx
	var/sy
	var/list/before
	var/armed = TRUE
	var/invalid = FALSE
	var/restoring = FALSE
	var/engine_return

/datum/human_subtile_transaction
	should_save = FALSE
	var/mob/living/human/actor
	var/client/owner
	var/end_time
	var/start_time
	var/cancelled = FALSE
	var/list/expected
	var/list/observations = list()
	var/total_distance = 0
	var/completed = FALSE
	var/legacy_posture = FALSE

/mob/living/human/proc/human_subtile_snapshot()
	return list("x" = x, "y" = y, "z" = z, "sx" = step_x, "sy" = step_y)

/proc/human_subtile_same(list/a, list/b)
	if (!islist(a) || !islist(b) || a.len != 5 || b.len != 5)
		return FALSE
	for (var/key in list("x", "y", "z", "sx", "sy"))
		if (!(key in a) || !(key in b) || !isnum(a[key]) || !isnum(b[key]) || a[key] != round(a[key]) || b[key] != round(b[key]) || a[key] != b[key])
			return FALSE
	return TRUE

/mob/living/human/proc/human_subtile_shape()
	return isturf(loc) && world.icon_size == 32 && bound_x == 0 && bound_y == 0 && bound_width == 32 && bound_height == 32 && isnum(step_x) && isnum(step_y) && step_x >= 0 && step_x < 32 && step_y >= 0 && step_y < 32 && step_x == round(step_x) && step_y == round(step_y)

/mob/living/human/proc/human_subtile_eligible(direction)
	return human_subtile_enabled && human_subtile_ready(direction)

/mob/living/human/proc/human_subtile_ready(direction)
	return human_subtile_shape() && (direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)) && !stat && canmove && !transforming && !lying && !prone && !crouching && !restrained() && (!pinned || !pinned.len) && human_subtile_unlinked()

/mob/living/human/proc/human_subtile_initialize_default(direction)
	// Wait for an eligible input, after construction/placement/load. Do not adopt
	// arbitrary legacy offsets, replay workers, or bypass the setter's safety.
	if (human_subtile_default_pending && human_subtile_ready(direction) && ((!step_x && !step_y) || human_subtile_offset_owned))
		return set_human_subtile(TRUE)
	return FALSE

/mob/living/human/proc/human_subtile_unlinked()
	return !buckled && !riding && !riding_mob && !using_drone && !control_object && !incorporeal_move && !pulling && !pulledby && (!grab_list || !grab_list.len) && (!grabbed_by || !grabbed_by.len) && !using_object && !using_cannon && !football

/mob/living/human/proc/human_subtile_input_supported(direction)
	human_subtile_initialize_default(direction)
	// Unsupported transitions keep the legacy path only when tile-aligned.
	// A restored capsule also owns a physical offset while the opt-in is off.
	if (!human_subtile_enabled && !human_subtile_offset_owned)
		return TRUE
	if (!step_x && !step_y)
		return TRUE
	return human_subtile_eligible(direction) || human_subtile_posture_ready(direction)

// Crawling has its own legacy wait and admission. Let that paid path recover
// an owned offset without making unconscious/restrained/linked bodies eligible.
/mob/living/human/proc/human_subtile_posture_ready(direction)
	return human_subtile_offset_owned && (step_x || step_y) && human_subtile_shape() && (direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)) && (prone || lying) && !stat && !transforming && !paralysis && !stunned && !sleeping && !(status_flags & FAKEDEATH) && !restrained() && weakened <= 10 && has_limbs && (!pinned || !pinned.len) && human_subtile_unlinked()

/mob/living/human/proc/human_subtile_posture_authority(client/owner)
	return client == owner && (!owner || (owner.mob == src && owner.canmove))

/mob/living/human/proc/human_subtile_posture_move(turf/n)
	var/direct = get_dir(src, n)
	if (!human_subtile_posture_ready(direct) || n != get_step(src, direct) || !human_subtile_posture_authority(client))
		return FALSE
	// Called only after proning/scramble already consumed its original wait.
	// Zero duration retains that cadence; at most sixteen native collision
	// pulses align moving axes, with one pair of completion hooks.
	return human_subtile_travel(n, direct, world.time, TRUE)

/mob/living/human/proc/set_human_subtile(enabled)
	if (human_subtile_transaction || human_subtile_pulse || !human_subtile_shape())
		return FALSE
	if (!enabled && (step_x || step_y))
		return FALSE
	human_subtile_enabled = !!enabled
	human_subtile_default_pending = FALSE
	if (!enabled)
		human_subtile_offset_owned = FALSE
		human_subtile_release_glide()
		if (client && client.human_subtile_visual_actor == src)
			client.human_subtile_release_visuals()
	return TRUE

/mob/living/human/verb/toggle_smooth_movement()
	set name = "Toggle Smooth Movement"
	set category = "IC"
	var/enabled = !(human_subtile_enabled || human_subtile_default_pending)
	if (!set_human_subtile(enabled))
		to_chat(src, SPAN_NOTICE("Finish moving to a tile alignment before changing smooth movement. A reverse input can finish an interrupted step."))
		return FALSE
	to_chat(src, SPAN_NOTICE("Smooth movement is now [enabled ? "enabled" : "disabled"] for this body."))
	return TRUE

// This narrow hook is adapted explicitly by the headless fixture. Production
// always requires the same real client/body and ordinary movement permission.
/mob/living/human/proc/human_subtile_authority(client/owner)
	return owner && client == owner && owner.mob == src && owner.canmove && owner.moving

// Same arithmetic as the existing cardinal client.Move epilogue, captured BEFORE
// sleeping. The disabled path still executes the original epilogue unchanged.
/mob/living/human/proc/human_subtile_deadline(raw_deadline, now, ordinal = FALSE)
	var/multiplier = movement_speed_multiplier
	if (find_trait("Slowness"))
		multiplier *= 0.85
	else if (find_trait("Agile"))
		multiplier *= 1.15
	else if (original_job_title == "Tuy Phai")
		multiplier *= 1.25
	if (find_trait("Gigantism"))
		multiplier *= 0.9
	var/delay = raw_deadline
	if (delay > now)
		delay -= now
	delay /= multiplier
	if (ordinal)
		delay *= ROOT2_FAST
	return now + delay

/mob/living/human/SelfMove(turf/n, direct, deadline = null)
	if (isnull(deadline))
		return ..()
	if (!human_subtile_eligible(direct) || !human_subtile_authority(client) || human_subtile_transaction || n != get_step(src, direct) || !isnum(deadline) || deadline < world.time || deadline >= INFINITY)
		return FALSE
	return human_subtile_travel(n, direct, deadline)

/mob/living/human/proc/human_subtile_travel(turf/n, direct, deadline, legacy_posture = FALSE)
	if (human_subtile_transaction || human_subtile_pulse)
		return FALSE
	var/datum/human_subtile_transaction/T = new
	T.actor = src
	T.owner = client
	T.start_time = world.time
	T.end_time = deadline
	T.expected = human_subtile_snapshot()
	T.legacy_posture = legacy_posture
	if (!legacy_posture)
		human_subtile_update_visuals(deadline - world.time, direct, client)
	human_subtile_transaction = T
	var/moved = FALSE
	try
		moved = T.perform(direct)
	catch (var/exception/subtile_error)
		T.finish()
		throw subtile_error
	T.finish()
	return moved

/datum/human_subtile_transaction/proc/release()
	if (actor && actor.human_subtile_transaction == src)
		actor.human_subtile_pulse = null
		actor.human_subtile_transaction = null
	actor = null
	owner = null
	return

/datum/human_subtile_transaction/proc/valid(direction)
	if (cancelled || !actor || isDeleted(actor) || actor.human_subtile_transaction != src || persistence_save_in_progress || world.time > end_time + world.tick_lag)
		return FALSE
	if (legacy_posture)
		if (!actor.human_subtile_posture_ready(direction) || !actor.human_subtile_posture_authority(owner))
			return FALSE
	else if (!actor.human_subtile_authority(owner) || !actor.human_subtile_eligible(direction))
		return FALSE
	return human_subtile_same(expected, actor.human_subtile_snapshot())

/datum/human_subtile_transaction/proc/perform(direction)
	total_distance = 0
	var/duration = end_time - start_time
	// At an interrupted offset, stop each moving axis at its next alignment.
	// This consumes the same admitted costs/cooldown, and every pixel still
	// uses native collision. A reverse input can therefore escape a 2px offset.
	var/remaining_x = (direction & EAST) ? 32 - actor.step_x : (direction & WEST) ? (actor.step_x ? actor.step_x : 32) : 0
	var/remaining_y = (direction & NORTH) ? 32 - actor.step_y : (direction & SOUTH) ? (actor.step_y ? actor.step_y : 32) : 0
	for (var/i = 1, i <= 16, i++)
		if (!remaining_x && !remaining_y)
			break
		var/due = start_time + (i - 1) * duration / 16
		if (due > world.time)
			sleep(due - world.time)
		if (!valid(direction))
			break
		var/dx = (direction & EAST) ? min(2, remaining_x) : (direction & WEST) ? -min(2, remaining_x) : 0
		var/dy = (direction & NORTH) ? min(2, remaining_y) : (direction & SOUTH) ? -min(2, remaining_y) : 0
		var/tx = actor.x
		var/ty = actor.y
		var/sx = actor.step_x + dx
		var/sy = actor.step_y + dy
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
			break
		// Admission rules for grace walls and hanging apply to every fresh pulse.
		var/grace_blocked = FALSE
		var/list/front_directions = list(direction)
		if (direction & (direction - 1))
			front_directions += direction & (NORTH | SOUTH)
			front_directions += direction & (EAST | WEST)
		for (var/front_direction in front_directions)
			var/turf/front = get_step(actor, front_direction)
			if (map && front && map.check_caribbean_block(actor, front))
				grace_blocked = TRUE
		if (grace_blocked)
			break
		var/hanging = FALSE
		for (var/obj/structure/noose/N in actor.loc)
			if (N.hanging == actor)
				hanging = TRUE
		if (hanging)
			break
		var/datum/human_subtile_pulse/P = new
		P.actor = actor
		P.destination = destination
		P.direction = direction
		P.sx = sx
		P.sy = sy
		P.before = expected
		actor.human_subtile_pulse = P
		// Actual human -> living -> movable chain. The third living flag is intact.
		actor.Move(destination, direction)
		if (!actor || isDeleted(actor) || actor.human_subtile_transaction != src)
			break
		actor.human_subtile_pulse = null
		if (legacy_posture ? !actor.human_subtile_posture_authority(owner) : !actor.human_subtile_authority(owner))
			break
		var/list/after = actor.human_subtile_snapshot()
		if (after["z"] != expected["z"])
			cancelled = TRUE
			break
		var/actual_x = (after["x"] - expected["x"]) * 32 + after["sx"] - expected["sx"]
		var/actual_y = (after["y"] - expected["y"]) * 32 + after["sy"] - expected["sy"]
		observations += list(list("at" = world.time, "due" = due, "engine_return" = P.engine_return, "dx" = actual_x, "dy" = actual_y, "x" = actor.x, "y" = actor.y, "sx" = actor.step_x, "sy" = actor.step_y))
		expected = after
		if (total_distance > 0)
			actor.human_subtile_offset_owned = TRUE
		if (P.invalid || actual_x != dx || actual_y != dy)
			break
		remaining_x -= abs(actual_x)
		remaining_y -= abs(actual_y)
	return total_distance > 0

/datum/human_subtile_transaction/proc/complete()
	if (!completed && actor && !isDeleted(actor) && total_distance > 0)
		completed = TRUE
		actor.human_subtile_pulse = null
		actor.living_movement_completed()
		actor.human_movement_completed()

/datum/human_subtile_transaction/proc/finish()
	try
		complete()
	catch (var/exception/subtile_completion_error)
		release()
		throw subtile_completion_error
	release()

/mob/living/human/proc/human_subtile_take_pulse(turf/destination, direction)
	var/datum/human_subtile_pulse/P = human_subtile_pulse
	if (!P)
		return null
	if (!P.armed || P.actor != src || P.destination != destination || P.direction != direction || !human_subtile_same(P.before, human_subtile_snapshot()))
		P.invalid = TRUE
		return null
	if (!P.restoring && (!human_subtile_transaction || !human_subtile_transaction.valid(direction)))
		P.invalid = TRUE
		return null
	P.armed = FALSE
	return P

/mob/living/human/persistence_runtime_var(key)
	if (key == "glide_size" && (human_subtile_glide_owned || human_subtile_import_owned || human_subtile_position))
		return TRUE
	if ((key == "step_x" || key == "step_y") && (human_subtile_import_owned || human_subtile_position))
		return TRUE
	return (key in list("human_subtile_enabled", "human_subtile_default_pending", "human_subtile_transaction", "human_subtile_pulse", "human_subtile_import_owned", "human_subtile_offset_owned", "human_subtile_glide_owned", "human_subtile_previous_glide", "human_subtile_applied_glide", "human_subtile_visual_owner")) || ..()

// Entry ownership is decided BEFORE assignments, independent of field order.
/mob/living/human/proc/human_subtile_prepare_import(savefile/F)
	human_subtile_import_owned = ("human_subtile_position" in F.dir)
	if (!human_subtile_import_owned)
		human_subtile_position = null
		human_subtile_offset_owned = FALSE

/mob/living/human/before_save()
	. = ..()
	if (human_subtile_pulse)
		throw EXCEPTION("Cannot snapshot an in-flight sub-tile pulse")
	if (human_subtile_transaction)
		human_subtile_transaction.cancelled = TRUE
	if ((human_subtile_enabled || human_subtile_offset_owned) && (step_x || step_y))
		if (!human_subtile_shape() || !human_subtile_unlinked())
			throw EXCEPTION("Unsupported sub-tile save geometry")
		human_subtile_position = human_subtile_snapshot()
	else
		human_subtile_position = null

/mob/living/human/proc/human_subtile_destination_clear(list/S)
	for (var/tx = S["x"], tx <= S["x"] + (S["sx"] > 0), tx++)
		for (var/ty = S["y"], ty <= S["y"] + (S["sy"] > 0), ty++)
			var/turf/T = locate(tx, ty, S["z"])
			if (!T || T.density || T.vehicle_transforming)
				return FALSE
			for (var/atom/movable/A in T)
				if (A != src && !A.CanPass(src, T, 1.5, FALSE))
					return FALSE
	return TRUE

/mob/living/human/after_load()
	. = ..()
	if (!human_subtile_import_owned)
		return
	var/list/S = human_subtile_position
	if (!islist(S) || S.len != 5)
		throw EXCEPTION("Malformed sub-tile position capsule")
	for (var/key in list("x", "y", "z", "sx", "sy"))
		if (!(key in S) || !isnum(S[key]) || S[key] != round(S[key]))
			throw EXCEPTION("Malformed sub-tile position field")
	if (!human_subtile_shape() || !human_subtile_unlinked() || x != S["x"] || y != S["y"] || z != S["z"] || S["sx"] < 0 || S["sx"] >= 32 || S["sy"] < 0 || S["sy"] >= 32 || !human_subtile_destination_clear(S))
		throw EXCEPTION("Sub-tile anchor or destination rejected")
	var/datum/human_subtile_pulse/P = new
	P.actor = src
	P.destination = loc
	P.direction = dir
	P.sx = S["sx"]
	P.sy = S["sy"]
	P.before = human_subtile_snapshot()
	P.restoring = TRUE
	human_subtile_pulse = P
	try
		Move(loc, dir)
	catch (var/exception/subtile_load_error)
		human_subtile_pulse = null
		throw subtile_load_error
	human_subtile_pulse = null
	if (P.invalid || !human_subtile_same(S, human_subtile_snapshot()))
		throw EXCEPTION("Native sub-tile placement did not reach saved position")
	human_subtile_offset_owned = TRUE
	human_subtile_import_owned = FALSE
	living_movement_completed()
	human_movement_completed()
