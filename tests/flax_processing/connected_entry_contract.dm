// Unwired DIRECT-PROC contracts for a separately admitted isolated scene.
// A connected client here permits screen assertions; these calls do NOT prove
// native click/drag delivery or rendered notices. See connected-scene-contract.md.
// No world/client overrides, verbs, listeners, client construction or auto-call.
/proc/flax_connected_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "CONNECTED ENTRY PASS: [message]"

/proc/flax_connected_count(atom/site, path)
	var/amount = 0
	for (var/obj/item/stack/S in site)
		if (istype(S, path))
			amount += S.amount
	return amount

/proc/flax_entry_direct_connected_proc_contract(mob/living/human/U, client/C, turf/floor/beach/water/W, obj/structure/table/T, left_hand = FALSE)
	flax_connected_assert(U && U.type == /mob/living/human && C && U.client == C && C.mob == U, "actual base production human owns the real client")
	flax_connected_assert(!U.l_hand && !U.r_hand && !U.lying && !U.sleeping && U.stat == CONSCIOUS, "connected test actor is awake with empty hands")
	flax_connected_assert(istype(W) && !W.salty && !W.radiation && flax_worker_can_reach(U, W), "connected scene has reachable fresh water")
	flax_connected_assert(!flax_connected_count(W, /obj/item/stack/rotten_flax), "connected output site is initially empty")
	var/turf/site = get_turf(U)
	flax_connected_assert(T && isturf(T.loc) && T.loc != site && get_dist(U, T) == 1, "connected scene owns an adjacent table test target")
	U.hand = left_hand
	var/obj/item/stack/material/flax/raw = new(site, 2, FALSE)
	flax_connected_assert(U.put_in_active_hand(raw), "connected production pickup accepts the paid raw input")
	flax_connected_assert(raw.tie_bundle(U), "connected production binding consumes actual flax")
	var/obj/item/flax_bundle/B = locate() in U
	flax_connected_assert(B && U.get_active_hand() == B && B.loc == U && B.screen_loc && (B in C.screen), "paid held bundle has actual client screen membership")
	var/list/observed = list("entry" = FALSE)
	spawn(1)
		if (U && C && U.client == C && C.mob == U && B && B.loc == W && B.soaking && !U.item_is_in_hands(B) && !B.screen_loc && !(B in C.screen))
			observed["entry"] = TRUE
	// The exact base human has no fixture wait override. All three original
	// 100-ds waits execute normally. Do not shorten or manually invoke soak.
	B.afterattack(W, U, TRUE)
	flax_connected_assert(observed["entry"], "real production wait owns placed bundle after actual client screen cleanup")
	flax_connected_assert(C && U && U.client == C && C.mob == U && !U.l_hand && !U.r_hand && (!B || !B.loc), "connected body and inventory ownership survive completion")
	flax_connected_assert(flax_connected_count(W, /obj/item/stack/rotten_flax) == 2, "connected genuine entry yields exactly two rotten flax")
	if (B)
		B.afterattack(W, U, TRUE)
	flax_connected_assert(flax_connected_count(W, /obj/item/stack/rotten_flax) == 2, "connected consumed bundle cannot replay entry")
	for (var/refused in list(FALSE, TRUE))
		var/obj/item/weapon/I = new(site)
		flax_connected_assert(U.put_in_active_hand(I) && (I in C.screen), "connected table input owns actual screen membership")
		I.nodrop = refused
		T.MouseDrop_T(I, U)
		if (refused)
			flax_connected_assert(I.loc == U && U.get_active_hand() == I && (I in C.screen), "connected table refusal preserves hand and screen ownership")
			I.nodrop = FALSE
			U.drop_from_inventory(I)
		else
			flax_connected_assert(I.loc == T.loc && !U.item_is_in_hands(I) && !I.screen_loc && !(I in C.screen), "connected table success clears hand and screen ownership")
		qdel(I)
	var/obj/item/weapon/defibrillator/D = new(site)
	var/obj/item/weapon/shockpaddles/linked/P = D.paddles
	flax_connected_assert(P && U.put_in_active_hand(P) && (P in C.screen), "connected paddle pickup owns actual screen membership")
	D.reattach_paddles(U)
	flax_connected_assert(P.loc == D && !U.item_is_in_hands(P) && !P.screen_loc && !(P in C.screen), "connected paddle return clears actual hand and screen ownership")
	qdel(D)
	return list("scope" = "direct_proc_only", "connected_acceptance" = FALSE, "afterattack_proc_contract" = TRUE, "real_wait_proc_contract" = TRUE, "client_screen_proc_contract" = TRUE, "table_proc_contract" = TRUE, "paddle_proc_contract" = TRUE)

// Only reviewed scene-owned scratch tiles may be supplied. This wrapper creates
// a fresh water turf per hand; it never resets or clears a prior hand's output.
// Both original 100-ds wait sequences are preserved. No auto-call is installed.
/proc/flax_entry_direct_connected_proc_pair(mob/living/human/U, client/C, turf/left_site, turf/right_site, obj/structure/table/T)
	flax_connected_assert(left_site && right_site && left_site != right_site && get_dist(U, left_site) <= 1 && get_dist(U, right_site) <= 1, "direct pair owns two distinct reachable scratch water sites")
	var/list/direct_records = list()
	for (var/left_hand in list(FALSE, TRUE))
		var/turf/floor/beach/water/W = new(left_hand ? left_site : right_site)
		W.salty = FALSE
		W.radiation = 0
		direct_records += list(flax_entry_direct_connected_proc_contract(U, C, W, T, left_hand))
	return list("scope" = "direct_proc_only", "connected_acceptance" = FALSE, "direct_records" = direct_records)
