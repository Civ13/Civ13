// Default-off admin debug adapter for the ecology activity heatmap.
// Nothing runs until an admin with R_DEBUG toggles it. It samples living,
// clientless simple animals on the admin's z-level every ten seconds and shows
// the decayed scores only to that admin as client images. Runtime-only.
#define ECOLOGY_HEATMAP_DEBUG_CELL 8
#define ECOLOGY_HEATMAP_DEBUG_INTERVAL 10

var/global/datum/ecology_heatmap_debug/ecology_heatmap_debugger = null

/datum/ecology_heatmap_debug
	should_save = FALSE
	var/tmp/datum/ecology_activity_heatmap/heatmap = null
	var/tmp/client/viewer = null
	var/tmp/z_level = 0
	var/tmp/token = 0
	var/tmp/list/images = list()
	var/tmp/status = "starting"
	var/tmp/resets = 0

/datum/ecology_heatmap_debug/proc/start(client/C, z)
	viewer = C
	z_level = z
	heatmap = new /datum/ecology_activity_heatmap(4096, ECOLOGY_HEATMAP_DEBUG_INTERVAL, 600, 0.25)
	token++
	spawn(0)
		run_loop(token)

/datum/ecology_heatmap_debug/proc/stop()
	token++
	clear_images()
	if (heatmap)
		qdel(heatmap)
	heatmap = null
	viewer = null

/datum/ecology_heatmap_debug/proc/run_loop(my_token)
	while (my_token == token && viewer && heatmap)
		refresh()
		sleep(ECOLOGY_HEATMAP_DEBUG_INTERVAL * 10)
	// The viewer logged out: release everything owned by this loop.
	if (my_token == token)
		stop()
		if (ecology_heatmap_debugger == src)
			ecology_heatmap_debugger = null

/datum/ecology_heatmap_debug/proc/refresh()
	var/now = round(world.time / 10)
	var/list/seen = list()
	var/list/rows = list()
	for (var/mob/living/simple_animal/A in living_mob_list)
		if (A.stat == DEAD || A.client)
			continue
		var/turf/T = get_turf(A)
		if (!T || T.z != z_level)
			continue
		var/cx = round((T.x - 1) / ECOLOGY_HEATMAP_DEBUG_CELL) + 1
		var/cy = round((T.y - 1) / ECOLOGY_HEATMAP_DEBUG_CELL) + 1
		var/key = "[cx]:[cy]"
		if (seen[key])
			continue
		seen[key] = TRUE
		rows[++rows.len] = list(z_level, cx, cy)
	// living_mob_list is the complete source for this debug adapter.
	heatmap.sample(now, rows, TRUE, heatmap.epoch)
	if (!heatmap.coverage_valid)
		// Overflow or bad input: the heatmap holds UNKNOWN, so start a new epoch.
		resets++
		heatmap.reset_epoch(now)
		status = "UNKNOWN at [now]s ([rows.len] occupied cells), reset epoch to [heatmap.epoch]"
	else
		status = "epoch [heatmap.epoch], [rows.len] occupied cells this sample, [heatmap.cells.len] scored cells"
	draw(now)

/datum/ecology_heatmap_debug/proc/clear_images()
	if (viewer && images.len)
		viewer.images -= images
	images = list()

/datum/ecology_heatmap_debug/proc/draw(now)
	clear_images()
	if (!viewer || !heatmap)
		return
	for (var/key in heatmap.cells)
		var/list/parts = splittext(key, ":")
		var/cx = text2num(parts[2])
		var/cy = text2num(parts[3])
		var/score = heatmap.pressure(now, list(z_level, cx, cy), heatmap.epoch)
		if (!isnum(score) || score < 0.02)
			continue
		var/turf/T = locate((cx - 1) * ECOLOGY_HEATMAP_DEBUG_CELL + 1, (cy - 1) * ECOLOGY_HEATMAP_DEBUG_CELL + 1, z_level)
		if (!T)
			continue
		var/image/I = image('icons/effects/effects.dmi', T, "white")
		// Above lighting so it stays readable at night; never clickable.
		I.plane = LIGHTING_PLANE + 1
		I.mouse_opacity = 0
		I.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART
		I.color = rgb(255, round(255 * (1 - score)), 0)
		I.alpha = 40 + round(120 * score)
		var/matrix/M = matrix()
		M.Scale(ECOLOGY_HEATMAP_DEBUG_CELL)
		M.Translate((ECOLOGY_HEATMAP_DEBUG_CELL - 1) * 16, (ECOLOGY_HEATMAP_DEBUG_CELL - 1) * 16)
		I.transform = M
		images += I
	viewer.images += images

/datum/ecology_heatmap_debug/persistence_runtime_var(key)
	switch (key)
		if ("heatmap", "viewer", "z_level", "token", "images", "status", "resets")
			return TRUE
	return ..()

/datum/ecology_heatmap_debug/Destroy()
	stop()
	return ..()

/client/proc/toggle_ecology_heatmap()
	set category = "Debug"
	set name = "Toggle Ecology Heatmap"
	if (!check_rights(R_DEBUG))
		return
	if (ecology_heatmap_debugger)
		var/datum/ecology_heatmap_debug/old = ecology_heatmap_debugger
		ecology_heatmap_debugger = null
		qdel(old)
		message_admins("[key_name(src)] turned the ecology heatmap debug overlay OFF.", key_name(src))
		log_admin("[key_name(src)] turned the ecology heatmap debug overlay OFF.")
		return
	var/turf/T = get_turf(mob)
	if (!T)
		to_chat(src, "<span class='warning'>Stand on a map z-level to start the ecology heatmap.</span>")
		return
	ecology_heatmap_debugger = new /datum/ecology_heatmap_debug
	ecology_heatmap_debugger.start(src, T.z)
	message_admins("[key_name(src)] turned the ecology heatmap debug overlay ON for z[T.z].", key_name(src))
	log_admin("[key_name(src)] turned the ecology heatmap debug overlay ON for z[T.z].")
	to_chat(src, "Ecology heatmap: sampling living clientless simple animals on z[T.z] every [ECOLOGY_HEATMAP_DEBUG_INTERVAL]s in [ECOLOGY_HEATMAP_DEBUG_CELL]x[ECOLOGY_HEATMAP_DEBUG_CELL] cells. Yellow is low activity, red is high; it builds up over a few minutes. Only you see it.")

/client/proc/ecology_heatmap_status()
	set category = "Debug"
	set name = "Ecology Heatmap Status"
	if (!check_rights(R_DEBUG))
		return
	if (!ecology_heatmap_debugger)
		to_chat(src, "Ecology heatmap debug overlay is OFF.")
		return
	to_chat(src, "Ecology heatmap (viewer [key_name(ecology_heatmap_debugger.viewer)], z[ecology_heatmap_debugger.z_level]): [ecology_heatmap_debugger.status]; unknown resets [ecology_heatmap_debugger.resets].")

#undef ECOLOGY_HEATMAP_DEBUG_CELL
#undef ECOLOGY_HEATMAP_DEBUG_INTERVAL
