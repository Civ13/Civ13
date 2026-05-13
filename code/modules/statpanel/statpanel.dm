///////////////////////////////
//////////// CivUI ////////////
///////////////////////////////
// This replaces the native BYOND statspanel
// and infopanel with a HTML-based menu

/client
	var/statpanel_ready = FALSE
	var/statpanel_tab = "Status"
	var/list/statpanel_data = list()
	var/list/statpanel_tabs = list()
	var/statpanel_next_update = 0

/client/proc/run_verb(verb_name as text)
	// 1) Collect all available verbs
	var/list/all_verbs = list()
	all_verbs += verbs
	if (mob)
		all_verbs += mob.verbs

	// 2) Try to find and execute by name or path
	for (var/v in all_verbs)
		if (!v) continue
		// Match against display name or path string
		if (v:name == verb_name || "[v]" == verb_name)
			if (mob && (v in mob.verbs))
				call(mob, v)()
			else
				call(src, v)()
			return TRUE
		
		// If verb_name has spaces, try matching against underscored version
		if (findtext(verb_name, " "))
			var/und_name = replacetext(verb_name, " ", "_")
			if (v:name == und_name || "[v]" == und_name || findtext("[v]", und_name))
				if (mob && (v in mob.verbs))
					call(mob, v)()
				else
					call(src, v)()
				return TRUE

	// 3) Try direct proc calls as fallback
	// No spaces: try direct match
	if (!findtext(verb_name, " "))
		if (hascall(src, verb_name))
			call(src, verb_name)()
			return TRUE
		
		var/datum/admins/A = holder
		if (A && hascall(A, verb_name))
			if (check_rights(R_ADMIN, FALSE, src))
				call(A, verb_name)()
				return TRUE

	// Spaces: try underscored version as proc name
	else
		var/und_name = lowertext(replacetext(verb_name, " ", "_"))
		if (hascall(src, und_name))
			call(src, und_name)()
			return TRUE
		var/datum/admins/A = holder
		if (A && hascall(A, und_name))
			if (check_rights(R_ADMIN, FALSE, src))
				call(A, und_name)()
				return TRUE

	return FALSE

/client/proc/init_statpanel()
	src << browse('interface/info/info.html', "window=browser_info")

/client/proc/add_stat(name, value = "")
	statpanel_data += list(list("name" = name, "value" = value))

/client/proc/add_stat_tab(tab)
	if (!(tab in statpanel_tabs))
		statpanel_tabs += tab

/client/proc/update_statpanel()
	if (!statpanel_ready)
		return
	
	statpanel_next_update = world.time + 10
	
	var/list/verbs_data = list()
	var/list/all_verbs = list()
	all_verbs += verbs
	if (mob)
		all_verbs += mob.verbs

	var/list/admin_categories = list("Admin", "Debug", "Bans", "Special", "Fun")
	var/list/server_categories = list("Server","Nomads")
	var/target_tab = lowertext(statpanel_tab)

	for (var/v in all_verbs)
		if (!v) continue
		
		var/v_category = ""
		var/v_name = ""
		try
			v_category = v:category
			v_name = v:name
		catch
			continue

		if (!v_category)
			continue

		var/display_category = v_category
		if (v_category in admin_categories)
			display_category = "Admin"
		if (v_category in server_categories)
			display_category = "Server"
		
		if (lowertext(display_category) == target_tab)
			v_name = replacetext(v_name, "\"", "'")
			v_name = replacetext(v_name, "\n", " ")
			verbs_data += list(list("name" = v_name, "command" = v_name, "category" = v_category))
		
		add_stat_tab(display_category)

	add_stat_tab(statpanel_tab)

	var/list/payload = list(
		"tabs" = statpanel_tabs,
		"current_tab" = statpanel_tab,
		"stats" = statpanel_data,
		"verbs" = verbs_data
	)
	var/json = json_encode(payload)
	src << output(json, "browser_info:receiveStats")
	
	statpanel_data.Cut()
	statpanel_tabs.Cut()

/client/Topic(href, href_list)
	if (href_list["action"] == "statpanel_ready")
		statpanel_ready = TRUE
		if (mob)
			mob.Stat()
		update_statpanel()
		return
	if (href_list["action"] == "statpanel_tab")
		statpanel_tab = href_list["tab"]
		if (mob)
			mob.Stat()
		update_statpanel()
		return
	if (href_list["action"] == "execute_verb")
		var/verb_name = href_list["verb"]
		run_verb(verb_name)
		return
	return ..()
