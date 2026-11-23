// The Barracks battle map vote (Val, 2026-11-23): while the battle world is
// empty and no round is running, players in the Barracks vote on its next map.
// Only maps the Barracks has enough players for are offered, by the player
// needs the battle's own round-end vote uses (mapswap_epoch_maps()). The winner
// goes to the battle world over the pair's link (tdm_link.command), which builds
// it beside itself and reboots onto it (tdm_battle.barracks_map()).

// Every TDM battle map once, in vote order: map id -> list("epoch", "players").
// With a player count, only the maps that many players can start.
/proc/tdm_battle_map_choices(players = null)
	. = list()
	for(var/epoch in tdm_epochs())
		var/list/maps = mapswap_epoch_maps(epoch)
		for(var/id in maps)
			if(.[id])
				continue
			var/needed = isnum(maps[id]) ? maps[id] : 0
			if(isnum(players) && players < needed)
				continue
			.[id] = list("epoch" = epoch, "players" = needed)

// The battle world is waiting for players with nobody in it.
/datum/tdm_barracks/proc/battle_idle()
	if(!status_fresh() || status["phase"] != "pregame")
		return FALSE
	return !status["players"]

// Why a map vote cannot start now, or null when it can.
/datum/tdm_barracks/proc/map_vote_block()
	if(!tdm_barracks_active())
		return "This server is not a TDM barracks."
	if(!battle_idle())
		return "The battle map can be chosen only while the battle world is empty and no round is running."
	if(vote.mode)
		return "Another vote is running. Wait for it to end."
	if(!length(tdm_battle_map_choices(length(clients))))
		return "No battle map can start with the [length(clients)] player\s here."
	return null

/datum/tdm_barracks/proc/start_map_vote(client/C)
	if(!C)
		return FALSE
	// A map vote is already running: the same link takes the player to its ballot.
	if(tdm_barracks_active() && vote.mode == "battle map")
		vote.show_window(C, TRUE)
		return TRUE
	var/reason = map_vote_block()
	if(reason)
		to_chat(C, SPAN_WARNING(reason))
		return FALSE
	if(!vote.initiate_vote("battle map", C.key, FALSE, list(src, "map_vote_won")))
		var/wait = vote.started_time != null ? vote.started_time + config.vote_delay - world.time : 0
		to_chat(C, SPAN_WARNING(wait > 0 ? "A vote was held a short while ago. The next one can start in [tdm_clock(wait / 10)]." : "The map vote could not start. Try again in a little while."))
		return FALSE
	log_game("TDM barracks: [C.ckey] started a battle map vote.")
	return TRUE

// The vote's callback: the winning map id.
/datum/tdm_barracks/proc/map_vote_won(winner)
	if(!istext(winner) || !tdm_barracks_active())
		return
	var/title = map_id_to_title[winner] ? map_id_to_title[winner] : winner
	if(!battle_idle())
		announce("The battle filled up before the vote ended, so it keeps <b>[html_encode(status_fresh() ? status["map"] : "its map")]</b>.")
		return
	var/list/reply = tdm_link.command("map", list("map" = winner))
	if(!islist(reply))
		announce("The battle world did not answer, so it keeps its map. Try the vote again shortly.")
		return
	if(!reply["ok"])
		announce("The battle world kept its map: [html_encode(istext(reply["reason"]) ? reply["reason"] : "it could not take the vote")].")
		return
	if(reply["same"])
		announce("The battle is already set on <b>[html_encode(title)]</b>. [join_link("Join the battle")]")
		return
	log_game("TDM barracks: the battle map vote chose [winner].")
	announce("<big>The battle world is loading <b>[html_encode(title)]</b>.</big> You will be told when it is ready to join.")

/datum/tdm_barracks/proc/map_vote_link(text)
	return "<a href='byond://?src=\ref[src];tdm_map_vote=1'>[text]</a>"

/client/proc/tdm_vote_battle_map()
	set name = "Vote Battle Map"
	set category = "Barracks"
	if(!tdm_barracks_active())
		to_chat(src, SPAN_NOTICE("This server is not a TDM barracks."))
		return
	tdm_barracks.start_map_vote(src)
