// Experimental straight-leaf producer. Default OFF until native acceptance.
/mob/living/human
	var/tmp/human_subtile_pull_enabled = FALSE

/obj/proc/subtile_pull_pulses_allowed()
	return FALSE

/obj/item/stack/subtile_pull_pulses_allowed()
	return type in list(/obj/item/stack/material/wood, /obj/item/stack/material/steel, /obj/item/stack/material/iron)

/obj/structure/closet/crate/subtile_pull_pulses_allowed()
	return type == /obj/structure/closet/crate

/mob/living/human/proc/set_human_subtile_pull(enabled)
	if (subtile_pull_ownership.owners[src] || human_subtile_transaction || human_subtile_pulse || !human_subtile_shape() || step_x || step_y)
		return FALSE
	if (enabled && !human_subtile_enabled && !set_human_subtile(TRUE))
		return FALSE
	human_subtile_pull_enabled = !!enabled
	return TRUE

/mob/living/human/proc/human_subtile_pull_ready(direct)
	if (!human_subtile_pull_enabled || !human_subtile_enabled || !client || client.mob != src || !client.canmove || !(direct in list(NORTH, SOUTH, EAST, WEST)))
		return FALSE
	var/datum/subtile_pull_pair/P = subtile_pull_ownership.owners[src]
	if (P)
		return P.recovery_required && direct == turn(P.direction, 180) && P.recovery_ready(src)
	if (!istype(pulling, /obj) || subtile_pull_ownership.owners[pulling] || !subtile_pull_shape(src, TRUE) || !subtile_pull_shape(pulling, TRUE) || pulling.pulledby != src || get_step(src, turn(direct, 180)) != pulling.loc)
		return FALSE
	// Read-only preflight precedes client.moving. Real input authority is
	// required again by claim/consume, after the original costs were paid.
	var/datum/subtile_pull_pair/check = new
	check.leader = src
	check.follower = pulling
	return check.leader_allowed() && check.leaf_allowed()

/mob/living/human/proc/human_subtile_pull_travel(turf/destination, direct, end_time)
	if (!human_subtile_pull_ready(direct) || destination != get_step(src, direct) || !human_subtile_authority(client))
		return FALSE
	var/datum/subtile_pull_pair/P = subtile_pull_ownership.owners[src]
	if (P)
		if (!P.begin_recovery(client, end_time))
			return FALSE
	else
		P = subtile_pull_ownership.claim(src, pulling, client, direct, end_time)
		if (!P)
			return FALSE
	P.intent_completed = FALSE
	P.intent_attempted = FALSE
	P.intent_moved = FALSE
	human_subtile_update_visuals(end_time - world.time, direct, client)
	P.follower_glide_before = P.follower.glide_size
	P.follower_glide_applied = glide_size
	P.follower.glide_size = glide_size
	P.follower_glide_owned = TRUE
	P.intent_running = TRUE
	try
		P.perform_intent()
	catch (var/exception/pull_producer_error)
		P.intent_running = FALSE
		P.cancel("producer_error")
		P.finish_intent()
		throw pull_producer_error
	P.intent_running = FALSE
	var/moved = P.intent_moved
	P.finish_intent()
	return moved

/datum/subtile_pull_pair
	var/intent_completed = FALSE
	var/intent_attempted = FALSE
	var/intent_moved = FALSE
	var/follower_glide_before
	var/follower_glide_applied
	var/follower_glide_owned = FALSE
	var/intent_running = FALSE
	var/native_inflight = FALSE
	var/completion_running = FALSE

/datum/subtile_pull_pair/proc/progress_of(atom/movable/A, list/origin)
	var/list/current = subtile_pull_snapshot(A)
	if (!human_subtile_same(current, current) || current["z"] != origin["z"])
		return -1
	var/dx = (current["x"] - origin["x"]) * 32 + current["sx"] - origin["sx"]
	var/dy = (current["y"] - origin["y"]) * 32 + current["sy"] - origin["sy"]
	var/progress = (direction == EAST) ? dx : (direction == WEST) ? -dx : (direction == NORTH) ? dy : -dy
	if ((direction in list(EAST, WEST)) ? dy : dx)
		return -1
	return (progress >= 0 && progress <= 32) ? progress : -1

/datum/subtile_pull_pair/proc/recovery_ready(mob/living/human/actor)
	if (orphaned || !registry || !claimed || released || actor != leader || registry.owners[leader] != src || registry.owners[follower] != src || !leader_allowed() || !leaf_allowed() || !subtile_pull_shape(leader) || !subtile_pull_shape(follower) || !human_subtile_same(leader_expected, subtile_pull_snapshot(leader)) || !human_subtile_same(follower_expected, subtile_pull_snapshot(follower)))
		return FALSE
	if ((leader.pulling && leader.pulling != follower) || (follower.pulledby && follower.pulledby != leader))
		return FALSE
	var/leading = progress_of(leader, leader_origin)
	var/trailing = progress_of(follower, follower_origin)
	return leading >= 0 && trailing >= 0 && leading >= trailing && leading - trailing <= 2

/datum/subtile_pull_pair/proc/begin_recovery(client/C, end_time)
	if (!recovery_ready(leader) || !C || leader.client != C || C.mob != leader || !C.canmove || !C.moving || !isnum(end_time) || !(end_time >= world.time + world.tick_lag && end_time <= world.time + 100))
		return FALSE
	cancel("recovery_started")
	controller = C
	start_time = world.time
	deadline = end_time
	recovering = TRUE
	phase = "recovering"
	recovery_ordinal = 0
	return TRUE

/datum/subtile_pull_pair/proc/recovery_valid()
	return recovering && recovery_ready(leader) && controller_allowed() && !persistence_save_in_progress && world.time <= deadline + world.tick_lag

/datum/subtile_pull_pair/proc/issue_recovery(atom/movable/member, amount, due)
	if (!recovery_valid() || issued || recovery_ordinal >= 34 || !(member == leader || member == follower) || !isnum(amount) || amount <= 0 || amount > 2 || amount > progress_of(member, member == leader ? leader_origin : follower_origin) || due < start_time || due > deadline)
		return null
	var/datum/subtile_pull_capability/P = new
	P.pair = src
	P.member = member
	P.before = member == leader ? leader_expected.Copy() : follower_expected.Copy()
	P.direction = turn(direction, 180)
	P.after = subtile_pull_shift(P.before, P.direction, amount)
	P.recovery = TRUE
	P.ordinal = ++recovery_ordinal
	P.due = due
	issued = P
	return P

/datum/subtile_pull_pair/proc/attempt(atom/movable/member, due, amount = 2)
	var/datum/subtile_pull_capability/P = recovering ? issue_recovery(member, amount, due) : issue(member)
	if (!P)
		return FALSE
	var/turf/destination = locate(P.after["x"], P.after["y"], P.after["z"])
	var/turf/front = get_step(member, P.direction)
	if (!destination || (map && front && map.check_caribbean_block(leader, front)))
		cancel("front_blocked")
		return FALSE
	intent_attempted = TRUE
	native_inflight = TRUE
	try
		member.Move(destination, P.direction)
	catch (var/exception/pull_native_error)
		native_inflight = FALSE
		record_interrupted_pulse(member, P)
		throw pull_native_error
	native_inflight = FALSE
	var/list/after = subtile_pull_snapshot(member)
	if (!human_subtile_same(P.before, after))
		intent_moved = TRUE
		if (member == leader)
			leader.human_subtile_offset_owned = TRUE
	// Logout/deletion/save hooks can revoke a capability during native callbacks.
	// Observe only its exact before/after positions; this grants no new movement.
	if (P.pair != src || (P.recovery ? !recovering || !controller_allowed() : !authority_valid()))
		record_interrupted_pulse(member, P)
		cancel("pulse_interrupted")
		return FALSE
	if (P.recovery)
		if (!recovery_valid_after(member, P))
			cancel("recovery_blocked")
			return FALSE
		if (member == leader)
			leader_expected = after
		else
			follower_expected = after
		issued = null
		P.pair = null
		return TRUE
	return observe(P)

/datum/subtile_pull_pair/proc/recovery_valid_after(atom/movable/member, datum/subtile_pull_capability/P)
	if (!recovering || !claimed || released || issued != P || P.pair != src || registry.owners[leader] != src || registry.owners[follower] != src || !controller_allowed() || !leader_allowed() || !leaf_allowed() || persistence_save_in_progress || P.armed || !human_subtile_same(P.after, subtile_pull_snapshot(member)))
		return FALSE
	return member == leader ? human_subtile_same(follower_expected, subtile_pull_snapshot(follower)) : human_subtile_same(leader_expected, subtile_pull_snapshot(leader))

/datum/subtile_pull_pair/proc/perform_intent()
	for (var/i = 1, i <= 16, i++)
		var/due = start_time + (i - 1) * (deadline - start_time) / 16
		if (due > world.time)
			sleep(due - world.time)
		if (recovering)
			if (!recovery_valid())
				break
			var/leading = progress_of(leader, leader_origin)
			var/trailing = progress_of(follower, follower_origin)
			if (!leading && !trailing)
				break
			var/list/plan = subtile_pull_recovery_plan(leading, trailing)
			var/succeeded = TRUE
			for (var/list/action in plan)
				var/atom/movable/member = action[1] == "leader" ? leader : follower
				if (!attempt(member, due, action[2]))
					succeeded = FALSE
					break
			if (!succeeded)
				break
		else
			if (!valid() || !attempt(leader, due) || !attempt(follower, due))
				break
	// Blocked/short recovery attempts still consume their admitted interval.
	if (controller_allowed() && world.time < deadline)
		sleep(deadline - world.time)

// Catch the2px gap first; then reverse follower-before-leader. The returned
// sequence contains at most3 physical moves, each at most2px, and never overlaps
// the two32px footprints. The producer supplies collision/authority per action.
/proc/subtile_pull_recovery_plan(leading, trailing)
	var/list/plan = list()
	if (leading > trailing)
		var/catchup = min(2, leading - trailing)
		plan += list(list("leader", catchup))
		leading -= catchup
	if (trailing)
		plan += list(list("follower", min(2, trailing)))
	if (leading)
		plan += list(list("leader", min(2, leading)))
	return plan

/datum/subtile_pull_pair/proc/finish_intent()
	if (intent_running || native_inflight || completion_running || intent_completed)
		return
	restore_follower_glide()
	completion_running = TRUE
	// One failing hook must not skip the other or strand the lease: both run,
	// the intent settles once after they unwind, then the first error rethrows.
	var/hook_error
	if (intent_attempted && leader && !isDeleted(leader))
		try
			leader.living_movement_completed()
		catch (var/exception/pull_living_hook_error)
			hook_error = pull_living_hook_error
		if (leader && !isDeleted(leader))
			try
				leader.human_movement_completed()
			catch (var/exception/pull_human_hook_error)
				if (!hook_error)
					hook_error = pull_human_hook_error
	completion_running = FALSE
	intent_completed = TRUE
	settle_intent()
	if (hook_error)
		throw hook_error

/datum/subtile_pull_pair/proc/settle_intent()
	if (!release())
		recovery_required = TRUE
		cancel(orphaned ? "orphan_checkpoint_required" : "reverse_to_recover")

/datum/subtile_pull_pair/proc/restore_follower_glide()
	if (follower_glide_owned)
		if (follower && !isDeleted(follower) && follower.glide_size == follower_glide_applied)
			follower.glide_size = follower_glide_before
		follower_glide_owned = FALSE

/atom/movable/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	var/datum/subtile_pull_pair/P = subtile_pull_ownership.owners[src]
	if (P)
		if (!P.save_checkpoint())
			throw EXCEPTION("Pull pair requires an aligned save checkpoint")
	return ..()
