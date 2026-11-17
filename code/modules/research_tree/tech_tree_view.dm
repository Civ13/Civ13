// The tech tree from one character's own knowledge: read only, no bench or
// book needed. The Crafting window opens it on the node a "Not learned yet"
// recipe needs, so the player can see where that node sits and what groundwork
// leads to it. It sends nothing back: learning still happens at a bench or
// from a book.

/client
	// The node the tech tree should jump to when it next opens, and a counter
	// so the same node can be asked for twice.
	var/tmp/tech_tree_focus = ""
	var/tmp/tech_tree_focus_seq = 0

/datum/topic_state/tech_tree/can_use_topic(var/src_object, var/mob/user)
	if (!ishuman(user) || !user.client || user.stat == DEAD || !map || !map.recipe_knowledge_enabled())
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/var/global/datum/topic_state/tech_tree/tech_tree_state = new()
/var/global/datum/tech_tree_view/tech_tree_view = new()

/datum/tech_tree_view

/datum/tech_tree_view/ui_actions(ui_key)
	return list()

// Open (or refresh) the tree for H, jumping to node_id when one is given.
/datum/tech_tree_view/proc/show(mob/living/human/H, node_id = "")
	if (!istype(H) || !H.client || tech_tree_state.can_use_topic(src, H) != STATUS_INTERACTIVE)
		return FALSE
	var/datum/research_node/N = node_id ? get_research_node(node_id) : null
	H.client.tech_tree_focus = N && !research_node_dormant(N) ? "[node_id]" : ""
	if (length(H.client.tech_tree_focus))
		H.client.tech_tree_focus_seq++
	ui_interact(H)
	return TRUE

/datum/tech_tree_view/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client)
		return
	var/list/data = tree_data(H)
	if (!data)
		return
	open_tgui(user, ui_key, "tech_tree.tmpl", "Tech tree", 900, 680, data, ui, force_open, tech_tree_state, keep_interaction = TRUE)

// Every live node grouped by tree and layer like the bench screen, each marked
// known, learnable now, or locked for this character alone.
/datum/tech_tree_view/proc/tree_data(mob/living/human/H)
	if (!map || !map.recipe_knowledge_enabled())
		return null
	var/books = map.book_research_enabled()
	var/list/trees = list()
	var/list/tree_index = list()
	var/list/tree_layer_index = list()
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (research_node_dormant(N))
			continue
		var/list/tree_entry = tree_index[N.tree]
		if (!tree_entry)
			tree_entry = list("tree_name" = N.tree, "idx" = trees.len, "layers" = list())
			tree_index[N.tree] = tree_entry
			tree_layer_index[N.tree] = list()
			trees += list(tree_entry)
		var/list/layer_index = tree_layer_index[N.tree]
		var/list/layer_entry = layer_index[N.category]
		if (!layer_entry)
			layer_entry = list("layer_name" = N.category, "nodes" = list())
			layer_index[N.category] = layer_entry
			tree_entry["layers"] += list(layer_entry)
		var/state
		var/label
		var/status_text
		if (H.knows_recipe_node(node_id))
			state = "known"
			label = "You know this"
			status_text = "Done"
		else if (H.can_learn_recipe_node(node_id))
			state = "ready"
			label = books ? "Ready to learn" : "Your faction has it"
			status_text = "Available"
		else
			state = "locked"
			label = books ? "Needs groundwork" : "Not researched yet"
			status_text = "Locked"
		var/list/prereq_ids = list()
		var/list/prereq_names = list()
		for (var/req in N.prereqs)
			prereq_ids += req
			var/datum/research_node/RN = get_research_node(req)
			prereq_names += RN ? RN.name : req
		var/mode_text = "Passive study"
		if (N.mode == RESEARCH_MODE_PROTOTYPE)
			mode_text = "Prototype"
		else if (N.mode == RESEARCH_MODE_BOOK)
			mode_text = "Book only"
		layer_entry["nodes"] += list(list(
			"id" = node_id,
			"name" = N.name,
			"era_tier" = N.era_tier,
			"era_name" = ordinal_age_name(N.era_tier),
			"grid_col" = get_node_grid_col(node_id),
			"is_era_changing" = (N.mode == RESEARCH_MODE_PROTOTYPE),
			"mode_text" = mode_text,
			"discipline" = scholar_disciplines[node_discipline(node_id)],
			"prereq_ids" = jointext(prereq_ids, ","),
			"prereq_names" = prereq_names.len ? jointext(prereq_names, ", ") : "None",
			"groundwork" = node_groundwork_rows(H, N),
			"recipe_names" = get_node_recipe_names(node_id),
			"effect" = research_node_effect_text(node_id),
			"state" = state,
			"state_label" = label,
			"status_text" = status_text))
	return list(
		"tech_tree" = 1,
		"book_research" = books ? 1 : 0,
		"focus" = H.client ? H.client.tech_tree_focus : "",
		"focus_seq" = H.client ? H.client.tech_tree_focus_seq : 0,
		"trees" = trees)
