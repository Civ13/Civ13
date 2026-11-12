// ============================================================
// Research Tree - practice and gathering for early nodes (Val, 2026-11-12)
// ------------------------------------------------------------
// "Players don't want an idle simulator." Field work (field_work.dm) only
// covered era tier 5 and up, so most of a book-research world was spent
// standing at a lit bench while a timer ran. This adds field work for the
// earlier tiers:
// - Practice: making things a node builds on writes a share of that node.
//   Smithing tools you know (Basic Toolmaking) advances Iron Tools, and so on.
//   Every early node with prerequisites gets one practice experiment per
//   prerequisite, generated from the tree, so new nodes are covered too.
// - Gathering: a few first nodes with nothing before them advance by
//   foraging or butchering.
// Credit still happens at a bench, once per book, exactly like late field
// work. Bench study alone still finishes every node.
// ============================================================

// Practice experiments are generated for nodes below this era tier. Late
// nodes keep their hand-picked field work.
#define PRACTICE_BELOW_TIER 5
// How much of a node practice can write in total, split between its
// prerequisites.
#define PRACTICE_TOTAL_SHARE 0.5
#define PRACTICE_MIN_ITEMS 4
#define PRACTICE_MAX_ITEMS 20

var/global/practice_experiments_built = FALSE

// The activity id that counts things made from node_id's recipes.
/proc/practice_activity(node_id)
	return "craft:[node_id]"

// How many things a practice experiment asks for: more for costlier nodes.
/proc/practice_items_needed(datum/research_node/N)
	return clamp(round(N.cost_ticks / 12), PRACTICE_MIN_ITEMS, PRACTICE_MAX_ITEMS)

// Adds one practice experiment per prerequisite of every early node. Runs once,
// the first time field work is looked up after the tree exists.
/proc/build_practice_experiments()
	if (practice_experiments_built || !research_nodes.len)
		return
	practice_experiments_built = TRUE
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (!N || N.era_tier >= PRACTICE_BELOW_TIER || N.mode == RESEARCH_MODE_BOOK || !N.prereqs.len)
			continue
		var/needed = practice_items_needed(N)
		var/share = round(PRACTICE_TOTAL_SHARE / N.prereqs.len, 0.01)
		for (var/req in N.prereqs)
			var/datum/research_node/P = get_research_node(req)
			if (!P)
				continue
			var/id = "practice_[N.id]_[P.id]"
			if (field_experiments[id])
				continue
			field_experiments[id] = list(N.id, practice_activity(P.id), needed, share, "Make [needed] things taught by [P.name]")
	// Caps are worked out again with the new experiments included.
	field_activity_caps = null

// Called when someone finishes making something. The recipe's own research
// node decides which practice it counts towards.
/proc/note_craft_practice(mob/user, result_path_string)
	if (!istext(result_path_string) || !map || !map.book_research_enabled())
		return FALSE
	var/node_id = get_recipe_node_req(result_path_string)
	if (!istext(node_id) || !get_research_node(node_id))
		return FALSE
	return note_field_work(user, practice_activity(node_id))

#undef PRACTICE_BELOW_TIER
#undef PRACTICE_TOTAL_SHARE
#undef PRACTICE_MIN_ITEMS
#undef PRACTICE_MAX_ITEMS
