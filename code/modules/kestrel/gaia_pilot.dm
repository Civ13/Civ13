// SPDX-License-Identifier: AGPL-3.0-only
// Runtime-only opt-in controller; native implementation remains private.
// Continuous mode: no attempt budget. The first 64 native results and then one in
// every shadow_interval are checked against ordinary DM; any mismatch, native call
// error or failed cleanup latches ordinary DM for the rest of the process.
var/global/datum/kestrel_gaia_pilot/kestrel_gaia
/hook/startup/proc/start_kestrel_gaia_pilot()
	if(!kestrel_gaia)
		kestrel_gaia = new /datum/kestrel_gaia_pilot
	kestrel_gaia.initialize_pilot()
	return TRUE
/datum/kestrel_gaia_pilot
	var/enabled = FALSE
	var/configured = FALSE
	var/initialized = FALSE
	// Counters since the last report; DM numbers are float32, so they are folded
	// into the *_total lists (millions, units) before they can lose precision.
	var/attempts = 0
	var/native_results = 0
	var/fallbacks = 0
	var/shadow_checks = 0
	var/mismatches = 0
	var/list/attempts_total = list(0, 0)
	var/list/native_total = list(0, 0)
	var/list/fallback_total = list(0, 0)
	var/list/shadow_total = list(0, 0)
	var/shadow_remaining = 64
	var/shadow_interval = 256
	var/since_shadow = 0
	var/report_interval = 3000 // deciseconds (5 minutes)
	var/diagnostic = "not requested"
	var/dll = "kestrel_gaia_pathscore_v1.dll"
/datum/kestrel_gaia_pilot/proc/fold(list/total, amount)
	total[2] += amount
	while(total[2] >= 1000000)
		total[2] -= 1000000
		total[1]++
/datum/kestrel_gaia_pilot/proc/total_text(list/total)
	if(!total[1])
		return "[total[2]]"
	var/units = "[total[2]]"
	while(length(units) < 6)
		units = "0[units]"
	return "[total[1]][units]"
/datum/kestrel_gaia_pilot/proc/fold_counters()
	fold(attempts_total, attempts)
	fold(native_total, native_results)
	fold(fallback_total, fallbacks)
	fold(shadow_total, shadow_checks)
	attempts = 0
	native_results = 0
	fallbacks = 0
	shadow_checks = 0
/datum/kestrel_gaia_pilot/proc/native_stats_text()
	if(!configured)
		return "dll=unloaded"
	try
		var/list/s = json_decode(call_ext(dll, "byond:kestrel_stats")())
		if(islist(s))
			return "dll_enabled=[s["enabled"]] dll_executions=[s["executions"]] guard=[s["guardExits"]] cold=[s["coldExits"]] compiled=[s["compiled"]] cache=[s["cacheBytes"]]"
	catch
	return "dll_stats=unavailable"
/datum/kestrel_gaia_pilot/proc/note(reason)
	diagnostic = reason
	fold_counters()
	world.log << "KESTREL_GAIA [reason]; attempts=[total_text(attempts_total)] native=[total_text(native_total)] fallback=[total_text(fallback_total)] shadow=[total_text(shadow_total)] mismatch=[mismatches] [native_stats_text()]"
/datum/kestrel_gaia_pilot/proc/report_loop()
	set waitfor = FALSE
	while(enabled)
		sleep(report_interval)
		if(!enabled)
			return
		note("periodic")
/datum/kestrel_gaia_pilot/proc/initialize_pilot()
	if(initialized)
		return
	initialized = TRUE
	if(!fexists("config/kestrel-jit.json"))
		note("ordinary DM: no explicit JIT config")
		return
	var/list/settings
	try
		var/text = file2text("config/kestrel-jit.json")
		if(length(text) > 4096)
			note("ordinary DM: oversized config")
			return
		settings = json_decode(text)
	catch
		note("ordinary DM: invalid config")
		return
	if(!islist(settings) || settings["enabled"] != TRUE)
		note("ordinary DM: JIT disabled")
		return
	var/explicit_gaia = settings["server_id"] == "gaia-test" && istype(map, /obj/map_metadata/nomads/gaia)
	var/explicit_aotd = settings["server_id"] == "tdm-aotd" && istype(map, /obj/map_metadata/art_of_the_deal)
	if(settings["contract"] != "kestrel-gaia-pathscore-v1" || !(explicit_gaia || explicit_aotd))
		note("ordinary DM: explicit supported instance/map pair required")
		return
	if(world.byond_version != 516 || world.byond_build != 1688 || world.system_type != MS_WINDOWS)
		note("ordinary DM: requires Windows x86 BYOND 516.1688")
		return
	if(!fexists(dll))
		note("ordinary DM: reviewed artifact missing")
		return
	try
		if(call_ext(dll, "byond:kestrel_gaia_identity")() != "kestrel-gaia-pathscore-v1;516.1688;windows-x86;ordered3")
			note("ordinary DM: native contract mismatch")
			return
		if(call_ext(dll, "byond:kestrel_configure")(TRUE, 1, FALSE) != TRUE)
			note("ordinary DM: native admission refused")
			return
		configured = TRUE
		enabled = TRUE
		note("enabled: continuous path-score acceleration, 64 initial shadows then 1/[shadow_interval] sampled, report every [report_interval / 10]s")
		report_loop()
	catch
		enabled = FALSE
		note("ordinary DM: load/admission error")
/datum/kestrel_gaia_pilot/proc/disable(reason)
	enabled = FALSE
	if(configured)
		try
			var/off = call_ext(dll, "byond:kestrel_configure")(FALSE, 1, FALSE)
			var/list/s = json_decode(call_ext(dll, "byond:kestrel_stats")())
			if(off != FALSE || !islist(s) || s["enabled"] != 0 || s["cacheBytes"] != 0 || s["ownedAllocations"] != 0 || s["publishedBytes"] != 0 || s["cleanupIncomplete"] != 0)
				note("disabled ([reason]); cleanup unconfirmed; no re-enable in this process")
				return
		catch
			note("disabled ([reason]); cleanup error; no re-enable in this process")
			return
	note(reason)
/datum/kestrel_gaia_pilot/proc/path_score_dm(g, step_scale, terrain_cost)
	var/dist = step_scale * terrain_cost
	return g + dist
/datum/kestrel_gaia_pilot/proc/path_score(g, step_scale, terrain_cost)
	if(!enabled)
		return path_score_dm(g, step_scale, terrain_cost)
	if(!isnum(g) || !isnum(step_scale) || !isnum(terrain_cost) || g < 0 || g > 1000000 || !(step_scale == 1 || step_scale == 1.414) || terrain_cost < 1 || terrain_cost > 10000)
		fallbacks++
		return path_score_dm(g, step_scale, terrain_cost)
	attempts++
	var/value
	try
		value = call_ext(dll, "byond:kestrel_run")(1, g, step_scale, terrain_cost)
	catch
		disable("native call error; ordinary DM")
	if(!isnum(value) || !(value >= 1 && value <= 1100000))
		fallbacks++
		return path_score_dm(g, step_scale, terrain_cost)
	native_results++
	var/shadow = FALSE
	if(shadow_remaining > 0)
		shadow_remaining--
		shadow = TRUE
	else if(++since_shadow >= shadow_interval)
		since_shadow = 0
		shadow = TRUE
	if(shadow)
		shadow_checks++
		var/original = path_score_dm(g, step_scale, terrain_cost)
		if(value != original)
			mismatches++
			disable("path-score mismatch; ordinary DM")
		return original
	return value
