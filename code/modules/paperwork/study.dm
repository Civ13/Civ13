// Deliberate study: a character slowly works through writing in a language
// they cannot read and earns progress toward learning that language, the same
// progress hearing it spoken gives. Each section version is credited once per
// character. Faithful copies keep their lineage, so copying a page grants
// nothing new; an edit bumps the version and can be studied again.
#define PAPER_STUDY_TICKS_PER_POINT 20 // 2 seconds of study per point
#define PAPER_STUDY_MAX_POINTS 25 // one section gives at most this much progress
#define PAPER_STUDY_CHARS_PER_POINT 8 // about one word
#define PAPER_STUDY_MEMORY 1000 // studied sections remembered per character

// lineage -> highest studied version. Saved with the character, not the client.
/mob/living/human/var/list/studied_paper_sections = null

// First section the reader cannot read and has not studied at this version.
/proc/paper_study_candidate(mob/reader, list/record, list/studied)
	if (!paper_document_record_valid(record))
		return null
	var/list/sections = record["sections"]
	for (var/list/section in sections)
		if (!paper_written_language(section["language_id"]))
			continue
		if (paper_knows_written_language(reader, section["language_id"]))
			continue
		if (islist(studied) && (section["lineage"] in studied) && studied[section["lineage"]] >= section["version"])
			continue
		return section
	return null

/proc/paper_study_points(text)
	return max(1, min(PAPER_STUDY_MAX_POINTS, round(length(text) / PAPER_STUDY_CHARS_PER_POINT)))

/proc/paper_study_examine_hint(mob/user, obj/item/weapon/paper/P)
	var/mob/living/human/H = user
	if (!istype(H) || !P || isnull(P.document_record))
		return
	if (paper_study_candidate(H, P.document_record, H.studied_paper_sections))
		to_chat(H, SPAN_NOTICE("You can't read some of this writing. Hold the paper and use <b>Study Writing</b> (right-click) to slowly learn the language from it."))

/obj/item/weapon/paper/verb/study_writing()
	set name = "Study Writing"
	set category = null
	set src in usr
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H.restrained() || loc != H)
		to_chat(usr, SPAN_WARNING("You need to hold the paper in your hands to study it."))
		return
	paper_study(H, src)

/proc/paper_study(mob/living/human/H, obj/item/weapon/paper/P)
	var/list/section = paper_study_candidate(H, P.document_record, H.studied_paper_sections)
	if (!section)
		to_chat(H, SPAN_NOTICE("There is nothing on [P] in a language you don't know that you haven't already studied."))
		return FALSE
	var/datum/language/L = paper_written_language(section["language_id"])
	var/lineage = section["lineage"]
	var/version = section["version"]
	var/points = paper_study_points(section["text"])
	var/delay = points * PAPER_STUDY_TICKS_PER_POINT
	H.visible_message(SPAN_NOTICE("[H] starts studying [P] closely."), SPAN_NOTICE("You start puzzling over the [L.name] writing on [P]. This will take about [round(delay / 10)] seconds, and you need to hold still."))
	if (!do_after(H, delay, P))
		to_chat(H, SPAN_WARNING("You stop studying [P]."))
		return FALSE
	if (P.gc_destroyed || P.loc != H || H.stat)
		return FALSE
	// The page or the reader may have changed during the wait; credit only the
	// exact section version that was studied, and only once.
	var/list/again = paper_study_candidate(H, P.document_record, H.studied_paper_sections)
	if (!again || again["lineage"] != lineage || again["version"] != version)
		to_chat(H, SPAN_WARNING("The writing on [P] changed while you were studying it."))
		return FALSE
	return paper_study_credit(H, L, lineage, version, points)

/proc/paper_study_credit(mob/living/human/H, datum/language/L, lineage, version, points)
	if (!islist(H.studied_paper_sections))
		H.studied_paper_sections = list()
	H.studied_paper_sections -= lineage
	H.studied_paper_sections[lineage] = version
	if (H.studied_paper_sections.len > PAPER_STUDY_MEMORY)
		H.studied_paper_sections.Cut(1, 2)
	var/lname = capitalize(L.name)
	H.partial_languages[lname] += points
	if (H.partial_languages[lname] >= L.difficulty && H.add_language(lname, FALSE))
		H.add_note("Known Languages", "[L.name]")
		to_chat(H, SPAN_NOTICE("You've learned <b>[L.name]</b> from studying its writing!"))
	else
		var/percent = min(99, round(H.partial_languages[lname] * 100 / L.difficulty))
		to_chat(H, SPAN_NOTICE("You make sense of a little more [L.name]. You now understand about [percent]% of it."))
	return TRUE

#undef PAPER_STUDY_TICKS_PER_POINT
#undef PAPER_STUDY_MAX_POINTS
#undef PAPER_STUDY_CHARS_PER_POINT
#undef PAPER_STUDY_MEMORY
