// Stage1: ownership and pulse planning only. No movement producer calls this
// kernel yet. Do not enable pulling by removing human_subtile_unlinked guards.
// First profile is a straight cardinal pull of an aligned, empty leaf object.
var/global/datum/subtile_pull_ownership/subtile_pull_ownership = new

/datum/subtile_pull_ownership
	should_save = FALSE
	var/list/owners = list()

/datum/subtile_pull_ownership/proc/claim(mob/living/human/leader, obj/follower, client/controller, direction, deadline)
	// Admission does not yield, so both participants are reserved together.
	if (!istype(leader, /mob/living/human) || !istype(follower, /obj) || owners[leader] || owners[follower] || owners.len > 126)
		return null
	var/datum/subtile_pull_pair/P = new
	if (!P.prepare(src, leader, follower, controller, direction, deadline))
		return null
	owners[leader] = P
	owners[follower] = P
	P.claimed = TRUE
	return P

/proc/subtile_pull_snapshot(atom/movable/A)
	if (!istype(A, /atom/movable) || isDeleted(A))
		return null
	return list("x" = A.x, "y" = A.y, "z" = A.z, "sx" = A.step_x, "sy" = A.step_y)

/proc/subtile_pull_shape(atom/movable/A, aligned = FALSE)
	return istype(A, /atom/movable) && !isDeleted(A) && isturf(A.loc) && world.icon_size == 32 && A.bound_x == 0 && A.bound_y == 0 && A.bound_width == 32 && A.bound_height == 32 && isnum(A.step_x) && isnum(A.step_y) && A.step_x == round(A.step_x) && A.step_y == round(A.step_y) && A.step_x >= 0 && A.step_x < 32 && A.step_y >= 0 && A.step_y < 32 && (!aligned || (!A.step_x && !A.step_y))

/proc/subtile_pull_shift(list/before, direction, amount)
	if (!human_subtile_same(before, before) || !(direction in list(NORTH, SOUTH, EAST, WEST)) || !isnum(amount) || amount <= 0 || amount > 2 || amount != round(amount))
		return null
	var/list/after = before.Copy()
	after["sx"] += (direction == EAST) ? amount : (direction == WEST) ? -amount : 0
	after["sy"] += (direction == NORTH) ? amount : (direction == SOUTH) ? -amount : 0
	if (after["sx"] < 0)
		after["x"]--
		after["sx"] += 32
	if (after["sx"] >= 32)
		after["x"]++
		after["sx"] -= 32
	if (after["sy"] < 0)
		after["y"]--
		after["sy"] += 32
	if (after["sy"] >= 32)
		after["y"]++
		after["sy"] -= 32
	return after

/datum/subtile_pull_pair
	should_save = FALSE
	var/datum/subtile_pull_ownership/registry
	var/mob/living/human/leader
	var/obj/follower
	var/client/controller
	var/direction
	var/start_time
	var/deadline
	var/list/leader_expected
	var/list/follower_expected
	var/list/leader_planned
	var/list/follower_planned
	var/datum/subtile_pull_capability/issued
	var/claimed = FALSE
	var/cancelled = FALSE
	var/released = FALSE
	var/recovery_required = FALSE
	var/phase = "idle"
	var/ordinal = 0
	var/distance = 0
	var/failure

/datum/subtile_pull_pair/proc/leader_allowed()
	return istype(leader, /mob/living/human) && !isDeleted(leader) && leader.human_subtile_enabled && !leader.human_subtile_transaction && !leader.human_subtile_pulse && !leader.stat && leader.canmove && !leader.transforming && !leader.lying && !leader.prone && !leader.crouching && !leader.restrained() && (!leader.pinned || !leader.pinned.len) && !leader.pulledby && !leader.buckled && !leader.riding && !leader.riding_mob && !leader.using_drone && !leader.control_object && !leader.incorporeal_move && !leader.using_object && !leader.using_cannon && !leader.football && (!leader.grab_list || !leader.grab_list.len) && (!leader.grabbed_by || !leader.grabbed_by.len)

/datum/subtile_pull_pair/proc/leaf_allowed()
	if (!istype(follower, /obj) || isDeleted(follower) || follower.anchored || follower.throwing || follower.contents.len || !(istype(follower, /obj/item) || istype(follower, /obj/structure/closet)))
		return FALSE
	if (istype(follower, /obj/item/vehicleparts) || istype(follower, /obj/item/football) || istype(follower, /obj/item/weapon/gun/projectile/automatic/stationary))
		return FALSE
	return leader && leader.can_pull_size && leader.can_pull_size >= follower.w_class

/datum/subtile_pull_pair/proc/controller_allowed()
	// Target participation never borrows or creates a client. The existing
	// real input owner's permissions remain necessary on EVERY capability.
	return istype(controller, /client) && istype(leader, /mob/living/human) && leader.client == controller && controller.mob == leader && controller.canmove && controller.moving

/datum/subtile_pull_pair/proc/prepare(datum/subtile_pull_ownership/manager, mob/living/human/L, obj/F, client/C, direct, end_time)
	if (claimed || released || registry || !istype(manager, /datum/subtile_pull_ownership) || !istype(L, /mob/living/human) || !istype(F, /obj) || !(direct in list(NORTH, SOUTH, EAST, WEST)) || !isnum(end_time) || end_time < world.time + world.tick_lag || end_time > world.time + 100)
		return FALSE
	leader = L
	follower = F
	controller = C
	direction = direct
	if (!leader_allowed() || !leaf_allowed() || !controller_allowed() || !subtile_pull_shape(L, TRUE) || !subtile_pull_shape(F, TRUE) || L.z != F.z || L.pulling != F || F.pulledby != L || get_step(L, turn(direct, 180)) != F.loc)
		leader = null
		follower = null
		controller = null
		return FALSE
	registry = manager
	start_time = world.time
	deadline = end_time
	leader_expected = subtile_pull_snapshot(L)
	follower_expected = subtile_pull_snapshot(F)
	return TRUE

/datum/subtile_pull_pair/proc/authority_valid()
	return claimed && !cancelled && !released && registry && registry.owners[leader] == src && registry.owners[follower] == src && leader_allowed() && leaf_allowed() && controller_allowed() && subtile_pull_shape(leader) && subtile_pull_shape(follower) && leader.z == follower.z && leader.pulling == follower && follower.pulledby == leader && !persistence_save_in_progress && world.time <= deadline + world.tick_lag

/datum/subtile_pull_pair/proc/valid()
	return authority_valid() && human_subtile_same(leader_expected, subtile_pull_snapshot(leader)) && human_subtile_same(follower_expected, subtile_pull_snapshot(follower))

/datum/subtile_pull_pair/proc/issue(atom/movable/member)
	if (!valid() || issued || distance >= 32)
		return null
	if (phase == "idle" && member == leader)
		if (ordinal >= 16)
			return null
		ordinal++
		leader_planned = subtile_pull_shift(leader_expected, direction, 2)
		follower_planned = subtile_pull_shift(follower_expected, direction, 2)
		phase = "leader_issued"
	else if (phase == "leader_observed" && member == follower)
		phase = "follower_issued"
	else
		return null
	var/datum/subtile_pull_capability/P = new
	P.pair = src
	P.member = member
	P.before = (member == leader) ? leader_expected.Copy() : follower_expected.Copy()
	P.after = (member == leader) ? leader_planned.Copy() : follower_planned.Copy()
	P.direction = direction
	P.ordinal = ordinal
	issued = P
	return P

/datum/subtile_pull_pair/proc/observe(datum/subtile_pull_capability/P)
	if (!P || issued != P || P.armed || P.pair != src || !authority_valid())
		cancel("receipt_owner_changed")
		return FALSE
	var/list/actual_leader = subtile_pull_snapshot(leader)
	var/list/actual_follower = subtile_pull_snapshot(follower)
	if (phase == "leader_issued" && P.member == leader && human_subtile_same(P.after, actual_leader) && human_subtile_same(follower_expected, actual_follower))
		leader_expected = actual_leader
		phase = "leader_observed"
	else if (phase == "follower_issued" && P.member == follower && human_subtile_same(leader_expected, actual_leader) && human_subtile_same(P.after, actual_follower))
		follower_expected = actual_follower
		distance += 2
		phase = "idle"
	else
		// A pair of native moves is not atomic. Retain real positions for a
		// future collision-safe resolver; never rewind or adopt external motion.
		cancel("participant_position_changed")
		return FALSE
	issued = null
	P.pair = null
	return TRUE

/datum/subtile_pull_pair/proc/cancel(reason)
	cancelled = TRUE
	failure = reason
	phase = "cancelled"
	if (issued)
		issued.armed = FALSE
		issued.pair = null
	issued = null
	return FALSE

/datum/subtile_pull_pair/proc/release()
	if (released)
		return TRUE
	// Releasing ownership at an offset without a physical recovery/capsule
	// would make an ordinary legacy Move snap. Integration is held until that
	// resolver and coherent pair save/load are implemented and tested.
	if ((leader && !isDeleted(leader) && (leader.step_x || leader.step_y)) || (follower && !isDeleted(follower) && (follower.step_x || follower.step_y)))
		recovery_required = TRUE
		return FALSE
	cancel("released")
	if (registry)
		if (registry.owners[leader] == src)
			registry.owners -= leader
		if (registry.owners[follower] == src)
			registry.owners -= follower
	released = TRUE
	leader = null
	follower = null
	controller = null
	registry = null
	return TRUE

/datum/subtile_pull_capability
	should_save = FALSE
	var/datum/subtile_pull_pair/pair
	var/atom/movable/member
	var/list/before
	var/list/after
	var/direction
	var/ordinal
	var/armed = TRUE

/datum/subtile_pull_capability/proc/consume(atom/movable/actor, turf/destination, direct, sx, sy)
	if (!armed || !pair || pair.issued != src || member != actor || direct != direction || ordinal != pair.ordinal || !pair.valid() || !human_subtile_same(before, subtile_pull_snapshot(actor)))
		return FALSE
	if (world.time < pair.start_time + (ordinal - 1) * (pair.deadline - pair.start_time) / 16 || destination != locate(after["x"], after["y"], after["z"]) || !destination || sx != after["sx"] || sy != after["sy"])
		return FALSE
	armed = FALSE
	return TRUE
