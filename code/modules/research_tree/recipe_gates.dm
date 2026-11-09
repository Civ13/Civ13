// Explicit free outputs. Subtypes are NOT automatically exempt. Other proposed
// basics (tools, shelter, fire, research bench, trail marker) remain node-gated.
var/global/list/basic_crafting_recipes = list(
	"/obj/item/stack/material/rope",
	"/obj/item/stack/material/stonebrick",
	"/obj/structure/researchdesk",
)

/proc/is_basic_crafting_recipe(result_path_string)
	return istext(result_path_string) && (result_path_string in basic_crafting_recipes)

// World eligibility is separate from the actor hook, for recipe menu visibility.
/proc/crafting_node_world_allowed(faction, node_id)
	return map && istext(node_id) && get_research_node(node_id) && map.is_node_done(faction, node_id)

/proc/crafting_node_allowed(mob/living/human/H, node_id)
	return istype(H) && crafting_node_world_allowed(H.civilization, node_id) && (!map.recipe_knowledge_enabled() || H.knows_recipe_node(node_id))

// Unknown outputs fail closed. Acquisition and generic chemistry do not call this.
/proc/crafting_recipe_allowed(mob/living/human/H, result_path_string)
	if (!istype(H))
		return FALSE
	if (is_basic_crafting_recipe(result_path_string))
		return TRUE
	return crafting_node_allowed(H, get_recipe_node_req(result_path_string))
