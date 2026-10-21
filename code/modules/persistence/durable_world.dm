// World metadata is opt-in by exact map profile. Its graph never constructs
// atom references: leaders resolve only to entries loaded by the normal world.
/map_storage
	var/datum/durable_save_graph/durable_export
	var/datum/durable_save_graph/durable_import
	var/list/durable_state
	var/loading_z = 0

/proc/durable_environment_schema()
	return list("season" = "text", "game_hour" = "number", "time_of_day" = "text", "weather" = "number", "weather_intensity" = "number", "global_radiation" = "number", "global_pollution" = "number", "global_export_tax" = "number", "global_import_tax" = "number", "abandonment_season_changes" = "number", "round_progressing" = "flag", "allow_vote_restart" = "flag", "daynight_on" = "flag", "seasons_on" = "flag", "tod_ticks" = "number", "tod_gate" = "flag", "research_clock" = "number", "win_hash" = "nullable_scalar")

/proc/durable_weather_schema()
	return list("enabled" = "flag", "mod_weather_interval" = "number", "change_weather_interval" = "number", "minimum_mod_weather_delay" = "number", "minimum_change_weather_delay" = "number", "next_can_mod_weather" = "realtime_deadline", "next_can_change_weather" = "realtime_deadline")

/map_storage/proc/capture_durable_world()
	durable_export = null
	if(!map.uses_durable_metadata()) return null
	if(map.season_busy || map.season_queue.len || environment_weather_running || (processes.time_of_day_change && processes.time_of_day_change.updating_lighting))
		throw EXCEPTION("World metadata is transitioning; retry saving after it settles")
	if(!processes.time_of_day || !processes.weather)
		throw EXCEPTION("World metadata processes are unavailable")
	durable_export = new
	var/list/fields = durable_metadata_snapshot_fields(map, durable_metadata_map_schema())
	var/list/encoded_fields = list()
	for(var/key in fields) encoded_fields[key] = durable_export.encode(fields[key])
	var/list/environment = list("season" = season, "game_hour" = game_hour, "time_of_day" = time_of_day, "weather" = weather, "weather_intensity" = weather_intensity, "global_radiation" = global_radiation, "global_pollution" = global_pollution, "global_export_tax" = global_export_tax, "global_import_tax" = global_import_tax, "abandonment_season_changes" = abandonment_season_changes, "round_progressing" = round_progressing, "allow_vote_restart" = config.allow_vote_restart, "daynight_on" = config.daynight_on, "seasons_on" = config.seasons_on, "tod_ticks" = processes.time_of_day.TOD_ticks, "tod_gate" = TOD_may_automatically_change, "research_clock" = map.research_time(), "win_hash" = map.win_condition ? map.win_condition.hash : null)
	durable_metadata_validate_fields(environment, durable_environment_schema())
	var/list/areas = list()
	for(var/area/A in world)
		var/turf/T = locate(/turf) in A
		if(!T) continue
		areas += list(list("x" = T.x, "y" = T.y, "z" = T.z, "type" = "[A.type]", "fields" = durable_metadata_snapshot_fields(A, durable_metadata_area_schema())))
	var/list/symbols = list()
	for(var/faction in map.faction_symbol_icon)
		var/icon/I = map.faction_symbol_icon[faction]
		if(!I) continue
		if(!isicon(I) || I.Width() != 32 || I.Height() != 32)
			throw EXCEPTION("Unsupported active faction symbol")
		var/list/pixels = list()
		for(var/y = 1, y <= 32, y++)
			for(var/x = 1, x <= 32, x++) pixels += list(I.GetPixel(x, y))
		symbols[faction] = pixels
	var/datum/durable_timer_queue/Q = map.durable_timer_queue()
	return list("schema" = 1, "map_type" = "[map.type]", "fields" = encoded_fields, "environment" = environment, "times" = durable_export.encode(times_of_day), "areas" = areas, "symbols" = symbols, "weather_process" = durable_metadata_snapshot_fields(processes.weather, durable_weather_schema()), "timers" = Q.snapshot(), "nodes" = null)

// Inspect encoded field roots without decoding references to atoms which have
// not been loaded yet. All graph edges and entry identities are checked first.
/map_storage/proc/validate_durable_world(list/state, generation)
	durable_import = null
	durable_state = null
	if(!map.uses_durable_metadata() || !islist(state))
		throw EXCEPTION("Unsupported durable world profile")
	var/datum/durable_save_graph/G = new
	G.check_fields(state, list("schema", "map_type", "fields", "environment", "times", "areas", "symbols", "weather_process", "timers", "nodes"))
	if(state["schema"] != 1 || state["map_type"] != "[map.type]")
		throw EXCEPTION("Durable world profile differs")
	G.validate(state["nodes"], generation)
	var/list/fields = state["fields"]
	var/list/schema = durable_metadata_map_schema()
	if(!islist(fields) || fields.len != schema.len)
		throw EXCEPTION("Durable map field inventory differs")
	for(var/key in schema)
		if(!(key in fields)) throw EXCEPTION("Missing durable map field [key]")
		G.check_index(fields[key])
		var/list/node = G.nodes[fields[key]]
		var/kind = schema[key]
		if(kind in list("list", "alist"))
			if(node["kind"] != kind) throw EXCEPTION("Invalid durable collection field [key]")
		else
			if(node["kind"] != "value") throw EXCEPTION("Invalid durable scalar field [key]")
			var/list/value = list()
			value[key] = node["value"]
			durable_metadata_validate_fields(value, list("[key]" = kind))
	durable_metadata_validate_fields(state["environment"], durable_environment_schema())
	var/list/environment = state["environment"]
	if(!(environment["season"] in list("SPRING", "SUMMER", "FALL", "WINTER")) || !(environment["time_of_day"] in time_of_day2luminosity) || environment["tod_ticks"] < 0 || environment["research_clock"] < 0)
		throw EXCEPTION("Invalid durable environment phase")
	G.check_index(state["times"])
	var/list/times_node = G.nodes[state["times"]]
	if(times_node["kind"] != "list") throw EXCEPTION("Invalid durable time cycle")
	var/list/time_keys = times_node["keys"]
	if(!time_keys.len || time_keys.len > 16) throw EXCEPTION("Invalid durable time cycle size")
	for(var/id in time_keys)
		var/list/node = G.nodes[id]
		if(node["kind"] != "value" || !(node["value"] in time_of_day2luminosity)) throw EXCEPTION("Invalid durable time cycle phase")
	var/list/areas = state["areas"]
	if(!islist(areas)) throw EXCEPTION("Invalid durable area inventory")
	var/list/seen = list()
	for(var/list/row in areas)
		G.check_fields(row, list("x", "y", "z", "type", "fields"))
		for(var/axis in list("x", "y", "z"))
			if(!isnum(row[axis]) || row[axis] != round(row[axis]) || row[axis] < 1) throw EXCEPTION("Invalid durable area coordinate")
		var/area_key = save_validation_area_key(row["x"], row["y"], row["z"])
		if(!area_key || "[save_validation_area_type(row["x"], row["y"], row["z"])]" != row["type"] || seen[area_key]) throw EXCEPTION("Invalid or duplicate durable area")
		seen[area_key] = TRUE
		durable_metadata_validate_fields(row["fields"], durable_metadata_area_schema())
	for(var/area/A in world)
		var/turf/T = locate(/turf) in A
		if(T && !seen["\ref[A]"]) throw EXCEPTION("Missing durable area")
	if(save_validation_maxz() > world.maxz && !seen[save_validation_area_key(1, 1, save_validation_maxz())])
		throw EXCEPTION("Missing prospective durable area")
	var/list/symbols = state["symbols"]
	if(!islist(symbols) || symbols.len > 1024) throw EXCEPTION("Invalid durable faction symbols")
	for(var/faction in symbols)
		var/list/pixels = symbols[faction]
		if(!istext(faction) || !length(faction) || !islist(pixels) || pixels.len != 1024) throw EXCEPTION("Invalid durable faction symbol")
		for(var/color in pixels)
			if(isnull(color)) continue
			if(!istext(color) || !(length(color) in list(7, 9)) || copytext(color, 1, 2) != "#") throw EXCEPTION("Invalid durable symbol color")
			for(var/i = 2, i <= length(color), i++)
				if(!findtext("0123456789abcdef", lowertext(copytext(color, i, i+1)))) throw EXCEPTION("Invalid durable symbol color digit")
	durable_metadata_validate_fields(state["weather_process"], durable_weather_schema())
	var/list/policy = state["weather_process"]
	if(policy["mod_weather_interval"] <= 0 || policy["change_weather_interval"] <= 0) throw EXCEPTION("Invalid durable weather interval")
	var/datum/durable_timer_queue/Q = new(map, map.durable_callback_names())
	Q.validate(state["timers"])
	Q.owner = null
	validate_durable_reachability(G)
	durable_import = G
	durable_state = state
	return TRUE

// A metadata atom must belong to the saved spatial ownership tree, not merely
// exist as an orphan entry. This mirrors normal contents loading from turfs.
/map_storage/proc/validate_durable_reachability(datum/durable_save_graph/G)
	for(var/z = 1, z <= save_validation_maxz(), z++)
		var/list/wanted = list()
		for(var/key in G.entry_targets)
			var/list/parts = splittext(key, ":")
			if(text2num(parts[1]) == z) wanted[parts[2]] = TRUE
		if(!wanted.len) continue
		var/savefile/F = new("map_saves/[z].sav")
		var/list/queue = list()
		var/list/seen = list()
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++) queue += F["/map/[z]/[y]/[x]"]
		var/cursor = 1
		while(cursor <= queue.len && wanted.len)
			TICK_CHECK
			var/ref = "[queue[cursor++]]"
			if(seen[ref]) continue
			seen[ref] = TRUE
			wanted -= ref
			var/path = entry_path(F, ref)
			var/type = F["[path]/type"]
			if(ispath(type, /obj/screen) || ispath(type, /datum/hud)) continue
			for(var/child in params2list(F["[path]/content"])) queue += child
		if(wanted.len) throw EXCEPTION("Durable metadata references an unreachable world entry")

// Read-only rejection before player ownership or timer state is changed.
/map_storage/proc/require_durable_world_idle()
	if(!durable_state) return
	if(map.season_busy || map.season_queue.len || environment_weather_running || (processes.time_of_day_change && processes.time_of_day_change.updating_lighting))
		throw EXCEPTION("World metadata is transitioning; retry loading after it settles")

/map_storage/proc/suspend_durable_world()
	if(!durable_state) return
	require_durable_world_idle()
	map.durable_timer_queue().cancel_all()
	map.season_epoch++
	map.season_loop_scheduled = FALSE

/map_storage/proc/restore_durable_world()
	if(!durable_state) return
	var/list/values = durable_import.decode()
	var/list/fields = list()
	var/list/encoded_fields = durable_state["fields"]
	for(var/key in encoded_fields) fields[key] = values[encoded_fields[key]]
	durable_metadata_restore_fields(map, fields, durable_metadata_map_schema())
	var/list/E = durable_state["environment"]
	season = E["season"]
	game_hour = E["game_hour"]
	time_of_day = E["time_of_day"]
	weather = E["weather"]
	weather_intensity = E["weather_intensity"]
	global_radiation = E["global_radiation"]
	global_pollution = E["global_pollution"]
	global_export_tax = E["global_export_tax"]
	global_import_tax = E["global_import_tax"]
	abandonment_season_changes = E["abandonment_season_changes"]
	round_progressing = E["round_progressing"]
	config.allow_vote_restart = E["allow_vote_restart"]
	config.daynight_on = E["daynight_on"]
	config.seasons_on = E["seasons_on"]
	processes.time_of_day.TOD_ticks = E["tod_ticks"]
	TOD_may_automatically_change = E["tod_gate"]
	map.research_clock_offset = E["research_clock"] - world.time
	if(map.win_condition) map.win_condition.hash = E["win_hash"]
	times_of_day = values[durable_state["times"]]
	var/list/areas = durable_state["areas"]
	for(var/list/row in areas)
		var/turf/T = locate(row["x"], row["y"], row["z"])
		durable_metadata_restore_fields(T.loc, row["fields"], durable_metadata_area_schema())
	map.faction_symbol_icon = list()
	var/list/symbols = durable_state["symbols"]
	for(var/faction in symbols)
		var/list/pixels = symbols[faction]
		var/icon/I = icon('icons/obj/banners.dmi', "b_star")
		I.Blend("#00000000", ICON_MULTIPLY)
		for(var/y = 1, y <= 32, y++)
			for(var/x = 1, x <= 32, x++)
				var/color = pixels[(y-1)*32+x]
				if(color) I.DrawBox(color, x, y, x, y)
		map.faction_symbol_icon[faction] = I
	durable_metadata_restore_fields(processes.weather, durable_state["weather_process"], durable_weather_schema())
	var/list/timers = durable_state["timers"]
	map.season_loop_scheduled = "season_loop" in timers
	map.durable_timer_queue().restore(timers)
	durable_import = null
	durable_state = null
	loading_z = 0

/map_storage/proc/release_durable_world()
	durable_export = null
	durable_import = null
	durable_state = null
	loading_z = 0
