// Harbor survey sheet: relative layout only. The site is supplied by the
// surveyor's present position; no map state or build permission is saved.

#define HARBOR_WINDOW "harbor_designer"
#define HARBOR_CODE_MAX 48
#define HARBOR_SLIDE 12

/proc/harbor_parts()
	var/static/list/parts = list("timber", "steel", "slip", "dock", "boathouse")
	return parts

/proc/harbor_profile(kind)
	switch (kind)
		if ("freighter")
			return /datum/vessel/freighter
	return /datum/vessel/schooner

/datum/harbor_plan
	var/name = "Harbor plan"
	var/part = "timber"
	var/length = 6
	var/width = 1
	var/hull = "schooner"
	var/tmp/turf/site
	var/tmp/list/survey_seen
	var/tmp/heading = NORTH

/datum/harbor_plan/proc/use_part(new_part)
	part = new_part
	switch (part)
		if ("timber", "steel")
			length = 6
			width = 1
		if ("slip")
			use_hull(hull)
		if ("dock")
			length = 16
			width = 7
		if ("boathouse")
			length = 7
			width = 7

/datum/harbor_plan/proc/use_hull(new_hull)
	hull = new_hull
	if (part == "slip")
		var/datum/vessel/profile = harbor_profile(hull)
		length = initial(profile.length)
		width = initial(profile.beam)

/datum/harbor_plan/proc/to_code()
	return "C13HARBOR/1/[part]/[length]/[width]/[hull]"

/proc/harbor_plan_from_code(code)
	if (!istext(code) || length(code) > HARBOR_CODE_MAX)
		return null
	var/list/fields = design_code_fields(code, "HARBOR", HARBOR_CODE_MAX)
	if (!fields || fields.len != 4 || !(fields[1] in harbor_parts()) || !(fields[4] in list("schooner", "freighter")))
		return null
	var/len_value = text2num(fields[2])
	var/beam_value = text2num(fields[3])
	if ("[len_value]" != fields[2] || "[beam_value]" != fields[3])
		return null
	switch (fields[1])
		if ("timber", "steel")
			if (len_value < 1 || len_value > 12 || beam_value != 1)
				return null
		if ("slip")
			var/datum/vessel/profile = harbor_profile(fields[4])
			if (len_value != initial(profile.length) || beam_value != initial(profile.beam))
				return null
		if ("dock")
			if (len_value < 4 || len_value > 24 || !(beam_value in list(3, 5, 7, 9, 11)))
				return null
		if ("boathouse")
			if (len_value != 7 || beam_value != 7)
				return null
	var/datum/harbor_plan/D = new
	D.part = fields[1]
	D.length = len_value
	D.width = beam_value
	D.hull = fields[4]
	return D

/datum/harbor_plan/proc/summary_text()
	var/list/help = design_part_help_for("harbor")
	var/list/entry = help[part]
	return "[entry["what"]] [length] by [width] tiles."

/datum/harbor_plan/proc/check_design()
	return design_report("harbor", src)

// Coordinates on a relative footprint, not player-provided world addresses.
/datum/harbor_plan/proc/tile(u, v = 0)
	if (!site || !(heading in cardinal))
		return null
	if (part == "boathouse")
		// The slip begins one tile along each arm of the selected corner.
		v += 4
		switch (heading)
			if (NORTH) return locate(site.x + v, site.y + u, site.z)
			if (EAST) return locate(site.x + u, site.y - v, site.z)
			if (SOUTH) return locate(site.x - v, site.y - u, site.z)
			if (WEST) return locate(site.x - u, site.y + v, site.z)
	switch (heading)
		if (NORTH) return locate(site.x + v, site.y + u, site.z)
		if (EAST) return locate(site.x + u, site.y - v, site.z)
		if (SOUTH) return locate(site.x - v, site.y - u, site.z)
		if (WEST) return locate(site.x - u, site.y + v, site.z)
	return null

/datum/harbor_plan/proc/survey_can_read(turf/T)
	return T && survey_seen && survey_seen[T]

/proc/harbor_depth(turf/T)
	if (!T)
		return "edge"
	if (istype(T, /turf/floor/beach/water/ice))
		return "ice"
	if (istype(T, /turf/floor/beach/water/deep/saltwater/underwater))
		return "below"
	if (istype(T, /turf/floor/beach/water/deep))
		return "deep"
	if (istype(T, /turf/floor/trench/flooded))
		return "flooded"
	if (istype(T, /turf/floor/trench))
		return "trench"
	if (is_liquid_water(T))
		return "shallow"
	return T.density ? "solid" : "land"

/proc/harbor_obstructed(turf/T, pier = FALSE)
	if (!T || T.density)
		return TRUE
	if (pier && (locate(/obj/covers) in T))
		return TRUE
	for (var/atom/movable/A in T)
		if (A.loc != T || QDELETED(A) || isliving(A) || istype(A, /atom/movable/lighting_overlay))
			continue
		if (A.density || istype(A, /obj/structure/slipway_frame) || (pier && (istype(A, /obj/structure/vehicleparts) || istype(A, /obj/structure/vehicle))))
			return TRUE
	return FALSE

/datum/design_check/harbor
	kind = "harbor"
	abstract_type = /datum/design_check/harbor

/datum/design_check/harbor/site
	order = 10

/datum/design_check/harbor/site/check(datum/D, datum/design_report/R)
	var/datum/harbor_plan/P = D
	if (!istype(P) || !P.site)
		R.note("Stand at the proposed site and use Survey from here to check the current terrain.")
		return
	if (!P.survey_can_read(P.site))
		R.note("The survey anchor is outside your current view; it has not been checked.")
		return
	if (P.part in list("slip", "boathouse"))
		if (harbor_depth(P.site) != "land")
			R.error("Choose dry, open ground for the post or boathouse.", part = P.part)
	else if (P.part == "dock")
		var/depth = harbor_depth(P.site)
		if (!(depth in list("land", "trench", "flooded")))
			R.error("Put the gate at the future basin mouth, not out in open water.", part = P.part)
		var/turf/approach = get_step(P.site, turn(P.heading, 180))
		if (!P.survey_can_read(approach))
			R.note("The tile behind the gate is outside your current view.", part = P.part)
		else if (!is_open_water(approach))
			R.warning("The tile behind the gate does not have open water now.", part = P.part)
	else if (!(harbor_depth(P.site) in list("land", "shallow")) && !bridge_deck_at(P.site))
		R.error("Start on the bank, in shallows or on an existing bridge deck.", part = P.part)

/datum/design_check/harbor/footprint
	order = 20

/datum/design_check/harbor/footprint/check(datum/D, datum/design_report/R)
	var/datum/harbor_plan/P = D
	if (!istype(P) || !P.site)
		return
	var/pier = P.part in list("timber", "steel")
	var/list/blocked = list()
	var/list/unfinished = list()
	var/list/unknown = list()
	var/end = (P.width - 1) / 2
	for (var/u = 1; u <= P.length; u++)
		for (var/v = -end; v <= end; v++)
			var/turf/T = P.tile(u, v)
			if (!P.survey_can_read(T))
				unknown += "[u],[v]"
				continue
			var/depth = harbor_depth(T)
			if (pier && bridge_deck_at(T))
				continue // an existing span can provide footing for later work
			if (harbor_obstructed(T, pier))
				blocked += "[u],[v]"
				continue
			switch (P.part)
				if ("timber", "steel")
					if (depth != "shallow" && !(P.part == "steel" && depth == "deep"))
						blocked += "[u],[v]"
				if ("slip")
					if (!slipway_ground(T) || vessel_at(T))
						blocked += "[u],[v]"
					else if (depth == "trench")
						unfinished += "[u],[v]"
				if ("dock")
					if (!(depth in list("land", "trench", "flooded")))
						blocked += "[u],[v]"
					else if (depth == "land")
						unfinished += "[u],[v]"
				if ("boathouse")
					if (!is_open_water(T) || depth == "below")
						blocked += "[u],[v]"
	if (blocked.len)
		R.error("Some visible footprint tiles are blocked or the wrong ground or depth for this part.", blocked, P.part)
	if (unknown.len)
		R.note("Some footprint tiles are outside your current view and have not been checked.", unknown, P.part)
	if (unfinished.len)
		R.note(P.part == "dock" ? "Dig these basin tiles before fitting the gate." : "Flood these trench tiles before launching.", unfinished, P.part)

/datum/design_check/harbor/access
	order = 30

/datum/design_check/harbor/access/check(datum/D, datum/design_report/R)
	var/datum/harbor_plan/P = D
	if (!istype(P))
		return
	if (P.part == "dock")
		var/datum/vessel/profile = harbor_profile(P.hull)
		if (P.length < initial(profile.length) || P.width < initial(profile.beam))
			R.error("The basin rectangle is too small for the selected hull envelope.", part = P.part)
		if (P.site)
			var/list/basin = list()
			var/list/current_escapes = list()
			var/unknown_edge = FALSE
			var/end = (P.width - 1) / 2
			for (var/u = 1; u <= P.length; u++)
				for (var/v = -end; v <= end; v++)
					var/turf/T = P.tile(u, v)
					if (T)
						basin[T] = "[u],[v]"
			for (var/turf/T in basin)
				for (var/turf/N in range(1, T))
					if (N == P.site || basin[N])
						continue
					if (!P.survey_can_read(T) || !P.survey_can_read(N))
						unknown_edge = TRUE
						continue
					if (is_open_water(N))
						current_escapes |= basin[T]
			if (unknown_edge)
				R.note("The basin perimeter extends out of your view. It has not been fully checked for leaks.", part = P.part)
			if (current_escapes.len)
				R.error("Open water touches the proposed basin somewhere other than its gate. Include diagonal leaks when closing the banks.", current_escapes, P.part)
		R.note("One gate is marked. Fit additional gates across a wider mouth when needed; only a live dock gate can survey the whole connected trench.", part = P.part)
	else if (P.part == "slip" && P.site)
		var/end = (P.width - 1) / 2
		var/run = 0
		var/found = FALSE
		var/clear_ways = TRUE
		var/unknown_way = FALSE
		for (var/u = 1; u <= P.length * 2 + HARBOR_SLIDE; u++)
			var/deep_row = TRUE
			for (var/v = -end; v <= end; v++)
				var/turf/T = P.tile(u, v)
				if (!P.survey_can_read(T))
					unknown_way = TRUE
					deep_row = FALSE
					clear_ways = FALSE
					continue
				var/depth = harbor_depth(T)
				var/obstructed = harbor_obstructed(T, TRUE) || vessel_at(T)
				if (depth != "deep" || obstructed)
					deep_row = FALSE
				if (u > P.length && (obstructed || depth in list("solid", "ice", "below", "trench")))
					clear_ways = FALSE
			run = deep_row ? run + 1 : 0
			if (run == P.length && clear_ways)
				found = TRUE
				break
		if (!found && unknown_way)
			R.note("The full launch route is outside your current view and cannot be verified. The slipway still runs the final launch check.", part = P.part)
		else if (!found)
			R.warning("No clear rectangular deep-water landing found down these ways. The actual hull is shaped; its slipway runs the final launch check.", part = P.part)
		if (P.hull == "freighter")
			R.note("This is a surface survey only; the freighter's hold also needs clearance below.", part = P.part)

/datum/design_part_book/harbor
	kind = "harbor"

/datum/design_part_book/harbor/entries()
	return list(
		"timber" = list("what" = "Timber pier", "use" = "A walking deck over shallow water.", "how" = "Set a pile driver on firm footing. Fit one timber pier span at a time from shore or the last finished span."),
		"steel" = list("what" = "Steel pier", "use" = "A walking deck that can cross deep water.", "how" = "Fit one steel bridge span at a time from the bank or completed deck. This pays no material."),
		"slip" = list("what" = "Shipbuilding slipway", "use" = "Lay a keel and launch bow-first down the marked ways.", "how" = "Build the slipway post, use a wrench to face the water, then choose a keel. Use the post to build in stages and validate the real launch."),
		"dock" = list("what" = "Drydock", "use" = "A closed basin to work on a hull when drained.", "how" = "Dig the basin, put the gate in its flooded mouth, sail in, shut every gate and pump. Open the sluices before sailing out."),
		"boathouse" = list("what" = "Boathouse slip", "use" = "An open 7-by-7 slip for small boats and modular boats, not full slipway ships.", "how" = "Build the boathouse and turn it with a wrench until the corner matches this survey. Sail a stopped boat completely within the marked square."),
	)

// One editor per drawer, like the house and rail designers.
/proc/harbor_designers()
	var/static/list/open
	if (!open)
		open = list()
	return open

/proc/harbor_can_draw(mob/living/human/H, obj/item/ship_draught/S)
	return ship_designer_can_draw(H, S) && H.client.mob == H && S.loc == H && (H.get_active_hand() == S || H.get_inactive_hand() == S) && !persistence_admission_blocked()

/datum/harbor_designer
	var/mob/living/human/drawer
	var/client/viewer
	var/datum/admission
	var/saved_code
	var/import_pending = FALSE
	var/obj/item/ship_draught/sheet
	var/datum/harbor_plan/plan
	var/next_input = 0

/datum/harbor_designer/Destroy()
	var/list/open = harbor_designers()
	if (drawer && open[drawer] == src)
		open -= drawer
	drawer = null
	viewer = null
	admission = null
	sheet = null
	if (plan)
		qdel(plan)
	plan = null
	return ..()

/obj/item/ship_draught/proc/harbor_plan()
	return harbor_plan_from_code(draught_code)

/obj/item/ship_draught/proc/take_harbor(datum/harbor_plan/D)
	draught_code = D.to_code()
	name = "harbor plan"

/obj/item/ship_draught/proc/harbor_sheet_menu(mob/living/human/H, datum/harbor_plan/D)
	if (!harbor_can_draw(H, src))
		return
	var/client/connection = H.client
	var/expected_code = draught_code
	var/datum/admission = persistence_admission_identity
	var/choice = WWinput(H, D.summary_text(), name, "Cancel", list("Open Harbor Planner", DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel"))
	if (!harbor_can_draw(H, src) || H.client != connection || draught_code != expected_code || persistence_admission_changed(admission))
		return
	switch (choice)
		if ("Open Harbor Planner")
			open_harbor_designer(H)
		if (DRAUGHT_EXPORT_LABEL)
			draught_export(H, D.name)
		if (DRAUGHT_IMPORT_LABEL)
			draught_import(H)

/obj/item/ship_draught/proc/open_harbor_designer(mob/living/human/H)
	if (!harbor_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a writing tool to draw on it."))
		return
	if (draught_code && design_code_kind(draught_code) != "HARBOR")
		to_chat(H, SPAN_WARNING("The sheet already holds another drawing."))
		return
	var/list/open = harbor_designers()
	if (open[H])
		qdel(open[H])
	var/datum/harbor_designer/A = new
	A.drawer = H
	A.viewer = H.client
	A.admission = persistence_admission_identity
	A.saved_code = draught_code
	A.sheet = src
	A.plan = harbor_plan()
	if (!A.plan)
		A.plan = new
	open[H] = A
	A.survey_here()
	A.show()
	onclose(H, HARBOR_WINDOW, A)

/datum/harbor_designer/proc/can_edit(mob/living/human/H)
	return istype(H) && H == drawer && H.client == viewer && harbor_designers()[H] == src && plan && harbor_can_draw(H, sheet) && sheet.draught_code == saved_code && !persistence_admission_changed(admission)

/datum/harbor_designer/proc/survey_here()
	plan.site = isturf(drawer.loc) ? drawer.loc : null
	plan.heading = drawer.dir in cardinal ? drawer.dir : NORTH

/datum/harbor_designer/proc/control(label, action, value = "")
	return "<a href='?src=\ref[src];harbor=[action];value=[value]'>[label]</a>"

/datum/harbor_designer/proc/show()
	var/datum/harbor_plan/P = plan
	P.survey_seen = list()
	if (P.site && drawer.loc == P.site && viewer.eye == drawer)
		for (var/turf/T in cartography_visible_turfs(drawer))
			P.survey_seen[T] = TRUE
	var/datum/design_report/R = P.check_design()
	var/list/help = design_part_help_for("harbor")
	var/list/entry = help[P.part]
	var/list/page = list({"
		<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Harbor Planner</title><style>
		body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:10px}
		h2{font-size:17px;margin:0 0 6px 0} h3{font-size:13px;color:#ffd985;margin:8px 0 4px 0} p{margin:6px 0;line-height:1.4}
		a{display:inline-block;margin:0 3px 3px 0;padding:4px 8px;color:#e9dfc8;background:#4a3a2a;border:1px solid #806040;text-decoration:none}
		a:hover,a:focus{border-color:#ffd985}
		.on a{background:#b48c4d;color:#211c16;border-color:#ffd985;font-weight:bold}
		.hint{color:#c5b48e}
		.sheet{background:#30271e;border:1px solid #66513b;padding:8px 10px;margin-top:8px}
		.error{color:#ffb098}.warning{color:#f5da8c}.note{color:#c5b48e}
		.tiles{border-collapse:collapse;font:bold 12px Consolas,monospace;margin:6px 0}
		.tiles th{color:#c5b48e;font-weight:normal;padding:0 5px 0 0;text-align:right}
		.tiles td{width:22px;height:22px;text-align:center;border:1px solid #8a7a55}
		.tiles .runway th{color:#ffd985}.tiles .runway td{border-style:dashed}
		.key span{display:inline-block;white-space:nowrap;margin:0 10px 3px 0}
		.key b{display:inline-block;width:18px;height:18px;line-height:18px;margin-right:4px;text-align:center;border:1px solid #8a7a55;font:bold 12px Consolas,monospace;vertical-align:middle}
		.land,.unseen,.deep,.shallow,.flooded,.trench,.solid,.edge,.below,.ice,.bad{background:#d9c9a3;color:#2a1c0e}
		.unseen{background:#a89c80;color:#2a1c0e}
		.deep{background:#2f5f86;color:#fff}.shallow,.flooded{background:#9cc6cf}
		.trench{background:#b08a55}.solid,.edge,.below{background:#5a554c;color:#fff}
		.ice{background:#eaf3f7}.bad{background:#a63a22;color:#fff}
		</style></head><body><h2>Harbor Planner</h2>
		<p class='hint'>Draw, survey and save a relative layout. This sheet never builds, digs or launches anything.</p>
		<p>
	"})
	// The chosen part and hull are highlighted like a pressed button in the other planners.
	for (var/key in harbor_parts())
		var/list/facts = help[key]
		var/part_control = control(html_encode(facts["what"]), "part", key)
		page += key == P.part ? "<span class='on'>[part_control]</span>" : part_control
	page += "</p>"
	if (P.part in list("slip", "dock"))
		page += "<p>Hull envelope: "
		for (var/hull in list("schooner", "freighter"))
			var/hull_control = control(capitalize(hull), "hull", hull)
			page += hull == P.hull ? "<span class='on'>[hull_control]</span>" : hull_control
		page += "</p>"
	if (P.part in list("timber", "steel", "dock"))
		page += "<p>Length [P.length]: [control("-", "length", "-1")] [control("+", "length", "1")]"
		if (P.part == "dock")
			page += " &nbsp; Width [P.width]: [control("-", "width", "-2")] [control("+", "width", "2")]"
		page += "</p>"
	page += "<p>[control("Rotate", "rotate")] [control("Survey from here", "survey")] [control("Save on sheet", "save")] [control("Export", "export")] [control("Import", "import")]</p>"
	page += "<div class='sheet'><h3>[html_encode(P.summary_text())]</h3><p>[html_encode(entry["use"])] [html_encode(entry["how"])]</p>"
	if (P.part == "timber")
		page += "<p>Materials: [P.length] timber spans ([P.length * 8] wood before any spans already laid), plus a pile driver.</p>"
	else if (P.part == "steel")
		page += "<p>Materials: [P.length] steel spans ([P.length * 4] steel before any spans already laid).</p>"
	else if (P.part == "slip")
		page += "<p>Site: slipway post (20 planks). The ship's materials are paid to the post stage by stage.</p>"
	else if (P.part == "dock")
		page += "<p>Site: [P.length * P.width] tiles of basin, plus the gate tile. Dock gates take 24 stone each. Digging and flooding are separate work.</p>"
	if (P.site)
		var/site_label = P.part == "dock" ? "gate" : (P.part == "boathouse" ? "boathouse" : "start")
		var/direction = dir2text(P.heading)
		if (P.part == "boathouse")
			var/static/list/corners = list("1" = "NORTHEAST", "4" = "SOUTHEAST", "2" = "SOUTHWEST", "8" = "NORTHWEST")
			direction = corners["[P.heading]"]
		page += "<p>Surveyed from the [site_label] tile where you stood | Toward: [direction] | Furthest row at top.</p>"
		var/list/bad = list()
		for (var/datum/design_finding/F in R.findings)
			if (F.level == DESIGN_ERROR && F.cells)
				for (var/cell in F.cells)
					bad[cell] = TRUE
		var/end = (P.width - 1) / 2
		page += "<table class='tiles' aria-label='harbor footprint'>"
		var/survey_length = P.part == "slip" ? P.length * 2 + HARBOR_SLIDE : P.length
		for (var/u = survey_length; u >= 1; u--)
			page += u > P.length ? "<tr class='runway'><th>[u]</th>" : "<tr><th>[u]</th>"
			for (var/v = -end; v <= end; v++)
				var/turf/T = P.tile(u, v)
				var/seen = P.survey_can_read(T)
				var/depth = seen ? harbor_depth(T) : "unseen"
				var/obstruction = seen && (bad["[u],[v]"] || (u > P.length && (harbor_obstructed(T, TRUE) || vessel_at(T) || depth == "trench")))
				var/style = obstruction ? "bad" : depth
				// Solid ground gets X so it never shares the S of shallow water.
				var/label = obstruction ? "!" : seen ? (depth == "solid" ? "X" : uppertext(copytext(depth, 1, 2))) : "?"
				page += "<td class='[style]' title='[obstruction ? "[depth] - investigate" : depth]'>[label]</td>"
			page += "</tr>"
		page += "</table><p class='key' aria-label='Tile key'><span><b class='deep'>D</b>deep water</span><span><b class='shallow'>S</b>shallow water</span><span><b class='flooded'>F</b>flooded trench</span><span><b class='trench'>T</b>dry trench</span><span><b class='ice'>I</b>ice</span><span><b class='land'>L</b>open land</span><span><b class='solid'>X</b>solid ground or wall</span><span><b class='below'>B</b>underwater level</span><span><b class='edge'>E</b>map edge</span><span><b class='bad'>!</b>investigate</span><span><b class='unseen'>?</b>unseen</span></p>"
		page += "<p class='hint'>Unseen tiles are neither clear nor blocked. Deep and shallow are game terrain classes, not measured depths. Row numbers count tiles away from the [site_label]. Hover a tile to read its terrain.</p>"
		if (P.part == "slip")
			page += "<p class='hint'>Dashed rows with gold numbers are the surveyed launch corridor beyond the berth.</p>"
	else
		page += "<p class='hint'>No site surveyed yet. Stand on the starting tile, face the way the work should run, and press Survey from here.</p>"
	page += "<h3>Checks</h3>"
	var/list/listed = R.data()
	if (!listed.len)
		page += "<p class='note'>No obvious blocker in this survey. Follow the actual construction checks.</p>"
	for (var/list/row in listed)
		page += "<p class='[row["level"]]'><b>[capitalize(row["level"])]:</b> [html_encode(row["text"])]</p>"
	page += "</div></body></html>"
	qdel(R)
	P.survey_seen = null
	show_browse(drawer, jointext(page, ""), "window=[HARBOR_WINDOW];size=850x750")

/datum/harbor_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (!istype(H) || H != drawer || H.client != viewer || harbor_designers()[H] != src)
		return
	if (href_list["close"])
		qdel(src)
		return
	if (!can_edit(H))
		to_chat(H, SPAN_WARNING("The drawing session changed. Reopen the sheet while holding it and a writing tool."))
		qdel(src)
		return
	var/action = href_list["harbor"]
	var/value = href_list["value"]
	if (!action || import_pending || world.time < next_input)
		return
	next_input = world.time + 3
	if (plan.site && H.loc != plan.site)
		plan.site = null
	if (href_list["harbor"] == "import")
		import_pending = TRUE
		sheet.draught_import_in_window(H, HARBOR_WINDOW, CALLBACK(src, PROC_REF(can_edit), H))
		if (!QDELETED(src))
			import_pending = FALSE
		return
	switch (action)
		if ("part")
			if (!(value in harbor_parts()))
				return
			plan.use_part(value)
		if ("hull")
			if (!(value in list("schooner", "freighter")))
				return
			plan.use_hull(value)
		if ("length")
			if (!(value in list("-1", "1")) || !(plan.part in list("timber", "steel", "dock")))
				return
			plan.length = clamp(plan.length + text2num(value), plan.part == "dock" ? 4 : 1, plan.part == "dock" ? 24 : 12)
		if ("width")
			if (!(value in list("-2", "2")) || plan.part != "dock")
				return
			plan.width = clamp(plan.width + text2num(value), 3, 11)
		if ("rotate")
			plan.heading = turn(plan.heading, -90)
		if ("survey")
			survey_here()
		if ("save", "export")
			sheet.take_harbor(plan)
			saved_code = sheet.draught_code
			to_chat(H, SPAN_NOTICE("You save the relative harbor plan on the sheet, without site coordinates."))
			if (action == "export")
				sheet.draught_export(H, plan.name)
		else
			return
	if (!QDELETED(src) && can_edit(H))
		show()

#undef HARBOR_SLIDE
#undef HARBOR_WINDOW
#undef HARBOR_CODE_MAX
