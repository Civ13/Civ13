// No background resolver or borrowed authority. Partial/orphaned survivors stay
// exclusively held until a real paid recovery or an explicit aligned placement.
/datum/subtile_pull_ownership/proc/save_ready()
	for (var/atom/movable/member in owners)
		var/datum/subtile_pull_pair/P = owners[member]
		if (!istype(P) || P.registry != src || !(member == P.leader || member == P.follower) || !P.checkpoint_ready())
			return FALSE
	return TRUE

/datum/subtile_pull_pair/proc/checkpoint_ready()
	return !intent_running && !native_inflight && !completion_running && !issued && intent_completed && (!leader || isDeleted(leader) || subtile_pull_shape(leader, TRUE)) && (!follower || isDeleted(follower) || subtile_pull_shape(follower, TRUE))

/datum/subtile_pull_ownership/proc/retire_member(atom/movable/member)
	var/datum/subtile_pull_pair/P = owners[member]
	if (P)
		P.retire_member(member)

/datum/subtile_pull_pair/proc/lifecycle_stop(reason, forget_controller = FALSE)
	if (released)
		return
	cancel(reason)
	restore_follower_glide()
	if (forget_controller)
		controller = null
	// A native callback must unwind before intent hooks or lease release.
	if (!intent_running && !native_inflight && !completion_running)
		if (intent_completed)
			settle_intent()
		else
			finish_intent()

/datum/subtile_pull_pair/proc/retire_member(atom/movable/member)
	if (released || !(member == leader || member == follower))
		return
	cancel("participant_deleted")
	restore_follower_glide()
	controller = null
	orphaned = TRUE
	if (registry && registry.owners[member] == src)
		registry.owners -= member
	if (member == leader)
		leader = null
		leader_expected = null
		leader_origin = null
	else
		follower = null
		follower_expected = null
		follower_origin = null
	// Remove the retiring actor's strong references even while a survivor holds.
	leader_planned = null
	follower_planned = null
	recovery_required = TRUE
	if (!intent_running && !native_inflight && !completion_running)
		if (intent_completed)
			settle_intent()
		else
			finish_intent()

/datum/subtile_pull_pair/proc/record_interrupted_pulse(atom/movable/member, datum/subtile_pull_capability/P)
	if (released || !P || P.member != member || !(member == leader || member == follower) || !subtile_pull_shape(member))
		return FALSE
	var/atom/movable/other = member == leader ? follower : leader
	var/list/other_expected = member == leader ? follower_expected : leader_expected
	if (other && !isDeleted(other) && !human_subtile_same(other_expected, subtile_pull_snapshot(other)))
		return FALSE
	var/list/actual = subtile_pull_snapshot(member)
	if (!human_subtile_same(actual, P.before) && (P.armed || !human_subtile_same(actual, P.after)))
		return FALSE
	if (member == leader)
		leader_expected = actual
	else
		follower_expected = actual
	return TRUE

/datum/subtile_pull_pair
	var/recovery_grace = 50
	var/resolve_epoch = 0

/datum/subtile_pull_pair/proc/recovery_possible()
	return leader && leader.client && leader.client.mob == leader && recovery_ready(leader)

// Nearest whole tile for a 32px footprint. For a straight pair (leader ahead
// of the follower by 0..2px) the two targets never coincide.
/proc/subtile_pull_nearest_tile(list/position)
	var/list/target = position.Copy()
	if (target["sx"] >= 16)
		target["x"]++
	if (target["sy"] >= 16)
		target["y"]++
	target["sx"] = 0
	target["sy"] = 0
	return target

/datum/subtile_pull_pair/proc/resolve_after(delay)
	var/epoch = ++resolve_epoch
	spawn(delay)
		if (!released && resolve_epoch == epoch && !resolve_aligned("recovery_timeout"))
			resolve_after(delay)

// Settle a quiet held pair without player input: place each live survivor on
// its nearest whole tile, then drop the lease. Never runs during a save or
// while native/intent/completion work is unwinding.
/datum/subtile_pull_pair/proc/resolve_aligned(reason)
	if (released)
		return TRUE
	if (intent_running || native_inflight || completion_running || issued || persistence_save_in_progress)
		return FALSE
	cancel(reason)
	restore_follower_glide()
	for (var/atom/movable/member in list(leader, follower))
		if (isDeleted(member))
			continue
		if (isturf(member.loc))
			var/list/target = subtile_pull_nearest_tile(subtile_pull_snapshot(member))
			var/turf/destination = locate(target["x"], target["y"], target["z"])
			if (destination && destination != member.loc)
				member.forceMove(destination)
		member.step_x = 0
		member.step_y = 0
	drop_lease()
	return TRUE

/datum/subtile_pull_ownership/proc/resolve_quiet(reason)
	var/list/pairs = list()
	for (var/atom/movable/member in owners)
		var/datum/subtile_pull_pair/P = owners[member]
		if (istype(P) && !(P in pairs))
			pairs += P
	for (var/datum/subtile_pull_pair/P in pairs)
		if (P.intent_completed)
			P.resolve_aligned(reason)

/datum/subtile_pull_pair/proc/save_checkpoint()
	if (intent_running || native_inflight || completion_running || issued)
		cancel("save_inflight")
		restore_follower_glide()
		return FALSE
	lifecycle_stop("save_checkpoint", TRUE)
	return released
