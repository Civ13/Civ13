// Headless full-game acceptance probe for generated ground snow (#3312).
// Test-only: full_game.py appends it to a temporary copy of civ13.dme with the
// Gaia map. Production snow, weather, season, action, lifecycle and persistence
// code runs unchanged; the probe only drives it and records what happened.
var/global/datum/snowfall_game_probe/snowfall_game_probe = new

/datum/snowfall_game_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/sites = list()
	var/phase = "startup"
	var/started_tod = 0
	var/list/scale_expected
	var/list/scale_terrain
	var/list/scale_actors

/datum/snowfall_game_probe/New()
	// Linux 516.1688 stops global_init at makeDatumRefLists before configuration
	// loads; finish the same initialisers once before world/New needs them.
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

/datum/snowfall_game_probe/proc/mark(name)
	phase = name
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/snowfall_game_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/snowfall_game_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/snowfall_game_probe/proc/wait_for(datum/target, proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(target, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

// Gaia's own round-start season timer would otherwise turn WINTER into SPRING
// part-way through accumulation. The probe forces each season it needs; the
// season workers themselves still run unchanged.
/datum/snowfall_game_probe/proc/hold_natural_seasons()
	if(map.uses_durable_metadata())
		map.durable_timer_queue().cancel("season_loop")
	map.season_loop_scheduled = TRUE

/datum/snowfall_game_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/snowfall_game_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && processes.snowfall_ground && ticker.current_state >= GAME_STATE_PREGAME

/datum/snowfall_game_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	try
		mark("startup")
		wait_for(src, "scheduler_ready", 9000, "Scheduler/ticker never became ready")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for(src, "game_playing", 3000, "Round did not reach PLAYING")
		// Keep random weather from changing the area under a controlled check.
		// The weather process and every production weather proc still run.
		if(processes.weather)
			processes.weather.next_can_mod_weather = world.realtime + 864000
			processes.weather.next_can_change_weather = world.realtime + 864000
		metrics["map"] = list("id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "z_levels" = z_levels, "durable_metadata" = map.uses_durable_metadata(), "byond_version" = world.byond_version, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"])
		check_registry("startup")
		mark("seasons_to_winter")
		reach_season("WINTER")
		hold_natural_seasons()
		// Controlled single-tile checks call the production check directly; the
		// scheduled worker is paused until the scale phase re-enables it.
		processes.snowfall_ground.disable()
		mark("climate")
		check_climate()
		mark("handlers")
		check_handlers()
		mark("lifecycle")
		check_lifecycle()
		mark("scale_accumulate")
		processes.snowfall_ground.enable()
		check_scale_accumulation()
		mark("persistence")
		if(!world.params["skip_persistence"]) // Development runs only; the runner never sets it.
			check_persistence()
		mark("scale_melt")
		check_seasonal_melt()
		check_registry("final")
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "wall_ds" = world.timeofday - started_tod)
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: snowfall full-game probe: [failure]" : "PASS: snowfall full-game probe")
	sleep(5)
	del(world)

// Registry integrity: every eligible floor appears once, at its own index.
/datum/snowfall_game_probe/proc/check_registry(label)
	var/eligible = 0
	var/work = 0
	for(var/turf/floor/T in world)
		if(T.gc_destroyed)
			require(!T.snowfall_ground_index, "[label]: destroyed turf still registered")
		else if(T.type == /turf/floor/dirt || T.type == /turf/floor/grass)
			eligible++
			require(T.snowfall_ground_index && snowfall_ground[T.snowfall_ground_index] == T, "[label]: eligible turf missing from registry at [T.x],[T.y],[T.z]")
		else
			require(!T.snowfall_ground_index, "[label]: ineligible [T.type] registered at [T.x],[T.y],[T.z]")
		if(++work % 20000 == 0)
			sleep(world.tick_lag)
	require(snowfall_ground.len == eligible, "[label]: registry length [snowfall_ground.len] != eligible floors [eligible]")
	for(var/i = 1 to snowfall_ground.len)
		var/turf/T = snowfall_ground[i]
		require(T && T.snowfall_ground_index == i, "[label]: registry entry [i] has wrong back-index")
	pass("registry_[label]", list("candidates" = snowfall_ground.len))

/datum/snowfall_game_probe/proc/season_done(target)
	return season == target && !map.season_busy

/datum/snowfall_game_probe/proc/reach_season(target)
	var/list/path = list()
	var/guard = 0
	while(season != target)
		require(++guard <= 4, "Season [target] not reached")
		var/from = season
		spawn(0)
			map.seasons(FALSE, TRUE, FALSE)
		var/until = world.time + 6000
		while(season == from || map.season_busy)
			require(world.time < until, "Forced season change from [from] stalled")
			sleep(5)
		path += "[from]->[season]"
	pass("season_[target]", list("path" = path, "season" = season))

/datum/snowfall_game_probe/proc/snow_icon(area/A)
	return replacetext("[A.icon_state]", "rad_", "") in list("snow1", "snow2", "snow_storm")

/datum/snowfall_game_probe/proc/site_clear(turf/floor/T)
	if(!T || (T.type != /turf/floor/grass && T.type != /turf/floor/dirt) || T.x < 6 || T.y < 6 || T.x > world.maxx - 6 || T.y > world.maxy - 6)
		return FALSE
	// Lighting and seasonal overlay objects live in turf contents; only piles,
	// mobs and dense objects would disturb the checks.
	if((locate(/obj/item/weapon/snowwall) in T) || (locate(/mob) in T) || !T.snowfall_ground_exposed() || T.weather_snow)
		return FALSE
	for(var/turf/N in range(3, T))
		if(N.density || get_area(N) != get_area(T) || (locate(/mob) in N) || (locate(/obj/roof) in N) || (locate(/obj/covers) in N))
			return FALSE
		for(var/obj/O in N)
			if(O.density)
				return FALSE
	return TRUE

// Distinct, spaced exposed grass sites in snowing, freezing outdoor areas.
/datum/snowfall_game_probe/proc/pick_sites(count)
	var/list/found = list()
	var/work = 0
	for(var/i = 1 to snowfall_ground.len)
		var/turf/floor/T = snowfall_ground[i]
		if(++work % 2000 == 0)
			sleep(world.tick_lag)
		var/area/A = get_area(T)
		if(!snow_icon(A) || get_temp(T) > SNOWFALL_STICK_C || !site_clear(T))
			continue
		var/far = TRUE
		for(var/turf/O in found)
			if(get_dist(O, T) < 12)
				far = FALSE
				break
		if(far)
			found += T
			if(found.len >= count)
				break
	if(found.len < count)
		var/list/why = list("snowing" = 0, "freezing" = 0, "clear" = 0, "not_grass" = 0, "not_exposed" = 0, "blocked_nearby" = 0)
		for(var/i = 1 to snowfall_ground.len)
			var/turf/floor/T = snowfall_ground[i]
			var/area/A = get_area(T)
			if(snow_icon(A))
				why["snowing"]++
				if(get_temp(T) <= SNOWFALL_STICK_C)
					why["freezing"]++
					if(site_clear(T))
						why["clear"]++
					else if(T.type != /turf/floor/grass && T.type != /turf/floor/dirt)
						why["not_grass"]++
					else if(!T.snowfall_ground_exposed())
						why["not_exposed"]++
					else
						why["blocked_nearby"]++
			if(i % 2000 == 0)
				sleep(world.tick_lag)
		throw EXCEPTION("Only [found.len] clear snowing sites found: [json_encode(why)] season=[season] weather=[weather]")
	return found

/datum/snowfall_game_probe/proc/overlay_count(turf/T)
	var/n = 0
	// Overlay entries are appearances, not /image instances.
	for(var/I in T.overlays)
		if(I:icon == 'icons/turf/snow.dmi' && I:icon_state == "snow" && I:layer == 2.03)
			n++
	return n

/datum/snowfall_game_probe/proc/check_climate()
	change_weather(WEATHER_WET, TRUE)
	var/list/picked = pick_sites(8)
	// The shovel check needs a grass site; ground type is otherwise irrelevant.
	for(var/i = 1 to picked.len)
		var/turf/G = picked[i]
		if(G.type == /turf/floor/grass)
			picked.Swap(i, 5)
			break
	var/turf/grass_site = picked[5]
	require(grass_site.type == /turf/floor/grass, "No clear snowing grass site")
	sites = picked
	var/turf/floor/T = picked[1]
	var/area/A = get_area(T)
	var/before_temp = get_temp(T)
	require(A.weather == WEATHER_WET && snow_icon(A) && before_temp <= SNOWFALL_STICK_C, "Production winter weather did not snow at the site")
	var/gen0 = T.snowfall_ground_generation
	T.snowfall_ground_check()
	require(T.weather_snow == 1 && T.snowfall_ground_generation != gen0 && overlay_count(T) == 1, "Real climate did not accumulate one unit: units [T.weather_snow], overlays [overlay_count(T)], temp [before_temp], area [A.type] [A.icon_state]")
	T.snowfall_ground_check()
	T.snowfall_ground_check()
	require(T.weather_snow == SNOWFALL_MAX_UNITS && overlay_count(T) == 1, "Accumulation did not cap at [SNOWFALL_MAX_UNITS] with one overlay")
	var/image/overlay = T.weather_snow_overlay
	pass("real_climate_accumulation", list("site" = "[T.x],[T.y],[T.z]", "area" = "[A.type]", "climate" = A.climate, "precipitation" = A.icon_state, "get_temp" = before_temp, "time_of_day" = time_of_day, "overlay_plane" = overlay.plane, "turf_plane" = T.plane, "overlay_layer" = overlay.layer))
	// Real heat sources at their production ranges melt cover on the next check.
	var/list/heat_rows = list()
	for(var/kind in list(/obj/structure/brazier, /obj/structure/heatsource, /obj/structure/oven/fireplace))
		T.snowfall_ground_check()
		T.snowfall_ground_check()
		require(T.weather_snow == SNOWFALL_MAX_UNITS, "Could not re-accumulate before [kind]")
		var/reach = kind == /obj/structure/oven/fireplace ? 1 : 3
		var/turf/place = locate(T.x + reach, T.y, T.z)
		var/obj/structure/heater = new kind(place)
		heater:on = FALSE
		var/cold = get_temp(T)
		T.snowfall_ground_check(FALSE)
		require(T.weather_snow == SNOWFALL_MAX_UNITS, "Unlit [kind] melted snow")
		heater:on = TRUE
		var/hot = get_temp(T)
		var/gen = T.snowfall_ground_generation
		T.snowfall_ground_check()
		require(hot == 22 && T.weather_snow == 0 && T.snowfall_ground_generation != gen && !overlay_count(T), "Lit [kind] at range [reach] did not melt snow")
		heater:on = FALSE
		qdel(heater)
		heat_rows += list(list("source" = "[kind]", "range" = reach, "unlit_temp" = cold, "lit_temp" = hot))
	pass("real_heat_sources_melt", list("sources" = heat_rows))
	// Dry weather keeps frozen cover and never starts new cover.
	T.snowfall_ground_check()
	change_weather(WEATHER_NONE, TRUE)
	var/turf/floor/clear = picked[2]
	clear.snowfall_ground_check()
	T.snowfall_ground_check()
	require(A.weather == WEATHER_NONE && T.weather_snow == 1 && clear.weather_snow == 0, "Dry weather changed cover")
	// Production storm path and its -82C storm temperature.
	change_weather(WEATHER_EXTREME, TRUE)
	var/area/clear_area = get_area(clear)
	clear.snowfall_ground_check()
	var/storm_temp = get_temp(clear)
	require(!snow_icon(clear_area) || clear.weather_snow == 1, "Storm weather did not accumulate")
	pass("weather_transitions", list("dry_kept_units" = T.weather_snow, "storm_precipitation" = clear_area.icon_state, "storm_temp" = storm_temp, "storm_units" = clear.weather_snow))
	change_weather(WEATHER_WET, TRUE)
	// A real roof switches the tile into a roofed (inside) area: no exposure,
	// insulated temperature, and cover under it melts or never starts.
	var/turf/floor/roofed = picked[3]
	roofed.snowfall_ground_check()
	require(roofed.weather_snow == 1, "Roof site did not accumulate before roofing")
	var/obj/roof/R = new /obj/roof(roofed)
	var/area/RA = get_area(roofed)
	var/roof_temp = get_temp(roofed)
	roofed.snowfall_ground_check()
	var/roof_present = !QDELETED(R) && (R in roofed)
	require(!roof_present || (!roofed.snowfall_ground_exposed() && roofed.weather_snow == 0), "Roofed tile kept or gained generated snow")
	roofed.snowfall_ground_check()
	require(!roof_present || roofed.weather_snow == 0, "Roofed tile accumulated")
	pass("real_roof_exposure", list("roof_present" = roof_present, "area" = "[RA.type]", "location" = RA.location, "temp" = roof_temp))
	// Production z-connection: Gaia's two levels are not connected, so the other
	// level is never a ceiling. A temporarily connected pair then uses the real
	// GetAbove path for an outdoor candidate on the lower level, if there is one.
	var/turf/floor/upper_site = picked[4]
	require(isnull(GetAbove(upper_site)) && upper_site.snowfall_ground_exposed(), "Unconnected level acted as a ceiling")
	var/turf/floor/lower = null
	for(var/i = 1 to snowfall_ground.len)
		var/turf/floor/C = snowfall_ground[i]
		var/area/CA = get_area(C)
		if(C.z < world.maxz && istype(CA, /area/caribbean) && CA.location == AREA_OUTSIDE && !(locate(/obj/roof) in C) && !(locate(/obj/covers) in C))
			lower = C
			break
	var/saved_levels = z_levels
	var/list/connected = list("production_z_levels" = saved_levels, "site_z" = upper_site.z)
	if(lower)
		var/turf/above_turf = locate(lower.x, lower.y, lower.z + 1)
		var/unconnected_exposed = lower.snowfall_ground_exposed()
		z_levels |= (1 << (lower.z - 1))
		var/connected_above = GetAbove(lower)
		var/open_above = istype(above_turf, /turf/sky) || istype(above_turf, /turf/floor/broken_floor) || istype(above_turf, /turf/floor/space)
		var/connected_exposed = lower.snowfall_ground_exposed()
		z_levels = saved_levels
		require(unconnected_exposed && connected_above == above_turf && connected_exposed == (open_above && !(locate(/obj/roof) in above_turf) && !(locate(/obj/covers) in above_turf)), "Connected-level exposure disagreed with the turf above")
		connected += list("lower_site" = "[lower.x],[lower.y],[lower.z]", "above_type" = "[above_turf.type]", "connected_exposed" = connected_exposed)
	else
		connected["lower_outdoor_candidates"] = 0
	pass("connected_level_exposure", connected)

// Stands in for a connected, awake player: the inherited human with only the
// SSD sleep check off, so Life does not put the headless body to sleep.
/mob/living/human/snow_probe_actor/ssd_check()
	return FALSE

/datum/snowfall_game_probe/proc/human_at(turf/T)
	var/mob/living/human/snow_probe_actor/H = new(T)
	sleep(10)
	H.sleeping = 0
	H.resting = FALSE
	H.update_canmove()
	H.a_intent = I_HELP
	require(H.stat == CONSCIOUS && !H.lying && !H.incapacitated(), "Probe actor is not conscious and standing")
	return H

/datum/snowfall_game_probe/proc/arm(mob/living/human/H, kind)
	var/obj/item/I = new kind(H.loc)
	H.drop_item()
	require(H.put_in_active_hand(I) && H.get_active_hand() == I, "Could not arm [H] with [kind]: lying [H.lying], stat [H.stat], hands [H.l_hand]/[H.r_hand]")
	return I

/datum/snowfall_game_probe/proc/piles(turf/T)
	var/n = 0
	for(var/obj/item/weapon/snowwall/S in T)
		n++
	return n

/datum/snowfall_game_probe/proc/settle(list/humans, timeout_ds = 900)
	var/until = world.time + timeout_ds
	while(TRUE)
		var/busy = FALSE
		for(var/mob/living/human/H in humans)
			if(H.shoveling || !H.may_do_after)
				busy = TRUE
		if(!busy)
			return
		require(world.time < until, "Action wait never finished")
		sleep(2)

/datum/snowfall_game_probe/proc/fill(turf/floor/T, units)
	while(T.weather_snow < units)
		var/before = T.weather_snow
		T.snowfall_ground_check()
		require(T.weather_snow > before, "Could not accumulate at [T.x],[T.y]")

/datum/snowfall_game_probe/proc/check_handlers()
	change_weather(WEATHER_WET, TRUE)
	var/turf/floor/T = sites[5]
	var/mob/living/human/H = human_at(T)
	// Shovel on generated snow over grass makes piles, never strips the grass.
	fill(T, 2)
	var/obj/item/shovel = arm(H, /obj/item/weapon/material/shovel/steel)
	var/started = world.timeofday
	spawn(0)
		T.attackby(shovel, H)
	sleep(2)
	settle(list(H))
	require(locate(T.x, T.y, T.z) == T && T.type == /turf/floor/grass && T.weather_snow == 1 && piles(T) == 1, "Shovel did not take one generated unit into one pile (type [T.type], units [T.weather_snow], piles [piles(T)])")
	var/gen = T.snowfall_ground_generation
	spawn(0)
		T.attackby(shovel, H)
	sleep(2)
	settle(list(H))
	require(T.weather_snow == 0 && piles(T) == 2 && T.snowfall_ground_generation != gen && !overlay_count(T) && T.type == /turf/floor/grass, "Second shovel did not clear the last unit")
	pass("shovel_generated_grass", list("wait_ds" = world.timeofday - started, "piles" = piles(T)))
	// Moving during the wait interrupts without taking snow or leaving a pile.
	fill(T, 1)
	var/before_piles = piles(T)
	spawn(0)
		T.attackby(shovel, H)
	sleep(5)
	H.forceMove(locate(T.x + 1, T.y, T.z))
	settle(list(H))
	require(T.weather_snow == 1 && piles(T) == before_piles && !H.shoveling, "Interrupted shovel took snow")
	H.forceMove(T)
	pass("shovel_interrupted")
	// A heater lit during the wait melts the unit; the action then takes nothing.
	spawn(0)
		T.attackby(shovel, H)
	sleep(5)
	// A fuelled brazier stays lit for the whole wait.
	var/obj/structure/brazier/loaded/B = new(locate(T.x + 2, T.y, T.z))
	var/lit_temp = get_temp(T)
	settle(list(H))
	require(T.weather_snow == 0 && piles(T) == before_piles, "Snow melted mid-action still produced a pile: units [T.weather_snow], piles [piles(T) - before_piles], lit [B.on], temp [lit_temp]")
	B.on = FALSE
	qdel(B)
	pass("melt_during_wait")
	// Two actors on one remaining unit: exactly one pile.
	fill(T, 1)
	var/mob/living/human/H2 = human_at(T)
	var/obj/item/shovel2 = arm(H2, /obj/item/weapon/material/shovel/steel)
	before_piles = piles(T)
	spawn(0)
		T.attackby(shovel, H)
	spawn(0)
		T.attackby(shovel2, H2)
	sleep(2)
	settle(list(H, H2))
	require(T.weather_snow == 0 && piles(T) == before_piles + 1, "Concurrent collection produced [piles(T) - before_piles] piles")
	pass("concurrent_single_unit")
	// Spoon uses the same production handler.
	fill(T, 1)
	var/obj/item/spoon = arm(H, /obj/item/weapon/material/kitchen/utensil/spoon)
	before_piles = piles(T)
	spawn(0)
		T.attackby(spoon, H)
	sleep(2)
	settle(list(H), 1800)
	require(T.weather_snow == 0 && piles(T) == before_piles + 1, "Spoon did not collect a unit")
	pass("spoon_generated")
	// Ant grab collection, including a repeated grab while busy.
	fill(T, 2)
	H.drop_item()
	H.ant = TRUE
	H.a_intent = I_GRAB
	before_piles = piles(T)
	spawn(0)
		T.attack_hand(H)
	sleep(3)
	T.attack_hand(H) // A repeated grab while busy must not yield a second unit.
	settle(list(H))
	require(T.weather_snow == 1 && piles(T) == before_piles + 1, "Ant collection did not take exactly one unit")
	H.ant = FALSE
	H.a_intent = I_HELP
	pass("ant_generated")
	// Authored snowy grass collects its own units and returns to ordinary grass,
	// which then joins the generated-snow registry.
	var/turf/floor/W = sites[6]
	var/wx = W.x
	var/wy = W.y
	var/wz = W.z
	W.ChangeTurf(/turf/floor/winter/grass)
	var/turf/floor/winter/grass/WG = locate(wx, wy, wz)
	require(istype(WG) && !WG.snowfall_ground_index && WG.has_snow_cover(), "Authored snowy grass not created outside registry")
	H.forceMove(WG)
	arm(H, /obj/item/weapon/material/kitchen/utensil/spoon)
	var/authored = WG.available_snow
	for(var/i = 1 to authored)
		var/turf/floor/current = locate(wx, wy, wz)
		spawn(0)
			current.attackby(H.get_active_hand(), H)
		sleep(2)
		settle(list(H), 1800)
	var/turf/floor/after = locate(wx, wy, wz)
	require(after.type == /turf/floor/grass && after.snowfall_ground_index && snowfall_ground[after.snowfall_ground_index] == after && after.weather_snow == 0 && piles(after) == authored, "Authored transition failed: [after.type], piles [piles(after)]")
	pass("authored_transition", list("authored_units" = authored))
	qdel(H)
	qdel(H2)

/datum/snowfall_game_probe/proc/check_lifecycle()
	var/turf/floor/T = sites[7]
	fill(T, 2)
	T.update_icon()
	T.update_icon(TRUE)
	require(overlay_count(T) == 1 && T.weather_snow == 2, "Floor update_icon lost or duplicated the snow overlay")
	for(var/turf/floor/N in orange(1, T))
		N.update_icon()
	require(overlay_count(T) == 1, "Neighbour icon update disturbed the overlay")
	pass("floor_update_icon")
	var/x = T.x
	var/y = T.y
	var/z = T.z
	var/old_len = snowfall_ground.len
	T.ChangeTurf(/turf/floor/beach/sand)
	var/turf/floor/S = locate(x, y, z)
	require(!S.snowfall_ground_index && !S.weather_snow && snowfall_ground.len == old_len - 1, "Replacement by an ineligible floor kept registry or snow")
	S.ChangeTurf(/turf/floor/grass)
	var/turf/floor/G = locate(x, y, z)
	require(G.snowfall_ground_index && snowfall_ground[G.snowfall_ground_index] == G && !G.weather_snow && snowfall_ground.len == old_len, "Grass replacement not re-registered")
	fill(G, 1)
	// Turf references are coordinates: after the collector's native Del, the
	// same location holds world.turf. Snow and registry state must follow that.
	qdel(G)
	sleep(20)
	var/turf/floor/Q = locate(x, y, z)
	var/eligible = Q.type == /turf/floor/grass || Q.type == /turf/floor/dirt
	var/consistent = FALSE
	if(Q.gc_destroyed)
		consistent = !Q.snowfall_ground_index
	else if(eligible)
		consistent = !Q.weather_snow && Q.snowfall_ground_index && snowfall_ground[Q.snowfall_ground_index] == Q
	else
		consistent = !Q.weather_snow && !Q.snowfall_ground_index
	require(consistent, "qdel left stale snow or registry state: [Q.type], units [Q.weather_snow], index [Q.snowfall_ground_index], destroyed [Q.gc_destroyed]")
	check_registry("lifecycle")
	var/pending = Q.gc_destroyed ? TRUE : FALSE
	pass("qdel_destroy", list("replacement" = "[Q.type]", "pending_collection" = pending))

/datum/snowfall_game_probe/proc/check_persistence()
	processes.snowfall_ground.disable() // Fixed tile states across the save.
	change_weather(WEATHER_WET, TRUE)
	var/turf/floor/kept = sites[8]
	fill(kept, 2)
	var/turf/floor/legacy = sites[2]
	if(legacy.weather_snow)
		legacy.weather_snow = 0
		legacy.snowfall_ground_icon()
	var/turf/floor/retyped = sites[4]
	fill(retyped, 1)
	retyped.weather_snow = 1 // The scale phase may already have filled it.
	retyped.snowfall_ground_icon()
	var/area/KA = get_area(kept)
	var/zone_before = KA.persistence_zone_id
	map.elevation_regions = list(list("x1" = kept.x, "x2" = kept.x, "y1" = kept.y, "y2" = kept.y, "z" = kept.z, "metres" = 1234))
	map.elevation_profile_cache = null
	require(get_elevation(kept) == 1234, "Elevation fixture did not apply")
	var/kx = kept.x
	var/ky = kept.y
	var/lx = legacy.x
	var/ly = legacy.y
	var/rx = retyped.x
	var/ry = retyped.y
	var/kept_type = kept.type
	var/legacy_type = legacy.type
	var/retyped_type = retyped.type
	var/save_start = world.timeofday
	require(ticker.savemap(), "Full-game save failed: [map_storage.last_error]")
	var/save_ds = world.timeofday - save_start
	// Diverge live state after the save.
	map.elevation_regions = list()
	map.elevation_profile_cache = null
	legacy.weather_snow = 2
	legacy.snowfall_ground_icon()
	kept.weather_snow = 0
	kept.snowfall_ground_icon()
	retyped.ChangeTurf(retyped_type == /turf/floor/dirt ? /turf/floor/grass : /turf/floor/dirt)
	var/load_start = world.timeofday
	require(ticker.loadmap(), "Full-game load failed: [map_storage.last_error]")
	var/load_ds = world.timeofday - load_start
	sleep(20)
	var/turf/floor/K = locate(kx, ky, kept.z)
	var/turf/floor/L = locate(lx, ly, legacy.z)
	var/turf/floor/RT = locate(rx, ry, retyped.z)
	var/area/KB = get_area(K)
	require(K.type == kept_type && K.weather_snow == 2 && overlay_count(K) == 1 && snowfall_ground[K.snowfall_ground_index] == K, "Saved generated snow not restored")
	require(L.type == legacy_type && L.weather_snow == 0 && !overlay_count(L), "Same-type legacy import kept post-save snow")
	require(RT.type == retyped_type && RT.weather_snow == 1 && snowfall_ground[RT.snowfall_ground_index] == RT, "Retyped turf did not restore type and snow")
	require(get_elevation(K) == 1234, "Elevation snapshot not restored with snow")
	require(KB.type == KA.type && KB.location == AREA_OUTSIDE && !isnull(KB.persistence_zone_id) && (KB in area_list) && K.snowfall_ground_exposed(), "Zone topology or exposure changed across the round trip")
	pass("disk_round_trip", list("save_ds" = save_ds, "load_ds" = load_ds, "zone_before" = zone_before, "zone_after" = KB.persistence_zone_id, "elevation" = get_elevation(K)))
	check_registry("after_load")
	hold_natural_seasons()
	processes.snowfall_ground.enable()
	map.elevation_regions = list()
	map.elevation_profile_cache = null

/datum/snowfall_game_probe/proc/snapshot_terrain()
	var/list/counts = list("water" = 0, "ice" = 0, "authored_snow" = 0)
	var/work = 0
	for(var/turf/floor/T in world)
		if(istype(T, /turf/floor/beach/water))
			counts["water"]++
		if(findtext("[T.type]", "ice"))
			counts["ice"]++
		if(T.icon == 'icons/turf/snow.dmi' && !istype(T, /turf/floor/grass) && !istype(T, /turf/floor/dirt))
			counts["authored_snow"]++
		if(++work % 20000 == 0)
			sleep(world.tick_lag)
	return counts

/datum/snowfall_game_probe/proc/census(list/expected_cold)
	var/list/out = list("units1" = 0, "units2" = 0, "expected_full" = 0, "warm_with_snow" = 0)
	var/work = 0
	for(var/i = 1 to snowfall_ground.len)
		var/turf/floor/T = snowfall_ground[i]
		if(T.weather_snow == 1)
			out["units1"]++
		else if(T.weather_snow >= 2)
			out["units2"]++
			if(expected_cold && expected_cold[T])
				out["expected_full"]++
		if(++work % 4000 == 0)
			sleep(world.tick_lag)
	return out

/datum/snowfall_game_probe/proc/process_stats()
	var/process/P = processes.snowfall_ground
	return list("ticks" = P.getTicks(), "avg_run_ds" = P.getAverageRunTime(), "last_run_ds" = P.getLastRunTime(), "highest_run_ds" = P.getHighestRunTime(), "disabled" = P.disabled, "state" = ticker.current_state, "cursor" = snowfall_ground_cursor, "next_in_ds" = snowfall_ground_next - world.time, "blocked" = (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required) ? TRUE : FALSE, "weather" = weather, "season" = season)

/datum/snowfall_game_probe/proc/check_scale_accumulation()
	change_weather(WEATHER_WET, TRUE)
	var/list/terrain_before = snapshot_terrain()
	var/season_before = season
	// Expected accumulators by the production predicates at the start.
	var/list/expected = list()
	var/work = 0
	for(var/i = 1 to snowfall_ground.len)
		var/turf/floor/T = snowfall_ground[i]
		var/area/A = get_area(T)
		if(A.weather == WEATHER_WET && snow_icon(A) && get_temp(T) <= SNOWFALL_STICK_C && T.snowfall_ground_exposed())
			expected[T] = TRUE
		if(++work % 2000 == 0)
			sleep(world.tick_lag)
	require(expected.len > 1000, "Too few snowing candidates ([expected.len]) for a scale run")
	// Add ordinary headless actors for scheduler pressure.
	var/list/actors = list()
	for(var/i = 1 to 40)
		var/turf/floor/T = snowfall_ground[1 + (i * 397) % snowfall_ground.len]
		actors += new /mob/living/human(T)
	var/start = world.time
	var/start_tod = world.timeofday
	var/list/samples = list()
	var/full_at = null
	// Two units need two snowing samples per cell from a randomly ordered,
	// tick-budgeted worker; observed fills took 11,600-12,100+ ds on Gaia.
	var/until = world.time + 24000
	while(world.time < until)
		sleep(50)
		var/list/c = census(expected)
		var/list/row = list("world_ds" = world.time - start, "wall_ds" = world.timeofday - start_tod, "cpu" = world.cpu, "tick_usage" = world.tick_usage, "map_cpu" = world.map_cpu) + c + process_stats()
		samples += list(row)
		if(c["expected_full"] >= expected.len)
			full_at = world.time - start
			break
	metrics["accumulation"] = list("candidates" = snowfall_ground.len, "expected" = expected.len, "full_world_ds" = full_at, "samples" = samples)
	require(full_at, "Expected candidates did not all reach [SNOWFALL_MAX_UNITS] units in time")
	var/list/terrain_after = snapshot_terrain()
	require(json_encode(terrain_before) == json_encode(terrain_after) && season == season_before, "Snow worker changed water/ice/authored snow or the season")
	metrics["accumulation"] = list("candidates" = snowfall_ground.len, "expected" = expected.len, "full_world_ds" = full_at, "batch" = SNOWFALL_GROUND_BATCH, "interval_ds" = SNOWFALL_GROUND_INTERVAL, "actors" = actors.len, "samples" = samples)
	pass("scale_accumulation", list("expected" = expected.len, "full_world_ds" = full_at))
	scale_expected = expected
	scale_terrain = terrain_before
	scale_actors = actors

// Real WINTER -> SPRING transition; cover melts wherever spring is above 2C.
/datum/snowfall_game_probe/proc/check_seasonal_melt()
	var/list/expected = scale_expected
	var/list/terrain_before = scale_terrain
	var/list/actors = scale_actors
	var/start
	var/start_tod
	var/list/samples
	var/until
	var/list/snowed_before = list()
	for(var/turf/floor/T in expected)
		if(T.weather_snow)
			snowed_before[T] = TRUE
	reach_season("SPRING")
	var/list/warm = list()
	var/list/cold = list()
	var/warm_snowed = 0
	for(var/turf/floor/T in expected)
		if(get_temp(T) > SNOWFALL_MELT_C)
			warm[T] = TRUE
			if(snowed_before[T])
				warm_snowed++
		else
			cold[T] = TRUE
	var/warm_after_transition = 0
	for(var/turf/floor/T in warm)
		if(T.weather_snow)
			warm_after_transition++
	metrics["melt"] = list("warm" = warm.len, "warm_snowed" = warm_snowed, "warm_after_transition" = warm_after_transition, "cold" = cold.len)
	require(warm_snowed > 0, "No warm candidate held generated snow when spring began")
	// Melt must come from the worker afterwards, not from the season transition itself.
	require(warm_after_transition > 0, "The spring transition cleared generated snow before the worker could melt it")
	start = world.time
	start_tod = world.timeofday
	samples = list()
	var/melted_at = null
	until = world.time + 12000
	while(world.time < until)
		sleep(50)
		var/remaining = 0
		for(var/turf/floor/T in warm)
			if(T.weather_snow)
				remaining++
		var/list/row = list("world_ds" = world.time - start, "wall_ds" = world.timeofday - start_tod, "cpu" = world.cpu, "tick_usage" = world.tick_usage, "warm_remaining" = remaining) + process_stats()
		samples += list(row)
		if(!remaining)
			melted_at = world.time - start
			break
	metrics["melt"] = list("warm" = warm.len, "warm_snowed" = warm_snowed, "warm_after_transition" = warm_after_transition, "cold" = cold.len, "samples" = samples)
	require(melted_at, "Spring did not melt generated snow on warm candidates")
	var/cold_kept = 0
	for(var/turf/floor/T in cold)
		if(T.weather_snow)
			cold_kept++
	var/list/terrain_spring = snapshot_terrain()
	require(terrain_spring["authored_snow"] == terrain_before["authored_snow"], "Spring transition changed authored permanent snow")
	metrics["melt"] = list("warm" = warm.len, "warm_snowed" = warm_snowed, "warm_after_transition" = warm_after_transition, "cold" = cold.len, "cold_kept" = cold_kept, "melted_world_ds" = melted_at, "samples" = samples, "terrain_before" = terrain_before, "terrain_spring" = terrain_spring)
	pass("seasonal_melt", list("warm" = warm.len, "warm_snowed" = warm_snowed, "melted_world_ds" = melted_at, "cold_kept" = cold_kept))
	for(var/mob/M in actors)
		qdel(M)
