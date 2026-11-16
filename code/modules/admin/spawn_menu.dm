// The admin Spawn picker (tgui/src/interfaces/SpawnMenu.tsx). The list of
// spawnable types is built once per round and searched on the server, so the
// window opens at once and only the best matches travel to the viewer.

#define SPAWN_MENU_RESULTS 150
#define SPAWN_MENU_MAX_AMOUNT 50
#define SPAWN_MENU_RECENT 12

// Every /atom type: its path, display name, search text and category. Parallel
// lists keep the search loop to plain index reads.
/var/global/list/spawn_catalog_paths
/var/global/list/spawn_catalog_names
/var/global/list/spawn_catalog_keys
/var/global/list/spawn_catalog_kinds
/var/global/list/spawn_catalog_texts
/var/global/list/spawn_catalog_leaves
/var/global/list/spawn_catalog_lower_names
/var/global/list/spawn_catalog_index

/var/global/datum/topic_state/admin_spawn_state/admin_spawn_state = new()

/datum/topic_state/admin_spawn_state/can_use_topic(var/src_object, var/mob/user)
	return check_rights(R_SPAWN, FALSE, user) ? STATUS_INTERACTIVE : STATUS_CLOSE

/proc/spawn_catalog_kind(path)
	if (ispath(path, /obj))
		return "obj"
	if (ispath(path, /mob))
		return "mob"
	if (ispath(path, /turf))
		return "turf"
	if (ispath(path, /area))
		return "area"
	return "other"

/proc/build_spawn_catalog()
	if (spawn_catalog_paths)
		return
	var/list/paths = typesof(/atom)
	var/list/names = new /list(paths.len)
	var/list/keys = new /list(paths.len)
	var/list/kinds = new /list(paths.len)
	var/list/texts = new /list(paths.len)
	var/list/leaves = new /list(paths.len)
	var/list/lower_names = new /list(paths.len)
	var/list/index = list()
	for (var/i = 1 to paths.len)
		var/atom/path = paths[i]
		var/name = "[initial(path.name)]"
		var/path_text = lowertext("[path]")
		names[i] = name
		texts[i] = path_text
		leaves[i] = copytext(path_text, findlasttext(path_text, "/") + 1)
		lower_names[i] = lowertext(name)
		keys[i] = "[path_text] [lower_names[i]]"
		kinds[i] = spawn_catalog_kind(path)
		index[path] = i
	spawn_catalog_texts = texts
	spawn_catalog_leaves = leaves
	spawn_catalog_lower_names = lower_names
	spawn_catalog_names = names
	spawn_catalog_keys = keys
	spawn_catalog_kinds = kinds
	spawn_catalog_index = index
	spawn_catalog_paths = paths

// Indexes of the catalog entries that contain every word of query, best first:
// an exact leaf or name, then a leaf or name that starts with the first word,
// then the rest. With paths_only, only the type path is searched (the typed
// argument form of the verb). total, when given, receives the full match count.
/proc/search_spawn_catalog(query, kind = "all", limit = SPAWN_MENU_RESULTS, paths_only = FALSE, list/total)
	build_spawn_catalog()
	query = lowertext(trim("[query]"))
	var/list/words = list()
	for (var/word in splittext(query, " "))
		if (word)
			words += word
	if (!words.len)
		return list()
	var/first = words[1]
	var/list/exact = list()
	var/list/prefix = list()
	var/list/rest = list()
	var/count = 0
	var/list/haystacks = paths_only ? spawn_catalog_texts : spawn_catalog_keys
	var/list/leaves = spawn_catalog_leaves
	var/list/names = spawn_catalog_lower_names
	var/list/kinds = spawn_catalog_kinds
	var/any_kind = (kind == "all")
	for (var/i = 1 to haystacks.len)
		if (!any_kind && kinds[i] != kind)
			continue
		var/haystack = haystacks[i]
		var/found = TRUE
		for (var/word in words)
			if (!findtextEx(haystack, word))
				found = FALSE
				break
		if (!found)
			continue
		count++
		var/leaf = leaves[i]
		var/name = names[i]
		if (leaf == query || name == query)
			exact += i
		else if (findtextEx(leaf, first) == 1 || findtextEx(name, first) == 1)
			if (prefix.len < limit)
				prefix += i
		else if (rest.len < limit)
			rest += i
	if (total)
		total += count
	var/list/out = exact + prefix + rest
	if (out.len > limit)
		out.Cut(limit + 1)
	return out

// Spawns amount of path where user stands; a turf replaces the floor once.
// Returns the turf used, or null when nothing was spawned.
/proc/admin_spawn_type(mob/user, path, amount = 1)
	if (!user || !ispath(path, /atom) || !check_rights(R_SPAWN, TRUE, user))
		return null
	var/turf/T = get_turf(user)
	if (!T)
		return null
	if (ispath(path, /turf))
		T.ChangeTurf(path)
		amount = 1
	else
		amount = clamp(round(amount), 1, SPAWN_MENU_MAX_AMOUNT)
		for (var/i = 1 to amount)
			new path(user.loc)
	log_and_message_admins("spawned [amount > 1 ? "[amount] x " : ""][path] at ([T.x],[T.y],[T.z])", user, T)
	return T

/datum/admins
	var/datum/admin_spawn_menu/spawn_menu

/datum/admins/proc/get_spawn_menu()
	if (!spawn_menu)
		spawn_menu = new /datum/admin_spawn_menu
	return spawn_menu

// One per admin, so a search survives closing and reopening the window.
/datum/admin_spawn_menu
	var/query = ""
	var/kind = "all"
	var/list/recent = list()
	var/last_spawned = ""

/datum/admin_spawn_menu/proc/open(mob/user, new_query)
	if (!isnull(new_query))
		query = copytext(trim("[new_query]"), 1, 101)
	ui_interact(user, "spawn")

/datum/admin_spawn_menu/ui_actions(ui_key)
	return list("search", "kind", "spawn")

/datum/admin_spawn_menu/ui_action_fields(ui_key, action)
	if (action == "spawn")
		return list("amount")
	return null

/datum/admin_spawn_menu/proc/entry(i)
	return list("path" = "[spawn_catalog_paths[i]]", "name" = spawn_catalog_names[i], "kind" = spawn_catalog_kinds[i])

/datum/admin_spawn_menu/ui_interact(mob/user, ui_key = "spawn", datum/nanoui/ui = null, force_open = TRUE, datum/nanoui/master_ui = null, datum/topic_state/state = admin_spawn_state)
	if (!check_rights(R_SPAWN, FALSE, user))
		return
	build_spawn_catalog()
	var/list/results = list()
	var/list/total = list()
	if (query)
		for (var/i in search_spawn_catalog(query, kind, SPAWN_MENU_RESULTS, FALSE, total))
			results += list(entry(i))
	else
		for (var/path in recent)
			var/i = spawn_catalog_index[path]
			if (i)
				results += list(entry(i))
	var/list/data = list(
		"query" = query,
		"kind" = kind,
		"results" = results,
		"matches" = total.len ? total[1] : 0,
		"limit" = SPAWN_MENU_RESULTS,
		"types" = spawn_catalog_paths.len,
		"max_amount" = SPAWN_MENU_MAX_AMOUNT,
		"last" = last_spawned)
	open_tgui(user, ui_key, "spawn_menu.tmpl", "Spawn", 640, 640, data, ui, force_open, admin_spawn_state)

/datum/admin_spawn_menu/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if (!check_rights(R_SPAWN, FALSE, user))
		return TRUE
	switch (action)
		if ("search")
			query = copytext(trim("[params["value"]]"), 1, 101)
		if ("kind")
			var/new_kind = "[params["value"]]"
			if (new_kind in list("all", "obj", "mob", "turf", "area"))
				kind = new_kind
		if ("spawn")
			build_spawn_catalog()
			var/path = text2path("[params["value"]]")
			if (!path || !spawn_catalog_index[path])
				return TRUE
			var/amount = text2num("[params["amount"]]")
			if (!isnum(amount))
				amount = 1
			if (admin_spawn_type(user, path, amount))
				last_spawned = "[path]"
				recent -= path
				recent.Insert(1, path)
				if (recent.len > SPAWN_MENU_RECENT)
					recent.Cut(SPAWN_MENU_RECENT + 1)
	return TRUE

#undef SPAWN_MENU_RESULTS
#undef SPAWN_MENU_MAX_AMOUNT
#undef SPAWN_MENU_RECENT
