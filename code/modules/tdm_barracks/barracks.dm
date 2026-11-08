// The barracks side of the TDM pair (shard kind BARRACKS): the battle world's
// live status, the way into a round, auto-join, and each player's record.
// The record (data/tdm_barracks/stats.json) is the only thing the barracks
// keeps across restarts; the world itself never saves.

#define TDM_STATS_FILE "data/tdm_barracks/stats.json"
#define TDM_HISTORY_KEPT 10
#define TDM_BOARD_SIZE 10

var/global/datum/tdm_barracks/tdm_barracks = new

/datum/tdm_barracks
	var/running = FALSE
	var/list/status = null
	var/status_at = 0
	var/last_phase = null
	// ckey -> list("key", "rounds", "wins", "losses", "draws", "kills", "deaths", "seconds", "best", "auto")
	var/list/stats = list()
	// The latest rounds, newest first: list("map", "winner", "round_seconds", "players", "top")
	var/list/history = list()

/datum/tdm_barracks/proc/start()
	if(running)
		return
	running = TRUE
	load()

/datum/tdm_barracks/proc/load()
	stats = list()
	history = list()
	if(!fexists(TDM_STATS_FILE))
		return
	var/list/saved = null
	try
		saved = json_decode(file2text(TDM_STATS_FILE))
	catch
		saved = null
	if(!islist(saved))
		log_game("TDM barracks: [TDM_STATS_FILE] is not readable; starting a new record.")
		return
	if(islist(saved["players"]))
		var/list/players = saved["players"]
		for(var/ckey in players)
			if(istext(ckey) && islist(players[ckey]))
				stats[ckey] = players[ckey]
	if(islist(saved["history"]))
		history = saved["history"]

/datum/tdm_barracks/proc/save()
	var/text = json_encode(list("players" = stats, "history" = history))
	var/temporary = "[TDM_STATS_FILE].new"
	fdel(temporary)
	if(!text2file(text, temporary))
		log_game("TDM barracks: could not write [temporary].")
		return FALSE
	fdel(TDM_STATS_FILE)
	fcopy(temporary, TDM_STATS_FILE)
	fdel(temporary)
	return TRUE

/datum/tdm_barracks/proc/record_of(ckey, key = null)
	var/list/R = stats[ckey]
	if(!R)
		R = list("key" = key ? key : ckey, "rounds" = 0, "wins" = 0, "losses" = 0, "draws" = 0, "kills" = 0, "deaths" = 0, "seconds" = 0, "best" = 0, "auto" = 0)
		stats[ckey] = R
	else if(key)
		R["key"] = key
	return R

// -- the battle world's reports -----------------------------------------------

/datum/tdm_barracks/proc/receive_status(list/data)
	status = data
	status_at = world.time
	var/phase = data["phase"]
	if(phase == last_phase)
		return
	var/previous = last_phase
	last_phase = phase
	switch(phase)
		if("pregame")
			announce("<big>A battle on <b>[html_encode(data["map"])]</b> is forming[isnum(data["pregame_seconds"]) ? " and starts in [tdm_clock(data["pregame_seconds"])]" : ""]. [join_link("Join the battle")]</big>")
			spawn(0)
				send_auto_joiners()
		if("playing")
			if(previous == "pregame")
				announce("The battle on <b>[html_encode(data["map"])]</b> has begun. You can still [join_link("join late")].")
		if("finished")
			announce("The battle on <b>[html_encode(data["map"])]</b> is over[data["winner"] ? ": <b>[html_encode(data["winner"])]</b> won" : ""].")
		if("rotating")
			announce("The next battle map, <b>[html_encode(data["next_map"])]</b>, is being prepared.")

/datum/tdm_barracks/proc/receive_results(list/data)
	var/list/rows = data["players"]
	if(!islist(rows))
		return
	var/list/top = null
	for(var/list/row in rows)
		if(!islist(row) || !istext(row["ckey"]) || ckey(row["ckey"]) != row["ckey"])
			continue
		var/list/R = record_of(row["ckey"], istext(row["key"]) ? copytext(row["key"], 1, 33) : null)
		var/kills = isnum(row["kills"]) ? max(0, round(row["kills"])) : 0
		R["rounds"]++
		R["kills"] += kills
		R["deaths"] += isnum(row["deaths"]) ? max(0, round(row["deaths"])) : 0
		R["seconds"] += isnum(row["seconds"]) ? max(0, round(row["seconds"])) : 0
		R["best"] = max(R["best"], kills)
		switch(row["result"])
			if("win")
				R["wins"]++
			if("loss")
				R["losses"]++
			else
				R["draws"]++
		if(!top || kills > top["kills"])
			top = list("key" = R["key"], "kills" = kills)
		var/client/C = directory[row["ckey"]]
		if(C)
			to_chat(C, SPAN_NOTICE("Your last battle: [kills] kills, [isnum(row["deaths"]) ? row["deaths"] : 0] deaths, [row["result"] == "win" ? "a win" : (row["result"] == "loss" ? "a loss" : "a draw")]. [stats_link("Your record")]"))
	var/list/summary = list("map" = data["map"], "winner" = data["winner"], "round_seconds" = data["round_seconds"], "players" = length(rows), "top" = top)
	history.Insert(1, list(summary))
	if(history.len > TDM_HISTORY_KEPT)
		history.Cut(TDM_HISTORY_KEPT + 1)
	save()

/datum/tdm_barracks/proc/announce(text)
	to_chat(world, SPAN_NOTICE(text))

// -- getting into a battle ----------------------------------------------------

/datum/tdm_barracks/proc/status_fresh()
	return status && world.time - status_at < TDM_STATUS_STALE

/datum/tdm_barracks/proc/joinable()
	if(!status_fresh())
		// A sleeping battle world wakes when someone joins it.
		var/list/peer = shard_group.peers[tdm_link.battle_id]
		return peer && (peer["state"] in list("UP", "ASLEEP", "COLD", "WAKING"))
	return status["phase"] in list("pregame", "playing", "finished", "starting")

/datum/tdm_barracks/proc/join(client/C)
	if(!C || !tdm_barracks_active())
		return FALSE
	if(!joinable())
		to_chat(C, SPAN_WARNING("The battle world is not taking players right now[status_fresh() && status["phase"] == "rotating" ? ": the next map is being prepared" : ""]. Try again shortly."))
		return FALSE
	to_chat(C, SPAN_NOTICE("Heading to the battle..."))
	log_game("TDM barracks: [C.ckey] joins the battle.")
	return shard_group.send_player(C, tdm_link.battle_id, TRUE)

/datum/tdm_barracks/proc/send_auto_joiners()
	for(var/client/C in clients)
		var/list/R = stats[C.ckey]
		if(R && R["auto"])
			to_chat(C, SPAN_NOTICE("Auto-join is on: heading to the battle. Use Barracks > Auto-join Battle to turn it off."))
			shard_group.send_player_soon(C, tdm_link.battle_id)

/datum/tdm_barracks/proc/toggle_auto(client/C)
	var/list/R = record_of(C.ckey, C.key)
	R["auto"] = !R["auto"]
	save()
	to_chat(C, SPAN_NOTICE(R["auto"] ? "Auto-join is on: you will be sent to every new battle when it forms." : "Auto-join is off."))
	if(R["auto"] && status_fresh() && status["phase"] == "pregame")
		join(C)

/datum/tdm_barracks/proc/join_link(text)
	return "<a href='byond://?src=\ref[src];tdm_join=1'>[text]</a>"

/datum/tdm_barracks/proc/stats_link(text)
	return "<a href='byond://?src=\ref[src];tdm_stats=1'>[text]</a>"

/datum/tdm_barracks/Topic(href, list/href_list)
	var/client/C = usr ? usr.client : null
	if(!C || !tdm_barracks_active())
		return
	if(href_list["tdm_join"])
		join(C)
	else if(href_list["tdm_stats"])
		show_stats(C)
	else if(href_list["tdm_board"])
		show_board(C)
	else if(href_list["tdm_status"])
		show_status(C)
	else if(href_list["tdm_auto"])
		toggle_auto(C)
		show_status(C)

// -- what players see ---------------------------------------------------------

/datum/tdm_barracks/proc/phase_text()
	if(!status_fresh())
		var/list/peer = shard_group.peers[tdm_link.battle_id]
		if(peer && (peer["state"] in list("ASLEEP", "COLD", "WAKING")))
			return "waiting for players (joining wakes it)"
		return "not answering"
	switch(status["phase"])
		if("pregame")
			return isnum(status["pregame_seconds"]) ? "forming, starts in [tdm_clock(status["pregame_seconds"])]" : "forming"
		if("playing")
			return isnum(status["round_seconds"]) ? "in battle for [tdm_clock(status["round_seconds"])]" : "in battle"
		if("finished")
			return "over, voting on the next map"
		if("returning")
			return "sending everyone back"
		if("rotating")
			return "preparing the next map[status["next_map"] ? " ([html_encode(status["next_map"])])" : ""]"
	return "starting up"

// One line for the Status panel.
/datum/tdm_barracks/proc/summary_line()
	if(!status_fresh())
		return "Battle: [phase_text()]"
	return "Battle: [status["map"]] - [phase_text()] - [isnum(status["players"]) ? status["players"] : 0] players"

/datum/tdm_barracks/proc/status_html(client/C)
	var/list/lines = list("<h2>Battle</h2>")
	if(status_fresh())
		lines += "<p><b>[html_encode(status["map"])]</b>[status["age"] ? " ([html_encode(status["age"])])" : ""][status["gamemode"] ? ", [html_encode(status["gamemode"])]" : ""]</p>"
	lines += "<p>[phase_text()]. [joinable() ? join_link("Join the battle") : ""]</p>"
	if(status_fresh())
		if(istext(status["condition"]) && length(status["condition"]))
			lines += "<p class='note'>[html_encode(status["condition"])]</p>"
		var/list/teams = status["teams"]
		if(islist(teams) && teams.len)
			lines += "<table><tr><th>Side</th><th>Alive</th><th>Fielded</th></tr>"
			for(var/list/T in teams)
				lines += "<tr><td>[html_encode(T["name"])]</td><td>[T["alive"]]</td><td>[T["total"]]</td></tr>"
			lines += "</table>"
		var/list/scores = status["scores"]
		if(islist(scores) && scores.len)
			var/list/parts = list()
			for(var/name in scores)
				parts += "[html_encode(name)]: [scores[name]]"
			lines += "<p>Scores: [jointext(parts, ", ")]</p>"
	var/list/R = C ? stats[C.ckey] : null
	lines += "<p><a href='byond://?src=\ref[src];tdm_auto=1'>Auto-join: [R && R["auto"] ? "on" : "off"]</a> - [stats_link("Your record")] - <a href='byond://?src=\ref[src];tdm_board=1'>Leaderboard</a></p>"
	if(history.len)
		lines += "<h3>Recent battles</h3><table><tr><th>Map</th><th>Winner</th><th>Length</th><th>Top fighter</th></tr>"
		for(var/list/H in history)
			var/list/top = H["top"]
			lines += "<tr><td>[html_encode(H["map"])]</td><td>[H["winner"] ? html_encode(H["winner"]) : "draw"]</td><td>[tdm_clock(H["round_seconds"])]</td><td>[islist(top) && top["kills"] ? "[html_encode(top["key"])] ([top["kills"]])" : "-"]</td></tr>"
		lines += "</table>"
	return jointext(lines, "")

/datum/tdm_barracks/proc/ratio(kills, deaths)
	return deaths ? round(kills / deaths, 0.01) : kills

/datum/tdm_barracks/proc/record_html(list/R)
	if(!R || !R["rounds"])
		return "<p>No battles on record yet. [join_link("Join one")].</p>"
	return "<table><tr><td>Battles</td><td>[R["rounds"]]</td></tr><tr><td>Won / lost / drawn</td><td>[R["wins"]] / [R["losses"]] / [R["draws"]]</td></tr><tr><td>Kills / deaths</td><td>[R["kills"]] / [R["deaths"]] (ratio [ratio(R["kills"], R["deaths"])])</td></tr><tr><td>Best battle</td><td>[R["best"]] kills</td></tr><tr><td>Time in battle</td><td>[tdm_clock(R["seconds"])]</td></tr></table>"

/datum/tdm_barracks/proc/show_status(client/C)
	popup(C, "tdm_status", "Battle Status", status_html(C))

/datum/tdm_barracks/proc/show_stats(client/C)
	popup(C, "tdm_stats", "Your Record", "<h2>[html_encode(C.key)]</h2>" + record_html(stats[C.ckey]))

// The top players by one field, best first.
/datum/tdm_barracks/proc/top(field, minimum_rounds = 1)
	var/list/ranked = list()
	for(var/ckey in stats)
		var/list/R = stats[ckey]
		if(R["rounds"] < minimum_rounds)
			continue
		var/value = field == "ratio" ? ratio(R["kills"], R["deaths"]) : R[field]
		if(!isnum(value) || value <= 0)
			continue
		var/placed = FALSE
		for(var/i = 1, i <= ranked.len, i++)
			if(value > ranked[ranked[i]])
				ranked.Insert(i, ckey)
				ranked[ckey] = value
				placed = TRUE
				break
		if(!placed)
			ranked[ckey] = value
		if(ranked.len > TDM_BOARD_SIZE)
			ranked.Cut(TDM_BOARD_SIZE + 1)
	return ranked

/datum/tdm_barracks/proc/board_html()
	var/list/lines = list("<h2>Leaderboard</h2>")
	for(var/list/board in list(list("kills", "Most kills", 1), list("wins", "Most wins", 1), list("ratio", "Best kill ratio (5+ battles)", 5), list("best", "Best single battle", 1), list("seconds", "Most time in battle", 1)))
		var/list/ranked = top(board[1], board[3])
		lines += "<h3>[board[2]]</h3>"
		if(!ranked.len)
			lines += "<p>Nobody yet.</p>"
			continue
		lines += "<ol>"
		for(var/ckey in ranked)
			var/list/R = stats[ckey]
			lines += "<li>[html_encode(R["key"])]: [board[1] == "seconds" ? tdm_clock(ranked[ckey]) : ranked[ckey]]</li>"
		lines += "</ol>"
	return jointext(lines, "")

/datum/tdm_barracks/proc/show_board(client/C)
	popup(C, "tdm_board", "Leaderboard", board_html())

/datum/tdm_barracks/proc/popup(client/C, id, title, html)
	if(!C || !C.mob)
		return
	var/datum/browser/popup = new(C.mob, id, title, 520, 520)
	popup.add_head_content("<style>table{border-collapse:collapse;width:100%}th,td{padding:3px 6px;text-align:left;border-bottom:1px solid #444}p.note{color:#c96}</style>")
	popup.set_content(html)
	popup.open(FALSE)

// -- verbs --------------------------------------------------------------------

/client/proc/tdm_battle_status()
	set name = "Battle Status"
	set category = "Barracks"
	if(!tdm_barracks_active())
		to_chat(src, SPAN_NOTICE("This server is not a TDM barracks."))
		return
	tdm_barracks.show_status(src)

/client/proc/tdm_join_battle()
	set name = "Join Battle"
	set category = "Barracks"
	if(!tdm_barracks_active())
		to_chat(src, SPAN_NOTICE("This server is not a TDM barracks."))
		return
	tdm_barracks.join(src)

/client/proc/tdm_auto_join()
	set name = "Auto-join Battle"
	set category = "Barracks"
	if(!tdm_barracks_active())
		to_chat(src, SPAN_NOTICE("This server is not a TDM barracks."))
		return
	tdm_barracks.toggle_auto(src)

/client/proc/tdm_my_record()
	set name = "My Battle Record"
	set category = "Barracks"
	if(!tdm_barracks_active())
		to_chat(src, SPAN_NOTICE("This server is not a TDM barracks."))
		return
	tdm_barracks.show_stats(src)

/client/proc/tdm_leaderboard()
	set name = "Leaderboard"
	set category = "Barracks"
	if(!tdm_barracks_active())
		to_chat(src, SPAN_NOTICE("This server is not a TDM barracks."))
		return
	tdm_barracks.show_board(src)

var/global/list/tdm_barracks_verbs = list(/client/proc/tdm_battle_status, /client/proc/tdm_join_battle, /client/proc/tdm_auto_join, /client/proc/tdm_my_record, /client/proc/tdm_leaderboard)

/mob/new_player/Login()
	. = ..()
	if(!QDELETED(src) && client && client.mob == src && tdm_barracks_active() && !(/client/proc/tdm_join_battle in client.verbs))
		client.verbs |= tdm_barracks_verbs
		tdm_barracks.greet(client)

// A newcomer hears what the battle is doing.
/datum/tdm_barracks/proc/greet(client/C)
	if(!C)
		return
	to_chat(C, SPAN_NOTICE("<b>Welcome to the Barracks.</b> [summary_line()]. [joinable() ? join_link("Join the battle") + " or " : ""]practise here. <a href='byond://?src=\ref[src];tdm_status=1'>Battle status</a> - [stats_link("your record")]."))

#undef TDM_STATS_FILE
#undef TDM_HISTORY_KEPT
#undef TDM_BOARD_SIZE
