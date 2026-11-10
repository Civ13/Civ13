// ============================================================
// Research Tree - book research (Persistence redesign, Val 2026-11-10)
// ------------------------------------------------------------
// When a map turns on book_research (on top of recipe_books), research
// benches belong to nobody and store nothing. A book placed on the bench
// holds the work: progress and finished chapters are written into the
// book, so research travels with it. Finishing a node teaches no one;
// anyone (researchers included) learns it by studying the chapter.
//
// The book keeps its data in two strings so the map object saver keeps
// them like any other text var:
//   research_chapters = "node_a;node_b"            finished chapters
//   research_progress = "node_c=40=0;node_d=12=1"  node=ticks=prototype
// ============================================================

/obj/map_metadata/var/book_research = FALSE

/obj/map_metadata/proc/book_research_enabled()
	return recipe_knowledge_enabled() && book_research

#define BOOK_RESEARCH_REACH 1
#define BOOK_STUDY_TIME(tier) (600 + 300 * max(0, tier))

/obj/item/weapon/book
	var/research_chapters = ""
	var/research_progress = ""

// Ordinary writable books carry research; sealed books (holy books, legacy
// skill scrolls, trade goods) do not.
/obj/item/weapon/book/proc/can_hold_research()
	return !unique

/obj/item/weapon/book/proc/research_chapter_list()
	var/list/result = list()
	if (istext(research_chapters) && length(research_chapters))
		for (var/node_id in splittext(research_chapters, ";"))
			if (valid_recipe_node_id(node_id))
				result |= node_id
	return result

/obj/item/weapon/book/proc/has_research_chapter(node_id)
	return node_id in research_chapter_list()

/obj/item/weapon/book/proc/add_research_chapter(node_id)
	if (!valid_recipe_node_id(node_id))
		return FALSE
	var/list/chapters = research_chapter_list()
	if (node_id in chapters)
		return FALSE
	chapters += node_id
	research_chapters = jointext(chapters, ";")
	clear_research_progress(node_id)
	return TRUE

// node_id => list(ticks, prototype_installed)
/obj/item/weapon/book/proc/research_progress_map()
	var/list/result = list()
	if (!istext(research_progress) || !length(research_progress))
		return result
	for (var/entry in splittext(research_progress, ";"))
		var/list/parts = splittext(entry, "=")
		if (parts.len < 2 || !valid_recipe_node_id(parts[1]))
			continue
		var/ticks = text2num(parts[2])
		var/proto = parts.len >= 3 ? text2num(parts[3]) : 0
		result[parts[1]] = list(max(0, isnum(ticks) ? ticks : 0), proto ? 1 : 0)
	return result

/obj/item/weapon/book/proc/set_research_progress_map(list/progress)
	var/list/parts = list()
	for (var/node_id in progress)
		var/list/entry = progress[node_id]
		parts += "[node_id]=[entry[1]]=[entry[2]]"
	research_progress = jointext(parts, ";")

/obj/item/weapon/book/proc/research_ticks(node_id)
	var/list/entry = research_progress_map()[node_id]
	return entry ? entry[1] : 0

/obj/item/weapon/book/proc/research_prototype_installed(node_id)
	var/list/entry = research_progress_map()[node_id]
	return entry ? entry[2] : 0

/obj/item/weapon/book/proc/clear_research_progress(node_id)
	var/list/progress = research_progress_map()
	if (!(node_id in progress))
		return
	progress -= node_id
	set_research_progress_map(progress)

// Adds ticks (and optionally marks the prototype installed). Finishes the
// chapter when both the study and, for prototype nodes, the prototype are in.
// Returns TRUE when the chapter was finished by this call.
/obj/item/weapon/book/proc/add_research_work(node_id, amount, prototype = FALSE)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || has_research_chapter(node_id))
		return FALSE
	var/list/progress = research_progress_map()
	var/list/entry = progress[node_id]
	if (!entry)
		entry = list(0, 0)
	entry[1] = min(N.cost_ticks, entry[1] + max(0, amount))
	if (prototype)
		entry[2] = 1
	progress[node_id] = entry
	set_research_progress_map(progress)
	if (entry[1] < N.cost_ticks)
		return FALSE
	if (N.mode == RESEARCH_MODE_PROTOTYPE && !entry[2])
		return FALSE
	add_research_chapter(node_id)
	map?.book_research_node_finished(N)
	return TRUE

// The world era still moves on a capstone, the first time anyone finishes one.
// No one learns the node here: it has to be studied from the book.
/obj/map_metadata/proc/book_research_node_finished(datum/research_node/N)
	if (!N || N.mode != RESEARCH_MODE_PROTOTYPE || N.era_tier <= ordinal_age)
		return
	ordinal_age = N.era_tier
	var/new_year = ordinal_age_year(N.era_tier)
	if (new_year)
		age = new_year
	to_chat(world, "<big><font color='#c98a1d'>The discovery of <b>[N.name]</b> sends the world into the <b>[ordinal_age_name(N.era_tier)]</b>!</font></big>")

// ------------------------------------------------------------
// Personal knowledge rules in book mode
// ------------------------------------------------------------

// Whether H may use something gated on node_id. With book research on it is
// the character's own knowledge; otherwise the faction or era research as
// before (faction is used when there is no character).
/proc/research_node_known(mob/H, node_id, faction = null)
	if (!map)
		return FALSE
	var/mob/living/human/HU = ishuman(H) ? H : null
	if (map.book_research_enabled())
		return HU && HU.knows_recipe_node(node_id)
	return map.is_node_done(HU ? HU.civilization : faction, node_id)

/mob/living/human/proc/knows_research_prereqs(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return FALSE
	for (var/req in N.prereqs)
		if (!knows_recipe_node(req))
			return FALSE
	return TRUE

// Someone at the bench who can push this node forward right now.
// A connected player, or an agent-controlled character (hired help later).
/mob/living/human/proc/research_presence()
	return client || agent_character_for(src)

/mob/living/human/proc/can_research_node_at(obj/structure/research_bench/B, node_id)
	if (stat != CONSCIOUS || incapacitated() || !research_presence())
		return FALSE
	if (get_dist(src, B) > BOOK_RESEARCH_REACH || !isturf(loc) || loc.z != B.z)
		return FALSE
	return knows_research_prereqs(node_id) && meets_scholar_requirement(node_id)

// ------------------------------------------------------------
// Bench behaviour in book mode
// ------------------------------------------------------------

/obj/structure/research_bench/proc/book_mode()
	return map && map.book_research_enabled()

// Up to two books sit on a bench (Val, 2026-11-10). The first one is where
// research is written; Swap books changes which.
#define BENCH_MAX_BOOKS 2

/obj/structure/research_bench/proc/placed_books()
	var/list/books = list()
	for (var/obj/item/weapon/book/B in contents)
		books += B
	return books

/obj/structure/research_bench/proc/placed_book()
	return locate(/obj/item/weapon/book) in contents

/obj/structure/research_bench/proc/book_analysis_tick()
	var/obj/item/weapon/book/B = placed_book()
	if (!B || !assigned_node)
		return
	var/datum/research_node/N = get_research_node(assigned_node)
	if (!N || N.mode == RESEARCH_MODE_BOOK || tier < N.min_bench_tier || B.has_research_chapter(assigned_node))
		return
	// The most skilled scholar at the bench sets the pace.
	var/mob/living/human/researcher = null
	var/best_rate = 0
	for (var/mob/living/human/H in range(BOOK_RESEARCH_REACH, src))
		if (!H.can_research_node_at(src, assigned_node))
			continue
		var/rate = H.scholar_research_rate(assigned_node)
		if (rate > best_rate)
			researcher = H
			best_rate = rate
	if (!researcher)
		return
	researcher.gain_scholarship(assigned_node, SCHOLAR_RESEARCH_GAIN)
	if (B.add_research_work(assigned_node, round(base_tick_rate * best_rate, 0.1)))
		for (var/mob/living/human/H in viewers(world.view, src))
			to_chat(H, SPAN_NOTICE("The chapter on <b>[N.name]</b> in [B] is finished. It can now be studied."))
	book_refresh_ui()

// Whether this bench can work on node_id for its book. Prerequisites are
// checked against whoever is at the bench each tick, not here, so anyone can
// line up a subject for a scholar who knows the groundwork.
/obj/structure/research_bench/proc/book_can_assign_node(node_id)
	var/obj/item/weapon/book/B = placed_book()
	var/datum/research_node/N = get_research_node(node_id)
	return B && N && N.min_bench_tier <= tier && N.mode != RESEARCH_MODE_BOOK && !B.has_research_chapter(node_id)

/obj/structure/research_bench/proc/book_try_assign_node(mob/living/human/H, node_id)
	if (!placed_book())
		to_chat(H, SPAN_WARNING("Place a book on the bench first. Research is written into it."))
		return
	if (!book_can_assign_node(node_id))
		to_chat(H, SPAN_WARNING("This bench can't research that into this book."))
		return
	assigned_node = node_id
	studied_samples = null
	var/datum/research_node/N = get_research_node(node_id)
	to_chat(H, SPAN_NOTICE("The bench is now set to research <b>[N.name]</b>."))

/obj/structure/research_bench/proc/book_place(obj/item/weapon/book/B, mob/living/human/user)
	if (!B.can_hold_research())
		to_chat(user, SPAN_WARNING("Research can't be written into [B]."))
		return
	var/list/books = placed_books()
	if (books.len >= BENCH_MAX_BOOKS)
		to_chat(user, SPAN_WARNING("There's no room for another book on the bench."))
		return
	user.remove_from_mob(B)
	B.forceMove(src)
	if (!books.len)
		studied_samples = null // samples counted toward the previous research book
		if (assigned_node && B.has_research_chapter(assigned_node))
			assigned_node = null
	if (books.len)
		to_chat(user, SPAN_NOTICE("You place [B] beside [books[1]]. Chapters can be copied between the two."))
	else
		to_chat(user, SPAN_NOTICE("You place [B] on the bench. Research done here will be written into it."))
	book_refresh_ui()

// The research book becomes the other one.
/obj/structure/research_bench/proc/book_swap(mob/living/human/user)
	var/list/books = placed_books()
	if (books.len < 2 || !in_range(src, user) || user.incapacitated())
		return
	var/obj/item/weapon/book/first = books[1]
	first.loc = null
	first.forceMove(src)
	studied_samples = null // samples counted toward the other book
	if (assigned_node && placed_book()?.has_research_chapter(assigned_node))
		assigned_node = null
	to_chat(user, SPAN_NOTICE("Research here will now be written into [placed_book()]."))
	book_refresh_ui()

/obj/structure/research_bench/proc/book_take(mob/living/human/user, index = 0)
	var/list/books = placed_books()
	if (!books.len || !in_range(src, user) || user.incapacitated())
		return
	if (!isnum(index) || index < 1 || index > books.len)
		index = books.len
	var/obj/item/weapon/book/B = books[index]
	if (index == 1)
		studied_samples = null // the research book leaves with its samples' credit
	B.forceMove(get_turf(src))
	user.put_in_hands(B)
	to_chat(user, SPAN_NOTICE("You take [B] from the bench. Its research goes with it."))
	book_refresh_ui()

/obj/structure/research_bench/proc/book_attackby(obj/item/W, mob/living/human/user)
	if (user.a_intent == I_HARM && (istype(W, /obj/item/weapon/wrench) || istype(W, /obj/item/weapon/hammer)))
		maintain_bench(W, user)
		return
	if (istype(W, /obj/item/weapon/book) && !istype(W, /obj/item/weapon/book/research/tree_book))
		book_place(W, user)
		return
	if (is_upgrade_coin(W))
		try_feed_coins(W, user)
		return
	var/obj/item/weapon/book/B = placed_book()
	if (!B || !assigned_node)
		to_chat(user, SPAN_WARNING("Place a book on the bench and choose a subject first."))
		return
	var/datum/research_node/N = get_research_node(assigned_node)
	if (!N || B.has_research_chapter(assigned_node))
		return
	if (!user.knows_research_prereqs(assigned_node))
		to_chat(user, SPAN_WARNING("You don't know enough to work on <b>[N.name]</b> yet."))
		return
	if (!user.meets_scholar_requirement(assigned_node))
		to_chat(user, SPAN_WARNING("You aren't skilled enough to work on <b>[N.name]</b>. [user.scholar_requirement_text(assigned_node)]."))
		return
	if (N.mode == RESEARCH_MODE_PROTOTYPE && N.prototype_type && istype(W, N.prototype_type))
		if (tier < N.min_bench_tier)
			to_chat(user, SPAN_WARNING("This bench isn't upgraded enough to complete this prototype."))
			return
		if (B.research_prototype_installed(assigned_node))
			to_chat(user, SPAN_WARNING("A working prototype has already been recorded for <b>[N.name]</b>."))
			return
		qdel(W)
		if (B.add_research_work(assigned_node, 0, TRUE))
			to_chat(user, SPAN_NOTICE("Your prototype works. The chapter on <b>[N.name]</b> is finished."))
		else
			to_chat(user, SPAN_NOTICE("You record the working prototype for <b>[N.name]</b>. The chapter is finished once the study is done."))
		book_refresh_ui()
		return
	for (var/stype in get_node_recipe_paths(assigned_node))
		if (!istype(W, stype))
			continue
		if (!studied_samples)
			studied_samples = list()
		if (W.type in studied_samples)
			to_chat(user, SPAN_WARNING("You have already learned all you can from studying \a [W]."))
			return
		studied_samples += W.type
		var/boost = max(1, round(N.cost_ticks * RESEARCH_SAMPLE_BOOST_FRACTION))
		var/done = B.add_research_work(assigned_node, boost)
		to_chat(user, SPAN_NOTICE("You dismantle and study \the [W], advancing <b>[N.name]</b> by [boost] points[done ? " and finishing the chapter" : ""]."))
		qdel(W)
		book_refresh_ui()
		return
	to_chat(user, SPAN_WARNING("That doesn't help with <b>[N.name]</b>."))

// Viewer-relative node status for the bench UI: what the viewer knows, plus
// what the book on the bench holds.
/obj/structure/research_bench/proc/book_node_status(mob/living/human/H, node_id)
	if (H.knows_recipe_node(node_id))
		return RNODE_DONE
	var/obj/item/weapon/book/B = placed_book()
	if (B && B.research_ticks(node_id) > 0 && !B.has_research_chapter(node_id))
		return RNODE_IN_PROGRESS
	if (!H.knows_research_prereqs(node_id))
		return RNODE_LOCKED
	return RNODE_AVAILABLE

// ------------------------------------------------------------
// Studying a chapter from any book
// ------------------------------------------------------------

/obj/item/weapon/book/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !map || !map.book_research_enabled() || !can_hold_research())
		return ..()
	var/list/chapters = research_chapter_list()
	if (!chapters.len)
		return ..()
	var/list/choices = list()
	if (dat)
		choices["Read the book"] = "read"
	for (var/node_id in chapters)
		var/datum/research_node/N = get_research_node(node_id)
		choices["Study: [N.name]"] = node_id
	var/pick = player_input(H, "What will you do with [src]?", "Book", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices))
		return
	if (choices[pick] == "read")
		return ..()
	study_research_source(H, src, choices[pick])

// Study a chapter from a book or a loose torn-out chapter page.
/proc/study_research_source(mob/living/human/H, obj/item/source, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !source || !source.holds_research_chapter(node_id))
		return FALSE
	if (H.knows_recipe_node(node_id))
		to_chat(H, SPAN_NOTICE("You already know <b>[N.name]</b>."))
		return FALSE
	if (!H.knows_research_prereqs(node_id))
		to_chat(H, SPAN_WARNING("You need to understand this chapter's groundwork first."))
		return FALSE
	var/time = BOOK_STUDY_TIME(N.era_tier)
	to_chat(H, SPAN_NOTICE("You begin studying the chapter on [N.name]. This takes about [round(time / 600, 0.5)] minute\s."))
	var/atom/anchor = isturf(source.loc) || source.loc == H ? source : source.loc
	var/atom/start_loc = source.loc
	// A book on a bench must still be there: taking it away ends the study.
	if (!do_after(H, time, anchor) || QDELETED(source) || (source.loc != start_loc && source.loc != H) || !source.holds_research_chapter(node_id) || !H.Adjacent(anchor) || H.incapacitated())
		return FALSE
	if (H.learn_recipe_node(node_id))
		H.gain_scholarship(node_id, SCHOLAR_STUDY_GAIN)
		to_chat(H, SPAN_NOTICE("You have learned <b>[N.name]</b>. [source] can be used again."))
		return TRUE
	return FALSE

/obj/item/weapon/book/examine(mob/user)
	..()
	if (!map || !map.book_research_enabled())
		return
	var/list/chapters = research_chapter_list()
	if (chapters.len)
		var/list/names = list()
		for (var/node_id in chapters)
			names += get_research_node(node_id).name
		to_chat(user, "It holds research chapters on: [jointext(names, ", ")].")
	var/list/progress = research_progress_map()
	for (var/node_id in progress)
		var/datum/research_node/N = get_research_node(node_id)
		var/list/entry = progress[node_id]
		to_chat(user, "An unfinished chapter on [N.name] ([round(entry[1] / N.cost_ticks * 100)]%).")

/obj/structure/research_bench/proc/book_ui_data(mob/living/human/H, list/data)
	var/obj/item/weapon/book/B = placed_book()
	var/list/books = placed_books()
	var/list/book_rows = list()
	for (var/i = 1, i <= books.len, i++)
		var/obj/item/weapon/book/row_book = books[i]
		var/list/names = list()
		for (var/node_id in row_book.research_chapter_list())
			names += get_research_node(node_id).name
		book_rows += list(list("name" = "[row_book]", "idx" = i, "is_target" = i == 1, "chapters" = names))
	data["books"] = book_rows
	data["book_room"] = books.len < BENCH_MAX_BOOKS
	data["can_swap"] = books.len >= 2
	data["can_copy"] = books.len >= 2
	data["can_study"] = books.len >= 1
	var/datum/research_node/AN = assigned_node ? get_research_node(assigned_node) : null
	if (!AN)
		return
	data["assigned_name"] = AN.name
	if (B && B.has_research_chapter(assigned_node))
		data["assigned_done"] = TRUE
		return
	var/ticks = B ? B.research_ticks(assigned_node) : 0
	var/text = "Written into the book: [round((ticks / AN.cost_ticks) * 100)]% ([ticks]/[AN.cost_ticks]). Work only goes on while someone who knows the groundwork stands at the bench."
	if (AN.mode == RESEARCH_MODE_PROTOTYPE)
		var/pname = AN.prototype_display_name()
		text += " It also needs a working [pname ? pname : "prototype"] fed to the bench[B && B.research_prototype_installed(assigned_node) ? " (recorded)" : ""]."
	if (!H.knows_research_prereqs(assigned_node))
		text += " You don't know its groundwork yet."
	if (!H.meets_scholar_requirement(assigned_node))
		text += " [H.scholar_requirement_text(assigned_node)]; you aren't skilled enough yet."
	data["assigned_status_text"] = text

/obj/structure/research_bench/proc/book_examine(mob/user)
	to_chat(user, "Anyone can use this bench. Place a book on it and choose a subject; research done here is written into that book. Use Harm intent with a wrench to fasten or unfasten it, or with a hammer to dismantle it.")
	to_chat(user, "It is tier [tier][tier < era_max_tier() ? " (upgrade progress: [tier_progress]/[BENCH_TIER_UPGRADE_COST(tier)])" : ""].")
	var/obj/item/weapon/book/B = placed_book()
	if (!B)
		to_chat(user, "There is no book on it.")
		return
	to_chat(user, "[B] lies open on it.")
	var/datum/research_node/N = assigned_node ? get_research_node(assigned_node) : null
	if (N && !B.has_research_chapter(assigned_node))
		to_chat(user, "It is set to research <b>[N.name]</b> ([round(B.research_ticks(assigned_node) / N.cost_ticks * 100)]%).")

/obj/structure/research_bench/AltClick(mob/user)
	if (book_mode() && ishuman(user) && placed_book() && in_range(src, user))
		book_take(user)
		return
	return ..()

/obj/structure/research_bench/proc/book_refresh_ui()
	if (GLOB.nanomanager)
		GLOB.nanomanager.update_uis(src)

// ------------------------------------------------------------
// Two books on a bench: copying and studying shelved chapters
// ------------------------------------------------------------

// Copy a chapter from one book on the bench into the other. The scribe
// needs no knowledge of it, only a blank sheet and stamina.
/obj/structure/research_bench/proc/book_copy_chapter(mob/living/human/H)
	var/list/books = placed_books()
	if (books.len < 2)
		to_chat(H, SPAN_WARNING("Place two books on the bench to copy between them."))
		return FALSE
	var/obj/item/weapon/book/A = books[1]
	var/obj/item/weapon/book/B = books[2]
	var/list/choices = list()
	for (var/node_id in A.research_chapter_list())
		if (!B.has_research_chapter(node_id))
			choices["[get_research_node(node_id).name]: [A] to [B]"] = list(A, B, node_id)
	for (var/node_id in B.research_chapter_list())
		if (!A.has_research_chapter(node_id))
			choices["[get_research_node(node_id).name]: [B] to [A]"] = list(B, A, node_id)
	if (!choices.len)
		to_chat(H, SPAN_WARNING("Neither book has a chapter the other lacks."))
		return FALSE
	var/pick = player_input(H, "Which chapter will you copy?", "Copy a chapter", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices))
		return FALSE
	var/list/job = choices[pick]
	var/obj/item/weapon/book/source = job[1]
	var/obj/item/weapon/book/dest = job[2]
	var/node_id = job[3]
	var/datum/research_node/N = get_research_node(node_id)
	var/obj/item/weapon/paper/sheet = locate() in list(H.l_hand, H.r_hand)
	if (!blank_writing_sheet(sheet))
		to_chat(H, SPAN_WARNING("Hold a blank sheet of paper or parchment to copy onto."))
		return FALSE
	if (H.stats["stamina"][1] < BOOK_WRITE_STAMINA(N.era_tier))
		to_chat(H, SPAN_WARNING("You are too tired to copy a chapter now."))
		return FALSE
	if (dest.page_busy)
		to_chat(H, SPAN_WARNING("Someone is already working on [dest]."))
		return FALSE
	var/time = BOOK_WRITE_TIME(N.era_tier)
	to_chat(H, SPAN_NOTICE("You begin copying the chapter on [N.name] into [dest]. This takes about [round(time / 600, 0.5)] minute\s."))
	dest.page_busy = TRUE
	var/done = do_after(H, time, src)
	dest.page_busy = FALSE
	if (!done || QDELETED(src) || source.loc != src || dest.loc != src || !recipe_held(H, sheet))
		return FALSE
	if (!copy_chapter_commit(H, source, dest, node_id, sheet))
		to_chat(H, SPAN_WARNING("You couldn't finish the copy."))
		return FALSE
	to_chat(H, SPAN_NOTICE("You finish copying the chapter on <b>[N.name]</b> into [dest]."))
	book_refresh_ui()
	return TRUE

/obj/structure/research_bench/proc/copy_chapter_commit(mob/living/human/H, obj/item/weapon/book/source, obj/item/weapon/book/dest, node_id, obj/item/weapon/paper/sheet)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !source.has_research_chapter(node_id) || dest.has_research_chapter(node_id) || !blank_writing_sheet(sheet))
		return FALSE
	var/cost = BOOK_WRITE_STAMINA(N.era_tier)
	if (H.stats["stamina"][1] < cost)
		return FALSE
	H.stats["stamina"][1] -= cost
	if (sheet.loc == H)
		H.remove_from_mob(sheet)
	qdel(sheet)
	return dest.add_research_chapter(node_id)

// Study any chapter from the books on the bench without picking them up.
/obj/structure/research_bench/proc/book_study_shelf(mob/living/human/H)
	var/list/choices = list()
	for (var/obj/item/weapon/book/B in placed_books())
		for (var/node_id in B.research_chapter_list())
			var/label = get_research_node(node_id).name
			if (!(label in choices))
				choices[label] = list(B, node_id)
	if (!choices.len)
		to_chat(H, SPAN_WARNING("The books on the bench hold no chapters."))
		return FALSE
	var/pick = player_input(H, "Which chapter will you study?", "Study", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices))
		return FALSE
	var/list/job = choices[pick]
	return study_research_source(H, job[1], job[2])
