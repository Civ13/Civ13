/client
	var/statpanel_loaded = FALSE
	var/statpanel_tab = "Status"
	var/list/statpanel_data = list()
	var/list/statpanel_tabs = list()

/client/proc/init_statpanel()
	src << browse(file("interface/info/info.css"), "display=0")
	src << browse(file("interface/info/info.js"), "display=0")
	src << browse(file("interface/info/info.html"), "window=browser_info")
	statpanel_loaded = TRUE

/client/proc/add_stat(name, value = "")
	statpanel_data += list(list("name" = name, "value" = value))

/client/proc/add_stat_tab(tab)
	if (!(tab in statpanel_tabs))
		statpanel_tabs += tab

/client/proc/update_statpanel()
	if (!statpanel_loaded)
		return
	
	var/list/verbs_data = list()
	var/list/all_verbs = list()
	all_verbs += verbs
	if (mob)
		all_verbs += mob.verbs

	var/list/admin_categories = list("Server", "Admin", "Debug", "Bans", "Special", "Fun", "Nomads")

	for (var/v in all_verbs)
		if (!v || v:hidden)
			continue
		var/category = v:category
		if (!category || category == "General")
			continue

		var/display_category = category
		if (category in admin_categories)
			display_category = "Admin"
		
		if (display_category == statpanel_tab)
			verbs_data += list(list("name" = v:name, "command" = v:name, "category" = category))
		
		add_stat_tab(display_category)

	add_stat_tab(statpanel_tab)

	var/list/payload = list(
		"tabs" = statpanel_tabs,
		"current_tab" = statpanel_tab,
		"stats" = statpanel_data,
		"verbs" = verbs_data
	)
	var/json = json_encode(payload)
	src << output(json, "browser_info:updateStats")
	
	statpanel_data.Cut()
	statpanel_tabs.Cut()

/client/Topic(href, href_list)
	if (href_list["action"] == "statpanel_tab")
		statpanel_tab = href_list["tab"]
		if (mob)
			mob.Stat()
		update_statpanel()
		return
	if (href_list["action"] == "execute_verb")
		var/verb_name = href_list["verb"]
		winset(src, null, "command=[verb_name]")
		return
	return ..()
