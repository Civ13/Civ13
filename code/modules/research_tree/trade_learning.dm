// ============================================================
// Research Tree - learning a trade from someone (Val, 2026-11-14)
// ------------------------------------------------------------
// The only way to learn a subject was to read its chapter for a set time.
// On book-research worlds a subject can now also pass from hand to hand:
//  - Watching: standing within reach while someone who knows a subject makes
//    its things fills part of your study of it, once per kind of thing.
//  - Guided work: with that person still within reach, you may make the
//    subject's things yourself. Each one fills more. Some attempts fail.
// Both add to the same study progress reading uses (study_progress.dm), so a
// half-read chapter and a half-served apprenticeship add up. Early subjects
// can be learned wholly this way; later ones only half, and the rest is read.
// Books stay the only way to carry knowledge over distance, time and death.
// ============================================================

#define TRADE_REACH 2
// Share of a subject each kind of thing watched fills, and how many kinds count.
#define TRADE_WATCH_SHARE 0.15
#define TRADE_WATCH_MAX 3
// Share each thing made under guidance fills, and a failed attempt's share.
#define TRADE_GUIDED_SHARE 0.2
#define TRADE_GUIDED_FAILED_SHARE 0.1
// Subjects below this era tier can be learned wholly from a teacher; later
// ones only up to TRADE_LATE_CAP.
#define TRADE_FULL_BELOW_TIER 5
#define TRADE_LATE_CAP 0.5
// Guided attempts fail this often (percent) at ordinary crafting skill, less
// for skilled hands, never below the floor.
#define TRADE_GUIDED_FAIL 30
#define TRADE_GUIDED_FAIL_FLOOR 5
// What teaching a pupil through a subject is worth to the teacher, as a
// share of the subject (learning_by_doing.dm).
#define TRADE_TEACHER_SHARE 0.1
#define TRADE_RECORD_LIMIT 400

/mob/living/human
	var/list/trade_watched = null // "node>path" => 1 for each kind of thing watched, "node" => kinds watched

// How much of a subject can be learned from a teacher.
/proc/trade_learning_cap(datum/research_node/N)
	if (!N)
		return 0
	// A spreading subject (knowledge_spread.dm) can be learned wholly by hand.
	return (N.era_tier < TRADE_FULL_BELOW_TIER || knowledge_band(N.id) == KNOWLEDGE_SPREADING) ? 1 : TRADE_LATE_CAP

// Whether src could learn more of node_id from a teacher now.
/mob/living/human/proc/can_learn_trade(node_id)
	if (!map || !map.book_research_enabled() || stat != CONSCIOUS)
		return FALSE
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || research_node_dormant(N) || N.mode == RESEARCH_MODE_BOOK)
		return FALSE
	if (knows_recipe_node(node_id) || !knows_research_prereqs(node_id))
		return FALSE
	return study_fraction(node_id) < trade_learning_cap(N)

// Someone within reach, awake and present, who knows node_id.
/mob/living/human/proc/trade_teacher(node_id)
	if (!isturf(loc))
		return null
	for (var/mob/living/human/M in range(TRADE_REACH, src))
		if (M == src || M.stat != CONSCIOUS || !isturf(M.loc) || !M.research_presence())
			continue
		if (M.knows_recipe_node(node_id))
			return M
	return null

/mob/living/human/proc/trade_watch_count(key)
	if (!islist(trade_watched))
		return 0
	var/value = trade_watched[key]
	return isnum(value) ? max(0, value) : 0

/proc/clean_trade_watched(value)
	var/list/result = list()
	if (islist(value))
		for (var/key in value)
			if (!istext(key) || !length(key) || length(key) > 200 || result.len >= TRADE_RECORD_LIMIT)
				continue
			var/count = value[key]
			if (isnum(count) && count >= 1)
				result[key] = min(TRADE_WATCH_MAX, round(count))
	return result

/mob/living/human/persistence_import_fields(list/saved_fields)
	. = ..()
	trade_watched = clean_trade_watched(trade_watched)
	if (stat == DEAD)
		trade_watched = list()

/mob/living/human/forget_recipe_knowledge()
	..()
	trade_watched = list()

// Adds share of node_id to what src has learned of it. Reaching the whole of
// an early subject teaches it. Returns the share actually added.
/mob/living/human/proc/add_trade_learning(node_id, share, mob/living/human/teacher)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || share <= 0 || !can_learn_trade(node_id))
		return 0
	var/cap = trade_learning_cap(N)
	var/before = study_fraction(node_id)
	var/after = min(cap, before + share)
	if (after >= 1)
		if (!learn_recipe_node(node_id))
			return 0
		clear_study_progress(node_id)
		gain_scholarship(node_id, SCHOLAR_STUDY_GAIN * SCHOLAR_TUTOR_GAIN_MULT)
		to_chat(src, SPAN_NOTICE("You have it now: you have learned <b>[N.name]</b>[teacher ? " from [teacher]" : ""] without opening a book."))
		reward_trade_teacher(teacher, N)
		tutorial_event_for(src, "research")
		return 1 - before
	note_study_progress(node_id, after)
	if (after >= cap)
		to_chat(src, SPAN_NOTICE("You have learned all of <b>[N.name]</b> that hands can show you ([round(after * 100)]%). The rest has to be read from its chapter."))
		reward_trade_teacher(teacher, N)
	else
		to_chat(src, SPAN_NOTICE("You understand more of <b>[N.name]</b> ([round(after * 100)]%)."))
	return after - before

// Teaching someone through a subject teaches the teacher too, once per pupil.
/mob/living/human/proc/reward_trade_teacher(mob/living/human/teacher, datum/research_node/N)
	if (!istype(teacher) || !N || teacher == src)
		return 0
	to_chat(teacher, SPAN_NOTICE("[src] has learned what you could show of <b>[N.name]</b>."))
	return teacher.gain_active_scholarship(N.id, max(1, round(N.cost_ticks * TRADE_TEACHER_SHARE)), "taught:[N.id]:[scholar_identity()]")

// ---------- Watching ----------

// Called when someone finishes making something (practice_work.dm): people
// within reach who could learn its subject pick some of it up.
/proc/note_craft_watched(mob/user, result_path_string)
	var/mob/living/human/maker = user
	if (!istype(maker) || !isturf(maker.loc) || !map || !map.book_research_enabled())
		return 0
	var/node_id = get_recipe_node_req(result_path_string)
	if (!istext(node_id) || !maker.knows_recipe_node(node_id))
		return 0
	var/taught = 0
	var/kind = "[node_id]>[result_path_string]"
	if (length(kind) > 200)
		return 0
	for (var/mob/living/human/watcher in range(TRADE_REACH, maker))
		if (watcher == maker || !isturf(watcher.loc) || !watcher.research_presence() || !watcher.can_learn_trade(node_id))
			continue
		if (watcher.trade_watch_count(kind) || watcher.trade_watch_count(node_id) >= TRADE_WATCH_MAX)
			continue
		if (!islist(watcher.trade_watched))
			watcher.trade_watched = list()
		if (watcher.trade_watched.len + 2 > TRADE_RECORD_LIMIT)
			continue
		watcher.trade_watched[kind] = 1
		watcher.trade_watched[node_id] = watcher.trade_watch_count(node_id) + 1
		to_chat(watcher, SPAN_NOTICE("You watch closely how [maker] makes it."))
		if (watcher.add_trade_learning(node_id, TRADE_WATCH_SHARE, maker))
			taught++
	return taught

// ---------- Guided work ----------

// The subject H could make result_path_string for under guidance, or null.
/proc/guided_work_node(mob/living/human/H, result_path_string)
	if (!istype(H) || !istext(result_path_string) || !map || !map.book_research_enabled())
		return null
	var/node_id = get_recipe_node_req(result_path_string)
	if (!istext(node_id) || !H.can_learn_trade(node_id) || !H.trade_teacher(node_id))
		return null
	return node_id

/proc/guided_work_allowed(mob/living/human/H, result_path_string)
	return guided_work_node(H, result_path_string) ? TRUE : FALSE

// Percent of guided attempts a pupil spoils, by their crafting skill.
/mob/living/human/proc/guided_fail_chance()
	var/skill = islist(stats) && islist(stats["crafting"]) ? stats["crafting"][1] : 100
	return clamp(round(TRADE_GUIDED_FAIL - (skill - 100) * 0.6), TRADE_GUIDED_FAIL_FLOOR, TRADE_GUIDED_FAIL)

// A spoiled guided attempt: the materials are gone, the lesson is not.
/proc/commit_guided_failure(mob/living/human/H, node_id, result_path_string)
	var/mob/living/human/teacher = H.trade_teacher(node_id)
	var/turf/T = get_turf(H)
	if (T)
		var/obj/item/trash/failed_attempt/ruin = new(T)
		var/atom/made = text2path(result_path_string)
		if (ispath(made))
			ruin.name = "ruined [initial(made.name)]"
	to_chat(H, SPAN_WARNING("You spoil the piece and the materials with it. [teacher ? "[teacher] shows you where it went wrong." : "You see where it went wrong."]"))
	return H.add_trade_learning(node_id, TRADE_GUIDED_FAILED_SHARE, teacher)

// Called when something is made (practice_work.dm). TRUE if it was guided
// work, which then is no prototype.
/proc/record_guided_work(mob/user, result_path_string)
	var/mob/living/human/H = user
	var/node_id = guided_work_node(H, result_path_string)
	if (!node_id)
		return FALSE
	H.add_trade_learning(node_id, TRADE_GUIDED_SHARE, H.trade_teacher(node_id))
	return TRUE

#undef TRADE_REACH
#undef TRADE_WATCH_SHARE
#undef TRADE_WATCH_MAX
#undef TRADE_GUIDED_SHARE
#undef TRADE_GUIDED_FAILED_SHARE
#undef TRADE_FULL_BELOW_TIER
#undef TRADE_LATE_CAP
#undef TRADE_GUIDED_FAIL
#undef TRADE_GUIDED_FAIL_FLOOR
#undef TRADE_TEACHER_SHARE
#undef TRADE_RECORD_LIMIT
