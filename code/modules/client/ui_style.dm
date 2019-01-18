/var/all_ui_styles = list(
	"1713Style",
	)


/proc/ui_style2icon(ui_style)
	if (ui_style in all_ui_styles)
		return all_ui_styles[ui_style]
	return all_ui_styles["White"]
