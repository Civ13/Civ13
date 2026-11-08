// Leader orders: a squad leader, officer, commander or faction leader calls an
// order, and nearby allies get a short bonus. Adapted from CM-SS13's
// issue_order.dm (cmss13-devs/cmss13, AGPL-3.0); reimplemented for Civ13.
//
// Move: faster running. Hold: less pain. Focus: tighter aim.
// A whistle in hand or on the body adds strength and range.
// Buffs and cooldowns are world.time stamps, so nothing needs a timer and
// nothing is saved: a restored character simply has no active order.

#define LEADER_ORDER_MOVE "move"
#define LEADER_ORDER_HOLD "hold"
#define LEADER_ORDER_FOCUS "focus"
#define LEADER_ORDER_RANGE 7
#define LEADER_ORDER_WHISTLE_RANGE 3
#define LEADER_ORDER_COOLDOWN (60 SECONDS)
#define LEADER_ORDER_WHISTLE_COOLDOWN (30 SECONDS)
#define LEADER_ORDER_MAX_STRENGTH 3

/mob/living/human/var/tmp/leader_order_ready_at = 0
/mob/living/human/var/tmp/order_move_until = 0
/mob/living/human/var/tmp/order_move_strength = 0
/mob/living/human/var/tmp/order_hold_until = 0
/mob/living/human/var/tmp/order_hold_strength = 0
/mob/living/human/var/tmp/order_focus_until = 0
/mob/living/human/var/tmp/order_focus_strength = 0

/mob/living/human/persistence_runtime_var(key)
	return (key in list("leader_order_ready_at", "order_move_until", "order_move_strength", "order_hold_until", "order_hold_strength", "order_focus_until", "order_focus_strength")) || ..()

// Base strength of this human's orders, or 0 when they cannot give orders.
/mob/living/human/proc/leader_order_strength()
	if (original_job)
		if (original_job.is_commander)
			return 2
		if (original_job.is_officer)
			return 1.5
		if (original_job.is_squad_leader)
			return 1
	if (map && civilization && civilization != "none" && map.is_faction_leader(src, civilization))
		return 1.5
	return 0

/mob/living/human/proc/leader_order_whistle()
	for (var/obj/item/weapon/whistle/W in contents)
		return W
	for (var/obj/item/clothing/C in contents)
		for (var/obj/item/weapon/whistle/W in C.contents)
			return W
	return null

/mob/living/human/proc/is_order_ally(mob/living/human/H)
	if (H == src)
		return TRUE
	if (map && map.civilizations)
		return civilization != "none" && H.civilization == civilization
	return faction_text && H.faction_text == faction_text

/proc/leader_order_shout(order)
	switch (order)
		if (LEADER_ORDER_MOVE)
			return pick("Forward!", "Advance!", "Move, move, move!", "On me!", "Double time!", "Go, go, go!", "Keep moving!")
		if (LEADER_ORDER_HOLD)
			return pick("Hold the line!", "Stand fast!", "Hold your ground!", "Not one step back!", "Dig in!", "Steady, hold!")
		if (LEADER_ORDER_FOCUS)
			return pick("Aim carefully!", "Pick your targets!", "Steady your aim!", "Make every shot count!", "Focus fire!")

/proc/leader_order_effect_text(order)
	switch (order)
		if (LEADER_ORDER_MOVE)
			return "you run faster"
		if (LEADER_ORDER_HOLD)
			return "you feel less pain"
		if (LEADER_ORDER_FOCUS)
			return "your aim is steadier"

/mob/living/human/verb/issue_order_verb()
	set name = "Issue Order"
	set desc = "Give an order to nearby allies: Move, Hold or Focus."
	set category = "IC"
	var/order = WWinput(src, "Move: allies run faster. Hold: allies feel less pain. Focus: allies aim steadier. A whistle makes orders stronger and carry further.", "Issue Order", "Cancel", list("Cancel", "Move", "Hold", "Focus"))
	if (order == "Cancel" || !order)
		return
	issue_leader_order(lowertext(order))

// Returns the number of allies (including the leader) who received the order.
/mob/living/human/proc/issue_leader_order(order)
	if (!(order in list(LEADER_ORDER_MOVE, LEADER_ORDER_HOLD, LEADER_ORDER_FOCUS)))
		return 0
	var/strength = leader_order_strength()
	if (strength <= 0)
		to_chat(src, SPAN_WARNING("Only squad leaders, officers, commanders and faction leaders can give orders."))
		return 0
	if (stat != CONSCIOUS)
		to_chat(src, SPAN_WARNING("You cannot give an order in your current state."))
		return 0
	if (world.time < leader_order_ready_at)
		to_chat(src, SPAN_WARNING("You gave an order recently. You can give another in [round((leader_order_ready_at - world.time) / 10)] seconds."))
		return 0

	var/order_range = LEADER_ORDER_RANGE
	var/cooldown = LEADER_ORDER_COOLDOWN
	var/obj/item/weapon/whistle/W = leader_order_whistle()
	if (W)
		strength += 1
		order_range += LEADER_ORDER_WHISTLE_RANGE
		cooldown += LEADER_ORDER_WHISTLE_COOLDOWN
	strength = min(strength, LEADER_ORDER_MAX_STRENGTH)
	var/duration = (strength + 1) * 10 SECONDS
	leader_order_ready_at = world.time + cooldown

	say(leader_order_shout(order))
	if (W)
		playsound(get_turf(src), W.whistle_sound, 100, FALSE, 5)

	var/count = 0
	var/turf/T = get_turf(src)
	var/list/hit = list()
	for (var/mob/living/human/H in range(order_range, T))
		hit |= H
	hit |= src
	for (var/mob/living/human/H in hit)
		if (H.stat == DEAD || !is_order_ally(H))
			continue
		H.receive_leader_order(order, strength, duration, src)
		count++
	return count

/mob/living/human/proc/receive_leader_order(order, strength, duration, mob/living/human/leader)
	var/until = world.time + duration
	switch (order)
		if (LEADER_ORDER_MOVE)
			if (world.time >= order_move_until || strength >= order_move_strength)
				order_move_strength = strength
			order_move_until = max(order_move_until, until)
			last_run_delay = -1 // recalculate the cached run speed now
		if (LEADER_ORDER_HOLD)
			if (world.time >= order_hold_until || strength >= order_hold_strength)
				order_hold_strength = strength
			order_hold_until = max(order_hold_until, until)
		if (LEADER_ORDER_FOCUS)
			if (world.time >= order_focus_until || strength >= order_focus_strength)
				order_focus_strength = strength
			order_focus_until = max(order_focus_until, until)
	if (leader == src)
		to_chat(src, SPAN_NOTICE("You order your allies to [order]. For [round(duration / 10)] seconds, [leader_order_effect_text(order)]."))
	else
		to_chat(src, SPAN_NOTICE("[leader] orders you to [order]! For [round(duration / 10)] seconds, [leader_order_effect_text(order)]."))

// Multiplier on running delay: up to 12% faster.
/mob/living/human/proc/leader_order_move_mult()
	if (world.time >= order_move_until)
		return 1
	return 1 - 0.04 * order_move_strength

// Multiplier on traumatic shock: up to 30% less pain.
/mob/living/human/proc/leader_order_hold_mult()
	if (world.time >= order_hold_until)
		return 1
	return 1 - 0.1 * order_hold_strength

// Multiplier on aim spread: up to 30% tighter.
/mob/living/proc/leader_order_focus_mult()
	return 1

/mob/living/human/leader_order_focus_mult()
	if (world.time >= order_focus_until)
		return 1
	return 1 - 0.1 * order_focus_strength

#undef LEADER_ORDER_MOVE
#undef LEADER_ORDER_HOLD
#undef LEADER_ORDER_FOCUS
#undef LEADER_ORDER_RANGE
#undef LEADER_ORDER_WHISTLE_RANGE
#undef LEADER_ORDER_COOLDOWN
#undef LEADER_ORDER_WHISTLE_COOLDOWN
#undef LEADER_ORDER_MAX_STRENGTH
