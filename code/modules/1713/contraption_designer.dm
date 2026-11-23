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
	// Same palette as the house, rail and waterworks planners: dark page,
	// button-style links, parchment sheet. Links only; this window has no script.
	var/list/html = list({"<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Contraptions Planner</title><style>
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:10px}
h1{font-size:17px;margin:0 0 6px 0} h2{font-size:13px;color:#ffd985;margin:10px 0 4px 0}
p{margin:6px 0;line-height:1.4} .hint{color:#c5b48e}
a{display:inline-block;margin:0 3px 3px 0;padding:3px 7px;color:#e9dfc8;background:#4a3a2a;border:1px solid #806040;text-decoration:none}
a:hover,a:focus{border-color:#ffd985}
.on a{background:#b48c4d;color:#211c16;border-color:#ffd985;font-weight:bold}
.lbl{display:inline-block;width:62px;color:#c5b48e}
#grid{border-collapse:collapse;text-align:center;margin:6px 0}
#grid th{color:#c5b48e;font-weight:normal;font-size:11px;padding:0 4px}
#grid td{border:1px solid #b19c73;background:#d9c9a3;padding:0}
#grid td a{display:block;width:30px;height:26px;line-height:26px;margin:0;padding:0;border:0;background:transparent;color:#8a7a55}
#grid td a:hover,#grid td a:focus{background:#c4b184}
#grid td.part a{color:#fff;background:#17505f;font-weight:bold}
#grid td.sel a{color:#211c16;background:#ffd985;font-weight:bold}
.key span{display:inline-block;white-space:nowrap;margin:0 10px 3px 0;color:#c5b48e}
.key b{display:inline-block;width:18px;height:18px;line-height:18px;margin-right:4px;text-align:center;border:1px solid #b19c73;vertical-align:middle}
.k0{background:#d9c9a3;color:#8a7a55}.k1{background:#17505f;color:#fff}.k2{background:#ffd985;color:#211c16}
.tag{color:#ffd985}
ul{margin:0;padding-left:18px} li{padding:2px 0} li a{margin:0 0 0 6px;padding:1px 6px}
.error{color:#ffb098}.warning{color:#f5da8c}.note{color:#c5b48e}
</style></head><body>"})
	html += "<h1>Contraptions Planner</h1><p><b>[html_encode(plan.name)]</b></p><p class='hint'>Draw mechanisms and preview a pull before tying anything. North is up.</p>"
	// The current tool is highlighted like a pressed button.
	html += "<p><span class='lbl'>Place</span>"
	for (var/key in parts)
		var/list/row = parts[key]
		var/place_link = action_link("tool", "[key] [row["name"]]", key)
		html += tool == key ? "<span class='on'>[place_link]</span>" : place_link
	html += "<br><span class='lbl'>Tools</span>"
	var/static/list/tools = list("tie" = "Tie cord", "erase" = "Erase part", "test" = "Test pull or throw over", "back" = "Test throwing back")
	for (var/key in tools)
		var/tool_link = action_link("tool", tools[key], key)
		html += tool == key ? "<span class='on'>[tool_link]</span>" : tool_link
	html += "<br><span class='lbl'>Examples</span>[action_link("sample", "Bell example", "bell")][action_link("sample", "Portcullis example", "gate")][action_link("sample", "Sluice example", "sluice")] <span class='hint'>(replaces this draft only)</span>"
	html += "<br><span class='lbl'>Sheet</span>[action_link("save", "Save on this sheet")][action_link("export", "Export last saved design")][action_link("import", "Import design")]</p>"
	var/list/description = help[tool]
	if (description)
		html += "<p class='tag'>[html_encode(description["what"])]: [html_encode(description["how"])]</p>"
	else
		html += "<p class='tag'>Mode: [html_encode(tool)]. [selection ? "Now pick an actuator tile." : (tool == "tie" ? "Pick a trigger tile first." : "Pick a tile.")]</p>"
	html += "<table id='grid' aria-label='Contraption drawing, north at the top'><tr><th></th>"
	for (var/x = 1, x <= CONTRAPTION_PLAN_SIDE, x++)
		html += "<th>[x]</th>"
	html += "</tr>"
	for (var/y = 1, y <= CONTRAPTION_PLAN_SIDE, y++)
		html += "<tr><th>[y]</th>"
		for (var/x = 1, x <= CONTRAPTION_PLAN_SIDE, x++)
			var/cell = "[x],[y]"
			var/part = plan.cells[cell]
			var/list/part_row = part ? parts[part] : null
			var/cell_title = html_encode("Tile [cell]: [part_row ? part_row["name"] : "empty"]")
			html += "<td[selection == cell ? " class='sel'" : (part ? " class='part'" : "")] title='[cell_title]'>[action_link("cell", part ? part : ".", cell)]</td>"
		html += "</tr>"
	html += "</table><p class='key' aria-label='Tile key'><span><b class='k0'>.</b>empty tile</span><span><b class='k1'>L</b>placed part, shown by the letter on its Place button</span><span><b class='k2'>L</b>trigger chosen for a cord</span></p>"
	html += "<p class='hint'>Tile numbers read column, then row, as used in the lists below.</p>"
	html += "<h2>Result</h2><p>[html_encode(status)]</p><h2>Cords ([plan.cords.len] rope when built by hand)</h2><ul>"
	for (var/key in plan.cords)
		var/list/ends = plan.cords[key]
		html += "<li>[html_encode(ends[1])] &rarr; [html_encode(ends[2])] [action_link("cut", "Remove", key)]</li>"
	if (!plan.cords.len)
		html += "<li class='note'>No cords tied yet.</li>"
	html += "</ul><h2>Parts</h2><ul>"
	var/list/counts = list()
	for (var/cell in plan.cells)
		counts[plan.cells[cell]] = counts[plan.cells[cell]] + 1
	for (var/key in counts)
		html += "<li>[counts[key]] &times; [html_encode(parts[key]["name"])]</li>"
	if (!counts.len)
		html += "<li class='note'>No parts placed yet.</li>"
	html += "</ul><h2>Checks</h2><ul>"
	var/datum/design_report/R = plan.check_design()
	for (var/datum/design_finding/F in R.findings)
		var/location = F.cells ? " ([jointext(F.cells, " / ")])" : ""
		var/level = design_level_name(F.level)
		html += "<li class='[level]'><b>[capitalize(level)]:</b> [html_encode(F.text)][html_encode(location)]</li>"
	if (!R.findings.len)
		html += "<li class='note'>No layout problems found. Real gates, clearance, locks and cooldown still apply.</li>"
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
		sheet.draught_import_in_window(H, CONTRAPTION_WINDOW, CALLBACK(src, PROC_REF(can_edit), H))
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
