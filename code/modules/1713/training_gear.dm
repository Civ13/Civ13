// Lifting weights: stones in three sizes, bronze hand weights and the Modern
// barbell. Held in the hand; one use starts a session of lifts that runs until
// the lifter stops or tires, and three lifts make a set. A weight that is too heavy slips, one that is too light teaches
// little, and hauling a heavy one about is a workout of its own.
#define LIFT_SET_REPS 3
#define LIFT_HEAVE_TIME 8
#define LIFT_HOLD_TIME 12
#define CARRY_SET_TILES 40

/obj/item/weapon/lifting_weight
	name = "small lifting stone"
	desc = "A water-worn cobble of a size to lift in one hand."
	icon = 'icons/obj/training.dmi'
	icon_state = "lifting_stone_small"
	item_state = "lifting_stone_small"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_training.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_training.dmi',
		)
	w_class = ITEM_SIZE_NORMAL
	force = 8
	throwforce = 10
	throw_range = 4
	attack_verb = list("bashed", "struck")
	// Strength (1.0 is 100) below which the weight slips from the hands.
	var/lift_need = 10
	// Strength at which it has become too light to teach much; 0 for never.
	var/outgrown = 80
	var/skill_cap = 100
	var/reward_rate = 0.005
	var/both_hands = FALSE
	var/carry_trains = FALSE
	var/tmp/reps = 0
	var/tmp/lifting = FALSE
	var/tmp/carry_tiles = 0
	// Set when a session has told the lifter they are worn out.
	var/tmp/winded = FALSE

/obj/item/weapon/lifting_weight/heavy
	name = "heavy lifting stone"
	desc = "A quarried stone with a groove pecked round its middle for the fingers. It takes both hands."
	icon_state = "lifting_stone_heavy"
	item_state = "lifting_stone_heavy"
	w_class = ITEM_SIZE_LARGE
	force = 12
	throwforce = 14
	throw_range = 2
	slowdown = 0.5
	lift_need = 70
	outgrown = 105
	skill_cap = 115
	both_hands = TRUE
	carry_trains = TRUE

/obj/item/weapon/lifting_weight/great
	name = "great lifting stone"
	desc = "A granite boulder with two hand holds pecked into its flanks. Whoever lifts this is full grown in strength."
	icon_state = "lifting_stone_great"
	item_state = "lifting_stone_great"
	w_class = ITEM_SIZE_HUGE
	force = 15
	throwforce = 18
	throw_range = 1
	slowdown = 1.2
	lift_need = 95
	outgrown = 0
	skill_cap = 125
	both_hands = TRUE
	carry_trains = TRUE

/obj/item/weapon/lifting_weight/hand_weights
	name = "bronze hand weights"
	desc = "A pair of cast bronze weights with a grip between two flared ends. Light to carry, and one hand is enough."
	icon_state = "hand_weights"
	item_state = "hand_weights"
	w_class = ITEM_SIZE_SMALL
	force = 6
	throwforce = 8
	lift_need = 40
	outgrown = 0
	skill_cap = 125

/obj/item/weapon/lifting_weight/barbell
	name = "iron barbell"
	desc = "A machined bar loaded with iron plates. It takes both hands and trains further than any stone."
	icon_state = "barbell"
	item_state = "barbell"
	w_class = ITEM_SIZE_HUGE
	force = 14
	throwforce = 12
	throw_range = 1
	slowdown = 1
	lift_need = 90
	outgrown = 0
	skill_cap = 150
	reward_rate = 0.006
	both_hands = TRUE
	carry_trains = TRUE

/obj/item/weapon/lifting_weight/persistence_runtime_var(key)
	return (key in list("reps", "lifting", "carry_tiles", "winded")) || ..()

// How the weight sits against the holder's strength: -1 too heavy, 0 right, 1 too light.
/obj/item/weapon/lifting_weight/proc/heft_for(mob/living/human/H)
	var/strength = H.stats["strength"][1]
	if (strength < lift_need)
		return -1
	if (outgrown && strength >= outgrown)
		return 1
	return 0

/obj/item/weapon/lifting_weight/examine(mob/user, distance = -1)
	. = ..()
	var/mob/living/human/H = user
	if (!istype(H))
		return
	to_chat(H, "Hold it and use it in your hand to start lifting; you keep lifting until you stop or tire, and every three lifts make a set.[carry_trains ? " Carrying it about also trains strength and stamina." : ""]")
	if (H.stats["strength"][1] >= skill_cap)
		to_chat(H, "<span class='notice'>You have grown past anything this can teach you.</span>")
		return
	switch (heft_for(H))
		if (-1)
			to_chat(H, "<span class='warning'>It looks too heavy for you yet; it may slip from your hands.</span>")
		if (1)
			to_chat(H, "<span class='notice'>It looks light for you now. Something heavier would teach you more.</span>")
		else
			to_chat(H, "<span class='notice'>It looks a good weight for you.</span>")

/obj/item/weapon/lifting_weight/proc/end_set()
	reps = 0

/obj/item/weapon/lifting_weight/proc/in_hand_of(mob/living/human/H)
	return istype(H) && loc == H && (H.l_hand == src || H.r_hand == src)

/obj/item/weapon/lifting_weight/proc/lift_state(raised)
	item_state = raised ? "[initial(item_state)]_lift" : initial(item_state)
	var/mob/living/human/H = loc
	if (istype(H))
		H.update_inv_l_hand()
		H.update_inv_r_hand()

/obj/item/weapon/lifting_weight/dropped(mob/user)
	. = ..()
	if (item_state != initial(item_state))
		item_state = initial(item_state)
	var/mob/living/human/H = user
	if (istype(H) && H.exercise_equipment == src)
		H.cancel_exercise()

// Whether H can lift this at all, with the reason when asked.
/obj/item/weapon/lifting_weight/proc/lift_refusal(mob/living/human/H)
	if (H.stat != CONSCIOUS || H.lying || H.restrained() || !H.can_use_hands())
		return "You must be on your feet with your hands free to lift."
	if (!isturf(H.loc))
		return "You need room to lift."
	if (!exercise_recipe_era(type))
		return "Nobody has worked out how to train with this yet."
	if (both_hands && H.get_inactive_hand())
		return "[capitalize(name)] takes both hands. Empty your other hand first."
	if (H.exercise_equipment && H.exercise_equipment != src)
		return "Finish what you are doing or use Stop Exercise first."
	if (H.stats["strength"][1] < 10)
		return "You are too weak to lift anything."
	return null

/obj/item/weapon/lifting_weight/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !in_hand_of(H))
		return
	if (lifting)
		// Using it again ends the session after the lift in hand.
		if (H.exercise_equipment == src)
			H.cancel_exercise()
		to_chat(H, "<span class='notice'>You finish this lift and set \the [src] down.</span>")
		return
	var/refusal = lift_refusal(H)
	if (!refusal)
		refusal = H.exercise_need_refusal()
	if (!refusal && !H.training_has_stamina(LIFT_HEAVE_TIME + LIFT_HOLD_TIME, TRUE))
		refusal = "You are too out of breath to train. Rest a little first."
	if (refusal)
		to_chat(H, "<span class='warning'>[refusal]</span>")
		return
	train(H)

/obj/item/weapon/lifting_weight/proc/lift_wait(mob/living/human/H, duration)
	return do_after(H, duration, H, TRUE, FALSE)

// Percent chance the weight slips: nothing once strong enough, more the weaker.
/obj/item/weapon/lifting_weight/proc/fumble_chance(mob/living/human/H)
	var/short = lift_need - H.stats["strength"][1]
	return short > 0 ? clamp(short * 3, 15, 90) : 0

// One use starts a session: lift after lift, a set every LIFT_SET_REPS, until
// the lifter stops, moves, lets go or runs out of breath.
/obj/item/weapon/lifting_weight/proc/train(mob/living/human/H)
	H.cancel_exercise()
	H.exercise_equipment = src
	var/token = ++H.exercise_token
	reps = 0
	winded = FALSE
	lifting = TRUE
	H.visible_message("<span class='notice'>[H] plants their feet and starts lifting \the [src].</span>", "<span class='notice'>You plant your feet and start lifting \the [src]; every [LIFT_SET_REPS] lifts make a set. You will keep going until you tire. Use it again, move or use Stop Exercise to stop.</span>")
	var/stop_reason = null
	while (isnull(stop_reason))
		stop_reason = lift(H, token)
	lifting = FALSE
	lift_state(FALSE)
	reps = 0
	if (H.exercise_token == token)
		H.exercise_equipment = null
		H.exercise_token++
	if (stop_reason)
		to_chat(H, "<span class='warning'>[stop_reason]</span>")

// One lift of a session: null to carry on, or why it ended ("" when the
// player ended it and has already been told).
/obj/item/weapon/lifting_weight/proc/lift(mob/living/human/H, token)
	if (H.exercise_token != token || QDELETED(H))
		return ""
	if (!in_hand_of(H))
		return "You stop lifting."
	var/refusal = lift_refusal(H)
	if (refusal)
		return refusal
	var/duration = LIFT_HEAVE_TIME + LIFT_HOLD_TIME
	if (!H.training_has_stamina(duration))
		return "You are out of breath and set \the [src] down."
	var/turf/start = H.loc
	var/ok = lift_wait(H, LIFT_HEAVE_TIME) && H.exercise_token == token && in_hand_of(H) && H.loc == start
	if (ok && prob(fumble_chance(H)))
		lifting = FALSE
		H.visible_message("<span class='warning'>[H] strains at \the [src] and it slips from their hands.</span>", "<span class='warning'>\The [src] is too heavy for you yet. It slips from your hands.</span>")
		H.drop_from_inventory(src)
		return ""
	if (ok)
		lift_state(TRUE)
		ok = lift_wait(H, LIFT_HOLD_TIME) && H.exercise_token == token && in_hand_of(H) && H.loc == start
	lift_state(FALSE)
	if (H.exercise_token != token)
		return ""
	if (!ok)
		return in_hand_of(H) ? "You lose the lift and stop." : "You stop lifting."
	H.training_spend_stamina(duration)
	if (++reps < LIFT_SET_REPS)
		if (prob(10))
			H.visible_message("<span class='notice'>[H] grunts and heaves \the [src] overhead.</span>")
		return null
	reps = 0
	return finish_set(H)

// A finished set pays strength unless the lifter is worn out; null to carry on.
/obj/item/weapon/lifting_weight/proc/finish_set(mob/living/human/H)
	var/refusal = H.exercise_need_refusal()
	if (refusal)
		return "Set done, but it taught you nothing. [refusal]"
	if (H.exercise_fatigued())
		if (!winded)
			winded = TRUE
			to_chat(H, "<span class='warning'>You are worn out: your sets teach nothing until you recover a little (about a minute). You keep lifting.</span>")
		return null
	winded = FALSE
	var/light = heft_for(H) > 0
	if (!H.exercise_reward("strength", reward_rate, skill_cap, (light ? 0.25 : 1) * TRAINING_SET_SCALE))
		return "You have grown past anything \the [src] can teach you."
	H.exercise_spend(TRAINING_SET_FATIGUE)
	to_chat(H, "<span class='notice'>Set done. [light ? "\The [src] is light for you now and taught you little. " : ""]Fatigue: [H.exercise_fatigue]/6.</span>")
	return null

// Called for each tile a human walks onto with a weight in hand (turf/Entered).
/mob/living/human/proc/exercise_carry_step()
	var/obj/item/weapon/lifting_weight/W = l_hand
	if (!istype(W) || !W.carry_trains)
		W = r_hand
	if (istype(W) && W.carry_trains)
		W.carried_step(src)

/obj/item/weapon/lifting_weight/proc/carried_step(mob/living/human/H)
	if (H.stat != CONSCIOUS || H.lying || H.buckled || !isturf(H.loc))
		return
	if (++carry_tiles < CARRY_SET_TILES)
		return
	carry_tiles = 0
	if (!exercise_recipe_era(type) || H.exercise_refusal())
		return
	var/strong = H.exercise_reward("strength", reward_rate * 0.6, skill_cap)
	var/hardy = H.exercise_reward("stamina", reward_rate * 0.6, skill_cap)
	if (!strong && !hardy)
		return
	H.exercise_spend(1)
	to_chat(H, "<span class='notice'>Hauling \the [src] has worked your back and legs. Fatigue: [H.exercise_fatigue]/6.</span>")

#undef LIFT_SET_REPS
#undef LIFT_HEAVE_TIME
#undef LIFT_HOLD_TIME
#undef CARRY_SET_TILES
