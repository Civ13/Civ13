// ============================================================
// Research Tree - starting a book research world (Val 2026-11-10)
// ------------------------------------------------------------
// A fresh Persistence world with book research starts in the Stone Age
// (a restored save keeps its own era). Each new faction's founder gets
// the Stone Age master book, holding every era-0 chapter, and a pencil.
// ============================================================

/obj/map_metadata/proc/start_book_research_world()
	if (!persistence || !book_research_enabled())
		return FALSE
	age = "5000 B.C."
	ordinal_age = 0
	age1_done = FALSE
	age2_done = FALSE
	age3_done = FALSE
	age4_done = FALSE
	age5_done = FALSE
	age6_done = FALSE
	age7_done = FALSE
	age8_done = FALSE
	age9_done = FALSE
	autoresearch = FALSE
	return TRUE

/proc/stone_age_node_ids()
	var/list/ids = list()
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (N.era_tier <= 0 && N.mode != RESEARCH_MODE_BOOK && valid_recipe_node_id(node_id))
			ids += node_id
	return ids

/proc/create_stone_age_master_book(turf/site)
	var/obj/item/weapon/book/B = new(site)
	B.name = "Stone Age master book"
	B.title = "Stone Age master book"
	B.desc = "A book holding every chapter of Stone Age knowledge. Study a chapter to learn it."
	for (var/node_id in stone_age_node_ids())
		B.add_research_chapter(node_id)
	return B

// The founding gift. Returns the book, or null when book research is off.
/mob/living/human/proc/receive_founding_books()
	if (!map || !map.book_research_enabled())
		return null
	var/turf/T = get_turf(src)
	var/obj/item/weapon/book/B = create_stone_age_master_book(T)
	var/obj/item/weapon/pen/pencil/P = new(T)
	put_in_hands(B)
	put_in_hands(P)
	to_chat(src, SPAN_NOTICE("Your faction starts with the <b>Stone Age master book</b> and a pencil. Study its chapters to learn them."))
	return B
