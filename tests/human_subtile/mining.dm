// Full-source combined collision/mining test. Only headless authority and the
// final ore/collapse effects are adapted; Enter/Bump, Move, reservation and
// do_after are production. Optional C requires a real attached fixture client.
var/human_subtile_mining_checks = 0
var/list/human_subtile_mining_rows = list()

/mob/living/human/subtile_fixture
	var/fixture_mining_authorized = TRUE
	var/fixture_mining_bumps = 0
	var/fixture_mining_client_owned = FALSE

/mob/living/human/subtile_fixture/bump_mining_authority()
	if (client)
		return ..()
	return fixture_mining_authorized

/mob/living/human/subtile_fixture/Bump(atom/A, yes)
	if (istype(A, /turf/floor/dirt/underground/subtile_mining))
		fixture_mining_bumps++
		fixture_mining_client_owned = client && client.mob == src && client.moving
	return ..()

/turf/floor/dirt/underground/subtile_mining
	var/fixture_effects = 0

/turf/floor/dirt/underground/subtile_mining/collapse_check()
	return

/turf/floor/dirt/underground/subtile_mining/mining_proc(mob/living/human/H)
	fixture_effects++

/proc/human_subtile_mining_assert(ok, label)
	human_subtile_mining_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/human_subtile_mining_move(mob/living/human/subtile_fixture/H, direction, client/C)
	if (C)
		human_subtile_fixture_wait(C)
		C.Move(get_step(H, direction), direction, FALSE)
	else if (H.human_subtile_enabled)
		H.SelfMove(get_step(H, direction), direction, world.time + 4)
	else
		H.SelfMove(get_step(H, direction), direction)

/proc/human_subtile_mining_settle(mob/living/human/H)
	var/deadline = world.time + 400
	while (H.pickaxe_mining_action && world.time < deadline)
		sleep(world.tick_lag)

/proc/human_subtile_fixture_mining(client/C = null)
	var/list/cases = list(list("enabled" = FALSE, "sy" = 0), list("enabled" = TRUE, "sy" = 0), list("enabled" = TRUE, "sy" = 4), list("enabled" = TRUE, "sy" = 28))
	var/mob/living/human/subtile_fixture/H
	if (C)
		H = C.mob
		human_subtile_mining_assert(istype(H) && H.client == C && !C.moving, "mining_real_client_required")
	else
		H = human_subtile_fixture_actor(4, 11)
	var/obj/item/weapon/material/pickaxe/P = new(H)
	H.r_hand = P
	P.usespeed = 4 // Bounded fixture duration; production timing expression stays intact.
	H.hand = FALSE
	H.m_intent = "walk"
	H.next_move = -1
	for (var/list/test_case in cases)
		H.forceMove(locate(4, 11, 1))
		// ForceMove is setup only. All exercised displacement uses native Move.
		human_subtile_fixture_place(H, 0, test_case["sy"])
		H.human_subtile_enabled = test_case["enabled"]
		H.fixture_mining_authorized = TRUE
		H.next_click = -1
		H.next_move = -1
		var/turf/floor/dirt/underground/subtile_mining/T = new(locate(5, 11, 1))
		var/list/before = H.human_subtile_snapshot()
		var/bumps = H.fixture_mining_bumps
		if (C)
			human_subtile_mining_assert(!H.bump_mining_authority(), "mining_client_idle_has_no_authority")
		else
			H.fixture_mining_authorized = FALSE
			human_subtile_mining_move(H, EAST, C)
			human_subtile_mining_assert(!H.pickaxe_mining_action && H.fixture_mining_bumps > bumps, "mining_headless_authority_denial")
			H.fixture_mining_authorized = TRUE
		bumps = H.fixture_mining_bumps
		human_subtile_mining_move(H, EAST, C)
		var/datum/pickaxe_mining_action/M = H.pickaxe_mining_action
		human_subtile_mining_assert(H.fixture_mining_bumps > bumps && M && T.pickaxe_mining_owner == M, "mining_native_collision_dispatch")
		human_subtile_mining_assert(human_subtile_same(before, H.human_subtile_snapshot()) && M.origin == H.loc && M.sx == H.step_x && M.sy == H.step_y, "mining_offset_snapshot_exact")
		human_subtile_mining_assert(!H.human_subtile_pulse && !H.human_subtile_transaction, "mining_blocked_transaction_released")
		if (C)
			human_subtile_mining_assert(H.fixture_mining_client_owned && !C.moving, "mining_native_client_moving_owned_and_released")
		// A repeated collision must retain the original reservation.
		human_subtile_mining_move(H, EAST, C)
		human_subtile_mining_assert(H.pickaxe_mining_action == M && T.pickaxe_mining_owner == M, "mining_repeat_cannot_replace_owner")
		sleep(world.tick_lag)
		human_subtile_mining_assert(M.wait_started && !H.may_do_after && T.fixture_effects == 0, "mining_one_paid_wait")
		human_subtile_mining_settle(H)
		human_subtile_mining_assert(M.committed && T.fixture_effects == 1, "mining_stationary_completion_once")
		human_subtile_mining_assert(!H.pickaxe_mining_action && !T.pickaxe_mining_owner && !T.mining_in_progress && H.may_do_after && !M.actor && !M.wall && !M.tool && !M.origin && !M.progressbar, "mining_completion_releases_all_owners")
		// Start again at the same physical offset, then move orthogonally through
		// the actual adapter. This stays in the anchor for offset 0/4 and crosses
		// it for offset 28; no direct step_x/step_y assignment fakes the drift.
		H.next_click = -1
		H.next_move = -1
		human_subtile_mining_move(H, EAST, C)
		M = H.pickaxe_mining_action
		human_subtile_mining_assert(M && M.sy == test_case["sy"], "mining_second_snapshot")
		sleep(world.tick_lag)
		if (H.human_subtile_enabled)
			H.fixture_cancel_after = H.fixture_pulses + 1
		human_subtile_mining_move(H, NORTH, C)
		H.fixture_cancel_after = 0
		H.fixture_authorized = TRUE
		human_subtile_mining_assert(!human_subtile_same(before, H.human_subtile_snapshot()), "mining_drift_is_physical")
		human_subtile_mining_assert(!M.valid(H, T), "mining_drift_rejected")
		human_subtile_mining_settle(H)
		human_subtile_mining_assert(!M.committed && T.fixture_effects == 1, "mining_drift_never_commits")
		human_subtile_mining_assert(!H.pickaxe_mining_action && !T.pickaxe_mining_owner && !T.mining_in_progress && H.may_do_after && !M.actor && !M.wall && !M.tool && !M.origin && !M.progressbar && !H.human_subtile_transaction && !H.human_subtile_pulse, "mining_drift_cleanup")
		human_subtile_mining_rows += list(list("enabled" = test_case["enabled"], "sy" = test_case["sy"], "client" = !!C, "bumps" = H.fixture_mining_bumps - bumps, "effects" = T.fixture_effects, "before" = before, "after" = H.human_subtile_snapshot()))
		T.ChangeTurf(/turf/floor/plating/subtile_fixture)
	H.r_hand = null
	qdel(P)
	if (!C)
		qdel(H)
	return human_subtile_mining_rows
