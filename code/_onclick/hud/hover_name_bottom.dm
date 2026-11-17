// Hover Text Position "bottom" (chat feedback, 2026-11-17): the hover name as
// a status line centred above the bottom HUD row, as it used to be, instead
// of a panel at the pointer. Chosen in Settings > Controls and HUD, at first
// join, or with OOC > Hover Text Position (prefs.hover_text_bottom).

// Where a panel panel_w pixels wide sits as a bottom status line in a view
// view_w pixels wide: centred, just above the bottom HUD row.
/proc/hover_name_bottom_loc(view_w, panel_w)
	var/x = max(1, round((view_w - panel_w) / 2, 1) + 1)
	var/tx = round(x / 32)
	return "[tx + 1]:[x - tx * 32],2:4"

/obj/screen/hover_name/follow_pointer()
	var/client/C = parentmob?.client
	if (!C || !C.prefs || !C.prefs.hover_text_bottom)
		return ..()
	var/list/size = getviewsize(C.view)
	var/bottom_loc = hover_name_bottom_loc(size[1] * 32, hover_text_width)
	if (bottom_loc != screen_loc)
		screen_loc = bottom_loc
