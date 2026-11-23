// A completely inert draught editor, rendered with ordinary browser links.
#define CONTRAPTION_WINDOW "contraption_designer"

/proc/contraption_designers()
	var/static/list/open = list()
	return open

/obj/item/ship_draught/proc/open_contraption_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src) || (H.get_active_hand() != src && H.get_inactive_hand() != src) || persistence_admission_blocked())
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil, and try again when the world is ready."))
		return
	var/datum/contraption_plan/D = contraption_plan()
	if (!D && draught_code)
		return
	var/list/open = contraption_designers()
	if (open[H])
		qdel(open[H])
	var/datum/contraption_designer/E = new
	E.drawer = H
	E.connection = H.client
	E.sheet = src
	E.paper_code = draught_code
	E.plan = D ? D : new /datum/contraption_plan
	E.admission = persistence_admission_identity
	open[H] = E
	E.render()

/datum/contraption_designer
	var/mob/living/human/drawer
	var/client/connection
	var/obj/item/ship_draught/sheet
	var/paper_code
	var/datum/admission
	var/datum/contraption_plan/plan
	var/tool = "L"
	var/selection
	var/status = ""
	var/next_action = 0
	var/importing = FALSE

/datum/contraption_designer/Destroy()
	var/list/open = contraption_designers()
	if (open[drawer] == src)
		open -= drawer
	drawer = null
	connection = null
	sheet = null
	admission = null
	if (plan)
		qdel(plan)
		plan = null
	return ..()

/datum/contraption_designer/proc/can_edit(mob/living/human/H)
	return H == drawer && connection && H.client == connection && connection.mob == H && contraption_designers()[H] == src && ship_designer_can_draw(H, sheet) && (H.get_active_hand() == sheet || H.get_inactive_hand() == sheet) && sheet.draught_code == paper_code && !persistence_admission_changed(admission)

// All passed action/detail values used by this helper are server-generated.
/datum/contraption_designer/proc/action_link(action, label, detail = "")
	return "<a href='?src=\ref[src];contraption=[action];detail=[detail]'>[html_encode(label)]</a>"

/datum/contraption_designer/proc/render()
	var/list/parts = contraption_plan_parts()
	var/list/help = design_part_help_for("contraption_plan")
	var/list/html = list({"<html><head><meta charset='utf-8'><style>
body{background:#27221b;color:#efe4cc;font:14px Verdana,sans-serif;padding:6px}
a{color:#f4d59f} table{border-collapse:collapse;text-align:center}
td{border:1px solid #79654d;width:28px;height:26px} .sel{background:#614e35}
.tag{color:#dfab68}li{padding-bottom:2px}</style></head><body>"})
	html += "<b>[html_encode(plan.name)]</b> &middot; Contraptions Planner<br>Draw mechanisms and preview a pull before tying anything. North is up.<p>"
	for (var/key in parts)
		var/list/row = parts[key]
		html += "[action_link("tool", "[key] [row["name"]]", key)] &nbsp;"
	html += "<br>[action_link("tool", "Tie cord", "tie")] &middot; [action_link("tool", "Erase part", "erase")] &middot; [action_link("tool", "Test pull or throw over", "test")] &middot; [action_link("tool", "Test throwing back", "back")]"
	html += "<br>[action_link("sample", "Bell example", "bell")] &middot; [action_link("sample", "Portcullis example", "gate")] &middot; [action_link("sample", "Sluice example", "sluice")] (replaces this draft only)"
	html += "<br>[action_link("save", "Save on this sheet")] &middot; [action_link("export", "Export last saved design")] &middot; [action_link("import", "Import design")]<p>"
	var/list/description = help[tool]
	if (description)
		html += "<span class='tag'>[html_encode(description["what"])]: [html_encode(description["how"])]</span>"
	else
		html += "<span class='tag'>Mode: [html_encode(tool)]. [selection ? "Now pick an actuator tile." : (tool == "tie" ? "Pick a trigger tile first." : "Pick a tile.")]</span>"
	html += "<table><tr><th></th>"
	for (var/x = 1, x <= CONTRAPTION_PLAN_SIDE, x++)
		html += "<th>[x]</th>"
	html += "</tr>"
	for (var/y = 1, y <= CONTRAPTION_PLAN_SIDE, y++)
		html += "<tr><th>[y]</th>"
		for (var/x = 1, x <= CONTRAPTION_PLAN_SIDE, x++)
			var/cell = "[x],[y]"
			var/part = plan.cells[cell]
			html += "<td[selection == cell ? " class='sel'" : ""]>[action_link("cell", part ? part : ".", cell)]</td>"
		html += "</tr>"
	html += "</table><p><b>Result</b><br>[html_encode(status)]<p><b>Cords ([plan.cords.len] rope when built by hand)</b><ul>"
	for (var/key in plan.cords)
		var/list/ends = plan.cords[key]
		html += "<li>[ends[1]] &rarr; [ends[2]] [action_link("cut", "Remove", key)]</li>"
	html += "</ul><b>Parts</b><ul>"
	var/list/counts = list()
	for (var/cell in plan.cells)
		counts[plan.cells[cell]] = counts[plan.cells[cell]] + 1
	for (var/key in counts)
		html += "<li>[counts[key]] &times; [parts[key]["name"]]</li>"
	html += "</ul><b>Checks</b><ul>"
	var/datum/design_report/R = plan.check_design()
	for (var/datum/design_finding/F in R.findings)
		var/location = F.cells ? " ([jointext(F.cells, " / ")])" : ""
		html += "<li>[design_level_name(F.level)] [html_encode(F.text)][html_encode(location)]</li>"
	if (!R.findings.len)
		html += "<li>No layout problems found. Real gates, clearance, locks and cooldown still apply.</li>"
	qdel(R)
	html += "</ul></body></html>"
	show_browse(drawer, jointext(html, ""), "window=[CONTRAPTION_WINDOW];size=780x640")
	onclose(drawer, CONTRAPTION_WINDOW, src)

/datum/contraption_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer && H.client == connection)
			qdel(src)
		return
	var/action = href_list["contraption"]
	var/detail = href_list["detail"]
	if (!istext(action) || length(action) > 6 || (detail && (!istext(detail) || length(detail) > 11)) || !can_edit(H) || importing || world.time < next_action)
		return
	next_action = world.time + 2
	if (href_list["contraption"] == "import")
		importing = TRUE
		sheet.draught_import_in_window(H, CONTRAPTION_WINDOW, src)
		if (!QDELETED(src))
			importing = FALSE
		return
	switch (action)
		if ("tool")
			if (!contraption_plan_parts()[detail] && !(detail in list("tie", "erase", "test", "back")))
				return
			tool = detail
			selection = null
			status = ""
		if ("cell")
			if (!contraption_plan_cell_valid(detail))
				return
			work_cell(detail)
		if ("cut")
			if (!plan.cords[detail])
				return
			plan.cords -= detail
			status = "Cord removed from the drawing."
		if ("sample")
			var/sample
			switch (detail)
				if ("bell")
					sample = "C13MECH/1/Doorway_bell/2,2,P;5,2,B/2,2,5,2"
				if ("gate")
					sample = "C13MECH/1/Lever_portcullis/2,2,L;6,2,W;7,2,G/2,2,6,2"
				if ("sluice")
					sample = "C13MECH/1/Lever_sluice/2,2,L;6,2,S/2,2,6,2"
			if (!sample)
				return
			var/datum/contraption_plan/D = contraption_plan_from_code(sample)
			if (!D)
				return
			qdel(plan)
			plan = D
			selection = null
			status = "Example loaded. The sheet has not changed."
		if ("save")
			sheet.take_contraption(plan)
			paper_code = sheet.draught_code
			status = "Drawing saved on the sheet. No mechanism was built or operated."
		if ("export")
			var/datum/contraption_plan/saved = sheet.contraption_plan()
			if (!saved)
				status = "There is no saved drawing to export yet."
			else
				sheet.draught_export(H, saved.name)
				qdel(saved)
				return
		else
			return
	render()

/datum/contraption_designer/proc/work_cell(cell)
	switch (tool)
		if ("erase")
			plan.erase(cell)
			status = "Tile erased; its cords were removed."
		if ("tie")
			if (!selection)
				if (plan.role(cell) != "trigger")
					status = "Choose a trigger first."
					return
				selection = cell
				status = "Now choose its actuator."
			else
				status = plan.tie(selection, cell) ? "Cord drawn. Check the layout before building." : "Pick a valid actuator with no duplicate cord."
				selection = null
		if ("test", "back")
			var/list/words = plan.forecast(cell, tool == "back")
			status = words.len ? jointext(words, " ") : "No connected action for this tile and test mode."
		else
			status = plan.place(cell, tool) ? "Part drawn." : "The sheet has no room for another part."

/obj/item/ship_draught/proc/contraption_sheet_menu(mob/living/human/H, datum/contraption_plan/D)
	var/paper_code = draught_code
	var/datum/admission = persistence_admission_identity
	var/choice = WWinput(H, "Review or redraw this contraption, or share its design code.", name, "Cancel", list("Open Contraptions Planner", DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel"))
	if (QDELETED(src) || !ship_designer_can_draw(H, src) || (H.get_active_hand() != src && H.get_inactive_hand() != src) || draught_code != paper_code || persistence_admission_changed(admission))
		return
	switch (choice)
		if ("Open Contraptions Planner")
			open_contraption_designer(H)
		if (DRAUGHT_EXPORT_LABEL)
			draught_export(H, D.name)
		if (DRAUGHT_IMPORT_LABEL)
			draught_import(H)

#undef CONTRAPTION_WINDOW
