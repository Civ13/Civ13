// Scholar profession: practice (book research).
//
// Scholars can train a discipline by hand with its practice tool: use it in
// hand once and keep practising until you stop, move, put it away or tire.
// Practice is a complement to research, study and tutoring, not a
// replacement: SCHOLAR_PRACTICE_GAIN per SCHOLAR_PRACTICE_TIME of practice,
// less as the character nears SCHOLAR_PRACTICE_CAP, and nothing past it.
// Practice drains stamina as it goes (TRAINING_STAMINA_DRAIN) and needs
// light; a writing desk speeds it up and a master nearby doubles the gain.
//
//   Basic Mathematics  writing slate (sums), abacus (faster)
//   Engineering        model kit, drafting set (faster)
//   Natural Science    specimen box
//   Medicine           study bones
//   Agriculture        seed tray
//   Military Science   war game board

// The discipline item I trains, or null.
/proc/scholar_practice_discipline(obj/item/I)
	if (istype(I, /obj/item/weapon/abacus) || istype(I, /obj/item/weapon/writing_slate))
		return "mathematics"
	if (istype(I, /obj/item/weapon/drafting_set) || istype(I, /obj/item/weapon/scholar_practice/model_kit))
		return "engineering"
	if (istype(I, /obj/item/weapon/scholar_practice/specimen_box))
		return "natural_science"
	if (istype(I, /obj/item/weapon/scholar_practice/study_bones))
		return "medicine"
	if (istype(I, /obj/item/weapon/scholar_practice/seed_tray))
		return "agriculture"
	if (istype(I, /obj/item/weapon/scholar_practice/war_game))
		return "military"
	return null

// How much a session with I teaches, relative to a plain practice tool.
/proc/scholar_practice_tool_rate(obj/item/I)
	if (istype(I, /obj/item/weapon/abacus) || istype(I, /obj/item/weapon/drafting_set))
		return SCHOLAR_PRACTICE_INSTRUMENT_RATE
	return 1

// What practising each discipline looks like, for messages.
/proc/scholar_practice_activity(discipline)
	switch (discipline)
		if ("mathematics")
			return "working through sums"
		if ("engineering")
			return "building and testing a scale model"
		if ("natural_science")
			return "sorting and describing specimens"
		if ("medicine")
			return "naming the bones of the body"
		if ("agriculture")
			return "sorting and grading seeds"
		if ("military")
			return "playing out a battle"
	return "practising"

// Skill one session of discipline would give now (0 at or past the cap).
/mob/living/human/proc/scholar_practice_gain(discipline, rate = 1)
	var/level = scholar_level(discipline)
	if (level >= SCHOLAR_PRACTICE_CAP)
		return 0
	// Gains shrink as the character nears what practice alone can teach.
	var/factor = clamp(1 - level / SCHOLAR_PRACTICE_CAP, 0.25, 1)
	var/gain = SCHOLAR_PRACTICE_GAIN * rate * factor
	if (master_nearby())
		gain *= SCHOLAR_APPRENTICE_GAIN_MULT
	return min(round(gain, 0.01), SCHOLAR_PRACTICE_CAP - level)

// Why the character can't practise discipline right now, or null. Starting
// needs more breath than carrying on.
/mob/living/human/proc/scholar_practice_problem(discipline, starting = FALSE)
	if (!map || !map.book_research_enabled())
		return "There's nothing to practise for here."
	if (!(discipline in scholar_disciplines))
		return "You can't practise with that."
	if (stat != CONSCIOUS || incapacitated())
		return "You can't practise now."
	if (scholar_level(discipline) >= SCHOLAR_PRACTICE_CAP)
		return "Practice can't teach you more [scholar_disciplines[discipline]]. Research and study to go further."
	var/turf/T = get_turf(src)
	if (!T || T.get_lumcount() < SCHOLAR_MIN_LIGHT)
		return "It's too dark to practise."
	if (!training_has_stamina(SCHOLAR_PRACTICE_TICK, starting))
		return starting ? "You are too tired to practise now." : "You are too tired to keep practising."
	return null

// Practice that teaches SCHOLAR_PRACTICE_GAIN, shortened at a writing desk.
/mob/living/human/proc/scholar_practice_time()
	return round(SCHOLAR_PRACTICE_TIME / scholar_desk_rate())

// Pays `duration` deciseconds of practice (a whole SCHOLAR_PRACTICE_TIME by
// default): its stamina and its share of a session's skill. Returns the skill
// gained (0 if the practice no longer counts).
/mob/living/human/proc/scholar_practice_commit(discipline, rate = 1, duration = null)
	if (isnull(duration))
		duration = scholar_practice_time()
	if (scholar_practice_problem(discipline) || !training_has_stamina(duration))
		return 0
	var/level = scholar_level(discipline)
	var/gain = min(scholar_practice_gain(discipline, rate) * duration / max(1, scholar_practice_time()), SCHOLAR_PRACTICE_CAP - level)
	if (gain <= 0)
		return 0
	training_spend_stamina(duration)
	if (!islist(scholarship))
		scholarship = list()
	scholarship[discipline] = min(SCHOLAR_MAX_LEVEL, round(level + gain, 0.0001))
	return gain

/mob/living/human/proc/scholar_practice_wait(obj/item/tool, duration)
	return do_after(src, duration, tool, TRUE, FALSE)

// Use a practice tool in hand: practise continuously, one SCHOLAR_PRACTICE_TICK
// at a time, until the player uses it again, moves, swaps or puts it away,
// uses Stop Exercise, runs out of stamina or light, or reaches the cap.
// TRUE if the tool was handled.
/mob/living/human/proc/practise_scholarship(obj/item/tool)
	var/discipline = scholar_practice_discipline(tool)
	if (!discipline)
		return FALSE
	if (scholar_practising)
		cancel_exercise()
		to_chat(src, SPAN_NOTICE("You finish the thought and put your practice aside."))
		return TRUE
	var/problem = scholar_practice_problem(discipline, TRUE)
	if (!problem && exercise_equipment)
		problem = "Finish what you are doing or use Stop Exercise first."
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return TRUE
	var/activity = scholar_practice_activity(discipline)
	var/rate = scholar_practice_tool_rate(tool)
	var/start_level = scholar_level(discipline)
	visible_message(SPAN_NOTICE("[src] starts [activity] with \the [tool]."), SPAN_NOTICE("You start [activity] with \the [tool]. You will keep at it until you tire. Use it again, move or use Stop Exercise to stop."))
	scholar_practising = TRUE
	var/token = ++exercise_token
	var/stop_reason = null
	while (isnull(stop_reason))
		var/done = scholar_practice_wait(tool, SCHOLAR_PRACTICE_TICK)
		if (token != exercise_token || QDELETED(src))
			stop_reason = ""
		else if (!done || QDELETED(tool) || !(tool in list(l_hand, r_hand)))
			stop_reason = "You stop practising."
		else
			stop_reason = scholar_practice_problem(discipline)
			if (!stop_reason && scholar_practice_commit(discipline, rate, SCHOLAR_PRACTICE_TICK) <= 0)
				stop_reason = "You couldn't keep your mind on it."
	scholar_practising = FALSE
	if (token == exercise_token)
		exercise_token++
	if (stop_reason)
		to_chat(src, SPAN_WARNING(stop_reason))
	var/level = scholar_level(discipline)
	if (level <= start_level)
		return TRUE
	if (level >= SCHOLAR_PRACTICE_CAP)
		to_chat(src, SPAN_NOTICE("Your [scholar_disciplines[discipline]] is now [round(level)], as far as practice alone can take it."))
	else
		to_chat(src, SPAN_NOTICE("Your [scholar_disciplines[discipline]] is now [round(level, 0.1)] (+[round(level - start_level, 0.01)])."))
	return TRUE

/mob/living/human/var/tmp/scholar_practising = FALSE

// Persistence saves tmp vars too. A save taken during a practice session must
// not carry the lock, or the restored character can never practise again.
/mob/living/human/persistence_runtime_var(key)
	return key == "scholar_practising" || ..()

/obj/item/weapon/writing_slate/attack_self(mob/living/human/user)
	if (istype(user) && user.practise_scholarship(src))
		return
	return ..()

/obj/item/weapon/abacus/attack_self(mob/living/human/user)
	if (istype(user) && user.practise_scholarship(src))
		return
	return ..()

/obj/item/weapon/drafting_set/attack_self(mob/living/human/user)
	if (istype(user) && user.practise_scholarship(src))
		return
	return ..()

// ------------------------------------------------------------
// Practice tools
// ------------------------------------------------------------

/obj/item/weapon/scholar_practice
	name = "practice kit"
	icon = 'icons/obj/scholar_tools.dmi'
	item_state = "paper"
	w_class = ITEM_SIZE_SMALL
	force = 2
	throwforce = 2
	flammable = TRUE

/obj/item/weapon/scholar_practice/attack_self(mob/living/human/user)
	if (istype(user) && user.practise_scholarship(src))
		return
	return ..()

/obj/item/weapon/scholar_practice/model_kit
	name = "model kit"
	desc = "Wooden blocks, beams and pegs for building scale models. Use it in hand to practise Engineering."
	icon_state = "model_kit"
	w_class = ITEM_SIZE_NORMAL

/obj/item/weapon/scholar_practice/specimen_box
	name = "specimen box"
	desc = "A partitioned box of stones, leaves, shells and ores to sort and describe. Use it in hand to practise Natural Science."
	icon_state = "specimen_box"

/obj/item/weapon/scholar_practice/study_bones
	name = "study bones"
	desc = "A cloth laid out with a skull and bones, for learning how the body fits together. Use it in hand to practise Medicine."
	icon_state = "study_bones"

/obj/item/weapon/scholar_practice/seed_tray
	name = "seed tray"
	desc = "A wooden tray of seeds to sort and grade by kind and quality. Use it in hand to practise Agriculture."
	icon_state = "seed_tray"

/obj/item/weapon/scholar_practice/war_game
	name = "war game board"
	desc = "A board of squares with red and blue pieces for playing out battles. Use it in hand to practise Military Science."
	icon_state = "war_game"
	w_class = ITEM_SIZE_NORMAL
