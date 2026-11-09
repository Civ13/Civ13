// One client admission/cost interval, native cardinal or diagonal pulses.
// Runtime ownership is explicitly excluded from the custom saver below.
#define CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE 1
/mob/living/human
	var/tmp/human_subtile_enabled = FALSE
	var/tmp/human_subtile_default_pending = TRUE
	var/tmp/datum/human_subtile_transaction/human_subtile_transaction
	var/tmp/datum/human_subtile_pulse/human_subtile_pulse
	var/tmp/datum/human_subtile_save_request/human_subtile_save_request
	var/tmp/datum/save_export_frame/human_subtile_save_hook_frame
	var/tmp/human_subtile_import_owned = FALSE
	var/tmp/list/human_direct_preflight_position
	var/tmp/human_subtile_offset_owned = FALSE
	var/tmp/human_subtile_glide_owned = FALSE
	var/tmp/human_subtile_previous_glide = 0
	var/tmp/human_subtile_applied_glide = 0
	var/tmp/client/human_subtile_visual_owner
	// Start of a held-key continuation: the previous step's deadline.
	var/tmp/human_subtile_chain_start
	// world.time a held precision slide stopped because its chord was released.
	var/tmp/human_subtile_fine_released_at
	var/tmp/list/human_subtile_pull_trail
	var/tmp/human_subtile_pull_trail_for
	// Set by before_save when an offset capsule would be rejected on load.
	var/tmp/human_subtile_save_aligned = FALSE
	// Set while a free-movement trench climb waits out its delay.
	var/tmp/human_subtile_climbing = FALSE
	var/list/human_subtile_position
	// Absent in historical capsules. Only validated new captures may use 1.
	var/human_subtile_restore_schema = 0

/client
	var/tmp/mob/living/human/human_subtile_visual_actor
	var/tmp/human_subtile_visual_owned = FALSE
	var/tmp/human_subtile_previous_glide
	var/tmp/human_subtile_applied_glide
	// Deadline of the smooth step a held key is continuing from, for one Move.
	var/tmp/human_subtile_chain_time

/client/proc/human_subtile_release_visuals()
	if (!human_subtile_visual_owned)
		return
	if (human_subtile_visual_actor)
		human_subtile_visual_actor.human_subtile_release_glide()
		if (human_subtile_visual_actor.human_subtile_visual_owner == src)
			human_subtile_visual_actor.human_subtile_visual_owner = null
	human_subtile_visual_actor = null
	human_subtile_visual_owned = FALSE
	if (glide_size == human_subtile_applied_glide)
		glide_size = human_subtile_previous_glide

/mob/living/human/proc/human_subtile_release_glide()
	if (human_subtile_glide_owned)
		if (glide_size == human_subtile_applied_glide)
			glide_size = human_subtile_previous_glide
		human_subtile_glide_owned = FALSE

/mob/living/human/proc/human_subtile_update_visuals(duration, direction, client/owner, distance = 32)
	release_carriage_glide()
	if (owner && human_subtile_visual_owner && human_subtile_visual_owner != owner)
		human_subtile_visual_owner.human_subtile_release_visuals()
	if (!human_subtile_glide_owned)
		human_subtile_previous_glide = glide_size
		human_subtile_glide_owned = TRUE
	else if (glide_size != human_subtile_applied_glide)
		human_subtile_previous_glide = glide_size
	// Native interpolation follows physical motion, including normalization at
	// tile edges. Client FPS belongs to the account preference, not movement.
	glide_size = distance * world.tick_lag / max(duration, world.tick_lag)
	if ((direction & (direction - 1)) && !(appearance_flags & LONG_GLIDE))
		glide_size *= ROOT2_FAST
	human_subtile_applied_glide = glide_size
	if (owner)
		if (owner.human_subtile_visual_actor != src)
			owner.human_subtile_release_visuals()
			owner.human_subtile_previous_glide = owner.glide_size
			owner.human_subtile_visual_actor = src
			owner.human_subtile_visual_owned = TRUE
			human_subtile_visual_owner = owner
		else
			if (owner.glide_size != owner.human_subtile_applied_glide)
				owner.human_subtile_previous_glide = owner.glide_size
		owner.glide_size = glide_size
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
	// A sideways try after the straight pulse was blocked.
	var/slide = FALSE

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
	var/paid_posture
	var/initial_prone
	var/initial_lying
	var/attempted = FALSE
	var/fine_step = FALSE

// An operation-owned, nonyielding handoff. This is not yet wired to the saver
// or movement admission; it does not authorize a save or change any lock.
/datum/human_subtile_save_request
	should_save = FALSE
	var/mob/living/human/actor
	var/datum/persistence_world_operation/operation
	var/turf/origin
	var/list/position
	var/captured = FALSE
	var/serialized = FALSE
	var/spatial_attached = FALSE
	var/saved_ref = 0
	var/saved_z = 0
	var/encoded_origin_checked = FALSE
	var/encoded_present_slots_checked = FALSE
	var/encoded_anchor_checked = FALSE
	var/reciprocal_links_checked = FALSE
	var/encoded_links_checked = FALSE
	proc/acknowledge(mob/living/human/H, datum/human_subtile_transaction/T)
		if(captured || !H || isDeleted(H) || actor != H || H.human_subtile_save_request != src || !operation || !operation.current(operation.storage, "save")) return FALSE
		if(H.human_subtile_pulse || !H.human_subtile_shape() || !H.human_subtile_unlinked() || H.pulling || subtile_pull_ownership.owners[H]) return FALSE
		if(H.human_subtile_transaction != T || (T && (T.actor != H || T.cancelled))) return FALSE
		var/turf/start = H.loc
		var/list/current = H.human_subtile_snapshot()
		if(T && !human_subtile_same(T.expected, current)) return FALSE
		// The entire handoff is synchronous; no hook, native move or wait here.
		origin = start
		// Freeze the actual tile in the same nonyielding observation as loc.
		// Fractional movement is transient; never export it into the save.
		position = list("x" = start.x, "y" = start.y, "z" = start.z, "sx" = 0, "sy" = 0)
		captured = TRUE
		return TRUE
	proc/release()
		if(actor && actor.human_subtile_save_request == src)
			actor.human_subtile_save_request = null
		actor = null
		operation = null
		origin = null
		position = null
		return

/mob/living/human/proc/request_human_subtile_save_position(datum/persistence_world_operation/operation)
	if(!operation || !operation.current(operation.storage, "save") || human_subtile_save_request) return null
	var/datum/human_subtile_save_request/request = new
	request.actor = src
	request.operation = operation
	human_subtile_save_request = request
	if(!operation.track_human_spatial_request(request))
		request.release()
		return null
	if(!human_subtile_transaction && !human_subtile_pulse)
		request.acknowledge(src, null)
	return request

/mob/living/human/proc/human_subtile_snapshot()
	return list("x" = x, "y" = y, "z" = z, "sx" = step_x, "sy" = step_y)

/proc/human_subtile_same(list/a, list/b)
	if (!islist(a) || !islist(b) || a.len != 5 || b.len != 5)
		return FALSE
	for (var/key in list("x", "y", "z", "sx", "sy"))
		if (!(key in a) || !(key in b) || !isnum(a[key]) || !isnum(b[key]) || a[key] != round(a[key]) || b[key] != round(b[key]) || a[key] != b[key])
			return FALSE
	return TRUE

// Players keep walking during a world save. Saves are tile-only for humans:
// a body is saved on the tile it occupies when its entry is written, with no
// movement offset, and the tile walk/sweep keep exactly one saved parent.
// Motion never releases load, dimension or startup holds. A busy restart may
// move only under its own currently admitted save operation.
/proc/human_subtile_save_motion_allowed()
	var/datum/persistence_world_operation/operation = persistence_active_operation
	var/map_storage/storage = operation ? operation.storage : null
	return operation && storage && operation.current(storage, "save") && !persistence_load_recovery_required && !storage.dimension_recovery_required && !storage.dimension_budget_hold && !persistence_restart.startup_hold && ((!persistence_restart.busy && !operation.restart_transaction) || (persistence_restart.busy && operation.restart_transaction == persistence_restart))

/mob/living/human/proc/human_subtile_shape()
	return isturf(loc) && world.icon_size == 32 && bound_x == 0 && bound_y == 0 && bound_width == 32 && bound_height == 32 && isnum(step_x) && isnum(step_y) && step_x >= 0 && step_x < 32 && step_y >= 0 && step_y < 32 && step_x == round(step_x) && step_y == round(step_y)

/mob/living/human/proc/human_subtile_eligible(direction)
	return human_subtile_enabled && human_subtile_ready(direction)

/mob/living/human/proc/human_subtile_ready(direction)
	if (persistence_save_in_progress && pulling && subtile_pull_ownership.owners[pulling])
		return FALSE
	return !subtile_pull_ownership.owners[src] && human_subtile_shape() && (direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)) && !stat && canmove && !transforming && !lying && !prone && !crouching && !restrained() && (!pinned || !pinned.len) && human_subtile_unlinked() && (!human_subtile_trench_crossing(direction) || human_subtile_climb_ready())

// Climbing into or out of a trench (or onto a bridge or frame over one) waits
// inside turf Enter/Exit. A sleeping Enter/Exit fails the native pixel Move at
// once, so a smooth step would stall at the edge. From a tile-aligned position,
// such a crossing takes the ordinary tile path, which owns that climb.
/mob/living/human/proc/human_subtile_trench_crossing(direction)
	if (step_x || step_y || !isturf(loc))
		return FALSE
	var/turf/origin = loc
	var/level = origin.trench_climb_level()
	var/list/fronts = list(direction)
	if (direction & (direction - 1))
		fronts += direction & (NORTH | SOUTH)
		fronts += direction & (EAST | WEST)
	for (var/front_direction in fronts)
		var/turf/front = get_step(origin, front_direction)
		if (front && front.trench_climb_level() != level)
			return TRUE
	return FALSE

// A free slide at an offset that would reach a trench edge takes the tile path
// instead: that step aligns the body, and the next aligned step owns the climb.
/mob/living/human/proc/human_subtile_trench_near(direction)
	if (!isturf(loc))
		return FALSE
	var/list/fronts = list(direction)
	if (direction & (direction - 1))
		fronts += direction & (NORTH | SOUTH)
		fronts += direction & (EAST | WEST)
	var/level = null
	for (var/turf/T in locs)
		var/here = T.trench_climb_level()
		if (isnull(level))
			level = here
		else if (here != level)
			return TRUE
		for (var/front_direction in fronts)
			var/turf/front = get_step(T, front_direction)
			if (front && front.trench_climb_level() != level)
				return TRUE
	return FALSE

// Free-movement trench climbs. A body walks freely up to the edge and climbs
// from wherever it stands, keeping its sideways offset when the tiles beyond
// allow it. Pulling a living body or being grabbed keeps the tile path.
/mob/living/human/proc/human_subtile_climb_ready()
	return human_subtile_enabled && !human_subtile_climbing && !human_subtile_transaction && human_subtile_shape() && !stat && canmove && !transforming && !lying && !prone && !crouching && !restrained() && (!pinned || !pinned.len) && human_subtile_unlinked() && !driver && !buckled && !subtile_pull_ownership.owners[src] && (!pulling || (isturf(pulling.loc) && !isliving(pulling))) && (!grabbed_by || !grabbed_by.len) && mob_size > MOB_SMALL && ((!step_x && !step_y) || human_subtile_offset_owned)

// The turfs a 32x32 body covers at tile (tx, ty) with offset (sx, sy).
/mob/living/human/proc/human_subtile_cover(tx, ty, sx, sy)
	. = list()
	for (var/cx in tx to (sx ? tx + 1 : tx))
		for (var/cy in ty to (sy ? ty + 1 : ty))
			var/turf/T = locate(cx, cy, z)
			if (T)
				. += T

// Whether moving the body by (dx, dy) pixels would reach a tile at another
// climb level, or leave a trench turf for one, where turf Enter/Exit waits.
// The climb starts at the first overlap, both into and out of a trench.
/mob/living/human/proc/human_subtile_pulse_climbs(dx, dy)
	if (!isturf(loc))
		return FALSE
	var/tx = x
	var/ty = y
	var/sx = step_x + dx
	var/sy = step_y + dy
	while (sx < 0)
		tx--
		sx += 32
	while (sx >= 32)
		tx++
		sx -= 32
	while (sy < 0)
		ty--
		sy += 32
	while (sy >= 32)
		ty++
		sy -= 32
	var/turf/oldloc = loc
	var/turf/newloc = locate(tx, ty, z)
	if (!newloc)
		return FALSE
	var/list/before = human_subtile_cover(x, y, step_x, step_y)
	var/list/after = human_subtile_cover(tx, ty, sx, sy)
	var/old_level = oldloc.trench_climb_level()
	var/new_level = newloc.trench_climb_level()
	for (var/turf/T in after - before)
		if (T.trench_climb_level() != old_level)
			return TRUE
	for (var/turf/T in before - after)
		if (istype(T, /turf/floor/trench) && T.trench_climb_level() != new_level)
			return TRUE
	return FALSE

// The cardinal part of a step that would climb, vertical first, or 0.
/mob/living/human/proc/human_subtile_climb_direction(direction)
	for (var/part in list(direction & (NORTH | SOUTH), direction & (EAST | WEST)))
		if (!part)
			continue
		var/dx = (part == EAST) ? 2 : (part == WEST) ? -2 : 0
		var/dy = (part == NORTH) ? 2 : (part == SOUTH) ? -2 : 0
		if (human_subtile_pulse_climbs(dx, dy))
			return part
	return 0

// Whether the body could stand at (tx, ty) with offset (sx, sy) after a climb.
/mob/living/human/proc/human_subtile_climb_open(tx, ty, sx, sy)
	var/list/cover = human_subtile_cover(tx, ty, sx, sy)
	if (cover.len != (sx ? 2 : 1) * (sy ? 2 : 1))
		return FALSE
	var/level = null
	for (var/turf/T in cover)
		if (!human_subtile_slide_open(T))
			return FALSE
		if (isnull(level))
			level = T.trench_climb_level()
		else if (T.trench_climb_level() != level)
			return FALSE
		if (map && map.check_caribbean_block(src, T))
			return FALSE
		for (var/mob/living/M in T)
			if (M != src && M.density && !swap_passable(M))
				return FALSE
	return TRUE

// Where a climb lands: the next row (or column) along the climb, keeping the
// sideways offset when the tiles there allow it, else the nearer open tile.
/mob/living/human/proc/human_subtile_climb_target(direction)
	var/vertical = direction & (NORTH | SOUTH)
	var/tx = x
	var/ty = y
	var/sx = step_x
	var/sy = step_y
	switch (direction)
		if (NORTH)
			ty++
			sy = 0
		if (SOUTH)
			ty = sy ? ty : ty - 1
			sy = 0
		if (EAST)
			tx++
			sx = 0
		if (WEST)
			tx = sx ? tx : tx - 1
			sx = 0
	var/side = vertical ? sx : sy
	if (human_subtile_climb_open(tx, ty, sx, sy))
		return list(tx, ty, sx, sy)
	if (!side)
		return null
	// Prefer the tile the body overlaps most.
	var/list/choices = (side < 16) ? list(0, 1) : list(1, 0)
	for (var/shift in choices)
		var/cx = vertical ? tx + shift : tx
		var/cy = vertical ? ty : ty + shift
		if (human_subtile_climb_open(cx, cy, vertical ? 0 : sx, vertical ? sy : 0))
			return list(cx, cy, vertical ? 0 : sx, vertical ? sy : 0)
	return null

/mob/living/human/proc/human_subtile_trench_climb(direction)
	var/list/target = human_subtile_climb_target(direction)
	if (!target)
		return FALSE
	var/turf/origin = loc
	var/turf/destination = locate(target[1], target[2], z)
	var/from_level = origin.trench_climb_level()
	var/to_level = destination.trench_climb_level()
	if (from_level == to_level)
		return FALSE
	var/down = to_level > from_level
	var/action = "exit a trench"
	if (down)
		action = istype(origin, /turf/floor/trench) ? "climb down" : "enter a trench"
	else if (locate(/obj/covers/repairedfloor) in destination)
		action = "climb on a bridge"
	else if (locate(/obj/structure/vehicleparts/frame) in destination)
		action = "climb on a frame"
	var/turf/floor/trench/edge = istype(destination, /turf/floor/trench) ? destination : origin
	if (istype(edge) && world.time > edge.message_cooldown + 30)
		visible_message(SPAN_NOTICE("[src] starts to [action]."))
		edge.message_cooldown = world.time
	dir = direction
	var/start_x = step_x
	var/start_y = step_y
	human_subtile_climbing = TRUE
	var/climbed = do_after(src, down ? 5 : 20, destination, needhand = FALSE)
	human_subtile_climbing = FALSE
	if (!climbed || loc != origin || step_x != start_x || step_y != start_y || !human_subtile_climb_ready())
		return FALSE
	if (!human_subtile_climb_open(target[1], target[2], target[3], target[4]))
		return FALSE
	var/atom/movable/pulled = pulling
	if (!trench_climb_place_offset(src, destination, target[3], target[4]))
		return FALSE
	if (pulled && pulling == pulled && !isliving(pulled))
		pulled.forceMove(destination)
	living_movement_completed()
	return TRUE

// Free and fine input never take ownership of a link. Pulling slides too:
// living/Move drags the pulled object onto each tile the body clears.
/mob/living/human/proc/human_subtile_fine_ready(direction)
	return human_subtile_eligible(direction) && !driver && (!pulling || isturf(pulling.loc)) && ((!step_x && !step_y) || human_subtile_offset_owned)

/mob/living/human/proc/human_subtile_initialize_default(direction)
	// Wait for an eligible input, after construction/placement/load. Do not adopt
	// arbitrary legacy offsets, replay workers, or bypass the setter's safety.
	if (human_subtile_default_pending && human_subtile_ready(direction) && ((!step_x && !step_y) || human_subtile_offset_owned))
		return set_human_subtile(TRUE)
	return FALSE

// Pulling and open menus keep smooth movement: living/Move drags the pulled
// object behind each tile crossing, and menus only record their source window.
/mob/living/human/proc/human_subtile_unlinked()
	return !buckled && !riding && !riding_mob && !using_drone && !control_object && !incorporeal_move && !pulledby && (!grab_list || !grab_list.len) && (!grabbed_by || !grabbed_by.len) && !istype(using_object, /obj/item/weapon/gun/projectile/automatic/stationary) && !using_cannon && !football

// Identifies a still-valid passive recipe view. It no longer gates movement:
// admission follows human_subtile_unlinked() above for every using_object.
/atom/movable/proc/allows_smooth_movement_ui(mob/living/human/user)
	return FALSE

/mob/living/human/proc/human_subtile_prepare_ui_movement()
	if (!(human_subtile_enabled || human_subtile_default_pending || human_subtile_offset_owned))
		return
	if (!istype(using_object, /obj/item/stack) || using_object.allows_smooth_movement_ui(src))
		return
	// Close a stale recipe view after a hand switch, drop, transfer or depleted
	// stack, so its refresh/close callbacks never target a stack no longer held.
	// Other object-use links stay put; this does not gate movement.
	unset_using_object()
	if (client)
		client << browse(null, "window=stack")

/mob/living/human/proc/human_subtile_input_supported(direction)
	human_subtile_initialize_default(direction)
	// Never let the tile-aligned legacy fallback move a member of an owned pair
	// while save admission settles it, including an owned pulled follower.
	if (persistence_save_in_progress && (subtile_pull_ownership.owners[src] || (pulling && subtile_pull_ownership.owners[pulling])))
		return FALSE
	// Unsupported transitions keep the legacy path only when tile-aligned.
	// A restored capsule also owns a physical offset while the opt-in is off.
	if (!human_subtile_enabled && !human_subtile_offset_owned)
		return TRUE
	if (!step_x && !step_y)
		return TRUE
	return human_subtile_eligible(direction) || human_subtile_posture_ready(direction) || human_subtile_pull_ready(direction)

// Crawling has its own legacy wait and admission. Let that paid path recover
// an owned offset without making unconscious/restrained/linked bodies eligible.
/mob/living/human/proc/human_subtile_posture_ready(direction)
	return !subtile_pull_ownership.owners[src] && human_subtile_offset_owned && (step_x || step_y) && human_subtile_shape() && (direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)) && (prone || lying) && !stat && !transforming && !paralysis && !stunned && !sleeping && !(status_flags & FAKEDEATH) && !restrained() && weakened <= 10 && has_limbs && (!pinned || !pinned.len) && human_subtile_unlinked()

/mob/living/human/proc/human_subtile_posture_authority(client/owner)
	return client == owner && (!owner || (owner.mob == src && owner.canmove))

/mob/living/human/proc/human_subtile_posture_move(turf/n)
	var/direct = get_dir(loc, n)
	if (!human_subtile_posture_ready(direct) || n != get_step(src, direct) || !human_subtile_posture_authority(client))
		return FALSE
	// Called only after proning/scramble already consumed its original wait.
	// Zero duration retains that cadence; at most sixteen native collision
	// pulses align moving axes, with one pair of completion hooks.
	return human_subtile_travel(n, direct, world.time, TRUE)

// Called after the original posture admission, before its paid wait. A handled
// attempt owns the entire interval, including an early collision/cancellation.
// This profile is client locomotion; NPC/linked bodies keep their legacy path.
// Smooth walking may pull, but a pulling crawl stays on the legacy path.
/mob/living/human/proc/human_subtile_crawl_authority(client/owner)
	return owner && client == owner && owner.mob == src && owner.canmove

/mob/living/human/proc/human_subtile_crawl_ready(direction)
	return human_subtile_shape() && (direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)) && (prone || lying) && !stat && !transforming && !crouching && !paralysis && !stunned && !sleeping && !(status_flags & FAKEDEATH) && !restrained() && weakened <= 10 && has_limbs && (!pinned || !pinned.len) && human_subtile_unlinked() && !pulling && ((!step_x && !step_y) || human_subtile_offset_owned) && !human_subtile_trench_crossing(direction)

/mob/living/human/proc/human_subtile_crawl_move(turf/n, duration, posture)
	// From the anchor tile: a body between tiles overlaps n, so get_dir(src, n) is 0.
	var/direct = get_dir(loc, n)
	if (human_subtile_transaction || human_subtile_pulse || !scrambling || !human_subtile_crawl_ready(direct) || !human_subtile_crawl_authority(client) || n != get_step(src, direct) || !(posture in list("prone", "scramble")) || !isnum(duration) || duration <= 0 || duration >= INFINITY)
		return FALSE
	if (human_subtile_default_pending)
		set_human_subtile(TRUE)
	if (!human_subtile_enabled)
		return FALSE
	var/deadline = world.time + duration
	if (client)
		client.move_delay = max(client.move_delay, deadline)
	// A held key crawls freely like walking: a whole tile's distance from
	// wherever the body is, sliding along walls, stopping on release.
	human_subtile_travel(n, direct, deadline, FALSE, posture, (held_movement_direction() == direct) ? FINE_STEP_HELD : FALSE)
	return TRUE

/mob/living/human/proc/set_human_subtile(enabled)
	if (human_subtile_transaction || human_subtile_pulse || subtile_pull_ownership.owners[src] || !human_subtile_shape())
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

// This narrow hook is adapted explicitly by the headless fixture. Production
// always requires the same real client/body and ordinary movement permission.
/mob/living/human/proc/human_subtile_authority(client/owner)
	return owner && client == owner && owner.mob == src && owner.canmove && owner.moving

// Same arithmetic as the existing cardinal client.Move epilogue, captured BEFORE
// sleeping. The disabled path still executes the original epilogue unchanged.
// A held key used to wait for the deadline tick and then one more scan tick
// before its next step. Chained held steps keep that pace, so smooth walking
// and running are no faster than before; only the stop at tile centres is gone.
/mob/living/human/proc/human_subtile_held_pace(duration)
	var/ticks = -round(-round(duration / world.tick_lag, 0.001))
	return (max(1, ticks) + 1) * world.tick_lag

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

// Whether a body could stand on T ahead, judged without calling Enter (trench
// and other turfs sleep or have side effects there). Native collision still
// decides every pulse; this only picks which way to slide.
/mob/living/human/proc/human_subtile_slide_open(turf/T)
	if (!T || T.density)
		return FALSE
	for (var/atom/movable/A in T)
		if (A != src && A.density && !istype(A, /mob))
			return FALSE
	return TRUE

// Graal-style sliding for a blocked free or held slide. Diagonals slide along
// a wall on either axis. A straight move that clips a corner shifts sideways
// toward the open tile ahead (a doorway), or to the nearer alignment when
// it is within 12px of one.
/mob/living/human/proc/human_subtile_slide_attempts(direction)
	. = list()
	if (direction & (direction - 1))
		. += list(list((direction & EAST) ? 2 : -2, 0))
		. += list(list(0, (direction & NORTH) ? 2 : -2))
		return .
	var/vertical = direction & (NORTH | SOUTH)
	var/offset = vertical ? step_x : step_y
	if (!offset || !isturf(loc))
		return .
	// With an offset along the travel axis, east/north fronts sit a tile further on.
	var/turf/base = loc
	if (((direction & EAST) && step_x) || ((direction & NORTH) && step_y))
		base = get_step(base, direction)
	var/turf/near_side = get_step(base, direction)
	var/turf/far_side = near_side ? get_step(near_side, vertical ? EAST : NORTH) : null
	var/open_near = human_subtile_slide_open(near_side)
	var/open_far = human_subtile_slide_open(far_side)
	var/shift = 0
	if (open_near && !open_far)
		shift = -min(2, offset)
	else if (open_far && !open_near)
		shift = min(2, 32 - offset)
	else if (open_near && open_far)
		if (offset <= 12)
			shift = -min(2, offset)
		else if (offset >= 20)
			shift = min(2, 32 - offset)
	if (shift)
		. += list(vertical ? list(shift, 0) : list(0, shift))
	return .

// Free movement while pulling: step the pulled object onto the neighbouring
// tile nearest the body's centre that the body no longer covers, when that
// brings it closer. It trails one tile behind, wherever the body turns.
/mob/living/human/proc/human_subtile_pull_follow()
	var/atom/movable/M = pulling
	if (!M || !isturf(M.loc) || M.anchored || M.z != z)
		return FALSE
	// Pulled things follow the tiles the body's centre has walked through, so
	// they trail along the path round corners instead of cutting sideways.
	if (human_subtile_pull_trail_for != "\ref[M]" || !islist(human_subtile_pull_trail))
		human_subtile_pull_trail = list()
		human_subtile_pull_trail_for = "\ref[M]"
	var/turf/centre = locate(x + (step_x >= 16 ? 1 : 0), y + (step_y >= 16 ? 1 : 0), z)
	if (centre && (!human_subtile_pull_trail.len || human_subtile_pull_trail[human_subtile_pull_trail.len] != centre))
		human_subtile_pull_trail += centre
		if (human_subtile_pull_trail.len > 4)
			human_subtile_pull_trail.Cut(1, 2)
	// Follow only once a gap opens, so it never pushes into the body.
	if (bounds_dist(src, M) <= 0)
		return FALSE
	// The newest trail tile next to the object that the body has fully left.
	var/turf/target
	var/target_index = 0
	for (var/i = human_subtile_pull_trail.len, i >= 1, i--)
		var/turf/T = human_subtile_pull_trail[i]
		if (T == M.loc || !T || T.z != M.z || T.density || (T in locs) || get_dist(M, T) != 1)
			continue
		target = T
		target_index = i
		break
	if (!target)
		// Off the trail and about to be left behind: step toward the body.
		if (bounds_dist(src, M) < 32)
			return FALSE
		var/cx = x * 32 + step_x + 16
		var/cy = y * 32 + step_y + 16
		var/best = (cx - (M.x * 32 + M.step_x + 16)) ** 2 + (cy - (M.y * 32 + M.step_y + 16)) ** 2
		for (var/dir_option in alldirs)
			var/turf/T = get_step(M, dir_option)
			if (!T || T.density || (T in locs))
				continue
			var/distance = (cx - (T.x * 32 + 16)) ** 2 + (cy - (T.y * 32 + 16)) ** 2
			if (distance < best)
				best = distance
				target = T
		if (!target)
			return FALSE
	else
		human_subtile_pull_trail.Cut(1, target_index + 1)
	// Glide the tile step at the body's own pace so it slides, not jumps.
	if (glide_size > 0)
		M.glide_size = glide_size * ((get_dir(M, target) & (get_dir(M, target) - 1)) ? ROOT2_FAST : 1)
	return step(M, get_dir(M, target))

// Walking through someone (help intent), drift 2px per pulse away from them,
// or to your right when dead centre, until at least 2px apart. Walls still
// win: in a one-tile corridor the sideways try fails and you pass overlapping.
/mob/living/human/proc/human_subtile_pass_nudge(direction)
	if (!direction || (direction & (direction - 1)))
		return null
	var/cx = x * 32 + step_x
	var/cy = y * 32 + step_y
	for (var/mob/living/L in obounds(src, 2))
		if (L == src || !L.density || !swap_passable(L))
			continue
		var/lx = L.x * 32 + L.step_x
		var/ly = L.y * 32 + L.step_y
		if (direction & (EAST | WEST))
			var/side_y = (cy > ly) ? 2 : (cy < ly) ? -2 : ((direction & EAST) ? -2 : 2)
			return list(0, side_y)
		var/side_x = (cx > lx) ? 2 : (cx < lx) ? -2 : ((direction & NORTH) ? 2 : -2)
		return list(side_x, 0)
	return null

// Free movement swaps places only when walking straight into someone head-on,
// as in a corridor. Grazing them, moving diagonally or sliding round them
// just blocks, so bodies never jump past each other.
/mob/living/human/proc/human_subtile_swap_allowed(mob/living/other)
	var/datum/human_subtile_pulse/P = human_subtile_pulse
	if (!P || !human_subtile_transaction || !human_subtile_transaction.fine_step)
		return TRUE
	var/direction = P.direction
	if (P.slide || (direction & (direction - 1)))
		return FALSE
	var/dx = (other.x * 32 + other.step_x) - (x * 32 + step_x)
	var/dy = (other.y * 32 + other.step_y) - (y * 32 + step_y)
	if (direction & (EAST | WEST))
		return abs(dy) <= 12 && ((direction & EAST) ? dx > 0 : dx < 0)
	return abs(dx) <= 12 && ((direction & NORTH) ? dy > 0 : dy < 0)

// Share of a whole tile left before each moving axis reaches its alignment.
/mob/living/human/proc/human_subtile_remaining_fraction(direction)
	var/remaining_x = (direction & EAST) ? 32 - step_x : (direction & WEST) ? (step_x ? step_x : 32) : 0
	var/remaining_y = (direction & NORTH) ? 32 - step_y : (direction & SOUTH) ? (step_y ? step_y : 32) : 0
	return max(remaining_x, remaining_y) / 32

/mob/living/human/SelfMove(turf/n, direct, deadline = null, fine_step = FALSE)
	if (isnull(deadline))
		return ..()
	if (human_subtile_climbing)
		return FALSE
	if (fine_step && !human_subtile_fine_ready(direct))
		return FALSE
	// At a trench edge a free step climbs from wherever the body stands.
	// Pulling a living body or being grabbed settles on the tile and takes the
	// tile path's climb instead.
	var/climb_direction = human_subtile_climb_direction(direct)
	if (climb_direction && human_subtile_authority(client) && !human_subtile_transaction)
		if (human_subtile_climb_ready())
			return human_subtile_trench_climb(climb_direction)
		trench_climb_align(src)
		return Move(get_step(src, direct), direct)
	if (!fine_step && human_subtile_pull_ready(direct))
		return human_subtile_pull_travel(n, direct, deadline)
	if (!human_subtile_eligible(direct) || !human_subtile_authority(client) || human_subtile_transaction || n != get_step(src, direct) || !isnum(deadline) || deadline < world.time || deadline >= INFINITY)
		return FALSE
	return human_subtile_travel(n, direct, deadline, fine_step = fine_step)

/mob/living/human/proc/human_subtile_travel(turf/n, direct, deadline, legacy_posture = FALSE, paid_posture = null, fine_step = FALSE)
	if (human_subtile_transaction || human_subtile_pulse)
		return FALSE
	var/datum/human_subtile_transaction/T = new
	T.actor = src
	T.owner = client
	T.start_time = world.time
	// A held-key continuation keeps the previous step's exact cadence, so the
	// pulses and glide run on without a pause at the tile centre.
	if (!legacy_posture && !paid_posture && fine_step != FINE_STEP_NUDGE && isnum(human_subtile_chain_start) && human_subtile_chain_start <= world.time && world.time - human_subtile_chain_start < world.tick_lag && deadline > human_subtile_chain_start)
		T.start_time = human_subtile_chain_start
	human_subtile_chain_start = null
	T.end_time = deadline
	T.expected = human_subtile_snapshot()
	T.legacy_posture = legacy_posture
	T.paid_posture = paid_posture
	T.fine_step = fine_step
	T.initial_prone = prone
	T.initial_lying = lying
	if (!legacy_posture && !paid_posture)
		human_subtile_update_visuals(deadline - T.start_time, direct, client, (fine_step == FINE_STEP_NUDGE) ? 2 : 32)
	human_subtile_transaction = T
	var/moved = FALSE
	try
		moved = T.perform(direct)
	catch (var/exception/subtile_error)
		T.wait_paid_interval()
		T.finish()
		throw subtile_error
	T.finish()
	return moved

/datum/human_subtile_transaction/proc/release()
	var/mob/living/human/released_actor = actor
	if (actor && actor.human_subtile_transaction == src)
		if (paid_posture)
			release_visuals()
		actor.human_subtile_pulse = null
		actor.human_subtile_transaction = null
	actor = null
	owner = null
	if (released_actor && released_actor.human_subtile_save_request)
		released_actor.human_subtile_save_request.acknowledge(released_actor, null)
	return

/datum/human_subtile_transaction/proc/release_visuals()
	if (actor && actor.human_subtile_transaction == src)
		if (owner && owner.human_subtile_visual_actor == actor)
			owner.human_subtile_release_visuals()
		actor.human_subtile_release_glide()

/datum/human_subtile_transaction/proc/valid(direction)
	if (cancelled || !actor || isDeleted(actor) || actor.human_subtile_transaction != src || (persistence_save_in_progress && !human_subtile_save_motion_allowed()) || world.time > end_time + world.tick_lag)
		return FALSE
	if (fine_step && !paid_posture && !actor.human_subtile_fine_ready(direction))
		return FALSE
	if (paid_posture)
		if (!actor.scrambling || !actor.human_subtile_enabled || !actor.human_subtile_crawl_ready(direction) || !actor.human_subtile_crawl_authority(owner) || actor.prone != initial_prone || actor.lying != initial_lying)
			return FALSE
		if (map && map.check_caribbean_block(actor, get_turf(actor)))
			return FALSE
	else if (legacy_posture)
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
	if (fine_step == FINE_STEP_NUDGE)
		remaining_x = (direction & (EAST | WEST)) ? 2 : 0
		remaining_y = (direction & (NORTH | SOUTH)) ? 2 : 0
	else if (fine_step)
		// A held precision slide covers one tile's distance from wherever the
		// body is, crossing alignments, until its chord is released.
		remaining_x = (direction & (EAST | WEST)) ? 32 : 0
		remaining_y = (direction & (NORTH | SOUTH)) ? 32 : 0
	// Pulses spread over the interval by the distance this step really covers,
	// so a short step from an offset moves at the ordinary pace.
	var/pulse_count = max(1, ceil(max(remaining_x, remaining_y) / 2))
	if (paid_posture)
		actor.human_subtile_update_visuals(duration, direction, owner, max(remaining_x, remaining_y))
	for (var/i = 1, i <= 16, i++)
		if (!remaining_x && !remaining_y)
			break
		var/due = start_time + (i - 1) * duration / pulse_count
		if (paid_posture)
			due = start_time + i * duration / pulse_count
			// Observe cancellation every tick, including injury-lengthened waits.
			while (due > world.time && valid(direction))
				sleep(world.tick_lag)
		else if (due > world.time)
			sleep(due - world.time)
		if (!valid(direction))
			break
		if (fine_step == FINE_STEP_HELD && actor.held_movement_direction() != direction)
			actor.human_subtile_fine_released_at = world.time
			break
		var/main_dx = (direction & EAST) ? min(2, remaining_x) : (direction & WEST) ? -min(2, remaining_x) : 0
		var/main_dy = (direction & NORTH) ? min(2, remaining_y) : (direction & SOUTH) ? -min(2, remaining_y) : 0
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
		// Free and held slides try the pulse straight on first. When it is blocked
		// outright they slide: a diagonal runs along the wall on whichever axis is
		// free, and a straight move slips sideways around a corner into an opening.
		// At a trench edge the slide stops; the next input climbs from here.
		if (!paid_posture && !legacy_posture && actor.human_subtile_climb_direction(direction))
			break
		var/list/attempts = list(list(main_dx, main_dy))
		if (fine_step == FINE_STEP_HELD)
			// Passing through someone, ease sideways to keep a little distance.
			var/list/nudge = actor.human_subtile_pass_nudge(direction)
			if (nudge)
				attempts.Insert(1, list(list(main_dx + nudge[1], main_dy + nudge[2])))
			attempts += actor.human_subtile_slide_attempts(direction)
		var/moved_pulse = FALSE
		var/stop = FALSE
		var/attempt_index = 0
		for (var/list/attempt in attempts)
			attempt_index++
			var/dx = attempt[1]
			var/dy = attempt[2]
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
				stop = TRUE
				break
			// A climb between trench levels waits in turf Enter/Exit, which would
			// fail a native pixel pulse. The slide stops at the edge instead and
			// the next input climbs (human_subtile_trench_climb).
			if (!paid_posture && !legacy_posture && actor.human_subtile_pulse_climbs(dx, dy))
				continue
			var/datum/human_subtile_pulse/P = new
			attempted = TRUE
			P.actor = actor
			P.destination = destination
			P.direction = direction
			P.sx = sx
			P.sy = sy
			P.slide = attempt_index > 1
			P.before = expected
			actor.human_subtile_pulse = P
			// Actual human -> living -> movable chain. The third living flag is intact.
			actor.Move(destination, direction)
			if (!actor || isDeleted(actor) || actor.human_subtile_transaction != src)
				stop = TRUE
				break
			actor.human_subtile_pulse = null
			if (paid_posture ? !actor.human_subtile_crawl_authority(owner) : (legacy_posture ? !actor.human_subtile_posture_authority(owner) : !actor.human_subtile_authority(owner)))
				stop = TRUE
				break
			var/list/after = actor.human_subtile_snapshot()
			if (after["z"] != expected["z"])
				cancelled = TRUE
				stop = TRUE
				break
			var/actual_x = (after["x"] - expected["x"]) * 32 + after["sx"] - expected["sx"]
			var/actual_y = (after["y"] - expected["y"]) * 32 + after["sy"] - expected["sy"]
			observations += list(list("at" = world.time, "due" = due, "engine_return" = P.engine_return, "dx" = actual_x, "dy" = actual_y, "x" = actor.x, "y" = actor.y, "sx" = actor.step_x, "sy" = actor.step_y))
			expected = after
			if (actor.human_subtile_save_request)
				actor.human_subtile_save_request.acknowledge(actor, src)
			if (total_distance > 0)
				actor.human_subtile_offset_owned = TRUE
			if (P.invalid || ((actual_x || actual_y) && (actual_x != dx || actual_y != dy)))
				stop = TRUE
				break
			if (actual_x == dx && actual_y == dy)
				moved_pulse = TRUE
				// A sideways slide does not shorten the step's own travel.
				if (direction & (EAST | WEST))
					remaining_x -= abs(actual_x)
				if (direction & (NORTH | SOUTH))
					remaining_y -= abs(actual_y)
				break
		if (stop || !moved_pulse)
			break
	wait_paid_interval()
	return total_distance > 0

/datum/human_subtile_transaction/proc/wait_paid_interval()
	if (paid_posture)
		// Restore visuals as soon as travel stops, but retain admission ownership
		// until the captured deadline, including a failed native call.
		if (actor && actor.human_subtile_transaction == src)
			actor.human_subtile_pulse = null
		release_visuals()
		while (world.time < end_time)
			sleep(world.tick_lag)

/datum/human_subtile_transaction/proc/complete()
	if (!completed && actor && !isDeleted(actor) && (total_distance > 0 || (paid_posture && attempted)))
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
	if (key == "human_subtile_pull_enabled")
		return TRUE
	// Tile-only persistence treats native sub-tile movement as transient.
	// Pixel offsets are unrelated artwork and continue through normal saving.
	if (key == "step_x" || key == "step_y") return TRUE
	if (key == "glide_size" && (human_subtile_glide_owned || human_subtile_import_owned || human_subtile_position))
		return TRUE
	return (key in list("human_subtile_save_aligned", "human_subtile_enabled", "human_subtile_default_pending", "human_subtile_transaction", "human_subtile_pulse", "human_subtile_save_request", "human_subtile_save_hook_frame", "human_subtile_import_owned", "human_direct_preflight_position", "human_subtile_offset_owned", "human_subtile_glide_owned", "human_subtile_previous_glide", "human_subtile_applied_glide", "human_subtile_visual_owner", "human_subtile_chain_start", "human_subtile_fine_released_at", "human_subtile_pull_trail", "human_subtile_pull_trail_for")) || ..()

// Entry ownership is decided BEFORE assignments, independent of field order.
/mob/living/human/proc/human_subtile_prepare_import(savefile/F)
	human_subtile_restore_schema = 0
	human_direct_preflight_position = null
	human_subtile_import_owned = ("human_subtile_position" in F.dir)
	if (!human_subtile_import_owned)
		human_subtile_position = null
		human_subtile_offset_owned = FALSE

/mob/living/human/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	if (!frame)
		return ..()
	if (!frame.human_spatial_request)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if (frame.human_legacy_aligned)
			var/datum/persistence_world_operation/operation = persistence_active_operation
			var/list/record = exporter ? exporter.human_save_roots[exporter.save_entry_identity(src)] : null
			if (human_subtile_save_hook_frame || frame.source != src || frame.exporter != exporter || !operation || !operation.current(exporter, "save") || !record || record["atom"] != src || record["mode"] != "legacy")
				throw EXCEPTION("Human legacy save hook lacks its frame owner")
			human_subtile_save_hook_frame = frame
			try
				. = ..()
			catch (var/exception/legacy_save_hook_error)
				human_subtile_save_hook_frame = null
				throw legacy_save_hook_error
			if (human_subtile_save_hook_frame != frame)
				human_subtile_save_hook_frame = null
				throw EXCEPTION("Human legacy save hook frame changed")
			human_subtile_save_hook_frame = null
			return .
#endif
		return ..()
	var/datum/human_subtile_save_request/request = frame.human_spatial_request
	if (human_subtile_save_hook_frame || frame.source != src || frame.exporter != exporter || request.actor != src || human_subtile_save_request != request || !request.captured || !request.operation || !request.operation.current(exporter, "save"))
		throw EXCEPTION("Human save hook lacks its captured frame owner")
	human_subtile_save_hook_frame = frame
	try
		. = ..()
	catch (var/exception/save_hook_error)
		human_subtile_save_hook_frame = null
		throw save_hook_error
	if (human_subtile_save_hook_frame != frame)
		human_subtile_save_hook_frame = null
		throw EXCEPTION("Human save hook frame changed during parent callbacks")
	human_subtile_save_hook_frame = null
	return .

/mob/living/human/before_save()
	. = ..()
	if (human_subtile_save_hook_frame)
		var/datum/save_export_frame/frame = human_subtile_save_hook_frame
		var/datum/human_subtile_save_request/request = frame.human_spatial_request
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if (frame.human_legacy_aligned)
			var/datum/persistence_world_operation/operation = persistence_active_operation
			var/list/record = frame.exporter ? frame.exporter.human_save_roots[frame.exporter.save_entry_identity(src)] : null
			if (!frame.active || frame.source != src || !operation || !operation.current(frame.exporter, "save") || !record || record["atom"] != src || record["mode"] != "legacy")
				throw EXCEPTION("Human legacy save hook owner changed")
			return .
#endif
		if (!frame.active || frame.source != src || !request || request.actor != src || human_subtile_save_request != request || !request.captured || !request.operation || !request.operation.current(frame.exporter, "save"))
			throw EXCEPTION("Human save hook owner changed")
		return .
	// Tile-only save: the body is written on the tile it occupies now, with no
	// movement offset, so a walking player is never stopped or cancelled here.
	// An unfinished step loads at the centre of its anchor tile, like a body
	// that was standing still. Offsets, transactions and pulses stay runtime.
	human_subtile_save_aligned = FALSE
	human_subtile_position = null

/mob/living/human/proc/human_subtile_destination_clear(list/S)
	for (var/tx = S["x"], tx <= S["x"] + (S["sx"] > 0), tx++)
		for (var/ty = S["y"], ty <= S["y"] + (S["sy"] > 0), ty++)
			var/turf/T = locate(tx, ty, S["z"])
			if (!T || T.density || T.vehicle_transforming)
				return FALSE
			for (var/atom/movable/A in T)
				// Bodies may overlap; only dense objects block a restore.
				if (A != src && !ismob(A) && !A.CanPass(src, T, 1.5, FALSE))
					return FALSE
	return TRUE

#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
// Run after the level's restored atoms have all received after_load().  The
// engine's bounds query includes overhangs from objects on neighbouring turfs.
// This is a local obstruction check, not a simultaneous-world snapshot.
/mob/living/human/proc/human_saved_tile_final_clear()
	if(!isturf(loc) || !human_subtile_unlinked() || pulling) return TRUE
	if(!human_subtile_shape()) return FALSE
	var/turf/T = loc
	if(T.density || T.vehicle_transforming) return FALSE
	var/list/nearby = obounds(src, 0)
	if(!islist(nearby) || nearby.len > 1024) return FALSE
	for(var/atom/A in nearby)
		if(!A || QDELETED(A) || A.gcDestroyed) continue
		if(isturf(A))
			var/turf/other_turf = A
			if(other_turf.density || other_turf.vehicle_transforming) return FALSE
		else if(isobj(A) && isturf(A.loc) && A.density)
			return FALSE
	return TRUE
#endif

/mob/living/human/after_load()
	. = ..()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	// Legacy capsules remain readable, but movement fractions are deliberately
	// not restored. Preserve the constructor's saved parent/relationship.
	if(human_subtile_restore_schema && (!isnum(human_subtile_restore_schema) || human_subtile_restore_schema != 1 || !human_subtile_import_owned))
		throw EXCEPTION("Unsupported human sub-tile restore schema")
	var/had_position = human_subtile_import_owned
	if(had_position)
		var/list/legacy_position = human_subtile_position
		if(!islist(legacy_position) || legacy_position.len != 5) throw EXCEPTION("Malformed sub-tile position capsule")
		for(var/key in list("x", "y", "z", "sx", "sy"))
			if(!(key in legacy_position) || !isnum(legacy_position[key]) || legacy_position[key] != round(legacy_position[key])) throw EXCEPTION("Malformed sub-tile position field")
		if(!human_subtile_shape() || !human_subtile_unlinked() || x != legacy_position["x"] || y != legacy_position["y"] || z != legacy_position["z"] || legacy_position["sx"] < 0 || legacy_position["sx"] >= 32 || legacy_position["sy"] < 0 || legacy_position["sy"] >= 32)
			throw EXCEPTION("Sub-tile anchor or destination rejected")
	if(human_subtile_transaction || human_subtile_pulse) throw EXCEPTION("Restored human has active movement ownership")
	step_x = 0
	step_y = 0
	human_subtile_position = null
	human_subtile_restore_schema = 0
	human_direct_preflight_position = null
	human_subtile_offset_owned = FALSE
	human_subtile_import_owned = FALSE
	if(had_position)
		living_movement_completed()
		human_movement_completed()
	return .
#else
	if(human_subtile_restore_schema && (!isnum(human_subtile_restore_schema) || human_subtile_restore_schema != 1 || !human_subtile_import_owned))
		throw EXCEPTION("Unsupported human sub-tile restore schema")
	if (!human_subtile_import_owned)
		return
	var/list/S = human_subtile_position
	if (!islist(S) || S.len != 5)
		throw EXCEPTION("Malformed sub-tile position capsule")
	for (var/key in list("x", "y", "z", "sx", "sy"))
		if (!(key in S) || !isnum(S[key]) || S[key] != round(S[key]))
			throw EXCEPTION("Malformed sub-tile position field")
	if (!human_subtile_shape() || !human_subtile_unlinked() || x != S["x"] || y != S["y"] || z != S["z"] || S["sx"] < 0 || S["sx"] >= 32 || S["sy"] < 0 || S["sy"] >= 32)
		throw EXCEPTION("Sub-tile anchor or destination rejected")
	if(human_subtile_restore_schema == 1)
		throw EXCEPTION("Human direct restore is unavailable")
	else
		if(!human_subtile_destination_clear(S)) throw EXCEPTION("Sub-tile anchor or destination rejected")
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
#endif
