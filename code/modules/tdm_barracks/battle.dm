// The battle side of the TDM pair (shard kind BATTLE): live status, per-player
// results, the trip back to the barracks before a reboot and the map rotation.

// How long a reboot waits for the next voted map to compile.
#define TDM_ROTATION_WAIT 12000

var/global/datum/tdm_battle/tdm_battle = new

/datum/tdm_battle
	var/running = FALSE
	// ckey -> list("key", "name", "team", "kills", "deaths", "seconds")
	var/list/players = list()
	var/returning = FALSE
	var/results_sent = FALSE
	var/last_phase = null
	var/rotation_map = null

/datum/tdm_battle/proc/start()
	if(running)
		return
	running = TRUE
	report_loop()

/datum/tdm_battle/proc/report_loop()
	set waitfor = FALSE
	while(tdm_battle_active())
		sample()
		var/phase = phase()
		tdm_link.report("status", status())
		last_phase = phase
		// Report a change of phase sooner than the usual interval.
		for(var/i = 1, i <= TDM_REPORT_INTERVAL / 10, i++)
			sleep(10)
			if(phase() != last_phase)
				break
	running = FALSE

/datum/tdm_battle/proc/phase()
	if(returning)
		return rotation_map ? "rotating" : "returning"
	if(!ticker)
		return "starting"
	switch(ticker.current_state)
		if(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP)
			return "pregame"
		if(GAME_STATE_PLAYING)
			return "playing"
		if(GAME_STATE_FINISHED)
			return "finished"
	return "starting"

/datum/tdm_battle/proc/team_name(faction)
	if(!map || isnull(faction))
		return "Unassigned"
	var/name = map.roundend_condition_def2army(faction)
	if(!name)
		name = map.roundend_condition_def2name(faction)
	return name ? "[name]" : "[faction]"

/datum/tdm_battle/proc/team_of(mob/living/human/H)
	if(!H || !H.original_job)
		return null
	return team_name(H.original_job.base_type_flag())

/datum/tdm_battle/proc/entry(mob/living/human/H)
	if(!H || !H.ckey)
		return null
	var/list/E = players[H.ckey]
	if(!E)
		E = list("key" = H.key, "name" = H.real_name, "team" = team_of(H), "kills" = 0, "deaths" = 0, "seconds" = 0)
		players[H.ckey] = E
	return E

// Counts time played for everyone on a side, every report.
/datum/tdm_battle/proc/sample()
	if(!ticker || ticker.current_state != GAME_STATE_PLAYING)
		return
	for(var/mob/living/human/H in player_list)
		if(!H.original_job || !H.client)
			continue
		var/list/E = entry(H)
		if(!E)
			continue
		E["team"] = team_of(H)
		E["name"] = H.real_name
		if(H.stat != DEAD)
			E["seconds"] += TDM_REPORT_INTERVAL / 10

/datum/tdm_battle/proc/record_death(mob/living/human/H)
	if(!ticker || ticker.current_state != GAME_STATE_PLAYING || !H.original_job)
		return
	var/list/victim = entry(H)
	if(!victim)
		return
	victim["deaths"]++
	var/mob/living/human/killer = H.last_harmed
	if(!ishuman(killer) && ishuman(H.lastattacker))
		killer = H.lastattacker
	if(!ishuman(killer) || killer == H || !killer.original_job)
		return
	// Team kills do not count.
	if(killer.original_job.base_type_flag() == H.original_job.base_type_flag())
		return
	var/list/K = entry(killer)
	if(K)
		K["kills"]++

/datum/tdm_battle/proc/status()
	. = list("phase" = phase(), "map" = map ? map.title : null, "age" = map ? map.age : null,
		"gamemode" = map ? map.gamemode : null, "players" = length(clients))
	if(ticker && ticker.current_state < GAME_STATE_PLAYING && isnum(ticker.pregame_timeleft))
		.["pregame_seconds"] = ticker.pregame_timeleft
	if(round_start_time && ticker && ticker.current_state >= GAME_STATE_PLAYING)
		.["round_seconds"] = round((world.time - round_start_time) / 10)
	if(rotation_map)
		.["next_map"] = rotation_map
	if(!map)
		return
	.["condition"] = map.current_win_condition
	.["winner"] = map.current_winner
	var/list/teams = list()
	for(var/faction in map.faction_organization)
		var/alive = 0
		var/total = 0
		for(var/mob/living/human/H in player_list)
			if(!H.original_job || H.original_job.base_type_flag() != faction)
				continue
			total++
			if(H.stat != DEAD)
				alive++
		teams += list(list("name" = team_name(faction), "alive" = alive, "total" = total))
	.["teams"] = teams
	var/list/scores = list()
	for(var/name in map.scores)
		if(istext(name) && isnum(map.scores[name]))
			scores[name] = map.scores[name]
	if(length(scores))
		.["scores"] = scores

// Every player's round, once, when the round ends.
/datum/tdm_battle/proc/send_results()
	if(results_sent)
		return
	results_sent = TRUE
	sample()
	var/winner = map ? map.current_winner : null
	var/list/rows = list()
	for(var/ckey in players)
		var/list/E = players[ckey]
		var/list/row = E.Copy()
		row["ckey"] = ckey
		row["result"] = !winner ? "draw" : (E["team"] == winner ? "win" : "loss")
		rows += list(row)
	var/list/data = list("map" = map ? map.title : null, "winner" = winner,
		"round_seconds" = round_start_time ? round((world.time - round_start_time) / 10) : 0, "players" = rows)
	if(!tdm_link.report("results", data))
		log_game("TDM battle: the barracks did not take this round's results.")

// Before the world reboots: everyone goes back to the barracks, then the
// reboot waits for a voted map that is still compiling. Sleeps.
/datum/tdm_battle/proc/before_reboot()
	if(returning)
		return
	send_results()
	returning = TRUE
	tdm_link.report("status", status())
	for(var/client/C in clients)
		to_chat(C, SPAN_NOTICE("<big>The battle is over. Back to the barracks!</big>"))
		shard_group.send_player_soon(C, tdm_link.barracks_id)
	var/deadline = world.time + TDM_ROTATION_WAIT
	while(rotation_map && world.time < deadline)
		var/list/state = rotation_state()
		if(!state || state["state"] != "building")
			break
		sleep(50)
		tdm_link.report("status", status())

/datum/tdm_battle/proc/rotation_state()
	if(!fexists("data/shard-host/rotation.json"))
		return null
	var/list/state = null
	try
		state = json_decode(file2text("data/shard-host/rotation.json"))
	catch
		state = null
	return islist(state) ? state : null

// The map vote's winner is compiled beside the running world
// (scripts/shard-group/battle_mapswap.py) and loaded by the next reboot.
/datum/tdm_battle/proc/rotate(winner)
	if(!istext(winner) || !length(winner) || length(winner) > 64)
		return FALSE
	for(var/i = 1, i <= length(winner), i++)
		var/c = text2ascii(winner, i)
		if(!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95))
			return FALSE
	if(!shell())
		return FALSE
	fdel("data/shard-host/rotation.json")
	text2file(json_encode(list("state" = "building", "map" = winner, "time" = world.realtime)), "data/shard-host/rotation.json")
	rotation_map = winner
	log_game("TDM battle: building the next map, [winner].")
	if(world.system_type == UNIX)
		shell("python3 scripts/shard-group/battle_mapswap.py [winner] > data/shard-host/rotation.log 2>&1 &")
	else
		shell("start \"\" /b python scripts\\shard-group\\battle_mapswap.py [winner] > data\\shard-host\\rotation.log 2>&1")
	return TRUE

/client/proc/tdm_return_to_barracks()
	set name = "Return to Barracks"
	set category = "OOC"
	if(!tdm_battle_active())
		return
	if(WWinput(src, "Leave the battle and go back to the barracks?", "Return to Barracks", "Stay", list("Go back", "Stay")) != "Go back")
		return
	shard_group.send_player(src, tdm_link.barracks_id, TRUE)

/mob/new_player/Login()
	. = ..()
	if(!QDELETED(src) && client && client.mob == src && tdm_battle_active())
		client.verbs |= /client/proc/tdm_return_to_barracks

/hook/death/proc/tdm_battle_death(mob/living/human/H, gibbed)
	if(istype(H) && tdm_battle_active())
		tdm_battle.record_death(H)
	return TRUE

/hook/roundend/proc/tdm_battle_roundend()
	if(tdm_battle_active())
		tdm_battle.send_results_soon()
	return TRUE

/datum/tdm_battle/proc/send_results_soon()
	set waitfor = FALSE
	send_results()

#undef TDM_ROTATION_WAIT
