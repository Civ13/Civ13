// The generic panel window (tgui/src/interfaces/Panel.tsx): a simple machine or
// menu describes sections of notes, labelled rows, item lists and buttons, and
// needs no screen of its own. The owner still declares the actions its buttons
// may send in ui_actions() and handles them in ui_act() or its Topic().

// A button that sends action with value. A text value is an identifier and is
// sent back exactly as given.
/proc/panel_button(label, action, value = 1, disabled = FALSE, selected = FALSE)
	. = list("label" = "[label]", "action" = action, "id" = value)
	if (disabled)
		.["disabled"] = 1
	if (selected)
		.["selected"] = 1

// A labelled value. tone marks its meaning: good, warn, info, ready, progress or muted.
/proc/panel_row(label, value, tone, list/buttons)
	. = list("label" = "[label]", "value" = value)
	if (tone)
		.["tone"] = tone
	if (buttons)
		.["buttons"] = buttons

// One line of an item list with its own buttons.
/proc/panel_item(name, detail, list/buttons)
	. = list("name" = "[name]")
	if (detail)
		.["detail"] = "[detail]"
	if (buttons)
		.["buttons"] = buttons

// A table cell that carries a tone as well as its text.
/proc/panel_cell(text, tone)
	. = list("text" = "[text]")
	if (tone)
		.["tone"] = tone

// A table: columns is a list of headings, rows a list of lists of cells. A cell
// is text, a number or a panel_cell().
/proc/panel_table(list/columns, list/rows)
	return list("columns" = columns, "rows" = rows)

// One line of a chart: points are numbers, oldest first. tone colours it.
/proc/panel_series(label, tone, list/points)
	return list("label" = "[label]", "tone" = tone, "points" = points)

// A line chart of up to slots points per series, newest at the right edge.
// top labels the highest value, left and right the ends of the time axis.
/proc/panel_chart(list/series, slots, top, left, right)
	return list("series" = series, "slots" = slots, "top" = "[top]", "left" = "[left]", "right" = "[right]")

// empty is shown when the section has no rows, items or table rows.
/proc/panel_section(title, list/notes, list/rows, list/items, list/buttons, empty, list/table, list/chart)
	. = list()
	if (title)
		.["title"] = "[title]"
	if (notes)
		.["notes"] = notes
	if (rows)
		.["rows"] = rows
	if (items)
		.["items"] = items
	if (buttons)
		.["buttons"] = buttons
	if (empty)
		.["empty"] = "[empty]"
	if (table)
		.["table"] = table
	if (chart)
		.["chart"] = chart

// Opens or refreshes this owner's panel. sections is a list of panel_section().
/datum/proc/open_panel(mob/user, title, width, height, list/sections, list/notes, ui_key = "main", datum/nanoui/ui, force_open = TRUE, state, auto_update = FALSE)
	var/list/data = list("sections" = sections)
	if (notes)
		data["notes"] = notes
	return open_tgui(user, ui_key, "panel.tmpl", title, width, height, data, ui, force_open, state, FALSE, auto_update)
