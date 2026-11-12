// ------------------------------------------------------------
// Research Tree - resumable studying (Val, 2026-11-11)
// ------------------------------------------------------------
// A reader who stops studying a chapter or a recipe manual part-way keeps the
// part they read and picks up there later. Progress belongs to the character
// (saved with them and carried on region travel), not to the book, so any copy
// of the same chapter or manual continues it.

/mob/living/human
	var/list/study_progress = null // node id => fraction of it read (0-1)

/mob/living/human/proc/study_fraction(node_id)
	if (!islist(study_progress))
		return 0
	var/value = study_progress[node_id]
	return isnum(value) ? clamp(value, 0, 1) : 0

/mob/living/human/proc/study_percent(node_id)
	return round(study_fraction(node_id) * 100)

/mob/living/human/proc/clear_study_progress(node_id)
	if (islist(study_progress))
		study_progress -= node_id

// Never reaches 1: the last moment of reading is what teaches the node.
/mob/living/human/proc/note_study_progress(node_id, fraction)
	if (!valid_recipe_node_id(node_id))
		return
	fraction = round(clamp(fraction, 0, 0.99), 0.001)
	if (fraction <= 0)
		clear_study_progress(node_id)
		return
	if (!islist(study_progress))
		study_progress = list()
	study_progress[node_id] = fraction

/proc/clean_study_progress(value)
	var/list/result = list()
	if (islist(value))
		for (var/node_id in value)
			var/fraction = value[node_id]
			if (valid_recipe_node_id(node_id) && isnum(fraction) && fraction > 0 && fraction < 1)
				result[node_id] = round(fraction, 0.001)
	return result

// Time still needed to finish node_id when a full read takes total_time.
/mob/living/human/proc/study_time_left(node_id, total_time)
	return max(1, round(total_time * (1 - study_fraction(node_id))))

// Says where the reader starts. Returns the time left to read.
/mob/living/human/proc/begin_study_message(node_id, total_time, what, helper_text = "")
	var/left = study_time_left(node_id, total_time)
	var/minutes = round(left / 600, 0.5)
	var/minutes_text = minutes > 0 ? "about [minutes] minute\s" : "less than a minute"
	if (study_fraction(node_id) > 0)
		to_chat(src, SPAN_NOTICE("You pick up [what][helper_text] where you left off, [study_percent(node_id)]% of the way through. Finishing takes [minutes_text]."))
	else
		to_chat(src, SPAN_NOTICE("You begin studying [what][helper_text]. This takes [minutes_text]."))
	return left

// The timed read for whatever part of node_id is left. Every moment spent
// reading counts, whether or not the read is finished; the caller teaches the
// node (which clears the progress) once its own checks pass.
/mob/living/human/proc/timed_study(node_id, total_time, atom/anchor)
	var/left = study_time_left(node_id, total_time)
	var/started = world.time
	var/done = do_reading(src, left, anchor)
	var/spent = done ? left : clamp(world.time - started, 0, left)
	if (spent > 0 && total_time > 0)
		note_study_progress(node_id, study_fraction(node_id) + spent / total_time)
	if (!done && spent > 0)
		to_chat(src, SPAN_NOTICE("You stop reading, [study_percent(node_id)]% of the way through. You can pick up where you left off later, from any copy."))
	return done

/mob/living/human/learn_recipe_node(node_id)
	. = ..()
	if (.)
		clear_study_progress(node_id)

/mob/living/human/persistence_import_fields(list/saved_fields)
	. = ..()
	study_progress = clean_study_progress(study_progress)
	if (stat == DEAD)
		study_progress = list()

// ------------------------------------------------------------
// Reading needs light (Val, 2026-11-12)
// ------------------------------------------------------------
// Studying, copying and writing are done by eye: the reader's tile must be lit
// at least as well as a research bench needs (SCHOLAR_MIN_LIGHT). Evening
// daylight is enough; night or a dark room needs a candle, lamp or torch
// nearby. A read that is interrupted because the light went out keeps the part
// already read, like any other interruption (timed_study above).

/mob/living/human/proc/reading_light_problem()
	var/turf/T = get_turf(src)
	if (!T || T.get_lumcount() < SCHOLAR_MIN_LIGHT)
		return "It's too dark to read or write here. Bring a candle, lamp or torch, or wait for daylight."
	return null

// Says why H can't read here and returns TRUE, or returns FALSE when lit.
/mob/living/human/proc/too_dark_to_read()
	var/problem = reading_light_problem()
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return TRUE
	return FALSE

// A do_after for reading and writing: it refuses to start in the dark and
// stops as soon as the reader's light goes out. It waits in short steps under
// one progress bar so the light is checked while the reader works.
/proc/do_reading(mob/living/human/H, delay, atom/target)
	if (!istype(H))
		return do_after(H, delay, target)
	if (H.too_dark_to_read())
		return FALSE
	delay = max(1, round(delay))
	var/datum/progressbar/bar = H.client ? new /datum/progressbar(H, delay, target) : null
	var/started = world.time
	var/steps = max(1, -round(-delay / READING_LIGHT_CHECK))
	. = TRUE
	for (var/i = 1 to steps)
		var/wait = min(READING_LIGHT_CHECK, delay - (i - 1) * READING_LIGHT_CHECK)
		if (!do_after(H, wait, target, TRUE, FALSE))
			. = FALSE
			break
		if (bar)
			bar.update(world.time - started)
		if (i < steps && H.reading_light_problem())
			to_chat(H, SPAN_WARNING("It has grown too dark to see the page. Bring a candle, lamp or torch, or wait for daylight."))
			. = FALSE
			break
	if (bar)
		qdel(bar)
