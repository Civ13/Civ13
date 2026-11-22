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
	// The panel is a second view of the native verb lists, not a proc API.
	// Resolve against the current lists, since the client's mob and rights can
	// change after a button was rendered.
	if (!istext(verb_name) || !length(verb_name))
		return FALSE

	var/list/all_verbs = list()
	all_verbs += verbs
	if (mob)
		all_verbs += mob.verbs

	for (var/v in all_verbs)
		if (!v)
			continue
		var/registered_name
		try
			if (!v:category)
				continue
			registered_name = v:name
		catch
			continue
		if (registered_name == verb_name)
			// list2params escapes names such as "Write God's Book", whose quote
			// would end a hand-quoted command='...' value.
			var/cmd_name = replacetext(registered_name, " ", "-")
			winset(src, null, list2params(list("command" = cmd_name)))
			return TRUE

	return FALSE

/client/proc/init_statpanel()
	src << browse_rsc('interface/fonts/Alegreya-Regular.ttf', "Alegreya-Regular.ttf")
	src << browse_rsc('interface/fonts/Alegreya-Bold.ttf', "Alegreya-Bold.ttf")
	src << browse_rsc('interface/fonts/Alegreya-Italic.ttf', "Alegreya-Italic.ttf")
	src << browse_rsc('interface/fonts/Alegreya-BoldItalic.ttf', "Alegreya-BoldItalic.ttf")
	src << browse_rsc('interface/fonts/Alegreya-Black.ttf', "Alegreya-Black.ttf")
	show_browse(src, 'interface/info/info.html', "window=browser_info")

// Both side panels are web pages that say when they are ready. A page sent
// while the client is still settling (a handover or reboot reconnect pulling
// the new resources) can stay blank or never answer, which leaves the stat
// panel white and the chat holding every new line. Resend each panel that has
// not answered, a few times, then stop.
#define BROWSER_PANEL_RETRIES 3
#define BROWSER_PANEL_RETRY_DELAY 100

/client/proc/watch_browser_panels()
	set waitfor = FALSE
	for (var/attempt in 1 to BROWSER_PANEL_RETRIES)
		sleep(BROWSER_PANEL_RETRY_DELAY)
		if (statpanel_ready && (!chat || chat.is_ready))
			return
		if (!statpanel_ready)
			init_statpanel()
		if (chat && !chat.is_ready)
			chat.load()

#undef BROWSER_PANEL_RETRIES
#undef BROWSER_PANEL_RETRY_DELAY

/client/proc/add_stat(name, value = "")
	statpanel_data += list(list("name" = name, "value" = value))

// Extra Status lines from mob Stat() overrides go through this and add_stat.
// The panel is a web page, and Stat() is also called from Topic, where the
// built-in stat() and statpanel() runtime with "unexpected stat".
/client/proc/shows_status_tab()
	return status_tabs && statpanel_tab == "Status"

/client/proc/add_stat_tab(tab)
	if (!(tab in statpanel_tabs))
		statpanel_tabs += tab
	return (statpanel_tab == tab)

/client/proc/update_statpanel()
	if (!statpanel_ready)
		return
	
	statpanel_next_update = world.time + 10
	if (status_tabs && statpanel_tab == "Status")
		// Put the shared, fixed-label observation ahead of longer mob sections.
		var/list/previous_stats = statpanel_data
		statpanel_data = list()
		var/list/player_status = player_status_observation()
		var/world_activity = player_world_activity(player_status)
		if(world_activity) add_stat("<b>World activity:</b>", world_activity)
		add_stat("<b>Joining:</b>", player_join_status(player_status))
		var/last_save = persistence_last_save_text()
		if(last_save) add_stat("<b>Last save:</b>", last_save)
		if(holder) add_stat("<b>Server build:</b>", server_build_summary())
		statpanel_data += previous_stats
	
	var/list/verbs_data = list()
	var/list/all_verbs = list()
	all_verbs += verbs
	if (mob)
		all_verbs += mob.verbs

	var/list/admin_categories = list("Admin", "Debug", "Bans", "Special", "Fun")
	var/list/server_categories = list("Server","Nomads","Magic","Map Controls")
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
			var/display_name = replacetext(replacetext(v_name, "\"", "'"), "\n", " ")
			verbs_data += list(list("name" = display_name, "command" = v_name, "category" = v_category))
		
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
	if(href_list["action"] == "refocus_map")
		winset(src, "mapwindow.map", "focus=true")
		return

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
	if (href_list["select_spell"] || href_list["action"] == "select_spell")
		var/datum/spell/S = locate(href_list["select_spell"])
		if (istype(S) && ishuman(mob))
			var/mob/living/human/H = mob
			var/obj/item/weapon/material/magic/wand/W = null
			if (H.l_hand && istype(H.l_hand, /obj/item/weapon/material/magic/wand))
				W = H.l_hand
			else if (H.r_hand && istype(H.r_hand, /obj/item/weapon/material/magic/wand))
				W = H.r_hand
			if (W)
				var/list/usable = W.get_usable_spells(mob)
				if (S in usable)
					W.active_spell = S
					to_chat(mob, SPAN_NOTICE("Spell set to <b>[S.name]</b>!"))
					mob.Stat()
					update_statpanel()
				else
					to_chat(mob, SPAN_WARNING("You cannot use that spell!"))
			else
				to_chat(mob, SPAN_WARNING("You need to hold a magic wand to select a spell!"))
		return
	return ..()
