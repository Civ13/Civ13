// ============================================================
// Research Tree - chapters are written in a language
// ------------------------------------------------------------
// On book-research worlds each research chapter records the language it was
// written in: the writing language of whoever researched, wrote or hand-copied
// it. A reader below Broken in that language cannot study the chapter, and one
// below Fluent studies it more slowly. Hand-copying a chapter needs
// Conversational in its language and writes the copy in the copier's own
// writing language, which is how a book is translated. A printed copy and a
// torn-out chapter keep the language they had. A chapter with no recorded
// language (starting books, admin books) is plain to everyone.
// ============================================================

/obj/item/weapon/book
	var/chapter_languages = ""	// "node_id=Language;node_id=Language"

/obj/item/weapon/paper/research_page
	var/chapter_language = ""	// the language of the torn-out chapter

/obj/item/weapon/book/proc/chapter_language_map()
	var/list/languages = list()
	if (!istext(chapter_languages) || !length(chapter_languages))
		return languages
	for (var/entry in splittext(chapter_languages, ";"))
		var/cut = findtext(entry, "=")
		if (cut > 1 && cut < length(entry))
			languages[copytext(entry, 1, cut)] = copytext(entry, cut + 1)
	return languages

/obj/item/weapon/book/proc/set_chapter_language(node_id, language_name)
	var/list/languages = chapter_language_map()
	languages -= node_id
	if (istext(language_name) && all_languages[language_name])
		languages[node_id] = language_name
	var/list/entries = list()
	for (var/id in languages)
		entries += "[id]=[languages[id]]"
	chapter_languages = jointext(entries, ";")

// The language a chapter is written in, or null when it is plain to everyone.
/obj/item/weapon/book/proc/chapter_language(node_id)
	var/list/languages = chapter_language_map()
	var/language_name = languages[node_id]
	return language_name ? all_languages[language_name] : null

// What a character writes in: the language they have set as default when they
// command it, otherwise their mother tongue.
/mob/living/human/proc/writing_language()
	var/datum/language/chosen = canonical_language(default_language)
	if (language_learnable(chosen) && language_score(chosen) >= LANGUAGE_CONVERSATIONAL)
		return chosen
	var/datum/language/own = mother_tongue()
	return language_learnable(own) ? own : null

// Who is writing when the caller did not say: whoever holds the book, else
// the person acting on it from beside it.
/obj/item/weapon/book/proc/infer_chapter_writer()
	if (ishuman(loc))
		return loc
	if (ishuman(usr) && get_dist(usr, src) <= 1)
		return usr
	return null

// Record the language of a chapter that has just come into being. An explicit
// language (text, "" for plain) wins; otherwise it is the writer's.
/obj/item/weapon/book/proc/record_chapter_language(node_id, mob/living/human/writer = null, language = null)
	if (!map || !map.book_research_enabled())
		return
	if (!istext(language))
		if (!istype(writer))
			writer = infer_chapter_writer()
		var/datum/language/L = istype(writer) ? writer.writing_language() : null
		language = L ? L.name : ""
	set_chapter_language(node_id, language)

// A printed book carries the languages of its original.
/obj/item/weapon/book/proc/copy_chapter_languages_from(obj/item/weapon/book/original)
	if (istype(original))
		chapter_languages = original.chapter_languages

/proc/language_reading_problem(mob/living/human/H, datum/language/L, needed)
	if (!L || !map || !map.book_research_enabled() || !istype(H))
		return null
	if (H.language_score(L) >= needed)
		return null
	if (needed >= LANGUAGE_CONVERSATIONAL)
		return "This chapter is written in [L.name]. You need to be conversational in [L.name] to copy it out."
	return "This chapter is written in [L.name], and you can't follow enough [L.name] to study it. Learn the language, or find someone to copy it out in yours."

// Tells a reader why the chapter's language keeps them out. TRUE when it does.
/obj/item/weapon/book/proc/chapter_refuses(mob/living/human/H, node_id, needed = LANGUAGE_BROKEN)
	var/problem = language_reading_problem(H, chapter_language(node_id), needed)
	if (!problem)
		return FALSE
	to_chat(H, SPAN_WARNING(problem))
	return TRUE

// Studying a chapter in a half-known language is slower: twice as long at
// Broken, easing to no penalty at Fluent.
/proc/language_study_factor(mob/living/human/H, datum/language/L)
	if (!L || !istype(H) || !map || !map.book_research_enabled())
		return 1
	var/score = H.language_score(L)
	if (score >= LANGUAGE_FLUENT)
		return 1
	return 1 + (LANGUAGE_FLUENT - max(score, LANGUAGE_BROKEN)) / (LANGUAGE_FLUENT - LANGUAGE_BROKEN)

// One line for the book window: which languages its chapters are in.
/obj/item/weapon/book/proc/chapter_language_note(mob/living/human/H)
	var/list/names = list()
	var/list/languages = chapter_language_map()
	for (var/id in languages)
		if (has_research_chapter(id))
			names |= languages[id]
	if (!names.len)
		return null
	var/list/parts = list()
	for (var/language_name in names)
		var/datum/language/L = all_languages[language_name]
		var/standing = (L && istype(H)) ? language_level_name(H.language_score(L)) : "None"
		parts += "[language_name] (your level: [standing])"
	return "Chapters written in: [jointext(parts, ", ")]."
