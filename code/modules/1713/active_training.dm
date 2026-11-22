// Training by doing: shared fatigue, rewards, stamina and crafting gates for the
// lifting weights (training_gear.dm), the tread wheel, treadmill and skipping
// rope (training_course.dm), the floor exercises (cmss13_field.dm) and the
// scholar practice tools (scholar_practice.dm). Weights, rope, floor exercises
// and practice tools run continuously once started (TRAINING_STAMINA_DRAIN).
#define EXERCISE_SET_WINDOW 300

/proc/exercise_time()
	return world.time

// Modern gear: the iron barbell and the treadmill.
/proc/exercise_modern_gear(result_type)
	return ispath(result_type, /obj/item/weapon/lifting_weight/barbell) || ispath(result_type, /obj/structure/treadwheel/treadmill)

/proc/exercise_gear(result_type)
	return ispath(result_type, /obj/item/weapon/lifting_weight) || ispath(result_type, /obj/structure/treadwheel) || ispath(result_type, /obj/item/weapon/skipping_rope)

/proc/exercise_recipe_era(result_type)
	return !exercise_modern_gear(result_type) || (map && map.ordinal_age >= 8)

// Crafting skill a piece of training gear asks of its builder.
/proc/exercise_build_skill(result_type)
	if (exercise_modern_gear(result_type))
		return 105
	if (result_type == /obj/item/weapon/lifting_weight || result_type == /obj/item/weapon/skipping_rope)
		return 0
	return 30

/proc/exercise_can_build(mob/living/human/H, result_type)
	if (!exercise_gear(result_type))
		return TRUE
	return H && H.stat == CONSCIOUS && exercise_recipe_era(result_type) && H.getStat("crafting") >= exercise_build_skill(result_type) && map && crafting_node_allowed(H, get_recipe_node_req("[result_type]"))

/mob/living/human
	var/exercise_fatigue = 0
	var/tmp/exercise_rest_epoch = -1
	// The weight, rope or wheel mid-set; anything else is idle.
	var/tmp/datum/exercise_equipment
	var/tmp/exercise_token = 0
	// Fractions of a 0.1% skill step earned but not yet paid, by skill, so
	// small frequent sets add up to the same gain as fewer big ones.
	var/tmp/list/exercise_carry

/mob/living/human/persistence_runtime_var(key)
	return (key in list("exercise_rest_epoch", "exercise_equipment", "exercise_carry", "survival_rest_since", "survival_actions", "survival_workload", "exercise_token")) || ..()

/mob/living/human/proc/recover_exercise()
	var/now = exercise_time()
	if (exercise_rest_epoch < 0 || now < exercise_rest_epoch)
		exercise_rest_epoch = now
	var/rest = round((now - exercise_rest_epoch) / 600)
	if (rest > 0)
		exercise_fatigue = max(0, exercise_fatigue - rest)
		exercise_rest_epoch += rest * 600
	exercise_fatigue = clamp(exercise_fatigue, 0, 6)

/mob/living/human/proc/cancel_exercise()
	var/datum/E = exercise_equipment
	exercise_equipment = null
	exercise_token++
	if (istype(E, /obj/item/weapon/lifting_weight))
		var/obj/item/weapon/lifting_weight/W = E
		W.end_set()
	else if (istype(E, /obj/item/weapon/skipping_rope))
		var/obj/item/weapon/skipping_rope/S = E
		S.end_set()
	else if (istype(E, /obj/structure/treadwheel))
		var/obj/structure/treadwheel/T = E
		T.end_set()

// Hold a set or a run open for `window`, then let it lapse by itself.
/mob/living/human/proc/hold_exercise(datum/E, window = EXERCISE_SET_WINDOW)
	exercise_equipment = E
	exercise_token++
	addtimer(CALLBACK(src, PROC_REF(lapse_exercise), exercise_token), window)

/mob/living/human/proc/lapse_exercise(token)
	if (token != exercise_token || !exercise_equipment)
		return
	cancel_exercise()
	to_chat(src, "<span class='notice'>You have rested too long; your set starts over.</span>")

// Any training session in progress: a weight, rope or wheel set, floor
// exercises or a practice tool.
/mob/living/human/proc/training_in_progress()
	return exercise_equipment || floor_exercise_busy || scholar_practising

/mob/living/human/verb/stop_exercise()
	set name = "Stop Exercise"
	set category = "IC"
	if (!training_in_progress())
		to_chat(src, "You are not training.")
		return
	// Continuous sessions watch exercise_token and end at their next step.
	cancel_exercise()
	to_chat(src, "You stop training.")

// Continuous training: the stamina `duration` deciseconds of it costs.
/mob/living/human/proc/training_stamina_cost(duration)
	return stats["stamina"][2] * TRAINING_STAMINA_DRAIN * duration / 10

// Whether there is breath left for `duration` more deciseconds, or, when
// starting, enough to begin a session at all.
/mob/living/human/proc/training_has_stamina(duration, starting = FALSE)
	var/needed = training_stamina_cost(duration)
	if (starting)
		needed = max(needed, stats["stamina"][2] * TRAINING_STAMINA_START)
	return stats["stamina"][1] >= needed

/mob/living/human/proc/training_spend_stamina(duration)
	stats["stamina"][1] = max(0, stats["stamina"][1] - training_stamina_cost(duration))

// Whether a finished set can pay: hunger, thirst and the skill cap end a
// session, but fatigue only pauses the gains while the session goes on, so a
// long session earns what resting between sets by hand would.
/mob/living/human/proc/exercise_fatigued()
	recover_exercise()
	return exercise_fatigue >= 6

/mob/living/human/proc/exercise_need_refusal()
	if (nutrition < 50)
		return "You are too hungry to keep training."
	if (water < 50)
		return "You are too thirsty to keep training."
	return null

// Whether the body can gain from training now, with the reason when it cannot.
/mob/living/human/proc/exercise_refusal()
	recover_exercise()
	if (exercise_fatigue >= 6)
		return "You are too fatigued to gain anything more. Rest; one fatigue point recovers each minute."
	if (nutrition < 50)
		return "You are too hungry to train."
	if (water < 50)
		return "You are too thirsty to train."
	return null

// One finished set or run: the hunger, thirst and fatigue it costs.
/mob/living/human/proc/exercise_spend(fatigue = 2)
	exercise_fatigue = min(6, exercise_fatigue + fatigue)
	nutrition = max(0, nutrition - 2 * fatigue)
	water = max(0, water - 3 * fatigue)

// Pay one skill. `rate` is the fractional gain before fatigue; gains halve at
// 1.0 and stop at `cap`. Returns FALSE when the skill is already at the cap.
/mob/living/human/proc/exercise_reward(skill, rate, cap, scale = 1)
	var/list/values = stats[skill]
	if (!islist(values) || values[1] < 10 || values[1] >= cap || values[2] >= cap)
		return FALSE
	var/paid = rate * scale * (1 - exercise_fatigue / 8) * (values[2] >= 100 ? 0.5 : 1)
	exercise_pay_steps(skill, paid * 1000, cap)
	return TRUE

// Pay `steps` 0.1% steps of skill (fractions carry over to the next payment),
// clamped to cap. adaptStat rounds to 0.1%; the + 0.001 keeps a binary float
// clear of landing just under the step after its division.
/mob/living/human/proc/exercise_pay_steps(skill, steps, cap)
	if (!islist(exercise_carry))
		exercise_carry = list()
	var/carried = (isnum(exercise_carry[skill]) ? exercise_carry[skill] : 0) + steps
	var/whole = round(carried + 0.00001)
	exercise_carry[skill] = max(0, carried - whole)
	if (whole > 0)
		adaptStat(skill, (whole + 0.001) * (skill == "dexterity" ? 0.1 : 0.15))
	var/list/values = stats[skill]
	values[1] = min(cap, values[1])
	values[2] = min(cap, values[2])
	return whole

// Stack recipe guard: training gear needs its era, research and skill.
/datum/craft_guard/skill_gate/exercise
	order = 20
	message = "This training gear requires its era, completed research and crafting skill."

/datum/craft_guard/skill_gate/exercise/allowed(mob/living/human/H, result_type)
	return exercise_can_build(H, result_type)

// Fixtures placed before the redesign (click-and-wait weights and the square
// course marker) turn into the new gear where they stand.
/obj/structure/exercise
	name = "old training equipment"
	desc = "Worn-out training equipment. Touch it to clear it away for something better."
	icon = 'icons/obj/training.dmi'
	icon_state = "lifting_stone_heavy"
	anchored = TRUE
	density = FALSE
	var/skill_cap = 125
	var/reward_rate = 0.005
	var/course = FALSE
	var/replacement = /obj/item/weapon/lifting_weight/heavy

/obj/structure/exercise/course
	icon_state = "course_start"
	replacement = /obj/structure/treadwheel

/obj/structure/exercise/modern
	icon_state = "barbell"
	replacement = /obj/item/weapon/lifting_weight/barbell

/obj/structure/exercise/modern/course
	icon_state = "course_start"
	replacement = /obj/structure/treadwheel/treadmill

/obj/structure/exercise/persistence_runtime_var(key)
	return (key in list("actor", "origin", "repetition", "busy", "epoch", "expiry")) || ..()

/obj/structure/exercise/after_load()
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(replace_legacy)), 10)

/obj/structure/exercise/attack_hand(mob/user)
	replace_legacy()

/obj/structure/exercise/proc/replace_legacy()
	if (QDELETED(src) || !isturf(loc))
		return
	new replacement(loc)
	qdel(src)

#undef EXERCISE_SET_WINDOW
