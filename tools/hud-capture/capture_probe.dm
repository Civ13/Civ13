// Capture-only probe (tools/hud-capture): boots Gaia, hands the connected
// DreamSeeker guest a dressed human and asks the runner for a screenshot of
// the production HUD at several HUD scales, in edit mode and with a custom
// layout. Never part of a game build. Preferences are set in memory only.
var/global/datum/hud_probe/hud_probe = new

/mob/living/human/hud_capture_subject/ssd_check()
	return FALSE

/datum/hud_probe
	var/list/checks = list()
	var/list/log = list()
	var/list/layouts = list()
	var/started_tod = 0

/datum/hud_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		config.guests_allowed = TRUE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/hud_probe/proc/note(text)
	log += "[world.time]: [text]"
	world.log << "HUD: [text]"

/datum/hud_probe/proc/check(name, condition, details = null)
	checks += list(list("check" = name, "passed" = !!condition, "details" = details))
	note("[condition ? "PASS" : "FAIL"] [name] [details ? json_encode(details) : ""]")

/datum/hud_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/hud_probe/proc/scheduler_ready()
	return ticker && processScheduler && ticker.current_state >= GAME_STATE_PREGAME

/datum/hud_probe/proc/client_present()
	for (var/client/C in clients)
		return TRUE
	return FALSE

/datum/hud_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/hud_probe/proc/find_ground()
	var/cx = round(world.maxx / 2)
	var/cy = round(world.maxy / 2)
	for (var/r = 0, r <= 150, r += 3)
		for (var/dx = -r, dx <= r, dx += 3)
			for (var/dy = -r, dy <= r, dy += 3)
				var/turf/T = locate(cx + dx, cy + dy, 2)
				if (istype(T, /turf/floor) && !istype(T, /turf/floor/beach/water) && !T.density)
					return T
	return null

/datum/hud_probe/proc/shot(name)
	sleep(15)
	fdel("shot-[name].done")
	text2file(name, "shot-[name].req")
	var/until = world.time + 300
	while (!fexists("shot-[name].done") && world.time < until)
		sleep(2)
	note("shot [name] [fexists("shot-[name].done") ? "taken" : "TIMED OUT"]")

// Records what the production code placed, so the stills can be checked.
/datum/hud_probe/proc/record(mob/living/human/H, label)
	var/list/rows = list()
	for (var/obj/screen/S in H.hud_layout_elements() + H.hud_action_buttons())
		var/matrix/M = S.transform
		rows["[S.hud_layout_key]"] = list("loc" = S.screen_loc, "scale" = M ? M.a : 1, "color" = S.color)
	layouts[label] = list("view" = H.client.view, "scale" = H.client.prefs.hud_scale, "tiles" = rows)

/datum/hud_probe/proc/layout(mob/living/human/H, label, scale)
	H.client.prefs.hud_scale = scale
	H.apply_hud_layout()
	record(H, label)
	shot(label)

/datum/hud_probe/proc/drive()
	var/failure = null
	try
		wait_for("scheduler_ready", 9000, "Scheduler never ready")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("game_playing", 3000, "Round did not reach PLAYING")
		var/turf/T = find_ground()
		if (!T)
			throw EXCEPTION("No ground found")
		update_lighting("Midday", null, FALSE)
		text2file("ready", "cloud-ready.txt")
		wait_for("client_present", 3000, "No client connected")
		var/client/C = clients[1]
		var/mob/living/human/hud_capture_subject/H = new(T)
		sleep(10)
		H.ckey = C.ckey
		sleep(20)
		C << browse(null, "window=playersetup")
		C << browse(null, "window=latechoices")
		check("client_owns_subject", C.mob == H, list("mob" = "[C.mob]", "style" = H.defaultHUD))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet(H), slot_head)
		H.put_in_r_hand(new /obj/item/weapon/material/hatchet(H))
		H.update_hud()
		sleep(10)
		C.prefs.hud_layout = list()
		layout(H, "1-scale-100", 1)
		layout(H, "2-scale-75", 0.75)
		layout(H, "3-scale-50", 0.5)
		layout(H, "4-scale-125", 1.25)
		layout(H, "5-scale-150", 1.5)
		layout(H, "6-scale-200", 2)
		var/style = H.defaultHUD
		C.prefs.hud_layout = list(
			"[style]~need:health~WEST~8~NORTH~-88~1.5~1",
			"[style]~need:mood~WEST~56~NORTH~-88~1~1",
			"[style]~need:nutrition~WEST~56~NORTH~-56~1~1",
			"[style]~need:body temperature~WEST~88~NORTH~-56~1~1",
			"[style]~inv:[slot_r_hand]~CENTER~-48~SOUTH~40~1.5~1",
			"[style]~inv:[slot_l_hand]~CENTER~0~SOUTH~40~1.5~1")
		C.hud_edit_mode = TRUE
		layout(H, "7-edit-mode-custom", 1)
		check("edit_tint_applied", H.HUDneed["health"] && H.HUDneed["health"]:color == "#ff8a8a")
		H.end_hud_edit()
		layout(H, "8-custom-layout", 1)
		check("tint_cleared", H.HUDneed["health"] && H.HUDneed["health"]:color != "#ff8a8a")
	catch(var/exception/e)
		failure = "[e.name] [e.file]:[e.line]"
		note("EXCEPTION [failure]")
	var/failed = 0
	for (var/list/row in checks)
		if (!row["passed"])
			failed++
	text2file(json_encode(list("passed" = isnull(failure) && !failed, "failure" = failure, "failed" = failed, "checks" = checks, "log" = log, "layouts" = layouts, "wall_ds" = world.timeofday - started_tod)), "result.json")
	text2file("done", "capture-done.txt")
