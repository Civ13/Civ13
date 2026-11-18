// Player view vs ghost view profiler. Test-only: run.py appends this file to a
// temporary copy of civ13.dme, starts the daemon behind a byte-counting proxy
// and connects one Dream Seeker client. For each role (ghost, human, or human
// with one player-only system switched off) the probe puts the client in a
// fresh body on open Gaia ground and runs the same stages: standing still,
// walking a cleared row (the runner holds the arrow keys), single key taps
// (the runner times key to picture) and walking past a crowd. Per stage it
// records the server's tick and map-send cost, a proc profile, the camera
// mob's glide and step timing and the client's image and screen counts. The
// runner adds bytes sent and what the client actually drew.
// With `-params headless=1` no client is awaited (staging rehearsal only).
var/global/datum/view_lag_probe/view_lag_probe = new
// Switches for the current role. "all" switches everything off.
var/global/list/view_lag_off = list()

#define VLP_SETTLE 60
#define VLP_STILL 100
#define VLP_WALK 200
#define VLP_TAPS 150
#define VLP_CROWD 200
#define VLP_STRIP 12
#define VLP_CROWD_SIZE 20

/proc/view_lag_is_off(name)
	return view_lag_off[name] || view_lag_off["all"]

// Probe-only switches. The shipped game never includes this file.
/client/root_tree_compositor_enabled()
	if(view_lag_is_off("trees"))
		return FALSE
	return ..()

/client/ambient_occlusion_enabled()
	if(view_lag_is_off("ao"))
		return FALSE
	return ..()

/mob/living/human/handle_vision()
	..()
	if(client && view_lag_is_off("lighting"))
		see_invisible = SEE_INVISIBLE_OBSERVER_NOLIGHTING
		see_in_dark = 100
		update_lighting_plane()

/mob/living/human/handle_regular_hud_updates()
	if(client && view_lag_is_off("hud"))
		return
	return ..()

/mob/living/human/update_vision_cone()
	if(view_lag_is_off("fov"))
		if(client)
			client.images -= client.hidden_atoms
			client.hidden_atoms = list()
			client.hidden_mobs = list()
		hide_cone()
		return
	return ..()

// No origin prompt for staged bodies: they take the birthplace people.
/mob/living/human/choose_origin(climate)
	if(!map || origin_id)
		return FALSE
	return apply_origin(land_origin_for(map.ID, climate), land_display_name(map), FALSE)

/mob/living/human/view_lag_actor/ssd_check()
	return FALSE

/mob/living/human/view_lag_extra/ssd_check()
	return FALSE

/datum/view_lag_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/stages = list()
	var/list/roles_run = list()
	var/phase = "startup"
	var/action = "none"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/M
	var/turf/centre
	var/turf/crowd_home
	var/list/crowd = list()
	var/crowd_active = FALSE
	var/keep_warm = FALSE

/datum/view_lag_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/view_lag_probe/proc/mark(name, new_action = "none")
	phase = name
	action = new_action
	world.log << "VIEWLAG [name] [new_action]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "action" = new_action, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod, "map" = metrics["map_layout"])), "phase.json")

/datum/view_lag_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/view_lag_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/view_lag_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/view_lag_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/view_lag_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/view_lag_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/view_lag_probe/proc/client_connected()
	return clients.len > 0

/datum/view_lag_probe/proc/open_tile(turf/T)
	if(!T || T.density || T.opacity || !istype(T, /turf/floor) || istype(T, /turf/floor/beach/water) || los_turf_roofed(T))
		return FALSE
	for(var/atom/movable/A in T)
		if(A.opacity || A.density)
			return FALSE
	return TRUE

// Open ground with a clear row east and west of it and woods in sight: the
// ordinary Gaia view, with trees for the line of sight and compositor to do.
/datum/view_lag_probe/proc/find_centre()
	for(var/attempt in 1 to 12000)
		if(attempt % 50 == 0)
			sleep(world.tick_lag)
		var/turf/T = locate(rand(40, world.maxx - 40), rand(40, world.maxy - 40), multiz_top_z())
		if(!open_tile(T))
			continue
		var/good = TRUE
		for(var/dx in -VLP_STRIP to VLP_STRIP)
			if(!open_tile(locate(T.x + dx, T.y, T.z)))
				good = FALSE
				break
		if(!good)
			continue
		var/trees = 0
		for(var/obj/structure/wild/W in range(9, T))
			trees++
		if((trees >= 12 && trees <= 60) || attempt > 9000)
			metrics["trees_near_centre"] = trees
			return T
	return null

/datum/view_lag_probe/proc/place_crowd()
	var/placed = 0
	for(var/turf/T in range(6, centre))
		if(placed >= VLP_CROWD_SIZE)
			break
		if(abs(T.y - centre.y) < 2 || !open_tile(T) || prob(60))
			continue
		var/mob/living/human/view_lag_extra/E = new(crowd_home)
		E.sleeping = 0
		E.resting = FALSE
		E.update_canmove()
		E.forceMove(T)
		crowd[E] = T
		placed++
	metrics["crowd_size"] = placed

/datum/view_lag_probe/proc/crowd_away()
	crowd_active = FALSE
	for(var/mob/living/human/view_lag_extra/E in crowd)
		E.forceMove(crowd_home)

/datum/view_lag_probe/proc/crowd_back()
	for(var/mob/living/human/view_lag_extra/E in crowd)
		E.forceMove(crowd[E])
	crowd_active = TRUE
	spawn(0)
		while(crowd_active)
			for(var/mob/living/human/view_lag_extra/E in crowd)
				if(!crowd_active)
					break
				if(prob(50))
					var/d = pick(NORTH, SOUTH, EAST, WEST)
					var/turf/T = get_step(E, d)
					var/turf/home = crowd[E]
					if(T && get_dist(T, home) <= 2 && abs(T.y - centre.y) >= 2 && open_tile(T))
						E.Move(T, d)
					else
						E.dir = d
			sleep(10)

/datum/view_lag_probe/proc/keep_body_warm()
	if(keep_warm)
		return
	keep_warm = TRUE
	spawn(0)
		while(keep_warm)
			if(ishuman(M) && !QDELETED(M))
				var/mob/living/human/H = M
				H.bodytemperature = H.species.body_temperature
				H.nutrition = 400
				H.water = 400
			for(var/mob/living/human/view_lag_extra/E in crowd)
				E.bodytemperature = E.species.body_temperature
				E.nutrition = 400
				E.water = 400
			sleep(10)

// The client takes a fresh body for each role, so every role starts from the
// same state (new HUD, new line-of-sight presentation).
/datum/view_lag_probe/proc/take_body(role)
	var/mob/old = M
	var/mob/body
	if(role == "ghost")
		var/mob/observer/ghost/G = new /mob/observer/ghost(old)
		G.forceMove(centre)
		body = G
	else
		var/mob/living/human/H = headless ? new /mob/living/human/view_lag_actor(centre) : new /mob/living/human(centre)
		H.sleeping = 0
		H.resting = FALSE
		H.update_canmove()
		body = H
	if(C)
		// No first-login questions or tutorial: their windows would cover the
		// map and take the keyboard.
		if(C.prefs)
			C.prefs.first_choices_done = TRUE
			C.prefs.tutorial_state = TUTORIAL_OFFERED
		body.ckey = C.ckey
		sleep(30)
		C = body.client
		require(C && C.mob == body, "The client did not take the [role] body")
		// Hotkey mode with the map focused, so held arrow keys move the body.
		winset(C, null, "mainwindow.macro=hotkeymode mapwindow.map.focus=true")
	M = body
	if(old && old != M && !isnewplayer(old))
		qdel(old)
	if(C)
		C.set_geometric_los(!view_lag_is_off("los"))
		C.refresh_ambient_occlusion()
	if(config)
		config.disable_fov = view_lag_is_off("fov") ? TRUE : FALSE
	keep_body_warm()

/datum/view_lag_probe/proc/map_layout()
	if(!C)
		return null
	return list("window" = winget(C, "mainwindow", "size"), "map" = winget(C, "mapwindow.map", "size"), "splitter" = winget(C, "mainwindow.mainvsplit", "splitter"), "view" = "[C.view]", "icon_size" = winget(C, "mapwindow.map", "icon-size"))

/datum/view_lag_probe/proc/recentre()
	M.forceMove(centre)
	M.dir = EAST
	if(C)
		C.los_dirty = TRUE
		// Any window that opened since (a notice, a prompt) must not keep the
		// keyboard: held arrows then stop after one tile.
		winset(C, null, "mainwindow.macro=hotkeymode mapwindow.map.focus=true")

/datum/view_lag_probe/proc/top_procs(text)
	var/list/rows = json_decode(text)
	if(!islist(rows))
		return list()
	var/list/out = list()
	// Keep the 25 heaviest by self time; sorting by hand is fine at this size.
	for(var/i in 1 to 25)
		var/best = null
		var/best_self = -1
		for(var/list/R in rows)
			if(R in out)
				continue
			var/s = text2num("[R["self"]]")
			if(s > best_self)
				best_self = s
				best = R
		if(!best)
			break
		out += list(best)
	return out

// Settles, then measures for a fixed time while the runner acts.
/datum/view_lag_probe/proc/stage(role, kind, length_ds, runner_action)
	var/name = "[role]_[kind]"
	recentre()
	mark("settle_[name]", "none")
	sleep(VLP_SETTLE)
	world.Profile(PROFILE_CLEAR)
	world.Profile(PROFILE_START)
	var/start = world.time
	var/samples = 0
	var/tick_sum = 0
	var/tick_max = 0
	var/list/ticks = list()
	var/cpu_sum = 0
	var/map_sum = 0
	var/map_max = 0
	var/glide_sum = 0
	var/glide_min = 1000
	var/glide_max = 0
	var/moves = 0
	var/list/step_gaps = list()
	var/last_move = 0
	var/turf/last_turf = get_turf(M)
	var/images_max = 0
	var/screen_max = 0
	mark("measure_[name]", runner_action)
	while(world.time < start + length_ds)
		var/t = world.tick_usage
		tick_sum += t
		tick_max = max(tick_max, t)
		ticks += t
		cpu_sum += world.cpu
		map_sum += world.map_cpu
		map_max = max(map_max, world.map_cpu)
		glide_sum += M.glide_size
		glide_min = min(glide_min, M.glide_size)
		glide_max = max(glide_max, M.glide_size)
		var/turf/now = get_turf(M)
		if(now != last_turf)
			moves++
			if(last_move)
				step_gaps += world.time - last_move
			last_move = world.time
			last_turf = now
		if(C)
			images_max = max(images_max, length(C.images))
			screen_max = max(screen_max, length(C.screen))
		samples++
		sleep(world.tick_lag)
	var/profile = world.Profile(PROFILE_REFRESH, null, "json")
	world.Profile(PROFILE_STOP)
	fdel("profile_[name].json")
	if(profile)
		text2file(profile, "profile_[name].json")
	samples = max(1, samples)
	sortTim(ticks, /proc/cmp_numeric_asc)
	var/list/row = list(
		"role" = role, "kind" = kind, "seconds" = (world.time - start) / 10,
		"tick_usage_avg" = round(tick_sum / samples, 0.1), "tick_usage_p95" = round(ticks[max(1, round(ticks.len * 0.95))], 0.1), "tick_usage_max" = round(tick_max, 0.1),
		"cpu_avg" = round(cpu_sum / samples, 0.1), "map_cpu_avg" = round(map_sum / samples, 0.1), "map_cpu_max" = round(map_max, 0.1),
		"glide_avg" = round(glide_sum / samples, 0.01), "glide_min" = round(glide_min, 0.01), "glide_max" = round(glide_max, 0.01),
		"moves" = moves, "step_gaps_ds" = step_gaps, "images_max" = images_max, "screen_max" = screen_max,
		"images_end" = C ? length(C.images) : 0, "screen_end" = C ? length(C.screen) : 0,
		"see_invisible" = M.see_invisible, "see_in_dark" = M.see_in_dark,
		"los_presenter" = !!(C && C.los_presenter && !C.los_presenter.retired),
		"compositor" = !!(C && C.root_tree_presenter && !C.root_tree_presenter.retired),
		"tick_lag" = world.tick_lag, "top_procs" = profile ? top_procs(profile) : list())
	stages[name] = row
	mark("done_[name]", "none")
	write_partial()

/datum/view_lag_probe/proc/write_partial()
	fdel("stages.json")
	text2file(json_encode(stages), "stages.json")

/datum/view_lag_probe/proc/run_role(role)
	view_lag_off = list()
	var/list/parts = splittext(role, "_no_")
	if(parts.len > 1)
		view_lag_off[parts[2]] = TRUE
	if(findtext(role, "all_off"))
		view_lag_off["all"] = TRUE
	var/kind = findtext(role, "ghost") == 1 ? "ghost" : "human"
	mark("switch_[role]", "none")
	take_body(kind)
	if(C)
		metrics["map_layout"] = map_layout()
	stage(role, "still", VLP_STILL, "still")
	stage(role, "walk", VLP_WALK, "walk")
	stage(role, "taps", VLP_TAPS, "taps")
	crowd_back()
	stage(role, "crowd", VLP_CROWD, "walk")
	crowd_away()
	roles_run += role

/datum/view_lag_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	headless = world.params["headless"] ? TRUE : FALSE
	try
		mark("startup")
		wait_for("scheduler_ready", 9000, "Scheduler/ticker never became ready")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("game_playing", 3000, "Round did not reach PLAYING")
		wait_for("lighting_settled", 6000, "Lighting never settled")
		metrics["map"] = list("id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "headless" = headless, "daylight_on_client" = daylight_on_client(), "time_of_day" = time_of_day, "tick_lag" = world.tick_lag)
		mark("scene")
		centre = find_centre()
		require(centre, "No open ground with a clear row found")
		metrics["centre"] = "[centre.x],[centre.y],[centre.z]"
		crowd_home = locate(clamp(centre.x + 60, 2, world.maxx - 2), centre.y, centre.z)
		if(abs(crowd_home.x - centre.x) < 40)
			crowd_home = locate(clamp(centre.x - 60, 2, world.maxx - 2), centre.y, centre.z)
		place_crowd()
		crowd_away()
		if(!headless)
			mark("waiting_for_client")
			wait_for("client_connected", 18000, "No client connected within 30 minutes")
			C = clients[1]
			sleep(100)
			show_browse(C, null, "window=playersetup")
			metrics["client"] = list("byond_version" = C.byond_version, "byond_build" = C.byond_build, "fps" = C.fps)
		var/list/roles = splittext(world.params["roles"] || "ghost,human,human_no_los,human_no_trees,human_no_fov,human_no_ao,human_no_lighting,human_no_hud,human_all_off,ghost_repeat,human_repeat", ",")
		for(var/role in roles)
			run_role(role)
		pass("roles_measured", list("roles" = roles_run))
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	world.Profile(PROFILE_STOP)
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "stages" = stages, "roles" = roles_run, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: view lag probe: [failure]" : "PASS: view lag probe")
	sleep(20)
	del(world)

#undef VLP_SETTLE
#undef VLP_STILL
#undef VLP_WALK
#undef VLP_TAPS
#undef VLP_CROWD
#undef VLP_STRIP
#undef VLP_CROWD_SIZE
