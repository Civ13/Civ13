// Headless full-game acceptance walkthrough for the natural crop bootstrap (#3048).
// Test-only: full_game.py appends it to a temporary copy of civ13.dme with the
// North America map. A fresh Nomad, spawned by the production agent autospawn on
// the production start picker, works from empty hands to a planted crop using
// only player actions (agent_control.perform_step: the clicks, hand actions,
// verbs, prompts and screens a player has). The world is then saved; a second
// daemon restores it and the same character harvests, eats and replants.
// Nothing is spawned, granted or moved by the probe.
var/global/datum/natural_bootstrap_probe/natural_bootstrap_probe = new

// An agent character normally skips the personal chapter rules. The walkthrough
// stands in for a player, so its body must learn chapters the way a player does.
/mob/living/human/recipe_knowledge_exempt()
	return FALSE

#define BOOTSTRAP_AGENT "bootstrap"
#define BOOTSTRAP_FACTION "Riverbank"
#define BOOTSTRAP_PLOTS 3
#define BOOTSTRAP_SITE_RADIUS 420
#define BOOTSTRAP_LEG 24

/datum/natural_bootstrap_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/journal = list()
	var/list/adapters = list()
	var/phase = "startup"
	var/started_tod = 0
	var/stage = "write"
	var/datum/agent_identity/agent
	var/datum/agent_character/C
	var/mob/living/human/H
	var/tiles_walked = 0
	var/walk_stalls = 0
	var/message_mark = 0

/datum/natural_bootstrap_probe/New()
	// Linux 516.1688 stops global_init before configuration loads in a probe
	// build; finish the same initialisers once before world/New needs them.
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

/datum/natural_bootstrap_probe/proc/mark(name)
	phase = name
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/natural_bootstrap_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))
	world.log << "PASS: [name]"

/datum/natural_bootstrap_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/natural_bootstrap_probe/proc/note(step, detail)
	journal += list(list("t" = world.time, "phase" = phase, "step" = step, "detail" = detail))
	world.log << "STEP [world.time] [phase]: [step]: [detail]"

/datum/natural_bootstrap_probe/proc/wait_for(datum/target, proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(target, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/natural_bootstrap_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/natural_bootstrap_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/natural_bootstrap_probe/proc/restore_settled()
	return isnull(persistence_startup_recovery_status) && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/datum/natural_bootstrap_probe/proc/character_ready()
	if(!agent_control)
		return FALSE
	agent = agent_control.agents[BOOTSTRAP_AGENT]
	if(!agent)
		return FALSE
	for(var/mob/living/human/M in agent_characters)
		var/datum/agent_character/found = agent_characters[M]
		if(found.owner_agent == BOOTSTRAP_AGENT && M.stat != DEAD && !QDELETED(M))
			C = found
			H = M
			return TRUE
	return FALSE

// The round's own season timer would otherwise move the season under the crop
// while the probe waits; the growth, water and soil code still runs unchanged.
/datum/natural_bootstrap_probe/proc/hold_seasons()
	if(map.uses_durable_metadata())
		map.durable_timer_queue().cancel("season_loop")
	map.season_loop_scheduled = TRUE
	adapters += "weather process disabled and the natural season timer held at [season]"

/datum/natural_bootstrap_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	stage = world.params["stage"] || "write"
	try
		mark("startup")
		if(world.params["seed"])
			rand_seed(text2num(world.params["seed"]))
		wait_for(src, "scheduler_ready", 18000, "Scheduler/ticker never became ready")
		if(stage == "read")
			sleep(100)
			mark("restore")
			wait_for(src, "restore_settled", 36000, "The saved world never finished restoring: [persistence_startup_recovery_status]")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for(src, "game_playing", 6000, "Round did not reach PLAYING")
		if(processes.weather)
			processes.weather.disable()
		hold_seasons()
		metrics["map"] = list("id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "gamemode" = map.gamemode, "persistence" = map.persistence, "book_research" = map.book_research_enabled(), "season" = season, "time_of_day" = time_of_day, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "stage" = stage, "seed" = world.params["seed"])
		require(map.ID == MAP_NOMADS_AMERICAS_NORTH, "Wrong map [map.ID]")
		require(map.persistence && map.book_research_enabled(), "Not a persistent book research world")
		mark("character")
		wait_for(src, "character_ready", 3000, "The agent autospawn never produced a character")
		sleep(20)
		if(stage == "write")
			run_write()
		else
			run_read()
	catch(var/exception/e)
		failure = "[e.name] ([e.file]:[e.line])"
		failed_phase = phase
	mark("finished")
	var/list/last = list()
	if(C)
		for(var/list/row in C.messages)
			last += row["text"]
		if(last.len > 25)
			last.Cut(1, last.len - 24)
	metrics["tiles_walked"] = tiles_walked
	metrics["walk_stalls"] = walk_stalls
	var/list/result = list("stage" = stage, "passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "adapters" = adapters, "journal" = journal, "last_messages" = last, "wall_ds" = world.timeofday - started_tod)
	fdel("result-[stage].json")
	text2file(json_encode(result), "result-[stage].json")
	world.log << (failure ? "FAIL: natural bootstrap [stage]: [failure]" : "PASS: natural bootstrap [stage]")
	sleep(5)
	del(world)

// ---------------------------------------------------------------- player actions

// One player action through the production step runner, in place. Returns the
// step's receipt, or the refusal text.
/datum/natural_bootstrap_probe/proc/act(list/req, quiet = FALSE)
	require(H && !QDELETED(H) && H.stat == CONSCIOUS, "The character is [H ? "not conscious (stat [H.stat])" : "gone"]")
	var/action = req["do"]
	var/guard = 0
	while(TRUE)
		var/wait = C.wait_for(action)
		if(!wait)
			break
		require(++guard < 4000, "Cooldown before [action] never ended")
		sleep(wait)
	var/result
	try
		result = agent_control.perform_step(agent, C, req, TRUE)
	catch(var/exception/E)
		result = "[E.desc || E.name]"
	if(!quiet)
		note(action, "[req["label"] || req["target"] || req["intent"] || req["recipe"] || req["name"] || req["act"] || ""] -> [islist(result) ? "ok" : result][new_messages()]")
	sleep(1)
	return result

/datum/natural_bootstrap_probe/proc/new_messages()
	var/list/lines = list()
	for(var/list/row in C.messages)
		if(row["id"] > message_mark)
			message_mark = row["id"]
			lines += row["text"]
	if(lines.len > 4)
		lines.Cut(1, lines.len - 3)
	return lines.len ? " | [jointext(lines, " / ")]" : ""

/datum/natural_bootstrap_probe/proc/intent(which)
	if(H.a_intent != which)
		act(list("do" = "intent", "intent" = which), TRUE)

/datum/natural_bootstrap_probe/proc/free_hand()
	if(!H.get_active_hand())
		return
	if(!H.get_inactive_hand())
		act(list("do" = "swap_hand"), TRUE)
		return
	act(list("do" = "drop", "label" = "[H.get_active_hand()]"))

// Bring a carried item to the active hand.
/datum/natural_bootstrap_probe/proc/hold(obj/item/I)
	require(I && !QDELETED(I), "Nothing to hold")
	if(H.get_active_hand() == I)
		return
	if(H.get_inactive_hand() == I)
		act(list("do" = "swap_hand"), TRUE)
	require(H.get_active_hand() == I, "[I] is not in a hand")

/datum/natural_bootstrap_probe/proc/click(atom/target, label, choose = null)
	var/list/req = list("do" = "click", "target" = agent_ref(target), "label" = label || "[target]")
	if(choose)
		req["choose"] = choose
	return act(req)

/datum/natural_bootstrap_probe/proc/pick_up(obj/item/I)
	require(I && !QDELETED(I) && isturf(I.loc), "Nothing on the ground to pick up")
	go_to(get_turf(I), 1)
	free_hand()
	intent(I_HELP)
	click(I, "pick up [I]")
	require(I.loc == H, "[I] was not picked up")

/datum/natural_bootstrap_probe/proc/carried(path)
	for(var/obj/item/I in list(H.get_active_hand(), H.get_inactive_hand()))
		if(istype(I, path))
			return I
	return null

// ---------------------------------------------------------------- walking

/datum/natural_bootstrap_probe/proc/standable(turf/T)
	if(!T || T.density || click_route_hazard_turf(T))
		return FALSE
	for(var/obj/O in T)
		if(O.density)
			return FALSE
	return TRUE

// A place to aim one leg at: BOOTSTRAP_LEG tiles toward the goal, shifted
// sideways after each stalled leg the way a walker goes round an obstacle.
/datum/natural_bootstrap_probe/proc/waypoint(turf/goal, stalls)
	var/dx = goal.x - H.x
	var/dy = goal.y - H.y
	var/far = max(abs(dx), abs(dy))
	var/scale = BOOTSTRAP_LEG / far
	var/side = stalls ? (stalls % 2 ? 1 : -1) * 8 * round((stalls + 1) / 2) : 0
	var/wx = clamp(round(H.x + dx * scale - (dy / far) * side), 2, world.maxx - 1)
	var/wy = clamp(round(H.y + dy * scale + (dx / far) * side), 2, world.maxy - 1)
	var/turf/centre = locate(wx, wy, H.z)
	if(standable(centre))
		return centre
	for(var/r = 1 to 5)
		for(var/turf/T in range(r, centre))
			if(standable(T) && max(abs(T.x - H.x), abs(T.y - H.y)) <= 30)
				return T
	return centre

// Walk with the production click-to-move route (walk_to), one leg at a time.
/datum/natural_bootstrap_probe/proc/go_to(turf/goal, reach = 0)
	var/stalls = 0
	var/legs = 0
	while(get_dist(H, goal) > reach)
		require(H.z == goal.z, "The goal is on another level")
		require(++legs <= 600, "Walk to [goal.x],[goal.y] took too many legs")
		var/turf/aim = get_dist(H, goal) > BOOTSTRAP_LEG + 4 ? waypoint(goal, stalls) : goal
		var/turf/from = get_turf(H)
		var/list/req = list("do" = "walk_to", "x" = aim.x, "y" = aim.y)
		var/outcome = "?"
		var/steps = 0
		while(TRUE)
			var/result = act(req, TRUE)
			if(!islist(result))
				outcome = "[result]"
				break
			if(result["route_done"])
				outcome = "[result["route_result"]]"
				break
			require(++steps < 400, "A walk leg never finished")
		var/moved = get_dist(from, get_turf(H))
		tiles_walked += moved
		if(aim == goal && get_dist(H, goal) <= max(reach, 1))
			break
		if(moved < 3)
			stalls++
			walk_stalls++
			note("walk", "leg toward [aim.x],[aim.y] stalled at [H.x],[H.y]: [outcome]")
			require(stalls <= 12, "Could not walk to [goal.x],[goal.y] from [H.x],[H.y]: [outcome]")
		else
			stalls = 0
	return TRUE

// ---------------------------------------------------------------- scouting

/datum/natural_bootstrap_probe/proc/ploughable(turf/T)
	if(!T || T.density || T.weather_snow > 0)
		return FALSE
	if(istype(T, /turf/floor/grass))
		if(istype(T, /turf/floor/grass/jungle))
			return FALSE
	else if(istype(T, /turf/floor/dirt))
		if(istype(T, /turf/floor/dirt/ploughed) || istype(T, /turf/floor/dirt/dust) || istype(T, /turf/floor/dirt/jungledirt) || istype(T, /turf/floor/dirt/burned) || istype(T, /turf/floor/dirt/underground) || istype(T, /turf/floor/dirt/flooded))
			return FALSE
	else
		return FALSE
	var/area/A = get_area(T)
	if(!A || A.location != AREA_OUTSIDE)
		return FALSE
	if((locate(/obj/structure) in T) || (locate(/obj/covers) in T) || (locate(/obj/item) in T) || (locate(/mob/living) in T))
		return FALSE
	return TRUE

/datum/natural_bootstrap_probe/proc/fresh_water(turf/T)
	if(!istype(T, /turf/floor/beach/water))
		return FALSE
	var/turf/floor/F = T
	return !F.salty

// Plots within reach of the nearest fresh water: what a walker finds by
// following the land to a river or lake bank.
/datum/natural_bootstrap_probe/proc/find_site()
	var/turf/origin = get_turf(H)
	for(var/r = 1 to BOOTSTRAP_SITE_RADIUS)
		var/list/ring = list()
		for(var/x = origin.x - r to origin.x + r)
			ring += locate(x, origin.y - r, origin.z)
			ring += locate(x, origin.y + r, origin.z)
		for(var/y = origin.y - r + 1 to origin.y + r - 1)
			ring += locate(origin.x - r, y, origin.z)
			ring += locate(origin.x + r, y, origin.z)
		for(var/turf/W in ring)
			if(!fresh_water(W))
				continue
			var/list/plots = list()
			for(var/turf/T in range(2, W))
				if(ploughable(T))
					plots += T
			if(plots.len < BOOTSTRAP_PLOTS + 2)
				continue
			// Plots that share one standing tile, so the farmer works from one spot.
			for(var/turf/stand in plots)
				var/list/near = list()
				for(var/turf/T in plots)
					if(T != stand && get_dist(T, stand) <= 1)
						near += T
				if(near.len >= BOOTSTRAP_PLOTS)
					near.Cut(BOOTSTRAP_PLOTS + 1)
					return list("water" = W, "stand" = stand, "plots" = near)
		if(r % 8 == 0)
			sleep(world.tick_lag)
	return null

/datum/natural_bootstrap_probe/proc/nearest(path, radius, check = null)
	var/atom/best = null
	var/best_d = 1e9
	for(var/atom/movable/AM in range(radius, H))
		if(!istype(AM, path) || !isturf(AM.loc))
			continue
		if(check && !call(src, check)(AM))
			continue
		var/d = get_dist(AM, H)
		if(d < best_d)
			best = AM
			best_d = d
	return best

/datum/natural_bootstrap_probe/proc/seeding_bush(obj/structure/wild/smallbush/B)
	return B.seedtimer == 1

/datum/natural_bootstrap_probe/proc/standing_tree(obj/structure/wild/tree/T)
	return T.health > 0 && !istype(T, /obj/structure/wild/tree/cactus)

// ---------------------------------------------------------------- state records

/datum/natural_bootstrap_probe/proc/inventory()
	var/list/rows = list()
	for(var/obj/item/I in H.contents)
		rows += "[I.type]"
	return rows

/datum/natural_bootstrap_probe/proc/plant_row(obj/structure/farming/plant/P)
	var/turf/floor/dirt/D = get_turf(P)
	return list("type" = "[P.type]", "x" = P.x, "y" = P.y, "z" = P.z, "stage" = P.stage, "water" = P.water, "plant_nutrition" = P.plant_nutrition, "name" = P.name,
		"turf" = "[D.type]", "is_plowed" = D.is_plowed, "soil_nutrition" = istype(D) ? D.soil_nutrition : null)

/datum/natural_bootstrap_probe/proc/body_row()
	var/turf/T = get_turf(H)
	var/area/body_area = get_area(T)
	var/list/known = islist(H.known_recipe_nodes) ? H.known_recipe_nodes.Copy() : list()
	return list("name" = H.real_name, "x" = T.x, "y" = T.y, "z" = T.z, "civilization" = H.civilization, "leader" = H.leader, "known_recipe_nodes" = known,
		"owner" = H.persistence_owner_ckey, "inventory" = inventory(), "nutrition" = round(H.nutrition), "water" = round(H.water), "health" = H.health, "farming" = H.getStatCoeff("farming"),
		"climate" = body_area.climate, "turf" = "[T.type]")

// ---------------------------------------------------------------- write stage

/datum/natural_bootstrap_probe/proc/run_write()
	mark("fresh_start")
	var/list/start = body_row()
	var/list/hands = list()
	for(var/obj/item/I in list(H.get_active_hand(), H.get_inactive_hand()))
		hands += "[I.type]"
	require(!hands.len, "A fresh nomad started with something in hand: [json_encode(hands)]")
	require(H.civilization == "none" && !length(start["known_recipe_nodes"]), "The character did not start fresh")
	for(var/item in start["inventory"])
		var/path = text2path(item)
		require(!ispath(path, /obj/item/stack/farming) && !ispath(path, /obj/item/weapon/plough) && !ispath(path, /obj/item/weapon/material) && !ispath(path, /obj/item/weapon/flint) && !ispath(path, /obj/item/weapon/book), "A fresh nomad started with [item]")
	require(!crafting_recipe_allowed(H, "/obj/item/weapon/plough/digging_stick"), "A fresh nomad already knew the digging stick")
	pass("fresh_character", list("start" = start, "spawned_by" = "agent autospawn on the production start picker", "hunger" = round(H.nutrition), "thirst" = round(H.water)))

	mark("scout")
	var/list/site = find_site()
	require(site, "No farm ground by fresh water within [BOOTSTRAP_SITE_RADIUS] tiles of the start")
	var/turf/water = site["water"]
	var/turf/stand = site["stand"]
	var/list/plots = site["plots"]
	note("scout", "bank at [stand.x],[stand.y] beside water [water.x],[water.y] ([water.type]), [get_dist(H, stand)] tiles from the start")
	mark("walk_to_bank")
	var/started = world.time
	var/area/stand_area = get_area(stand)
	go_to(stand)
	pass("walked_to_fresh_water", list("from" = "[start["x"]],[start["y"]]", "to" = "[stand.x],[stand.y]", "water" = "[water.type]", "climate" = stand_area.climate, "tiles" = tiles_walked, "stalled_legs" = walk_stalls, "game_seconds" = (world.time - started) / 10))

	mark("faction_and_chapter")
	found_and_study()

	mark("flint_knife")
	var/obj/item/knife = make_knife()

	mark("digging_stick")
	var/obj/item/stick = make_digging_stick(knife, stand)

	mark("plough")
	go_to(stand)
	hold(stick)
	intent(I_HELP)
	for(var/turf/plot in plots)
		var/guard = 0
		while(!istype(plot, /turf/floor/dirt/ploughed))
			require(++guard <= 4, "Plot [plot.x],[plot.y] would not plough: [plot.type]")
			click(plot, "plough [plot.type] at [plot.x],[plot.y]")
			plot = locate(plot.x, plot.y, plot.z)
		require(plot.is_plowed, "Ploughed plot is not ready for seed")
	pass("ploughed_plots", list("plots" = plots.len, "tool" = "[stick.type]", "farming" = H.getStatCoeff("farming")))
	act(list("do" = "drop", "label" = "[stick]"))
	var/turf/stick_at = get_turf(stick)

	mark("forage_and_plant")
	var/list/planted = list()
	var/list/used = list()
	var/list/seed_rows = list()
	for(var/i = 1 to plots.len)
		var/turf/plot = plots[i]
		var/obj/item/stack/farming/seeds/seed = null
		var/tries = 0
		while(!seed)
			require(++tries <= 6, "No seed could be foraged for plot [i]")
			var/obj/structure/wild/smallbush/bush = null
			var/best_d = 1e9
			for(var/obj/structure/wild/smallbush/B in range(70, H))
				if(B.seedtimer != 1 || (B in used) || !isturf(B.loc))
					continue
				var/d = get_dist(B, stand)
				if(d < best_d)
					bush = B
					best_d = d
			require(bush, "No seeding small bush within 70 tiles of the bank")
			used += bush
			go_to(get_turf(bush), 1)
			hold(knife)
			intent(I_HELP)
			var/area/BA = get_area(H)
			click(bush, "forage [bush] at [bush.x],[bush.y]")
			seed = locate(/obj/item/stack/farming/seeds) in get_turf(H)
			if(seed)
				seed_rows += list(list("seed" = "[seed.type]", "bush" = "[bush.x],[bush.y]", "climate" = BA.climate, "amount" = seed.amount))
		act(list("do" = "swap_hand"), TRUE)
		pick_up(seed)
		go_to(stand)
		hold(seed)
		intent(I_HELP)
		click(plot, "plant [seed] at [plot.x],[plot.y]")
		var/obj/structure/farming/plant/P = locate(/obj/structure/farming/plant) in plot
		require(P, "Nothing grew from the seed at [plot.x],[plot.y]")
		planted += P
		if(!H.get_active_hand())
			act(list("do" = "swap_hand"), TRUE)
	pass("foraged_seed_planted", list("seeds" = seed_rows, "plants" = planted.len))

	mark("growing")
	var/until = world.time + 3600
	var/grown = FALSE
	while(world.time < until && !grown)
		sleep(100)
		for(var/obj/structure/farming/plant/P in planted)
			if(!QDELETED(P) && P.stage >= 3 && P.stage <= P.readyStageMax)
				grown = TRUE
	var/list/rows = list()
	for(var/obj/structure/farming/plant/P in planted)
		require(!QDELETED(P), "A planted crop vanished before the save")
		rows += list(plant_row(P))
	require(grown, "No crop reached its third stage in six minutes: [json_encode(rows)]")
	pass("crop_growing_before_save", list("plants" = rows, "season" = season))

	mark("save")
	hold(knife)
	var/list/manifest = list("body" = body_row(), "plants" = rows, "stick" = list("type" = "[stick.type]", "x" = stick_at.x, "y" = stick_at.y, "z" = stick_at.z),
		"stand" = list("x" = stand.x, "y" = stand.y, "z" = stand.z), "season" = season, "world_time" = world.time, "faction" = BOOTSTRAP_FACTION)
	var/save_start = world.timeofday
	require(ticker.savemap(), "The world save failed: [map_storage.last_error]")
	require(fexists("map_saves/map.txt") && fexists("map_saves/save_complete.txt"), "The save left no completed generation")
	fdel("manifest.json")
	text2file(json_encode(manifest), "manifest.json")
	pass("world_saved", list("save_ds" = world.timeofday - save_start, "world_time" = world.time))

// Found a faction for its Stone Age master book, then study Basic Toolmaking.
/datum/natural_bootstrap_probe/proc/found_and_study()
	free_hand()
	var/made = act(list("do" = "verb", "name" = "Create Faction"))
	require(islist(made), "Create Faction verb refused: [made]")
	var/named = act(list("do" = "screen", "screen" = 1, "act" = "set_name", "choose" = BOOTSTRAP_FACTION))
	require(islist(named), "Naming the faction refused: [named]")
	var/founded = act(list("do" = "screen", "screen" = 1, "act" = "found"))
	require(islist(founded) && H.civilization == BOOTSTRAP_FACTION, "The faction was not founded: [founded]")
	var/obj/item/weapon/book/book = carried(/obj/item/weapon/book)
	require(book, "The founder received no master book")
	require("basic_tools" in book.research_chapter_list(), "The master book has no Basic Toolmaking chapter")
	// Reading needs daylight. A player would wait for morning; the probe turns
	// the production day clock forward instead and says so.
	var/turns = 0
	while(H.reading_light_problem())
		require(++turns <= 8, "It never became light enough to read")
		progress_time_of_day(null, TRUE)
		sleep(50)
	if(turns)
		adapters += "time of day advanced [turns] step(s) to [time_of_day] so the chapter could be read"
	hold(book)
	var/study_start = world.time
	act(list("do" = "use", "label" = "study Basic Toolmaking", "choose" = "Study: Basic Toolmaking"))
	require(H.knows_recipe_node("basic_tools"), "Basic Toolmaking was not learned")
	require(crafting_recipe_allowed(H, "/obj/item/weapon/plough/digging_stick"), "The digging stick is still not allowed")
	pass("founded_and_studied", list("faction" = H.civilization, "book" = "[book.type]", "chapters" = book.research_chapter_list(), "study_seconds" = (world.time - study_start) / 10, "time_of_day" = time_of_day))
	// The book and slate stay at the camp beside the plots.
	for(var/obj/item/I in list(H.get_active_hand(), H.get_inactive_hand()))
		hold(I)
		act(list("do" = "drop", "label" = "[I]"))
	require(!H.get_active_hand() && !H.get_inactive_hand(), "The book and slate could not be put down")

// Two flints from a rock, one knapped with the other into a flint knife.
/datum/natural_bootstrap_probe/proc/make_knife()
	var/list/spent = list()
	var/attempts = 0
	var/flints = 0
	while(TRUE)
		require(++attempts <= 12, "No flint knife after [attempts - 1] knapping attempts")
		// Fill both hands with flint.
		var/searches = 0
		while(!(istype(H.get_active_hand(), /obj/item/weapon/flint) && istype(H.get_inactive_hand(), /obj/item/weapon/flint)))
			require(++searches <= 14, "Could not gather two flints")
			var/obj/item/held = H.get_active_hand()
			if(held && !istype(held, /obj/item/weapon/flint))
				act(list("do" = "drop", "label" = "[held]"))
			if(H.get_active_hand())
				act(list("do" = "swap_hand"), TRUE)
				held = H.get_active_hand()
				if(held && !istype(held, /obj/item/weapon/flint))
					act(list("do" = "drop", "label" = "[held]"))
				if(H.get_active_hand())
					continue
			var/obj/structure/wild/rock/rock = null
			var/best_d = 1e9
			for(var/obj/structure/wild/rock/R in range(70, H))
				if((R in spent) || !isturf(R.loc))
					continue
				var/d = get_dist(R, H)
				if(d < best_d)
					rock = R
					best_d = d
			require(rock, "No rock within 70 tiles")
			go_to(get_turf(rock), 1)
			intent(I_GRAB)
			click(rock, "search [rock] at [rock.x],[rock.y]")
			if(istype(H.get_active_hand(), /obj/item/weapon/flint))
				flints++
			else
				spent += rock
		var/obj/item/weapon/flint/hammer = H.get_active_hand()
		var/obj/item/weapon/flint/core = H.get_inactive_hand()
		intent(I_HELP)
		click(core, "knap [core] with [hammer]", "Flint knife")
		var/obj/item/weapon/material/kitchen/utensil/knife/knife = carried(/obj/item/weapon/material/kitchen/utensil/knife)
		if(knife)
			require(is_tool(knife, TOOL_KNIFE), "The flint knife does not work as a knife")
			// The hammerstone is no longer needed.
			for(var/obj/item/weapon/flint/F in list(H.get_active_hand(), H.get_inactive_hand()))
				hold(F)
				act(list("do" = "drop", "label" = "[F]"))
			pass("flint_knife", list("knife" = "[knife.type]", "flints_found" = flints, "knapping_attempts" = attempts))
			return knife
	return null

// A tree cut down with the knife, its wood made into a digging stick.
/datum/natural_bootstrap_probe/proc/make_digging_stick(obj/item/knife, turf/stand)
	var/obj/structure/wild/tree/tree = nearest(/obj/structure/wild/tree, 70, "standing_tree")
	require(tree, "No tree within 70 tiles")
	var/turf/tree_at = get_turf(tree)
	go_to(tree_at, 1)
	hold(knife)
	intent(I_HARM)
	var/cuts = 0
	while(!QDELETED(tree) && tree.loc)
		require(++cuts <= 40, "The tree never fell")
		act(list("do" = "click", "target" = agent_ref(tree), "label" = "cut [tree]"), cuts > 1)
	var/obj/item/stack/material/wood/wood = locate(/obj/item/stack/material/wood) in tree_at
	require(wood, "The felled tree left no wood")
	var/wood_amount = wood.amount
	act(list("do" = "swap_hand"), TRUE)
	pick_up(wood)
	hold(wood)
	var/crafted = act(list("do" = "craft", "recipe" = "digging stick"))
	require(islist(crafted), "Crafting the digging stick was refused: [crafted]")
	var/obj/item/weapon/plough/digging_stick/stick = null
	for(var/obj/item/weapon/plough/digging_stick/S in range(1, H))
		stick = S
	if(!stick)
		stick = locate(/obj/item/weapon/plough/digging_stick) in H
	require(stick, "No digging stick was made")
	// Leftover wood stays where the tree fell.
	if(!QDELETED(wood) && wood.loc == H)
		hold(wood)
		act(list("do" = "drop", "label" = "[wood]"))
	if(stick.loc != H)
		pick_up(stick)
	pass("digging_stick", list("tree" = "[tree_at.x],[tree_at.y]", "knife_cuts" = cuts, "wood" = wood_amount, "stick" = "[stick.type]"))
	return stick

// ---------------------------------------------------------------- read stage

/datum/natural_bootstrap_probe/proc/run_read()
	mark("restored_state")
	require(fexists("manifest.json"), "No manifest from the write stage")
	var/list/manifest = json_decode(file2text("manifest.json"))
	var/list/saved_body = manifest["body"]
	var/list/now = body_row()
	var/humans = 0
	for(var/mob/living/human/M in human_mob_list)
		if(M.persistence_owner_ckey == saved_body["owner"] && M.stat != DEAD)
			humans++
	require(humans == 1, "[humans] bodies belong to the agent account after the restore")
	require(now["name"] == saved_body["name"] && now["x"] == saved_body["x"] && now["y"] == saved_body["y"] && now["z"] == saved_body["z"], "The body was not restored where it stood: [json_encode(now)]")
	require(now["civilization"] == manifest["faction"] && ("basic_tools" in H.known_recipe_nodes), "Faction or learned chapter was lost")
	var/list/before_items = saved_body["inventory"]
	var/list/after_items = now["inventory"]
	require(json_encode(sortList(before_items.Copy())) == json_encode(sortList(after_items.Copy())), "Carried items changed across the restart: [json_encode(after_items)]")
	var/obj/item/knife = carried(/obj/item/weapon/material/kitchen/utensil/knife)
	require(knife, "The flint knife is no longer in hand")
	var/list/stick_row = manifest["stick"]
	var/obj/item/weapon/plough/digging_stick/stick = locate(/obj/item/weapon/plough/digging_stick) in locate(stick_row["x"], stick_row["y"], stick_row["z"])
	require(stick, "The digging stick left at the camp was not restored")
	pass("character_restored", list("before" = saved_body, "after" = now, "world_time" = world.time, "saved_world_time" = manifest["world_time"], "season" = season, "saved_season" = manifest["season"]))

	var/list/plants = list()
	var/list/compare = list()
	for(var/list/row in manifest["plants"])
		var/turf/floor/dirt/D = locate(row["x"], row["y"], row["z"])
		var/obj/structure/farming/plant/P = locate(/obj/structure/farming/plant) in D
		require(P, "The crop at [row["x"]],[row["y"]] was not restored")
		var/list/after = plant_row(P)
		compare += list(list("saved" = row, "restored" = after))
		require(after["type"] == row["type"], "Crop type changed: [after["type"]]")
		require(after["turf"] == row["turf"] && after["is_plowed"], "Soil changed: [after["turf"]]")
		// The restored world has already run for a while; a crop may have taken one more step.
		require(after["stage"] >= row["stage"] && after["stage"] <= row["stage"] + 2, "Crop stage [row["stage"]] came back as [after["stage"]]")
		require(after["soil_nutrition"] <= row["soil_nutrition"] && after["soil_nutrition"] >= row["soil_nutrition"] - 9, "Soil nutrition [row["soil_nutrition"]] came back as [after["soil_nutrition"]]")
		plants += P
	require(season == manifest["season"], "Season [manifest["season"]] came back as [season]")
	pass("crop_and_soil_restored", list("plots" = compare))

	mark("growing_after_restore")
	var/obj/structure/farming/plant/ready = null
	var/until = world.time + 6600
	while(world.time < until && !ready)
		sleep(100)
		for(var/obj/structure/farming/plant/P in plants)
			if(!QDELETED(P) && P.readyHarvest())
				ready = P
				break
	var/list/rows = list()
	for(var/obj/structure/farming/plant/P in plants)
		if(!QDELETED(P))
			rows += list(plant_row(P))
	require(ready, "No restored crop became ready to harvest in eleven minutes: [json_encode(rows)]")
	pass("growth_continued_after_restore", list("plants" = rows))

	mark("harvest")
	var/turf/plot = get_turf(ready)
	var/ready_type = ready.type
	var/seed_path = text2path("/obj/item/stack/farming/seeds/[ready.plant]")
	go_to(plot, 1)
	hold(knife)
	intent(I_HELP)
	click(ready, "harvest [ready]")
	require(QDELETED(ready) || !ready.loc, "The ready crop was not harvested")
	var/obj/item/stack/farming/seeds/seed = locate(seed_path) in plot
	require(seed && seed.amount >= 1, "The harvest left no seed")
	var/list/produce = list()
	var/obj/item/weapon/reagent_containers/food/snacks/food = null
	for(var/obj/item/I in plot)
		if(I == seed)
			continue
		produce += "[I.type]"
		if(istype(I, /obj/item/weapon/reagent_containers/food/snacks) && !food)
			food = I
	require(produce.len, "The harvest left no produce")
	pass("harvested", list("crop" = "[ready_type]", "seed" = "[seed.type]", "seed_amount" = seed.amount, "produce" = produce))

	mark("eat")
	if(food)
		act(list("do" = "swap_hand"), TRUE)
		pick_up(food)
		hold(food)
		var/hunger = H.nutrition
		var/bites = 0
		while(!QDELETED(food) && food.loc == H && bites < 6)
			bites++
			click(H, "eat [food]")
			sleep(20)
		pass("ate_the_harvest", list("food" = produce[1], "bites" = bites, "nutrition_before" = round(hunger), "nutrition_after" = round(H.nutrition), "eaten" = QDELETED(food) || H.nutrition > hunger))
		if(!QDELETED(food) && food.loc == H)
			hold(food)
			act(list("do" = "drop", "label" = "[food]"))
	else
		note("eat", "the produce is not eaten raw: [json_encode(produce)]")

	mark("replant")
	if(H.get_active_hand())
		act(list("do" = "swap_hand"), TRUE)
	var/seed_amount = seed.amount
	pick_up(seed)
	plot = locate(plot.x, plot.y, plot.z)
	if(!istype(plot, /turf/floor/dirt/ploughed) || !plot.is_plowed)
		note("replant", "the plot needs ploughing again: [plot.type]")
		hold(knife)
		act(list("do" = "drop", "label" = "[knife]"))
		pick_up(stick)
		hold(stick)
		var/guard = 0
		while(!istype(plot, /turf/floor/dirt/ploughed))
			require(++guard <= 4, "The plot would not plough again")
			click(plot, "plough [plot.type]")
			plot = locate(plot.x, plot.y, plot.z)
	go_to(plot, 1)
	hold(seed)
	intent(I_HELP)
	click(plot, "replant [seed]")
	var/obj/structure/farming/plant/second = locate(/obj/structure/farming/plant) in plot
	require(second && second.type == ready_type, "The saved seed did not grow a second crop")
	var/first_stage = second.stage
	until = world.time + 2400
	while(world.time < until && second.stage <= first_stage && !QDELETED(second))
		sleep(100)
	require(!QDELETED(second) && second.stage > first_stage && second.stage <= second.readyStageMax, "The second crop did not grow: stage [second.stage]")
	pass("replanted_from_own_seed", list("crop" = plant_row(second), "seed_left" = QDELETED(seed) ? 0 : seed.amount, "seed_harvested" = seed_amount))

#undef BOOTSTRAP_AGENT
#undef BOOTSTRAP_FACTION
#undef BOOTSTRAP_PLOTS
#undef BOOTSTRAP_SITE_RADIUS
#undef BOOTSTRAP_LEG
