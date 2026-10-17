// Real save -> load cycle in the full game, comparing turf lighting overlays.
// Included instead of probe.dm's exercise by run.py --lighting-load.
/datum/core_boot_probe/var/list/lighting_samples = list()

/datum/core_boot_probe/proc/lighting_quiet()
	return !lighting_update_overlays.len && !lighting_update_lights.len && !processes.time_of_day_change.updating_lighting

/datum/core_boot_probe/proc/sample_turfs()
	var/list/turfs_out = list()
	var/step = max(1, round(world.maxx * world.maxy / 3000))
	var/i = 0
	for (var/turf/T in block(locate(1, 1, 1), locate(world.maxx, world.maxy, 1)))
		if (++i % step)
			continue
		var/area/A = T.loc
		if (A && A.dynamic_lighting)
			turfs_out += T
	return turfs_out

/datum/core_boot_probe/proc/overlay_brightness(atom/movable/lighting_overlay/O)
	var/list/L = O.color
	if (!islist(L) || L.len < 16)
		return -1
	// Average of the four corner RGB rows in the colour matrix.
	var/total = 0
	for (var/index in list(1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15))
		total += L[index]
	return round(total / 12, 0.001)

/datum/core_boot_probe/proc/lighting_snapshot(label)
	var/list/rows = list()
	var/missing = 0
	var/hidden = 0
	var/duplicate = 0
	var/misplaced = 0
	var/dark = 0
	var/unlit = 0 // native visibility: an overlay with luminosity 0 leaves its tile black
	var/turf_lum = 0
	var/total_brightness = 0
	var/list/turfs_sampled = sample_turfs()
	for (var/turf/T in turfs_sampled)
		var/count = 0
		for (var/atom/movable/lighting_overlay/O in T)
			count++
		if (count > 1)
			duplicate++
		var/atom/movable/lighting_overlay/O = T.lighting_overlay
		if (!O)
			missing++
			rows["[T.x],[T.y]"] = -2
			continue
		if (O.loc != T)
			misplaced++
		if (O.invisibility > INVISIBILITY_LIGHTING)
			hidden++
		if (!O.luminosity)
			unlit++
		if (T.luminosity)
			turf_lum++
		var/b = overlay_brightness(O)
		rows["[T.x],[T.y]"] = b
		total_brightness += max(b, 0)
		if (b >= 0 && b < 0.05)
			dark++
	var/list/summary = list("label" = label, "time_of_day" = time_of_day, "sampled" = turfs_sampled.len, "missing" = missing, "hidden" = hidden, "duplicate" = duplicate, "misplaced" = misplaced, "dark" = dark, "unlit" = unlit, "turf_luminous" = turf_lum, "mean_brightness" = turfs_sampled.len ? round(total_brightness / turfs_sampled.len, 0.001) : 0, "overlay_list" = lighting_overlay_list.len)
	world.log << "CORE BOOT LIGHTING [label]: [json_encode(summary)]"
	lighting_samples[label] = list("summary" = summary, "rows" = rows)
	return summary

/datum/core_boot_probe/proc/load_cycle_lighting()
	update_lighting("Midday", null, FALSE)
	wait_until(src, /datum/core_boot_probe/proc/lighting_quiet, 120, "lighting settles at Midday before saving")
	var/list/before = lighting_snapshot("before_save")
	check(before["sampled"] > 100 && !before["missing"] && !before["hidden"], "sampled lit turfs have visible overlays before saving")
	check(ticker.savemap(), "the world saves")
	mark("saved")
	check(ticker.loadmap(), "the saved world loads")
	mark("loaded")
	wait_until(src, /datum/core_boot_probe/proc/lighting_quiet, 180, "lighting settles after loading")
	sleep(50)
	var/list/after = lighting_snapshot("after_load")
	text2file(json_encode(lighting_samples), "lighting-samples.json")
	check(time_of_day == "Midday", "the saved time of day is restored")
	check(!after["missing"] && !after["duplicate"] && !after["misplaced"], "every sampled turf keeps exactly one overlay after loading")
	check(!after["hidden"], "overlays stay visible after loading")
	check(after["mean_brightness"] >= before["mean_brightness"] * 0.95, "daylight brightness survives loading ([after["mean_brightness"]] vs [before["mean_brightness"]])")
	check(after["dark"] <= before["dark"] + round(before["sampled"] / 100), "no new dark turfs after loading ([after["dark"]] vs [before["dark"]])")

// Restart path: phase 1 saves; phase 2 is a fresh process whose production
// startup imports that save. Overlays there are built before the import.
/datum/core_boot_probe/proc/restored_and_playing()
	return map_storage.round_restored && ticker && ticker.current_state == GAME_STATE_PLAYING && persistence_active_operation == null

/datum/core_boot_probe/proc/restart_save_phase()
	update_lighting("Midday", null, FALSE)
	wait_until(src, /datum/core_boot_probe/proc/lighting_quiet, 120, "lighting settles at Midday before saving")
	var/list/before = lighting_snapshot("before_save")
	check(before["sampled"] > 100 && !before["missing"] && !before["hidden"], "sampled lit turfs have visible overlays before saving")
	check(ticker.savemap(), "the world saves")
	text2file(json_encode(lighting_samples["before_save"]), "lighting-before.json")
	mark("saved")

/datum/core_boot_probe/proc/restart_load_phase()
	wait_until(src, /datum/core_boot_probe/proc/restored_and_playing, 1200, "the startup import restores the playing round")
	mark("restored")
	wait_until(src, /datum/core_boot_probe/proc/lighting_quiet, 180, "lighting settles after the startup import")
	sleep(50)
	var/list/saved = json_decode(file2text("lighting-before.json"))
	var/list/before = saved["summary"]
	var/list/after = lighting_snapshot("after_restart_load")
	text2file(json_encode(lighting_samples), "lighting-samples.json")
	check(time_of_day == before["time_of_day"], "the saved time of day is restored ([time_of_day])")
	check(!after["missing"] && !after["duplicate"] && !after["misplaced"], "every sampled turf keeps exactly one overlay after the restart import")
	check(!after["hidden"], "overlays are visible after the restart import ([after["hidden"]] hidden)")
	check(after["mean_brightness"] >= before["mean_brightness"] * 0.95, "daylight brightness survives the restart import ([after["mean_brightness"]] vs [before["mean_brightness"]])")
	check(after["dark"] <= before["dark"] + round(before["sampled"] / 100), "no new dark turfs after the restart import ([after["dark"]] vs [before["dark"]])")
	check(after["unlit"] <= before["unlit"] + round(before["sampled"] / 100), "no newly unlit overlays after the restart import ([after["unlit"]] vs [before["unlit"]])")
