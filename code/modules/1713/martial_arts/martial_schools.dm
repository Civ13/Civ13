// Martial schools (martial arts plan, Val 2026-11-21). A character follows one
// unarmed school at a time and climbs its ranks, Novice to Master, by training.
// Each school opens with its own research node from the era it belongs to and
// never closes in a later era, and every era opens at least one. Every school
// can be trained alone all the way to Master; partners and masters only speed
// it up (later PR). The framework names no weapon, so schools for weapon
// types can join the same list later.
//
// The combat reaction engine (combat_reactions.dm) reads the rank with
// martial_rank(school_id); the ranks are in code/__defines/martial.dm.

// Points of practice for each rank above Novice.
#define MARTIAL_STUDENT_POINTS 40
#define MARTIAL_ADEPT_POINTS 150
#define MARTIAL_MASTER_POINTS 400
// Real time between one change of school and the next pick.
#define MARTIAL_SCHOOL_LOCK (7 * 24 * 36000)
// A set of forms: about eight seconds of drills.
#define MARTIAL_FORMS_TIME 80

// id = list(name, minimum era, research node, what it teaches)
var/global/list/martial_schools = list(
	"grappling" = list("Grappling", 0, "school_grappling", "Holds, throws and sprawls, the oldest way to put a man on the ground."),
	"pugilism" = list("Classical Pugilism", 1, "school_pugilism", "Boxing with bound hands: footwork, guard and slipping punches to the head."),
	"pankration" = list("Pankration", 1, "school_pankration", "The all-in contest of strikes, kicks, locks and chokes."),
	"shaolin" = list("Shaolin Kung Fu", 2, "school_shaolin", "Temple boxing: stances, conditioning and long, flowing forms."),
	"wing_chun" = list("Wing Chun", 3, "school_wing_chun", "Close-range boxing on the centre line, with trapping hands and the Bong Sau deflection."),
	"hard_hand" = list("Hard-Hand Striking", 3, "school_hard_hand", "Conditioned fists and forearms that block and counter in one motion."),
	"savate" = list("Savate", 4, "school_savate", "French boxing with the feet: low kicks and fast hands."),
	"judo" = list("Judo", 5, "school_judo", "The gentle way: off-balancing, throws and pins."),
	"combatives" = list("Military Combatives", 6, "school_combatives", "Short, brutal drills for soldiers who lose their weapon."),
	"krav_maga" = list("Krav Maga", 7, "school_krav_maga", "Self-defence that strikes while it defends, against armed and unarmed attackers."),
	"bjj" = list("Brazilian Jiu-Jitsu", 8, "school_bjj", "Ground fighting: guard, sweeps and submissions."),
	"mma" = list("Mixed Martial Arts", 9, "school_mma", "Striking and grappling drilled together for the cage."))

/proc/martial_school_name(school_id)
	var/list/S = martial_schools[school_id]
	return islist(S) ? S[1] : null

/proc/martial_school_node(school_id)
	var/list/S = martial_schools[school_id]
	return islist(S) ? S[3] : null

/proc/martial_rank_name(rank)
	switch (rank)
		if (MARTIAL_RANK_NOVICE)
			return "Novice"
		if (MARTIAL_RANK_STUDENT)
			return "Student"
		if (MARTIAL_RANK_ADEPT)
			return "Adept"
		if (MARTIAL_RANK_MASTER)
			return "Master"
	return "None"

/proc/martial_rank_for_points(points)
	if (points >= MARTIAL_MASTER_POINTS)
		return MARTIAL_RANK_MASTER
	if (points >= MARTIAL_ADEPT_POINTS)
		return MARTIAL_RANK_ADEPT
	if (points >= MARTIAL_STUDENT_POINTS)
		return MARTIAL_RANK_STUDENT
	return MARTIAL_RANK_NOVICE

/proc/martial_progress_valid(list/progress)
	if (!islist(progress) || progress.len > martial_schools.len)
		return FALSE
	for (var/school_id in progress)
		if (!(school_id in martial_schools))
			return FALSE
		var/points = progress[school_id]
		if (!isnum(points) || points < 0 || points > MARTIAL_MASTER_POINTS * 4)
			return FALSE
	return TRUE

/mob/living/human
	// The school this character follows, or null.
	var/martial_school = null
	// school id = points of practice. A school left behind keeps its points,
	// so coming back to it picks up where it stopped.
	var/list/martial_progress = null
	// world.realtime before which a new school can't be picked.
	var/martial_school_lock = 0

// The rank in school_id: none unless it is the school this character follows.
/mob/living/human/proc/martial_rank(school_id)
	if (!school_id || school_id != martial_school || !(school_id in martial_schools))
		return MARTIAL_RANK_NONE
	return martial_rank_for_points(martial_points(school_id))

/mob/living/human/proc/martial_points(school_id)
	if (!islist(martial_progress))
		return 0
	var/points = martial_progress[school_id]
	return isnum(points) ? points : 0

// Practice in the followed school. Returns the points added.
/mob/living/human/proc/martial_practice(amount)
	if (!martial_school || !(martial_school in martial_schools) || amount <= 0)
		return 0
	if (!islist(martial_progress))
		martial_progress = list()
	var/before = martial_rank(martial_school)
	var/had = martial_points(martial_school)
	martial_progress[martial_school] = min(MARTIAL_MASTER_POINTS * 4, had + amount)
	var/after = martial_rank(martial_school)
	if (after > before)
		to_chat(src, SPAN_NOTICE("<b>You are now [after == MARTIAL_RANK_ADEPT ? "an" : "a"] [martial_rank_name(after)] of [martial_school_name(martial_school)].</b>"))
	return martial_progress[martial_school] - had

// Schools this character may take up now: their research is known.
/mob/living/human/proc/martial_school_choices()
	. = list()
	for (var/school_id in martial_schools)
		if (martial_school_known(school_id))
			. += school_id

// Overridden by the probe, which has no research.
/mob/living/human/proc/martial_school_known(school_id)
	return research_node_known(src, martial_school_node(school_id))

/mob/living/human/proc/martial_school_wait_text()
	var/left = martial_school_lock - world.realtime
	if (left <= 0)
		return null
	var/hours = round(left / 36000)
	if (hours >= 24)
		return "[round(hours / 24)] day\s and [hours % 24] hour\s"
	return hours >= 1 ? "[hours] hour\s" : "less than an hour"

/mob/living/human/proc/set_martial_school(school_id)
	martial_school = (school_id in martial_schools) ? school_id : null
	if (martial_school)
		if (!islist(martial_progress))
			martial_progress = list()
		if (!(martial_school in martial_progress))
			martial_progress[martial_school] = 0
	martial_school_lock = world.realtime + MARTIAL_SCHOOL_LOCK

/mob/living/human/proc/martial_status_text()
	if (!martial_school)
		return "You follow no martial school."
	var/rank = martial_rank(martial_school)
	var/points = martial_points(martial_school)
	var/next = rank == MARTIAL_RANK_NOVICE ? MARTIAL_STUDENT_POINTS : rank == MARTIAL_RANK_STUDENT ? MARTIAL_ADEPT_POINTS : rank == MARTIAL_RANK_ADEPT ? MARTIAL_MASTER_POINTS : 0
	return "You are [rank == MARTIAL_RANK_ADEPT ? "an" : "a"] [martial_rank_name(rank)] of [martial_school_name(martial_school)][next ? " ([round(points)] of [next] points toward the next rank)" : ""]."

/mob/living/human/verb/choose_martial_school()
	set name = "Choose martial school"
	set category = "IC"
	set desc = "Follow one school of unarmed fighting and train up its ranks."
	if (stat == DEAD)
		return
	var/wait = martial_school_wait_text()
	var/list/options = list()
	if (martial_school)
		options["Leave [martial_school_name(martial_school)]"] = "none"
	if (!wait)
		for (var/school_id in martial_school_choices())
			if (school_id != martial_school)
				options["[martial_school_name(school_id)] ([martial_rank_name(martial_rank_for_points(martial_points(school_id)))] when you start)"] = school_id
	if (!options.len)
		to_chat(src, SPAN_WARNING(wait ? "You changed schools recently. You can take up another in [wait]." : "You know no martial school yet. Each school opens with its own research under Martial Disciplines."))
		return
	options["Cancel"] = null
	var/intro = "[martial_status_text()] Train a school's forms with Practise martial forms, and by landing punches and toughening your hands. A school you leave keeps your progress, but after any change you must wait 7 real days before taking up another."
	if (wait)
		intro += " You can leave your school now and pick again in [wait]."
	var/choice = player_input(src, intro, "Martial school", null, "anything", options, TRUE)
	if (!choice || !options[choice] || stat == DEAD)
		return
	var/picked = options[choice]
	if (picked == "none")
		var/old = martial_school_name(martial_school)
		set_martial_school(null)
		to_chat(src, SPAN_NOTICE("You leave [old]. Your progress waits for you if you return. You can take up a school again in 7 real days."))
		return
	if (martial_school_wait_text() || !(picked in martial_school_choices()))
		return
	var/list/S = martial_schools[picked]
	if (player_alert(src, S[4], "Follow [S[1]]?", list("Yes", "No")) != "Yes" || martial_school_wait_text())
		return
	set_martial_school(picked)
	to_chat(src, SPAN_NOTICE("You now follow <b>[S[1]]</b>. [martial_status_text()]"))

// --- Forms ------------------------------------------------------------------

// Overridden by the probe, which has no do_after timing.
/mob/living/human/proc/martial_forms_wait()
	return do_after(src, MARTIAL_FORMS_TIME, src)

/mob/living/human/proc/martial_forms_refusal()
	if (!martial_school)
		return "You follow no martial school. Choose one first."
	if (stat != CONSCIOUS || lying || restrained() || buckled)
		return "You need to be up and free to drill your forms."
	if (get_active_hand() || get_inactive_hand())
		return "Empty your hands to drill your forms."
	return exercise_refusal()

// One set of forms: about eight seconds of drills alone, paid like any set.
/mob/living/human/proc/practise_martial_forms()
	var/refusal = martial_forms_refusal()
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		return FALSE
	visible_message(SPAN_NOTICE("[src] runs through the forms of [martial_school_name(martial_school)]."), SPAN_NOTICE("You run through your forms."))
	if (!martial_forms_wait())
		return FALSE
	refusal = martial_forms_refusal()
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		return FALSE
	var/gain = 1 - exercise_fatigue / 8
	exercise_spend(2)
	practice_unarmed(0.5)
	martial_practice(gain)
	to_chat(src, SPAN_NOTICE("You finish a set of forms. [martial_status_text()]"))
	return TRUE

/mob/living/human/verb/practise_martial_forms_verb()
	set name = "Practise martial forms"
	set category = "IC"
	set desc = "Drill your martial school's forms alone. A set takes about eight seconds and tires you like any exercise."
	practise_martial_forms()

// --- Region travel ------------------------------------------------------------

/mob/living/human/proc/martial_travel_record()
	var/list/progress = martial_progress_valid(martial_progress) ? martial_progress.Copy() : list()
	var/hand = current_hand_conditioning()
	if (!progress.len && !martial_school && martial_school_lock <= world.realtime && hand <= 0)
		return null
	// Hardened hands (hand_conditioning.dm) travel with the school.
	return list("school" = martial_school, "progress" = progress, "lock" = martial_school_lock > world.realtime ? martial_school_lock : 0,
		"hand" = hand, "hand_at" = hand > 0 ? hand_conditioning_at : 0)

/proc/martial_travel_valid(list/R)
	if (!islist(R))
		return FALSE
	if (!isnull(R["school"]) && !(R["school"] in martial_schools))
		return FALSE
	if (!isnum(R["hand"]) || R["hand"] < 0 || R["hand"] > 100 || !isnum(R["hand_at"]))
		return FALSE
	return martial_progress_valid(R["progress"]) && isnum(R["lock"])

/mob/living/human/proc/martial_travel_restore(list/R)
	if (!martial_travel_valid(R))
		return FALSE
	var/list/progress = R["progress"]
	martial_progress = progress.Copy()
	martial_school = R["school"]
	martial_school_lock = R["lock"]
	hand_conditioning = R["hand"]
	hand_conditioning_at = R["hand_at"]
	return TRUE

#undef MARTIAL_STUDENT_POINTS
#undef MARTIAL_ADEPT_POINTS
#undef MARTIAL_MASTER_POINTS
#undef MARTIAL_SCHOOL_LOCK
#undef MARTIAL_FORMS_TIME
