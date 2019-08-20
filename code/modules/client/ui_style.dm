/var/list/all_ui_styles = list(
	"1713Style",
	"NewStyle",
	"LiteWebStyle",
	"FoFStyle",
	)

/client/verb/change_ui()
	set name = "ChangeHUD"
	set category = "OOC"
	set desc = "Configure your user interface."

	if (!ishuman(usr))
		usr << "<span class='warning'>You must be human to use this verb.</span>"
		return
	var/UI_style_new = prefs.UI_style
	if (all_ui_styles.len > 2)
		UI_style_new = input(usr, "Select a style:") as null|anything in all_ui_styles
	else
		if (all_ui_styles[1] == UI_style_new)
			UI_style_new = all_ui_styles[2]
		else
			UI_style_new = all_ui_styles[1]
	if (UI_style_new)
		prefs.UI_style = UI_style_new
		var/datum/hud/currhud = global.HUDdatums[UI_style_new]
		if (currhud)
			prefs.UI_file = currhud.icon
	prefs.save_preferences()
	usr:regenerate_icons()


/client/verb/change_cursor()
	set name = "Change Cursor"
	set category = "OOC"
	set desc = "Configure your mouse cursor."
//	set hidden = TRUE

	var/choice = WWinput(usr, "Which style?", "Mouse Cursor", "Default", list("Default","Red Crosshair","Green Crosshair","White Crosshair"))
	if (choice == "Default")
		mouse_pointer_icon = initial(mouse_pointer_icon)
	else if (choice == "Red Crosshair")
		mouse_pointer_icon = 'icons/effects/red_cursors.dmi'
	else if (choice == "White Crosshair")
		mouse_pointer_icon = 'icons/effects/white_cursors.dmi'
	else if (choice == "Green Crosshair")
		mouse_pointer_icon = 'icons/effects/green_cursors.dmi'
	else
		mouse_pointer_icon = initial(mouse_pointer_icon)
	prefs.cursor = mouse_pointer_icon
	prefs.save_preferences()
	return