// Lifting weights: stones in three sizes, bronze hand weights and the Modern
// barbell. Held in the hand and lifted one repetition per use; six lifts make
// a set. A weight that is too heavy slips, one that is too light teaches
// little, and hauling a heavy one about is a workout of its own.
#define LIFT_SET_REPS 6
#define LIFT_HEAVE_TIME 8
#define LIFT_HOLD_TIME 12
#define LIFT_SET_WINDOW 300
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
	return (key in list("reps", "lifting", "carry_tiles")) || ..()

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
	to_chat(H, "Hold it and use it in your hand to lift it; six lifts make a set.[carry_trains ? " Carrying it about also trains strength and stamina." : ""]")
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
		return
	var/refusal = lift_refusal(H)
	if (refusal)
		to_chat(H, "<span class='warning'>[refusal]</span>")
		return
	lift(H)

/obj/item/weapon/lifting_weight/proc/lift_wait(mob/living/human/H, duration)
	return do_after(H, duration, H, TRUE, FALSE)

// Percent chance the weight slips: nothing once strong enough, more the weaker.
/obj/item/weapon/lifting_weight/proc/fumble_chance(mob/living/human/H)
	var/short = lift_need - H.stats["strength"][1]
	return short > 0 ? clamp(short * 3, 15, 90) : 0

/obj/item/weapon/lifting_weight/proc/lift(mob/living/human/H)
	if (H.exercise_equipment != src)
		reps = 0
		to_chat(H, "<span class='notice'>You plant your feet and take hold of \the [src]. Lift it [LIFT_SET_REPS] times for a set.</span>")
	H.hold_exercise(src, LIFT_SET_WINDOW)
	lifting = TRUE
	var/turf/start = H.loc
	var/ok = lift_wait(H, LIFT_HEAVE_TIME) && in_hand_of(H) && H.loc == start
	if (ok && prob(fumble_chance(H)))
		lifting = FALSE
		H.visible_message("<span class='warning'>[H] strains at \the [src] and it slips from their hands.</span>", "<span class='warning'>\The [src] is too heavy for you yet. It slips from your hands.</span>")
		H.drop_from_inventory(src)
		return FALSE
	if (ok)
		lift_state(TRUE)
		ok = lift_wait(H, LIFT_HOLD_TIME) && in_hand_of(H) && H.loc == start
	lift_state(FALSE)
	lifting = FALSE
	if (!ok || H.exercise_equipment != src)
		if (in_hand_of(H))
			to_chat(H, "<span class='warning'>You lose the lift. Hold still and try that one again.</span>")
		return FALSE
	reps++
	if (reps < LIFT_SET_REPS)
		if (prob(30))
			H.visible_message("<span class='notice'>[H] grunts and heaves \the [src] overhead.</span>", "<span class='notice'>You grunt and heave \the [src] overhead. [reps]/[LIFT_SET_REPS].</span>")
		else
			to_chat(H, "<span class='notice'>Up and down. [reps]/[LIFT_SET_REPS].</span>")
		return TRUE
	finish_set(H)
	return TRUE

/obj/item/weapon/lifting_weight/proc/finish_set(mob/living/human/H)
	H.exercise_equipment = null
	H.exercise_token++
	reps = 0
	var/refusal = H.exercise_refusal()
	if (refusal)
		to_chat(H, "<span class='warning'>Set done, but it taught you nothing. [refusal]</span>")
		return
	var/light = heft_for(H) > 0
	if (!H.exercise_reward("strength", reward_rate, skill_cap, light ? 0.25 : 1))
		to_chat(H, "<span class='notice'>Set done. You have grown past anything \the [src] can teach you.</span>")
		return
	H.exercise_spend(2)
	H.visible_message("<span class='notice'>[H] sets \the [src] down, breathing hard.</span>", "<span class='notice'>Set done. [light ? "\The [src] is light for you now and taught you little. " : ""]Fatigue: [H.exercise_fatigue]/6.</span>")

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
#undef LIFT_SET_WINDOW
#undef CARRY_SET_TILES
