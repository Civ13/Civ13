// Headless map variation probe. Test-only: native_probe.py appends it to a
// temporary copy of civ13.dme with a battle map selected. It records the
// variants the pregame lobby picked, then lays every insert variant over its
// slot in turn and checks each changed cell holds what the insert asks for,
// while keep cells are left as they were.
var/global/datum/map_variation_probe/map_variation_probe = new

/datum/map_variation_probe
	var/list/checks = list()

/datum/map_variation_probe/New()
	if (!all_species || !all_species.len)
		makeDatumRefLists()
	if (!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(10)
		drive()

/datum/map_variation_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/map_variation_probe/proc/cell_signature(turf/T)
	var/list/parts = list("[T.type]")
	for (var/obj/O in T)
		if (istype(O, /obj/structure) || istype(O, /obj/item) || istype(O, /obj/covers))
			parts += "[O.type]"
	return jointext(sortList(parts), ";")

/datum/map_variation_probe/proc/check_variant(list/slot, list/variant)
	var/list/insert = map_variation_parse(file2text("[map_variation_folder(map.ID)][variant["file"]]"))
	require(islist(insert), "[variant["file"]] refused: [insert]")
	var/x1 = slot["x"]
	var/y1 = slot["y"]
	var/list/rows = insert["rows"]
	var/list/models = insert["models"]
	var/key_len = insert["key_len"]
	var/list/before = list()
	for (var/turf/T in block(locate(x1, y1, 1), locate(x1 + insert["width"] - 1, y1 + insert["height"] - 1, 1)))
		before["[T.x],[T.y]"] = cell_signature(T)
	var/list/chosen = map_variation_apply_slot(slot, map.ID, variant["id"])
	require(chosen && chosen["id"] == variant["id"], "slot [slot["id"]] did not take [variant["id"]]")
	var/changed = 0
	var/kept = 0
	for (var/row_index = 1 to rows.len)
		var/row = rows[row_index]
		var/y = y1 + rows.len - row_index
		for (var/column = 1 to length(row) / key_len)
			var/model = models[copytext(row, (column - 1) * key_len + 1, column * key_len + 1)]
			var/turf/T = locate(x1 + column - 1, y, 1)
			if (model == "/obj/effect/map_variation_keep")
				require(cell_signature(T) == before["[T.x],[T.y]"], "keep cell [T.x],[T.y] changed")
				kept++
				continue
			changed++
			require(!T.dmm_preloader, "preloader left on [T.x],[T.y]")
			for (var/atom_text in splittext(model, ","))
				var/path = text2path(copytext(atom_text, 1, findtext(atom_text, "{")))
				if (ispath(path, /turf))
					require(istype(T, path), "[T.x],[T.y] is [T.type], wanted [path]")
				else
					require(locate(path) in T, "[T.x],[T.y] lacks [path]")
					if (ispath(path, /obj/structure/window/barrier))
						var/want_dir = text2num(copytext(atom_text, findtext(atom_text, "dir = ") + 6))
						var/found = FALSE
						for (var/obj/structure/window/barrier/B in T)
							if (B.dir == want_dir)
								found = TRUE
						require(found, "[T.x],[T.y] sandbag dir [want_dir] missing")
	checks += list(list("check" = "[slot["id"]]/[variant["id"]]", "passed" = TRUE, "changed" = changed, "kept" = kept))

/datum/map_variation_probe/proc/drive()
	var/failure = null
	var/list/auto = null
	try
		var/until = world.time + 9000
		while (!(ticker && ticker.current_state >= GAME_STATE_PREGAME && map_variations_applied))
			require(world.time < until, "pregame never applied map variations")
			sleep(5)
		auto = map_variation_choices.Copy()
		var/list/data = map_variation_config(map.ID)
		require(data, "no variation config for [map.ID]")
		require(auto.len == length(data["slots"]), "pregame picked [auto.len] of [length(data["slots"])] slots")
		for (var/list/slot in data["slots"])
			for (var/list/variant in slot["variants"])
				if (variant["file"])
					check_variant(slot, variant)
		require(map_variation_announcement() || !map_variation_notes.len, "announcement missing")
	catch (var/exception/e)
		failure = "[e.name]"
	var/list/result = list("passed" = !failure, "failure" = failure, "map" = map ? map.ID : null,
		"pregame_choices" = auto, "checks" = checks, "notes" = map_variation_notes)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	del(world)
