// Personal recipe knowledge is opt-in configuration, never durable map state.
/obj/map_metadata/var/recipe_books = FALSE

/obj/map_metadata/proc/recipe_knowledge_enabled()
	return persistence && recipe_books

/mob/living/human
	var/list/known_recipe_nodes = null
	var/recipe_knowledge_initialized = FALSE

/proc/valid_recipe_node_id(node_id)
	return istext(node_id) && length(node_id) && !!get_research_node(node_id)

/proc/clean_recipe_node_ids(value)
	var/list/result = list()
	if (islist(value))
		for (var/node_id in value)
			if (valid_recipe_node_id(node_id))
				result |= node_id
	return result

/mob/living/human/proc/recipe_knowledge_exempt()
	// Agent-controlled Nomads remain subject to faction/era research, but do
	// not need a player's personal book collection. NPC traders are structures.
	return !!agent_character_for(src)

/mob/living/human/proc/knows_recipe_node(node_id)
	return valid_recipe_node_id(node_id) && stat != DEAD && (recipe_knowledge_exempt() || (islist(known_recipe_nodes) && (node_id in known_recipe_nodes)))

/mob/living/human/proc/can_learn_recipe_node(node_id)
	return stat == CONSCIOUS && valid_recipe_node_id(node_id) && map && map.recipe_knowledge_enabled() && map.is_node_done(civilization, node_id)

/mob/living/human/proc/learn_recipe_node(node_id)
	if (!can_learn_recipe_node(node_id))
		return FALSE
	known_recipe_nodes = clean_recipe_node_ids(known_recipe_nodes)
	known_recipe_nodes |= node_id
	recipe_knowledge_initialized = TRUE
	return TRUE

/mob/living/human/proc/initialize_recipe_knowledge()
	// Called only for a genuine new body, never during saved construction.
	known_recipe_nodes = list()
	recipe_knowledge_initialized = map && map.recipe_knowledge_enabled()

/mob/living/human/proc/forget_recipe_knowledge()
	known_recipe_nodes = list()
	// A corpse or subsequently revived body must not receive a migration grant.
	recipe_knowledge_initialized = TRUE

/mob/living/human/proc/migrate_recipe_knowledge()
	if (!map || !map.recipe_knowledge_enabled() || recipe_knowledge_initialized)
		return FALSE
	known_recipe_nodes = list()
	if (stat != DEAD)
		for (var/node_id in research_nodes)
			if (valid_recipe_node_id(node_id) && map.is_node_done(civilization, node_id))
				known_recipe_nodes += node_id
	recipe_knowledge_initialized = TRUE
	return TRUE

/mob/living/human/persistence_import_fields(list/saved_fields)
	. = ..()
	// Missing marker means legacy, not a newly spawned body. Invalid present
	// markers fail closed rather than reopening the one-time migration grant.
	if ("recipe_knowledge_initialized" in saved_fields)
		recipe_knowledge_initialized = recipe_knowledge_initialized == FALSE ? FALSE : TRUE
	else
		recipe_knowledge_initialized = FALSE
	known_recipe_nodes = clean_recipe_node_ids(known_recipe_nodes)
	if (stat == DEAD)
		forget_recipe_knowledge()

/obj/map_metadata/proc/activate_recipe_books()
	// Explicit operator integration point. Not called by this feature; a map
	// choosing live activation must snapshot existing bodies before any yield.
	if (!persistence)
		return FALSE
	recipe_books = TRUE
	for (var/mob/living/human/H in human_mob_list)
		H.migrate_recipe_knowledge()
	return TRUE

/obj/item/weapon/book/node_book
	name = "recipe manual"
	desc = "A reusable manual for a group of crafting recipes."
	icon = 'icons/obj/library.dmi'
	icon_state = "book2"
	unique = TRUE
	flammable = TRUE
	var/node_id = null

/obj/item/weapon/book/node_book/proc/refresh_node_title()
	if (!valid_recipe_node_id(node_id))
		name = "unreadable recipe manual"
		return FALSE
	var/datum/research_node/N = get_research_node(node_id)
	name = "[N.name] manual"
	return TRUE

/obj/item/weapon/book/node_book/after_load()
	. = ..()
	if (!valid_recipe_node_id(node_id))
		node_id = null
	refresh_node_title()

/proc/create_node_book(atom/location, node_id)
	if (!location || !valid_recipe_node_id(node_id))
		return null
	var/obj/item/weapon/book/node_book/B = new(location)
	B.node_id = node_id
	B.refresh_node_title()
	return B

/obj/item/weapon/book/node_book/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !H.can_learn_recipe_node(node_id))
		to_chat(user, SPAN_WARNING("You cannot study this manual beyond your faction or era's research."))
		return
	if (H.knows_recipe_node(node_id))
		to_chat(H, SPAN_NOTICE("You already know the recipes in this manual."))
		return
	var/reading_node = node_id
	to_chat(H, SPAN_NOTICE("You begin studying [src]. This takes one minute."))
	if (!do_after(H, 600, src) || QDELETED(src) || node_id != reading_node || !H.Adjacent(src) || H.incapacitated())
		return
	if (H.learn_recipe_node(reading_node))
		to_chat(H, SPAN_NOTICE("You have learned the recipes in [src]. The manual can be used again."))

/obj/map_metadata/proc/produce_first_node_book(faction, node_id)
	if (!recipe_knowledge_enabled())
		return
	// Exactly one copy per transition to DONE, not one per member or callback.
	for (var/obj/structure/research_bench/B in research_benches)
		if (B.faction == faction && get_turf(B) && !istype(B, /obj/structure/research_bench/adminbench))
			create_node_book(get_turf(B), node_id)
			return
	for (var/mob/living/human/H in human_mob_list)
		if (H.civilization == faction && H.stat != DEAD && get_turf(H))
			create_node_book(get_turf(H), node_id)
			return
