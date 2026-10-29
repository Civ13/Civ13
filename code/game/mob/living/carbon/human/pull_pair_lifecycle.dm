// No borrowed authority. Partial/orphaned survivors stay exclusively held until
// a real paid recovery or the stuck-pair resolver below aligns them.
/datum/subtile_pull_ownership/proc/save_ready()
	for (var/atom/movable/member in owners)
		var/datum/subtile_pull_pair/P = owners[member]
		if (!istype(P) || P.registry != src || !(member == P.leader || member == P.follower) || !P.checkpoint_ready())
			return FALSE
	return TRUE

/datum/subtile_pull_pair/proc/checkpoint_ready()
	return !intent_running && !native_inflight && !completion_running && !issued && !settling && intent_completed && (!leader || isDeleted(leader) || subtile_pull_shape(leader, TRUE)) && (!follower || isDeleted(follower) || subtile_pull_shape(follower, TRUE))

/datum/subtile_pull_ownership/proc/retire_member(atom/movable/member)
	var/datum/subtile_pull_pair/P = owners[member]
	if (P)
		P.retire_member(member)

// Destroy, Logout and client Del must finish their own cleanup. A hook error
// rethrown by finish_intent arrives after the pair has settled, so log it here.
/datum/subtile_pull_pair/proc/teardown_settle()
	try
		if (intent_completed)
			settle_intent()
		else
			finish_intent()
	catch (var/exception/pull_teardown_error)
		log_debug("Pull pair teardown hook failed: [pull_teardown_error]")

/datum/subtile_pull_pair/proc/lifecycle_stop(reason, forget_controller = FALSE)
	if (released)
		return
	cancel(reason)
	restore_follower_glide()
	if (forget_controller)
		controller = null
	// A native callback must unwind before intent hooks or lease release.
	if (!intent_running && !native_inflight && !completion_running)
		teardown_settle()

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
		teardown_settle()

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
	var/settling = FALSE

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
// its nearest whole tile, then drop the lease. Never runs during another save
// or while native/intent/completion work is unwinding. Save admission passes
// its own unstarted reservation, so the settle runs under that exclusion.
/datum/subtile_pull_pair/proc/resolve_aligned(reason, datum/persistence_world_operation/admission)
	if (released)
		return TRUE
	if (settling || intent_running || native_inflight || completion_running || issued)
		return FALSE
	if (persistence_save_in_progress && !(admission && persistence_active_operation == admission && !admission.backend_started))
		return FALSE
	settling = TRUE
	var/list/targets = list()
	try
		cancel(reason)
		restore_follower_glide()
		for (var/atom/movable/member in list(leader, follower))
			if (isDeleted(member))
				continue
			var/atom/destination = member.loc
			if (isturf(member.loc))
				var/list/target = subtile_pull_nearest_tile(subtile_pull_snapshot(member))
				destination = locate(target["x"], target["y"], target["z"])
			targets[member] = destination
		for (var/atom/movable/member in targets)
			if (isDeleted(member))
				continue
			var/atom/destination = targets[member]
			// Clear the offset first, so a callback's own offset stays observable.
			member.step_x = 0
			member.step_y = 0
			if (destination && destination != member.loc)
				member.forceMove(destination)
	catch (var/exception/settle_error)
		settling = FALSE
		recovery_required = TRUE
		failure = "settle_error"
		throw settle_error
	settling = FALSE
	if (released)
		return TRUE
	// Entered/Crossed/forceMove callbacks can relocate or re-offset a member,
	// start native work or end the reservation. Keep the lease unless every
	// survivor is exactly where it was placed; a later pass settles again.
	if (intent_running || native_inflight || completion_running || issued || (admission && persistence_active_operation != admission))
		recovery_required = TRUE
		failure = "settle_interrupted"
		return FALSE
	for (var/atom/movable/member in targets)
		if (isDeleted(member))
			continue
		if (!targets[member] || member.loc != targets[member] || member.step_x || member.step_y || (isturf(member.loc) && !subtile_pull_shape(member, TRUE)))
			recovery_required = TRUE
			failure = "settle_position_changed"
			return FALSE
	drop_lease()
	return TRUE

// TRUE only when every quiet pair settled. Pairs still running an intent are
// left to the caller's save_ready() hold.
/datum/subtile_pull_ownership/proc/resolve_quiet(reason, datum/persistence_world_operation/admission)
	var/list/pairs = list()
	for (var/atom/movable/member in owners)
		var/datum/subtile_pull_pair/P = owners[member]
		if (istype(P) && !(P in pairs))
			pairs += P
	. = TRUE
	for (var/datum/subtile_pull_pair/P in pairs)
		if (P.intent_completed && !P.resolve_aligned(reason, admission))
			. = FALSE

/datum/subtile_pull_pair/proc/save_checkpoint()
	if (intent_running || native_inflight || completion_running || issued)
		cancel("save_inflight")
		restore_follower_glide()
		return FALSE
	lifecycle_stop("save_checkpoint", TRUE)
	return released
