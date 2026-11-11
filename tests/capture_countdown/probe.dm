// Standalone driver for tests/capture_countdown/run.py. The runner prepends
// the faction/map defines and the extracted map_metadata procs, with
// world.time rewritten to the scripted clock capture_clock. The runner also
// copies the SPAN and INFINITY macros ahead of the extracted code.

var/capture_clock = 0
var/list/capture_events = list()
var/capture_alive_1 = TRUE
var/capture_alive_2 = TRUE
var/obj/map_metadata/map = null
var/datum/capture_ticker/ticker = null
var/list/clients = list()
// Scripted occupancy: faction flag -> list(area type -> head count).
var/list/capture_occupancy = list()

/datum/capture_ticker
	var/finished = FALSE

/proc/to_chat(target, message)
	capture_events += "chat:[message]"

/proc/show_global_battle_report(shower)
	capture_events += "battle_report"

/proc/alive_n_of_side(side)
	if (map && side == map.faction1)
		return capture_alive_1
	if (map && side == map.faction2)
		return capture_alive_2
	return TRUE

/area/capture_probe
/area/capture_probe/one
/area/capture_probe/two
/area/caribbean/island

/datum/win_condition
	var/hash = 0

// Same coefficient and hash rules as code/datums/win_condition.dm; head counts
// come from capture_occupancy instead of human_mob_list.
/datum/win_condition/proc/check(var/list/areas, var/list/attackers, var/list/defenders, threshold = 1.0, sethash = FALSE)
	if (sethash)
		set_hash(areas, attackers, defenders, threshold)
	var/attacker_count = 0
	var/defender_count = 0
	for (var/faction in capture_occupancy)
		var/list/where = capture_occupancy[faction]
		for (var/area_type in where)
			if (!(area_type in areas))
				continue
			if (attackers.Find(faction))
				attacker_count += where[area_type]
			else if (defenders.Find(faction))
				defender_count += where[area_type]
	var/coeff = 1.0
	if (!defender_count)
		if (!attacker_count)
			coeff = 1.0
		else
			coeff = INFINITY
	else
		coeff = attacker_count/defender_count
	return coeff >= threshold

/datum/win_condition/proc/set_hash(var/list/areas, var/list/attackers, var/list/defenders, threshold = 1.0)
	hash = ""
	for (var/area_path in areas)
		hash = "[.][area_path]|"
	for (var/attacker in attackers)
		hash = "[.][attacker]|"
	for (var/defender in defenders)
		hash = "[.][defenders]|"
	hash = "[.][threshold]"
	return hash

/obj/map_metadata
	var/ID = null
	var/no_winner = "Neither side has captured the other side's base."
	var/capture_objective_name = null
	var/capture_verb = "have"
	var/capture_notice_in_font = FALSE
	var/victory_time = 36000
	var/nomads = FALSE
	var/is_singlefaction = FALSE
	var/civilizations = FALSE
	var/battle_name = null
	var/faction1 = null
	var/faction2 = null
	var/list/roundend_condition_sides = list()
	var/datum/win_condition/win_condition = null
	var/current_win_condition = "Neither side has captured the other side's base."
	var/last_win_condition = null
	var/current_winner = null
	var/current_loser = null
	var/next_win = -1
	var/win_condition_spam_check = FALSE

// Plain maps on the base implementation: separate bases, and a civilizations map.
/obj/map_metadata/capture_base
	battle_name = "probe battle"
	faction1 = BRITISH
	faction2 = FRENCH
	roundend_condition_sides = list(
		list(BRITISH) = /area/capture_probe/one,
		list(FRENCH) = /area/capture_probe/two
		)

/obj/map_metadata/capture_base/civ
	battle_name = null
	civilizations = TRUE

/proc/capture_side_flag(obj/map_metadata/M, side)
	var/list/key = M.roundend_condition_sides[side]
	return key[1]

/proc/capture_base_area(obj/map_metadata/M, side)
	return M.roundend_condition_sides[M.roundend_condition_sides[side]]

// One scripted round. Phases hold a random occupancy for a random number of
// ticks; each tick advances the clock by 10 deciseconds (one ticker pass).
/proc/capture_run(map_type, seed, ticks, wipe_chance, contested)
	rand_seed(seed)
	var/obj/map_metadata/M = new map_type
	M.win_condition = new /datum/win_condition
	map = M
	ticker = new /datum/capture_ticker
	clients = list()
	capture_clock = 0
	capture_alive_1 = TRUE
	capture_alive_2 = TRUE
	var/list/lines = list()
	var/phase_left = 0
	var/flag1 = capture_side_flag(M, 1)
	var/flag2 = capture_side_flag(M, 2)
	for (var/tick = 1, tick <= ticks, tick++)
		capture_clock += 10
		if (phase_left <= 0)
			phase_left = rand(1, 90)
			var/a1 = capture_base_area(M, 1)
			var/a2 = capture_base_area(M, 2)
			var/list/o1 = list()
			var/list/o2 = list()
			// Head counts chosen to land on every threshold: 0, ties, 1.01-1.33 and above.
			var/list/counts = list(0, 0, 0, 1, 2, 3, 4, 5, 8)
			o1[a2] = pick(counts)
			o2[a1] = pick(counts)
			if (a1 != a2)
				o1[a1] = pick(counts)
				o2[a2] = pick(counts)
			else
				o2[a1] = pick(counts)
			if (contested)
				// Even numbers on every base: nobody captures, so the map deadline decides.
				o2[a2] = o1[a2]
				o1[a1] = o2[a1]
			capture_occupancy = list()
			capture_occupancy[flag1] = o1
			capture_occupancy[flag2] = o2
			var/list/client_counts = list(3, 19, 20, 30)
			clients.len = pick(client_counts)
			capture_alive_1 = prob(85)
			capture_alive_2 = prob(85)
		phase_left--
		capture_events = list()
		// The ticker's wiped-side check in /obj/map_metadata/proc/tick().
		if (wipe_chance && prob(wipe_chance))
			M.current_winner = M.roundend_condition_def2army(M.faction2)
			M.current_loser = M.roundend_condition_def2army(M.faction1)
			ticker.finished = TRUE
			M.next_win = capture_clock - 100
			capture_events += "wipe"
		var/result = M.update_win_condition()
		lines += json_encode(list(
			"tick" = tick, "time" = capture_clock, "result" = result,
			"next_win" = M.next_win, "condition" = M.current_win_condition,
			"stat" = M.current_stat_message(), "winner" = M.current_winner,
			"loser" = M.current_loser, "last_hash" = M.last_win_condition,
			"hash" = M.win_condition.hash, "spam" = M.win_condition_spam_check,
			"finished" = ticker.finished, "events" = capture_events))
	return lines

/world/New()
	..()
	var/list/cases = list(
		list("camp", /obj/map_metadata/camp),
		list("oasis", /obj/map_metadata/oasis),
		list("twotribes", /obj/map_metadata/twotribes),
		list("base", /obj/map_metadata/capture_base),
		list("base_civ", /obj/map_metadata/capture_base/civ))
	var/list/out = list()
	for (var/list/c in cases)
		for (var/seed = 1, seed <= CAPTURE_SEEDS, seed++)
			// Every third seed adds side wipes; every fourth keeps bases contested.
			var/list/lines = capture_run(c[2], seed * 7919, CAPTURE_TICKS, (seed % 3 == 0) ? 1 : 0, seed % 4 == 0)
			out["[c[1]]/[seed]"] = lines
	text2file(json_encode(out), "trace.json")
	world.log << "COMPLETE capture countdown trace"
	del(world)
