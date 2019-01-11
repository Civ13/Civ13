/datum/category_item/player_setup_item/player_global/ui
	name = "UI"
	sort_order = TRUE

/datum/category_item/player_setup_item/player_global/ui/sanitize_preferences()
	pref.UI_style		= sanitize_inlist(pref.UI_style, all_ui_styles, initial(pref.UI_style))
	pref.ooccolor		= sanitize_hexcolor(pref.ooccolor, initial(pref.ooccolor))
	pref.lobby_music_volume		= sanitize_integer(pref.ooccolor, 1, 100, initial(pref.ooccolor))

/datum/category_item/player_setup_item/player_global/ui/content(var/mob/user)
//	. += "<b>UI Settings</b><br><br>"
//	. += "<b>UI Style:</b> <a href='?src=\ref[src];select_style=1'><b>[pref.UI_style]</b></a><br>"
/*
	if (can_select_ooc_color(user))
		. += "<b>OOC Color:</b> "
		if (pref.ooccolor == initial(pref.ooccolor))
			. += "<a href='?src=\ref[src];select_ooc_color=1'><b>Using Default</b></a><br><br>"
		else
			. += "<a href='?src=\ref[src];select_ooc_color=1'><b>[pref.ooccolor]</b></a> <table style='display:inline;' bgcolor='[pref.ooccolor]'><tr><td>__</td></tr></table> <a href='?src=\ref[src];reset=ooc'>reset</a><br>" // only one linebreak needed here
*/
//	. += "<b>Lobby Music Volume:</b> <a href='?src=\ref[src];change_lobby_music_volume=1'><b>[pref.lobby_music_volume]%</b></a><br>"
//	. += "<br>"

/datum/category_item/player_setup_item/player_global/ui/OnTopic(var/href,var/list/href_list, var/mob/user)
	if (href_list["select_style"])
		var/UI_style_new = input(user, "Choose UI style.", "Character Preference", pref.UI_style) as null|anything in all_ui_styles
		if (!UI_style_new || !CanUseTopic(user)) return TOPIC_NOACTION
		pref.UI_style = UI_style_new
		return TOPIC_REFRESH

	else if (href_list["select_ooc_color"])
		var/new_ooccolor = input(user, "Choose OOC color:", "Global Preference") as color|null
		if (new_ooccolor && can_select_ooc_color(user) && CanUseTopic(user))
			pref.ooccolor = new_ooccolor
			return TOPIC_REFRESH

	else if (href_list["change_lobby_music_volume"])
		pref.lobby_music_volume = input(user, "Select a new volume (1 - 100)", "Lobby Music Volume", pref.lobby_music_volume) as num
		pref.lobby_music_volume = Clamp(pref.lobby_music_volume, 1, 100)
		if (pref.client)
			pref.client.onload_preferences("SOUND_LOBBY")
		return TOPIC_REFRESH

	else if (href_list["reset"])
		switch(href_list["reset"])
			if ("ooc")
				pref.ooccolor = initial(pref.ooccolor)
		return TOPIC_REFRESH

	return ..()

/datum/category_item/player_setup_item/player_global/ui/proc/can_select_ooc_color(var/mob/user)
	return ((config.allow_admin_ooccolor && check_rights(R_ADMIN, FALSE, user)))
