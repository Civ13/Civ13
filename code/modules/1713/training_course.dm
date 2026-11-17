// The obstacle course: a start post, hurdles and balance logs laid out however
// the builder likes, and a finish post (or the start post again, for a loop).
// Touch the start post, clear the obstacles at a run, touch a post to finish.
// The run pays dexterity and stamina by obstacles cleared and by pace, and the
// start post keeps the best time.
#define COURSE_RUN_LIMIT 1800
#define COURSE_MIN_OBSTACLES 3
#define COURSE_FULL_OBSTACLES 6
#define COURSE_MAX_OBSTACLES 8
#define COURSE_SPACING 2
#define COURSE_STEEL_FOR_MODERN 3

/datum/course_run
	var/mob/living/human/runner
	var/obj/structure/training_course/post/start
	var/started = 0
	var/list/cleared = list()
	var/obj/structure/training_course/last
	var/stumbles = 0
	var/steel = 0

/datum/course_run/proc/end_run()
	runner = null
	start = null
	last = null
	cleared = list()

/mob/living/human/proc/course_run()
	var/datum/course_run/R = exercise_equipment
	return istype(R) ? R : null

/obj/structure/training_course
	name = "course obstacle"
	icon = 'icons/obj/training.dmi'
	anchored = TRUE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/steel = FALSE

// Count this obstacle for a runner who has just cleared it.
/obj/structure/training_course/proc/credit(mob/living/human/H)
	var/datum/course_run/R = H.course_run()
	if (!R || (src in R.cleared))
		return FALSE
	if (R.last && R.last.z == z && get_dist(R.last, src) < COURSE_SPACING)
		to_chat(H, "<span class='warning'>That one stands too close to the last to count. Obstacles need a clear tile between them.</span>")
		return FALSE
	R.cleared += src
	R.last = src
	if (steel)
		R.steel++
	to_chat(H, "<span class='notice'>Cleared! [R.cleared.len] so far.</span>")
	return TRUE

/obj/structure/training_course/proc/stumble(mob/living/human/H, others, self)
	var/datum/course_run/R = H.course_run()
	if (R)
		R.stumbles++
	H.Weaken(2)
	H.visible_message("<span class='warning'>[H] [others]</span>", "<span class='warning'>[self]</span>")

/obj/structure/training_course/verb/turn_obstacle()
	set name = "Turn Obstacle"
	set category = null
	set src in oview(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || H.restrained() || istype(src, /obj/structure/training_course/post))
		return
	set_dir(turn(dir, 90))
	to_chat(H, "You turn \the [src].")

// --- posts ----------------------------------------------------------------

/obj/structure/training_course/post
	name = "course start post"
	desc = "A post flying a pennant. Touch it to start a run over the course's hurdles and balance logs, and touch it or a finish post to end the run."
	icon_state = "course_start"
	density = TRUE
	var/starts_runs = TRUE
	var/best_time = 0
	var/best_count = 0
	var/best_name = ""

/obj/structure/training_course/post/finish
	name = "course finish post"
	desc = "A post hung with a wreath and ribbons. Touch it to finish a run begun at a start post."
	icon_state = "course_finish"
	starts_runs = FALSE

/obj/structure/training_course/post/examine(mob/user, distance = -1)
	. = ..()
	if (!starts_runs)
		return
	if (best_time)
		to_chat(user, "<span class='notice'>Best run: [course_time_text(best_time)] over [best_count] obstacles, by [best_name].</span>")
	else
		to_chat(user, "<span class='notice'>Nobody has set a time here yet.</span>")

/proc/course_time_text(deciseconds)
	return "[round(deciseconds / 10, 0.1)] seconds"

/obj/structure/training_course/post/Bumped(atom/A)
	. = ..()
	var/mob/living/human/H = A
	if (istype(H) && H.course_run() && H.course_run().cleared.len >= COURSE_MIN_OBSTACLES)
		finish_run(H)

/obj/structure/training_course/post/attack_hand(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || H.z != z || get_dist(H, src) > 1)
		return
	if (H.course_run())
		finish_run(H)
	else if (starts_runs)
		start_run(H)
	else
		to_chat(H, "<span class='notice'>This is where a run ends. Begin at a start post.</span>")

/obj/structure/training_course/post/proc/start_run(mob/living/human/H)
	if (H.stat != CONSCIOUS || H.lying || H.restrained() || !isturf(H.loc))
		to_chat(H, "<span class='warning'>You must be on your feet and free to run the course.</span>")
		return FALSE
	if (H.exercise_equipment)
		to_chat(H, "<span class='warning'>Finish what you are doing or use Stop Exercise first.</span>")
		return FALSE
	var/datum/course_run/R = new
	R.runner = H
	R.start = src
	R.started = exercise_time()
	H.hold_exercise(R, COURSE_RUN_LIMIT)
	H.visible_message("<span class='notice'>[H] slaps \the [src] and sets off.</span>", "<span class='notice'>Go! Clear at least [COURSE_MIN_OBSTACLES] obstacles, then touch a finish post or this one again. Vault hurdles at a run; walk the balance logs.</span>")
	return TRUE

/obj/structure/training_course/post/proc/finish_run(mob/living/human/H)
	var/datum/course_run/R = H.course_run()
	if (!R)
		return FALSE
	var/count = R.cleared.len
	if (count < COURSE_MIN_OBSTACLES)
		to_chat(H, "<span class='warning'>You have cleared [count] of the [COURSE_MIN_OBSTACLES] obstacles a run needs. Keep going, or use Stop Exercise to give up.</span>")
		return FALSE
	var/elapsed = max(1, exercise_time() - R.started)
	var/stumbles = R.stumbles
	var/modern = R.steel >= COURSE_STEEL_FOR_MODERN && map && map.ordinal_age >= 8
	var/obj/structure/training_course/post/origin = R.start
	H.cancel_exercise()
	H.visible_message("<span class='notice'>[H] reaches \the [src], finishing the course in [course_time_text(elapsed)].</span>", "<span class='notice'>Finished: [course_time_text(elapsed)] over [count] obstacles[stumbles ? ", with [stumbles] stumble[stumbles > 1 ? "s" : ""]" : ""].</span>")
	if (origin && !QDELETED(origin))
		origin.record(H, elapsed, count)
	var/refusal = H.exercise_refusal()
	if (refusal)
		to_chat(H, "<span class='warning'>The run taught you nothing. [refusal]</span>")
		return TRUE
	// Pace: 4 seconds an obstacle or better pays half as much again, 12 or worse pays half.
	var/pace = clamp(1.5 - ((elapsed / count) - 40) / 80, 0.5, 1.5)
	var/scale = pace * min(count, COURSE_MAX_OBSTACLES) / COURSE_FULL_OBSTACLES
	var/cap = modern ? 150 : 125
	var/rate = modern ? 0.004 : 0.003
	var/nimble = H.exercise_reward("dexterity", rate, cap, scale)
	var/hardy = H.exercise_reward("stamina", rate, cap, scale)
	if (!nimble && !hardy)
		to_chat(H, "<span class='notice'>You have grown past anything this course can teach you.</span>")
		return TRUE
	H.exercise_spend(2)
	to_chat(H, "<span class='notice'>[pace >= 1.2 ? "A fast run." : pace <= 0.8 ? "A slow run; a quicker one would teach you more." : "A steady run."] Fatigue: [H.exercise_fatigue]/6.</span>")
	return TRUE

// A run over more obstacles always replaces the record; over as many, only a faster one.
/obj/structure/training_course/post/proc/record(mob/living/human/H, elapsed, count)
	if (best_time && (count < best_count || (count == best_count && elapsed >= best_time)))
		return FALSE
	best_time = elapsed
	best_count = count
	best_name = H.real_name
	visible_message("<span class='notice'><b>[H] sets a new best time at \the [src]: [course_time_text(elapsed)] over [count] obstacles!</b></span>")
	return TRUE

// --- hurdles ---------------------------------------------------------------

/obj/structure/training_course/hurdle
	name = "log hurdle"
	desc = "A rail lashed across two forked stakes. Run at it to vault it; at a walk you clamber over."
	icon_state = "log_hurdle"
	density = TRUE
	throwpass = TRUE

/obj/structure/training_course/hurdle/steel
	name = "steel hurdle"
	desc = "A striped board on a steel frame. Run at it to vault it; at a walk you clamber over."
	icon_state = "steel_hurdle"
	steel = TRUE

/obj/structure/training_course/hurdle/proc/landing(mob/living/human/H)
	var/direction = get_dir(get_turf(H), src)
	if (!direction || (direction & (direction - 1)))
		return null
	var/turf/far = get_step(src, direction)
	if (!far || far.density)
		return null
	for (var/atom/movable/A in far)
		if (A.density && A != H)
			return null
	return far

/obj/structure/training_course/hurdle/proc/vault_chance(mob/living/human/H)
	return clamp(30 - H.stats["dexterity"][1] * 0.2, 4, 30)

/obj/structure/training_course/hurdle/proc/clamber_wait(mob/living/human/H)
	return do_after(H, 15, src, FALSE, FALSE)

/obj/structure/training_course/hurdle/Bumped(atom/A)
	. = ..()
	var/mob/living/human/H = A
	if (istype(H))
		vault(H)

/obj/structure/training_course/hurdle/proc/vault(mob/living/human/H)
	if (H.stat != CONSCIOUS || H.lying || H.restrained() || H.buckled || H.z != z || get_dist(H, src) > 1)
		return FALSE
	if (H.course_vault_at > world.time)
		return FALSE
	var/turf/far = landing(H)
	if (!far)
		H.course_vault_at = world.time + 10
		to_chat(H, "<span class='warning'>There is no room to land beyond \the [src] from here.</span>")
		return FALSE
	if (H.m_intent != "run")
		H.course_vault_at = world.time + 20
		var/turf/from = H.loc
		if (!clamber_wait(H) || H.loc != from || QDELETED(src) || landing(H) != far)
			return FALSE
		H.forceMove(far)
		to_chat(H, "<span class='notice'>You clamber over \the [src].</span>")
		credit(H)
		return TRUE
	H.course_vault_at = world.time + 4
	if (prob(vault_chance(H)))
		stumble(H, "clips \the [src] and goes sprawling.", "You clip \the [src] and go sprawling.")
		return FALSE
	H.forceMove(far)
	animate(H, pixel_y = 8, time = 2, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(pixel_y = -8, time = 2, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_RELATIVE)
	credit(H)
	return TRUE

// --- balance log -----------------------------------------------------------

/obj/structure/training_course/balance_log
	name = "balance log"
	desc = "A log on low chocks, its top hewn flat. Walk it; anyone who runs along it is likely to come off."
	icon_state = "balance_log"

/obj/structure/training_course/balance_log/proc/fall_chance(mob/living/human/H)
	var/dexterity = H.stats["dexterity"][1]
	if (H.m_intent == "run")
		return clamp(85 - dexterity * 0.3, 40, 85)
	return clamp(22 - dexterity * 0.15, 2, 22)

/obj/structure/training_course/balance_log/Crossed(atom/movable/A)
	. = ..()
	var/mob/living/human/H = A
	if (!istype(H) || H.stat != CONSCIOUS || H.lying || H.buckled)
		return
	if (prob(fall_chance(H)))
		stumble(H, "loses their footing on \the [src] and tumbles off.", H.m_intent == "run" ? "You run onto \the [src], lose your footing and tumble off. Walk it." : "You wobble on \the [src] and tumble off.")
		return
	credit(H)

#undef COURSE_RUN_LIMIT
#undef COURSE_MIN_OBSTACLES
#undef COURSE_FULL_OBSTACLES
#undef COURSE_MAX_OBSTACLES
#undef COURSE_SPACING
#undef COURSE_STEEL_FOR_MODERN
