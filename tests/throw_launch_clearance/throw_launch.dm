// Included only by tests/throw_launch_clearance/prepare.py. No production include.
// Uses native footprint membership, actual throwing.fire and real hitby dispatch
// into a harmless fixture override. Runtime execution is a separate approval.
var/throw_launch_fixture_checks = 0
#define THROW_LAUNCH_EXPECTED_CHECKS 242

/turf/floor/plating/subtile_fixture
	var/fixture_throw_action
	var/mob/living/human/fixture_throw_source
	var/turf/fixture_throw_target

/turf/floor/plating/subtile_fixture/Entered(atom/A, atom/old)
	. = ..()
	if (!istype(A, /obj/item/throw_launch_fixture) || !fixture_throw_action)
		return
	var/action = fixture_throw_action
	fixture_throw_action = null
	if (action == "relocate")
		A:forceMove(old)
		A:forceMove(src)
	else if (action == "rethrow")
		A:throw_at(fixture_throw_target, 12, 2, fixture_throw_source)

/mob/living/human/subtile_fixture
	var/fixture_throw_hits = 0

/mob/living/human/subtile_fixture/hitby(atom/movable/AM, speed)
	if (istype(AM, /obj/item/throw_launch_fixture))
		fixture_throw_hits++
		AM.throwing = FALSE
		return
	return ..()

/obj/item/throw_launch_fixture
	var/list/fixture_impacts = list()
	var/mob/living/human/fixture_rethrow_source
	var/turf/fixture_rethrow_target

/obj/item/throw_launch_fixture/throw_impact(atom/hit_atom, speed)
	fixture_impacts += hit_atom
	if (fixture_rethrow_source)
		var/mob/living/human/source = fixture_rethrow_source
		fixture_rethrow_source = null
		throw_at(fixture_rethrow_target, 12, 2, source)
		return
	if (isliving(hit_atom))
		return ..()

/proc/throw_launch_fixture_assert(ok, label)
	throw_launch_fixture_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/throw_launch_fixture_actor(direction, offset)
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(8, 7)
	var/tx = 8
	var/ty = 7
	var/sx = (direction & EAST) ? offset : (direction & WEST) ? -offset : 0
	var/sy = (direction & NORTH) ? offset : (direction & SOUTH) ? -offset : 0
	if (sx < 0)
		tx--
		sx += 32
	if (sy < 0)
		ty--
		sy += 32
	H.forceMove(locate(tx, ty, 1))
	human_subtile_fixture_place(H, sx, sy)
	return H

/proc/throw_launch_fixture_item(mob/living/human/H, direction)
	var/obj/item/throw_launch_fixture/I = new(get_turf(H))
	var/dx = (direction & EAST) ? 4 : (direction & WEST) ? -4 : 0
	var/dy = (direction & NORTH) ? 4 : (direction & SOUTH) ? -4 : 0
	I.throw_at(locate(H.x + dx, H.y + dy, 1), 12, 2, H)
	return I

/proc/throw_launch_fixture_step(process/throwing/P, atom/movable/I)
	P.current_list = list(I)
	P.fire()

/proc/throw_launch_fixture_run()
	throw_launch_fixture_assert(world.byond_version == 516 && world.byond_build == 1688, "throw_current_engine")
	var/process/throwing/P = new
	P.priority = PROCESS_PRIORITY_VERY_HIGH
	for (var/direction in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		for (var/offset in list(0, 1, 2, 15, 16, 30, 31))
			var/mob/living/human/subtile_fixture/H = throw_launch_fixture_actor(direction, offset)
			var/obj/item/throw_launch_fixture/I = throw_launch_fixture_item(H, direction)
			throw_launch_fixture_assert(I.throw_launch_source == H, "launch_arms_[direction]_[offset]")
			throw_launch_fixture_step(P, I)
			throw_launch_fixture_assert(!H.fixture_throw_hits && !(H in I.fixture_impacts), "initial_no_self_hit_[direction]_[offset]")
			throw_launch_fixture_assert(I.speed == 2 && I.range == 12 && I.dist_travelled == 1, "flight_contract_[direction]_[offset]")
			if (!offset)
				throw_launch_fixture_assert(!I.throw_launch_source, "stationary_first_hop_separates_[direction]")
			qdel(I)
			qdel(H)
		// An aligned release followed by an actual admitted 2px human pulse.
		var/mob/living/human/subtile_fixture/M = throw_launch_fixture_actor(direction, 0)
		var/obj/item/throw_launch_fixture/J = throw_launch_fixture_item(M, direction)
		M.set_human_subtile(TRUE)
		M.fixture_cancel_after = 1
		M.SelfMove(get_step(M, direction), direction, world.time + 4)
		throw_launch_fixture_assert(M.fixture_pulses == 1, "moving_release_actual_pulse_[direction]")
		throw_launch_fixture_step(P, J)
		throw_launch_fixture_assert(!M.fixture_throw_hits, "moving_release_no_self_hit_[direction]")
		qdel(J)
		qdel(M)
		// The opposite deterministic ordering: real human pulse before release.
		var/mob/living/human/subtile_fixture/U = throw_launch_fixture_actor(direction, 0)
		U.set_human_subtile(TRUE)
		U.fixture_cancel_after = 1
		U.SelfMove(get_step(U, direction), direction, world.time + 4)
		throw_launch_fixture_assert(U.fixture_pulses == 1, "pulse_before_release_actual_[direction]")
		var/obj/item/throw_launch_fixture/UI = throw_launch_fixture_item(U, direction)
		throw_launch_fixture_step(P, UI)
		throw_launch_fixture_assert(!U.fixture_throw_hits, "pulse_before_release_no_self_hit_[direction]")
		qdel(UI)
		qdel(U)
	// A diagonal initially overlaps across BOTH of its first cardinal hops.
	var/mob/living/human/subtile_fixture/D = throw_launch_fixture_actor(NORTHEAST, 2)
	var/obj/item/throw_launch_fixture/DI = throw_launch_fixture_item(D, NORTHEAST)
	throw_launch_fixture_step(P, DI)
	throw_launch_fixture_step(P, DI)
	throw_launch_fixture_assert(!D.fixture_throw_hits && DI.throw_launch_source == D, "diagonal_two_hops_overlap")
	throw_launch_fixture_step(P, DI)
	throw_launch_fixture_assert(!DI.throw_launch_source, "diagonal_empty_turf_separates")
	qdel(DI)
	qdel(D)
	// After separation, a later real hitby on the same source is retained.
	var/mob/living/human/subtile_fixture/R = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/RI = throw_launch_fixture_item(R, NORTH)
	throw_launch_fixture_step(P, RI)
	throw_launch_fixture_step(P, RI)
	throw_launch_fixture_assert(!RI.throw_launch_source, "cardinal_empty_turf_separates")
	R.forceMove(get_step(RI, NORTH))
	human_subtile_fixture_place(R, 0, 0)
	throw_launch_fixture_step(P, RI)
	throw_launch_fixture_assert(R.fixture_throw_hits == 1 && !RI.throwing, "later_source_hitby_dispatch")
	qdel(RI)
	qdel(R)
	// Reflection before separation must not inherit initial outbound protection.
	var/mob/living/human/subtile_fixture/B = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/BI = throw_launch_fixture_item(B, NORTH)
	throw_launch_fixture_step(P, BI)
	BI.dy = SOUTH
	BI.original_target = locate(BI.x, BI.y - 4, 1)
	throw_launch_fixture_step(P, BI)
	throw_launch_fixture_assert(B.fixture_throw_hits == 1 && !BI.throw_launch_source, "reflected_before_separation_hits")
	qdel(BI)
	qdel(B)
	// A different standing mob remains hittable during initial source overlap.
	var/mob/living/human/subtile_fixture/S = throw_launch_fixture_actor(NORTH, 2)
	var/mob/living/human/subtile_fixture/O = human_subtile_fixture_actor(S.x, S.y + 1)
	var/obj/item/throw_launch_fixture/SI = throw_launch_fixture_item(S, NORTH)
	throw_launch_fixture_step(P, SI)
	throw_launch_fixture_assert(!S.fixture_throw_hits && O.fixture_throw_hits == 1, "other_actor_not_exempt")
	qdel(SI)
	qdel(O)
	qdel(S)
	// Preserve existing blocked-launch collision; it earns no outbound grace.
	var/mob/living/human/subtile_fixture/W = throw_launch_fixture_actor(NORTH, 0)
	var/obj/item/throw_launch_fixture/WI = throw_launch_fixture_item(W, NORTH)
	var/turf/wall = get_step(W, NORTH)
	wall.density = TRUE
	throw_launch_fixture_step(P, WI)
	wall.density = FALSE
	throw_launch_fixture_assert(W.fixture_throw_hits == 1 && !WI.throw_launch_source, "blocked_hop_keeps_old_collision")
	qdel(WI)
	qdel(W)
	// Inventory/catch, pickup, completion, rethrow and unattributed entrypoint.
	var/mob/living/human/subtile_fixture/C = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/CI = throw_launch_fixture_item(C, NORTH)
	CI.forceMove(C)
	throw_launch_fixture_assert(!CI.throw_launch_source, "catch_container_clears")
	CI.forceMove(get_turf(C))
	CI.throw_at(get_step(C, NORTH), 1, 2, C)
	CI.pickup(C)
	throw_launch_fixture_assert(!CI.throw_launch_source, "pickup_clears")
	CI.throw_at(get_step(C, NORTH), 1, 2, C)
	CI.finished_throwing()
	throw_launch_fixture_assert(!CI.throw_launch_source, "completion_clears")
	CI.throw_at(get_step(C, NORTH), 1, 2)
	throw_launch_fixture_assert(!CI.throw_launch_source, "unattributed_entry_does_not_arm")
	CI.throw_at(get_step(C, NORTH), 1, 2, C)
	CI.Bump(get_turf(C), FALSE)
	throw_launch_fixture_assert(!CI.throw_launch_source && !CI.throwing, "bump_ends_launch_segment")
	for (var/key in list("throw_launch_source", "throw_launch_dx", "throw_launch_dy", "throw_launch_x", "throw_launch_y", "throw_flight_token"))
		throw_launch_fixture_assert(CI.persistence_runtime_var(key), "runtime_exclusion_[key]")
	qdel(CI)
	qdel(C)
	// A literal same-turf request is an unchanged no-op, not a flight hop.
	var/mob/living/human/subtile_fixture/F = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/FI = throw_launch_fixture_item(F, NORTH)
	var/turf/origin = get_turf(FI)
	var/noop = FI.forceMove(origin)
	throw_launch_fixture_assert(!noop && FI.loc == origin && !FI.dist_travelled, "same_turf_force_move_does_not_advance")
	throw_launch_fixture_assert(FI.throw_launch_source == F, "same_turf_noop_keeps_uninterrupted_initial_state")
	throw_launch_fixture_step(P, FI)
	throw_launch_fixture_assert(!F.fixture_throw_hits, "same_turf_noop_then_normal_launch_stays_safe")
	qdel(FI)
	qdel(F)
	// A genuine same-z relocation away and back must not look uninterrupted.
	var/mob/living/human/subtile_fixture/V = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/VI = throw_launch_fixture_item(V, NORTH)
	var/turf/start = get_turf(VI)
	var/away = VI.forceMove(get_step(VI, EAST))
	throw_launch_fixture_assert(away && !VI.throw_launch_source, "same_z_away_revokes_clearance_immediately")
	var/back = VI.forceMove(start)
	throw_launch_fixture_assert(back && !VI.throw_launch_source, "same_z_return_cannot_rearm_clearance")
	throw_launch_fixture_step(P, VI)
	throw_launch_fixture_assert(V.fixture_throw_hits == 1, "same_z_return_followed_by_hop_hits_source")
	qdel(VI)
	qdel(V)
	// Return the projectile itself after a verified separated flight sample.
	var/mob/living/human/subtile_fixture/Q = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/QI = throw_launch_fixture_item(Q, NORTH)
	throw_launch_fixture_step(P, QI)
	throw_launch_fixture_step(P, QI)
	throw_launch_fixture_assert(!QI.throw_launch_source, "projectile_return_starts_after_separation")
	QI.dy = SOUTH
	QI.original_target = locate(QI.x, QI.y - 4, 1)
	throw_launch_fixture_step(P, QI)
	throw_launch_fixture_assert(Q.fixture_throw_hits == 1, "returning_projectile_after_separation_hits_source")
	qdel(QI)
	qdel(Q)
	// Real Entered callback relocation must not inherit the outer hop token.
	var/mob/living/human/subtile_fixture/N = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/NI = throw_launch_fixture_item(N, NORTH)
	var/turf/floor/plating/subtile_fixture/nested_tile = get_step(NI, NORTH)
	nested_tile.fixture_throw_action = "relocate"
	throw_launch_fixture_step(P, NI)
	throw_launch_fixture_assert(!NI.throw_launch_source && N.fixture_throw_hits == 1, "entered_relocation_revokes_outer_permission")
	qdel(NI)
	qdel(N)
	// A callback-started new flight must not consume the old frame's hit/progress.
	var/mob/living/human/subtile_fixture/E = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/EI = throw_launch_fixture_item(E, NORTH)
	var/turf/floor/plating/subtile_fixture/rethrow_tile = get_step(EI, NORTH)
	var/mob/living/human/subtile_fixture/EO = human_subtile_fixture_actor(rethrow_tile.x, rethrow_tile.y)
	var/list/old_token = EI.throw_flight_token
	rethrow_tile.fixture_throw_action = "rethrow"
	rethrow_tile.fixture_throw_source = EO
	rethrow_tile.fixture_throw_target = get_step(EO, NORTH)
	throw_launch_fixture_step(P, EI)
	throw_launch_fixture_assert(EI.throw_flight_token != old_token && EI.throw_launch_source == EO && !EI.dist_travelled && !E.fixture_throw_hits && !EO.fixture_throw_hits, "entered_rethrow_skips_old_frame")
	throw_launch_fixture_step(P, EI)
	throw_launch_fixture_assert(EI.dist_travelled == 1 && !EO.fixture_throw_hits, "replacement_flight_owns_next_hop")
	rethrow_tile.fixture_throw_source = null
	rethrow_tile.fixture_throw_target = null
	qdel(EI)
	qdel(EO)
	qdel(E)
	// Impact callbacks must also stop the old collision loop and progress work.
	var/mob/living/human/subtile_fixture/J = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/JI = throw_launch_fixture_item(J, NORTH)
	var/turf/impact_tile = get_step(JI, NORTH)
	var/mob/living/human/subtile_fixture/JO = human_subtile_fixture_actor(impact_tile.x, impact_tile.y)
	var/mob/living/human/subtile_fixture/JX = human_subtile_fixture_actor(impact_tile.x, impact_tile.y)
	JI.fixture_rethrow_source = JO
	JI.fixture_rethrow_target = get_step(JO, NORTH)
	throw_launch_fixture_step(P, JI)
	throw_launch_fixture_assert(JI.throw_launch_source == JO && !JI.dist_travelled && JI.fixture_impacts.len == 1 && !JO.fixture_throw_hits && !JX.fixture_throw_hits, "impact_rethrow_skips_old_collision_loop_and_progress")
	qdel(JI)
	qdel(JX)
	qdel(JO)
	qdel(J)
	// Completion/Bump callbacks must not cancel the newer flight's fields.
	var/mob/living/human/subtile_fixture/K = throw_launch_fixture_actor(NORTH, 2)
	var/obj/item/throw_launch_fixture/KI = throw_launch_fixture_item(K, NORTH)
	KI.fixture_rethrow_source = K
	KI.fixture_rethrow_target = get_step(K, NORTH)
	KI.finished_throwing()
	throw_launch_fixture_assert(KI.throwing && KI.throw_flight_token && KI.throw_launch_source == K && !KI.dist_travelled, "completion_rethrow_keeps_new_flight")
	throw_launch_fixture_step(P, KI)
	throw_launch_fixture_assert(KI.dist_travelled == 1 && !K.fixture_throw_hits, "completion_rethrow_next_hop")
	KI.forceMove(get_turf(K))
	KI.throw_at(get_step(K, NORTH), 12, 2, K)
	KI.fixture_rethrow_source = K
	KI.fixture_rethrow_target = get_step(K, NORTH)
	KI.Bump(get_turf(K), FALSE)
	throw_launch_fixture_assert(KI.throwing && KI.throw_flight_token && KI.throw_launch_source == K, "bump_rethrow_keeps_new_flight")
	qdel(KI)
	qdel(K)
	qdel(P)
