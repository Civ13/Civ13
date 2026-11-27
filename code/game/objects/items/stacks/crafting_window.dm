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
#define CRAFTING_WINDOW_PIN_LIMIT 60
#define CRAFTING_WINDOW_RECENT_LIMIT 30
#define CRAFTING_WINDOW_REACH_LIMIT 12

/client
	// Set once this client's browser could not run the Crafting window.
	var/tmp/crafting_window_classic = FALSE
	// Product type path -> preview file already sent to this client ("-" = no picture).
	var/tmp/list/craft_icon_cache
	// Recipe keys this client crafted this session, newest first.
	var/tmp/list/craft_recent

/datum/preferences
	// Recipe keys the player pinned; saved with the other interface choices.
	var/list/craft_pinned = list()

// Purpose tabs. The rules are data (config/crafting_purposes.json): a
// recipe's old category decides first, then the first matching product type.
var/global/list/crafting_purpose_rules
var/global/list/crafting_purpose_cache = list()

/proc/crafting_purpose(typepath, category)
	var/path = "[typepath]"
	var/named = lowertext(trim("[category]"))
	var/key = "[path]|[named]"
	var/known = crafting_purpose_cache[key]
	if (known)
		return known
	if (!crafting_purpose_rules)
		// A missing or empty file leaves every recipe under Other instead of failing.
		var/raw = fexists("config/crafting_purposes.json") ? file2text("config/crafting_purposes.json") : null
		crafting_purpose_rules = length(raw) ? json_decode(raw) : null
		if (!islist(crafting_purpose_rules))
			crafting_purpose_rules = list()
	var/found = "Other"
	var/list/categories = crafting_purpose_rules["categories"]
	var/list/types = crafting_purpose_rules["types"]
	if (islist(categories) && categories[named])
		found = categories[named]
	else if (islist(types))
		for (var/i = 1, i <= types.len, i++)
			var/list/rule = types[i]
			if (!islist(rule) || rule.len < 2)
				continue
			if (path == rule[1] || findtext(path, "[rule[1]]/") == 1)
				found = rule[2]
				break
	crafting_purpose_cache[key] = found
	return found

// One recipe of one material, the same on every visit: what Pinned and Recent remember.
/proc/crafting_window_pin_key(obj/item/stack/S, datum/stack_recipe/R)
	// Preserve pins and recent entries created before the dowel recipe rename.
	var/pin_title = R.title
	if (R.result_type == /obj/item/stack/wooden_dowels && pin_title == "whittled wooden dowel set")
		pin_title = "joinery: whittled wooden dowel set"
	return md5("[S.type]|[pin_title]|[R.result_type]")

// The player's pins, with anything a damaged save left behind removed.
/datum/crafting_window/proc/pinned_keys()
	var/datum/preferences/P = viewer.client ? viewer.client.prefs : null
	if (!P)
		return list()
	if (!islist(P.craft_pinned))
		P.craft_pinned = list()
	for (var/entry in P.craft_pinned)
		if (!istext(entry) || length(entry) != 32)
			P.craft_pinned -= entry
	return P.craft_pinned

/mob/living/human/var/tmp/datum/crafting_window/crafting_window = null

/datum/crafting_window
	var/mob/living/human/viewer
	var/obj/item/stack/source
	// The craft in progress, as sent to the window: id, name and expected deciseconds.
	var/list/working
	// The last full snapshot, reused while a craft is in progress.
	var/list/cached
	// Opened with the craft key: the material may be in either hand or loose
	// on a tile next to the player, and the window offers the others in reach.
	var/reach = FALSE
	// A row the window should select when it next opens, and a counter so the
	// same row can be asked for twice. Set by the Atlas hand-off only.
	var/focus = ""
	var/focus_seq = 0
	// The selected recipe's exact requirements and the choices it asks for.
	var/list/detail
	// Set for one push that must reuse the last snapshot instead of rebuilding every row.
	var/keep_snapshot = FALSE
	// Processing row id -> the Atlas page its "Open in Atlas" link may show.
	var/list/processing_links

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
	if (reach)
		return source.crafting_stack_accessible(H)
	return source.loc == H && H.get_active_hand() == source

// Every material this character could craft from without picking anything up:
// both hands first, then loose stacks on their own tile and the tiles around it.
/mob/living/human/proc/crafting_stacks_within_reach()
	var/list/found = list()
	for (var/obj/item/stack/held in list(get_active_hand(), get_inactive_hand()))
		if (held.amount > 0 && held.recipes && held.recipes.len)
			found += held
	var/turf/here = get_turf(src)
	if (!here)
		return found
	for (var/turf/T in range(1, here))
		for (var/obj/item/stack/loose in T)
			if (found.len >= CRAFTING_WINDOW_REACH_LIMIT)
				return found
			if (loose.amount > 0 && loose.recipes && loose.recipes.len && loose.crafting_stack_accessible(src))
				found += loose
	return found

// The craft key and the IC tab entry. Nothing is picked up or spent here.
/mob/living/human/verb/craft_within_reach()
	set name = "craft-within-reach"
	set hidden = TRUE
	open_crafting_within_reach()

/mob/living/human/verb/craft_within_reach_listed()
	set name = "Craft With Nearby Materials"
	set category = "IC"
	set desc = "Open the Crafting window for the materials in your hands and on the tiles around you."
	open_crafting_within_reach()

/mob/living/human/proc/open_crafting_within_reach()
	if (!client || stat || restrained())
		return
	var/list/near = crafting_stacks_within_reach()
	player_activity.feature_used(src, "crafting_within_reach")
	if (!near.len)
		to_chat(src, "<span class='notice'>Nothing to craft with is within reach. Hold a material, or stand next to one.</span>")
		return
	var/obj/item/stack/first = near[1]
	if (first.crafting_window_shown(src, TRUE))
		return
	// The classic list only knows the material in the active hand.
	var/obj/item/stack/held = get_active_hand()
	if (istype(held))
		held.attack_self(src)
	else
		to_chat(src, "<span class='notice'>The classic crafting list needs the material in your active hand.</span>")

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

// A browser that cannot run the window gets the plain HTML list for the rest
// of this connection.
/datum/nanoui/tgui/crafting_window/show_plain_page()
	var/datum/crafting_window/W = src_object
	var/mob/living/human/H = user
	var/obj/item/stack/S = istype(W) ? W.source : null
	if (H && H.client)
		H.client.crafting_window_classic = TRUE
	var/datum/crafting_window/anvil/station = W
	var/obj/structure/anvil/A = istype(station) ? station.anvil : null
	close()
	if (istype(H) && S && !QDELETED(S) && S.loc == H && H.get_active_hand() == S)
		if (istype(station))
			// The anvil's own menus are its classic list.
			if (A && !QDELETED(A) && in_range(A, H))
				A.attackby(S, H)
			return
		S.list_recipes(H)

// TRUE when the modern window took this request; FALSE sends the caller on to
// the classic list.
/obj/item/stack/proc/crafting_window_shown(mob/user, reach = FALSE, focus = "")
	var/mob/living/human/H = user
	if (!istype(H) || !H.client || H.client.crafting_window_classic || H.client.modern_ui_failed)
		return FALSE
	if (reach ? !crafting_stack_accessible(H) : (loc != H || H.get_active_hand() != src))
		return FALSE
	var/datum/crafting_window/W = H.crafting_window
	if (W && W.working)
		// A craft is under way: leave its window as it is.
		return TRUE
	// A station's window (the anvil's) lists that station's rows, never this stack's own.
	if (W && (W.type != /datum/crafting_window || (W.source != src && !(reach && W.reach))))
		GLOB.nanomanager.close_uis(W)
		W.closed()
		W = null
	if (!W)
		W = new /datum/crafting_window(H, src)
		H.crafting_window = W
	W.source = src
	W.reach = reach
	W.focus = "[focus]"
	if (length(W.focus))
		W.focus_seq++
	if (reach)
		W.load_recipes()
	show_browse(H, null, "window=stack")
	H.set_using_object(src)
	W.cached = null
	W.ui_interact(H)
	return TRUE

/datum/crafting_window/ui_actions(ui_key)
	return list("make", "makeable_only", "images", "atlas", "pin", "source", "detail", "process_atlas", "tech_tree")

/datum/crafting_window/ui_action_fields(ui_key, action)
	if (action == "make")
		return list("quantity", "options")
	return ..()

/datum/crafting_window/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	if (user != viewer || !still_valid(viewer))
		return
	var/list/data = ((working || keep_snapshot) && cached) ? cached : build_data()
	keep_snapshot = FALSE
	cached = data
	data["working"] = working
	data["detail"] = detail
	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		var/datum/topic_state/crafting_window/window_state = new()
		ui = new /datum/nanoui/tgui/crafting_window(user, src, ui_key, "crafting_window.tmpl", "Crafting", 940, 680, _state = window_state)
		ui.set_initial_data(data)
		ui.open()

// Push a fresh snapshot to the open window without reopening it.
/datum/crafting_window/proc/refresh()
	if (!viewer)
		return
	if (reach && !still_valid(viewer) && !QDELETED(viewer) && viewer.client)
		// The material in use ran out or moved: carry on with the next one in reach.
		var/list/near = viewer.crafting_stacks_within_reach()
		if (near.len)
			source = near[1]
			viewer.set_using_object(source)
	if (!still_valid(viewer))
		return
	cached = null
	load_recipes()
	// What the selected recipe needs may have changed with what was just made.
	if (detail)
		detail = detail_for(detail["id"])
	ui_interact(viewer, force_open = FALSE)

// Push the last snapshot again with only its small parts changed.
/datum/crafting_window/proc/push_cached()
	if (!viewer || !still_valid(viewer))
		return
	keep_snapshot = TRUE
	ui_interact(viewer, force_open = FALSE)

// One recipe looked at closely: every requirement its guards report as unmet
// right now, and the choices it would otherwise ask in pop-ups. Read only.
/datum/crafting_window/proc/detail_for(id)
	var/datum/stack_recipe/R = find_recipe(id)
	if (!R)
		return null
	var/list/needs = list()
	for (var/list/line in craft_recipe_requirements(viewer, R, source))
		needs += list(list("label" = html_encode(trim("[line["label"]]")), "met" = line["met"] ? 1 : 0))
	var/list/fields = list()
	var/datum/craft_product/P = craft_product_for(R)
	if (P)
		for (var/list/prompt in P.prompts)
			var/list/field = list(
				"field" = "[prompt["field"]]",
				"kind" = "[prompt["kind"]]",
				"question" = html_encode("[craft_product_text(prompt["question"], R, viewer)]"),
				"default" = html_encode("[craft_product_text(prompt["default"], R, viewer)]"),
				"required" = prompt["required"] ? 1 : 0,
				"max_length" = prompt["max_length"] ? prompt["max_length"] : 256)
			if (prompt["kind"] == "company")
				var/list/choices = list()
				for (var/company in craft_product_companies(viewer))
					choices += html_encode("[company]")
				field["choices"] = choices
			fields += list(field)
	return list("id" = "[id]", "needs" = needs, "fields" = fields)

// The answers the card sent for this recipe's declared choices. Only fields the
// product declares are kept; the craft code sanitizes and validates each one,
// and asks in a pop-up for any that are missing.
/datum/crafting_window/proc/given_options(datum/stack_recipe/R, raw)
	var/datum/craft_product/P = craft_product_for(R)
	if (!P || !istext(raw) || length(raw) > 4096)
		return null
	var/list/sent
	try
		sent = json_decode(raw)
	catch
		return null
	if (!islist(sent))
		return null
	var/list/options = list()
	for (var/list/prompt in P.prompts)
		var/field = "[prompt["field"]]"
		var/value = sent[field]
		if (istext(value) && length(value) <= 1024)
			options[field] = value
	return options.len ? options : null

// Material stacks rebuild their list for this character, as the classic list does on opening.
/datum/crafting_window/proc/load_recipes()
	if (istype(source, /obj/item/stack/material))
		var/obj/item/stack/material/M = source
		M.recipes = M.material.get_recipes_civs(viewer)

// The row id of the first recipe in this stack's lists that makes the given type, or "".
/obj/item/stack/proc/crafting_window_row_for(wanted)
	if (!ispath(wanted) || !recipes)
		return ""
	for (var/i = 1, i <= recipes.len, i++)
		var/E = recipes[i]
		if (istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/srl = E
			for (var/j = 1, j <= srl.recipes.len, j++)
				var/datum/stack_recipe/inner = srl.recipes[j]
				if (istype(inner) && inner.result_type == wanted)
					return crafting_window_row_id(inner, i, j)
		else if (istype(E, /datum/stack_recipe))
			var/datum/stack_recipe/top = E
			if (top.result_type == wanted)
				return crafting_window_row_id(top, 0, i)
	return ""

// "Craft this" on an Atlas recipe: open the Crafting window on that recipe when
// a material that makes it is within reach. A hand-off only; nothing is made
// here and the window applies its own checks before anything is.
/proc/crafting_window_from_atlas(mob/viewer, product)
	var/mob/living/human/H = viewer
	if (!istype(H) || !H.client || H.stat || H.restrained())
		if (viewer)
			to_chat(viewer, "<span class='notice'>You cannot craft right now.</span>")
		return FALSE
	var/wanted = text2path("[product]")
	if (!ispath(wanted, /atom))
		return FALSE
	for (var/obj/item/stack/near in H.crafting_stacks_within_reach())
		// Material stacks list recipes per character, as they do when used in hand.
		if (istype(near, /obj/item/stack/material))
			var/obj/item/stack/material/M = near
			M.recipes = M.material.get_recipes_civs(H)
		var/row = near.crafting_window_row_for(wanted)
		if (!length(row))
			continue
		if (near.crafting_window_shown(H, TRUE, row))
			return TRUE
		to_chat(H, "<span class='notice'>You can make that from the [near.name] within reach. Use it in your hand to open the classic crafting list.</span>")
		return FALSE
	to_chat(H, "<span class='notice'>Nothing within reach makes that. Hold the material the recipe needs, or stand next to it, and try again.</span>")
	return FALSE

// Where a material is, in the player's words.
/datum/crafting_window/proc/where(obj/item/stack/S)
	if (S.loc == viewer)
		return "in your hand"
	return get_turf(S) == get_turf(viewer) ? "at your feet" : "next to you"

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
		if (source)
			buildtime *= viewer.trade_time_mult(source.stack_trade())
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

/datum/crafting_window/proc/row_data(datum/stack_recipe/R, sublist, index, category, list/budget, list/pinned, list/recent)
	var/obj/item/stack/S = source
	var/pin_key = crafting_window_pin_key(S, R)
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
			why = recipe_skill_refusal(viewer, R) || ""
		if (!why)
			var/need = craft_needs_refusal(viewer, R, 1, S)
			if (istext(need))
				why = trim(strip_html_properly(need))
		if (!why)
			why = "Missing a tool, skill or second material"
	var/cost = "[R.req_amount] [S.singular_name]\s"
	if (recipe_needs_crafting_handle(R.title))
		cost += " + wood handle"
	var/tools = ""
	var/list/joint_spec = furniture_joinery_spec(R)
	if (stone_mold_type(R.result_type))
		tools = "Chisel and hammer/mallet equipped or at your feet."
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
		"purpose" = html_encode(crafting_purpose(R.result_type, category)),
		"pinned" = (pinned && pinned.Find(pin_key)) ? 1 : 0,
		"recent" = recent ? recent.Find(pin_key) : 0,
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
		"tech_tree" = manual_hint ? 1 : 0,
		"image" = product_image(R.result_type, budget))

/datum/crafting_window/proc/build_data()
	var/obj/item/stack/S = source
	var/list/rows = list()
	// New pictures this snapshot may send, and whether any were left for the next one.
	var/list/budget = list(CRAFTING_WINDOW_ICONS_PER_PUSH, FALSE)
	var/list/pinned = pinned_keys()
	var/list/recent = viewer.client ? viewer.client.craft_recent : null
	// Flatten only the display, never the source lists: each row keeps its
	// original category and index for find_recipe().
	for (var/i = 1, i <= S.recipes.len, i++)
		var/E = S.recipes[i]
		if (istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/srl = E
			for (var/j = 1, j <= srl.recipes.len, j++)
				if (istype(srl.recipes[j], /datum/stack_recipe))
					rows += list(row_data(srl.recipes[j], i, j, srl.title, budget, pinned, recent))
		else if (istype(E, /datum/stack_recipe))
			rows += list(row_data(E, 0, i, "General", budget, pinned, recent))
	// Tool work, stations and soaking that turn this material into something else.
	var/list/processing = type == /datum/crafting_window ? processing_data(S, budget) : list(list(), 0)
	var/list/sources = list()
	if (reach)
		for (var/obj/item/stack/near in viewer.crafting_stacks_within_reach())
			sources += list(list(
				"key" = "\ref[near]",
				"name" = html_encode("[near.name]"),
				"amount" = near.amount,
				"where" = where(near),
				"current" = near == S ? 1 : 0,
				"image" = product_image(near.type, budget)))
	return list(
		"focus" = focus,
		"focus_seq" = focus_seq,
		"reach" = reach ? 1 : 0,
		"sources" = sources,
		"where" = where(S),
		"material" = html_encode("[S.name]"),
		"unit" = html_encode("[S.singular_name]"),
		"amount" = S.amount,
		"image" = product_image(S.type, budget),
		"makeable_only" = viewer.craft_makeable_only() ? 1 : 0,
		"purposes" = islist(crafting_purpose_rules) && islist(crafting_purpose_rules["order"]) ? crafting_purpose_rules["order"] : list("Other"),
		"rows" = rows,
		"processing" = processing[1],
		"processing_total" = processing[2],
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
	if (href_list["tech_tree"])
		// Only the node a recipe of this material still needs: never a client-chosen node.
		var/datum/stack_recipe/gated = find_recipe(href_list["tech_tree"])
		if (gated && tech_tree_view && crafting_recipe_manual_hint(H, "[gated.result_type]"))
			tech_tree_view.show(H, get_recipe_node_req("[gated.result_type]"))
		return FALSE
	if (href_list["process_atlas"])
		// Only a page this window listed for the material: never a client-chosen id.
		var/page = islist(processing_links) ? processing_links["[href_list["process_atlas"]]"] : null
		if (page && crafting_atlas_reference && crafting_atlas_reference.resource_exists(page))
			crafting_atlas_reference.show(H, page, 1, page)
		return FALSE
	if (href_list["source"])
		// Another material in reach: only ones the server can still see next to the player.
		if (!reach || working)
			return FALSE
		var/obj/item/stack/picked = locate(href_list["source"])
		if (istype(picked) && (picked in H.crafting_stacks_within_reach()))
			picked.crafting_window_shown(H, TRUE)
		else
			refresh()
		return FALSE
	if (href_list["pin"])
		// Pinning spends nothing and changes no recipe: it only marks the row.
		var/datum/stack_recipe/marked = find_recipe(href_list["pin"])
		var/datum/preferences/P = H.client.prefs
		if (!marked || !P || working)
			return FALSE
		var/list/pinned = pinned_keys()
		var/pin_key = crafting_window_pin_key(source, marked)
		if (pinned.Find(pin_key))
			pinned -= pin_key
		else if (pinned.len < CRAFTING_WINDOW_PIN_LIMIT)
			pinned += pin_key
		else
			to_chat(H, "<span class='warning'>You can pin up to [CRAFTING_WINDOW_PIN_LIMIT] recipes. Unpin one first.</span>")
			return FALSE
		P.save_preferences()
		if (cached)
			for (var/list/row in cached["rows"])
				if (row["id"] == href_list["pin"])
					row["pinned"] = pinned.Find(pin_key) ? 1 : 0
			push_cached()
		return FALSE
	if (href_list["detail"])
		// Selecting a row asks what exactly it needs. Nothing is spent or built.
		if (working)
			return FALSE
		detail = detail_for(href_list["detail"])
		push_cached()
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
		var/list/options = given_options(R, href_list["options"])
		working = list("id" = href_list["make"], "name" = html_encode("[R.title]"), "time" = expected_time(R))
		GLOB.nanomanager.update_uis(src)
		var/held_before = S.amount
		var/recent_key = crafting_window_pin_key(S, R)
		H.can_build_recipe = FALSE
		S.produce_recipe(R, quantity, H, options, recheck_source = reach)
		H.can_build_recipe = TRUE
		working = null
		// Material went, so something was made: remember it for the Recent strip.
		if (H.client && (QDELETED(S) || S.amount < held_before))
			if (!islist(H.client.craft_recent))
				H.client.craft_recent = list()
			H.client.craft_recent -= recent_key
			H.client.craft_recent.Insert(1, recent_key)
			if (H.client.craft_recent.len > CRAFTING_WINDOW_RECENT_LIMIT)
				H.client.craft_recent.len = CRAFTING_WINDOW_RECENT_LIMIT
		// The craft may have used the stack up or the window may have closed.
		if (viewer == H && (source == S || reach))
			refresh()
		return FALSE
	return FALSE

#undef CRAFTING_WINDOW_ICONS_PER_PUSH
#undef CRAFTING_WINDOW_PIN_LIMIT
#undef CRAFTING_WINDOW_RECENT_LIMIT
#undef CRAFTING_WINDOW_REACH_LIMIT
