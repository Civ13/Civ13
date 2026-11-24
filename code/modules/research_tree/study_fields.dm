// ============================================================
// Fields of study, Autistic and ADHD (Val, 2026-11-16)
// ------------------------------------------------------------
// Optional traits for a scholar who wants to focus on one discipline. Each
// speeds research and scholarship in its focus and slows the other applied
// disciplines a little; Basic Mathematics is never touched. They are never
// required: a character can take one in character setup or later from the
// Scholarship tab, drop it at any time, and never needs one at all.
//
// Balance (Fable review, Val chose the scaled boosts): the bench boost shrinks
// with the size of the discipline (Engineering is ~40% of all bench work,
// Medicine ~8%), so for a solo all-rounder every field is a small net loss
// over the whole tree and only a dedicated scholar comes out ahead. Reading
// chapters outside the focus is slower too, a cost a specialist can't hand
// off to friends because everyone studies chapters personally.
// ============================================================

var/global/list/study_field_traits = list(
	"Engineer" = "engineering",
	"Strategist" = "military",
	"Naturalist" = "natural_science",
	"Agronomist" = "agriculture",
	"Physician" = "medicine")

// Bench research speed in each field's own discipline.
var/global/list/study_field_focus_rate = list(
	"engineering" = 1.1,
	"military" = 1.2,
	"natural_science" = 1.3,
	"agriculture" = 1.4,
	"medicine" = 1.4)

#define STUDY_FIELD_FOCUS_GAIN 1.25  // scholarship gain in the focus
#define STUDY_FIELD_OTHER_GAIN 0.75  // scholarship gain in the other applied disciplines
#define STUDY_FIELD_OTHER_RATE 0.9   // bench speed in the other applied disciplines
#define STUDY_FIELD_OTHER_READING 1.15 // study time for chapters outside the focus
#define STUDY_FIELD_LOCK (7 * 24 * 36000) // real time between one change and the next pick

// Autistic: deep focus on a special interest, a settling-in cost on switching.
#define AUTISTIC_INTEREST_READING 0.8
#define AUTISTIC_SWITCH_READING 1.35
// ADHD: fast bursts, long unbroken sessions wear on you.
#define ADHD_READ_BURST 600        // first minute of a reading sitting
#define ADHD_READ_BURST_RATE 1.3
#define ADHD_READ_TIRE 1800        // after three minutes
#define ADHD_READ_TIRE_RATE 0.8
#define ADHD_READ_BREAK 600        // a minute away starts a new sitting
#define ADHD_BENCH_BURST 3000      // first five minutes at a bench
#define ADHD_BENCH_BURST_RATE 1.2
#define ADHD_BENCH_TIRE 12000      // after twenty minutes
#define ADHD_BENCH_TIRE_RATE 0.9
#define ADHD_BENCH_BREAK 1200      // two minutes away starts a new session

/mob/living/human
	// world.realtime before which a new field or interest can't be picked in
	// play. Saved with the body so the wait can't be dodged by a restart.
	var/study_field_lock = 0
	var/study_interest = null        // Autistic special interest without a field
	var/last_study_discipline = null // discipline of the last chapter studied
	var/tmp/adhd_read_start = 0
	var/tmp/adhd_read_last = -ADHD_READ_BREAK
	var/tmp/adhd_bench_start = 0
	var/tmp/adhd_bench_last = -ADHD_BENCH_BREAK

/mob/living/human/persistence_runtime_var(key)
	return key == "next_science_investigation" || key == "adhd_read_start" || key == "adhd_read_last" || key == "adhd_bench_start" || key == "adhd_bench_last" || ..()

// The discipline this character focuses on, or null.
/mob/living/human/proc/study_field()
	for (var/name in study_field_traits)
		if (find_trait(name))
			return study_field_traits[name]
	return null

/mob/living/human/proc/study_field_trait()
	for (var/name in study_field_traits)
		if (find_trait(name))
			return name
	return null

// Bench research speed for work in discipline.
/mob/living/human/proc/study_field_research_mult(discipline)
	var/field = study_field()
	if (!field || discipline == "mathematics")
		return 1
	if (discipline == field)
		return study_field_focus_rate[field]
	return STUDY_FIELD_OTHER_RATE

// Scholarship gained in discipline itself (not its Basic Mathematics share).
/mob/living/human/proc/study_field_gain_mult(discipline)
	var/field = study_field()
	if (!field || discipline == "mathematics")
		return 1
	return discipline == field ? STUDY_FIELD_FOCUS_GAIN : STUDY_FIELD_OTHER_GAIN

// Study time for a chapter of discipline.
/mob/living/human/proc/study_field_study_mult(discipline)
	var/field = study_field()
	if (!field || !discipline || discipline == "mathematics" || discipline == field)
		return 1
	return STUDY_FIELD_OTHER_READING

// ------------------------------------------------------------
// Autistic
// ------------------------------------------------------------

// The special interest: the field of study when there is one, else the
// discipline chosen from the Scholarship tab (Basic Mathematics allowed).
/mob/living/human/proc/special_interest()
	if (!find_trait("Autistic"))
		return null
	var/field = study_field()
	if (field)
		return field
	return (study_interest in scholar_disciplines) ? study_interest : null

// Study time for a chapter of node_id. Resuming a part-read chapter or
// returning to the special interest never costs a switch.
/mob/living/human/proc/autistic_study_mult(node_id)
	if (!find_trait("Autistic") || !node_id)
		return 1
	var/discipline = node_discipline(node_id)
	if (discipline == special_interest())
		return AUTISTIC_INTEREST_READING
	if (last_study_discipline && last_study_discipline != discipline && study_fraction(node_id) <= 0)
		return AUTISTIC_SWITCH_READING
	return 1

// ------------------------------------------------------------
// ADHD
// ------------------------------------------------------------

// Real time an ADHD reader needs for base_time of reading, starting
// sitting_time into the current sitting: x1.3 for the first minute, x1 until
// three minutes, x0.8 after that.
/proc/adhd_reading_time(base_time, sitting_time = 0)
	var/real = 0
	var/t = max(0, sitting_time)
	var/left = max(0, base_time)
	if (left > 0 && t < ADHD_READ_BURST)
		var/span = min(ADHD_READ_BURST - t, left / ADHD_READ_BURST_RATE)
		real += span
		left -= span * ADHD_READ_BURST_RATE
		t += span
	if (left > 0 && t < ADHD_READ_TIRE)
		var/span = min(ADHD_READ_TIRE - t, left)
		real += span
		left -= span
		t += span
	if (left > 0)
		real += left / ADHD_READ_TIRE_RATE
	return real

// Real reading time for base_time, starting or continuing a sitting.
/mob/living/human/proc/adhd_begin_reading(base_time)
	if (!find_trait("ADHD"))
		return base_time
	if (world.time - adhd_read_last > ADHD_READ_BREAK)
		adhd_read_start = world.time
	return max(1, round(adhd_reading_time(base_time, world.time - adhd_read_start)))

/mob/living/human/proc/adhd_end_reading()
	adhd_read_last = world.time

// Bench speed for the session so far.
/mob/living/human/proc/adhd_bench_mult()
	if (!find_trait("ADHD"))
		return 1
	if (world.time - adhd_bench_last > ADHD_BENCH_BREAK)
		return ADHD_BENCH_BURST_RATE // a fresh session
	var/session = world.time - adhd_bench_start
	if (session < ADHD_BENCH_BURST)
		return ADHD_BENCH_BURST_RATE
	if (session >= ADHD_BENCH_TIRE)
		return ADHD_BENCH_TIRE_RATE
	return 1

// Called each bench tick for the scholar who set the pace.
/mob/living/human/proc/note_bench_work()
	if (world.time - adhd_bench_last > ADHD_BENCH_BREAK)
		adhd_bench_start = world.time
	adhd_bench_last = world.time

/proc/study_field_summary(name)
	var/discipline = study_field_traits[name]
	if (!discipline)
		return ""
	return "[scholar_disciplines[discipline]] research x[study_field_focus_rate[discipline]] and its scholarship grows 25% faster. Other disciplines except Basic Mathematics: research x0.9, scholarship grows 25% slower and their chapters take 15% longer to study."

// ------------------------------------------------------------
// Picking a field in play
// ------------------------------------------------------------

/mob/living/human/proc/study_field_wait_text()
	var/left = study_field_lock - world.realtime
	if (left <= 0)
		return null
	var/hours = round(left / 36000)
	if (hours >= 24)
		return "[round(hours / 24)] day\s and [hours % 24] hour\s"
	return hours >= 1 ? "[hours] hour\s" : "less than an hour"

/mob/living/human/proc/study_field_choices()
	. = list()
	// Only the field's own exclusions matter: body traits can include ones
	// added at spawn (climate, background) that are not player choices.
	for (var/name in study_field_traits)
		var/list/exclusions = trait_list[name] ? trait_list[name][2] : list()
		var/blocked = FALSE
		for (var/other in exclusions)
			if (!(other in study_field_traits) && find_trait(other))
				blocked = TRUE
				break
		if (!blocked)
			. += name

/mob/living/human/proc/set_study_field(name)
	traits -= study_field_traits
	if (name)
		traits += name
	traits_dirty = TRUE
	study_field_lock = world.realtime + STUDY_FIELD_LOCK

/mob/living/human/proc/set_study_interest(discipline)
	study_interest = discipline
	study_field_lock = world.realtime + STUDY_FIELD_LOCK

/mob/living/human/verb/choose_field_of_study()
	set name = "Choose field of study"
	set category = "IC"
	set desc = "Optionally focus your studies on one discipline, at a cost to the others."
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("Scholarship isn't used here."))
		return
	if (stat == DEAD)
		return
	var/current = study_field_trait()
	var/wait = study_field_wait_text()
	var/list/options = list()
	if (current)
		options["Drop [current] (no field)"] = "none"
	if (!wait)
		for (var/name in study_field_choices())
			if (name != current)
				options["[name] ([scholar_disciplines[study_field_traits[name]]])"] = name
		if (find_trait("Autistic") && !current)
			for (var/discipline in scholar_disciplines)
				if (discipline != study_interest)
					options["Special interest: [scholar_disciplines[discipline]]"] = "interest:[discipline]"
	if (!options.len)
		to_chat(src, SPAN_WARNING(wait ? "You changed your field of study recently. You can pick a new one in [wait]." : "None of the fields of study suits your other traits."))
		return
	options["Cancel"] = null
	var/list/intro = list("A field of study is optional. It speeds your research in one discipline and slows the others a little; Basic Mathematics is never affected. After any change you must wait 7 real days before picking again.")
	if (current)
		intro += "You are a [current] now."
	else if (special_interest())
		intro += "Your special interest is [scholar_disciplines[special_interest()]]."
	if (wait)
		intro += "You can drop your field now and pick again in [wait]."
	var/choice = player_input(src, jointext(intro, " "), "Field of study", null, "anything", options, TRUE)
	if (!choice || !options[choice] || stat == DEAD)
		return
	var/picked = options[choice]
	if (picked == "none")
		if (study_field_trait() != current)
			return
		set_study_field(null)
		to_chat(src, SPAN_NOTICE("You no longer focus on one field of study. You can pick again in 7 real days."))
		return
	if (study_field_wait_text())
		return
	if (copytext(picked, 1, 10) == "interest:")
		var/discipline = copytext(picked, 10)
		if (!find_trait("Autistic") || study_field_trait() || !(discipline in scholar_disciplines))
			return
		set_study_interest(discipline)
		to_chat(src, SPAN_NOTICE("Your special interest is now <b>[scholar_disciplines[discipline]]</b>."))
		return
	if (!(picked in study_field_choices()))
		return
	if (player_alert(src, study_field_summary(picked), "Become a [picked]?", list("Yes", "No")) != "Yes" || study_field_wait_text())
		return
	set_study_field(picked)
	to_chat(src, SPAN_NOTICE("You now focus your studies as a <b>[picked]</b>."))

// Rows for the Scholarship tab.
/mob/living/human/proc/study_field_panel_rows()
	var/list/rows = list()
	var/field = study_field_trait()
	rows[++rows.len] = list("<b>Field of study:</b>", field ? "[field] ([scholar_disciplines[study_field_traits[field]]])" : "None (optional, see Choose field of study)")
	if (find_trait("Autistic"))
		var/interest = special_interest()
		rows[++rows.len] = list("<b>Special interest:</b>", interest ? scholar_disciplines[interest] : "None chosen yet")
	var/wait = study_field_wait_text()
	if (wait)
		rows[++rows.len] = list("<b>Next change:</b>", "in [wait]")
	return rows
