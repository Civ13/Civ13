// The Crafting window: the modern presentation of a held stack's recipes.
//
// Presentation and request routing only. Every craft still runs through
// produce_recipe(), which owns research, skill, tool, place and payment checks.
// A row id names a recipe by its position in the stack's own recipe lists plus
// a short digest of its title and product, so a request made against a list
// that has since changed is refused instead of crafting a neighbouring row.
//
// The classic HTML list in list_recipes() stays as the fallback for clients
// whose browser cannot run the modern window, and for agent characters.

#define CRAFTING_WINDOW_ICONS_PER_PUSH 60

/client
	// Set once this client's browser fell back, or the player asked for the classic list.
	var/tmp/crafting_window_classic = FALSE
	// Product type path -> preview file already sent to this client ("-" = no picture).
	var/tmp/list/craft_icon_cache

/mob/living/human/var/tmp/datum/crafting_window/crafting_window = null

/datum/crafting_window
	var/mob/living/human/viewer
	var/obj/item/stack/source
	// The craft in progress, as sent to the window: id, name and expected deciseconds.
	var/list/working
	// The last full snapshot, reused while a craft is in progress.
	var/list/cached

/datum/crafting_window/New(mob/living/human/H, obj/item/stack/S)
	viewer = H
	source = S

// The window closed: drop every reference so neither the mob nor the stack is held.
/datum/crafting_window/proc/closed()
	if (viewer)
		if (viewer.crafting_window == src)
			viewer.crafting_window = null
		if (source && viewer.using_object == source)
			viewer.unset_using_object()
	viewer = null
	source = null
	cached = null

// The same admission the classic list's Topic applies before any craft.
/datum/crafting_window/proc/still_valid(mob/living/human/H)
	if (!H || H != viewer || QDELETED(H) || !H.client)
		return FALSE
	if (QDELETED(source) || source.amount <= 0 || !source.recipes)
		return FALSE
	return source.loc == H && H.get_active_hand() == source

/datum/topic_state/crafting_window/can_use_topic(var/datum/crafting_window/W, var/mob/user)
	if (!istype(W) || !W.still_valid(user))
		return STATUS_CLOSE
	if (user.stat || user.restrained())
		return STATUS_DISABLED
	return STATUS_INTERACTIVE

/datum/nanoui/tgui/crafting_window/close()
	var/datum/crafting_window/W = src_object
	. = ..()
	if (istype(W))
		W.closed()

// A browser that cannot run the window, or a player who asked for the classic
// list, gets the retained HTML list for the rest of this connection.
/datum/nanoui/tgui/crafting_window/use_legacy_renderer()
	var/datum/crafting_window/W = src_object
	var/mob/living/human/H = user
	var/obj/item/stack/S = istype(W) ? W.source : null
	if (H && H.client)
		H.client.crafting_window_classic = TRUE
	close()
	if (istype(H) && S && !QDELETED(S) && S.loc == H && H.get_active_hand() == S)
		S.list_recipes(H)

// TRUE when the modern window took this request; FALSE sends the caller on to
// the classic list.
/obj/item/stack/proc/crafting_window_shown(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client || H.client.crafting_window_classic || H.client.modern_ui_failed)
		return FALSE
	if (loc != H || H.get_active_hand() != src)
		return FALSE
	var/datum/crafting_window/W = H.crafting_window
	if (W && W.source != src)
		GLOB.nanomanager.close_uis(W)
		W.closed()
		W = null
	if (!W)
		W = new /datum/crafting_window(H, src)
		H.crafting_window = W
	show_browse(H, null, "window=stack")
	H.set_using_object(src)
	W.cached = null
	W.ui_interact(H)
	return TRUE

/datum/crafting_window/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	if (user != viewer || !still_valid(viewer))
		return
	var/list/data = (working && cached) ? cached : build_data()
	cached = data
	data["working"] = working
	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		var/datum/topic_state/crafting_window/window_state = new()
		ui = new /datum/nanoui/tgui/crafting_window(user, src, ui_key, "crafting_window.tmpl", "Crafting", 940, 680, _state = window_state)
		ui.set_initial_data(data)
		ui.open()

// Push a fresh snapshot to the open window without reopening it.
/datum/crafting_window/proc/refresh()
	if (!viewer || !still_valid(viewer))
		return
	cached = null
	// Material stacks rebuild their list for this character, as the classic list does on opening.
	if (istype(source, /obj/item/stack/material))
		var/obj/item/stack/material/M = source
		M.recipes = M.material.get_recipes_civs(viewer)
	ui_interact(viewer, force_open = FALSE)

/proc/crafting_window_row_id(datum/stack_recipe/R, sublist, index)
	return "[sublist]:[index]:[copytext(md5("[R.title]|[R.result_type]"), 1, 9)]"

// The recipe a row id names in the stack's current lists, or null when the id
// is malformed or the list has changed since the window was drawn.
/datum/crafting_window/proc/find_recipe(id)
	if (!istext(id) || length(id) > 32 || !source || !source.recipes)
		return null
	var/list/parts = splittext(id, ":")
	if (parts.len != 3)
		return null
	var/sublist = text2num(parts[1])
	var/index = text2num(parts[2])
	if (!isnum(sublist) || !isnum(index) || sublist != round(sublist) || index != round(index) || sublist < 0 || index < 1)
		return null
	var/list/recipes_list = source.recipes
	if (sublist)
		if (sublist > recipes_list.len)
			return null
		var/datum/stack_recipe_list/srl = recipes_list[sublist]
		if (!istype(srl))
			return null
		recipes_list = srl.recipes
	if (index > recipes_list.len)
		return null
	var/datum/stack_recipe/R = recipes_list[index]
	if (!istype(R) || crafting_window_row_id(R, sublist, index) != id)
		return null
	return R

// How many batches one request may ask for, mirroring the classic list's choices.
/datum/crafting_window/proc/batch_limit(datum/stack_recipe/R)
	if (!R || R.req_amount <= 0)
		return 0
	var/limit = round(source.amount / R.req_amount)
	if (limit < 1)
		return 0
	if (R.max_res_amount > 1 && R.res_amount > 0)
		return max(1, min(limit, round(R.max_res_amount / R.res_amount)))
	return 1

// The wait produce_recipe() will apply, for the progress bar only.
/datum/crafting_window/proc/expected_time(datum/stack_recipe/R)
	var/buildtime = R.time
	if (!buildtime)
		return 0
	if (viewer.getStatCoeff("strength"))
		buildtime /= viewer.getStatCoeff("strength")
		buildtime /= (viewer.getStatCoeff("crafting") * viewer.getStatCoeff("crafting"))
	return round(buildtime)

// The preview file for a product, sent to this client once. budget is a
// one-element list counting how many new pictures this snapshot may still send.
/datum/crafting_window/proc/product_image(typepath, list/budget)
	var/client/C = viewer.client
	if (!C || !ispath(typepath, /atom))
		return ""
	if (!islist(C.craft_icon_cache))
		C.craft_icon_cache = list()
	var/key = "[typepath]"
	var/known = C.craft_icon_cache[key]
	if (known)
		return known == "-" ? "" : known
	if (budget[1] <= 0)
		budget[2] = TRUE
		return ""
	var/atom/prototype = typepath
	var/icon_file = initial(prototype.icon)
	var/state = initial(prototype.icon_state)
	if (!icon_file || !istext(state) || !length(state))
		C.craft_icon_cache[key] = "-"
		return ""
	budget[1]--
	var/filename = "craft_[md5(key)].png"
	C << browse_rsc(icon(icon_file, state, SOUTH, 1), filename)
	C.craft_icon_cache[key] = filename
	return filename

/datum/crafting_window/proc/row_data(datum/stack_recipe/R, sublist, index, category, list/budget)
	var/obj/item/stack/S = source
	var/result = "[R.result_type]"
	var/limit = batch_limit(R)
	var/manual_hint = crafting_recipe_manual_hint(viewer, result)
	var/row_state = "ready"
	var/why = ""
	if (manual_hint)
		row_state = "locked"
		why = manual_hint
	else if (limit < 1)
		row_state = "missing"
		why = "Needs [R.req_amount] [S.singular_name]\s, you have [S.amount]"
	else if (!S.recipe_makeable_now(viewer, R))
		row_state = "missing"
		var/refusal = craft_guard_refusal(viewer, R, CRAFT_GUARD_MENU)
		why = istext(refusal) ? trim(strip_html_properly(refusal)) : ""
		if (!why)
			why = "Missing a tool, skill or second material"
	var/cost = "[R.req_amount] [S.singular_name]\s"
	var/tools = ""
	var/list/joint_spec = furniture_joinery_spec(R)
	if (stone_mold_type(R.result_type))
		tools = "Chisel and hammer/mallet equipped or at your feet; no firing needed."
	if (joint_spec)
		if (joint_spec["component_cost"])
			cost += " + [joint_spec["component_cost"]] wooden dowel set(s)"
			tools = "Chisel and hammer/mallet equipped or at your feet."
		else
			tools = "Sharpened flint or a sharp knife harder than the plank equipped or at your feet."
	var/atom/prototype = R.result_type
	var/built = ispath(R.result_type, /obj/structure) || ispath(R.result_type, /obj/covers) || ispath(R.result_type, /turf)
	return list(
		"id" = crafting_window_row_id(R, sublist, index),
		"name" = html_encode(R.res_amount > 1 ? "[R.res_amount]x [R.title]\s" : "[R.title]"),
		"category" = html_encode("[category]"),
		"cost" = html_encode(cost),
		"state" = row_state,
		"why" = html_encode(why),
		"tools" = html_encode(tools),
		"desc" = html_encode(ispath(R.result_type, /atom) ? "[initial(prototype.desc)]" : ""),
		"built" = built ? 1 : 0,
		"one_per_turf" = R.one_per_turf ? 1 : 0,
		"on_floor" = R.on_floor ? 1 : 0,
		"time" = expected_time(R),
		"makes" = R.res_amount,
		"batches" = limit,
		"atlas" = (crafting_atlas_reference && crafting_atlas_reference.resource_exists(result)) ? 1 : 0,
		"image" = product_image(R.result_type, budget))

/datum/crafting_window/proc/build_data()
	var/obj/item/stack/S = source
	var/list/rows = list()
	var/list/categories = list()
	// New pictures this snapshot may send, and whether any were left for the next one.
	var/list/budget = list(CRAFTING_WINDOW_ICONS_PER_PUSH, FALSE)
	// Flatten only the display, never the source lists: each row keeps its
	// original category and index for find_recipe().
	for (var/i = 1, i <= S.recipes.len, i++)
		var/E = S.recipes[i]
		if (istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/srl = E
			categories += html_encode("[srl.title]")
			for (var/j = 1, j <= srl.recipes.len, j++)
				if (istype(srl.recipes[j], /datum/stack_recipe))
					rows += list(row_data(srl.recipes[j], i, j, srl.title, budget))
		else if (istype(E, /datum/stack_recipe))
			rows += list(row_data(E, 0, i, "General", budget))
	return list(
		"material" = html_encode("[S.name]"),
		"unit" = html_encode("[S.singular_name]"),
		"amount" = S.amount,
		"image" = product_image(S.type, budget),
		"makeable_only" = viewer.craft_makeable_only() ? 1 : 0,
		"categories" = categories,
		"rows" = rows,
		"more_images" = budget[2] ? 1 : 0)

/datum/crafting_window/Topic(href, href_list, state)
	var/mob/living/human/H = usr
	if (!istype(H) || !still_valid(H) || H.stat || H.restrained())
		return FALSE
	if (!isnull(href_list["makeable_only"]))
		var/datum/preferences/P = H.client.prefs
		var/wanted = text2num(href_list["makeable_only"]) ? TRUE : FALSE
		if (P && P.craft_makeable_only != wanted)
			P.craft_makeable_only = wanted
			P.save_preferences()
		// The window already shows the new choice; keep the snapshot in step.
		if (cached)
			cached["makeable_only"] = wanted ? 1 : 0
		return FALSE
	if (href_list["images"])
		// The window asks for the pictures the last snapshot had no room for.
		if (!working && cached && cached["more_images"])
			refresh()
		return FALSE
	if (href_list["atlas"])
		var/datum/stack_recipe/shown = find_recipe(href_list["atlas"])
		if (shown && crafting_atlas_reference && crafting_atlas_reference.resource_exists("[shown.result_type]"))
			crafting_atlas_reference.show(H, "[shown.result_type]", 1, "[shown.result_type]")
		return FALSE
	if (href_list["make"])
		if (working || !H.can_build_recipe)
			return FALSE
		var/datum/stack_recipe/R = find_recipe(href_list["make"])
		if (!R)
			// The list changed under the window: show the current one.
			refresh()
			return FALSE
		var/limit = batch_limit(R)
		var/quantity = round(text2num(href_list["quantity"]))
		if (limit < 1 || !isnum(quantity) || quantity < 1 || quantity > limit)
			refresh()
			return FALSE
		var/obj/item/stack/S = source
		working = list("id" = href_list["make"], "name" = html_encode("[R.title]"), "time" = expected_time(R))
		GLOB.nanomanager.update_uis(src)
		H.can_build_recipe = FALSE
		S.produce_recipe(R, quantity, H)
		H.can_build_recipe = TRUE
		working = null
		// The craft may have used the stack up or the window may have closed.
		if (viewer == H && source == S)
			refresh()
		return FALSE
	return FALSE

#undef CRAFTING_WINDOW_ICONS_PER_PUSH
