// Explicit fully ungated outputs. Every other crafted output needs research
// (Val, 2026-11-09), except the campfire: a new character's first fire must
// not wait on Basic Furniture (Val, 2026-11-13). Tests may add a synthetic
// output here.
var/global/list/basic_crafting_recipes = list("/obj/structure/oven/fireplace")

/proc/is_basic_crafting_recipe(result_path_string)
	return istext(result_path_string) && (result_path_string in basic_crafting_recipes)

// World eligibility is separate from the actor hook, for recipe menu visibility.
/proc/crafting_node_world_allowed(faction, node_id)
	return map && istext(node_id) && get_research_node(node_id) && map.is_node_done(faction, node_id)

// Agent characters skip the personal check, but on a book research world
// nothing else would stop them, so they keep the world's research ceiling.
/proc/book_research_agent_allowed(mob/living/human/H, node_id)
	return H.recipe_knowledge_exempt() && crafting_node_world_allowed(H.civilization, node_id)

/proc/crafting_node_allowed(mob/living/human/H, node_id)
	// Book research: only what the character knows. No faction or era grants.
	if (istype(H) && map && map.book_research_enabled())
		if (!istext(node_id) || !get_research_node(node_id))
			return FALSE
		if (H.recipe_knowledge_exempt())
			return book_research_agent_allowed(H, node_id)
		return H.knows_recipe_node(node_id)
	return istype(H) && crafting_node_world_allowed(H.civilization, node_id) && (!map.recipe_knowledge_enabled() || H.knows_recipe_node(node_id))

// The same check for a hand action, telling the player which knowledge is
// missing instead of failing silently.
/proc/crafting_node_allowed_or_warn(mob/living/human/H, node_id)
	if (crafting_node_allowed(H, node_id))
		return TRUE
	return crafting_nodes_allowed_or_warn(H, list(node_id))

// Seconds before the same missing-knowledge warning is shown to a player again,
// so repeated clicks on the same thing do not flood the chat.
#define RESEARCH_WALL_REPEAT_DELAY (3 SECONDS)
// "\ref[H]" -> list(warning text, world.time it was last shown).
var/global/list/research_wall_last_warning = list()

// Any one of several nodes allows the action. The warning names every chapter
// that would do, e.g. "Study the Steelmaking or Tatara Smelting chapter first."
/proc/crafting_nodes_allowed_or_warn(mob/living/human/H, list/node_ids)
	if (!istype(H) || !islist(node_ids))
		return FALSE
	var/list/names = list()
	for (var/node_id in node_ids)
		if (crafting_node_allowed(H, node_id))
			return TRUE
		var/datum/research_node/N = istext(node_id) ? get_research_node(node_id) : null
		if (N)
			names += "<b>[N.name]</b>"
	if (!names.len)
		return FALSE
	var/joined = english_list(names, and_text = " or ")
	var/text
	if (map && map.book_research_enabled())
		text = "You don't know how to do this yet. Study the [joined] chapter first."
	else
		text = "You don't know how to do this yet. It needs [joined]."
	var/key = "\ref[H]"
	var/list/last = research_wall_last_warning[key]
	if (islist(last) && last[1] == text && world.time < last[2] + RESEARCH_WALL_REPEAT_DELAY)
		return FALSE
	if (research_wall_last_warning.len > 500)
		research_wall_last_warning.Cut()
	research_wall_last_warning[key] = list(text, world.time)
	for (var/node_id in node_ids)
		player_activity.research_wall(H, node_id)
	to_chat(H, SPAN_WARNING(text))
	return FALSE

#undef RESEARCH_WALL_REPEAT_DELAY

// Planks: on a book research world anyone may turn logs into planks (with an
// axe or saw, or by hand with flint, wedge and mallet), because the free
// writing supplies and the research bench are made from planks (Val,
// 2026-11-11). Elsewhere planks still need Basic Toolmaking.
/proc/plank_making_allowed(mob/living/human/H)
	if (istype(H) && map && map.book_research_enabled())
		return TRUE
	return crafting_node_allowed(H, "basic_tools")

/proc/plank_making_allowed_or_warn(mob/living/human/H)
	if (istype(H) && map && map.book_research_enabled())
		return TRUE
	return crafting_node_allowed_or_warn(H, "basic_tools")

// Unknown outputs fail closed. Acquisition and generic chemistry do not call this.
/proc/crafting_recipe_allowed(mob/living/human/H, result_path_string)
	if (!istype(H))
		return FALSE
	if (is_basic_crafting_recipe(result_path_string) || tutorial_waterworks_recipe(H, result_path_string))
		return TRUE
	var/node_id = get_recipe_node_req(result_path_string)
	// Book research: the pencil, paper and blank book are free from the start,
	// so research can begin at all.
	if (is_book_research_writing_supply(result_path_string))
		return TRUE
	// Book research: anyone who knows the groundwork may build what the next
	// step of research needs, without a manual for it.
	if (map && map.book_research_enabled() && is_research_essential_recipe(result_path_string))
		if (!istext(node_id) || !get_research_node(node_id))
			return FALSE
		if (H.recipe_knowledge_exempt())
			return book_research_agent_allowed(H, node_id)
		return H.knows_recipe_node(node_id) || H.knows_research_prereqs(node_id)
	// Research essentials still need the world's research, never a manual.
	if (is_research_essential_recipe(result_path_string))
		return crafting_node_world_allowed(H.civilization, node_id)
	// A crude experimental machine for a capstone demonstration (demonstrations.dm).
	// Or a prototype of a subject the actor's book is a third into (subject_prototypes.dm).
	// Or guided work beside someone who knows the subject (trade_learning.dm).
	return crafting_node_allowed(H, node_id) || demonstration_kit_allowed(H, result_path_string) || subject_prototype_allowed(H, result_path_string) || guided_work_allowed(H, result_path_string)

// What to tell a player whose craft crafting_recipe_allowed() refused: on a
// book-research world, what their prototype attempt is missing.
/proc/crafting_recipe_refusal(mob/living/human/H, result_path_string)
	var/why = subject_prototype_refusal(H, result_path_string)
	return why ? SPAN_WARNING(why) : SPAN_WARNING("This recipe requires its research node.")

// The only recipes that skip personal manuals are the ones needed to reach the
// next research level: the research bench, the legacy research desk and every
// node's prototype item (any subtype the bench would accept).
/proc/is_research_essential_recipe(result_path_string)
	var/path = istext(result_path_string) ? text2path(result_path_string) : result_path_string
	if (!ispath(path))
		return FALSE
	if (ispath(path, /obj/structure/research_bench) || ispath(path, /obj/structure/researchdesk))
		return TRUE
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (N && N.prototype_type && ispath(path, N.prototype_type))
			return TRUE
	return FALSE
