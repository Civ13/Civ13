// ============================================================
// Research Tree - comparing notes (Val, 2026-11-14)
// ------------------------------------------------------------
// On book-research worlds, two books on one bench that each hold part of the
// same unfinished chapter can be compared by two scholars working together:
// the fuller chapter gains half of the other's points. Two groups who each
// got a subject part-way finish it by meeting instead of each waiting out
// the rest alone. A book gives or takes a comparison once per subject.
// ============================================================

// Share of the lesser chapter's points the fuller one gains.
#define COMPARE_NOTES_SHARE 0.5

/obj/item/weapon/book
	var/research_compared = "" // "node_a;node_b": subjects this book has already been compared on

/obj/item/weapon/book/proc/compared_list()
	var/list/result = list()
	if (istext(research_compared) && length(research_compared))
		for (var/node_id in splittext(research_compared, ";"))
			if (valid_recipe_node_id(node_id))
				result |= node_id
	return result

/obj/item/weapon/book/proc/has_compared(node_id)
	return node_id in compared_list()

/obj/item/weapon/book/proc/mark_compared(node_id)
	var/list/done = compared_list()
	done |= node_id
	research_compared = jointext(done, ";")

// Subjects the two books on this bench could be compared on: both hold part
// of the chapter, neither holds it whole, neither has been compared on it.
/obj/structure/research_bench/proc/comparable_subjects()
	var/list/result = list()
	var/list/books = placed_books()
	if (!book_mode() || books.len < 2)
		return result
	var/obj/item/weapon/book/A = books[1]
	var/obj/item/weapon/book/B = books[2]
	for (var/node_id in A.research_progress_map())
		if (!get_research_node(node_id) || A.research_ticks(node_id) <= 0 || B.research_ticks(node_id) <= 0)
			continue
		if (A.has_research_chapter(node_id) || B.has_research_chapter(node_id) || A.has_compared(node_id) || B.has_compared(node_id))
			continue
		result += node_id
	return result

// Why H can't compare notes on node_id here now, or null. Needs H and a
// second scholar at the bench who could both research the subject.
/obj/structure/research_bench/proc/compare_notes_problem(mob/living/human/H, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !(node_id in comparable_subjects()))
		return "These two books can't be compared on that."
	for (var/obj/item/weapon/book/B in placed_books())
		if (B.cipher_refuses(H))
			return "You can't read [B]."
	if (!research_lit())
		return "It's too dark to read here."
	if (!H.can_research_node_at(src, node_id))
		return "You need to be able to research [N.name] yourself: [H.scholar_requirement_text(node_id)], its groundwork, and a writing tool in hand."
	if (!second_scholar(node_id, H))
		return "Comparing notes takes two: a second scholar who could research [N.name] must be at the bench with a writing tool in hand."
	return null

// Writes the comparison. No waiting here. Returns the points gained.
/obj/structure/research_bench/proc/compare_notes_commit(mob/living/human/H, node_id)
	if (compare_notes_problem(H, node_id))
		return 0
	var/datum/research_node/N = get_research_node(node_id)
	var/mob/living/human/partner = second_scholar(node_id, H)
	var/list/books = placed_books()
	var/obj/item/weapon/book/fuller = books[1]
	var/obj/item/weapon/book/lesser = books[2]
	if (lesser.research_ticks(node_id) > fuller.research_ticks(node_id))
		fuller = books[2]
		lesser = books[1]
	var/room = N.cost_ticks - fuller.research_ticks(node_id)
	var/points = min(room, max(1, round(lesser.research_ticks(node_id) * COMPARE_NOTES_SHARE)))
	fuller.mark_compared(node_id)
	lesser.mark_compared(node_id)
	var/finished = fuller.add_research_work(node_id, points, FALSE, H)
	// Each pairing of scholars on a subject teaches both, once (learning_by_doing.dm).
	H.gain_active_scholarship(node_id, points, "compared:[node_id]:[partner.scholar_identity()]")
	partner.gain_active_scholarship(node_id, points, "compared:[node_id]:[H.scholar_identity()]")
	H.philosophy_from_comparing(node_id, partner)
	partner.philosophy_from_comparing(node_id, H)
	for (var/mob/living/human/V in viewers(world.view, src))
		to_chat(V, SPAN_NOTICE("[V == H ? "You and [partner]" : "[H] and [partner]"] compare the notes on <b>[N.name]</b> in [fuller] and [lesser]: [fuller] gains [points] points[finished ? " and the chapter is finished. It can now be studied" : ""]."))
	if (finished && assigned_node == node_id && placed_book() == fuller)
		assigned_node = null
	book_refresh_ui()
	return points

/obj/structure/research_bench/proc/compare_notes(mob/living/human/H)
	if (!book_mode())
		to_chat(H, SPAN_WARNING("There are no notes to compare here."))
		return 0
	var/list/subjects = comparable_subjects()
	if (!subjects.len)
		to_chat(H, SPAN_WARNING("Comparing notes needs two books on the bench that each hold part of the same unfinished chapter, and neither may have been compared on it before."))
		return 0
	var/node_id = subjects[1]
	if (subjects.len > 1)
		var/list/names = list()
		for (var/id in subjects)
			names[get_research_node(id).name] = id
		var/choice = player_input(H, "Which subject do you compare notes on?", "Compare Notes", null, "anything", names, TRUE)
		if (!choice || !(choice in names) || !in_range(src, H) || H.incapacitated())
			return 0
		node_id = names[choice]
	var/problem = compare_notes_problem(H, node_id)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return 0
	return compare_notes_commit(H, node_id)

/obj/structure/research_bench/verb/compare_notes_verb()
	set name = "Compare Notes"
	set category = "Object"
	set src in oview(1)
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		compare_notes(H)

#undef COMPARE_NOTES_SHARE
