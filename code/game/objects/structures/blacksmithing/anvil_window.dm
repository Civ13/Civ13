// The Crafting window at an anvil: everything the sheet metal in hand makes
// here, in one list, instead of a kind menu followed by an item menu.
//
// Presentation and request routing only. A craft request goes back through
// the anvil's own attackby(), so its skill, job and material checks run again,
// and forge_stack_recipe() / produce_blackpowder_part() still own the wait,
// the re-checks after it and the payment. Molds and tool work keep their menus.

/datum/crafting_window/anvil
	var/obj/structure/anvil/anvil
	// The row a craft request named, for the anvil to pick up inside attackby().
	var/pending

/datum/crafting_window/anvil/New(mob/living/human/H, obj/item/stack/S, obj/structure/anvil/A)
	..(H, S)
	anvil = A

/datum/crafting_window/anvil/closed()
	..()
	anvil = null
	pending = null

/datum/crafting_window/anvil/still_valid(mob/living/human/H)
	if (!H || H != viewer || QDELETED(H) || !H.client)
		return FALSE
	if (QDELETED(source) || source.amount <= 0 || QDELETED(anvil))
		return FALSE
	return source.loc == H && H.get_active_hand() == source && isturf(H.loc) && in_range(anvil, H)

// The anvil's rows are a fixed table, not the stack's own recipe lists.
/datum/crafting_window/anvil/load_recipes()
	return

/datum/crafting_window/anvil/detail_for(id)
	return null

// A short id for a recipe name, safe to send to the window and back.
/proc/anvil_window_row_id(recipe_name)
	return copytext(md5("anvil|[recipe_name]"), 1, 17)

// The recipe names this anvil offers this character for the sheet metal in
// hand, in table order: the same rows the kind and item menus would list.
/obj/structure/anvil/proc/stack_offers(obj/item/P, mob/living/human/H)
	var/list/found = list()
	var/list/metal = stack_metal(P)
	var/list/kinds = stack_categories(P, H)
	if (!metal || !kinds)
		return found
	var/list/parts = list()
	if ("flintlock parts" in kinds)
		for (var/entry in blackpowder_part_options(P, H))
			var/list/parsed = splittext(entry, " - ")
			parts += parsed[1]
	for (var/key in anvil_recipes)
		var/list/R = anvil_recipes[key]
		if (!R)
			continue
		if (R[2] == "flintlock parts")
			if (key in parts)
				found += key
		else if ((R[2] in kinds) && anvil_recipe_offered(R, R[2], R[metal[1]], metal[2]))
			found += key
	return found

// What Pinned and Recent remember for an anvil row: the metal and the recipe.
/datum/crafting_window/anvil/proc/row_key(recipe_name)
	var/list/metal = anvil.stack_metal(source)
	return md5("anvil|[metal ? metal[2] : ""]|[recipe_name]")

// The recipe name a row id stands for among the rows offered right now, or null.
/datum/crafting_window/anvil/proc/offered_name(id)
	if (!istext(id) || length(id) > 32)
		return null
	for (var/key in anvil.stack_offers(source, viewer))
		if (anvil_window_row_id(key) == id)
			return key
	return null

// Resolve exactly the offered variant, not the first producer for its output.
/datum/crafting_atlas_reference/proc/anvil_variant_id(recipe_name, material, cost, product)
	if (!load_catalog())
		return ""
	var/display_name = "[recipe_name] \[[material]\]"
	var/ingredient_id = "/material/[material]"
	for (var/list/group in recipes)
		if (group["kind"] != "Anvil")
			continue
		var/list/variants = group["variants"]
		if (!islist(variants))
			variants = list(group)
		for (var/list/recipe in variants)
			if (recipe["kind"] != "Anvil" || recipe["name"] != display_name)
				continue
			var/list/inputs = recipe["inputs"]
			var/list/outputs = recipe["outputs"]
			if (length(inputs) != 1 || length(outputs) != 1)
				continue
			var/list/ingredient = inputs[1]
			var/list/output = outputs[1]
			if (ingredient["id"] == ingredient_id && text2num("[ingredient["quantity"]]") == cost && output["id"] == product)
				return recipe["id"]
	return ""

/datum/crafting_window/anvil/build_data()
	var/obj/item/stack/S = source
	var/list/rows = list()
	var/list/budget = list(60, FALSE)
	var/list/pinned = pinned_keys()
	var/list/recent = viewer.client ? viewer.client.craft_recent : null
	var/list/metal = anvil.stack_metal(S)
	var/list/assist_cache = list()
	for (var/key in anvil.stack_offers(S, viewer))
		var/list/R = anvil_recipes[key]
		var/cost = R[metal[1]]
		var/result = "[R[9]]"
		var/row_state = "ready"
		var/why = ""
		var/hint = ""
		if (!crafting_recipe_allowed(viewer, result))
			row_state = "locked"
			hint = crafting_recipe_manual_hint(viewer, result)
			why = hint || "Not learned yet"
		else if (S.amount < cost)
			row_state = "missing"
			why = "Needs [cost] [metal[2]], you have [S.amount]"
		var/atom/prototype = R[9]
		var/pin_key = row_key(key)
		rows += list(list(
			"id" = anvil_window_row_id(key),
			"name" = html_encode("[key]"),
			"category" = html_encode(capitalize("[R[2]]")),
			"purpose" = html_encode(crafting_purpose(R[9], R[2])),
			"pinned" = pinned.Find(pin_key) ? 1 : 0,
			"recent" = recent ? recent.Find(pin_key) : 0,
			"cost" = html_encode("[cost] [metal[2]]"),
			"state" = row_state,
			"why" = html_encode(why),
			"tools" = "",
			"desc" = html_encode(ispath(R[9], /atom) ? "[initial(prototype.desc)]" : ""),
			"built" = 0,
			"one_per_turf" = 0,
			"on_floor" = 0,
			"time" = anvil.stack_forge_duration(viewer, viewer, R, cost, TRUE, assist_cache),
			"tech_tree" = hint && tech_tree_view ? 1 : 0,
			"makes" = 1,
			"batches" = S.amount >= cost ? 1 : 0,
			"atlas" = (crafting_atlas_reference && crafting_atlas_reference.resource_exists(result)) ? 1 : 0,
			"image" = product_image(R[9], budget)))
	return list(
		"focus" = "",
		"focus_seq" = 0,
		"reach" = 0,
		"sources" = list(),
		"where" = "in your hand",
		"station" = html_encode("[anvil.name]"),
		"material" = html_encode("[S.name]"),
		"unit" = html_encode("[S.singular_name]"),
		"amount" = S.amount,
		"image" = product_image(S.type, budget),
		"makeable_only" = viewer.craft_makeable_only() ? 1 : 0,
		"purposes" = islist(crafting_purpose_rules) && islist(crafting_purpose_rules["order"]) ? crafting_purpose_rules["order"] : list("Other"),
		"rows" = rows,
		"more_images" = budget[2] ? 1 : 0)

/datum/crafting_window/anvil/Topic(href, href_list, state)
	var/mob/living/human/H = usr
	if (!istype(H) || !still_valid(H) || H.stat || H.restrained())
		return FALSE
	if (!isnull(href_list["makeable_only"]) || href_list["images"])
		return ..()
	if (href_list["atlas"])
		var/shown = offered_name(href_list["atlas"])
		var/list/metal = anvil.stack_metal(source)
		if (shown && metal)
			var/list/R = anvil_recipes[shown]
			var/product = "[R[9]]"
			if (crafting_atlas_reference && crafting_atlas_reference.resource_exists(product))
				var/recipe = crafting_atlas_reference.anvil_variant_id(shown, metal[2], R[metal[1]], product)
				crafting_atlas_reference.show(H, product, 1, product, recipe_id = recipe)
		return FALSE
	if (href_list["tech_tree"])
		var/gated = offered_name(href_list["tech_tree"])
		if (gated && tech_tree_view)
			var/list/R = anvil_recipes[gated]
			var/product = "[R[9]]"
			if (crafting_recipe_manual_hint(H, product))
				tech_tree_view.show(H, get_recipe_node_req(product))
		return FALSE
	if (href_list["pin"])
		var/marked = offered_name(href_list["pin"])
		var/datum/preferences/P = H.client.prefs
		if (!marked || !P || working)
			return FALSE
		var/list/pinned = pinned_keys()
		var/pin_key = row_key(marked)
		if (pinned.Find(pin_key))
			pinned -= pin_key
		else if (pinned.len < 60)
			pinned += pin_key
		else
			to_chat(H, "<span class='warning'>You can pin up to 60 recipes. Unpin one first.</span>")
			return FALSE
		P.save_preferences()
		if (cached)
			for (var/list/row in cached["rows"])
				if (row["id"] == href_list["pin"])
					row["pinned"] = pinned.Find(pin_key) ? 1 : 0
			push_cached()
		return FALSE
	if (href_list["make"])
		if (working || anvil.in_use)
			return FALSE
		var/wanted = offered_name(href_list["make"])
		var/list/metal = anvil.stack_metal(source)
		var/list/R = wanted ? anvil_recipes[wanted] : null
		if (!R || !metal || source.amount < R[metal[1]])
			// The list changed under the window: show the current one.
			refresh()
			return FALSE
		var/obj/item/stack/S = source
		var/obj/structure/anvil/A = anvil
		var/held_before = S.amount
		var/recent_key = row_key(wanted)
		// Reserve the window now; only an admitted forge may start its timer.
		working = list("id" = href_list["make"], "name" = html_encode("[wanted]"))
		// The anvil admits the smith again and picks the row up from here.
		pending = wanted
		A.attackby(S, H)
		pending = null
		working = null
		if (H.client && (QDELETED(S) || S.amount < held_before))
			if (!islist(H.client.craft_recent))
				H.client.craft_recent = list()
			H.client.craft_recent -= recent_key
			H.client.craft_recent.Insert(1, recent_key)
			if (H.client.craft_recent.len > 30)
				H.client.craft_recent.len = 30
		if (viewer == H && source == S)
			refresh()
		return FALSE
	return FALSE

// Show the actual duration the accepted job is just about to request.
/obj/structure/anvil/proc/show_stack_forge_progress(mob/living/human/H, delay)
	var/datum/crafting_window/anvil/W = H ? H.crafting_window : null
	if (istype(W) && W.anvil == src && W.working && !W.pending && W.still_valid(H))
		W.working["time"] = delay
		GLOB.nanomanager.update_uis(W)

// TRUE when the Crafting window took this use of a sheet metal on the anvil:
// either it opened, or it had asked for a row and the row was worked here.
// FALSE sends attackby() on to the pop-up menus.
/obj/structure/anvil/proc/anvil_window_shown(obj/item/P, mob/living/human/H)
	if (!istype(H) || !stack_metal(P))
		return FALSE
	var/datum/crafting_window/anvil/W = H.crafting_window
	if (istype(W) && W.anvil == src && W.source == P && W.pending)
		var/wanted = W.pending
		W.pending = null
		// Offered is checked again here, after attackby() admitted the smith.
		if (!(wanted in stack_offers(P, H)))
			return TRUE
		var/list/R = anvil_recipes[wanted]
		var/list/metal = stack_metal(P)
		if (R[2] == "flintlock parts")
			produce_blackpowder_part(wanted, P, H)
		else
			forge_stack_recipe(P, H, H, R[2], metal[1], metal[2], "[wanted] - ")
		return TRUE
	if (!H.client || H.client.crafting_window_classic || H.client.modern_ui_failed)
		return FALSE
	if (P.loc != H || H.get_active_hand() != P || !stack_offers(P, H).len)
		return FALSE
	var/datum/crafting_window/open = H.crafting_window
	if (open && open.working)
		// A craft is under way: leave its window as it is.
		return TRUE
	if (open && (!istype(W) || W.anvil != src || W.source != P))
		GLOB.nanomanager.close_uis(open)
		open.closed()
		W = null
	if (!istype(W) || !W.viewer)
		W = new /datum/crafting_window/anvil(H, P, src)
		H.crafting_window = W
	show_browse(H, null, "window=stack")
	W.cached = null
	W.ui_interact(H)
	return TRUE
