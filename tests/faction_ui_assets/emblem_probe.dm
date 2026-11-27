// Detached native probe: actual editor, NanoUI manager, stamp and undo.
var/emblem_failures = 0
var/emblem_runtime = FALSE

/world
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf
	area = /area
	hub = ""
	visibility = 0

/world/OpenPort(port)
	return ..("none")

/world/Topic()
	return null

/world/Error(exception/e)
	emblem_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/obj/map_metadata/emblem_probe/New()
	return

/mob/living/human/emblem_probe/New()
	return

/proc/emblem_check(value, label)
	if (!value)
		emblem_failures++
	world.log << "[value ? "PASS" : "FAIL"]: [label]"

/world/New()
	OpenPort("none")
	try
		GLOB.nanomanager = new
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/emblem_probe
		emblem_checks()
	catch(var/exception/e)
		emblem_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = emblem_failures, "runtime_error" = emblem_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/emblem_checks()
	var/list/cross = faction_symbol_new_grid()
	var/icon/stamp = icon('icons/obj/banners.dmi', "b_big_cross")
	faction_symbol_stamp_grid(cross, "big cross")
	var/nonempty = FALSE
	var/mismatches = 0
	for (var/y in 1 to FACTION_SYMBOL_SIZE)
		for (var/x in 1 to FACTION_SYMBOL_SIZE)
			var/px = stamp.GetPixel(x, FACTION_SYMBOL_SIZE - y + 1)
			if (px && !cmptext(px, "#FFFFFF"))
				nonempty = TRUE
			if (!cmptext(cross[faction_symbol_grid_index(x, y)], px || "#FFFFFF"))
				mismatches++
	emblem_check(nonempty && !mismatches, "Big Cross paints the real b_big_cross sprite with the correct orientation")

	var/mob/living/human/emblem_probe/leader = new(locate(2, 2, 1))
	leader.civilization = "Probe faction"
	leader.leader = TRUE
	leader.design_faction_symbol()
	var/datum/nano_module/faction_symbol_editor/editor = leader.active_faction_symbol_editor
	emblem_check(editor && editor.can_edit(), "the leader's actual verb acquires an editor")
	var/list/grid = map.ensure_faction_symbol_grid(leader.civilization)
	var/list/undo = map.ensure_faction_symbol_undo(leader.civilization)
	map.faction_symbol_tool[leader.civilization] = "bucket"
	map.faction_symbol_color[leader.civilization] = "#1122AA"
	editor.Topic("", list("paint" = 1, "x" = "1", "y" = "1"))
	emblem_check(undo.len == 1 && grid[1] == "#1122AA" && grid[grid.len] == "#1122AA", "a real bucket action records one undo step")
	map.faction_symbol_color[leader.civilization] = "#1122aa"
	for (var/i in 1 to FACTION_SYMBOL_UNDO_MAX + 2)
		editor.Topic("", list("paint" = 1, "x" = "1", "y" = "1"))
	editor.Topic("", list("paint" = 1, "x" = "1.5", "y" = "1"))
	emblem_check(undo.len == 1, "same-color and invalid fills cannot evict the real undo step")
	editor.Topic("", list("undo" = 1))
	emblem_check(!undo.len && faction_symbol_grid_is_blank(map.faction_symbol_grid[leader.civilization]), "Undo restores the grid from before the real fill")

	var/datum/nanoui/ui = editor.ui_interact(leader)
	GLOB.nanomanager.ui_opened(ui) // Adopt at the absent client browse boundary.
	var/first_window_id = ui.window_id
	map.faction_symbol_color[leader.civilization] = "#aa9900"
	leader.design_faction_symbol()
	emblem_check(leader.active_faction_symbol_editor == editor && GLOB.nanomanager.get_open_ui(leader, editor, "main") == ui, "reopening keeps the same editor and registered browser")
	emblem_check(ui.window_id == first_window_id && ui.initial_data["color"] == "#aa9900", "the original browser id is refreshed with the current palette")
	map.faction_renames["Renamed faction"] = list(leader.civilization, abandonment_season_changes, world.realtime)
	leader.civilization = "Renamed faction"
	leader.design_faction_symbol()
	emblem_check(leader.active_faction_symbol_editor == editor && editor.faction == "Renamed faction", "a genuine faction rename keeps the same editor")
	leader.civilization = "Other faction"
	leader.design_faction_symbol()
	var/datum/nano_module/faction_symbol_editor/next = leader.active_faction_symbol_editor
	emblem_check(next != editor && QDELETED(editor) && !GLOB.nanomanager.get_open_ui(leader, editor, "main"), "changing factions retires the stale editor and window")
	emblem_check(next && next.can_edit(), "the replacement belongs to the new faction")
	leader.remove_faction_symbol_editor()
	emblem_check(QDELETED(next) && !leader.active_faction_symbol_editor, "losing the editor verb retires its source")
