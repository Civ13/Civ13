// ============================================================
// Research Tree - prototypes and field study (Val, 2026-11-13)
// ------------------------------------------------------------
// Two more ways to research away from the bench, from a player's suggestions:
// - Prototypes: once a carried book holds a third of a chapter, its carrier
//   can make that subject's own things before knowing it. Each one made
//   writes a share of the chapter into that book, up to a limit per book.
//   After that the book stays a reference with no limit on uses (Val,
//   2026-11-17): it writes no more research, and building from it is slower
//   until the subject is learned (reference_build_time below).
// - Field study: take paper, parchment or a book to something that already
//   exists and that the subject makes (a building, a machine, a tool...) and
//   study it. Each kind of thing counts once per book.
// - Trial and error (Val, 2026-11-14): a book can be set to attempt a subject
//   from its very first page. Early attempts mostly fail: the materials are
//   used, a ruined piece is left, and the lesson is written into the book.
//   The chance improves with the chapter, with each failure on that thing and
//   with scholarship, and reaches certainty at the old one-third mark.
// Only on book-research worlds. Capstones still need their demonstration or
// prototype part (demonstrations.dm).
// ============================================================

// Share of a chapter a carried book needs before prototypes can be made.
#define SUBJECT_PROTO_SHARE 0.34
// Share of the chapter each prototype writes, and how many count per book.
#define SUBJECT_PROTO_POINTS 0.08
#define SUBJECT_PROTO_MAX 5
// Building from a book before knowing the subject (Val, 2026-11-17): the
// first piece takes this many times as long, each later one takes off
// REFERENCE_SLOW_STEP of the extra time, never below REFERENCE_SLOW_FLOOR.
// Learning the subject (reading its finished chapter) brings it back to 1.
#define REFERENCE_SLOW_START 2
#define REFERENCE_SLOW_STEP 0.1
#define REFERENCE_SLOW_FLOOR 1.5
// Share of the chapter each kind of thing studied writes, and how many kinds count.
#define FIELD_STUDY_POINTS 0.1
#define FIELD_STUDY_MAX 3
#define FIELD_STUDY_RANGE 1
#define FIELD_STUDY_TIME 300
// Trial and error: chance of a working piece from an empty chapter (percent),
// what each earlier failure on the same thing adds, and the most scholarship
// above or below the requirement can add or take away.
#define TRIAL_BASE_CHANCE 15
#define TRIAL_FAILURE_STEP 10
#define TRIAL_SKILL_BONUS 15
#define TRIAL_SKILL_PENALTY 10
// Share of the chapter a failure's lesson writes, and how many count per book.
#define TRIAL_LESSON_POINTS 0.04
#define TRIAL_LESSON_MAX 5
// Working pieces one character can make of a subject before its book is a
// third written, across every book they carry.
#define TRIAL_CHARACTER_MAX 5
// From this era tier on, a failure can hurt (percent of failures).
#define TRIAL_MISHAP_TIER 4
#define TRIAL_MISHAP_CHANCE 25
#define TRIAL_RECORD_LIMIT 400

/obj/item/weapon/book
	var/research_prototypes = "" // "node=count;node=count" prototypes made from this book
	var/research_fieldstudies = "" // "node>/type/path;..." kinds of things studied into this book
	var/research_lessons = "" // "node=count;node=count" lessons from failed attempts written into this book
	var/trial_subject = null // the subject this book's carrier is attempting by trial and error

/mob/living/human
	var/list/trial_work = null // "node" => early working pieces, "node>path" => failures on that thing, "node!path" => made it work once

/obj/item/weapon/paper
	var/field_study_node = null // subject these field notes are about
	var/field_study_type = null // the kind of thing studied

// ---------- Prototypes ----------

/obj/item/weapon/book/proc/prototype_counts()
	var/list/counts = list()
	if (istext(research_prototypes) && length(research_prototypes))
		for (var/part in splittext(research_prototypes, ";"))
			var/list/pair = splittext(part, "=")
			if (pair.len == 2 && valid_recipe_node_id(pair[1]))
				counts[pair[1]] = max(0, text2num(pair[2]) || 0)
	return counts

/obj/item/weapon/book/proc/prototypes_made(node_id)
	return prototype_counts()[node_id] || 0

/obj/item/weapon/book/proc/add_prototype_made(node_id)
	var/list/counts = prototype_counts()
	counts[node_id] = (counts[node_id] || 0) + 1
	var/list/parts = list()
	for (var/id in counts)
		parts += "[id]=[counts[id]]"
	research_prototypes = jointext(parts, ";")

// A carried book that can still take a prototype of node_id, or null.
/mob/living/human/proc/prototype_book(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return null
	var/obj/item/weapon/book/trial = null
	var/obj/item/weapon/book/reference = null
	for (var/obj/item/weapon/book/B in get_demonstration_carried())
		if (istype(B, /obj/item/weapon/book/research/tree_book) || B.has_research_chapter(node_id))
			continue
		// A third written: a reference with no limit on uses. Prefer a book
		// that can still take a prototype's research.
		if (B.research_ticks(node_id) >= N.cost_ticks * SUBJECT_PROTO_SHARE)
			if (B.prototypes_made(node_id) < SUBJECT_PROTO_MAX)
				return B
			if (!reference)
				reference = B
			continue
		// Not a third written yet: only by trial and error (below).
		if (!trial && B.trial_subject == node_id && trial_count(node_id) < TRIAL_CHARACTER_MAX)
			trial = B
	return reference || trial

// A carried book holding node_id's finished chapter, or null: reading it is
// how the subject is learned (crafting hints name it).
/mob/living/human/proc/carried_chapter_book(node_id)
	for (var/obj/item/weapon/book/B in get_demonstration_carried())
		if (!istype(B, /obj/item/weapon/book/research/tree_book) && B.has_research_chapter(node_id))
			return B
	return null

// The subject a prototype of result_path_string would be for, if H may make one.
/proc/subject_prototype_node(mob/living/human/H, result_path_string)
	if (!istype(H) || !istext(result_path_string) || !map || !map.book_research_enabled())
		return null
	var/node_id = get_recipe_node_req(result_path_string)
	if (!istext(node_id) || !get_research_node(node_id))
		return null
	if (H.knows_recipe_node(node_id) || !H.knows_research_prereqs(node_id))
		return null
	return H.prototype_book(node_id) ? node_id : null

/proc/subject_prototype_allowed(mob/living/human/H, result_path_string)
	return subject_prototype_node(H, result_path_string) ? TRUE : FALSE

// Builds from a book before learning the subject: counted per character, so
// practice makes it quicker even across books.
#define REFERENCE_SLOW_BUILDS 5
/proc/reference_build_key(node_id)
	return "ref:[node_id]"

// How many times as long H takes to make result_path_string: more than 1 only
// while working from a book without knowing the subject. Guided work beside a
// teacher (trade_learning.dm) is not slowed.
/proc/reference_build_mult(mob/living/human/H, result_path_string)
	if (!istype(H) || guided_work_node(H, result_path_string))
		return 1
	var/node_id = subject_prototype_node(H, result_path_string)
	if (!node_id)
		return 1
	var/done = H.trial_count(reference_build_key(node_id))
	return max(REFERENCE_SLOW_FLOOR, REFERENCE_SLOW_START - REFERENCE_SLOW_STEP * done)

// Called by whatever makes things, before its wait: the wait while working
// from a book (Val, 2026-11-17: unlimited uses, but slower until learned).
/proc/reference_build_time(mob/user, result_path_string, time)
	var/mult = reference_build_mult(user, "[result_path_string]")
	if (mult <= 1)
		return time
	to_chat(user, SPAN_NOTICE("You work slowly, checking each step against your book."))
	return round(time * mult)

// Called when something is made (from note_craft_practice): a prototype writes
// its share into the carried book.
/proc/record_subject_prototype(mob/living/human/H, result_path_string)
	var/node_id = subject_prototype_node(H, result_path_string)
	if (!node_id)
		return 0
	var/datum/research_node/N = get_research_node(node_id)
	var/obj/item/weapon/book/B = H.prototype_book(node_id)
	H.add_trial_count(reference_build_key(node_id), REFERENCE_SLOW_BUILDS)
	// Made before the chapter is a third written: trial and error paid off.
	if (B.research_ticks(node_id) < N.cost_ticks * SUBJECT_PROTO_SHARE)
		H.note_trial_success(node_id, result_path_string)
	// The book has had all the prototypes it can learn from: still a
	// reference, but nothing more is written.
	if (B.prototypes_made(node_id) >= SUBJECT_PROTO_MAX)
		to_chat(H, SPAN_NOTICE("You work from [B] as a reference. It has nothing more to learn from prototypes of <b>[N.name]</b>; finish the chapter and read it to work at full speed."))
		return 0
	B.add_prototype_made(node_id)
	var/points = max(1, round(N.cost_ticks * SUBJECT_PROTO_POINTS))
	var/finished = B.add_research_work(node_id, points, FALSE, H)
	H.gain_active_scholarship(node_id, points, "prototype:[node_id]:[B.prototypes_made(node_id)]")
	to_chat(H, SPAN_NOTICE("You note how the prototype came out in [B]: <b>[N.name]</b> advances by [points] points[finished ? " and the chapter is finished" : ""]. ([B.prototypes_made(node_id)] of [SUBJECT_PROTO_MAX] prototypes for this book.)"))
	// Say what is left, so a recorded prototype is not mistaken for the whole subject.
	if (finished)
		to_chat(H, SPAN_NOTICE("Read the finished chapter in [B] to learn <b>[N.name]</b>."))
	else
		var/written = round(B.research_ticks(node_id) / N.cost_ticks * 100)
		var/left = SUBJECT_PROTO_MAX - B.prototypes_made(node_id)
		to_chat(H, SPAN_NOTICE("The chapter is [written]% written. [left > 0 ? "[left] more prototype\s can add to it; the rest" : "Prototypes can add no more; the rest"] needs work at a research bench or other field work."))
	return points

// Prototypes a book has recorded for a subject, and the most that count.
/obj/item/weapon/book/proc/prototype_progress(node_id)
	return list(prototypes_made(node_id), SUBJECT_PROTO_MAX)

// H carries a book that is working on node_id: its recipes stay listed in the
// crafting menu, so a refused prototype says why instead of vanishing.
/proc/subject_in_carried_book(mob/living/human/H, node_id)
	if (!istype(H) || !istext(node_id) || !map || !map.book_research_enabled())
		return FALSE
	for (var/obj/item/weapon/book/B in H.get_demonstration_carried())
		if (istype(B, /obj/item/weapon/book/research/tree_book))
			continue
		if (B.trial_subject == node_id || B.research_ticks(node_id) > 0)
			return TRUE
	return FALSE

// Why H can't make result_path_string early from a part-written chapter,
// naming what is missing (Val, 2026-11-16: a researcher with the chapter
// nearly written was simply told nothing). Null when the recipe's subject is
// not one they could be working on, so the caller keeps its own message.
/proc/subject_prototype_refusal(mob/living/human/H, result_path_string)
	if (!istype(H) || !istext(result_path_string) || !map || !map.book_research_enabled())
		return null
	var/node_id = get_recipe_node_req(result_path_string)
	var/datum/research_node/N = istext(node_id) ? get_research_node(node_id) : null
	if (!N || H.knows_recipe_node(node_id))
		return null
	var/list/missing = list()
	for (var/req in N.prereqs)
		if (!H.knows_recipe_node(req))
			var/datum/research_node/R = get_research_node(req)
			missing += "<b>[R ? R.name : req]</b>"
	if (missing.len)
		return "You don't know <b>[N.name]</b>, and you can't try its work early until you know [english_list(missing)]."
	var/need = ceil(N.cost_ticks * SUBJECT_PROTO_SHARE)
	var/obj/item/weapon/book/best = null
	for (var/obj/item/weapon/book/B in H.get_demonstration_carried())
		if (istype(B, /obj/item/weapon/book/research/tree_book))
			continue
		if (B.has_research_chapter(node_id))
			return "[B] already holds the whole <b>[N.name]</b> chapter. Read it to learn the subject, then you can make its things."
		if (!best || B.research_ticks(node_id) > best.research_ticks(node_id) || (B.trial_subject == node_id && best.trial_subject != node_id && B.research_ticks(node_id) == best.research_ticks(node_id)))
			best = B
	if (!best || (!best.research_ticks(node_id) && best.trial_subject != node_id))
		return "You don't know <b>[N.name]</b> yet. Study its chapter, carry a book with at least a third of it written ([need] of [N.cost_ticks] points) to make prototypes, or set a book to Attempt a Subject."
	var/written = best.research_ticks(node_id)
	if (written < need && best.trial_subject == node_id && H.trial_count(node_id) >= TRIAL_CHARACTER_MAX)
		return "You have made all [TRIAL_CHARACTER_MAX] early pieces of <b>[N.name]</b> you can before a book holds a third of the chapter. [best] has [written] of the [need] points needed."
	if (written < need)
		return "[best] has only [written] of the [need] points of <b>[N.name]</b> needed to make prototypes (a third of [N.cost_ticks]). Write more at a research bench, or set the book to Attempt a Subject."
	return null

// ---------- Trial and error ----------

/obj/item/trash/failed_attempt
	name = "ruined piece"
	desc = "What is left of an attempt that did not work."
	icon_state = "trash_3"

/mob/living/human/proc/trial_count(key)
	if (!islist(trial_work))
		return 0
	var/value = trial_work[key]
	return isnum(value) ? max(0, value) : 0

/mob/living/human/proc/add_trial_count(key, most = 9)
	if (!islist(trial_work))
		trial_work = list()
	if (isnull(trial_work[key]) && trial_work.len >= TRIAL_RECORD_LIMIT)
		return
	trial_work[key] = min(most, trial_count(key) + 1)

/proc/clean_trial_work(value)
	var/list/result = list()
	if (islist(value))
		for (var/key in value)
			if (!istext(key) || !length(key) || length(key) > 200 || result.len >= TRIAL_RECORD_LIMIT)
				continue
			var/count = value[key]
			if (isnum(count) && count >= 1)
				result[key] = min(9, round(count))
	return result

/mob/living/human/persistence_import_fields(list/saved_fields)
	. = ..()
	trial_work = clean_trial_work(trial_work)
	if (stat == DEAD)
		trial_work = list()

/mob/living/human/forget_recipe_knowledge()
	..()
	trial_work = list()

/obj/item/weapon/book/proc/lesson_counts()
	var/list/counts = list()
	if (istext(research_lessons) && length(research_lessons))
		for (var/part in splittext(research_lessons, ";"))
			var/list/pair = splittext(part, "=")
			if (pair.len == 2 && valid_recipe_node_id(pair[1]))
				counts[pair[1]] = max(0, text2num(pair[2]) || 0)
	return counts

/obj/item/weapon/book/proc/lessons_learned(node_id)
	return lesson_counts()[node_id] || 0

/obj/item/weapon/book/proc/add_lesson_learned(node_id)
	var/list/counts = lesson_counts()
	counts[node_id] = (counts[node_id] || 0) + 1
	var/list/parts = list()
	for (var/id in counts)
		parts += "[id]=[counts[id]]"
	research_lessons = jointext(parts, ";")

// Subjects H could set a book to attempt: groundwork known, subject not.
/mob/living/human/proc/trial_subject_choices(obj/item/weapon/book/B)
	var/list/names = list()
	if (!istype(B) || !B.can_hold_research() || istype(B, /obj/item/weapon/book/research/tree_book))
		return names
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (research_node_dormant(N) || N.mode == RESEARCH_MODE_BOOK || knows_recipe_node(node_id) || !knows_research_prereqs(node_id))
			continue
		if (B.has_research_chapter(node_id) || !length(get_node_recipe_paths(node_id)))
			continue
		names[N.name] = node_id
	return names

// Sets what the book's carrier attempts. No waiting here.
/mob/living/human/proc/set_trial_subject(obj/item/weapon/book/B, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	var/offered = FALSE
	var/list/choices = trial_subject_choices(B)
	for (var/name in choices)
		if (choices[name] == node_id)
			offered = TRUE
	if (!N || !offered)
		return FALSE
	B.trial_subject = node_id
	to_chat(src, SPAN_NOTICE("You open [B] to a fresh page headed <b>[N.name]</b>. While you carry it you can try to make that subject's things. Expect most early attempts to fail: the materials are used either way, and each failure teaches something."))
	return TRUE

/mob/living/human/proc/attempt_a_subject(obj/item/weapon/book/B)
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("There is nothing to attempt here."))
		return FALSE
	var/list/names = trial_subject_choices(B)
	if (!names.len)
		to_chat(src, SPAN_WARNING("There is no subject you could attempt in [B]. You need to know what a subject builds on, and the book must not hold its chapter already."))
		return FALSE
	var/choice = player_input(src, "Which subject do you attempt by trial and error?", "Attempt a Subject", null, "anything", names, TRUE)
	if (!choice || !(B in get_demonstration_carried()))
		return FALSE
	return set_trial_subject(B, names[choice])

/obj/item/weapon/book/verb/attempt_a_subject_book()
	set name = "Attempt a Subject"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.attempt_a_subject(src)

// Percent chance that H's next attempt at result_path_string works.
/mob/living/human/proc/trial_success_chance(node_id, result_path_string, obj/item/weapon/book/B)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !istype(B))
		return 100
	var/share = B.research_ticks(node_id) / max(1, N.cost_ticks)
	if (share >= SUBJECT_PROTO_SHARE)
		return 100
	var/margin = clamp(scholar_level(node_discipline(node_id)) - node_scholar_requirement(node_id), -TRIAL_SKILL_PENALTY, TRIAL_SKILL_BONUS)
	var/chance = TRIAL_BASE_CHANCE + (100 - TRIAL_BASE_CHANCE) * share / SUBJECT_PROTO_SHARE + TRIAL_FAILURE_STEP * trial_count("[node_id]>[result_path_string]") + margin
	return clamp(round(chance), 5, 95)

// A working piece made early: counted on the character, and the first of
// each thing is a breakthrough worth telling people about.
/mob/living/human/proc/note_trial_success(node_id, result_path_string)
	add_trial_count(node_id, TRIAL_CHARACTER_MAX)
	var/first_key = "[node_id]![result_path_string]"
	if (trial_count(first_key))
		return FALSE
	add_trial_count(first_key, 1)
	var/datum/research_node/N = get_research_node(node_id)
	visible_message(SPAN_NOTICE("<b>[src]</b> turns the finished piece over. It works: a breakthrough in <b>[N ? N.name : "the craft"]</b>!"), SPAN_NOTICE("It works! After the failures, you have found how this is made."))
	return TRUE

// Writes down a failed attempt. Returns the points its lesson wrote (0 once
// the book has all the lessons it takes).
/proc/commit_trial_failure(mob/living/human/H, node_id, result_path_string, obj/item/weapon/book/B)
	var/datum/research_node/N = get_research_node(node_id)
	if (!istype(H) || !N || !istype(B))
		return 0
	H.add_trial_count("[node_id]>[result_path_string]")
	var/points = 0
	var/finished = FALSE
	if (B.lessons_learned(node_id) < TRIAL_LESSON_MAX && !B.has_research_chapter(node_id))
		B.add_lesson_learned(node_id)
		points = max(1, round(N.cost_ticks * TRIAL_LESSON_POINTS))
		finished = B.add_research_work(node_id, points, FALSE, H)
		H.gain_active_scholarship(node_id, points, "lesson:[node_id]:[B.lessons_learned(node_id)]")
	var/turf/T = get_turf(H)
	if (T)
		var/obj/item/trash/failed_attempt/ruin = new(T)
		var/atom/made = text2path(result_path_string)
		if (ispath(made))
			ruin.name = "ruined [initial(made.name)]"
	if (points)
		to_chat(H, SPAN_WARNING("The attempt fails and the materials are spoiled. You write down what went wrong in [B]: <b>[N.name]</b> advances by [points] points[finished ? " and the chapter is finished" : ""]. ([B.lessons_learned(node_id)] of [TRIAL_LESSON_MAX] lessons for this book.) Your next try at this is likelier to work."))
	else
		to_chat(H, SPAN_WARNING("The attempt fails and the materials are spoiled. [B] has every lesson failure can teach about <b>[N.name]</b>, but your next try at this is likelier to work."))
	return points

// What a failed attempt at a dangerous subject does to its maker, or null.
/proc/trial_mishap(mob/living/human/H, datum/research_node/N)
	if (!istype(H) || !N || N.era_tier < TRIAL_MISHAP_TIER)
		return null
	var/kind = rush_accident_kind(N.id)
	switch (kind)
		if ("radiation")
			H.apply_effect(10, IRRADIATE, blocked = 0)
			to_chat(H, SPAN_DANGER("Something in the failed piece leaves your skin tingling."))
		if ("blast")
			H.apply_damage(rand(5, 10), BURN)
			to_chat(H, SPAN_DANGER("The failed piece flares up and burns you!"))
		if ("poison")
			H.apply_damage(rand(5, 10), TOX)
			to_chat(H, SPAN_DANGER("The fumes from the failed batch make you feel sick."))
		if ("injury")
			H.apply_damage(rand(5, 10), BRUTE, pick("l_hand", "r_hand"))
			to_chat(H, SPAN_DANGER("The failed piece slips and gashes your hand."))
		else
			return null
	return kind

// Called by whatever makes things, once the materials are spent and before
// (or just after) the result exists. TRUE means the attempt failed: the
// caller must not hand over the result.
/proc/trial_craft_ruined(mob/user, result_path_string)
	var/mob/living/human/H = user
	if (!istype(H))
		return FALSE
	// Guided work beside a teacher comes first and has its own odds (trade_learning.dm).
	var/guided = guided_work_node(H, result_path_string)
	if (guided)
		if (!prob(H.guided_fail_chance()))
			return FALSE
		commit_guided_failure(H, guided, result_path_string)
		return TRUE
	var/node_id = subject_prototype_node(H, result_path_string)
	if (!node_id)
		return FALSE
	var/obj/item/weapon/book/B = H.prototype_book(node_id)
	if (prob(H.trial_success_chance(node_id, result_path_string, B)))
		return FALSE
	commit_trial_failure(H, node_id, result_path_string, B)
	if (prob(TRIAL_MISHAP_CHANCE))
		trial_mishap(H, get_research_node(node_id))
	return TRUE

// ---------- Field study ----------

/obj/item/weapon/book/proc/field_study_list()
	var/list/result = list()
	if (istext(research_fieldstudies) && length(research_fieldstudies))
		for (var/part in splittext(research_fieldstudies, ";"))
			if (length(part))
				result |= part
	return result

/obj/item/weapon/book/proc/field_study_count(node_id)
	. = 0
	for (var/entry in field_study_list())
		if (findtext(entry, "[node_id]>") == 1)
			.++

/obj/item/weapon/book/proc/has_field_study(node_id, kind)
	return "[node_id]>[kind]" in field_study_list()

/obj/item/weapon/book/proc/can_take_field_study(node_id, kind)
	return valid_recipe_node_id(node_id) && !has_research_chapter(node_id) && !has_field_study(node_id, kind) && field_study_count(node_id) < FIELD_STUDY_MAX

// Writes one study into the book. Returns the points added, or 0.
/obj/item/weapon/book/proc/record_field_study(node_id, kind)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !can_take_field_study(node_id, kind))
		return 0
	var/list/done = field_study_list()
	done += "[node_id]>[kind]"
	research_fieldstudies = jointext(done, ";")
	var/points = max(1, round(N.cost_ticks * FIELD_STUDY_POINTS))
	add_research_work(node_id, points)
	return points

// The subject a thing teaches about, for someone who could research it now.
/proc/field_study_node(mob/living/human/H, atom/movable/A)
	if (!istype(H) || !istype(A) || !map || !map.book_research_enabled())
		return null
	var/node_id = get_recipe_node_req("[A.type]")
	if (!istext(node_id) || !get_research_node(node_id))
		return null
	if (H.knows_recipe_node(node_id) || !H.knows_research_prereqs(node_id))
		return null
	return node_id

// Things near H worth studying, thing => subject.
/proc/field_study_targets(mob/living/human/H)
	var/list/found = list()
	if (!istype(H))
		return found
	for (var/atom/movable/A in range(FIELD_STUDY_RANGE, H))
		if (A == H || isturf(A) || ismob(A) || (A in list(H.l_hand, H.r_hand)))
			continue
		var/node_id = field_study_node(H, A)
		if (node_id)
			found[A] = node_id
	return found

/proc/field_study_carrier_ok(obj/item/carrier, node_id, kind)
	if (istype(carrier, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = carrier
		return !istype(P, /obj/item/weapon/paper/research_page) && !P.demonstration_node && !P.field_study_node && !P.find_kind
	if (istype(carrier, /obj/item/weapon/book) && !istype(carrier, /obj/item/weapon/book/research/tree_book))
		var/obj/item/weapon/book/B = carrier
		return B.can_take_field_study(node_id, kind)
	return FALSE

// Writes a finished study down. No waiting here.
/proc/commit_field_study(mob/living/human/H, obj/item/carrier, node_id, kind, thing_name)
	var/datum/research_node/N = get_research_node(node_id)
	if (!istype(H) || !N || !field_study_carrier_ok(carrier, node_id, kind))
		return 0
	if (istype(carrier, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = carrier
		P.field_study_node = node_id
		P.field_study_type = kind
		P.name = "field notes ([N.name])"
		P.desc = "Notes taken by [H.real_name] while studying \a [thing_name] for [N.name]. Use them on a research bench working on [N.name], with its book on the bench."
		P.update_icon()
		return 1
	var/obj/item/weapon/book/B = carrier
	. = B.record_field_study(node_id, kind)
	H.gain_active_scholarship(node_id, ., "study:[node_id]:[kind]")

/mob/living/human/proc/study_in_field(obj/item/carrier)
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("There is nothing here to study."))
		return FALSE
	if (!(carrier in list(l_hand, r_hand)))
		to_chat(src, SPAN_WARNING("Hold \the [carrier] in your hand first."))
		return FALSE
	if (!held_writing_pen())
		to_chat(src, SPAN_WARNING("You need a pen or pencil in your other hand to take notes."))
		return FALSE
	var/list/found = field_study_targets(src)
	if (!found.len)
		to_chat(src, SPAN_WARNING("Nothing next to you belongs to a subject you could research now. Stand beside a building, machine or tool made with a subject whose groundwork you know."))
		return FALSE
	var/atom/movable/thing = null
	if (found.len == 1)
		thing = found[1]
	else
		var/list/names = list()
		for (var/atom/movable/A in found)
			var/datum/research_node/FN = get_research_node(found[A])
			names["[A.name] ([FN.name])"] = A
		var/choice = player_input(src, "What do you study?", "Study in the Field", null, "anything", names, TRUE)
		if (!choice)
			return FALSE
		thing = names[choice]
	var/node_id = found[thing]
	var/datum/research_node/N = get_research_node(node_id)
	var/kind = "[thing.type]"
	if (!field_study_carrier_ok(carrier, node_id, kind))
		to_chat(src, SPAN_WARNING("\The [carrier] can't take a study of \the [thing] for [N.name]. A book takes [FIELD_STUDY_MAX] different kinds of thing per subject, each once."))
		return FALSE
	visible_message(SPAN_NOTICE("[src] starts studying \the [thing] and taking notes."), SPAN_NOTICE("You start studying \the [thing] for <b>[N.name]</b>."))
	if (!do_reading(src, FIELD_STUDY_TIME, thing))
		to_chat(src, SPAN_WARNING("You stop before your notes are done."))
		return FALSE
	if (QDELETED(thing) || get_dist(src, thing) > FIELD_STUDY_RANGE || !(carrier in list(l_hand, r_hand)))
		to_chat(src, SPAN_WARNING("You lost sight of what you were studying."))
		return FALSE
	var/points = commit_field_study(src, carrier, node_id, kind, thing.name)
	if (!points)
		return FALSE
	if (istype(carrier, /obj/item/weapon/paper))
		to_chat(src, SPAN_NOTICE("You finish your field notes on \the [thing]. Use them on a research bench working on <b>[N.name]</b>."))
	else
		to_chat(src, SPAN_NOTICE("You write your study of \the [thing] into [carrier]: <b>[N.name]</b> advances by [points] points."))
	return TRUE

/obj/item/weapon/paper/verb/study_in_field_paper()
	set name = "Study in the Field"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.study_in_field(src)

/obj/item/weapon/book/verb/study_in_field_book()
	set name = "Study in the Field"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.study_in_field(src)

// Field notes used on a bench working on the same subject.
/obj/structure/research_bench/proc/take_field_notes(obj/item/weapon/paper/P, mob/living/human/user)
	if (!istype(P) || !P.field_study_node)
		return FALSE
	var/obj/item/weapon/book/B = placed_book()
	var/datum/research_node/N = get_research_node(P.field_study_node)
	if (!B || assigned_node != P.field_study_node || !N)
		to_chat(user, SPAN_WARNING("These notes are about [N ? N.name : "something else"]. Put a book on the bench and research that subject first."))
		return TRUE
	if (!B.can_take_field_study(N.id, P.field_study_type))
		to_chat(user, SPAN_WARNING("[B] already holds this study, or as many as it takes for <b>[N.name]</b>."))
		return TRUE
	if (!user.remove_from_mob(P))
		return TRUE
	var/kind = P.field_study_type
	qdel(P)
	var/points = B.record_field_study(N.id, kind)
	user.gain_active_scholarship(N.id, points, "study:[N.id]:[kind]")
	to_chat(user, SPAN_NOTICE("You copy the field notes into [B]: <b>[N.name]</b> advances by [points] points[B.has_research_chapter(N.id) ? " and the chapter is finished" : ""]."))
	book_refresh_ui()
	return TRUE

#undef SUBJECT_PROTO_SHARE
#undef SUBJECT_PROTO_POINTS
#undef SUBJECT_PROTO_MAX
#undef FIELD_STUDY_POINTS
#undef FIELD_STUDY_MAX
#undef FIELD_STUDY_RANGE
#undef FIELD_STUDY_TIME
#undef TRIAL_BASE_CHANCE
#undef TRIAL_FAILURE_STEP
#undef TRIAL_SKILL_BONUS
#undef TRIAL_SKILL_PENALTY
#undef TRIAL_LESSON_POINTS
#undef TRIAL_LESSON_MAX
#undef TRIAL_CHARACTER_MAX
#undef TRIAL_MISHAP_TIER
#undef TRIAL_MISHAP_CHANCE
#undef TRIAL_RECORD_LIMIT
#undef REFERENCE_SLOW_START
#undef REFERENCE_SLOW_STEP
#undef REFERENCE_SLOW_FLOOR
#undef REFERENCE_SLOW_BUILDS
