// Versioned, explicit field inventory. This is NOT map.vars enumeration.
// New map subtypes require an extension inventory and timer acceptance before
// claiming complete recovery. Gaia and Europe add no subtype data fields.
/proc/durable_metadata_map_schema()
	var/list/groups = list(
		"flag" = list("admin_ended_all_grace_periods", "availablefactions_run", "admins_triggered_roundend", "admins_triggered_noroundend", "win_condition_spam_check", "can_spawn_on_base_capture", "round_finished", "no_time_of_day_cycle", "blizzard", "heat_wave", "sandstorm", "triggered_heatwave", "triggered_blizzard", "triggered_sandstorm", "chad_mode", "chad_mode_plus", "research_active", "perschadplus", "autoresearch", "resourceresearch", "persistence", "age1_done", "age2_done", "age3_done", "age4_done", "age5_done", "age6_done", "age7_done", "age8_done"),
		"number" = list("respawn_delay", "victory_time", "grace_wall_timer", "faction1_points", "faction2_points", "required_players", "ordinal_age", "default_research", "autoresearch_mult", "age1_lim", "age1_top", "age2_lim", "age2_top", "age2_timer", "age3_lim", "age3_top", "age3_timer", "age4_lim", "age4_top", "age4_timer", "age5_lim", "age5_top", "age5_timer", "age6_lim", "age6_top", "age6_timer", "age7_lim", "age7_top", "age7_timer", "age8_lim", "age8_timer", "windspeedvar", "artillery_count", "artillery_timer", "ar_to_close_timeleft"),
		"text" = list("faction1", "faction2", "current_win_condition", "age", "gamemode", "winddirection", "windspeed", "winddesc", "ar_to_close", "ar_to_close_string"),
		"nullable_text" = list("last_win_condition", "current_winner", "current_loser"),
		"list" = list("last_crossing_block_status", "availablefactions", "faction_organization", "initial_faction_organization", "faction_distribution_coeffs", "roundend_condition_sides", "faction1_squads", "faction2_squads", "faction1_squad_leaders", "faction2_squad_leaders", "faction_targets", "awards", "scores", "warrants", "vehicle_registrations", "gun_registrations", "times_of_day", "custom_faction_nr", "custom_civs", "custom_religions", "custom_religion_nr", "custom_company", "custom_company_nr", "custom_company_value", "custom_company_fiat_value", "sales_registry", "custom_company_colors", "civa_research", "civb_research", "civc_research", "civd_research", "cive_research", "civf_research", "facl", "globalmarketplace", "marketplaceaccounts", "pending_warrants", "emails", "assign_precursors", "precursor_stocks", "berryeffects", "human", "faction_research", "faction_bench_cap_bonus", "faction_forge_progress", "faction_research_director", "faction_director_title", "faction_baseline_era", "faction_motto", "faction_flavour", "faction_symbol_grid"),
		// These are offsets, never imported as raw old-runtime clock values.
		"world_time_deadline" = list("next_win"),
		"world_time_origin" = list("artillery_last"),
		"realtime_deadline" = list("lastcheck")
	)
	var/list/schema = list()
	for(var/kind in groups)
		for(var/key in groups[kind])
			if(key in schema) throw EXCEPTION("Duplicate durable metadata field [key]")
			schema[key] = kind
	return schema

/proc/durable_metadata_area_schema()
	return list("climate" = "text", "weather" = "number", "weather_intensity" = "number", "capturable" = "flag", "artillery_integrity" = "number", "has_gravity" = "flag", "no_air" = "nullable_number")

/proc/durable_metadata_scalar_valid(value, kind)
	switch(kind)
		if("list") return islist(value)
		if("text") return istext(value) && length(value) <= 1048576
		if("nullable_text") return isnull(value) || (istext(value) && length(value) <= 1048576)
		if("flag") return isnum(value) && (value == TRUE || value == FALSE)
		if("nullable_number") return isnull(value) || (isnum(value) && abs(value) <= 1e15)
		if("number", "world_time_deadline", "world_time_origin", "realtime_deadline") return isnum(value) && abs(value) <= 1e15
	return FALSE

/proc/durable_metadata_snapshot_fields(datum/source, list/schema)
	var/list/values = list()
	for(var/key in schema)
		if(!(key in source.vars)) throw EXCEPTION("Durable metadata field is absent: [key]")
		var/value = source.vars[key]
		var/kind = schema[key]
		if(!durable_metadata_scalar_valid(value, kind))
			throw EXCEPTION("Durable metadata field has an unsupported value: [key]")
		if(kind == "world_time_deadline") value = value == -1 ? null : max(0, value - world.time)
		if(kind == "world_time_origin") value = max(0, world.time - value)
		if(kind == "realtime_deadline") value = max(0, value - world.realtime)
		values[key] = value
	return values

/proc/durable_metadata_validate_fields(list/values, list/schema)
	if(!islist(values) || values.len != schema.len)
		throw EXCEPTION("Durable metadata field inventory differs")
	for(var/key in schema)
		if(!(key in values)) throw EXCEPTION("Durable metadata field is missing: [key]")
		var/kind = schema[key]
		var/value = values[key]
		if(kind == "world_time_deadline" && isnull(value)) continue
		if(!durable_metadata_scalar_valid(value, kind))
			throw EXCEPTION("Invalid durable metadata field: [key]")
		if((kind in list("world_time_deadline", "world_time_origin", "realtime_deadline")) && value < 0)
			throw EXCEPTION("Negative durable metadata clock remainder: [key]")
	return TRUE

/proc/durable_metadata_restore_fields(datum/target, list/values, list/schema)
	durable_metadata_validate_fields(values, schema)
	for(var/key in schema)
		var/kind = schema[key]
		var/value = values[key]
		if(kind == "world_time_deadline") value = isnull(value) ? -1 : world.time + value
		if(kind == "world_time_origin") value = world.time - value
		if(kind == "realtime_deadline") value = world.realtime + value
		target.vars[key] = value
