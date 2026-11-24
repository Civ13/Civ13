// ============================================================
// Research Tree - learning by doing (Val, 2026-11-14)
// ------------------------------------------------------------
// "There should be ways to advance research that aren't only sitting around
// waiting for a timer." On book-research worlds:
//  - Scholarship from active work: field work, practice, prototypes, field
//    study, samples and demonstrations wrote chapter points but taught no
//    scholarship, so the skill each era needs still came from bench time.
//    Each now teaches the scholarship the same points would have earned at
//    the bench, and half as much again. Each piece of work teaches a
//    character once, so swapping in a fresh book teaches nothing new.
//  - Variety: the first time a character makes, performs or harvests each
//    different thing teaches its body skill far more than a repeat, and long
//    runs of the same thing teach less.
//  - Beside a master: working within reach of someone clearly more skilled
//    doubles what the action teaches.
// ============================================================

// Scholarship for points written by active work, against the same points
// earned at the bench (SCHOLAR_RESEARCH_GAIN each).
#define SCHOLAR_ACTIVE_GAIN_RATE 1.5
// A demonstration writes no points; it teaches as this share of the subject.
#define SCHOLAR_DEMONSTRATION_SHARE 0.2
// The most lessons and kinds of work a character keeps track of.
#define SCHOLAR_LESSON_LIMIT 600
#define SKILL_VARIETY_LIMIT 500
// Skill gain by how often this character has done this exact thing before.
#define SKILL_VARIETY_FIRST 5      // never before
#define SKILL_VARIETY_NORMAL_UNTIL 5 // the 2nd to 5th time: the usual gain
#define SKILL_VARIETY_TIRED_UNTIL 10 // the 6th to 10th time
#define SKILL_VARIETY_TIRED 0.5
#define SKILL_VARIETY_ROTE 0.25    // from then on
// Beside a master: how close, how much better they must be, and the gain.
#define SKILL_MASTER_REACH 2
#define SKILL_MASTER_LEAD 1.25
#define SKILL_MASTER_GAIN 2
// The most one action may teach crafting, as an adaptStat multiplier: about
// 2% of the skill. Stack recipes teach by material used, five times over for
// a first try, so a few first crafts of big things (a well, a bed, a bench)
// once took crafting from 100 to the 250 cap and paid every mastery milestone
// (Val, 2026-11-17).
#define SKILL_CRAFTING_GAIN_CAP 10

// Body skills a master can pass on by example.
var/global/list/skill_master_stats = list("crafting", "medical", "farming", "hunting", "throwing", "swords", "bows", "rifle", "pistol", "machinegun", "philosophy", "swimming", "unarmed")

/mob/living/human
	var/list/scholar_lessons = null // lesson keys this character has already learned from
	var/list/skill_variety = null   // "stat:thing" => times done, up to SKILL_VARIETY_TIRED_UNTIL
	var/list/skill_mastery = null   // mastery milestones already paid, "mastery:discipline:value"

/proc/learning_by_doing_enabled()
	return map && map.book_research_enabled()

// ---------- Philosophy from learning and teaching ----------

// Philosophy gates language books and holy books, but on book-research worlds
// nothing raised it: its only gains were in the old research desk and
// bookcase. It now grows from the life of a scholar. `what` names the exact
// thing done, so the variety rules apply: each new chapter studied, taught,
// written or compared teaches five times what a repeat does, and rote
// repeats teach almost nothing.
#define PHILOSOPHY_STUDY 1
#define PHILOSOPHY_TUTOR 0.5
#define PHILOSOPHY_WRITE 0.6
#define PHILOSOPHY_COMPARE 0.6

/mob/living/human/proc/gain_philosophy(amount, what)
	if (!learning_by_doing_enabled() || amount <= 0 || stat == DEAD)
		return FALSE
	adaptStat("philosophy", amount, what)
	return TRUE

// ---------- Scholarship from active work ----------

// Teaches the scholarship of `points` chapter points written by active work
// on node_id. lesson_key names the piece of work; each teaches once.
// Returns the discipline levels gained.
/mob/living/human/proc/gain_active_scholarship(node_id, points, lesson_key)
	if (!learning_by_doing_enabled() || stat == DEAD || !isnum(points) || points <= 0 || !istext(lesson_key) || !valid_recipe_node_id(node_id))
		return 0
	if (!islist(scholar_lessons))
		scholar_lessons = list()
	if ((lesson_key in scholar_lessons) || scholar_lessons.len >= SCHOLAR_LESSON_LIMIT)
		return 0
	scholar_lessons += lesson_key
	var/discipline = node_discipline(node_id)
	var/before = scholar_level(discipline)
	gain_scholarship(node_id, points * SCHOLAR_RESEARCH_GAIN * SCHOLAR_ACTIVE_GAIN_RATE)
	var/gained = round(scholar_level(discipline) - before, 0.01)
	if (gained > 0)
		to_chat(src, SPAN_NOTICE("The work teaches you something of [scholar_disciplines[discipline]]."))
	return gained

// What a demonstration teaches: it writes no points of its own.
/proc/demonstration_lesson_points(datum/research_node/N)
	return N ? max(1, round(N.cost_ticks * SCHOLAR_DEMONSTRATION_SHARE)) : 0

/proc/clean_scholar_lessons(value)
	var/list/result = list()
	if (islist(value))
		for (var/key in value)
			if (istext(key) && length(key) && length(key) <= 160 && result.len < SCHOLAR_LESSON_LIMIT)
				result |= key
	return result

// ---------- Variety and masters for body skills ----------

/proc/clean_skill_variety(value)
	var/list/result = list()
	if (islist(value))
		for (var/key in value)
			if (!istext(key) || !length(key) || length(key) > 160 || result.len >= SKILL_VARIETY_LIMIT)
				continue
			var/count = value[key]
			if (isnum(count) && count >= 1)
				result[key] = min(SKILL_VARIETY_TIRED_UNTIL, round(count))
	return result

// The multiplier for doing variety_key once more, by how often before.
/proc/skill_variety_factor(times_before)
	if (times_before <= 0)
		return SKILL_VARIETY_FIRST
	if (times_before < SKILL_VARIETY_NORMAL_UNTIL)
		return 1
	if (times_before < SKILL_VARIETY_TIRED_UNTIL)
		return SKILL_VARIETY_TIRED
	return SKILL_VARIETY_ROTE

// Counts one more of variety_key for statname and returns its multiplier.
/mob/living/human/proc/skill_variety_mult(statname, variety_key)
	if (!learning_by_doing_enabled() || isnull(variety_key))
		return 1
	var/key = "[statname]:[variety_key]"
	if (length(key) > 160)
		return 1
	if (!islist(skill_variety))
		skill_variety = list()
	var/before = skill_variety[key]
	if (!isnum(before))
		// A full record stops counting new things; they teach as usual.
		if (skill_variety.len >= SKILL_VARIETY_LIMIT)
			return 1
		before = 0
	if (before < SKILL_VARIETY_TIRED_UNTIL)
		skill_variety[key] = before + 1
	return skill_variety_factor(before)

// The most one gain may teach statname, as an adaptStat multiplier, or null
// for no limit. Applied after variety, masters and traits.
/mob/living/human/proc/skill_gain_cap(statname)
	if (statname == "crafting" && learning_by_doing_enabled())
		return SKILL_CRAFTING_GAIN_CAP
	return null

// Someone nearby, awake and clearly better at statname.
/mob/living/human/proc/skill_master_nearby(statname)
	if (!learning_by_doing_enabled() || !(statname in skill_master_stats) || !isturf(loc) || !islist(stats[statname]))
		return null
	var/mine = stats[statname][1]
	for (var/mob/living/human/M in range(SKILL_MASTER_REACH, src))
		if (M == src || M.stat != CONSCIOUS || !M.research_presence() || !islist(M.stats) || !islist(M.stats[statname]))
			continue
		if (M.stats[statname][1] >= mine * SKILL_MASTER_LEAD)
			return M
	return null

/mob/living/human/proc/skill_master_mult(statname)
	return skill_master_nearby(statname) ? SKILL_MASTER_GAIN : 1

// The Craftsman pilot teaches the existing Crafting skill, not a new skill
// or a benefit of selecting a trade. Call only after the useful work commits.
/mob/living/human/proc/note_craftsman_work(lesson, result_type, effort)
	if (!learning_by_doing_enabled() || stat != CONSCIOUS || !ispath(result_type) || effort <= 0)
		return
	adaptStat("crafting", effort, "craftsman:[lesson]:[result_type]")

// ---------- Mastery: body skills teach their scholarship ----------
// Player suggestion (Localbox, relayed by Val 2026-11-14): reaching a milestone
// in a body skill, or maxing it, gives a large piece of the scholarship that
// goes with it, "so you actually feel like a master". Each milestone pays a
// discipline once per character, whichever skill reaches it first, so six
// weapon skills do not pay Military Science six times. Building walls and
// the like already pay through deeds and practice (practice_work.dm) and
// raise crafting, so there is no separate count for them.

// body skill => the discipline it belongs to.
var/global/list/skill_mastery_disciplines = list(
	"medical" = "medicine",
	"crafting" = "engineering",
	"farming" = "agriculture",
	"hunting" = "agriculture",
	"philosophy" = "mathematics",
	"swords" = "military",
	"bows" = "military",
	"rifle" = "military",
	"pistol" = "military",
	"machinegun" = "military",
	"throwing" = "military",
	"unarmed" = "military",
	"swimming" = "natural_science")

// Milestones: skill value reached, scholarship levels given, what it makes you.
// The last is the most a skill can reach.
var/global/list/skill_mastery_milestones = list(
	list(150, 4, "skilled"),
	list(200, 8, "expert"),
	list(250, 12, "master"))

/proc/clean_skill_mastery(value)
	var/list/result = list()
	if (islist(value))
		for (var/key in value)
			if (istext(key) && findtext(key, "mastery:") == 1 && length(key) <= 60 && result.len < 40)
				result |= key
	return result

/proc/skill_mastery_key(discipline, value)
	return "mastery:[discipline]:[value]"

// The most one gain may carry statname from value: the next milestone above
// it, so a big jump (a first try at a large recipe beside a master, a eureka,
// an old study book) stops at each milestone and pays it as it is reached
// instead of skipping to the cap and paying them all at once.
/mob/living/human/proc/skill_mastery_ceiling(statname, value)
	if (!isnum(value) || !skill_mastery_disciplines[statname] || !learning_by_doing_enabled())
		return null
	for (var/list/M in skill_mastery_milestones)
		if (value < M[1] - 0.01)
			return M[1]
	return null

// Pays every milestone statname has reached and its discipline has not yet
// been paid for. Returns the scholarship levels gained.
/mob/living/human/proc/note_skill_mastery(statname)
	. = 0
	var/discipline = skill_mastery_disciplines[statname]
	if (!discipline || !learning_by_doing_enabled() || stat == DEAD || !islist(stats[statname]))
		return
	var/value = stats[statname][1]
	if (!isnum(value) || value < skill_mastery_milestones[1][1])
		return
	if (!islist(skill_mastery))
		skill_mastery = list()
	for (var/list/M in skill_mastery_milestones)
		// A hair under the mark counts: gains are rounded on the way up.
		if (value < M[1] - 0.01)
			break
		var/key = skill_mastery_key(discipline, M[1])
		if (key in skill_mastery)
			continue
		skill_mastery += key
		if (!islist(scholarship))
			scholarship = list()
		var/before = scholar_level(discipline)
		scholarship[discipline] = min(SCHOLAR_MAX_LEVEL, round(before + M[2], 0.01))
		var/gained = scholarship[discipline] - before
		. += gained
		to_chat(src, SPAN_NOTICE("<b>You have become \a [M[3]] at [statname].</b> What your hands know now, your mind keeps: you gain [round(gained, 0.1)] levels of [scholar_disciplines[discipline]]."))

// First Master in any school pays Military Science once, like the body-skill
// milestones above (martial_schools.dm names the levels). Returns the levels gained.
/mob/living/human/proc/note_martial_mastery(levels)
	. = 0
	if (!learning_by_doing_enabled() || stat == DEAD)
		return
	var/key = skill_mastery_key("military", "school")
	if (!islist(skill_mastery))
		skill_mastery = list()
	if (key in skill_mastery)
		return
	skill_mastery += key
	if (!islist(scholarship))
		scholarship = list()
	var/before = scholar_level("military")
	scholarship["military"] = min(SCHOLAR_MAX_LEVEL, round(before + levels, 0.01))
	. = scholarship["military"] - before
	to_chat(src, SPAN_NOTICE("<b>You have mastered a fighting school.</b> What your body knows now, your mind keeps: you gain [round(., 0.1)] levels of [scholar_disciplines["military"]]."))

// ---------- Saved with the character ----------

/mob/living/human/persistence_import_fields(list/saved_fields)
	. = ..()
	scholar_lessons = clean_scholar_lessons(scholar_lessons)
	skill_variety = clean_skill_variety(skill_variety)
	skill_mastery = clean_skill_mastery(skill_mastery)
	if (stat == DEAD)
		scholar_lessons = list()
		skill_variety = list()
		skill_mastery = list()

/mob/living/human/forget_recipe_knowledge()
	..()
	scholar_lessons = list()

/mob/living/human/proc/philosophy_from_study(node_id)
	return gain_philosophy(PHILOSOPHY_STUDY, "study:[node_id]")

/mob/living/human/proc/philosophy_from_tutoring(node_id, mob/living/human/student)
	return gain_philosophy(PHILOSOPHY_TUTOR, "tutor:[node_id]:[student ? student.scholar_identity() : ""]")

/mob/living/human/proc/philosophy_from_writing(node_id)
	return gain_philosophy(PHILOSOPHY_WRITE, "write:[node_id]")

/mob/living/human/proc/philosophy_from_comparing(node_id, mob/living/human/partner)
	return gain_philosophy(PHILOSOPHY_COMPARE, "compare:[node_id]:[partner ? partner.scholar_identity() : ""]")

#undef PHILOSOPHY_STUDY
#undef PHILOSOPHY_TUTOR
#undef PHILOSOPHY_WRITE
#undef PHILOSOPHY_COMPARE
#undef SCHOLAR_ACTIVE_GAIN_RATE
#undef SCHOLAR_DEMONSTRATION_SHARE
#undef SCHOLAR_LESSON_LIMIT
#undef SKILL_VARIETY_LIMIT
#undef SKILL_VARIETY_FIRST
#undef SKILL_VARIETY_NORMAL_UNTIL
#undef SKILL_VARIETY_TIRED_UNTIL
#undef SKILL_VARIETY_TIRED
#undef SKILL_VARIETY_ROTE
#undef SKILL_MASTER_REACH
#undef SKILL_MASTER_LEAD
#undef SKILL_MASTER_GAIN
#undef SKILL_CRAFTING_GAIN_CAP
