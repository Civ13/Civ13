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

/datum/subtile_pull_pair/proc/save_checkpoint()
	if (intent_running || native_inflight || completion_running || issued)
		cancel("save_inflight")
		restore_follower_glide()
		return FALSE
	lifecycle_stop("save_checkpoint", TRUE)
	return released
