/var/list/all_ui_styles = list(
	"1713Style",
	"NewStyle",
	"LiteWebStyle",
	"FoFStyle",
	)

/client/verb/change_ui()
	set name = "ChangeHUD"
	set category = "OOC"
	set desc = "Configure your user interface"

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

	prefs.save_preferences()
	usr:regenerate_icons()
