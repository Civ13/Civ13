// Running in place: the wooden tread wheel and the Modern treadmill, plus the
// skipping rope. Step into a wheel, face along it and hold the forward key:
// you stay on your tile, the wheel turns and every stride counts. Strides at
// a run train dexterity and stamina, strides at a walk a little stamina. Any
// other direction steps off that way. The skipping rope is used in the hand
// like a lifting weight. All three share the fatigue in active_training.dm.
//
// This replaced the obstacle course; the course pieces still standing in old
// saves turn into a tread wheel or the material they were built from.
#define TREAD_SET_STRIDES 40
#define TREAD_PAUSE 50
#define TREAD_SET_WINDOW 1200
#define SKIP_SET_REPS 6
#define SKIP_TIME 20

/obj/structure/treadwheel
	name = "tread wheel"
	desc = "A great slatted wheel on a timber frame, turned by whoever walks inside it."
	icon = 'icons/obj/training.dmi'
	icon_state = "treadwheel"
	anchored = TRUE
	density = TRUE
	can_buckle = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/skill_cap = 125
	var/reward_rate = 0.005
	var/turning_state = "treadwheel_turning"
	var/tmp/strides = 0
	var/tmp/run_strides = 0
	var/tmp/last_stride = 0

/obj/structure/treadwheel/treadmill
	name = "treadmill"
	desc = "A rubber belt running over a steel deck, with a rail to hold at the front. It trains further than any wheel."
	icon_state = "treadmill"
	turning_state = "treadmill_running"
	skill_cap = 150
	reward_rate = 0.006

/obj/structure/treadwheel/persistence_runtime_var(key)
	return (key in list("strides", "run_strides", "last_stride")) || ..()

/obj/structure/treadwheel/after_load()
	. = ..()
	update_icon()

/obj/structure/treadwheel/update_icon()
	icon_state = buckled_mob ? turning_state : initial(icon_state)
	overlays.Cut()
	var/front = front_state()
	if (front)
		var/image/I = image(icon, front)
		I.layer = MOB_LAYER + 0.1
		overlays += I

// What stands in front of the runner and draws over them; nothing by default.
/obj/structure/treadwheel/proc/front_state()
	return null

// Facing the viewer, the treadmill's rail and console are in front of the runner.
/obj/structure/treadwheel/treadmill/front_state()
	return buckled_mob && dir == SOUTH ? "treadmill_front" : null

/obj/structure/treadwheel/set_dir(new_dir)
	. = ..()
	update_icon()

/obj/structure/treadwheel/examine(mob/user, distance = -1)
	. = ..()
	to_chat(user, "Click it to step in. Face along it and hold the forward key to stride in place; [TREAD_SET_STRIDES] strides make a set. Running trains dexterity and stamina, walking only a little stamina. Any other direction steps off.")
	if (!exercise_recipe_era(type))
		to_chat(user, "<span class='warning'>Nobody has worked out how to train on this yet.</span>")

/obj/structure/treadwheel/verb/turn_wheel()
	set name = "Turn Around"
	set category = null
	set src in oview(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || H.restrained() || buckled_mob)
		return
	set_dir(turn(dir, 90))
	to_chat(H, "You turn \the [src].")

/obj/structure/treadwheel/attack_hand(mob/user)
	var/mob/living/human/H = user
	if (!istype(H))
		return
	if (buckled_mob == H)
		step_off(H, turn(dir, 180))
		return
	if (buckled_mob)
		to_chat(H, "<span class='warning'>[buckled_mob] is already on \the [src].</span>")
		return
	step_in(H)

/obj/structure/treadwheel/MouseDrop_T(mob/living/M, mob/living/user)
	if (M == user)
		attack_hand(user)

// Whether H can step in now, with the reason when not.
/obj/structure/treadwheel/proc/step_in_refusal(mob/living/human/H)
	if (H.stat != CONSCIOUS || H.lying || H.restrained() || H.buckled || !isturf(H.loc))
		return "You must be on your feet and free to train."
	if (H.z != z || get_dist(H, src) > 1)
		return "You are too far away."
	if (!exercise_recipe_era(type))
		return "Nobody has worked out how to train on this yet."
	if (H.exercise_equipment)
		return "Finish what you are doing or use Stop Exercise first."
	for (var/atom/movable/A in loc)
		if (A != src && A.density && A != H)
			return "Something is in the way."
	return null

/obj/structure/treadwheel/proc/step_in(mob/living/human/H)
	var/refusal = step_in_refusal(H)
	if (refusal)
		to_chat(H, "<span class='warning'>[refusal]</span>")
		return FALSE
	H.forceMove(loc)
	if (!buckle_mob(H))
		return FALSE
	strides = 0
	run_strides = 0
	last_stride = 0
	H.visible_message("<span class='notice'>[H] steps onto \the [src].</span>", "<span class='notice'>You step onto \the [src]. Hold the key for [dir2text(dir)] to stride; any other direction steps off.</span>")
	return TRUE

/obj/structure/treadwheel/proc/step_off(mob/living/human/H, direction)
	if (buckled_mob != H)
		return FALSE
	unbuckle_mob()
	var/turf/T = get_step(src, direction)
	if (T)
		step(H, direction)
	H.visible_message("<span class='notice'>[H] steps off \the [src].</span>", "<span class='notice'>You step off \the [src].</span>")
	return TRUE

// Buckling and unbuckling both pass here, whoever does it (resisting, the
// wheel coming down): keep the turning picture and the set in step.
/obj/structure/treadwheel/post_buckle_mob(mob/living/M)
	update_icon()
	var/mob/living/human/H = M
	if (istype(H) && H.buckled != src && H.exercise_equipment == src)
		H.cancel_exercise()

// The client sends the rider's movement keys here (mob_movement.dm).
/obj/structure/treadwheel/relaymove(mob/user, direction)
	var/mob/living/human/H = user
	if (!istype(H) || buckled_mob != H || H.stat != CONSCIOUS)
		return FALSE
	if (direction == dir)
		return stride(H)
	return step_off(H, direction)

/obj/structure/treadwheel/proc/end_set()
	strides = 0
	run_strides = 0
	last_stride = 0

/obj/structure/treadwheel/proc/stride(mob/living/human/H)
	if (H.restrained() || H.lying)
		return FALSE
	if (H.exercise_equipment != src)
		if (H.exercise_equipment)
			to_chat(H, "<span class='warning'>Finish what you are doing or use Stop Exercise first.</span>")
			return FALSE
		end_set()
		H.hold_exercise(src, TREAD_SET_WINDOW)
	var/now = exercise_time()
	if (strides && now - last_stride > TREAD_PAUSE)
		end_set()
		to_chat(H, "<span class='notice'>You slowed to a stop; the set starts over.</span>")
	last_stride = now
	strides++
	if (H.m_intent == "run")
		run_strides++
	animate(H, pixel_y = 1, time = 1, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(pixel_y = -1, time = 1, flags = ANIMATION_RELATIVE)
	if (strides >= TREAD_SET_STRIDES)
		finish_set(H)
	else if (!(strides % 10))
		to_chat(H, "<span class='notice'>[strides]/[TREAD_SET_STRIDES] strides.</span>")
	return TRUE

/obj/structure/treadwheel/proc/finish_set(mob/living/human/H)
	var/running = strides ? run_strides / strides : 0
	H.exercise_equipment = null
	H.exercise_token++
	end_set()
	var/refusal = H.exercise_refusal()
	if (refusal)
		to_chat(H, "<span class='warning'>Set done, but it taught you nothing. [refusal]</span>")
		return FALSE
	var/nimble = running > 0 && H.exercise_reward("dexterity", reward_rate, skill_cap, running)
	var/hardy = H.exercise_reward("stamina", reward_rate, skill_cap, 0.5 + running * 0.5)
	if (!nimble && !hardy)
		to_chat(H, "<span class='notice'>Set done. You have grown past anything \the [src] can teach you.</span>")
		return FALSE
	H.exercise_spend(2)
	H.visible_message("<span class='notice'>[H] slows on \the [src], breathing hard.</span>", "<span class='notice'>Set done. [running >= 0.5 ? "" : "Running would have taught you more. "]Fatigue: [H.exercise_fatigue]/6.</span>")
	return TRUE

// --- skipping rope ---------------------------------------------------------

/obj/item/weapon/skipping_rope
	name = "skipping rope"
	desc = "A length of rope with a turned wooden handle at each end."
	icon = 'icons/obj/training.dmi'
	icon_state = "skipping_rope"
	item_state = "skipping_rope"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_training.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_training.dmi',
		)
	w_class = ITEM_SIZE_SMALL
	force = 2
	throwforce = 2
	attack_verb = list("whipped", "lashed")
	var/skill_cap = 125
	var/reward_rate = 0.005
	var/tmp/skips = 0
	var/tmp/skipping = FALSE
	var/tmp/winded = FALSE

/obj/item/weapon/skipping_rope/persistence_runtime_var(key)
	return (key in list("skips", "skipping", "winded")) || ..()

/obj/item/weapon/skipping_rope/examine(mob/user, distance = -1)
	. = ..()
	to_chat(user, "Hold it and use it in your hand to start skipping; you keep skipping until you stop or tire, and [SKIP_SET_REPS] skips make a set. It trains dexterity and some stamina, and takes both hands.")

/obj/item/weapon/skipping_rope/proc/end_set()
	skips = 0

/obj/item/weapon/skipping_rope/proc/in_hand_of(mob/living/human/H)
	return istype(H) && loc == H && (H.l_hand == src || H.r_hand == src)

/obj/item/weapon/skipping_rope/proc/swing_state(raised)
	item_state = raised ? "skipping_rope_lift" : "skipping_rope"
	var/mob/living/human/H = loc
	if (istype(H))
		H.update_inv_l_hand()
		H.update_inv_r_hand()

/obj/item/weapon/skipping_rope/dropped(mob/user)
	. = ..()
	item_state = "skipping_rope"
	var/mob/living/human/H = user
	if (istype(H) && H.exercise_equipment == src)
		H.cancel_exercise()

/obj/item/weapon/skipping_rope/proc/skip_refusal(mob/living/human/H)
	if (H.stat != CONSCIOUS || H.lying || H.restrained() || H.buckled || !H.can_use_hands())
		return "You must be on your feet with your hands free to skip."
	if (!isturf(H.loc))
		return "You need room to skip."
	if (H.get_inactive_hand())
		return "Skipping takes both hands. Empty your other hand first."
	if (H.exercise_equipment && H.exercise_equipment != src)
		return "Finish what you are doing or use Stop Exercise first."
	return null

/obj/item/weapon/skipping_rope/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !in_hand_of(H))
		return
	if (skipping)
		// Using it again ends the session after the skip in progress.
		if (H.exercise_equipment == src)
			H.cancel_exercise()
		to_chat(H, "<span class='notice'>You finish this skip and coil up \the [src].</span>")
		return
	var/refusal = skip_refusal(H)
	if (!refusal)
		refusal = H.exercise_need_refusal()
	if (!refusal && !H.training_has_stamina(SKIP_TIME, TRUE))
		refusal = "You are too out of breath to train. Rest a little first."
	if (refusal)
		to_chat(H, "<span class='warning'>[refusal]</span>")
		return
	train(H)

/obj/item/weapon/skipping_rope/proc/skip_wait(mob/living/human/H, duration)
	return do_after(H, duration, H, TRUE, FALSE)

// One use starts a session: skip after skip, a set every SKIP_SET_REPS, until
// the skipper stops, moves, lets go or runs out of breath.
/obj/item/weapon/skipping_rope/proc/train(mob/living/human/H)
	H.cancel_exercise()
	H.exercise_equipment = src
	var/token = ++H.exercise_token
	skips = 0
	winded = FALSE
	skipping = TRUE
	H.visible_message("<span class='notice'>[H] takes a handle in each hand and starts skipping.</span>", "<span class='notice'>You take a handle in each hand and start skipping; every [SKIP_SET_REPS] skips make a set. You will keep going until you tire. Use it again, move or use Stop Exercise to stop.</span>")
	var/stop_reason = null
	while (isnull(stop_reason))
		stop_reason = skip(H, token)
	skipping = FALSE
	swing_state(FALSE)
	skips = 0
	if (H.exercise_token == token)
		H.exercise_equipment = null
		H.exercise_token++
	if (stop_reason)
		to_chat(H, "<span class='warning'>[stop_reason]</span>")

// One skip of a session: null to carry on, or why it ended ("" when the
// player ended it and has already been told).
/obj/item/weapon/skipping_rope/proc/skip(mob/living/human/H, token)
	if (H.exercise_token != token || QDELETED(H))
		return ""
	if (!in_hand_of(H))
		return "You stop skipping."
	var/refusal = skip_refusal(H)
	if (refusal)
		return refusal
	if (!H.training_has_stamina(SKIP_TIME))
		return "You are out of breath and coil up \the [src]."
	swing_state(TRUE)
	animate(H, pixel_y = 3, time = 2, loop = 4, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(pixel_y = -3, time = 3, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_RELATIVE)
	var/turf/start = H.loc
	var/ok = skip_wait(H, SKIP_TIME) && H.exercise_token == token && in_hand_of(H) && H.loc == start
	if (H.exercise_token != token)
		return ""
	if (!ok)
		return in_hand_of(H) ? "You tangle your feet in the rope and stop." : "You stop skipping."
	H.training_spend_stamina(SKIP_TIME)
	if (++skips < SKIP_SET_REPS)
		return null
	skips = 0
	return finish_set(H)

// A finished set pays dexterity and some stamina unless the skipper is worn
// out; null to carry on.
/obj/item/weapon/skipping_rope/proc/finish_set(mob/living/human/H)
	var/refusal = H.exercise_need_refusal()
	if (refusal)
		return "Set done, but it taught you nothing. [refusal]"
	if (H.exercise_fatigued())
		if (!winded)
			winded = TRUE
			to_chat(H, "<span class='warning'>You are worn out: your sets teach nothing until you recover a little (about a minute). You keep skipping.</span>")
		return null
	winded = FALSE
	var/nimble = H.exercise_reward("dexterity", reward_rate, skill_cap)
	var/hardy = H.exercise_reward("stamina", reward_rate, skill_cap, 0.5)
	if (!nimble && !hardy)
		return "You have grown past anything \the [src] can teach you."
	H.exercise_spend(2)
	to_chat(H, "<span class='notice'>Set done. Fatigue: [H.exercise_fatigue]/6.</span>")
	return null

// --- the old obstacle course -----------------------------------------------
// Pieces built before the tread wheel turn into one (start posts) or into the
// material they were built from, where they stand.

/obj/structure/training_course
	name = "old course obstacle"
	desc = "Part of an old obstacle course. Touch it to clear it away."
	icon = 'icons/obj/training.dmi'
	icon_state = "log_hurdle"
	anchored = TRUE
	density = FALSE
	var/replacement = /obj/item/stack/material/wood
	var/amount = 3

/obj/structure/training_course/post
	icon_state = "course_start"
	replacement = /obj/structure/treadwheel
	amount = 0

/obj/structure/training_course/post/finish
	icon_state = "course_finish"
	replacement = /obj/item/stack/material/wood
	amount = 3

/obj/structure/training_course/hurdle
	icon_state = "log_hurdle"

/obj/structure/training_course/hurdle/steel
	icon_state = "steel_hurdle"
	replacement = /obj/item/stack/material/steel

/obj/structure/training_course/balance_log
	icon_state = "balance_log"
	amount = 4

/obj/structure/training_course/after_load()
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(replace_legacy)), 10)

/obj/structure/training_course/attack_hand(mob/user)
	replace_legacy()

/obj/structure/training_course/proc/replace_legacy()
	if (QDELETED(src) || !isturf(loc))
		return
	if (amount)
		new replacement(loc, amount)
	else
		var/atom/A = new replacement(loc)
		A.set_dir(dir)
	qdel(src)

#undef TREAD_SET_STRIDES
#undef TREAD_PAUSE
#undef TREAD_SET_WINDOW
#undef SKIP_SET_REPS
#undef SKIP_TIME
