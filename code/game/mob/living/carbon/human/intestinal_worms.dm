// Gameplay balance, not a model of real parasites or medical treatment.
// Intestinal worms come from swallowed worm eggs: raw wild meat, the raw
// flesh of an infested person, and dirty water. They never spread from person
// to person, build no resistance, and penicillin does nothing for them. They
// make you hungry faster and bring cramps. A course of healing herbs or a few
// drinks of absinthe purges them; the body also passes them on its own, twice
// as fast while resting in bed. One call per existing /process/mob tick.

#define WORMS_QUIET 300 // about five minutes before the first symptoms
#define WORMS_CLEAR 5400 // passed naturally after about 90 minutes of play
#define WORMS_COURSE 60 // treatment points that purge them (herbs give 0.3 a tick)
#define WORMS_PAIN 20 // cramps alone never push pain past this
#define WORMS_HUNGER 0.04 // extra nutrition lost per tick, about half again an active appetite

/mob/living/human/proc/handle_worms()
	if (inducedSSD || (status_flags & GODMODE))
		disease_treatment = 0
		return
	var/treatment = disease_treatment
	disease_treatment = 0
	if (treatment > 0)
		disease_course = min(WORMS_COURSE, round(disease_course + treatment, 0.01))
		if (disease_course >= WORMS_COURSE)
			clear_disease()
			to_chat(src, SPAN_NOTICE("The cramps ease as the remedy purges the worms. Your gut feels clear again."))
			return
	var/before = disease_progression
	disease_progression += resting_in_bed() ? 2 : 1
	if (disease_progression >= WORMS_CLEAR)
		clear_disease()
		to_chat(src, SPAN_NOTICE("Your body has finally passed the worms. Your appetite settles."))
		return
	if (disease_progression < WORMS_QUIET)
		return
	if (before < WORMS_QUIET)
		to_chat(src, SPAN_WARNING("Your stomach churns, and you feel hungrier than you should. Something is living in your gut."))
	if (stat == CONSCIOUS)
		nutrition -= WORMS_HUNGER
	if (life_tick % 45 == 0)
		adjust_mood(-1, "intestinal worms")
		if (halloss < WORMS_PAIN)
			apply_effect(min(8, WORMS_PAIN - halloss), AGONY, FALSE)
		to_chat(src, SPAN_WARNING("A cramp twists through your gut."))

#undef WORMS_QUIET
#undef WORMS_CLEAR
#undef WORMS_COURSE
#undef WORMS_PAIN
#undef WORMS_HUNGER
