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
		ui.set_initial_data(model(reference, viewer, query, page, resource_id, legacy, era, processor, recipe_id, ui.scope))
	ui.open()
	return TRUE

// Only this UI subtype admits navigation. Existing transport limits, owner,
// generation, ready/snapshot/ack and parent Topic checks still run first.
/datum/nanoui/tgui/crafting_atlas
	var/list/render_arguments
	// "" lists the recipes of the reader's own map; "all" adds every other map's list.
	var/scope = ""

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
			keys = list("route", "query", "era", "processor", "recipe", "scope")
		if ("page")
			keys = list("route", "query", "page", "recipe")
		if ("resource")
			keys = list("route", "resource", "recipe", "scope")
		if ("reset")
			keys = list("route")
		else
			return FALSE
	for (var/key in params)
		if (!istext(key) || !(key in keys) || (!istext(params[key]) && !isnum(params[key])))
			return FALSE
	// Scope is a view preference of this window, never a recipe permission.
	if ("scope" in params)
		ui.scope = params["scope"] == "all" ? "all" : ""
	if (route == "resource")
		var/resource_id = copytext("[params["resource"]]", 1, 257)
		if (reference.resource_exists(resource_id))
			// Preserve direct-resource routing: reset all prior recipe filters.
			// A recipe picked on the resource page stays on that page.
			reference.show(viewer, resource_id, 1, resource_id, recipe_id = copytext("[params["recipe"]]", 1, 32))
	else if (route == "reset")
		ui.scope = ""
		reference.show(viewer)
	else if (route == "page")
		reference.show(viewer, params["query"], text2num("[params["page"]]"), legacy = TRUE, recipe_id = copytext("[params["recipe"]]", 1, 32))
	else
		reference.show(viewer, params["query"], era = copytext("[params["era"]]", 1, 16), processor = copytext("[params["processor"]]", 1, 32), recipe_id = copytext("[params["recipe"]]", 1, 32))
	// show() owns the original per-client throttle and updates only this reader.
	// Do not broadcast one reader's query to every viewer of the global catalog.
	return FALSE

// Each reader keeps the preview filenames already sent to them, so browsing
// does not rebuild and resend the same sprites on every navigation.
/client
	var/list/atlas_icon_cache

/datum/crafting_atlas_presenter/tgui
	var/list/resource_search

// The in-game name where the catalog has one; canonical IDs never change.
/datum/crafting_atlas_presenter/tgui/proc/display_name(datum/crafting_atlas_reference/reference, id, fallback)
	var/list/resource = reference.resources[id]
	if (islist(resource))
		if (resource["title"])
			return "[resource["title"]]"
		if (resource["name"])
			return "[resource["name"]]"
	return "[fallback ? fallback : id]"

/datum/crafting_atlas_presenter/tgui/proc/resource_view(datum/crafting_atlas_reference/reference, mob/viewer, list/resource)
	var/id = resource["id"]
	var/client/reader = viewer.client
	var/list/cached = reader && islist(reader.atlas_icon_cache) ? reader.atlas_icon_cache[id] : null
	if (!islist(cached))
		var/list/info = reference.resource_info(viewer, resource)
		cached = list(info["image"], info["preview"])
		if (reader)
			if (!islist(reader.atlas_icon_cache))
				reader.atlas_icon_cache = list()
			reader.atlas_icon_cache[id] = cached
	return list("id" = id, "name" = html_encode(display_name(reference, id, resource["name"])), "quantity" = html_encode("[resource["quantity"]]"), "image" = cached[1], "preview" = cached[2])

// Research the reader still lacks. Mirrors crafting_recipe_allowed for display
// only; crafting itself keeps its own server-side checks.
/datum/crafting_atlas_presenter/tgui/proc/research_data(mob/viewer, list/recipe, list/known)
	var/list/rows = list()
	var/list/nodes = recipe["research_nodes"]
	if (recipe["research_status"] != "gated" || !islist(nodes))
		return rows
	var/mob/living/human/H = viewer
	for (var/node_id in nodes)
		var/datum/research_node/N = get_research_node(node_id)
		var/state = ""
		if (istype(H) && map && N)
			var/key = "[recipe["manual_free"] ? "free" : "node"]:[node_id]"
			state = known[key]
			if (!state)
				var/done
				if (!recipe["manual_free"])
					done = crafting_node_allowed(H, node_id)
				else if (map.book_research_enabled())
					done = H.knows_recipe_node(node_id) || H.knows_research_prereqs(node_id)
				else
					done = crafting_node_world_allowed(H.civilization, node_id)
				state = done ? "done" : "needed"
				known[key] = state
		rows += list(list("id" = node_id, "name" = html_encode(N ? N.name : replacetext("[node_id]", "_", " ")), "state" = state))
	return rows

/datum/crafting_atlas_presenter/tgui/proc/research_state(mob/viewer, list/recipe, list/known)
	var/state = ""
	for (var/list/row in research_data(viewer, recipe, known))
		if (row["state"] == "needed")
			return "needed"
		if (row["state"] == "done")
			state = "done"
	return state

/datum/crafting_atlas_presenter/tgui/proc/retired(list/recipe)
	return map && isnum(recipe["maximum_era"]) && !recipe_age_allowed(recipe["maximum_era"])

// Material recipes come in one list per map family. Keep the reader's own list
// first; other maps' copies are only shown on request.
/datum/crafting_atlas_presenter/tgui/proc/catalog_matches(list/matches, catalog, scope)
	var/list/local = list()
	var/list/other = list()
	for (var/list/variant in matches)
		var/kind = "[variant["kind"]]"
		if (findtext(kind, "Material / ") != 1 || kind == "Material / [catalog]")
			local += list(variant)
		else
			other += list(variant)
	if (scope == "all")
		return local + other
	return local

/datum/crafting_atlas_presenter/tgui/proc/has_local(list/matches, catalog)
	if (!matches.len)
		return FALSE
	var/list/first = matches[1]
	var/kind = "[first["kind"]]"
	return findtext(kind, "Material / ") != 1 || kind == "Material / [catalog]"

/datum/crafting_atlas_presenter/tgui/proc/search_words(datum/crafting_atlas_reference/reference, query)
	var/list/words = list()
	for (var/word in splittext(reference.search_text(query), " "))
		if (word && words.len < 6)
			words += word
	return words

// Every word must match the same variant; one word keeps the original matching.
/datum/crafting_atlas_presenter/tgui/proc/search_variants(datum/crafting_atlas_reference/reference, list/recipe, list/words)
	var/list/matches = reference.matching_variants(recipe, words.len ? words[1] : "")
	for (var/i in 2 to words.len)
		if (!matches.len)
			break
		var/list/also = reference.matching_variants(recipe, words[i])
		var/list/both = list()
		for (var/list/variant in matches)
			if (variant in also)
				both += list(variant)
		matches = both
	return matches

/datum/crafting_atlas_presenter/tgui/proc/all_words(text, list/words)
	for (var/word in words)
		if (!findtext(text, word))
			return FALSE
	return TRUE

/datum/crafting_atlas_presenter/tgui/proc/search_resources(datum/crafting_atlas_reference/reference, list/words)
	var/list/exact = list()
	var/list/other = list()
	if (!words.len)
		return exact
	if (!islist(resource_search))
		resource_search = list()
		for (var/id in reference.resources)
			var/list/resource = reference.resources[id]
			if (islist(resource))
				resource_search[id] = reference.search_text("[resource["title"]] [resource["name"]] [id]")
	var/phrase = jointext(words, " ")
	for (var/id in resource_search)
		if (!all_words(resource_search[id], words))
			continue
		if (reference.search_text(display_name(reference, id)) == phrase)
			exact += id
		else
			other += id
	return exact + other

/datum/crafting_atlas_presenter/tgui/proc/amounts(datum/crafting_atlas_reference/reference, list/resources)
	var/list/parts = list()
	for (var/list/resource in resources)
		// Gathering routes carry notes such as "conditional" instead of a count.
		var/quantity = "[resource["quantity"]]"
		var/name = display_name(reference, resource["id"], resource["name"])
		parts += isnum(text2num(quantity)) ? "[quantity] x [name]" : name
	return jointext(parts, ", ")

/datum/crafting_atlas_presenter/tgui/proc/row_data(datum/crafting_atlas_reference/reference, mob/viewer, list/recipe, list/choice, catalog, list/matches, list/known)
	var/list/row = list("id" = choice["id"], "name" = html_encode("[recipe["name"]]"), "era_label" = html_encode("[recipe["era_label"]]"), "kind" = html_encode("[choice["kind"]]"), "variant_count" = 1, "manual_hint" = html_encode(manual_hint(viewer, choice)), "research" = research_state(viewer, recipe, known), "retired" = retired(recipe), "elsewhere" = !has_local(matches, catalog), "image" = "", "makes" = "", "needs" = html_encode(amounts(reference, recipe["inputs"])))
	var/list/outputs = recipe["outputs"]
	if (islist(outputs) && outputs.len)
		var/list/product = resource_view(reference, viewer, outputs[1])
		row["image"] = product["image"]
		row["makes"] = html_encode(amounts(reference, outputs))
	return row

/datum/crafting_atlas_presenter/tgui/proc/recipe_data(datum/crafting_atlas_reference/reference, mob/viewer, list/group, list/matches, list/recipe, catalog, list/known)
	var/list/inputs = list()
	var/list/outputs = list()
	for (var/list/ingredient in recipe["inputs"])
		inputs += list(resource_view(reference, viewer, ingredient))
	for (var/list/product in recipe["outputs"])
		outputs += list(resource_view(reference, viewer, product))
	var/list/variants = list()
	if (islist(group["variants"]))
		for (var/list/variant in matches)
			variants += list(list("id" = variant["id"], "kind" = html_encode("[variant["kind"]]"), "line" = variant["line"]))
	var/station = ""
	if (recipe["station"])
		station = display_name(reference, recipe["station"], recipe["processor_name"])
	return list("id" = recipe["id"], "name" = html_encode("[recipe["name"]]"), "kind" = html_encode("[recipe["kind"]]"), "inputs" = inputs, "outputs" = outputs, "manual_hint" = html_encode(manual_hint(viewer, recipe)), "conditions" = html_encode("[recipe["conditions"]]"), "era_label" = html_encode("[recipe["era_label"]]"), "era_basis" = html_encode("[recipe["era_basis"]]"), "file" = recipe["file"], "line" = recipe["line"], "variants" = variants, "research" = research_data(viewer, recipe, known), "retired" = retired(recipe), "maximum_era" = recipe["maximum_era"], "station" = html_encode(station), "elsewhere" = !has_local(matches, catalog))

/datum/crafting_atlas_presenter/tgui/proc/guidance_data(datum/crafting_atlas_reference/reference, mob/viewer, resource_id)
	var/list/all_routes = reference.catalog["acquisition"]
	var/list/routes = islist(all_routes) ? all_routes[resource_id] : null
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
			var/list/steps = list()
			if (islist(route["steps"]))
				for (var/step in route["steps"])
					steps += html_encode("[step]")
			var/list/related = list()
			for (var/field in list("inputs", "outputs"))
				var/list/identities = route[field]
				if (!islist(identities))
					continue
				for (var/id in identities)
					var/list/view = resource_view(reference, viewer, list("id" = id, "name" = id, "quantity" = ""))
					related += list(list("id" = id, "name" = view["name"], "image" = view["image"], "heading" = field == "inputs" ? "Needs" : "Can provide (conditional)"))
			entries += list(list("name" = html_encode("[route["name"]]"), "details" = details, "steps" = steps, "related" = related, "file" = route["file"], "line" = route["line"], "revision" = route["audit_commit"]))
	var/list/view = resource_view(reference, viewer, list("id" = resource_id, "name" = resource_id, "quantity" = ""))
	return list("id" = resource_id, "name" = view["name"], "image" = view["image"], "heading" = findtext("[resource_id]", "/turf/") == 1 ? "Gathering from" : "How to obtain", "routes" = entries, "more" = islist(routes) && routes.len > 12, "made_by" = list(), "used_in" = list(), "made_by_count" = 0, "used_in_count" = 0)

// Family metadata is generated from reviewed public recipe/output identities.
// Navigation still selects only canonical recipe IDs, never family IDs.
/datum/crafting_atlas_presenter/tgui/proc/family_variants(datum/crafting_atlas_reference/reference, mob/viewer, list/members, recipe_id, catalog, list/known)
	var/list/options = list()
	for (var/list/member in members)
		var/list/group = member["group"]
		var/list/matches = member["matches"]
		var/list/chosen = matches[1]
		for (var/list/variant in matches)
			if (variant["id"] == recipe_id)
				chosen = variant
		var/label = "[amounts(reference, group["inputs"])] makes [amounts(reference, group["outputs"])]"
		options += list(list("id" = chosen["id"], "label" = html_encode(label), "needs" = html_encode(amounts(reference, group["inputs"])), "makes" = html_encode(amounts(reference, group["outputs"])), "kind" = html_encode("[chosen["kind"]]"), "era_label" = html_encode("[group["era_label"]]"), "line" = chosen["line"], "research" = research_state(viewer, group, known), "elsewhere" = !has_local(matches, catalog)))
	return options

/datum/crafting_atlas_presenter/tgui/proc/era_allows(list/recipe, era)
	var/list/eras = recipe["unlock_eras"]
	if (era == "unknown")
		if (islist(eras) && eras.len)
			return FALSE
	else if (era == "multiple")
		if (!islist(eras) || eras.len < 2)
			return FALSE
	else if (era && (!islist(eras) || !isnum(text2num(era)) || !(text2num(era) in eras)))
		return FALSE
	return TRUE

// A resource page lists the recipes that make and use exactly that resource,
// instead of a text search for its type path.
/datum/crafting_atlas_presenter/tgui/proc/resource_model(datum/crafting_atlas_reference/reference, mob/viewer, list/data, resource_id, recipe_id, catalog, scope, list/known)
	var/list/guidance = guidance_data(reference, viewer, resource_id)
	var/list/made_by = list()
	var/list/used_in = list()
	var/made = 0
	var/used = 0
	var/hidden = 0
	var/list/selected
	var/list/selected_group
	var/list/selected_matches
	for (var/list/recipe in reference.recipes)
		var/makes = FALSE
		var/uses = FALSE
		for (var/list/product in recipe["outputs"])
			if (product["id"] == resource_id)
				makes = TRUE
		for (var/list/ingredient in recipe["inputs"])
			if (ingredient["id"] == resource_id)
				uses = TRUE
		if (!makes && !uses)
			continue
		var/list/matches = catalog_matches(reference.matching_variants(recipe, ""), catalog, scope)
		if (!matches.len)
			hidden++
			continue
		var/list/choice = reference.variant_record(recipe, matches, recipe_id)
		if (choice["id"] == recipe_id)
			selected = choice
			selected_group = recipe
			selected_matches = matches
		if (makes && ++made <= 60)
			made_by += list(row_data(reference, viewer, recipe, choice, catalog, matches, known))
		if (uses && ++used <= 60)
			used_in += list(row_data(reference, viewer, recipe, choice, catalog, matches, known))
	guidance["made_by"] = made_by
	guidance["used_in"] = used_in
	guidance["made_by_count"] = made
	guidance["used_in_count"] = used
	data["guidance"] = guidance
	data["query"] = ""
	data["hidden_count"] = hidden
	if (selected)
		data["detail"] = recipe_data(reference, viewer, selected_group, selected_matches, selected, catalog, known)
	return data

/datum/crafting_atlas_presenter/tgui/proc/model(datum/crafting_atlas_reference/reference, mob/viewer, query = "", page = 1, resource_id = "", legacy = FALSE, era = "", processor = "", recipe_id = "", scope = "")
	query = copytext("[query]", 1, 65)
	page = max(1, min(10000, round(page)))
	var/catalog = crafting_catalog_key(viewer)
	var/list/known = list()
	var/list/data = list("query" = html_encode(query), "page" = page, "mode" = legacy ? "page" : "graph", "era" = era, "processor" = processor, "scope" = scope, "map_era" = map ? map.ordinal_age : null, "recipes" = list(), "resources" = list(), "entries" = list(), "detail" = null, "guidance" = null, "recipe_count" = 0, "resource_count" = 0, "hidden_count" = 0, "previous" = FALSE, "next" = FALSE)
	if (legacy)
		if (resource_id)
			data["guidance"] = guidance_data(reference, viewer, resource_id)
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
			entries += list(recipe_data(reference, viewer, group, matches, recipe, catalog, known))
		data["entries"] = entries
		data["recipe_count"] = matched
		data["previous"] = page > 1
		data["next"] = matched > first + 11
		return data
	if (resource_id)
		return resource_model(reference, viewer, data, resource_id, recipe_id, catalog, scope, known)
	var/list/words = search_words(reference, query)
	var/list/resource_matches = search_resources(reference, words)
	var/list/resource_rows = list()
	for (var/id in resource_matches)
		if (resource_rows.len >= 150)
			break
		var/list/view = resource_view(reference, viewer, list("id" = id, "name" = id, "quantity" = ""))
		resource_rows += list(list("id" = id, "name" = view["name"], "image" = view["image"]))
	data["resources"] = resource_rows
	data["resource_count"] = resource_matches.len
	// Recipes whose own name matches come first, then ingredient and note matches.
	var/phrase = jointext(words, " ")
	var/list/exact = list()
	var/list/named = list()
	var/list/other = list()
	var/list/family_members = list()
	var/selected_family
	var/matched = 0
	var/recipe_matches = 0
	var/hidden = 0
	for (var/list/recipe in reference.recipes)
		var/list/matches = search_variants(reference, recipe, words)
		if (!matches.len)
			continue
		if (processor && recipe["processor"] != processor)
			continue
		if (!era_allows(recipe, era))
			continue
		matches = catalog_matches(matches, catalog, scope)
		if (!matches.len)
			hidden++
			continue
		recipe_matches++
		var/family = recipe["family_id"] ? recipe["family_id"] : "recipe_[recipe["id"]]"
		var/list/members = family_members[family]
		if (!islist(members))
			matched++
			members = list()
			family_members[family] = members
			var/recipe_name = reference.search_text("[recipe["name"]]")
			if (words.len && recipe_name == phrase)
				exact += family
			else if (words.len && all_words(recipe_name, words))
				named += family
			else
				other += family
		members += list(list("group" = recipe, "matches" = matches))
		for (var/list/variant in matches)
			if (recipe_id && variant["id"] == recipe_id)
				selected_family = family
	var/list/order = exact + named + other
	if (!selected_family && order.len)
		selected_family = order[1]
	var/list/index = list()
	for (var/family in order)
		// The index is bounded; a selected recipe past the bound stays listed.
		if (index.len >= 150 && family != selected_family)
			continue
		var/list/members = family_members[family]
		var/list/row
		for (var/list/member in members)
			var/list/group = member["group"]
			var/list/matches = member["matches"]
			var/list/choice = reference.variant_record(group, matches, recipe_id)
			var/list/entry = row_data(reference, viewer, group, choice, catalog, matches, known)
			if (!row)
				row = entry
				row["family_id"] = family
				row["variant_count"] = 0
			else
				// Families may mix researched and unresearched routes. Grey the
				// family only when every matching route is out of reach.
				if (!entry["manual_hint"])
					row["manual_hint"] = ""
				else if (row["manual_hint"] && row["manual_hint"] != entry["manual_hint"])
					row["manual_hint"] = "Needs a manual; select a variant for details"
				if (row["research"] == "needed")
					row["research"] = entry["research"]
				if (!entry["retired"])
					row["retired"] = FALSE
				if (!entry["elsewhere"])
					row["elsewhere"] = FALSE
				if (row["era_label"] != entry["era_label"])
					row["era_label"] = "Multiple unlock eras"
				if (row["needs"] != entry["needs"])
					row["needs"] = ""
			row["variant_count"]++
			if (choice["id"] == recipe_id)
				row["id"] = choice["id"]
		index += list(row)
	data["recipes"] = index
	data["recipe_count"] = recipe_matches
	data["family_count"] = matched
	data["hidden_count"] = hidden
	if (selected_family)
		var/list/members = family_members[selected_family]
		var/list/chosen_member = members[1]
		for (var/list/member in members)
			for (var/list/variant in member["matches"])
				if (recipe_id && variant["id"] == recipe_id)
					chosen_member = member
		var/list/selected_group = chosen_member["group"]
		var/list/selected_matches = chosen_member["matches"]
		var/list/selected = reference.variant_record(selected_group, selected_matches, recipe_id)
		var/list/detail = recipe_data(reference, viewer, selected_group, selected_matches, selected, catalog, known)
		if (members.len > 1)
			detail["family_variants"] = family_variants(reference, viewer, members, selected["id"], catalog, known)
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
	if (is_research_essential_recipe(result_path))
		return ""
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
			ui.push_data(crafting_atlas_tgui_presenter.model(arglist(arguments + ui.scope)), TRUE)
	var/obj/item/stack/stack = using_object
	if (istype(stack) && stack.loc == src && item_is_in_hands(stack))
		stack.list_recipes(src)

/datum/crafting_atlas_presenter/tgui/manual_hint(mob/viewer, list/recipe)
	// Route metadata explicitly excludes reactions/acquisition and true basics.
	if (recipe["research_status"] != "gated")
		return ""
	// Research benches, desks and node prototypes never need a manual.
	if (recipe["manual_free"])
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
