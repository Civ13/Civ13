// ============================================================
// Research Tree - books from memory (Persistence redesign, Val 2026-11-10)
// ------------------------------------------------------------
// A book is an ordinary book first: players write pages in it like a
// journal. With book research on, the same pencil or pen menu can also
// transcribe a research chapter from the writer's memory, one node per
// sitting, using a blank sheet (paper or parchment) and stamina.
//
// Any page can be ripped out: written pages become a written sheet, and a
// research chapter becomes a loose chapter page that can be studied on its
// own. Putting a page back takes time.
// ============================================================

#define BOOK_WRITE_TIME(tier) (1200 + 600 * max(0, tier))
#define BOOK_WRITE_STAMINA(tier) (15 + 5 * max(0, tier))
#define BOOK_RIP_TIME 20
#define BOOK_REINSERT_TIME 300
#define BOOK_WRITE_SKILL_GAIN 0.5

/obj/item/weapon/book
	var/list/written_pages = null // page texts, oldest first; dat mirrors them
	var/tmp/page_busy = FALSE

// Older books keep one block of text; it becomes the first page.
/obj/item/weapon/book/proc/page_list()
	if (!islist(written_pages))
		written_pages = list()
		if (istext(dat) && length(dat))
			written_pages += dat
	return written_pages

/obj/item/weapon/book/proc/rebuild_dat()
	dat = written_pages && written_pages.len ? jointext(written_pages, "<hr>") : null

/obj/item/weapon/book/proc/add_written_page(text)
	if (!istext(text) || !length(text))
		return FALSE
	var/list/pages = page_list()
	pages += text
	rebuild_dat()
	return TRUE

// ------------------------------------------------------------
// Writing materials
// ------------------------------------------------------------

// Parchment: a dried hide cut into sheets. It works like paper everywhere.
/obj/item/weapon/paper/parchment
	name = "parchment"
	desc = "A sheet of scraped and dried hide. It can be written on like paper."
	color = "#E8D8B0"

/obj/item/stack/material/dryhide/proc/cut_parchment(mob/living/user, obj/item/tool)
	if (!user || !tool || !tool.sharp || amount < 1 || !user.Adjacent(src))
		return FALSE
	to_chat(user, SPAN_NOTICE("You begin cutting the dried hide into parchment."))
	if (!do_after(user, 50, src) || QDELETED(src) || !use(1))
		return FALSE
	var/turf/site = get_turf(user)
	for (var/i = 1, i <= 4, i++)
		new /obj/item/weapon/paper/parchment(site)
	to_chat(user, SPAN_NOTICE("You cut four sheets of parchment."))
	return TRUE

/obj/item/stack/material/dryhide/attackby(obj/W, mob/user)
	var/obj/item/I = W
	if (istype(I) && I.sharp && !W.reagents)
		cut_parchment(user, I)
		return TRUE
	return ..()

/proc/blank_writing_sheet(obj/item/weapon/paper/P)
	return istype(P) && (P.type == /obj/item/weapon/paper || P.type == /obj/item/weapon/paper/parchment) && isnull(P.document_record) && !P.gcDestroyed && P.loc && !length(P.info) && !length(P.stamps) && !length(P.stamped) && !length(P.contents)

// Writing supplies that let research start at all: anyone may make them in
// book research, from 5000 B.C. (the pen stays a Papermaking upgrade).
var/global/list/book_research_writing_supplies = list(
	"/obj/item/weapon/pen/pencil",
	"/obj/item/weapon/paper",
	"/obj/item/weapon/book")

/proc/is_book_research_writing_supply(result_path_string)
	return map && map.book_research_enabled() && istext(result_path_string) && (result_path_string in book_research_writing_supplies)

// ------------------------------------------------------------
// Transcribing a chapter from memory
// ------------------------------------------------------------

/obj/item/weapon/book/proc/write_research_chapter(mob/living/human/H, obj/item/weapon/pen/P)
	if (!istype(H) || !map || !map.book_research_enabled() || !can_hold_research())
		return FALSE
	if (page_busy)
		to_chat(H, SPAN_WARNING("Someone is already working on [src]."))
		return FALSE
	var/list/choices = list()
	for (var/node_id in clean_recipe_node_ids(H.known_recipe_nodes))
		if (!has_research_chapter(node_id))
			choices[get_research_node(node_id).name] = node_id
	if (!choices.len)
		to_chat(H, SPAN_WARNING("There's nothing you know that isn't already in [src]."))
		return FALSE
	var/pick = player_input(H, "Which piece of your knowledge will you write down?", "Write a chapter", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices))
		return FALSE
	var/node_id = choices[pick]
	var/datum/research_node/N = get_research_node(node_id)
	var/obj/item/weapon/paper/sheet = locate() in list(H.l_hand, H.r_hand)
	if (!blank_writing_sheet(sheet))
		to_chat(H, SPAN_WARNING("Hold a blank sheet of paper or parchment to write on."))
		return FALSE
	var/cost = BOOK_WRITE_STAMINA(N.era_tier)
	if (H.stats["stamina"][1] < cost)
		to_chat(H, SPAN_WARNING("You are too tired to write a chapter now."))
		return FALSE
	var/time = BOOK_WRITE_TIME(N.era_tier)
	to_chat(H, SPAN_NOTICE("You begin writing the chapter on [N.name] into [src]. This takes about [round(time / 600, 0.5)] minute\s."))
	page_busy = TRUE
	var/done = do_after(H, time, src)
	page_busy = FALSE
	if (!done || QDELETED(src) || has_research_chapter(node_id) || !H.knows_recipe_node(node_id) || !recipe_held(H, P) || !recipe_held(H, sheet) || !blank_writing_sheet(sheet))
		return FALSE
	if (!commit_written_chapter(H, node_id, sheet))
		to_chat(H, SPAN_WARNING("You are too tired to finish the chapter."))
		return FALSE
	playsound(src, 'sound/effects/pen.ogg', 40, 1)
	to_chat(H, SPAN_NOTICE("You finish the chapter on <b>[N.name]</b>."))
	return TRUE

// Pays for and records a chapter written from H's memory onto sheet.
/obj/item/weapon/book/proc/commit_written_chapter(mob/living/human/H, node_id, obj/item/weapon/paper/sheet)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !H.knows_recipe_node(node_id) || has_research_chapter(node_id) || !blank_writing_sheet(sheet))
		return FALSE
	var/cost = BOOK_WRITE_STAMINA(N.era_tier)
	if (H.stats["stamina"][1] < cost)
		return FALSE
	H.stats["stamina"][1] -= cost
	if (sheet.loc == H)
		H.remove_from_mob(sheet)
	qdel(sheet)
	add_research_chapter(node_id)
	H.gain_scholarship(node_id, BOOK_WRITE_SKILL_GAIN)
	return TRUE

// ------------------------------------------------------------
// Loose chapter pages
// ------------------------------------------------------------

/obj/item/weapon/paper/research_page
	name = "torn chapter"
	var/node_id = null

/obj/item/weapon/paper/research_page/proc/refresh_page()
	var/datum/research_node/N = valid_recipe_node_id(node_id) ? get_research_node(node_id) : null
	name = N ? "torn chapter: [N.name]" : "torn chapter"
	desc = N ? "A chapter on [N.name], torn out of a book. It can be studied, or put back into a book." : "An unreadable torn chapter."
	info = N ? "<b>[N.name]</b><br>A chapter of research notes." : ""

/obj/item/weapon/paper/research_page/after_load()
	. = ..()
	if (!valid_recipe_node_id(node_id))
		node_id = null
	refresh_page()

/obj/item/weapon/paper/research_page/attack_self(mob/living/user)
	var/mob/living/human/H = user
	if (istype(H) && user.a_intent != I_HARM && map && map.book_research_enabled() && valid_recipe_node_id(node_id))
		study_research_source(H, src, node_id)
		return
	return ..()

/obj/item/proc/holds_research_chapter(node_id)
	return FALSE

/obj/item/weapon/book/holds_research_chapter(node_id)
	return has_research_chapter(node_id)

/obj/item/weapon/paper/research_page/holds_research_chapter(id)
	return node_id && node_id == id

// ------------------------------------------------------------
// Ripping pages out and putting them back
// ------------------------------------------------------------

/obj/item/weapon/book/verb/rip_out_page()
	set name = "Rip out a page"
	set category = null
	set src in usr
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || !can_hold_research() || page_busy)
		return
	var/list/choices = list()
	var/list/pages = page_list()
	for (var/i = 1, i <= pages.len, i++)
		choices["Page [i]: [copytext(strip_html_properly(pages[i]), 1, 30)]"] = i
	for (var/node_id in research_chapter_list())
		choices["Chapter: [get_research_node(node_id).name]"] = node_id
	if (!choices.len)
		to_chat(H, SPAN_WARNING("[src] has nothing written in it."))
		return
	var/pick = player_input(H, "Which page will you rip out?", "Rip out a page", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices))
		return
	rip_page(H, choices[pick])

/obj/item/weapon/book/proc/rip_page(mob/living/human/H, which)
	page_busy = TRUE
	var/done = do_after(H, BOOK_RIP_TIME, src)
	page_busy = FALSE
	if (!done || QDELETED(src) || H.incapacitated())
		return FALSE
	var/obj/item/weapon/paper/P = tear_out_page(which, get_turf(H))
	if (!P)
		return FALSE
	H.put_in_hands(P)
	playsound(src, 'sound/items/poster_ripped.ogg', 40, 1)
	H.visible_message(SPAN_NOTICE("[H] rips a page out of [src]."))
	return TRUE

// Removes a page (index) or chapter (node id) and returns the loose sheet.
/obj/item/weapon/book/proc/tear_out_page(which, turf/site)
	if (istext(which))
		if (!has_research_chapter(which))
			return null
		var/list/chapters = research_chapter_list()
		chapters -= which
		research_chapters = jointext(chapters, ";")
		var/obj/item/weapon/paper/research_page/R = new(site)
		R.node_id = which
		R.refresh_page()
		return R
	var/list/pages = page_list()
	if (!isnum(which) || which < 1 || which > pages.len)
		return null
	var/obj/item/weapon/paper/P = new(site)
	P.name = "torn page"
	P.info = pages[which]
	pages.Cut(which, which + 1)
	rebuild_dat()
	P.update_icon()
	return P

// Only a plain written sheet (or a torn chapter) can be bound: its text is all
// it has. Documents, stamped or formatted sheets keep their own record and stay
// loose, since binding would delete the original.
/proc/bindable_loose_page(obj/item/weapon/paper/P)
	if (istype(P, /obj/item/weapon/paper/research_page))
		return TRUE
	return istype(P) && (P.type == /obj/item/weapon/paper || P.type == /obj/item/weapon/paper/parchment) && isnull(P.document_record) && !P.rigged && !P.fields && !length(P.stamps) && !length(P.stamped) && !length(P.ico) && !length(P.contents)

// Adds a loose sheet back as a page or chapter. The caller deletes the sheet.
/obj/item/weapon/book/proc/bind_loose_page(obj/item/weapon/paper/P)
	var/obj/item/weapon/paper/research_page/R = istype(P, /obj/item/weapon/paper/research_page) ? P : null
	if (R)
		return valid_recipe_node_id(R.node_id) && add_research_chapter(R.node_id)
	return add_written_page(P.info)

/obj/item/weapon/book/proc/reinsert_page(mob/living/human/H, obj/item/weapon/paper/P)
	if (!can_hold_research() || page_busy)
		return FALSE
	var/obj/item/weapon/paper/research_page/R = istype(P, /obj/item/weapon/paper/research_page) ? P : null
	if (R && (!valid_recipe_node_id(R.node_id) || has_research_chapter(R.node_id)))
		to_chat(H, SPAN_WARNING("That chapter can't go back into [src]."))
		return FALSE
	if (!R && !length(P.info))
		to_chat(H, SPAN_WARNING("There is nothing written on [P]."))
		return FALSE
	if (!bindable_loose_page(P))
		to_chat(H, SPAN_WARNING("[P] is a document with marks of its own; binding it would lose them."))
		return FALSE
	to_chat(H, SPAN_NOTICE("You begin binding [P] into [src]."))
	page_busy = TRUE
	var/done = do_after(H, BOOK_REINSERT_TIME, src)
	page_busy = FALSE
	if (!done || QDELETED(src) || QDELETED(P) || !recipe_held(H, P) || !bindable_loose_page(P))
		return FALSE
	if (!bind_loose_page(P))
		return FALSE
	H.remove_from_mob(P)
	qdel(P)
	to_chat(H, SPAN_NOTICE("You bind the page into [src]."))
	return TRUE
