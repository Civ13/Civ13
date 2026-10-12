// Finite, manually completed sets. No autonomous training or damage targets.
/proc/exercise_time()
	return world.time

/proc/exercise_recipe_era(result_type)
	return !ispath(result_type, /obj/structure/exercise/modern) || (map && map.ordinal_age >= 8)

/proc/exercise_can_build(mob/living/human/H, result_type)
	if (!ispath(result_type, /obj/structure/exercise))
		return TRUE
	var/skill = ispath(result_type, /obj/structure/exercise/modern) ? 105 : 30
	return H && H.stat == CONSCIOUS && exercise_recipe_era(result_type) && H.getStat("crafting") >= skill && map && map.is_node_done(H.civilization, get_recipe_node_req("[result_type]"))

/mob/living/human
	var/exercise_fatigue = 0
	var/tmp/exercise_rest_epoch = -1
	var/tmp/obj/structure/exercise/exercise_equipment

/mob/living/human/persistence_runtime_var(key)
	return key in list("exercise_rest_epoch", "exercise_equipment") || ..()

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
	var/obj/structure/exercise/E = exercise_equipment
	exercise_equipment = null
	if (E && E.actor == src)
		E.actor = null
		E.repetition = 0
		E.busy = FALSE
		E.origin = null
		E.epoch++

/mob/living/human/verb/stop_exercise()
	set name = "Stop Exercise"
	set category = "IC"
	cancel_exercise()
	to_chat(src, "You stop your unfinished exercise set.")

/obj/structure/exercise
	name = "stone lifting weights"
	desc = "Paid stone weights for manually completed lifting sets. Click three times, completing each fifteen-second repetition. Leaving the weights, interruption or cancelling loses the unfinished set."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-stone"
	anchored = TRUE
	density = FALSE
	var/skill_cap = 125
	var/reward_rate = 0.005
	var/course = FALSE
	var/tmp/mob/living/human/actor
	var/tmp/turf/origin
	var/tmp/repetition = 0
	var/tmp/busy = FALSE
	var/tmp/epoch = 0
	var/tmp/expiry = 0

/obj/structure/exercise/course
	name = "agility and endurance course marker"
	desc = "A manually walked square course: start on this tile, then visit three tiles east, three north, three west and back south to the start. Use Exercise Step at each corner for a timed repetition."
	icon = 'icons/obj/flags.dmi'
	icon_state = "flagpole_blank"
	course = TRUE
	reward_rate = 0.003

/obj/structure/exercise/modern
	name = "gym lifting weights"
	desc = "Machined lifting weights for three manually started fifteen-second repetitions. Fatigue and native skill caps still apply."
	icon_state = "sheet-iron"
	skill_cap = 150
	reward_rate = 0.006

/obj/structure/exercise/modern/course
	name = "gym circuit marker"
	desc = "A Modern agility and endurance circuit. Walk the four corners of its three-tile square and complete Exercise Step at each corner."
	icon = 'icons/obj/flags.dmi'
	icon_state = "flagpole_blank"
	course = TRUE
	reward_rate = 0.004

/obj/structure/exercise/persistence_runtime_var(key)
	return key in list("actor", "origin", "repetition", "busy", "epoch", "expiry") || ..()

/obj/structure/exercise/proc/clear_exercise()
	if (actor)
		actor.cancel_exercise()

/obj/structure/exercise/Destroy()
	clear_exercise()
	return ..()
/obj/structure/exercise/Del()
	clear_exercise()
	..()
/obj/structure/exercise/Move()
	var/atom/previous = loc
	. = ..()
	if (. && previous != loc)
		clear_exercise()
/obj/structure/exercise/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (. && previous != loc)
		clear_exercise()

/obj/structure/exercise/proc/eligible(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || H.lying || !isturf(H.loc) || !anchored || !isturf(loc) || H.z != z || !exercise_recipe_era(type))
		return FALSE
	H.recover_exercise()
	if (H.exercise_fatigue >= 6)
		return FALSE
	var/list/skills = course ? list("dexterity", "stamina") : list("strength")
	for (var/skill in skills)
		if (H.stats[skill][1] < 10 || H.stats[skill][1] >= skill_cap || H.stats[skill][2] >= skill_cap)
			return FALSE
	return TRUE

/obj/structure/exercise/proc/goal()
	if (!origin || !course)
		return origin
	var/list/xs = list(3,3,0,0)
	var/list/ys = list(0,3,3,0)
	return locate(origin.x + xs[repetition+1], origin.y + ys[repetition+1], origin.z)

/obj/structure/exercise/proc/exercise_wait(mob/living/human/H, duration)
	return do_after(H, duration, H.loc)

/obj/structure/exercise/attack_hand(mob/living/human/H)
	if (actor && exercise_time() >= expiry)
		clear_exercise()
	if (!eligible(H) || H.z != z || get_dist(H, src) > 1 || busy || (actor && actor != H) || (H.exercise_equipment && H.exercise_equipment != src))
		return
	if (!actor)
		if (course && (H.loc != loc || !locate(x+3,y+3,z)))
			to_chat(H, "Start on the marker with room for a three-tile square to the northeast.")
			return
		actor = H
		H.exercise_equipment = src
		origin = H.loc
		repetition = 0
		epoch++
		expiry = exercise_time() + 1200
	if (course)
		tell_goal(H)
	else
		complete_repetition(H)

/obj/structure/exercise/proc/tell_goal(mob/living/human/H)
	var/turf/T = goal()
	to_chat(H, "Walk to ([T.x], [T.y]) on this level, then use Exercise Step. Completed: [repetition]/4. Stop Exercise cancels the set.")

/mob/living/human/verb/exercise_step()
	set name = "Exercise Step"
	set category = "IC"
	if (exercise_equipment && exercise_equipment.course)
		exercise_equipment.complete_repetition(src)

/obj/structure/exercise/proc/complete_repetition(mob/living/human/H)
	if (busy || actor != H || H.exercise_equipment != src)
		return FALSE
	if (!eligible(H) || exercise_time() >= expiry || loc != get_turf(src) || (course ? H.loc != goal() : H.loc != origin))
		H.cancel_exercise()
		return FALSE
	var/token = epoch
	var/turf/start = H.loc
	busy = TRUE
	var/success = exercise_wait(H, course ? 112.5 : 150)
	if (epoch != token || actor != H || H.exercise_equipment != src)
		return FALSE
	busy = FALSE
	if (!success || !eligible(H) || H.loc != start || !anchored || !isturf(loc) || exercise_time() >= expiry)
		H.cancel_exercise()
		return FALSE
	repetition++
	var/total = course ? 4 : 3
	if (repetition < total)
		if (course)
			tell_goal(H)
		else
			to_chat(H, "Repetition [repetition]/3 complete. Click again to continue; stopping earns no partial XP.")
		return TRUE
	var/list/skills = course ? list("dexterity", "stamina") : list("strength")
	for (var/skill in skills)
		var/list/values = H.stats[skill]
		var/rate = reward_rate * (1 - H.exercise_fatigue / 8) * (values[2] >= 100 ? 0.5 : 1)
		// Native adaptStat floors to 0.001. Quantize deliberately and avoid a
		// binary float just below the intended floor boundary after division.
		var/steps = max(1, round(rate / 0.001))
		H.adaptStat(skill, (steps + 0.001) * (skill == "dexterity" ? 0.1 : 0.15))
		values[1] = min(skill_cap, values[1])
		values[2] = min(skill_cap, values[2])
	H.exercise_fatigue = min(6, H.exercise_fatigue + 2)
	H.cancel_exercise()
	to_chat(H, "Set complete. Fatigue: [H.exercise_fatigue]/6; one point recovers per running-server minute. Gains diminish with fatigue and at 100 trained skill.")
	return TRUE
