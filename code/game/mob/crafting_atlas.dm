// Read-only recipe reference. One shared catalog, bounded browser pages, no item constructors.
var/global/datum/crafting_atlas_reference/crafting_atlas_reference = new

/client
	var/atlas_last_request = -100

/mob/verb/crafting_atlas()
	set name = "Crafting Atlas"
	set category = "IC"
	if (client)
		crafting_atlas_reference.show(src)

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
		var/searchable = "[recipe["name"]] [recipe["kind"]]"
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
	return "<html><head><title>Crafting Atlas</title></head><body><h2>Crafting Atlas</h2><p>[navigation]</p><p>[matched] matching recipes. Page [page]. Map, research, tools and other requirements still apply; alternative catalogs are included.</p>[jointext(body, "")]<p><a href='https://civ13.github.io/Civ13/crafting/'>Open the full resource graph</a></p></body></html>"

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

/datum/crafting_atlas_reference/proc/show(mob/viewer, query = "", page = 1, resource_id = "")
	if (!viewer || !viewer.client)
		return
	if (world.time < viewer.client.atlas_last_request + 10)
		return
	viewer.client.atlas_last_request = world.time
	if (!load_catalog())
		to_chat(viewer, "The crafting reference is unavailable in this build.")
		return
	var/content = page_html(viewer, query, page)
	if (resource_id)
		content = replacetext(content, "<h2>Crafting Atlas</h2>", acquisition_html(resource_id))
	viewer << browse(content, "window=crafting_atlas;size=850x650")

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
		show(viewer, href_list["atlas_query"], text2num(href_list["atlas_page"]))
