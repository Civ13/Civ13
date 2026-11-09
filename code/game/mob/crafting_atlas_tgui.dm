// Full-game presentation adapter. The standalone catalog fixture retains its
// existing HTML renderer without importing NanoUI, clients or gameplay systems.
var/global/datum/crafting_atlas_presenter/tgui/crafting_atlas_tgui_presenter = new

/datum/crafting_atlas_presenter/tgui/New()
	..()
	crafting_atlas_presenter = src

/datum/crafting_atlas_presenter/tgui/open(datum/crafting_atlas_reference/reference, mob/viewer, query, page, resource_id, legacy, era, processor, recipe_id)
	if (!reference || !viewer || !viewer.client)
		return FALSE
	query = copytext("[query]", 1, 65)
	page = max(1, min(10000, round(page)))
	resource_id = copytext("[resource_id]", 1, 257)
	era = copytext("[era]", 1, 16)
	processor = copytext("[processor]", 1, 32)
	recipe_id = copytext("[recipe_id]", 1, 32)
	var/ui_key = "crafting_atlas"
	var/datum/nanoui/tgui/crafting_atlas/ui = GLOB.nanomanager.get_open_ui(viewer, reference, ui_key)
	if (ui)
		var/datum/topic_state/crafting_atlas/old_state = ui.state
		if (!istype(ui) || !istype(old_state) || old_state.reader != viewer)
			ui.close()
			ui = null
	if (!ui)
		var/datum/topic_state/crafting_atlas/reader_state = new(reference, viewer)
		ui = new /datum/nanoui/tgui/crafting_atlas(viewer, reference, ui_key, "crafting_atlas.tmpl", "Crafting Atlas", 1000, 700, _state = reader_state)
		ui.use_on_close_logic(FALSE)
	ui.render_arguments = list(query, page, resource_id, legacy, era, processor, recipe_id)
	if (!ui.legacy_renderer)
		ui.set_initial_data(model(reference, viewer, query, page, resource_id, legacy, era, processor, recipe_id))
	ui.open()
	return TRUE

// Only this UI subtype admits navigation. Existing transport limits, owner,
// generation, ready/snapshot/ack and parent Topic checks still run first.
/datum/nanoui/tgui/crafting_atlas
	var/list/render_arguments

/datum/nanoui/tgui/crafting_atlas/allowed_actions()
	return list("atlas_navigate")

/datum/nanoui/tgui/crafting_atlas/get_html()
	if (legacy_renderer)
		var/datum/crafting_atlas_reference/reference = src_object
		var/list/arguments = list(user) + render_arguments
		return reference.render_html(arglist(arguments))
	return ..()

/datum/nanoui/tgui/crafting_atlas/update(var/force_open = FALSE)
	if (!user || !src_object || !state)
		close()
		return
	// Status only: no catalog queries or resource generation from manager polling.
	if (legacy_renderer)
		update_status(FALSE)
	else
		push_data(null, TRUE)

/datum/topic_state/crafting_atlas
	var/datum/crafting_atlas_reference/reference
	var/mob/reader

/datum/topic_state/crafting_atlas/New(datum/crafting_atlas_reference/new_reference, mob/new_reader)
	..()
	reference = new_reference
	reader = new_reader

/datum/topic_state/crafting_atlas/can_use_topic(var/src_object, var/mob/user)
	if (!user || src_object != reference || user != reader || !user.client)
		return STATUS_CLOSE
	// Original reference navigation is public to every connected mob, including
	// observers and incapacitated/dead readers. These actions cannot craft items.
	return STATUS_INTERACTIVE

/datum/crafting_atlas_presenter/tgui/navigate(datum/crafting_atlas_reference/reference, mob/viewer, payload, state)
	var/datum/nanoui/tgui/crafting_atlas/ui = GLOB.nanomanager.get_open_ui(viewer, reference, "crafting_atlas")
	if (!istype(ui) || ui.user != viewer || ui.src_object != reference || !state || ui.state != state)
		return FALSE
	if (state:can_use_topic(reference, viewer) != STATUS_INTERACTIVE || ui.legacy_renderer || !ui.frontend_ready || !ui.frontend_acknowledged)
		return FALSE
	if (!istext(payload) || length(payload) > 1024)
		return FALSE
	var/list/params
	try
		params = json_decode(payload)
	catch
		return FALSE
	if (!islist(params) || params.len > 6 || !istext(params["route"]))
		return FALSE
	var/route = params["route"]
	var/list/keys
	switch (route)
		if ("open")
			keys = list("route", "query", "era", "processor", "recipe")
		if ("page")
			keys = list("route", "query", "page", "recipe")
		if ("resource")
			keys = list("route", "resource")
		if ("reset")
			keys = list("route")
		else
			return FALSE
	for (var/key in params)
		if (!istext(key) || !(key in keys) || (!istext(params[key]) && !isnum(params[key])))
			return FALSE
	if (route == "resource")
		var/resource_id = copytext("[params["resource"]]", 1, 257)
		if (reference.resource_exists(resource_id))
			// Preserve direct-resource routing: reset all prior recipe filters.
			reference.show(viewer, resource_id, 1, resource_id)
	else if (route == "reset")
		reference.show(viewer)
	else if (route == "page")
		reference.show(viewer, params["query"], text2num("[params["page"]]"), legacy = TRUE, recipe_id = copytext("[params["recipe"]]", 1, 32))
	else
		reference.show(viewer, params["query"], era = copytext("[params["era"]]", 1, 16), processor = copytext("[params["processor"]]", 1, 32), recipe_id = copytext("[params["recipe"]]", 1, 32))
	// show() owns the original per-client throttle and updates only this reader.
	// Do not broadcast one reader's query to every viewer of the global catalog.
	return FALSE

/datum/crafting_atlas_presenter/tgui/proc/recipe_data(datum/crafting_atlas_reference/reference, mob/viewer, list/group, list/matches, list/recipe)
	var/list/inputs = list()
	var/list/outputs = list()
	for (var/list/ingredient in recipe["inputs"])
		inputs += list(reference.resource_info(viewer, ingredient))
	for (var/list/product in recipe["outputs"])
		outputs += list(reference.resource_info(viewer, product))
	var/list/variants = list()
	if (islist(group["variants"]))
		for (var/list/variant in matches)
			variants += list(list("id" = variant["id"], "kind" = html_encode("[variant["kind"]]"), "line" = variant["line"]))
	return list("id" = recipe["id"], "name" = html_encode("[recipe["name"]]"), "kind" = html_encode("[recipe["kind"]]"), "inputs" = inputs, "outputs" = outputs, "manual_hint" = html_encode(manual_hint(viewer, recipe)), "conditions" = html_encode("[recipe["conditions"]]"), "era_label" = html_encode("[recipe["era_label"]]"), "era_basis" = html_encode("[recipe["era_basis"]]"), "file" = recipe["file"], "line" = recipe["line"], "variants" = variants)

/datum/crafting_atlas_presenter/tgui/proc/guidance_data(datum/crafting_atlas_reference/reference, resource_id)
	var/list/all_routes = reference.catalog["acquisition"]
	var/list/routes = islist(all_routes) ? all_routes[resource_id] : null
	var/list/resource = reference.resources[resource_id]
	var/name = islist(resource) && resource["name"] ? resource["name"] : resource_id
	var/list/entries = list()
	if (islist(routes))
		for (var/list/route in routes)
			if (entries.len >= 12)
				break
			var/list/details = list()
			for (var/key in list("steps", "tools", "conditions", "era", "map_notes", "status"))
				var/value = route[key]
				if (islist(value))
					value = jointext(value, "; ")
				if (value)
					details += list(list("label" = key, "value" = html_encode("[value]")))
			var/list/related = list()
			for (var/field in list("inputs", "outputs"))
				var/list/identities = route[field]
				if (!islist(identities))
					continue
				for (var/id in identities)
					var/list/info = reference.resources[id]
					var/label = islist(info) && info["name"] ? info["name"] : id
					related += list(list("id" = id, "name" = html_encode("[label]"), "heading" = field == "inputs" ? "Needs" : "Can provide (conditional)"))
			entries += list(list("name" = html_encode("[route["name"]]"), "details" = details, "related" = related, "file" = route["file"], "line" = route["line"], "revision" = route["audit_commit"]))
	return list("name" = html_encode("[name]"), "heading" = findtext("[resource_id]", "/turf/") == 1 ? "Gathering from" : "How to obtain", "routes" = entries, "more" = islist(routes) && routes.len > 12)

// Family metadata is generated from reviewed public recipe/output identities.
// Navigation still selects only canonical recipe IDs, never family IDs.
/datum/crafting_atlas_presenter/tgui/proc/family_variants(list/members, recipe_id)
	var/list/options = list()
	for (var/list/member in members)
		var/list/group = member["group"]
		var/list/matches = member["matches"]
		var/list/chosen = matches[1]
		for (var/list/variant in matches)
			if (variant["id"] == recipe_id)
				chosen = variant
		var/list/products = list()
		for (var/list/product in group["outputs"])
			products += "[product["quantity"]] x [product["name"]]"
		var/list/ingredients = list()
		for (var/list/ingredient in group["inputs"])
			ingredients += "[ingredient["quantity"]] x [ingredient["name"]]"
		var/label = "[jointext(products, ", ")] / needs [jointext(ingredients, ", ")] / [chosen["kind"]] / [group["era_label"]] (line [chosen["line"]])"
		options += list(list("id" = chosen["id"], "label" = html_encode(label)))
	return options

/datum/crafting_atlas_presenter/tgui/proc/model(datum/crafting_atlas_reference/reference, mob/viewer, query = "", page = 1, resource_id = "", legacy = FALSE, era = "", processor = "", recipe_id = "")
	query = copytext("[query]", 1, 65)
	page = max(1, min(10000, round(page)))
	var/list/data = list("query" = html_encode(query), "page" = page, "mode" = legacy ? "page" : "graph", "era" = era, "processor" = processor, "recipes" = list(), "resources" = list(), "entries" = list(), "detail" = null, "guidance" = null, "recipe_count" = 0, "resource_count" = 0, "previous" = FALSE, "next" = FALSE)
	if (resource_id)
		data["guidance"] = guidance_data(reference, resource_id)
	if (legacy)
		var/first = (page - 1) * 12 + 1
		var/matched = 0
		var/shown = 0
		var/list/entries = list()
		for (var/list/group in reference.recipes)
			var/list/matches = reference.matching_variants(group, query)
			if (!matches.len)
				continue
			matched++
			if (matched < first || shown >= 12)
				continue
			shown++
			var/list/recipe = reference.variant_record(group, matches, recipe_id)
			entries += list(recipe_data(reference, viewer, group, matches, recipe))
		data["entries"] = entries
		data["recipe_count"] = matched
		data["previous"] = page > 1
		data["next"] = matched > first + 11
		return data
	var/list/resource_matches = reference.matching_resources(query)
	var/list/resource_rows = list()
	for (var/id in resource_matches)
		if (resource_rows.len >= 150)
			break
		var/list/resource = reference.resources[id]
		var/name = resource["name"] ? resource["name"] : id
		resource_rows += list(list("id" = id, "name" = html_encode("[name]")))
	data["resources"] = resource_rows
	data["resource_count"] = resource_matches.len
	var/list/index = list()
	var/list/selected
	var/list/selected_group
	var/list/selected_matches
	var/selected_family
	var/list/family_rows = list()
	var/list/family_members = list()
	var/matched = 0
	var/recipe_matches = 0
	for (var/list/recipe in reference.recipes)
		var/list/matches = reference.matching_variants(recipe, query)
		if (!matches.len)
			continue
		if (processor && recipe["processor"] != processor)
			continue
		var/list/eras = recipe["unlock_eras"]
		if (era == "unknown")
			if (islist(eras) && eras.len)
				continue
		else if (era == "multiple")
			if (!islist(eras) || eras.len < 2)
				continue
		else if (era && (!islist(eras) || !isnum(text2num(era)) || !(text2num(era) in eras)))
			continue
		recipe_matches++
		var/list/choice = reference.variant_record(recipe, matches, recipe_id)
		var/family = recipe["family_id"] ? recipe["family_id"] : "recipe_[recipe["id"]]"
		var/list/row = family_rows[family]
		if (!islist(row))
			matched++
			row = list("id" = choice["id"], "family_id" = family, "name" = html_encode("[recipe["name"]]"), "era_label" = html_encode("[recipe["era_label"]]"), "variant_count" = 0, "manual_hint" = html_encode(manual_hint(viewer, choice)))
			family_rows[family] = row
			family_members[family] = list()
			if (matched <= 150)
				index += list(row)
		// Families may contain both basic/known and unknown variants. Only grey
		// the whole family if every matching route needs a personal manual.
		var/choice_hint = html_encode(manual_hint(viewer, choice))
		if (!choice_hint)
			row["manual_hint"] = ""
		else if (row["manual_hint"] && row["manual_hint"] != choice_hint)
			row["manual_hint"] = "Needs a manual; select a variant for details"
		row["variant_count"]++
		if (row["era_label"] != html_encode("[recipe["era_label"]]"))
			row["era_label"] = "Multiple unlock eras"
		var/list/members = family_members[family]
		members += list(list("group" = recipe, "matches" = matches))
		if (!selected || choice["id"] == recipe_id)
			selected = choice
			selected_group = recipe
			selected_matches = matches
			selected_family = family
			row["id"] = choice["id"]
	data["recipes"] = index
	data["recipe_count"] = recipe_matches
	data["family_count"] = matched
	if (selected)
		var/list/detail = recipe_data(reference, viewer, selected_group, selected_matches, selected)
		var/list/members = family_members[selected_family]
		if (members.len > 1)
			detail["family_variants"] = family_variants(members, selected["id"])
		data["detail"] = detail
	return data

// Hints describe personal knowledge, never replace server-side crafting admission.
/proc/crafting_node_manual_hint(mob/viewer, node_id)
	if (!map || !map.recipe_knowledge_enabled() || !ishuman(viewer) || !node_id)
		return ""
	var/mob/living/human/H = viewer
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || H.knows_recipe_node(node_id))
		return ""
	return "Needs the [N.name] manual"

/proc/crafting_recipe_manual_hint(mob/viewer, result_path)
	return crafting_node_manual_hint(viewer, get_recipe_node_req(result_path))

/mob/living/human/proc/refresh_recipe_knowledge_menus()
	if (!client)
		return
	var/datum/nanoui/tgui/crafting_atlas/ui = GLOB.nanomanager.get_open_ui(src, crafting_atlas_reference, "crafting_atlas")
	if (istype(ui) && ui.user == src && islist(ui.render_arguments))
		var/list/arguments = list(crafting_atlas_reference, src) + ui.render_arguments
		if (ui.legacy_renderer)
			crafting_atlas_tgui_presenter.open(arglist(arguments))
		else
			ui.push_data(crafting_atlas_tgui_presenter.model(arglist(arguments)), TRUE)
	var/obj/item/stack/stack = using_object
	if (istype(stack) && stack.loc == src && item_is_in_hands(stack))
		stack.list_recipes(src)

/datum/crafting_atlas_presenter/tgui/manual_hint(mob/viewer, list/recipe)
	// Route metadata explicitly excludes reactions/acquisition and true basics.
	if (recipe["research_status"] != "gated")
		return ""
	var/list/nodes = recipe["research_nodes"]
	var/list/hints = list()
	if (islist(nodes))
		for (var/node_id in nodes)
			var/hint = crafting_node_manual_hint(viewer, node_id)
			if (hint)
				hints += hint
	return jointext(hints, "; ")

/proc/crafting_recipe_manual_suffix(mob/viewer, result_path)
	var/hint = crafting_recipe_manual_hint(viewer, result_path)
	return hint ? " - [hint]" : ""
