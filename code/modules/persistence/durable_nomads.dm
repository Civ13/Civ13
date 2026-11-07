// Exact, audited profiles. New descendants do not inherit recovery admission.
// Exact types: a subtype saves only when listed here, so the barren region
// (Mars), the Moon (code/modules/space/moon_world.dm) and orbit
// (code/modules/space/orbit_world.dm) are named explicitly.
/proc/durable_nomads_profiles()
	return list(/obj/map_metadata/nomads, /obj/map_metadata/nomads/africa, /obj/map_metadata/nomads/asia, /obj/map_metadata/nomads/continental, /obj/map_metadata/nomads/desert, /obj/map_metadata/nomads/divide, /obj/map_metadata/nomads/europe, /obj/map_metadata/nomads/extended, /obj/map_metadata/nomads/frozen_wasteland, /obj/map_metadata/nomads/gaia, /obj/map_metadata/nomads/ice_age, /obj/map_metadata/nomads/island, /obj/map_metadata/nomads/jungle, /obj/map_metadata/nomads/karafuto, /obj/map_metadata/nomads/mediterranean, /obj/map_metadata/nomads/mountain, /obj/map_metadata/nomads/new_world, /obj/map_metadata/nomads/north_america, /obj/map_metadata/nomads/oceania, /obj/map_metadata/nomads/pangea, /obj/map_metadata/nomads/persistence_beta, /obj/map_metadata/nomads/stranded, /obj/map_metadata/nomads/uk, /obj/map_metadata/nomads/wasteland, /obj/map_metadata/nomads/wasteland/two, /obj/map_metadata/nomads/wasteland/three, /obj/map_metadata/nomads/barren, /obj/map_metadata/nomads/barren/moon, /obj/map_metadata/nomads/orbit)

/obj/map_metadata
	var/nomads_nuke_threshold = 0
	var/nomads_nuke_x = 0
	var/nomads_nuke_y = 0
	var/nomads_nuke_z = 0
	var/tmp/nomads_event_busy = FALSE
	var/tmp/datum/durable_nomads_event/nomads_active_event
	var/tmp/nomads_recovery_required = FALSE

/obj/map_metadata/proc/durable_nomads_extension()
	return uses_durable_metadata() && !(type in list(/obj/map_metadata/nomads/gaia, /obj/map_metadata/nomads/europe))

/obj/map_metadata/proc/durable_nomads_fail(reason)
	var/first_failure = !nomads_recovery_required
	nomads_recovery_required = TRUE
	nomads_event_busy = TRUE
	if(first_failure)
		try
			message_admins("Persistence recovery required after [reason]. Restart recovery from the retained completed generation; waiting or clearing runtime flags does not recover this world.")
		catch
			// Notification failure never clears the recovery barrier.
			return

/obj/map_metadata/proc/durable_nomads_schema()
	var/list/schema = list("hasnukes" = "flag", "is_zombie" = "flag", "is_wasteland" = "flag", "nomads_nuke_threshold" = "number", "nomads_nuke_x" = "number", "nomads_nuke_y" = "number", "nomads_nuke_z" = "number")
	if(type in list(/obj/map_metadata/nomads/desert, /obj/map_metadata/nomads/divide, /obj/map_metadata/nomads/ice_age, /obj/map_metadata/nomads/island, /obj/map_metadata/nomads/jungle, /obj/map_metadata/nomads/mountain, /obj/map_metadata/nomads/stranded)) schema["real_season"] = "text"
	if(type in list(/obj/map_metadata/nomads/africa, /obj/map_metadata/nomads/island)) schema["eruptions_enabled"] = "flag"
	if(type == /obj/map_metadata/nomads/extended) schema["oiltarget"] = "number"
	return schema

/obj/map_metadata/proc/durable_nomads_seasons_allowed()
	if(type == /obj/map_metadata/nomads/mountain) return list("SPRING", "Wet Season", "Dry Season")
	if(type in list(/obj/map_metadata/nomads/desert, /obj/map_metadata/nomads/divide, /obj/map_metadata/nomads/island, /obj/map_metadata/nomads/jungle, /obj/map_metadata/nomads/stranded)) return list("SPRING", "SUMMER", "FALL", "WINTER", "Wet Season", "Dry Season")
	return list("SPRING", "SUMMER", "FALL", "WINTER")

/map_storage/proc/capture_durable_nomads()
	if(!map.durable_nomads_extension()) return null
	var/list/fields = durable_metadata_snapshot_fields(map, map.durable_nomads_schema())
	var/list/encoded = list()
	for(var/key in fields) encoded[key] = durable_export.encode(fields[key])
	return list("version" = 1, "fields" = encoded, "civilization_names" = list(civname_a, civname_b, civname_c, civname_d, civname_e, civname_f), "no_respawn_delays" = !!config.no_respawn_delays)

/map_storage/proc/validate_durable_nomads(list/state, datum/durable_save_graph/G)
	if(!map.durable_nomads_extension())
		if("nomads_profile" in state) throw EXCEPTION("Unexpected Nomads extension on legacy profile")
		return TRUE
	var/list/profile = state["nomads_profile"]
	G.check_fields(profile, list("version", "fields", "civilization_names", "no_respawn_delays"))
	if(profile["version"] != 1) throw EXCEPTION("Unsupported Nomads profile version")
	var/list/fields = profile["fields"]
	var/list/schema = map.durable_nomads_schema()
	if(!islist(fields) || fields.len != schema.len) throw EXCEPTION("Nomads field inventory differs")
	var/list/decoded = list()
	for(var/key in schema)
		if(!(key in fields)) throw EXCEPTION("Missing Nomads field [key]")
		G.check_index(fields[key])
		var/list/node = G.nodes[fields[key]]
		if(node["kind"] != "value") throw EXCEPTION("Invalid Nomads field root [key]")
		decoded[key] = node["value"]
	durable_metadata_validate_fields(decoded, schema)
	if("real_season" in schema)
		var/list/allowed = map.type == /obj/map_metadata/nomads/ice_age ? list("SUMMER", "WINTER") : list("wet", "dry")
		if(!(decoded["real_season"] in allowed)) throw EXCEPTION("Invalid Nomads calendar")
		var/list/environment = state["environment"]
		if(!islist(environment)) throw EXCEPTION("Missing Nomads environment")
		if(map.type == /obj/map_metadata/nomads/mountain && environment["season"] != "SPRING")
			if(environment["season"] != (decoded["real_season"] == "wet" ? "Wet Season" : "Dry Season")) throw EXCEPTION("Nomads wet/dry phase differs")
		if(map.type == /obj/map_metadata/nomads/ice_age && environment["season"] != "SPRING")
			if(environment["season"] != decoded["real_season"]) throw EXCEPTION("Nomads Ice Age phase differs")
	if(("oiltarget" in schema) && decoded["oiltarget"] <= 0) throw EXCEPTION("Invalid Nomads oil target")
	if(decoded["nomads_nuke_threshold"] < 0) throw EXCEPTION("Invalid Nomads nuke threshold")
	var/list/timers = state["timers"]
	if(("nomads_nuke_check" in timers) && decoded["nomads_nuke_threshold"] <= 0) throw EXCEPTION("Missing Nomads nuke threshold")
	for(var/axis in list("x", "y", "z"))
		var/value = decoded["nomads_nuke_[axis]"]
		var/maximum = axis == "x" ? world.maxx : (axis == "y" ? world.maxy : save_validation_maxz())
		if(value != round(value) || value < 0 || value > maximum || (("nomads_nuke_fire" in timers) && value < 1)) throw EXCEPTION("Invalid Nomads nuke coordinate")
	var/list/names = profile["civilization_names"]
	if(!islist(names) || names.len != 6) throw EXCEPTION("Invalid Nomads civilization names")
	for(var/name in names)
		if(!istext(name) || !length(name) || length(name) > 1024 || !isnull(names[name])) throw EXCEPTION("Invalid Nomads civilization name")
	if(!durable_metadata_scalar_valid(profile["no_respawn_delays"], "flag")) throw EXCEPTION("Invalid Nomads respawn policy")
	return TRUE

/map_storage/proc/restore_durable_nomads(list/state, list/values)
	if(!map.durable_nomads_extension()) return
	var/list/profile = state["nomads_profile"]
	var/list/encoded = profile["fields"]
	var/list/fields = list()
	for(var/key in encoded) fields[key] = values[encoded[key]]
	durable_metadata_restore_fields(map, fields, map.durable_nomads_schema())
	var/list/names = profile["civilization_names"]
	civname_a = names[1]
	civname_b = names[2]
	civname_c = names[3]
	civname_d = names[4]
	civname_e = names[5]
	civname_f = names[6]
	config.no_respawn_delays = profile["no_respawn_delays"]

/obj/map_metadata/proc/durable_nomads_callbacks()
	var/list/callbacks = list()
	if(type in list(/obj/map_metadata/nomads/desert, /obj/map_metadata/nomads/divide, /obj/map_metadata/nomads/island, /obj/map_metadata/nomads/jungle, /obj/map_metadata/nomads/mountain, /obj/map_metadata/nomads/stranded)) callbacks["nomads_initial_climate"] = "durable_nomads_initial_climate"
	if(type in list(/obj/map_metadata/nomads/africa, /obj/map_metadata/nomads/island))
		callbacks["nomads_eruption_boot"] = "eruption_check"
		callbacks["nomads_eruption_check"] = "durable_nomads_eruption_check"
		callbacks["nomads_eruption_fire"] = "durable_nomads_eruption_fire"
	if(type in list(/obj/map_metadata/nomads/continental, /obj/map_metadata/nomads/mediterranean)) callbacks["nomads_fish_boot"] = "durable_nomads_fish_boot"
	if(type == /obj/map_metadata/nomads/continental) callbacks["nomads_piranha_boot"] = "durable_nomads_piranha_boot"
	if(type == /obj/map_metadata/nomads/extended) callbacks["nomads_oil_check"] = "check_oil"
	if(type == /obj/map_metadata/nomads/persistence_beta) callbacks["nomads_respawn_policy"] = "durable_nomads_respawn_policy"
	if(type in list(/obj/map_metadata/nomads/wasteland, /obj/map_metadata/nomads/wasteland/two, /obj/map_metadata/nomads/wasteland/three, /obj/map_metadata/nomads/frozen_wasteland))
		callbacks["nomads_wasteland_boot"] = "durable_nomads_wasteland_boot"
		callbacks["nomads_nuke_check"] = "durable_nomads_nuke_check"
		callbacks["nomads_nuke_fire"] = "durable_nomads_nuke_fire"
		callbacks["nomads_supplydrop"] = "supplydrop_proc"
	if(type == /obj/map_metadata/nomads/ice_age)
		callbacks["nomads_ice_weather"] = "durable_nomads_ice_weather"
		callbacks["nomads_ice_water"] = "durable_nomads_ice_water"
	return callbacks

/obj/map_metadata/proc/durable_nomads_initial_climate()
	if(map == src && season == "SPRING") season = "Wet Season"

/obj/map_metadata/proc/durable_nomads_eruption_check()
	if(vars["eruptions_enabled"]) call(src, "do_eruption")()
	call(src, "eruption_check")()

/obj/map_metadata/proc/durable_nomads_eruption_fire()
	if(map != src || !vars["eruptions_enabled"] || clients.len <= 5) return
	var/datum/durable_nomads_event/event = new(src)
	try
		volcano_eruption(event)
	catch(var/exception/E)
		// A partially applied event must not become a completed generation.
		// Keep the barrier held for explicit recovery with fresh metadata.
		event.failed = TRUE
		event.release()
		throw E
	event.release()

/obj/map_metadata/proc/durable_nomads_fish_boot()
	var/count = type == /obj/map_metadata/nomads/continental ? 65 : 35
	for(var/i = 1, i <= count, i++)
		var/turf/T = safepick(get_area_turfs(/area/caribbean/sea/sea))
		if(T) new /obj/structure/fish(T)

/obj/map_metadata/proc/durable_nomads_piranha_boot()
	for(var/i = 1, i <= 30, i++)
		var/turf/T = safepick(get_area_turfs(/area/caribbean/nomads/forest/Jungle/river))
		if(T) new /obj/structure/piranha(T)

/obj/map_metadata/proc/durable_nomads_respawn_policy()
	config.no_respawn_delays = FALSE

/obj/map_metadata/proc/durable_nomads_wasteland_boot()
	nomads_nuke_threshold = type == /obj/map_metadata/nomads/frozen_wasteland ? rand(10, 20) : rand(72000, 108000)
	if(hasnukes) call(src, "nuke_proc")(nomads_nuke_threshold)
	call(src, "supplydrop_proc")()

/obj/map_metadata/proc/durable_nomads_nuke_check()
	call(src, "nuke_proc")(nomads_nuke_threshold)

/obj/map_metadata/proc/durable_nomads_nuke_fire()
	var/turf/epicenter = locate(nomads_nuke_x, nomads_nuke_y, nomads_nuke_z)
	if(!epicenter || map != src) throw EXCEPTION("Nomads nuke lost its captured target")
	var/datum/durable_nomads_event/event = new(src)
	try
		to_chat(world, "<font size=4 color='red'>A nuclear explosion has happened! <br><i>(Game might freeze/lag for a while while processing, please wait)</i></font>")
		durable_nomads_nuke_effect(epicenter, event)
		message_admins("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
		log_game("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
	catch(var/exception/E)
		// Failure keeps the barrier held; do not publish a partial event.
		event.failed = TRUE
		event.release()
		throw E
	event.release()

/obj/map_metadata/proc/durable_nomads_nuke_effect(turf/epicenter, datum/durable_nomads_event/event)
	if(!nuke_map(epicenter, 200, 180, 0, event)) throw EXCEPTION("Nomads nuke did not start")

// Each delayed phase, recursive pulse and queued explosion retains one unit.
// Failure latches the barrier even after all remaining work drains. A deadline
// alone cannot prove completion when the scheduler is delayed or a phase yields.
/datum/durable_nomads_event
	var/obj/map_metadata/owner
	var/pending = 1
	var/failed = FALSE
/datum/durable_nomads_event/New(obj/map_metadata/target)
	owner = target
	if(owner.nomads_event_busy || owner.nomads_active_event || owner.nomads_recovery_required) throw EXCEPTION("Nomads event is already active or requires recovery")
	owner.nomads_event_busy = TRUE
	owner.nomads_active_event = src
/datum/durable_nomads_event/proc/retain()
	pending++
/datum/durable_nomads_event/proc/release()
	if(pending <= 0) throw EXCEPTION("Nomads event completion underflow")
	pending--
	if(owner && (failed || owner.nomads_recovery_required))
		failed = TRUE
		owner.durable_nomads_fail("mutating Nomads event failure")
	if(!pending && !failed && owner && map == owner)
		if(owner.nomads_active_event != src) throw EXCEPTION("Nomads event owner changed")
		owner.nomads_active_event = null
		owner.nomads_event_busy = FALSE
		owner = null
/datum/durable_nomads_event/proc/valid()
	if(!owner || map != owner || owner.nomads_recovery_required) failed = TRUE
	return !failed
/datum/durable_nomads_event/proc/defer_lava(delay, turf/floor/lava/target, method, list/arguments)
	var/datum/identity = target.lava_callback_identity
	retain()
	spawn(delay)
		try
			if(valid() && istype(target, /turf/floor/lava) && target.lava_callback_identity == identity)
				call(target, method)(arglist(arguments))
		catch(var/exception/E)
			failed = TRUE
			log_debug("Nomads event child [method] failed: [E]")
		release()

/obj/map_metadata/proc/durable_nomads_lava_active()
	// Legacy or map-authored transient lava has no event owner. Do not save a
	// partially dried stage or load over its unowned constructor callbacks.
	for(var/turf/floor/lava/L in world)
		if(L.dries || L.spreads) return TRUE
	return FALSE

/obj/map_metadata/proc/durable_nomads_transients_active()
	// Ordinary fire is not a resumable snapshot. Wait for its tracked callbacks
	// to finish or retire, including callbacks whose fire has been extinguished.
	if(nomads_fire_callbacks.len) return TRUE
	var/process/explosion/P = processes.explosion
	if(!P) return FALSE
	if(P.nomads_work_active || P.nomads_work_failed || length(P.work_queue)) return TRUE
	if(processes.callproc && length(processes.callproc.by_object[P])) return TRUE
	return FALSE

// Reuse the existing serialized worker and its epoch/budget checks. Custom
// calendars preserve their own cadence instead of invoking the temperate cycle.
/obj/map_metadata/proc/durable_nomads_seasons(looping, force, advance_decay)
	if(map != src || season_retired || persistence_save_in_progress || nomads_event_busy || nomads_active_event || nomads_recovery_required) return FALSE
	advance_decay = season_decay_requested(force, advance_decay)
	if(force)
		for(var/i = 1, i <= season_queue.len, i += 4)
			if(season_queue[i] == "nomads_transition" && season_queue[i+2])
				season_queue[i+1] = looping
				season_queue[i+3] = advance_decay
				return TRUE
	season_queue += list("nomads_transition", looping, force, advance_decay)
	season_run_queue()
	return TRUE

/obj/map_metadata/proc/durable_nomads_replace(old_type, new_type, epoch, chance = 100)
	var/work = 0
	for(var/turf/T in season_world_candidates(old_type, epoch))
		if(!season_work_pause(epoch, ++work)) return FALSE
		if(!season_candidate_valid(T, old_type)) continue
		if(chance < 100 && (!prob(chance) || T:water_level < 50)) continue
		T.ChangeTurf(new_type)
	return season_worker_valid(epoch)

/obj/map_metadata/proc/durable_nomads_apply(looping, advance_decay)
	if(nomads_event_busy) throw EXCEPTION("Nomads transition requires recovery")
	nomads_event_busy = TRUE
	try
		durable_nomads_apply_work(looping, advance_decay)
	catch(var/exception/E)
		// season_run_queue retires its worker on failure; retain this separate
		// recovery barrier so a partially changed calendar cannot be saved.
		durable_nomads_fail("custom calendar transition failure")
		throw E
	nomads_event_busy = nomads_recovery_required || !!nomads_active_event

/obj/map_metadata/proc/durable_nomads_apply_work(looping, advance_decay)
	if(!(type in list(/obj/map_metadata/nomads/mountain, /obj/map_metadata/nomads/ice_age))) throw EXCEPTION("Unsupported Nomads custom calendar")
	season_epoch++
	var/epoch = season_epoch
	durable_cancel_season_phases()
	var/datum/durable_timer_queue/Q = durable_timer_queue()
	Q.cancel("nomads_ice_weather")
	Q.cancel("nomads_ice_water")
	var/delay
	if(type == /obj/map_metadata/nomads/mountain)
		if(vars["real_season"] == "dry")
			season = "Wet Season"
			vars["real_season"] = "wet"
		else
			season = "Dry Season"
			vars["real_season"] = "dry"
		record_abandonment_season_change(advance_decay)
		to_chat(world, "<big>The <b>[season]</b> has started.</big>")
		change_weather_somehow()
		if(season == "Wet Season")
			durable_nomads_replace(/turf/floor/beach/drywater, /turf/floor/beach/water/swamp, epoch)
		else
			durable_nomads_replace(/turf/floor/beach/water/swamp, /turf/floor/beach/drywater, epoch)
		delay = 18000
	else
		var/winter = vars["real_season"] == "SUMMER"
		season = winter ? "WINTER" : "SUMMER"
		vars["real_season"] = season
		record_abandonment_season_change(advance_decay)
		to_chat(world, winter ? "<big>It's getting very cold. <b>Winter</b> has started.</big>" : "<big>The weather gets warmer. <b>Summer</b> has started.</big>")
		change_weather_somehow()
		var/work = 0
		for(var/obj/structure/wild/tree/live_tree/T in season_world_candidates(/obj/structure/wild/tree/live_tree, epoch))
			if(!season_work_pause(epoch, ++work)) return
			if(season_candidate_valid(T, /obj/structure/wild/tree/live_tree)) T.change_season()
		var/bush_type = winter ? /obj/structure/wild/smallbush : /obj/structure/wild/smallbush/winter
		for(var/obj/structure/wild/smallbush/B in season_world_candidates(bush_type, epoch))
			if(!season_work_pause(epoch, ++work)) return
			if(!season_candidate_valid(B, bush_type) || (winter && istype(B, /obj/structure/wild/smallbush/winter))) continue
			if(winter)
				new /obj/structure/wild/smallbush/winter(B.loc)
			else
				new /obj/structure/wild/smallbush(B.loc)
			qdel(B)
		if(!winter)
			for(var/turf/floor/dirt/burned/B in season_world_candidates(/turf/floor/dirt/burned, epoch))
				if(!season_work_pause(epoch, ++work)) return
				if(season_candidate_valid(B, /turf/floor/dirt/burned) && prob(60)) B.ChangeTurf(/turf/floor/grass)
		durable_schedule("nomads_ice_weather", winter ? 100 : 150)
		durable_schedule("nomads_ice_water", winter ? 800 : 1500)
		delay = winter ? 27000 : 9000
	if(looping && season_worker_valid(epoch))
		Q.cancel("season_loop")
		season_loop_scheduled = TRUE
		season_note_next_change(delay)
		durable_schedule("season_loop", delay)

/obj/map_metadata/proc/durable_nomads_ice_weather()
	durable_nomads_enqueue_phase("durable_nomads_ice_weather_phase")
/obj/map_metadata/proc/durable_nomads_ice_water()
	durable_nomads_enqueue_phase("durable_nomads_ice_water_phase")
/obj/map_metadata/proc/durable_nomads_enqueue_phase(phase)
	if(!season_worker_valid(season_epoch)) return
	season_queue += list(phase, season_epoch, FALSE, FALSE)
	season_run_queue()
/obj/map_metadata/proc/durable_nomads_ice_weather_phase(epoch)
	if(season_worker_valid(epoch)) change_weather(vars["real_season"] == "WINTER" ? WEATHER_WET : WEATHER_NONE)
/obj/map_metadata/proc/durable_nomads_ice_water_phase(epoch)
	if(!season_worker_valid(epoch)) return
	if(vars["real_season"] == "WINTER")
		durable_nomads_replace(/turf/floor/beach/water/shallowsaltwater, /turf/floor/beach/water/ice/salty, epoch)
	else
		durable_nomads_replace(/turf/floor/beach/water/ice/salty, /turf/floor/beach/water/shallowsaltwater, epoch, 65)
