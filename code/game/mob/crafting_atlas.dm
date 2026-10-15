// Read-only recipe graph. Bounded index and explicit legacy pages, no item constructors.
var/global/datum/crafting_atlas_reference/crafting_atlas_reference = new

/client
	var/atlas_last_request = -100

/mob/verb/crafting_atlas()
	set name = "Crafting Atlas"
	set category = "IC"
	if (client)
		crafting_atlas_reference.show(src)

/obj/structure/sawmill/verb/processing_reference()
	set name = "Processing Reference"
	set category = "IC"
	set src in view(1)
	crafting_atlas_reference.show(usr, processor = "sawmill")

/obj/structure/mill/verb/processing_reference()
	set name = "Processing Reference"
	set category = "IC"
	set src in view(1)
	crafting_atlas_reference.show(usr, processor = "grain_mill")

/datum/crafting_atlas_reference
	var/list/catalog
	var/list/recipes
	var/list/resources
	var/load_attempted = FALSE

/datum/crafting_atlas_reference/proc/load_catalog()
	if (load_attempted)
		return islist(recipes) && islist(resources)
	load_attempted = TRUE
	var/raw = file2text('UI/crafting-atlas.json')
	if (!raw)
		return FALSE
	try
		catalog = json_decode(raw)
	catch
		return FALSE
	if (!islist(catalog))
		return FALSE
	recipes = catalog["recipes"]
	resources = catalog["resources"]
	if (!islist(recipes) || !islist(resources))
		return FALSE
	for (var/list/recipe in recipes)
		var/searchable = "[recipe["name"]] [recipe["kind"]] [recipe["conditions"]] [recipe["era_basis"]]"
		for (var/list/ingredient in recipe["inputs"])
			searchable += " [ingredient["name"]] [ingredient["id"]]"
		for (var/list/product in recipe["outputs"])
			searchable += " [product["name"]] [product["id"]]"
		recipe["searchable"] = searchable
	return TRUE

/datum/crafting_atlas_reference/proc/resource_html(mob/viewer, list/resource)
	var/id = resource["id"]
	var/label = html_encode("[resource["name"]]")
	var/quantity = html_encode("[resource["quantity"]]")
	var/list/image_data = resources[id]
	var/image_html = ""
	if (islist(image_data))
		var/typepath = text2path(image_data["type"])
		var/source_symbol = !ispath(typepath, /atom)
		if (!ispath(typepath, /atom))
			typepath = /obj/item/weapon/paper
		if (ispath(typepath, /atom))
			var/atom/prototype = typepath
			var/icon_file = initial(prototype.icon)
			var/state = initial(prototype.icon_state)
			if (image_data["state"])
				state = image_data["state"]
			var/preview_label = "Inherited default; material coloring and overlays can differ."
			if (source_symbol || !icon_file || !(state in icon_states(icon_file)))
				var/atom/paper_type = /obj/item/weapon/paper
				icon_file = initial(paper_type.icon)
				state = initial(paper_type.icon_state)
				preview_label = "Source symbol; this resource has an abstract or dynamic appearance."
			if (icon_file && (state in icon_states(icon_file)))
				var/icon/preview = icon(icon_file, state, initial(prototype.dir), 1)
				var/filename = "atlas_[md5("[id]")].png"
				viewer << browse_rsc(preview, filename)
				image_html = "<img src='[filename]' width='32' height='32' alt='[label]' title='[preview_label]'> "
	return "[image_html]<a href='?src=\ref[src];atlas_resource=[url_encode(id)]'>[label]</a> ([quantity])"

/datum/crafting_atlas_reference/proc/page_html(mob/viewer, query = "", page = 1)
	query = copytext("[query]", 1, 65)
	page = max(1, min(10000, round(page)))
	var/first = (page - 1) * 12 + 1
	var/matched = 0
	var/shown = 0
	var/list/body = list()
	for (var/list/recipe in recipes)
		var/searchable = recipe["searchable"]
		if (query && !findtext(searchable, query))
			continue
		matched++
		if (matched < first || shown >= 12)
			continue
		shown++
		body += "<h3>[html_encode("[recipe["name"]]")]</h3><p>[html_encode("[recipe["kind"]]")]</p><p>Inputs: "
		var/list/inputs = list()
		for (var/list/ingredient in recipe["inputs"])
			inputs += resource_html(viewer, ingredient)
		body += jointext(inputs, "; ")
		body += "</p><p>Produces: "
		var/list/outputs = list()
		for (var/list/product in recipe["outputs"])
			outputs += resource_html(viewer, product)
		body += jointext(outputs, "; ")
		body += "</p><p>[html_encode("[recipe["conditions"]]")]</p><hr>"
	var/navigation = "<a href='?src=\ref[src];atlas_search=1'>Search</a> | <a href='?src=\ref[src];atlas_page=1'>All recipes</a>"
	if (page > 1)
		navigation += " | <a href='?src=\ref[src];atlas_page=[page-1];atlas_query=[url_encode(query)]'>Previous</a>"
	if (matched > first + 11)
		navigation += " | <a href='?src=\ref[src];atlas_page=[page+1];atlas_query=[url_encode(query)]'>Next</a>"
	return "<html><head><title>Crafting Atlas</title></head><body><h2>Crafting Atlas</h2><p><a href='?src=\ref[src];atlas_open=1'>Return to dependency atlas</a> | Legacy paginated list</p><p>[navigation]</p><p>[matched] matching recipes. Page [page]. Map, research, tools and other requirements still apply; alternative catalogs are included.</p>[jointext(body, "")]<p><a href='https://civ13.github.io/Civ13/crafting/'>Open the full resource graph</a></p></body></html>"

/datum/crafting_atlas_reference/proc/graph_html(mob/viewer, query = "", era = "", processor = "", recipe_id = "")
	query = copytext("[query]", 1, 65)
	var/list/index = list()
	var/list/selected
	var/matched = 0
	for (var/list/recipe in recipes)
		if (query && !findtext(recipe["searchable"], query))
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
		else if (era && (!islist(eras) || !(text2num(era) in eras)))
			continue
		matched++
		if (!selected || recipe["id"] == recipe_id)
			selected = recipe
		if (matched <= 150)
			index += "<p><a href='?src=\ref[src];atlas_open=1;atlas_recipe=[url_encode("[recipe["id"]]")];atlas_query=[url_encode(query)];atlas_era=[url_encode(era)];atlas_processor=[url_encode(processor)]'>[html_encode("[recipe["name"]]")]</a><br><small>[html_encode("[recipe["era_label"]]")]</small></p>"
	var/list/era_names = list("0: Stone Age", "1: Bronze Age", "2: Middle Ages", "3: Imperial Age", "4: Industrial Age", "5: Early Modern Age", "6: WW2", "7: Cold War", "8: Modern Age")
	var/query_html = replacetext(html_encode(query), "'", "&#39;")
	var/controls = "<form action='byond://?' method='get'><input type='hidden' name='src' value='\ref[src]'><input type='hidden' name='atlas_open' value='1'><input name='atlas_query' maxlength='64' value='[query_html]' aria-label='Search'><select name='atlas_era' aria-label='Unlock era'><option value=''>All unlock eras</option>"
	for (var/i in 1 to era_names.len)
		controls += "<option value='[i-1]'[era == "[i-1]" ? " selected" : ""]>[era_names[i]]</option>"
	controls += "<option value='multiple'[era == "multiple" ? " selected" : ""]>Multiple eras</option><option value='unknown'[era == "unknown" ? " selected" : ""]>Unknown / context dependent</option></select><select name='atlas_processor' aria-label='Processor'><option value=''>All processors and recipes</option><option value='sawmill'[processor == "sawmill" ? " selected" : ""]>Sawmills</option><option value='grain_mill'[processor == "grain_mill" ? " selected" : ""]>Grain mills</option></select><input type='submit' value='Filter'></form>"
	var/diagram = "<p>No matching recipes. Clear filters or search for an ingredient.</p>"
	if (selected)
		var/list/inputs = list()
		var/list/outputs = list()
		for (var/list/ingredient in selected["inputs"])
			inputs += "<p>[resource_html(viewer, ingredient)]</p>"
		for (var/list/product in selected["outputs"])
			outputs += "<p>[resource_html(viewer, product)]</p>"
		diagram = "<h3>[html_encode("[selected["name"]]")]</h3><table class='dependency' width='100%'><tr><th>Inputs</th><th></th><th>Transformation</th><th></th><th>Outputs</th></tr><tr><td bgcolor='#254a35'>[jointext(inputs, "")]</td><td>&rarr;</td><td bgcolor='#254366'>[html_encode("[selected["kind"]]")]</td><td>&rarr;</td><td bgcolor='#5b4824'>[jointext(outputs, "")]</td></tr></table><p>Unlock era: [html_encode("[selected["era_label"]]")]. [html_encode("[selected["era_basis"]]")]</p><p>[html_encode("[selected["conditions"]]")]</p>"
	return "<html><head><title>Crafting Atlas</title><style>body{background:#17202b;color:#eee;font-family:Verdana;font-size:13px}a{color:#9ed2ff}td{padding:8px;vertical-align:top}input,select{margin:4px}small{color:#c4d2e2}</style></head><body><h2>Crafting Atlas</h2>[controls]<p>[matched] matching recipes, sorted by unlock era. Research tiers can be ahead of map era; unknown and multiple-era records remain explicit. Map, faction, skills and other conditions still apply.</p><table width='100%'><tr><td width='26%'>[jointext(index, "")][matched > 150 ? "<p>First 150 matches shown. Refine filters to find more.</p>" : ""]</td><td>[diagram]</td></tr></table><p><a href='?src=\ref[src];atlas_open=1'>Reset atlas</a> | <a href='?src=\ref[src];atlas_page=1'>Legacy paginated list</a> | <a href='https://civ13.github.io/Civ13/crafting/'>Full web atlas</a></p></body></html>"

/datum/crafting_atlas_reference/proc/acquisition_html(resource_id)
	var/list/all_routes = catalog["acquisition"]
	var/list/routes = islist(all_routes) ? all_routes[resource_id] : null
	var/list/resource_data = resources[resource_id]
	var/resource_name = islist(resource_data) && resource_data["name"] ? resource_data["name"] : resource_id
	var/list/body = list("<h2>How to obtain [html_encode(resource_name)]</h2>")
	if (!islist(routes) || !routes.len)
		body += "<p>No reviewed gathering instructions for this resource. Producer recipes below may provide processing routes; their requirements still apply.</p>"
	else
		var/shown = 0
		for (var/list/route in routes)
			if (++shown > 12)
				body += "<p>More routes are available in the full web atlas.</p>"
				break
			body += "<h3>[html_encode("[route["name"]]")]</h3>"
			for (var/key in list("steps", "tools", "conditions", "era", "map_notes", "status"))
				var/value = route[key]
				if (islist(value))
					value = jointext(value, "; ")
				if (value)
					body += "<p>[html_encode(key)]: [html_encode("[value]")]</p>"
			for (var/field in list("inputs", "outputs"))
				var/list/related = route[field]
				if (!islist(related))
					continue
				var/list/links = list()
				for (var/id in related)
					var/list/details = resources[id]
					var/name = islist(details) && details["name"] ? details["name"] : id
					links += "<a href='?src=\ref[src];atlas_resource=[url_encode(id)]'>[html_encode(name)]</a>"
				var/heading = field == "inputs" ? "Needs" : "Can provide (conditional)"
				body += "<p>[heading]: [jointext(links, "; ")]</p>"
			if (route["file"] && route["audit_commit"])
				body += "<p><a href='https://github.com/Civ13/Civ13/blob/[html_encode("[route["audit_commit"]]")]/[html_encode("[route["file"]]")]#L[route["line"]]'>Reviewed source</a></p>"
	return jointext(body, "")

/datum/crafting_atlas_reference/proc/show(mob/viewer, query = "", page = 1, resource_id = "", legacy = FALSE, era = "", processor = "", recipe_id = "")
	if (!viewer || !viewer.client)
		return
	if (world.time < viewer.client.atlas_last_request + 10)
		return
	viewer.client.atlas_last_request = world.time
	if (!load_catalog())
		to_chat(viewer, "The crafting reference is unavailable in this build.")
		return
	viewer << browse(render_html(viewer, query, page, resource_id, legacy, era, processor, recipe_id), "window=crafting_atlas;size=1000x700")

/datum/crafting_atlas_reference/proc/render_html(mob/viewer, query = "", page = 1, resource_id = "", legacy = FALSE, era = "", processor = "", recipe_id = "")
	var/content = legacy ? page_html(viewer, query, page) : graph_html(viewer, query, era, processor, recipe_id)
	if (resource_id)
		content = replacetext(content, "<h2>Crafting Atlas</h2>", acquisition_html(resource_id))
	return content

/datum/crafting_atlas_reference/proc/resource_exists(resource_id)
	if (!load_catalog())
		return FALSE
	return islist(resources[resource_id])

/datum/crafting_atlas_reference/Topic(href, list/href_list)
	if (!usr || !usr.client)
		return
	var/mob/viewer = usr
	if (href_list["atlas_resource"])
		var/resource_id = copytext("[href_list["atlas_resource"]]", 1, 257)
		if (resource_exists(resource_id))
			show(viewer, resource_id, 1, resource_id)
	else if (href_list["atlas_search"])
		var/query = input(viewer, "Find a recipe, ingredient or product", "Crafting Atlas") as text|null
		if (!isnull(query))
			show(viewer, query)
	else if (href_list["atlas_page"])
		show(viewer, href_list["atlas_query"], text2num(href_list["atlas_page"]), legacy = TRUE)
	else if (href_list["atlas_open"])
		show(viewer, href_list["atlas_query"], era = copytext("[href_list["atlas_era"]]", 1, 16), processor = copytext("[href_list["atlas_processor"]]", 1, 32), recipe_id = copytext("[href_list["atlas_recipe"]]", 1, 32))
