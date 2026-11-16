// Language lessons: the fastest way to learn, and it takes another person.
// A fluent speaker teaches someone next to them. Both stay put for the
// lesson; the learner gains LANGUAGE_LESSON_GAIN, never past the teacher's
// own score, up to LANGUAGE_LESSON_DAILY_CAP a day, on top of what hearing
// and speaking give. About fifteen one-minute lessons take a beginner to Fluent.

// The languages src could teach learner now: fluent in it, and better at it.
/mob/living/human/proc/teachable_languages(mob/living/human/learner)
	var/list/teachable = list()
	if (!istype(learner) || learner == src)
		return teachable
	for (var/datum/language/L in languages)
		if (!language_learnable(L) || language_score(L) < LANGUAGE_FLUENT)
			continue
		if (learner.language_score(L) >= language_score(L))
			continue
		teachable[L.name] = L
	return teachable

/mob/living/human/proc/can_take_part_in_lesson()
	return !stat && !restrained() && !sleeping && !lying

/mob/living/human/verb/teach_language()
	set name = "Teach Language"
	set category = "IC"
	set desc = "Give someone next to you a lesson in a language you speak fluently."

	if (!can_take_part_in_lesson())
		to_chat(src, SPAN_WARNING("You are in no state to teach."))
		return
	var/list/learners = list()
	for (var/mob/living/human/H in orange(1, src))
		if (H.can_take_part_in_lesson() && (H.client || agent_character_for(H)) && length(teachable_languages(H)))
			learners[H.name] = H
	if (!learners.len)
		to_chat(src, SPAN_WARNING("There is nobody next to you who could learn a language from you. You need to be fluent in it, and they need to stand beside you."))
		return
	var/learner_name = learners[1]
	if (learners.len > 1)
		learner_name = WWinput(src, "Who do you want to teach?", "Teach Language", learners[1], learners + "Cancel")
	var/mob/living/human/learner = learners[learner_name]
	if (!istype(learner))
		return
	var/list/teachable = teachable_languages(learner)
	if (!teachable.len)
		return
	var/language_name = teachable[1]
	if (teachable.len > 1)
		language_name = WWinput(src, "Which language do you want to teach [learner]?", "Teach Language", teachable[1], teachable + "Cancel")
	var/datum/language/L = teachable[language_name]
	if (!istype(L))
		return
	give_language_lesson(learner, L)

/mob/living/human/proc/lesson_still_possible(mob/living/human/learner, datum/language/L)
	if (QDELETED(learner) || !can_take_part_in_lesson() || !learner.can_take_part_in_lesson())
		return FALSE
	if (get_dist(src, learner) > 1 || z != learner.z)
		return FALSE
	return language_score(L) >= LANGUAGE_FLUENT && learner.language_score(L) < language_score(L)

/mob/living/human/proc/give_language_lesson(mob/living/human/learner, datum/language/L)
	L = canonical_language(L)
	if (!language_learnable(L) || !lesson_still_possible(learner, L))
		to_chat(src, SPAN_WARNING("You can't teach [learner] that right now."))
		return FALSE
	if (!learner.language_day_left(L, "lesson"))
		to_chat(src, SPAN_WARNING("[learner] has had all the [L.name] lessons they can take in today."))
		return FALSE
	if (learner.client)
		var/answer = WWinput(learner, "[src] offers you a lesson in [L.name]. It takes about a minute and you both need to stay put.", "Language Lesson", "Accept", list("Accept", "Decline"))
		if (answer != "Accept")
			if (!QDELETED(src))
				to_chat(src, SPAN_WARNING("[learner] declines the lesson."))
			return FALSE
		if (QDELETED(src) || !lesson_still_possible(learner, L))
			return FALSE
	visible_message(SPAN_NOTICE("[src] starts teaching [learner] [L.name]."), SPAN_NOTICE("You start a [L.name] lesson with [learner]. It takes about a minute and you both need to stay put."))
	var/turf/learner_spot = get_turf(learner)
	if (!do_after(src, LANGUAGE_LESSON_TIME, learner))
		to_chat(src, SPAN_WARNING("The lesson is cut short."))
		if (!QDELETED(learner))
			to_chat(learner, SPAN_WARNING("The lesson is cut short."))
		return FALSE
	if (!lesson_still_possible(learner, L) || get_turf(learner) != learner_spot)
		to_chat(src, SPAN_WARNING("The lesson is cut short."))
		return FALSE
	var/gained = learner.gain_language(L, LANGUAGE_LESSON_GAIN, language_score(L), "lesson")
	if (!gained)
		to_chat(src, SPAN_WARNING("[learner] could not take in any more today."))
		return FALSE
	to_chat(src, SPAN_NOTICE("You finish the lesson. [learner] seems to follow a little more [L.name]."))
	to_chat(learner, SPAN_NOTICE("The lesson ends. You now understand about [round(learner.language_score(L))]% of [L.name][learner.language_day_left(L, "lesson") ? "" : ", and that is all the lessons you can take in today"]."))
	return TRUE
