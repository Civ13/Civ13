// Other ways to work a held material: a tool used on it, a station it goes
// into, a liquid it soaks in. These are not menu recipes. The rows come from
// the Crafting Atlas's acquisition routes (the same "How to get it" data the
// Atlas shows), so the window and the Atlas always agree. Read only: nothing
// here makes, moves or spends anything; the player still does the work in
// the world with the tool, and that code checks everything again.

#define CRAFTING_WINDOW_PROCESSING_LIMIT 30

/datum/crafting_atlas_reference
	// Atlas resource id -> the distinct acquisition routes that take it as an input.
	var/list/processing_by_input

/datum/crafting_atlas_reference/proc/processing_routes_for(id)
	if (!load_catalog())
		return list()
	if (!processing_by_input)
		processing_by_input = list()
		var/list/acquisition = catalog["acquisition"]
		var/list/seen = list()
		if (islist(acquisition))
			// The same route is listed under each thing it makes: keep it once.
			for (var/output in acquisition)
				var/list/routes = acquisition[output]
				if (!islist(routes))
					continue
				for (var/list/route in routes)
					if (!islist(route) || !islist(route["inputs"]))
						continue
					var/key = "[route["name"]]|[route["file"]]|[route["line"]]"
					if (seen[key])
						continue
					seen[key] = TRUE
					for (var/input in route["inputs"])
						var/list/uses = processing_by_input["[input]"]
						if (!uses)
							uses = list()
							processing_by_input["[input]"] = uses
						if (!uses.len || uses[uses.len] != route)
							uses += list(route)
	var/list/found = processing_by_input["[id]"]
	return found ? found : list()

// Whether the viewer has something that fits a route's tool label, and its
// name: 1 in hand, on them or next to them; 0 when nothing fits; -1 when the
// label is a place, a condition or a long description a quick look cannot judge.
/mob/living/human/proc/crafting_tool_match(label, obj/worked)
	var/text = lowertext(trim("[label]"))
	if (copytext(text, 1, 6) == "held ")
		text = copytext(text, 6)
	var/typepath = copytext(text, 1, 2) == "/" ? text2path(text) : null
	var/sharp = findtext(text, "sharp")
	var/liquid = findtext(text, "liquid container")
	var/hammerstone = text == "hammerstone"
	// A river, lake, shallows or puddle within reach (leather.dm hide_wash_water).
	if (findtext(text, "open water"))
		for (var/atom/A in range(1, src))
			if (hide_wash_water(A))
				return list(1, A.name)
		return list(0, "")
	if (!typepath && !sharp && !liquid && !hammerstone)
		if (!length(text) || length(text) > 24 || findtext(text, ",") || findtext(text, "(") || findtext(text, ";") || findtext(text, "/") || splittext(text, " ").len > 2)
			return list(-1, "")
		if (text in list("modern", "fishing", "water", "clay", "branch", "glass", "net"))
			return list(-1, "")
	var/list/candidates = list()
	for (var/obj/item/I in list(get_active_hand(), get_inactive_hand()))
		candidates += I
	for (var/obj/item/I in get_contents())
		candidates |= I
	for (var/obj/O in range(1, src))
		candidates |= O
	// The material being worked is never its own tool (a flint is no hammerstone for itself).
	candidates -= worked
	var/underscored = replacetext(text, " ", "_")
	var/joined = replacetext(text, " ", "")
	for (var/obj/O in candidates)
		if (QDELETED(O))
			continue
		if (typepath)
			if (istype(O, typepath))
				return list(1, O.name)
			continue
		if (sharp)
			var/obj/item/I = O
			if (istype(I) && I.sharp && !istype(I, /obj/item/weapon/reagent_containers))
				return list(1, O.name)
			continue
		if (liquid)
			if (O.reagents && O.tanning_liquid_accessible())
				return list(1, O.name)
			continue
		if (hammerstone)
			if (istype(O, /obj/item) && obsidian_is_hammerstone(O))
				return list(1, O.name)
			continue
		// Whole words of the name, or one segment of the type path, so "net"
		// never matches a bayonet and a hand axe still counts as a hatchet.
		if (findtext(" [lowertext(O.name)] ", " [text] "))
			return list(1, O.name)
		var/list/segments = splittext("[O.type]", "/")
		if ((underscored in segments) || (joined in segments))
			return list(1, O.name)
	return list(0, "")

// Processing rows for the held material, and the row id -> Atlas page links
// the window may open. Returns list(rows, total) so the screen can say how many
// more the Atlas lists.
/datum/crafting_window/proc/processing_data(obj/item/stack/S, list/budget)
	var/list/rows = list()
	processing_links = list()
	if (!crafting_atlas_reference || !S)
		return list(rows, 0)
	var/list/ids = list()
	var/own = S.atlas_resource_id()
	if (own)
		ids += "[own]"
	ids |= "[S.type]"
	var/list/seen = list()
	var/total = 0
	for (var/id in ids)
		for (var/list/route in crafting_atlas_reference.processing_routes_for(id))
			var/key = "[route["name"]]|[route["file"]]|[route["line"]]"
			if (seen[key])
				continue
			seen[key] = TRUE
			if (++total > CRAFTING_WINDOW_PROCESSING_LIMIT)
				continue
			rows += list(processing_row(route, "p[total]", budget))
	return list(rows, total)

/datum/crafting_window/proc/processing_row(list/route, row_id, list/budget)
	var/list/resources = crafting_atlas_reference.resources
	var/list/makes = list()
	var/image = ""
	var/link = ""
	for (var/output in route["outputs"])
		var/list/resource = resources["[output]"]
		var/label = "[output]"
		if (islist(resource))
			label = resource["title"] ? "[resource["title"]]" : (resource["name"] ? "[resource["name"]]" : label)
			if (!image)
				image = product_image(text2path("[resource["type"]]"), budget)
			if (!link)
				link = "[output]"
		if (makes.len < 6)
			makes += html_encode(label)
	var/list/tools = list()
	var/ready = TRUE
	for (var/label in route["tools"])
		if (tools.len >= 4)
			break
		var/list/match = viewer.crafting_tool_match(label, source)
		var/name = "[label]"
		if (copytext(name, 1, 2) == "/")
			var/list/resource = resources[name]
			name = islist(resource) && resource["name"] ? "[resource["name"]]" : name
		else if (lowertext(copytext(name, 1, 6)) == "held ")
			name = copytext(name, 6)
		if (match[1] == 0)
			ready = FALSE
		tools += list(list("name" = html_encode(name), "have" = match[1], "found" = html_encode("[match[2]]")))
	var/list/steps = list()
	for (var/step in route["steps"])
		if (steps.len < 6)
			steps += html_encode("[step]")
	if (!steps.len && route["conditions"])
		steps += html_encode("[route["conditions"]]")
	if (link)
		processing_links[row_id] = link
	return list(
		"id" = row_id,
		"name" = html_encode("[route["name"]]"),
		"makes" = makes,
		"tools" = tools,
		"steps" = steps,
		"state" = ready ? "ready" : "missing",
		"atlas" = link ? 1 : 0,
		"image" = image)

#undef CRAFTING_WINDOW_PROCESSING_LIMIT
