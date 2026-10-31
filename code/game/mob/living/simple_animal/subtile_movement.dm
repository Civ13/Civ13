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
	var/npc_subtile_follow_enabled = FALSE
	var/tmp/datum/npc_subtile_follow/npc_subtile_follow
	var/npc_subtile_flee_enabled = FALSE
	var/tmp/datum/npc_subtile_flee/npc_subtile_flee
	var/npc_subtile_species_enabled = FALSE
	var/npc_subtile_pet_enabled = FALSE
	var/tmp/datum/npc_subtile_pet_walk/npc_subtile_pet_walk
	var/npc_subtile_recovery_enabled = FALSE
	var/tmp/datum/npc_subtile_recovery/npc_subtile_recovery
	var/tmp/datum/npc_subtile_pending_intent/npc_subtile_pending_intent
	var/tmp/datum/npc_subtile_wild_walk/npc_subtile_wild_walk
	// Experimental collision bridge; the normal 32x32 admission guard stays in force.
	var/tmp/npc_subtile_large_exit_enabled = FALSE
	var/tmp/datum/npc_subtile_large_frame/npc_subtile_large_frame

/mob/living/simple_animal/proc/npc_subtile_snapshot()
	return list("x" = x, "y" = y, "z" = z, "sx" = step_x, "sy" = step_y)

/mob/living/simple_animal/proc/npc_subtile_shape()
	return isturf(loc) && world.icon_size == 32 && bound_x == 0 && bound_y == 0 && bound_width == 32 && bound_height == 32 && isnum(step_x) && isnum(step_y) && step_x == round(step_x) && step_y == round(step_y) && step_x >= 0 && step_x < 32 && step_y >= 0 && step_y < 32

// Contact decisions keep their existing Life cadence. Do not use turf entry
// during an owned pulse as proof that either animal has finished arriving.
/mob/living/simple_animal/proc/npc_subtile_settled()
	return !src.npc_subtile_transaction && !src.npc_subtile_pulse && world.time >= src.npc_subtile_until && (!src.npc_subtile_offset_owned || !(src.step_x || src.step_y))

/mob/living/simple_animal/proc/npc_subtile_contact_settled(mob/living/simple_animal/other = null)
	return src.npc_subtile_settled() && (!other || other.npc_subtile_settled())

// Species with Life-based contact rolls request one observation opportunity
// after arrival. The roll itself stays in Life and is never queued or repeated.
/mob/living/simple_animal/proc/npc_subtile_wait_contact_tick()
	return FALSE

/mob/living/simple_animal/proc/npc_subtile_contact_tick()
	if (src.npc_subtile_wild_walk && src.npc_subtile_wild_walk.await_contact && src.npc_subtile_settled())
		src.npc_subtile_wild_walk.await_contact = FALSE

/mob/living/simple_animal/proc/npc_subtile_native_interval(lag)
	return lag * world.tick_lag

// Native walk(0) cancels a continuous walker, but not the step-based pursuit.
// Keep the same distinction for staged owners and their pending commands.
/mob/living/simple_animal/proc/npc_subtile_stop_continuous_walk()
	src.npc_subtile_stop_follow()
	src.npc_subtile_stop_flee()
	src.npc_subtile_stop_pet_walk()
	src.npc_subtile_stop_wild_walk()
	walk(src, 0)

/mob/living/simple_animal/proc/npc_subtile_authority_ready()
	return !client && !stat && canmove && !anchored && !lying && !prone && !resting && !paralysis && !stunned && !weakened && !sleeping && !(status_flags & FAKEDEATH) && !buckled && !restrained() && !pulling && !pulledby && !ride && !rider && !control_object && !incorporeal_move && (!grab_list || !grab_list.len) && (!grabbed_by || !grabbed_by.len) && (!pinned || !pinned.len)

/mob/living/simple_animal/proc/npc_subtile_ready()
	return npc_subtile_authority_ready() && npc_subtile_shape()

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

// A continuous AI owner excludes other producers between its pulse steps too.
/mob/living/simple_animal/proc/npc_subtile_intent_valid(datum/owner)
	if ((npc_subtile_pursuit && npc_subtile_pursuit != owner) || (npc_subtile_follow && npc_subtile_follow != owner) || (npc_subtile_flee && npc_subtile_flee != owner) || (npc_subtile_pet_walk && npc_subtile_pet_walk != owner) || (npc_subtile_recovery && npc_subtile_recovery != owner) || (npc_subtile_wild_walk && npc_subtile_wild_walk != owner))
		return FALSE
	return !owner || owner == npc_subtile_pursuit || owner == npc_subtile_follow || owner == npc_subtile_flee || owner == npc_subtile_pet_walk || owner == npc_subtile_recovery || owner == npc_subtile_wild_walk

// The AI chooses a destination ONCE and retains its existing sleep/throttle.
// Return first physical progress synchronously, then finish within that interval.
// No AI, path search, RNG, client FPS changes or queued intents inside the worker.
/mob/living/simple_animal/proc/ai_step(turf/destination, interval, pulse_only = FALSE, list/receipt = null, datum/intent_owner = null)
	if (npc_subtile_transaction || world.time < npc_subtile_until || !npc_subtile_intent_valid(intent_owner))
		return FALSE
	var/direction = get_dir(src, destination)
	if (!npc_subtile_enabled || !npc_subtile_ready() || !(direction in alldirs) || destination != get_step(src, direction) || !isnum(interval) || interval < world.tick_lag || interval > 100)
		if (pulse_only)
			return FALSE
		if (npc_subtile_offset_owned && (step_x || step_y))
			return FALSE
		return Move(destination, direction)
	if ((step_x || step_y) && !npc_subtile_offset_owned)
		if (pulse_only)
			return FALSE
		return Move(destination, direction)
	var/datum/npc_subtile_transaction/T = new
	T.actor = src
	T.intent_owner = intent_owner
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
	// Capture this admission before Move callbacks can change actor ownership.
	if (!isnull(receipt))
		receipt["transaction"] = T
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

// For future AI paths that must distinguish initial progress from arrival.
// No legacy Move fallback is allowed: it would not have a pulse receipt.
/mob/living/simple_animal/proc/ai_step_wait(turf/destination, interval, datum/intent_owner = null)
	var/list/receipt = list()
	if (!ai_step(destination, interval, TRUE, receipt, intent_owner))
		return FALSE
	var/datum/npc_subtile_transaction/T = receipt["transaction"]
	if (!T)
		return FALSE
	return T.wait_for_completion()

// Reacquire the grid only through paid native pulses. No teleport, snap or
// unowned legacy Move is allowed, even if both alignment directions are blocked.
/mob/living/simple_animal/proc/npc_subtile_settle_axis(datum/owner, interval_base)
	if (!npc_subtile_intent_valid(owner) || !npc_subtile_ready() || !npc_subtile_offset_owned || !(step_x || step_y))
		return FALSE
	if (npc_subtile_transaction || world.time < npc_subtile_until)
		sleep(max(world.tick_lag, npc_subtile_until - world.time))
		return FALSE
	var/direction
	var/distance
	if (step_x)
		direction = step_x <= 16 ? WEST : EAST
		distance = step_x <= 16 ? step_x : 32 - step_x
	else
		direction = step_y <= 16 ? SOUTH : NORTH
		distance = step_y <= 16 ? step_y : 32 - step_y
	var/interval = max(world.tick_lag, interval_base * distance / 32)
	var/started = world.time
	var/list/before = npc_subtile_snapshot()
	var/generation = move_gen
	var/atom/path_target = target_obj
	var/mob/living/combat_target = target_mob
	var/atom/following = following_mob
	var/old_stance = stance
	var/arrived = ai_step_wait(get_step(src, direction), interval, owner)
	if (!arrived && npc_subtile_intent_valid(owner) && npc_subtile_ready() && move_gen == generation && target_obj == path_target && target_mob == combat_target && following_mob == following && stance == old_stance && world.time == started && !npc_subtile_transaction && world.time >= npc_subtile_until && human_subtile_same(before, npc_subtile_snapshot()))
		var/other_interval = max(world.tick_lag, interval_base * (32 - distance) / 32)
		arrived = ai_step_wait(get_step(src, turn(direction, 180)), other_interval, owner)
	if (npc_subtile_intent_valid(owner) && world.time == started)
		sleep(max(world.tick_lag, interval_base))
	return arrived

/mob/living/simple_animal/proc/npc_subtile_request_recovery()
	if (!npc_subtile_recovery_enabled || !npc_subtile_enabled || !npc_subtile_ready() || !npc_subtile_offset_owned || !(step_x || step_y) || npc_subtile_transaction || world.time < npc_subtile_until || !npc_subtile_intent_valid(null))
		return FALSE
	npc_subtile_prune_pending()
	walk(src, 0)
	walk_id = 0
	if (moving)
		moving = FALSE
		found_path = list()
		target_obj = null
	var/previous_generation = move_gen
	move_gen++
	if (npc_subtile_pending_intent && npc_subtile_pending_intent.generation == previous_generation)
		npc_subtile_pending_intent.generation = move_gen
	var/datum/npc_subtile_recovery/R = new
	R.actor = src
	R.generation = move_gen
	R.expected_stance = stance
	R.expected_combat_target = target_mob
	R.expected_path_target = target_obj
	R.expected_following = following_mob
	npc_subtile_recovery = R
	spawn(0)
		R.perform()
	return TRUE

// At most one command may wait for recovery. A newer valid command replaces
// it; explicit stop, ownership generation changes and changed AI state revoke it.
/mob/living/simple_animal/proc/npc_subtile_defer_intent(kind, atom/target, mode = null, distance_limit = null, interval = null, side_direction = 0, blocked_wild_owner = FALSE)
	if (!(npc_subtile_can_defer() || (blocked_wild_owner && kind == "wild" && npc_subtile_wild_walk && npc_subtile_recovery_enabled && npc_subtile_offset_owned && (step_x || step_y))) || !npc_subtile_enabled || (!target && !(kind == "wild" && (mode == "random" || mode == "direction"))))
		return FALSE
	var/datum/npc_subtile_pending_intent/P = new
	P.actor = src
	P.target = target
	P.kind = kind
	P.mode = mode
	P.distance_limit = distance_limit
	P.interval = interval
	P.side_direction = side_direction
	if (kind == "pursuit" && side_direction)
		P.side_origin = get_turf(src)
		P.side_target = get_turf(target)
	P.generation = move_gen
	P.expected_stance = stance
	P.expected_behaviour = behaviour
	P.expected_combat_target = target_mob
	P.expected_following = following_mob
	if (kind == "flee")
		P.expires_at = world.time + 50
	var/datum/npc_subtile_pending_intent/previous = npc_subtile_pending_intent
	npc_subtile_pending_intent = P
	if (!P.valid())
		npc_subtile_pending_intent = previous
		npc_subtile_prune_pending()
		return FALSE
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_can_defer()
	return npc_subtile_recovery || (npc_subtile_recovery_enabled && npc_subtile_offset_owned && (step_x || step_y) && !npc_subtile_ready() && !client && !stat)

// A matching explicit stop clears its pending kind first. Other still-valid
// commands may transfer when the previous movement generation is released.
/mob/living/simple_animal/proc/npc_subtile_release_generation(generation, transfer_pending)
	if (move_gen != generation)
		return FALSE
	if (transfer_pending)
		npc_subtile_prune_pending()
	move_gen++
	if (transfer_pending && npc_subtile_pending_intent && npc_subtile_pending_intent.generation == generation)
		npc_subtile_pending_intent.generation = move_gen
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_cancel_pending(kind)
	if (npc_subtile_pending_intent && npc_subtile_pending_intent.kind == kind)
		npc_subtile_pending_intent = null

/mob/living/simple_animal/proc/npc_subtile_prune_pending()
	if (npc_subtile_pending_intent && !npc_subtile_pending_intent.valid())
		npc_subtile_pending_intent = null

// Pulse-time invalidation deliberately avoids view and target searches.
/mob/living/simple_animal/proc/npc_subtile_prune_pending_fast()
	if (npc_subtile_pending_intent && !npc_subtile_pending_intent.base_valid())
		npc_subtile_pending_intent = null

/mob/living/simple_animal/proc/npc_subtile_dispatch_pending()
	npc_subtile_prune_pending()
	var/datum/npc_subtile_pending_intent/P = npc_subtile_pending_intent
	if (!P || npc_subtile_recovery || npc_subtile_transaction || world.time < npc_subtile_until || !npc_subtile_ready() || (npc_subtile_offset_owned && (step_x || step_y)) || !npc_subtile_intent_valid(null))
		return FALSE
	// Consume before dispatch so stop/replacement callbacks cannot replay it twice.
	npc_subtile_pending_intent = null
	switch (P.kind)
		if ("pursuit")
			return npc_subtile_start_pursuit(P.target, P.side_direction)
		if ("follow")
			return npc_subtile_start_follow(P.target)
		if ("flee")
			return npc_subtile_start_flee(P.target, P.distance_limit, P.interval)
		if ("pet")
			var/mob/living/simple_animal/pet/pet = src
			return pet.npc_subtile_start_pet_walk(P.target, P.mode, P.distance_limit, P.interval)
		if ("wild")
			return npc_subtile_start_wild_walk(P.mode, P.target, P.interval, P.side_direction, P.distance_limit)
	return FALSE

/datum/npc_subtile_pending_intent
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/atom/target
	var/kind
	var/mode
	var/distance_limit
	var/interval
	var/side_direction = 0
	var/turf/side_origin
	var/turf/side_target
	var/generation
	var/expected_stance
	var/expected_behaviour
	var/mob/living/expected_combat_target
	var/atom/expected_following
	var/expires_at = 0

/datum/npc_subtile_pending_intent/proc/base_valid()
	if (!actor || isDeleted(actor) || actor.npc_subtile_pending_intent != src || !actor.npc_subtile_recovery_enabled || !actor.npc_subtile_enabled || actor.client || actor.stat || actor.move_gen != generation || actor.stance != expected_stance || actor.behaviour != expected_behaviour || actor.target_mob != expected_combat_target || actor.following_mob != expected_following || (!target && !(kind == "wild" && (mode == "random" || mode == "direction"))) || (target && isDeleted(target)))
		return FALSE
	return !expires_at || world.time < expires_at

/datum/npc_subtile_pending_intent/proc/valid()
	if (!base_valid())
		return FALSE
	if (kind == "wild" && (mode == "random" || mode == "direction"))
		return actor.npc_subtile_species_enabled && isnum(interval) && interval >= world.tick_lag && interval <= 100 && (mode == "random" || (side_direction in alldirs))
	var/turf/target_turf = get_turf(target)
	if (!target_turf || actor.z != target_turf.z)
		return FALSE
	// Recovery may cross a turf boundary after the AI chose a side-step.
	// Drop that stale direction while retaining the still-valid pursuit request.
	if (kind == "pursuit" && side_direction && (!(side_direction in alldirs) || get_turf(actor) != side_origin || target_turf != side_target))
		side_direction = 0
		side_origin = null
		side_target = null
	switch (kind)
		if ("pursuit")
			return actor.npc_subtile_pursuit_enabled && (!side_direction || ((side_direction in alldirs) && get_turf(actor) == side_origin && target_turf == side_target)) && actor.target_mob == target && actor.SA_attackable(target) && ((target in view(actor.aggro_vision_range, actor)) || (target in view(actor.idle_vision_range, actor)))
		if ("follow")
			return actor.npc_subtile_follow_enabled && actor.following_mob == target && get_dist(actor, target) <= 6
		if ("flee")
			return actor.npc_subtile_flee_enabled && isnum(distance_limit) && distance_limit >= 0 && isnum(interval) && interval >= world.tick_lag && interval <= 100 && world.time < expires_at && get_dist(actor, target) <= distance_limit
		if ("pet")
			if (!actor.npc_subtile_pet_enabled || !istype(actor, /mob/living/simple_animal/pet) || !(mode in list("towards", "away")) || !isnum(distance_limit) || distance_limit < 0 || !isnum(interval) || interval < world.tick_lag || interval > 100)
				return FALSE
			var/mob/living/simple_animal/pet/pet = actor
			return (mode == "towards" && pet.movement_target == target) || (mode == "away" && pet.flee_target == target && get_dist(actor, target) <= distance_limit)
		if ("wild")
			return actor.npc_subtile_species_enabled && (mode == "towards" || mode == "away" || mode == "path") && isnum(interval) && interval >= world.tick_lag && interval <= 100 && (!(mode in list("away", "path")) || (isnum(distance_limit) && distance_limit >= 0))
	return FALSE

// Species producers retain their native commands until explicitly opted in.
/mob/living/simple_animal/proc/npc_subtile_species_walk(mode, atom/target = null, lag = 0, direction = 0, distance_limit = 0)
	if (!npc_subtile_species_enabled)
		switch (mode)
			if ("random")
				walk_rand(src, lag)
			if ("towards")
				walk_towards(src, target, lag)
			if ("away")
				walk_away_od(src, target, distance_limit, lag)
			if ("path")
				walk_to(src, target, distance_limit, lag)
			if ("direction")
				walk(src, 0)
				walk(src, direction, lag)
		return
	// Native walker lag counts world ticks; world.time and sleep use deciseconds.
	return npc_subtile_start_wild_walk(mode, target, npc_subtile_native_interval(lag), direction, distance_limit)

/mob/living/simple_animal/proc/npc_subtile_start_wild_walk(mode, atom/target, interval, direction, distance_limit)
	if (!(mode in list("random", "towards", "away", "path", "direction")) || !isnum(interval) || interval < world.tick_lag || interval > 100 || (mode == "direction" && !(direction in alldirs)) || ((mode == "away" || mode == "path") && (!isnum(distance_limit) || distance_limit < 0)))
		return FALSE
	if (mode == "towards" || mode == "away" || mode == "path")
		var/turf/destination = get_turf(target)
		if (!target || isDeleted(target) || !destination || z != destination.z)
			return FALSE
	if (!npc_subtile_species_enabled || !npc_subtile_enabled)
		return FALSE
	if (npc_subtile_can_defer())
		return npc_subtile_defer_intent("wild", target, mode, distance_limit, interval, direction)
	if (!npc_subtile_ready())
		return FALSE
	npc_subtile_pending_intent = null
	npc_subtile_stop_follow()
	npc_subtile_stop_flee()
	npc_subtile_stop_pet_walk()
	npc_subtile_stop_pursuit()
	walk(src, 0)
	walk_id = 0
	if (moving)
		moving = FALSE
		target_obj = null
		found_path = list()
	var/datum/npc_subtile_wild_walk/W = npc_subtile_wild_walk
	var/new_owner = !W
	if (new_owner)
		W = new
		W.actor = src
		npc_subtile_wild_walk = W
	move_gen++
	W.generation = move_gen
	W.revision++
	W.target = target
	W.mode = mode
	W.interval = interval
	W.direction = direction
	W.distance_limit = distance_limit
	W.due = world.time + interval
	W.expected_stance = stance
	W.expected_behaviour = behaviour
	W.expected_combat_target = target_mob
	W.expected_path_target = target_obj
	W.expected_following = following_mob
	if (new_owner)
		spawn(0)
			W.perform()
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_stop_wild_walk(cancel_pending = TRUE)
	if (cancel_pending)
		npc_subtile_cancel_pending("wild")
	var/datum/npc_subtile_wild_walk/W = npc_subtile_wild_walk
	if (!W)
		return
	W.cancelled = TRUE
	npc_subtile_wild_walk = null
	npc_subtile_release_generation(W.generation, TRUE)

/datum/npc_subtile_wild_walk
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/atom/target
	var/mode
	var/interval
	var/direction
	var/distance_limit
	var/due
	var/revision = 0
	var/generation
	var/expected_stance
	var/expected_behaviour
	var/await_contact = FALSE
	var/mob/living/expected_combat_target
	var/atom/expected_path_target
	var/atom/expected_following
	var/cancelled = FALSE

/datum/npc_subtile_wild_walk/proc/semantic_valid()
	if (cancelled || !actor || isDeleted(actor) || actor.npc_subtile_wild_walk != src || !actor.npc_subtile_species_enabled || !actor.npc_subtile_enabled || !actor.npc_subtile_intent_valid(src) || actor.move_gen != generation || actor.stance != expected_stance || actor.behaviour != expected_behaviour || actor.target_mob != expected_combat_target || actor.target_obj != expected_path_target || actor.following_mob != expected_following)
		return FALSE
	if (mode == "towards" || mode == "away" || mode == "path")
		var/turf/destination = get_turf(target)
		return target && !isDeleted(target) && destination && actor.z == destination.z
	return mode == "random" || mode == "direction"

/datum/npc_subtile_wild_walk/proc/valid()
	return semantic_valid() && actor.npc_subtile_ready()

/datum/npc_subtile_wild_walk/proc/perform()
	try
		perform_loop()
	catch (var/exception/wild_error)
		finish()
		throw wild_error
	finish()

/datum/npc_subtile_wild_walk/proc/finish()
	if (actor && !isDeleted(actor) && actor.npc_subtile_wild_walk == src)
		if (semantic_valid() && !actor.npc_subtile_ready() && actor.npc_subtile_can_defer() && !actor.npc_subtile_pending_intent)
			actor.npc_subtile_defer_intent("wild", target, mode, distance_limit, interval, direction)
		actor.npc_subtile_stop_wild_walk(FALSE)
	actor = null
	target = null
	expected_combat_target = null
	expected_path_target = null
	expected_following = null

/datum/npc_subtile_wild_walk/proc/perform_loop()
	while (valid())
		if (await_contact)
			sleep(world.tick_lag)
			continue
		if (world.time < due || actor.npc_subtile_transaction || world.time < actor.npc_subtile_until)
			sleep(world.tick_lag)
			continue
		var/current_revision = revision
		if (actor.npc_subtile_offset_owned && (actor.step_x || actor.step_y))
			var/list/before = actor.npc_subtile_snapshot()
			actor.npc_subtile_settle_axis(src, interval)
			if (valid() && actor.npc_subtile_settled() && actor.npc_subtile_wait_contact_tick())
				await_contact = TRUE
			if (valid() && revision == current_revision && human_subtile_same(before, actor.npc_subtile_snapshot()))
				actor.npc_subtile_defer_intent("wild", target, mode, distance_limit, interval, direction, TRUE)
				break
			continue
		var/started = world.time
		var/turf/next
		switch (mode)
			if ("random")
				next = get_step_rand(actor)
			if ("towards")
				next = get_step_towards(actor, target)
			if ("away")
				next = get_step_away(actor, target, distance_limit)
			if ("path")
				next = get_step_to(actor, target, distance_limit)
			if ("direction")
				next = get_step(actor, direction)
		if (next && valid())
			var/arrived = actor.ai_step_wait(next, interval, src)
			if (arrived && valid() && actor.npc_subtile_settled() && actor.npc_subtile_wait_contact_tick())
				await_contact = TRUE
		if (valid() && revision == current_revision)
			due = max(started + interval, world.time)

/datum/npc_subtile_recovery
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/generation
	var/expected_stance
	var/mob/living/expected_combat_target
	var/atom/expected_path_target
	var/atom/expected_following

/datum/npc_subtile_recovery/proc/valid()
	return actor && !isDeleted(actor) && actor.npc_subtile_recovery == src && actor.npc_subtile_recovery_enabled && actor.npc_subtile_enabled && actor.npc_subtile_ready() && actor.npc_subtile_intent_valid(src) && actor.move_gen == generation && actor.stance == expected_stance && actor.target_mob == expected_combat_target && actor.target_obj == expected_path_target && actor.following_mob == expected_following

/datum/npc_subtile_recovery/proc/perform()
	try
		while (valid() && actor.npc_subtile_offset_owned && (actor.step_x || actor.step_y))
			actor.npc_subtile_prune_pending()
			var/list/before = actor.npc_subtile_snapshot()
			actor.npc_subtile_settle_axis(src, actor.move_to_delay)
			// One blocked attempt tries both alignment directions; relinquish so
			// the next Life tick may retry without suppressing unrelated AI.
			if (valid() && human_subtile_same(before, actor.npc_subtile_snapshot()))
				break
	catch (var/exception/npc_recovery_error)
		finish()
		throw npc_recovery_error
	finish()

/datum/npc_subtile_recovery/proc/finish()
	if (actor && !isDeleted(actor) && actor.npc_subtile_recovery == src)
		// Keep a still-valid command across temporary physical ineligibility,
		// but never transfer it after another owner changed the generation.
		if (actor.move_gen == generation && actor.npc_subtile_intent_valid(src))
			actor.npc_subtile_prune_pending()
		else
			actor.npc_subtile_pending_intent = null
		actor.npc_subtile_recovery = null
		if (actor.move_gen == generation)
			actor.move_gen++
			if (actor.npc_subtile_pending_intent && actor.npc_subtile_pending_intent.generation == generation)
				actor.npc_subtile_pending_intent.generation = actor.move_gen
		actor.npc_subtile_dispatch_pending()
	actor = null
	expected_combat_target = null
	expected_path_target = null
	expected_following = null

// A staged leash-follow owner. The durable following_mob link is never owned
// by this worker. A combat pursuit has precedence over its movement intent.
/mob/living/simple_animal/proc/npc_subtile_start_follow(atom/target)
	if (npc_subtile_can_defer())
		return npc_subtile_defer_intent("follow", target)
	if (!npc_subtile_follow_enabled || !npc_subtile_enabled || !npc_subtile_ready() || npc_subtile_pursuit || npc_subtile_flee || !target || following_mob != target)
		return FALSE
	var/turf/target_turf = get_turf(target)
	if (!target_turf || z != target_turf.z || get_dist(src, target) > 6)
		return FALSE
	npc_subtile_pending_intent = null
	if (npc_subtile_follow && npc_subtile_follow.target == target && npc_subtile_follow.valid())
		return TRUE
	npc_subtile_stop_follow()
	npc_subtile_stop_wild_walk()
	npc_subtile_stop_pet_walk()
	walk(src, 0)
	walk_id = 0
	if (moving)
		moving = FALSE
		target_obj = null
		found_path = list()
	move_gen++
	var/datum/npc_subtile_follow/F = new
	F.actor = src
	F.target = target
	F.generation = move_gen
	F.expected_stance = stance
	F.expected_combat_target = target_mob
	F.expected_path_target = target_obj
	npc_subtile_follow = F
	spawn(0)
		F.perform()
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_stop_follow(cancel_pending = TRUE)
	if (cancel_pending)
		npc_subtile_cancel_pending("follow")
	var/datum/npc_subtile_follow/F = npc_subtile_follow
	if (!F)
		return
	F.cancelled = TRUE
	npc_subtile_follow = null
	if (move_gen == F.generation)
		npc_subtile_release_generation(F.generation, TRUE)

/datum/npc_subtile_follow
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/atom/target
	var/generation
	var/expected_stance
	var/mob/living/expected_combat_target
	var/atom/expected_path_target
	var/cancelled = FALSE

/datum/npc_subtile_follow/proc/valid()
	if (cancelled || !actor || isDeleted(actor) || actor.npc_subtile_follow != src || !actor.npc_subtile_follow_enabled || !actor.npc_subtile_enabled || !actor.npc_subtile_ready() || actor.npc_subtile_pursuit || actor.npc_subtile_flee || actor.npc_subtile_pet_walk || actor.move_gen != generation || !target || isDeleted(target) || actor.following_mob != target || actor.stance != expected_stance || actor.target_mob != expected_combat_target || actor.target_obj != expected_path_target)
		return FALSE
	var/turf/destination = get_turf(target)
	return destination && actor.z == destination.z && get_dist(actor, target) <= 6

/datum/npc_subtile_follow/proc/perform()
	try
		perform_loop()
	catch (var/exception/npc_follow_error)
		finish()
		throw npc_follow_error
	finish()

/datum/npc_subtile_follow/proc/finish()
	if (actor && !isDeleted(actor) && actor.npc_subtile_follow == src)
		actor.npc_subtile_stop_follow(FALSE)
	actor = null
	target = null

/datum/npc_subtile_follow/proc/perform_loop()
	while (valid())
		var/interval = actor.npc_subtile_native_interval(6)
		if (get_dist(actor, target) <= 1 && actor.npc_subtile_offset_owned && (actor.step_x || actor.step_y))
			actor.npc_subtile_settle_axis(src, interval)
			break
		var/started = world.time
		var/deadline = started + interval
		if (get_dist(actor, target) > 1)
			var/turf/next = get_step_to(actor, target, 1)
			if (next && valid())
				actor.ai_step_wait(next, interval, src)
		if (valid() && world.time < deadline)
			sleep(deadline - world.time)
		else if (valid() && world.time == started)
			sleep(0)

// The scared behavior's timed native walk owns neither the leash nor pursuit.
// The producer still owns its existing 50 ds stop callback.
/mob/living/simple_animal/proc/npc_subtile_start_flee(atom/target, max_distance, interval)
	if (npc_subtile_can_defer())
		return npc_subtile_defer_intent("flee", target, null, max_distance, interval)
	if (!npc_subtile_flee_enabled || !npc_subtile_enabled || !npc_subtile_ready() || !target || !isnum(max_distance) || max_distance < 0 || !isnum(interval) || interval < world.tick_lag || interval > 100)
		return FALSE
	var/turf/target_turf = get_turf(target)
	if (!target_turf || z != target_turf.z || get_dist(src, target) > max_distance)
		return FALSE
	npc_subtile_pending_intent = null
	if (npc_subtile_flee && npc_subtile_flee.target == target && npc_subtile_flee.max_distance == max_distance && npc_subtile_flee.interval == interval && npc_subtile_flee.valid())
		return TRUE
	npc_subtile_stop_flee()
	npc_subtile_stop_follow()
	npc_subtile_stop_pursuit()
	npc_subtile_stop_pet_walk()
	npc_subtile_stop_wild_walk()
	walk(src, 0)
	walk_id = 0
	if (moving)
		moving = FALSE
		target_obj = null
		found_path = list()
	move_gen++
	var/datum/npc_subtile_flee/F = new
	F.actor = src
	F.target = target
	F.max_distance = max_distance
	F.interval = interval
	F.generation = move_gen
	F.expected_stance = stance
	F.expected_combat_target = target_mob
	F.expected_path_target = target_obj
	F.expected_following = following_mob
	npc_subtile_flee = F
	spawn(0)
		F.perform()
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_stop_flee(cancel_pending = TRUE)
	if (cancel_pending)
		npc_subtile_cancel_pending("flee")
	var/datum/npc_subtile_flee/F = npc_subtile_flee
	if (!F)
		return
	F.cancelled = TRUE
	npc_subtile_flee = null
	if (move_gen == F.generation)
		npc_subtile_release_generation(F.generation, TRUE)

/datum/npc_subtile_flee
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/atom/target
	var/max_distance
	var/interval
	var/generation
	var/expected_stance
	var/mob/living/expected_combat_target
	var/atom/expected_path_target
	var/atom/expected_following
	var/cancelled = FALSE

/datum/npc_subtile_flee/proc/valid()
	if (cancelled || !actor || isDeleted(actor) || actor.npc_subtile_flee != src || !actor.npc_subtile_flee_enabled || !actor.npc_subtile_enabled || !actor.npc_subtile_ready() || actor.npc_subtile_pursuit || actor.npc_subtile_follow || actor.npc_subtile_pet_walk || actor.move_gen != generation || !target || isDeleted(target) || actor.stance != expected_stance || actor.target_mob != expected_combat_target || actor.target_obj != expected_path_target || actor.following_mob != expected_following)
		return FALSE
	var/turf/destination = get_turf(target)
	return destination && actor.z == destination.z && get_dist(actor, target) <= max_distance

/datum/npc_subtile_flee/proc/perform()
	try
		perform_loop()
	catch (var/exception/npc_flee_error)
		finish()
		throw npc_flee_error
	finish()

/datum/npc_subtile_flee/proc/finish()
	if (actor && !isDeleted(actor) && actor.npc_subtile_flee == src)
		actor.npc_subtile_stop_flee(FALSE)
	actor = null
	target = null

/datum/npc_subtile_flee/proc/perform_loop()
	while (valid())
		var/started = world.time
		var/deadline = started + interval
		var/turf/next = get_step_away(actor, target, max_distance)
		if (next && valid())
			actor.ai_step_wait(next, interval, src)
		if (valid() && world.time < deadline)
			sleep(deadline - world.time)
		else if (valid() && world.time == started)
			sleep(0)

// Pet-specific continuous walk. The scan and target selection stay in pet AI.
/mob/living/simple_animal/pet/proc/npc_subtile_start_pet_walk(atom/target, mode, distance_limit, interval)
	if (npc_subtile_can_defer())
		return npc_subtile_defer_intent("pet", target, mode, distance_limit, interval)
	if (!npc_subtile_pet_enabled || !npc_subtile_enabled || !npc_subtile_ready() || !target || !(mode in list("towards", "away")) || !isnum(distance_limit) || distance_limit < 0 || !isnum(interval) || interval < world.tick_lag || interval > 100)
		return FALSE
	if ((mode == "towards" && movement_target != target) || (mode == "away" && flee_target != target))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if (!target_turf || z != target_turf.z || (mode == "away" && get_dist(src, target) > distance_limit))
		return FALSE
	npc_subtile_pending_intent = null
	if (npc_subtile_pet_walk && npc_subtile_pet_walk.target == target && npc_subtile_pet_walk.mode == mode && npc_subtile_pet_walk.distance_limit == distance_limit && npc_subtile_pet_walk.interval == interval && npc_subtile_pet_walk.valid())
		return TRUE
	npc_subtile_stop_pet_walk()
	npc_subtile_stop_follow()
	npc_subtile_stop_flee()
	npc_subtile_stop_pursuit()
	npc_subtile_stop_wild_walk()
	walk(src, 0)
	walk_id = 0
	if (moving)
		moving = FALSE
		target_obj = null
		found_path = list()
	move_gen++
	var/datum/npc_subtile_pet_walk/P = new
	P.actor = src
	P.target = target
	P.mode = mode
	P.distance_limit = distance_limit
	P.interval = interval
	P.generation = move_gen
	P.expected_stance = stance
	P.expected_combat_target = target_mob
	P.expected_path_target = target_obj
	P.expected_following = following_mob
	npc_subtile_pet_walk = P
	spawn(0)
		P.perform()
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_stop_pet_walk(cancel_pending = TRUE)
	if (cancel_pending)
		npc_subtile_cancel_pending("pet")
	var/datum/npc_subtile_pet_walk/P = npc_subtile_pet_walk
	if (!P)
		return
	P.cancelled = TRUE
	npc_subtile_pet_walk = null
	if (move_gen == P.generation)
		npc_subtile_release_generation(P.generation, TRUE)

/datum/npc_subtile_pet_walk
	should_save = FALSE
	var/mob/living/simple_animal/pet/actor
	var/atom/target
	var/mode
	var/distance_limit
	var/interval
	var/generation
	var/expected_stance
	var/mob/living/expected_combat_target
	var/atom/expected_path_target
	var/atom/expected_following
	var/cancelled = FALSE

/datum/npc_subtile_pet_walk/proc/valid()
	if (cancelled || !actor || isDeleted(actor) || actor.npc_subtile_pet_walk != src || !actor.npc_subtile_pet_enabled || !actor.npc_subtile_enabled || !actor.npc_subtile_ready() || actor.npc_subtile_pursuit || actor.npc_subtile_follow || actor.npc_subtile_flee || actor.move_gen != generation || !target || isDeleted(target) || actor.stance != expected_stance || actor.target_mob != expected_combat_target || actor.target_obj != expected_path_target || actor.following_mob != expected_following)
		return FALSE
	if ((mode == "towards" && actor.movement_target != target) || (mode == "away" && actor.flee_target != target))
		return FALSE
	var/turf/destination = get_turf(target)
	return destination && actor.z == destination.z && (mode != "away" || get_dist(actor, target) <= distance_limit)

/datum/npc_subtile_pet_walk/proc/perform()
	try
		perform_loop()
	catch (var/exception/npc_pet_walk_error)
		finish()
		throw npc_pet_walk_error
	finish()

/datum/npc_subtile_pet_walk/proc/finish()
	if (actor && !isDeleted(actor) && actor.npc_subtile_pet_walk == src)
		actor.npc_subtile_stop_pet_walk(FALSE)
	actor = null
	target = null

/datum/npc_subtile_pet_walk/proc/perform_loop()
	while (valid())
		if (mode == "towards" && get_dist(actor, target) <= distance_limit && actor.npc_subtile_offset_owned && (actor.step_x || actor.step_y))
			actor.npc_subtile_settle_axis(src, interval)
			break
		var/started = world.time
		var/deadline = started + interval
		var/turf/next
		if (mode == "towards" && get_dist(actor, target) > distance_limit)
			next = get_step_to(actor, target, distance_limit)
		else if (mode == "away")
			next = get_step_away(actor, target, distance_limit)
		if (next && valid())
			actor.ai_step_wait(next, interval, src)
		if (valid() && world.time < deadline)
			sleep(deadline - world.time)
		else if (valid() && world.time == started)
			sleep(0)

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

// Exists only across a consumed, native large-animal Move. Never saved.
// Cardinal 2px pulses over a 96px footprint cannot enter and leave a tile
// column in the same pulse. Keep diagonals and direction changes unsupported.
/datum/npc_subtile_large_frame
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/datum/npc_subtile_pulse/pulse
	var/datum/npc_subtile_transaction/transaction
	var/list/start
	var/turf/destination
	var/direction
	var/sx
	var/sy
	var/generation
	var/datum/intent_owner
	var/deadline
	var/enabled
	var/bx
	var/by
	var/width
	var/height
	var/facing
	var/atom/path_target
	var/mob/living/combat_target
	var/mob/living/following
	var/stance
	var/active = TRUE
	var/checking = FALSE
	// Native Move can consume a callback exception. Preserve its first fault so
	// the outer DM Move boundary can propagate it after the frame is closed.
	var/faulted = FALSE
	var/exception/fault

/datum/npc_subtile_large_frame/proc/valid()
	return active && actor && !isDeleted(actor) && !actor.gc_destroyed && actor.npc_subtile_authority_ready() && !persistence_save_in_progress && actor.npc_subtile_large_exit_enabled && actor.npc_subtile_enabled == enabled && actor.npc_subtile_large_frame == src && actor.npc_subtile_pulse == pulse && actor.npc_subtile_transaction == transaction && transaction && !isDeleted(transaction) && !transaction.gc_destroyed && !transaction.cancelled && !transaction.finished && transaction.actor == actor && transaction.generation == generation && transaction.end_time == deadline && isnum(deadline) && world.time <= deadline + world.tick_lag && transaction.intent_owner == intent_owner && (!intent_owner || (!isDeleted(intent_owner) && !intent_owner.gc_destroyed)) && actor.npc_subtile_intent_valid(intent_owner) && human_subtile_same(start, transaction.expected) && pulse && !isDeleted(pulse) && !pulse.gc_destroyed && !pulse.armed && !pulse.restoring && pulse.actor == actor && pulse.destination == destination && pulse.direction == direction && pulse.sx == sx && pulse.sy == sy && human_subtile_same(start, pulse.before) && actor.move_gen == generation && actor.target_obj == path_target && actor.target_mob == combat_target && actor.following_mob == following && actor.stance == stance && actor.bound_x == bx && actor.bound_y == by && actor.bound_width == width && actor.bound_height == height && actor.dir == facing && human_subtile_same(start, actor.npc_subtile_snapshot())

/datum/npc_subtile_large_frame/proc/check_exit(obj/obstacle)
	if (faulted || !valid() || checking)
		return FALSE
	if (!(obstacle.flags & ON_BORDER) || obstacle == actor)
		return TRUE
	// Every real callback checks current policy; recursive entry fails closed.
	checking = TRUE
	var/allowed = FALSE
	try
		allowed = obstacle.CheckExit(actor, destination, direction)
	catch (var/exception/large_exit_error)
		if (!faulted)
			faulted = TRUE
			fault = large_exit_error
		checking = FALSE
		throw large_exit_error
	checking = FALSE
	if (!allowed || !obstacle || isDeleted(obstacle) || obstacle.gc_destroyed || !valid())
		return FALSE
	return TRUE

/mob/living/simple_animal/proc/npc_subtile_begin_large_frame(datum/npc_subtile_pulse/P)
	if (!npc_subtile_large_exit_enabled || npc_subtile_large_frame || !P || P.armed || P.restoring || P.actor != src || P != npc_subtile_pulse || !npc_subtile_transaction || client || !isturf(loc) || world.icon_size != 32 || !(P.direction in list(NORTH, SOUTH, EAST, WEST)) || dir != P.direction || bound_y != 0 || !(bound_x in list(0, 64)) || bound_width != 96 || bound_height != 96 || !(istype(src, /mob/living/simple_animal/hostile/mammoth) || istype(src, /mob/living/simple_animal/hostile/dinosaur/trex)) || !human_subtile_same(P.before, npc_subtile_snapshot()))
		return null
	if (!P.destination || P.destination.z != z || !isnum(P.sx) || !isnum(P.sy) || P.sx != round(P.sx) || P.sy != round(P.sy) || P.sx < 0 || P.sx >= 32 || P.sy < 0 || P.sy >= 32)
		return null
	var/dx = (P.destination.x - x) * 32 + P.sx - step_x
	var/dy = (P.destination.y - y) * 32 + P.sy - step_y
	if ((P.direction == EAST && !(dx > 0 && dx <= 2 && !dy)) || (P.direction == WEST && !(dx < 0 && dx >= -2 && !dy)) || (P.direction == NORTH && !(dy > 0 && dy <= 2 && !dx)) || (P.direction == SOUTH && !(dy < 0 && dy >= -2 && !dx)))
		return null
	var/datum/npc_subtile_large_frame/F = new
	F.actor = src; F.pulse = P; F.transaction = npc_subtile_transaction
	F.start = P.before.Copy(); F.destination = P.destination; F.direction = P.direction
	F.sx = P.sx; F.sy = P.sy; F.generation = move_gen
	F.intent_owner = npc_subtile_transaction.intent_owner; F.deadline = npc_subtile_transaction.end_time
	F.enabled = npc_subtile_enabled
	F.bx = bound_x; F.by = bound_y; F.width = bound_width; F.height = bound_height; F.facing = dir
	F.path_target = target_obj; F.combat_target = target_mob; F.following = following_mob; F.stance = stance
	npc_subtile_large_frame = F
	if (!F.valid())
		F.close()
		return null
	return F

/datum/npc_subtile_large_frame/proc/retire()
	active = FALSE
	if (actor && !isDeleted(actor) && actor.npc_subtile_large_frame == src)
		actor.npc_subtile_large_frame = null
	actor = null
	pulse = null
	transaction = null
	intent_owner = null
	start = null
	destination = null
	path_target = null
	combat_target = null
	following = null
	fault = null
	checking = FALSE

/datum/npc_subtile_large_frame/proc/close()
	retire()
	if (!isDeleted(src))
		qdel(src)

/datum/npc_subtile_transaction
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/datum/intent_owner
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
	var/failed_pulse = FALSE
	var/finished = FALSE
	var/arrived = FALSE

/datum/npc_subtile_transaction/proc/wait_for_completion()
	while (!finished)
		sleep(world.tick_lag)
	return arrived

/datum/npc_subtile_transaction/proc/valid()
	return !cancelled && actor && !isDeleted(actor) && actor.npc_subtile_transaction == src && actor.npc_subtile_enabled && actor.npc_subtile_ready() && actor.npc_subtile_intent_valid(intent_owner) && !persistence_save_in_progress && world.time <= end_time + world.tick_lag && actor.move_gen == generation && actor.target_obj == target && actor.target_mob == combat_target && actor.following_mob == following && actor.stance == stance && human_subtile_same(expected, actor.npc_subtile_snapshot())

/datum/npc_subtile_transaction/proc/advance()
	if (actor && !isDeleted(actor) && actor.npc_subtile_pending_intent)
		actor.npc_subtile_prune_pending_fast()
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
	if (P.armed || actual_x != dx || actual_y != dy)
		failed_pulse = TRUE
		return FALSE
	return TRUE

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
	if (finished)
		return
	var/reached = !failed_pulse && !remaining_x && !remaining_y && valid()
	var/exception/finish_error
	try
		if (!completed && actor && !isDeleted(actor) && actor.npc_subtile_transaction == src)
			completed = TRUE
			actor.npc_subtile_pulse = null
			actor.npc_subtile_transaction = null
			actor.npc_subtile_release_glide()
			// Preserve one legacy living hook set even for a blocked native attempt.
			if (attempted)
				actor.living_movement_completed()
	catch (var/exception/npc_finish_error)
		finish_error = npc_finish_error
	if (reached && !finish_error && actor && !isDeleted(actor) && !actor.npc_subtile_transaction && actor.npc_subtile_enabled && actor.npc_subtile_ready() && actor.npc_subtile_intent_valid(intent_owner) && !persistence_save_in_progress && actor.move_gen == generation && actor.target_obj == target && actor.target_mob == combat_target && actor.following_mob == following && actor.stance == stance && human_subtile_same(expected, actor.npc_subtile_snapshot()))
		arrived = TRUE
	actor = null
	target = null
	combat_target = null
	following = null
	finished = TRUE
	if (finish_error)
		throw finish_error

/mob/living/simple_animal/proc/npc_subtile_take_pulse(turf/destination, direction)
	var/datum/npc_subtile_pulse/P = npc_subtile_pulse
	if (!P || !P.armed || P.actor != src || P.destination != destination || P.direction != direction || !human_subtile_same(P.before, npc_subtile_snapshot()))
		return null
	if (!P.restoring && (!npc_subtile_transaction || !npc_subtile_transaction.valid()))
		return null
	P.armed = FALSE
	return P

// A paid leash or command-follow is a durable relationship. It is saved as-is,
// through the cross-level link codec when the followed atom is on another level.
/mob/living/simple_animal/persistence_level_link_var(key)
	return key == "following_mob" || ..()

/mob/living/simple_animal/persistence_runtime_var(key)
	// Targets, path caches and their control state belong to this AI run.
	// following_mob is durable; see persistence_level_link_var above.
	if (key in list("target_obj", "target_mob", "pathfind_target", "found_path", "moving", "last_pathfound", "move_gen", "stance", "stance_step"))
		return TRUE
	if (key == "glide_size" && (npc_subtile_glide_owned || npc_subtile_import_owned || npc_subtile_position))
		return TRUE
	if (key == "npc_subtile_large_exit_enabled" || key == "npc_subtile_large_frame")
		return TRUE
	if ((key == "step_x" || key == "step_y") && (npc_subtile_import_owned || npc_subtile_position))
		return TRUE
	return (key in list("npc_subtile_enabled", "npc_subtile_transaction", "npc_subtile_pulse", "npc_subtile_offset_owned", "npc_subtile_import_owned", "npc_subtile_until", "npc_subtile_glide_owned", "npc_subtile_previous_glide", "npc_subtile_applied_glide", "npc_subtile_pursuit_enabled", "npc_subtile_pursuit", "npc_subtile_follow_enabled", "npc_subtile_follow", "npc_subtile_flee_enabled", "npc_subtile_flee", "npc_subtile_species_enabled", "npc_subtile_pet_enabled", "npc_subtile_pet_walk", "npc_subtile_recovery_enabled", "npc_subtile_recovery", "npc_subtile_pending_intent", "npc_subtile_wild_walk")) || ..()

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
