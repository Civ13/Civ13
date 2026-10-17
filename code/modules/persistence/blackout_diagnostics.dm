// Private own-host diagnostics on the existing authenticated lifecycle transport.
// Protocol bookkeeping changes; character, camera, HUD and lighting never do.
#define BLACKOUT_DIAGNOSTIC_LIMIT 32768

/datum/nomads_lifecycle_control
	var/list/diagnostic_nonces = list()
	var/diagnostic_last_tick = -100

/proc/blackout_diagnostic_scalar(value)
	if(istext(value)) return copytext(value, 1, 161)
	if(isnum(value) || isnull(value)) return value
	return "unavailable: non-scalar"

/proc/blackout_diagnostic_color(value)
	if(!islist(value)) return blackout_diagnostic_scalar(value)
	var/list/values = value
	var/list/sample = list()
	for(var/i = 1 to min(values.len, 20))
		sample += list(blackout_diagnostic_scalar(values[i]))
	return list("count" = values.len, "first_20" = sample)

/proc/blackout_diagnostic_turf(atom/A)
	for(var/i = 1 to 8)
		if(!A) return null
		if(isturf(A)) return A
		A = A.loc
	return null

/proc/blackout_diagnostic_display(atom/A, client/C)
	if(!A) return list("present" = FALSE)
	return list("present" = TRUE, "type" = "[A.type]", "plane" = A.plane, "layer" = A.layer, "alpha" = A.alpha, "invisibility" = A.invisibility, "blend_mode" = A.blend_mode, "appearance_flags" = A.appearance_flags, "color" = blackout_diagnostic_color(A.color), "overlays_count" = A.overlays.len, "underlays_count" = A.underlays.len, "on_client_screen" = (A in C.screen), "filters" = "not captured", "transform" = "not captured")

/proc/blackout_diagnostic_light(turf/T, client/C)
	if(!T) return list("present" = FALSE)
	var/area/A = T.loc
	var/list/row = list("present" = TRUE, "x" = T.x, "y" = T.y, "z" = T.z, "type" = "[T.type]", "dynamic" = T.dynamic_lighting, "luminosity" = T.luminosity, "opacity" = T.opacity, "window_coeff" = T.window_coeff, "window_coeff_dirty" = T.window_coeff_dirty, "opaque_atom" = T.has_opaque_atom, "area_type" = A ? "[A.type]" : null, "area_location" = A ? blackout_diagnostic_scalar(A.location) : null, "area_dynamic" = A ? A.dynamic_lighting : null)
	// Fixed raw fields only: no icon extraction, appearance construction or updates.
	row["appearance"] = list("icon" = T.icon ? blackout_diagnostic_scalar("[T.icon]") : null, "icon_state" = blackout_diagnostic_scalar(T.icon_state), "alpha" = T.alpha, "color" = blackout_diagnostic_color(T.color), "plane" = T.plane, "layer" = T.layer, "invisibility" = T.invisibility, "blend_mode" = T.blend_mode, "appearance_flags" = T.appearance_flags)
	var/atom/movable/lighting_overlay/O = T.lighting_overlay
	row["overlay"] = blackout_diagnostic_display(O, C)
	row["turf_ref"] = "\ref[T]"
	var/scanned = 0
	var/local_complete = TRUE
	var/overlay_count = 0
	var/roof_count = 0
	var/cover_count = 0
	for(var/atom/local_atom in T)
		if(scanned >= 64)
			local_complete = FALSE
			break
		scanned++
		if(istype(local_atom, /atom/movable/lighting_overlay)) overlay_count++
		if(istype(local_atom, /obj/roof)) roof_count++
		if(istype(local_atom, /obj/covers)) cover_count++
	row["local_atoms"] = list("scanned" = scanned, "complete" = local_complete, "overlay_count" = overlay_count, "roof_count" = roof_count, "cover_count" = cover_count)
	if(O)
		row["overlay_luminosity"] = O.luminosity
		row["overlay_last_luminosity"] = O.last_luminosity
		row["overlay_last_color"] = blackout_diagnostic_color(O.last_color)
		var/turf/overlay_turf = blackout_diagnostic_turf(O)
		var/registry_index = lighting_overlay_list.Find(O, 1, min(lighting_overlay_list.len + 1, 257))
		row["overlay_owner"] = list("ref" = "\ref[O]", "loc_ref" = O.loc ? "\ref[O.loc]" : null, "loc_type" = O.loc ? "[O.loc.type]" : null, "loc_is_sample_turf" = O.loc == T, "x" = overlay_turf ? overlay_turf.x : null, "y" = overlay_turf ? overlay_turf.y : null, "z" = overlay_turf ? overlay_turf.z : null, "registry_prefix_scanned" = min(lighting_overlay_list.len, 256), "registry_total" = lighting_overlay_list.len, "registry_membership" = registry_index ? "present in prefix" : (lighting_overlay_list.len <= 256 ? "absent" : "unknown beyond prefix"))
		row["overlay_time_of_day"] = blackout_diagnostic_scalar(O.TOD)
		row["overlay_pending"] = O.needs_update
	var/list/corners = list()
	for(var/i = 1 to 4)
		var/datum/lighting_corner/K = (T.corners && T.corners.len >= i) ? T.corners[i] : null
		corners += list(K ? list("present" = TRUE, "ref" = "\ref[K]", "active" = K.active, "r" = K.lum_r, "g" = K.lum_g, "b" = K.lum_b, "window_coeff" = K.window_coeff, "owner_direction" = K.masters[T], "expected_owner_direction" = turn(LIGHTING_CORNER_DIAGONAL[i], 180), "master_count" = K.masters.len) : list("present" = FALSE))
	row["corners"] = corners
	return row

/proc/blackout_diagnostic_capture(client/C, mob/M)
	var/list/row = list()
	var/atom/eye = C.eye
	row["client"] = list("eye_relation" = eye == M ? "own mob" : (eye ? "other; position withheld" : "absent"), "eye_type" = eye ? "[eye.type]" : null, "perspective" = C.perspective, "view" = blackout_diagnostic_scalar(C.view), "color" = blackout_diagnostic_color(C.color), "pixel_x" = C.pixel_x, "pixel_y" = C.pixel_y, "images_count" = C.images.len, "screen_count" = C.screen.len)
	if(!M)
		row["mob"] = list("status" = "unavailable: no current mob")
		return row
	row["mob"] = list("type" = "[M.type]", "loc_type" = M.loc ? "[M.loc.type]" : null, "stat" = M.stat, "sleeping" = M.sleeping, "resting" = M.resting, "paralysis" = M.paralysis, "blinded" = M.blinded, "sight" = M.sight, "see_in_dark" = M.see_in_dark, "see_invisible" = M.see_invisible, "invisibility" = M.invisibility, "transforming" = blackout_diagnostic_scalar(M.transforming), "status_flags" = M.status_flags, "gcDestroyed" = M.gcDestroyed)
	if(istype(M, /mob/living))
		var/mob/living/L = M
		row["living"] = list("health" = L.health, "eye_blind" = L.eye_blind, "eye_blurry" = L.eye_blurry, "last_life_tick" = L.last_life_tick)
	if(istype(M, /mob/living/human))
		var/mob/living/human/H = M
		row["human"] = list("life_tick" = H.life_tick, "inducedSSD" = H.inducedSSD, "roofs_removed" = H.roofs_removed, "saved_return_x" = H.lastx, "saved_return_y" = H.lasty, "saved_return_z" = H.lastz, "saved_return_status" = "sleep-return only; may be unset or stale", "eyewear_present" = H.eyes ? TRUE : FALSE, "vision_organ_present" = H.internal_organs_by_name["eyes"] ? TRUE : FALSE)
	var/list/planes = list()
	for(var/plane_key in list("[GAME_PLANE]", "[LIGHTING_PLANE]", "[HUD_PLANE]"))
		var/obj/screen/plane_master/P = (M.hud_used && M.hud_used.plane_masters) ? M.hud_used.plane_masters[plane_key] : null
		planes[plane_key] = blackout_diagnostic_display(P, C)
	row["plane_masters"] = planes
	var/list/hud = list()
	for(var/hud_key in list("screen_cover", "damageoverlay", "flash", "pain", "fov"))
		var/obj/screen/S = M.HUDtech ? M.HUDtech[hud_key] : null
		hud[hud_key] = blackout_diagnostic_display(S, C)
	row["known_hud"] = hud
	var/list/nearby = list()
	var/bounded_sample_partial = FALSE
	var/turf/T = blackout_diagnostic_turf(M)
	if(T)
		for(var/dx = -1 to 1)
			for(var/dy = -1 to 1)
				var/list/light_row = blackout_diagnostic_light(locate(T.x + dx, T.y + dy, T.z), C)
				nearby += list(light_row)
				var/list/local_summary = light_row["local_atoms"]
				if(local_summary && !local_summary["complete"]) bounded_sample_partial = TRUE
	row["lighting_3x3"] = nearby
	var/process/time_of_day_change/daylight = processes ? processes.time_of_day_change : null
	row["lighting_lifecycle"] = list("startup_in_progress" = lighting_startup_in_progress, "overlays_created" = created_lighting_corners_and_overlays, "daylight_worker_available" = !!daylight, "daylight_updating" = daylight ? daylight.updating_lighting : FALSE, "daylight_setup" = daylight ? daylight.setup_lighting : FALSE, "daylight_revision" = daylight ? daylight.lighting_revision : null, "overlay_queue" = lighting_update_overlays.len)
	row["bounded_sample_partial"] = bounded_sample_partial
	row["environment"] = list("season" = blackout_diagnostic_scalar(season), "phase" = blackout_diagnostic_scalar(time_of_day), "game_hour" = game_hour, "maxz" = world.maxz, "daynight_on" = config.daynight_on, "seasons_on" = config.seasons_on, "sample_z" = T ? T.z : null, "scope" = "own turf and eight adjacent turfs only; black/visible distinction requires matching client capture")
	row["lighting_status"] = T ? "raw cached fields; queued updates/rendering not verified" : "unavailable: no turf within eight links"
	row["processing"] = list("mob_ticks" = (processes && processes.mob) ? processes.mob.ticks : null, "lighting_startup" = lighting_startup_in_progress, "overlay_queue" = lighting_update_overlays.len, "runtime_count" = GLOB.total_runtimes, "runtime_text" = "withheld")
	return row

/datum/nomads_lifecycle_control/proc/diagnose(list/input)
	// handle() has already enforced existing loopback/token/build auth and keys.
	if(input["session"] != boot_session() || !nomads_lifecycle_hex(input["operation"], 32))
		return json_encode(list("ok" = FALSE, "error" = "invalid_session_or_operation"))
	if(input["operation"] in diagnostic_nonces)
		return json_encode(list("ok" = FALSE, "error" = "diagnostic_replayed"))
	if(diagnostic_nonces.len >= 64 || world.time - diagnostic_last_tick < 100)
		return json_encode(list("ok" = FALSE, "error" = "diagnostic_quota_or_cooldown"))
	diagnostic_nonces += input["operation"]
	diagnostic_last_tick = world.time
	// Existing host configuration only. Never fall back to another player/admin.
	if(!fexists("config/host.txt") || length(file("config/host.txt")) > 128)
		return json_encode(list("ok" = FALSE, "error" = "own_host_unavailable"))
	var/own_host = ckey(file2text("config/host.txt"))
	if(!istext(input["target"]) || !length(own_host) || length(input["target"]) > 64 || input["target"] != own_host)
		return json_encode(list("ok" = FALSE, "error" = "own_host_unavailable"))
	var/client/C = directory[own_host]
	if(!C || C.ckey != own_host || !C.holder || !(C.holder.rights & R_HOST))
		return json_encode(list("ok" = FALSE, "error" = "own_host_unavailable"))
	var/mob/M = C.mob
	var/start_tick = world.time
	var/list/result = list("ok" = TRUE, "schema" = 1, "revision" = read_revision(), "session" = boot_session(), "request" = input["operation"], "utc_start" = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss", 0), "tick_start" = start_tick, "engine" = "[world.byond_version].[world.byond_build]", "game_id" = blackout_diagnostic_scalar(game_id), "map" = map ? blackout_diagnostic_scalar(map.ID) : null, "phase" = blackout_diagnostic_scalar(time_of_day), "target" = list("ckey" = own_host, "client_ref" = "\ref[C]", "mob_ref" = M ? "\ref[M]" : null), "partial" = !M, "partial_reason" = M ? "none" : "no current mob")
	try
		result["sample"] = blackout_diagnostic_capture(C, M)
		var/list/sample = result["sample"]
		if(sample["bounded_sample_partial"])
			result["partial"] = TRUE
			result["partial_reason"] = "local atom sample truncated at 64 per turf"
	catch
		result["partial"] = TRUE
		result["partial_reason"] = "capture failed; exception details withheld"
	var/same_target = C && directory[own_host] == C && C.ckey == own_host && C.mob == M && C.holder && (C.holder.rights & R_HOST)
	result["same_target"] = same_target ? TRUE : FALSE
	result["tick_end"] = world.time
	result["utc_end"] = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss", 0)
	if(!same_target || world.time != start_tick)
		result["partial"] = TRUE
		result["partial_reason"] = "target or tick changed during capture"
	var/encoded = json_encode(result)
	if(length(encoded) > BLACKOUT_DIAGNOSTIC_LIMIT)
		result["sample"] = null
		result["partial"] = TRUE
		result["partial_reason"] = "sample omitted: response exceeded byte limit"
		encoded = json_encode(result)
	return encoded
