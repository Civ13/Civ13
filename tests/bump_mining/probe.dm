var/list/failures = list()
var/checks = 0
/proc/check(value, label)
	checks++
	if (!value)
		failures += label
	world.log << "[value ? "PASS" : "FAIL"]: [label]"
/proc/settle(mob/living/human/H)
	var/end = world.time + 150
	while (H.pickaxe_mining_action && world.time < end)
		sleep(1)
	check(!H.pickaxe_mining_action && H.may_do_after && H.actions == 0 && H.starts == H.ends, "balanced_wait_and_release")
/world/New()
	OpenPort("none")
	spawn(0)
		var/mob/living/human/probe/H = new(locate(3,3,1))
		var/turf/floor/dirt/underground/T = new(locate(4,3,1))
		var/turf/floor/dirt/underground/U = new(locate(3,4,1))
		var/obj/item/weapon/material/pickaxe/P = new(H)
		var/obj/item/weapon/material/pickaxe/Q = new(H)
		H.r_hand = P
		H.l_hand = Q
		var/start = world.time
		H.Bump(T, TRUE)
		check(H.pickaxe_mining_action && T.pickaxe_mining_owner, "bump_starts_once")
		U.start_pickaxe_mining(H, P, TRUE)
		check(!U.pickaxe_mining_owner, "different_wall_cannot_queue")
		for (var/i=1, i<=32, i++)
			H.Bump(T, TRUE)
		check(H.pickaxe_mining_action && H.pickaxe_mining_action.tool == P, "active_hand_preferred")
		sleep(1)
		check(H.starts == 1 && H.actions == 1 && T.effects == 0, "repeat_has_one_paid_wait")
		settle(H)
		check(T.effects == 1 && world.time - start >= 120, "same_click_duration_and_one_effect")
		H.r_hand = null
		H.next_click = -1
		H.Bump(T, TRUE)
		check(H.pickaxe_mining_action && H.pickaxe_mining_action.tool == Q && !H.hand, "inactive_hand_no_switch")
		settle(H)
		check(T.effects == 2, "inactive_hand_completes_once")
		H.hand = TRUE
		H.next_click = -1
		H.Bump(T, TRUE)
		settle(H)
		check(T.effects == 3, "left_active_hand_completes")
		H.r_hand = P
		H.l_hand = null
		H.next_click = -1
		H.Bump(T, TRUE)
		check(H.pickaxe_mining_action && H.pickaxe_mining_action.tool == P && H.hand, "right_inactive_no_switch")
		settle(H)
		check(T.effects == 4, "right_inactive_completes")
		H.l_hand = Q
		H.r_hand = null
		for (var/mode in list("movement", "offset", "tool", "incapacity", "wall"))
			H.next_click = -1
			H.Bump(T, TRUE)
			sleep(1)
			if (mode == "movement") H.loc = locate(2,3,1)
			if (mode == "offset") H.step_x = 1
			if (mode == "tool") Q.loc = locate(3,3,1)
			if (mode == "incapacity") H.stat = 1
			if (mode == "wall")
				T = new /turf/floor/dirt/underground(locate(4,3,1))
			settle(H)
			check(T.effects == (mode == "wall" ? 0 : 4), mode == "offset" ? "subtile_motion_cancels" : "cancel_[mode]")
			H.loc = locate(3,3,1)
			H.step_x = 0
			Q.loc = H
			H.stat = 0
		H.next_move = world.time + 10
		H.next_click = -1
		H.Bump(T, TRUE)
		check(!H.pickaxe_mining_action, "click_cooldown_preserved")
		H.next_move = -1
		H.l_hand = null
		H.Bump(T, TRUE)
		check(!H.pickaxe_mining_action, "carried_inventory_not_equipped")
		var/before = H.parent_bumps
		H.Bump(locate(2,3,1), TRUE)
		check(H.parent_bumps == before + 1, "nonmineable_parent_bump_preserved")
		H.l_hand = Q
		H.next_click = -1
		T.start_pickaxe_mining(H, Q, TRUE)
		var/datum/pickaxe_mining_action/M = H.pickaxe_mining_action
		sleep(1)
		check(M && !M.claim(H,T), "wait_context_one_use")
		H.stat = 1
		settle(H)
		text2file(json_encode(list("head"=world.params["tested_commit"], "build"=world.byond_build, "checks"=checks, "failures"=failures)), "result.json")
		del(world)
		return
