var/datum/vote/vote = new()

var/global/list/round_voters = list() //Keeps track of the individuals voting for a given round, for use in forcedrafting.

/datum/vote_handle
	var/state = "pending"
	var/generation
	var/winner
	var/deadline
	var/datum/vote/manager
	var/list/completion
	proc/cancel()
		return manager ? manager.cancel_request(src) : FALSE
	proc/resolve()
		return manager ? manager.result(src) : FALSE

// Keep the round alive even if configuration allows restart votes or a saved
// round contains an old finished flag. Administrative save/restart is separate.
/proc/persistence_round_active()
	return (map && (map.persistence || map.perschadplus)) || (config && config.allowedgamemodes == "PERSISTENCE")

/proc/persistence_blocks_vote(var/vote_type, list/completion)
	if (!persistence_round_active())
		return FALSE
	if (vote_type == "restart")
		return TRUE
	// Initial lobby map selection must still be possible.
	if (!ticker || ticker.current_state < GAME_STATE_PLAYING)
		return FALSE
	if (vote_type == "epoch" || vote_type == "map" || vote_type == "gamemode")
		return TRUE
	// A generic question must not disguise a round-transition callback.
	return completion && completion.len == 2 && (istype(completion[1], /process/epochswap) || istype(completion[1], /process/mapswap) || istype(completion[1], /process/gamemode))

// world.time of the last successful persistence save in this process.
var/global/last_persistence_save_time = 0

// Returns why players cannot start (or complete) a save vote, or null if they can.
/proc/persistence_save_vote_block_reason()
	if (!persistence_round_active())
		return "Save votes are only available in persistent rounds."
	if (config.skip_persistence_saving)
		return "Saving is disabled on this server."
	if (!ticker || ticker.current_state < GAME_STATE_PLAYING)
		return "The round has not started yet."
	if (persistence_restart.startup_hold || persistence_restart.busy)
		return "The world is busy with a save or restart."
	if (clients.len < 3)
		return "At least 3 players must be online."
	var/wait = max(last_persistence_save_time, round_start_time) + 6000 - world.time
	if (wait > 0)
		return "The world was saved less than 10 minutes ago ([round((wait + 599) / 600)] minutes left)."
	return null

/datum/vote
	// Runtime admin policy. Restarting the server restores the existing enabled default.
	var/disruptive_votes_enabled = TRUE
	proc/disruptive_action(vote_type, list/completion)
		if (vote_type in list("restart", "epoch", "map")) return TRUE
		if (completion && completion.len == 2)
			// These process callbacks perform the actual map/server transition,
			// including when attached to a generically named question.
			if (istype(completion[1], /process/mapswap) || istype(completion[1], /process/epochswap)) return TRUE
		return FALSE
	proc/action_allowed(vote_type, list/completion)
		return disruptive_votes_enabled || !disruptive_action(vote_type, completion)
	proc/set_disruptive_votes(enabled)
		disruptive_votes_enabled = !!enabled
		if (!disruptive_votes_enabled && is_current(active_request) && disruptive_action(mode, active_request.completion))
			cancel_request(active_request)
		return disruptive_votes_enabled
	var/generation = 0
	var/datum/vote_handle/active_request
	proc/is_current(datum/vote_handle/H)
		return H && H == active_request && H.manager == src && H.generation == generation && H.state == "pending"
	proc/close_ui()
		for (var/client/C in voting.Copy())
			if (C) C << browse(null, "window=vote")
	proc/cancel_request(datum/vote_handle/H)
		if (!is_current(H)) return FALSE
		H.state = "cancelled"
		H.completion = null
		H.manager = null
		active_request = null
		reset()
		return TRUE
	proc/request_vote(vote_type, initiator_key, automatic = FALSE, list/completion = list())
		if (!initiate_vote(vote_type, initiator_key, automatic, completion)) return null
		return active_request
	proc/request_choices(prompt, list/options, initiator_key, duration, list/completion = list(), automatic = FALSE)
		if (persistence_blocks_vote("request", completion) || !action_allowed("request", completion)) return null
		if (mode || !islist(options) || !options.len || options.len > 100 || !istext(prompt) || !isnum(duration) || duration < 10 || duration > 6000) return null
		if (started_time != null && !automatic && !check_rights(R_ADMIN) && started_time + config.vote_delay > world.time) return null
		for (var/option in options)
			if (!istext(option) || !length(option)) return null
		reset()
		mode = "request"
		question = prompt
		initiator = initiator_key
		started_time = world.time
		win_threshold = 0
		for (var/option in options)
			choices[option] = 0
		generation++
		active_request = new
		active_request.manager = src
		active_request.generation = generation
		active_request.deadline = world.time + duration
		active_request.completion = completion.Copy()
		time_remaining = round(duration / 10)
		for (var/client/C in clients)
			if (C) C << browse(interface(C), "window=vote;size=500x800")
		return active_request
	var/initiator = null
	var/started_time = null
	var/time_remaining = 0
	var/mode = null
	var/question = null
	var/default = null
	var/list/choices = list()
	var/list/voted = list()
	var/list/voting = list()
	var/list/current_votes = list()
	var/list/additional_text = list()
	var/win_threshold = 0.65
	var/list/callback = null
	var/list/disabled[10]
	var/voted_epoch = "1713"
	var/voted_gamemode = "Classic (Stone Age Start)"
	var/autogamemode_triggered = FALSE
	var/faction = 0
	var/ship_size = "Small Ships"
	New()
		if (vote != src)
			if (istype(vote))
				del(vote)
			vote = src
	Del()
		reset()
		..()

	proc/process()	//called by master_controller
		var/datum/vote_handle/H = active_request
		if (!is_current(H)) return
		if (mode)
			if (persistence_blocks_vote(mode, H.completion))
				to_chat(world, "<b>Voting aborted: persistent rounds cannot be ended or restarted by a vote.</b>")
				cancel_request(H)
				return
			// No more change mode votes after the game has started.
			// 3 is GAME_STATE_PLAYING, but that #define is undefined for some reason
			if ((mode == "gamemode" || mode == "ship selection") && ticker.current_state >= 2)
				to_chat(world, "<b>Voting aborted due to game start.</b>")
				reset()
				return

			// Calculate how much time is remaining by comparing current time, to time of vote start,
			// plus vote duration
			time_remaining = round((H.deadline - world.time)/10)

			if (world.time >= H.deadline)
				result(H)
			else
				for (var/client/C in voting.Copy())
					if (C)
						C << browse(vote.interface(C),"window=vote")

	proc/autogamemode()
		if (!map.gamemode_vote)
			return
		if (map.persistence)
			return
		if (map.ID == MAP_BATTLE_SHIPS)
			if (faction == 3)
				initiate_vote("gamemode","the server", TRUE)
			else if (faction <= 2)
				initiate_vote("ship selection","the server", TRUE)
			return
		if (!map.is_RP && autogamemode_triggered == FALSE)
			initiate_vote("gamemode", "the server", TRUE)
			log_debug("The server has called a gamemode vote.")
			autogamemode_triggered = TRUE
			return
		else
			return


	proc/reset()
		close_ui()
		if (is_current(active_request))
			active_request.state = "cancelled"
			active_request.completion = null
			active_request.manager = null
		active_request = null
		callback = null
		initiator = null
		time_remaining = 0
		mode = null
		question = null
		default = null
		choices.Cut()
		voted.Cut()
		voting.Cut()
		current_votes.Cut()
		additional_text.Cut()
		disabled.Cut()

	proc/get_result()
		//get the highest number of votes
		var/greatest_votes = 0
		var/total_votes = 0
		for (var/option in choices)
			var/votes = choices[option]
			total_votes += votes
			if (votes > greatest_votes)
				greatest_votes = votes

		var/vote_threshold = total_votes * win_threshold


		//get all options with that many votes and return them in a list
		. = list()
		if (greatest_votes && greatest_votes >= vote_threshold)
			for (var/option in choices)
				if (choices[option] == greatest_votes)
					. += option
		return .

	proc/announce_result()
		var/list/winners = get_result()
		var/text = ""
		if (!winners.len)
			if (default)
				winners += default
		if (winners.len)
			if (winners.len > 1)
			//	if (mode != "gamemode") // Here we are making sure we don't announce potential game modes
				text = "<b>Vote Tied Between:</b>\n"
				for (var/option in winners)
					var/display_opt = option
					if ((mode in list("map", "safehouse map")) && map_id_to_title[option])
						display_opt = map_id_to_title[option]
					text += "\t[display_opt]\n"
			var/newwinner = pick(winners)
			. = newwinner

			for (var/key in current_votes)
				if (choices[current_votes[key]] == newwinner)
					round_voters += key // Keep track of who voted for the winning round.
			var/display_winner = newwinner
			if ((mode in list("map", "safehouse map")) && map_id_to_title[newwinner])
				display_winner = map_id_to_title[newwinner]
			text += "<b>Vote Result: <span class = 'ping'>[display_winner]</span></b><br>"
			text += "<b>The vote has ended.</b>"
		else
			text += "<b>Vote Result: <span class = 'ping'>No</span> - Not enough YES votes (59% is needed)</b>"
		log_vote(text)
		to_chat(world, "<font color='purple'>[text]</font>")
		return .

	proc/result(datum/vote_handle/H)
		if (!is_current(H)) return FALSE
		if (persistence_blocks_vote(mode, H.completion) || !action_allowed(mode, H.completion))
			cancel_request(H)
			return FALSE
		// No yielding callbacks until the old session is terminal and detached.
		H.state = "resolved"
		var/resolved_mode = mode
		var/resolved_faction = faction
		var/list/completion = H.completion
		H.completion = null
		H.manager = null
		. = announce_result()
		H.winner = .
		active_request = null
		reset()
		if ((. || resolved_mode == "request") && completion && completion.len == 2)
			call(completion[1], completion[2])(.)
		// A completion may create or cancel another session. Never apply the
		// old route to it, even if the replacement already finished synchronously.
		if (generation != H.generation || active_request) return .
		if (persistence_blocks_vote(resolved_mode, completion) || !action_allowed(resolved_mode, completion)) return FALSE
		if (.) apply_result(resolved_mode, resolved_faction, ., completion)
		return .

	proc/apply_result(resolved_mode, resolved_faction, winner, list/completion)
		if (persistence_blocks_vote(resolved_mode, completion) || !action_allowed(resolved_mode, completion)) return FALSE
		. = winner
		if (.)
			switch(resolved_mode)
				if ("restart")
					if (. == "Restart Round")
						to_chat(world, "Round ending due to vote.")
						log_game("Ending the round due to restart vote.")
						map.next_win = world.time - 100
						map.round_finished = TRUE
						ticker.finished = TRUE
						processes.epochswap.restart_triggered = TRUE
						processes.epochswap.ready = TRUE
						log_admin("Restart Vote triggered an epoch vote.")
						message_admins("Restart Vote triggered an epoch vote.")
				if ("epoch")
					ticker.finished = TRUE
					processes.mapswap.restart_triggered = TRUE
					processes.mapswap.ready = TRUE
					processes.mapswap.fire()
				if ("map")
					ticker.finished = TRUE
					processes.mapswap.finished_at = world.time
					var/F = file("SQL/gamedata.txt")
					if (fexists("SQL/gamedata.txt"))
						fdel(F)
					var/winner_title = .
					if (map_id_to_title[.])
						winner_title = map_id_to_title[.]
					var/string1 = "map:[winner_title]\n"
					var/string2 = "players:[clients.len]\n"
					text2file("[string1][string2]","SQL/gamedata.txt")
				if ("gamemode")
					// The legacy process supplies this same swap as its callback.
					if (!completion || completion.len != 2 || completion[1] != processes.gamemode || completion[2] != "swap")
						processes.gamemode.swap(.)
				if ("save")
					if (. == "Save Now")
						var/save_block = persistence_save_vote_block_reason()
						if (save_block)
							to_chat(world, "<b>The save vote passed, but the save was skipped: [save_block]</b>")
						else
							log_game("Saving the world due to save vote.")
							spawn(0)
								if (ticker.savemap())
									nextsave = world.realtime + 216000
				if ("ship selection")
					var/obj/map_metadata/battle_ships/battle_ships = map
					if (resolved_faction == 0)
						faction = 1
						ship_size = .
					else if (resolved_faction == 1)
						faction = 2
						battle_ships.load_map(lowertext(replacetext(., " ", "_")), "south")
					else if (resolved_faction == 2)
						faction = 3
						battle_ships.load_map(lowertext(replacetext(., " ", "_")), "north")
		return .

	proc/submit_vote(var/ckey, var/vote, session_generation)
		if (mode && is_current(active_request) && session_generation == generation)
			if (vote && vote >= 1 && vote <= choices.len)
				if (disabled.Find(choices[vote])) return FALSE
				if (current_votes[ckey])
					choices[choices[current_votes[ckey]]] = max(0, choices[choices[current_votes[ckey]]]-1)
				voted |= ckey
				choices[choices[vote]]++	//check this
				current_votes[ckey] = vote
				return vote
		return FALSE

	proc/initiate_vote(var/vote_type, var/initiator_key, var/automatic = FALSE, var/list/_callback = list())
		if (!action_allowed(vote_type, _callback)) return FALSE
		if (persistence_blocks_vote(vote_type, _callback))
			to_chat(world, "<b>Persistent rounds cannot be ended or restarted by a vote.</b>")
			return FALSE
		if (!mode)
			if (started_time != null && !(check_rights(R_ADMIN) || automatic))
				var/next_allowed_time = (started_time + config.vote_delay)
				if (next_allowed_time > world.time)
					return FALSE

			reset()
			var/setup_generation = generation
			win_threshold = 0.00
			default = null

			switch(vote_type)
				if ("restart")
					choices.Add("Restart Round","Continue Playing")
					win_threshold = 0.59
				if ("save")
					question = "Save the world now?"
					choices.Add("Save Now","Keep Playing")
					win_threshold = 0.59
				if ("epoch")
					for (var/epoch in processes.epochswap.epochs)
						if (!default)
							default = epoch
						choices.Add(epoch)
						choices[epoch] = 0
					for (var/epoch in processes.epochswap.epochs)
						if (clients.len < processes.epochswap.epochs[epoch])
							disabled[epoch] = "[processes.epochswap.epochs[epoch]] players needed"
				if ("map")
					for (var/map in processes.mapswap.maps)
						if (!default)
							default = map
						choices.Add(map)
						choices[map] = 0
					for (var/map in processes.mapswap.maps)
						if (clients.len < processes.mapswap.maps[map])
							disabled[map] = "[processes.mapswap.maps[map]] players needed"
				if ("safehouse map")
					var/obj/map_metadata/extraction_survival/M = map
					if (!istype(M) || M.round_closing) return FALSE
					var/list/catalog = M.hub_map_catalog()
					for (var/id in catalog)
						if (!default) default = id
						choices.Add(id)
						choices[id] = 0
				if ("custom")
					var/custom_question = input(usr,"What is the vote for?") as text|null
					if (!custom_question || mode || generation != setup_generation) return FALSE
					var/list/custom_options = list()
					for (var/i=1,i<=10,i++)
						var/option = capitalize(input(usr,"Please enter an option or hit cancel to finish") as text|null)
						if (mode || generation != setup_generation || !usr.client) return FALSE
						if (!option) break
						custom_options.Add(option)
					question = custom_question
					choices = custom_options
					if (!choices.len)
						choices.Add("Yes")
						choices.Add("No")
				if ("gamemode")
					var/list/options = list()
					if (map.ID == MAP_CAPITOL_HILL || map.ID == MAP_YELTSIN)
						options = list("Protect the VIP", "Siege",/* "Area Capture",*/ "Kills")
						if (!default)
							default = "Siege"
					else if (map.ID == MAP_WACO)
						options = list("Protect the VIP", "Siege",/* "Area Capture",*/ /*"Kills"*/)
						if (!default)
							default = "Siege"
					else if (map.ID == MAP_EFT_FACTORY)
						options = list("Hardcore")
						if (!default)
							default = "Hardcore"
					else if (!map.is_RP && !map.nomads && !map.civilizations)
						if(map.no_hardcore)
							options = list("Normal", "Competitive")
						else
							options = list("Normal", "Competitive", "Hardcore")
						if (!default)
							default = "Normal"
					else if (map.is_wasteland)
						options = list("After the Fall", "Nuclear","Zombie Apocalypse")
					else if (map.nomads || map.civilizations)
						options = list(
							"Classic (Stone Age Start)",
							"Auto-Research Mode",
							"Resource-Based Research",
							"Bronze Age (No Research)",
							"Medieval (No Research)",
							"Imperial Age (No Research)",
							"Industrial Age (No Research)",
							"Early Modern Age (No Research)",
							"WW2 Age (No Research)",
							"Modern Age (No Research)")
						if (!default)
							default = "Classic (Stone Age Start)"
					choices.Add(options)

				if ("ship selection")
					var/list/options = list()
					
					var/list/small_ships = list(
						"Patrol boat" = 0,
					)
					var/list/destroyers = list(
						"Indomitable" = 0,
						"Azula" = 0
					)
					var/list/battle_ships = list(
						"Kurama" = 0,
					)
					if (faction == 0)
						question = "What kind of ships should face eachother?"
						options = list(
						"Small Ships" = 0,
						"Destroyers" = 10,
						"Battle Ships (OUT OF ROTATION)" = 999,
						)
						default = "Small Ships"

					else
						switch (faction)
							if (1)
								question = "What ship should the Redmenians use?"
							if (2)
								question = "What ship should the Blugoslavians use?"
						switch (ship_size)
							if ("Small Ships")
								options = small_ships
								default = "Patrol boat"
							if ("Destroyers")
								options = destroyers
								default = "Indomitable"
							if ("Battle Ships")
								options = battle_ships
								default = "Kurama"

					for (var/cur_option in options)
						choices.Add(cur_option)
						choices[cur_option] = 0
					for (var/cur_option in options)
						if (clients.len < options[cur_option])
							disabled[cur_option] = "[options[cur_option]] players needed"
						if (cur_option == "Small Ships" && (clients.len > 20))
							disabled[cur_option] = "20 players maximum"

				else
					return FALSE
			if (persistence_blocks_vote(vote_type, _callback) || !action_allowed(vote_type, _callback))
				reset()
				return FALSE
			mode = vote_type
			generation++
			active_request = new
			active_request.generation = generation
			active_request.manager = src
			active_request.deadline = world.time + (vote_type == "ship selection" ? (faction == 0 ? 450 : 300) : config.vote_period)
			active_request.completion = _callback.Copy()
			initiator = initiator_key
			started_time = world.time
			var/text = "[capitalize(mode)] vote started by [initiator]."
			if (mode == "custom")
				text += "\n[question]"

			log_vote(text)
			if (mode == "ship selection")
				to_chat(world, "<span class = 'deadsay'><b>[text]</b>\nType <b>vote</b> or click <a href='?src=\ref[src]'>here</a> to place your votes.\nYou have 60 seconds to vote.</span>")
				world << sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3)
			else
				to_chat(world, "<span class = 'deadsay'><b>[text]</b>\nType <b>vote</b> or click <a href='?src=\ref[src]'>here</a> to place your votes.\nYou have [config.vote_period/10] seconds to vote.</span>")
				world << sound('sound/ambience/alarm4.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3)

			if ((mode == "gamemode" || mode == "ship selection") && round_progressing)
				round_progressing = FALSE
				to_chat(world, "<font color='red'><b>Round start has been delayed.</b></font>")
			time_remaining = round(config.vote_period/10)

			for (var/client/C in clients)
				if (C)
					C << browse(interface(C), "window=vote;size=500x800")

			return TRUE
		return FALSE

	proc/interface(var/client/C)
		if (!C)	return
		var/admin = FALSE
		if (C.holder)
			if (C.holder.rights & R_ADMIN)
				admin = TRUE
		voting |= C
		. = "<html><head><title>Voting Panel</title></head><body>[common_browser_style]"
		if (mode)
			if (question)	. += "<h2>Vote: '[question]'</h2>"
			else			. += "<h2>Vote: [capitalize(mode)]</h2>"
			. += "Time Left: [time_remaining] s<hr>"
			. += "<table width = '100%'><tr><td align = 'center'><b>Choices</b></td><td align = 'center'><b>Votes</b></td>"
			for (var/i = 1, i <= choices.len, i++)
				var/votes = choices[choices[i]]
				if (!votes)	votes = 0
				. += "<tr>"

				var/display_name = choices[i]
				var/display_desc = ""
				if (mode == "map")
					if (map_id_to_title[choices[i]])
						display_name = map_id_to_title[choices[i]]
					else
						display_name = capitalize(lowertext(choices[i]))
					if (map_id_to_desc[choices[i]])
						display_desc = "<br><span style='font-size: 0.85em; color: #b0a080; font-style: italic;'>[map_id_to_desc[choices[i]]]</span>"
				else if (mode == "epoch")
					if (processes.epochswap.epoch_desc[choices[i]])
						display_desc = "<br><span style='font-size: 0.85em; color: #b0a080; font-style: italic;'>[processes.epochswap.epoch_desc[choices[i]]]</span>"
				else if (mode == "gamemode")
					if (processes.gamemode.gamemode_desc[choices[i]])
						display_desc = "<br><span style='font-size: 0.85em; color: #b0a080; font-style: italic;'>[processes.gamemode.gamemode_desc[choices[i]]]</span>"

				if (disabled.Find(choices[i]))
					continue
				else if (current_votes[C.ckey] == i)
					. += "<td><b><a href='?src=\ref[src];generation=[generation];vote=[i]'>[display_name]</a></b>[display_desc]</td><td align = 'center'>[votes]</td>"
				else
					. += "<td><a href='?src=\ref[src];generation=[generation];vote=[i]'>[display_name]</a>[display_desc]</td><td align = 'center'>[votes]</td>"
				if (additional_text.len >= i)
					. += additional_text[i]
				. += "</tr>"

			. += "</table><hr>"
			if (admin && mode != "map")
				. += "(<a href='?src=\ref[src];generation=[generation];vote=cancel'>Cancel Vote</a>) "
		else
			. += "<h2>Start a vote:</h2><hr><ul><li>"
			//restart
			if (!persistence_blocks_vote("restart") && (admin || config.allow_vote_restart))
				. += "<a href='?src=\ref[src];vote=restart'>Restart</a>"
			else
				. += "<font color='grey'>Restart (Disallowed)</font>"
			. += "</li><li>"
			if (persistence_round_active())
				var/save_block = persistence_save_vote_block_reason()
				if (!save_block)
					. += "<a href='?src=\ref[src];vote=save'>Save progress</a>"
				else
					. += "<font color='grey'>Save progress ([save_block])</font>"
				. += "</li><li>"
			if (admin)
				. += "\t(<a href='?src=\ref[src];vote=toggle_restart'>[config.allow_vote_restart?"Allowed":"Disallowed"]</a>)"
				. += "</li><li>"
				. += "<a href='?src=\ref[src];vote=gamemode'>Gamemode</a></li>"
			//custom
			if (admin)
				. += "<li><a href='?src=\ref[src];vote=custom'>Custom</a></li>"
			. += "</ul><hr>"
		. += "<a href='?src=\ref[src];generation=[generation];vote=close' style='position:absolute;right:50px'>Close</a></body></html>"

		return .


	Topic(href,href_list[],hsrc)
		if (!usr || !usr.client)	return	//not necessary but meh...just in-case somebody does something stupid
		if (href_list["vote"] && (mode || href_list["generation"]) && text2num(href_list["generation"]) != generation) return
		switch(href_list["vote"])
			if ("close")
				voting -= usr.client
				usr << browse(null, "window=vote")
				return
			if ("cancel")
				if (usr.client.holder)
					reset()
			if ("toggle_restart")
				if (usr.client.holder)
					config.allow_vote_restart = !config.allow_vote_restart
			if ("toggle_gamemode")
				if (usr.client.holder)
					config.allow_vote_mode = !config.allow_vote_mode
			if ("restart")
				if (config.allow_vote_restart || usr.client.holder)
					if (config.vote_no_dead && usr.stat == DEAD && !usr.client.holder)
						to_chat(usr, "You can't start restart votes if you are not playing.")
						return FALSE
					if (!config.allowedgamemodes == "TDM")
						if (map.nomads && clients.len < 5 && ((world.time-round_start_time)>108000) && !usr.client.holder)
							to_chat(usr, "You can't start restart votes if the server population is lower than <b>five</b> and the round has been going for over <b>three</b> hours.")
							return FALSE
					initiate_vote("restart",usr.key)
			if ("save")
				var/save_block = persistence_save_vote_block_reason()
				if (save_block)
					to_chat(usr, save_block)
					return FALSE
				if (config.vote_no_dead && usr.stat == DEAD && !usr.client.holder)
					to_chat(usr, "You can't start save votes if you are not playing.")
					return FALSE
				initiate_vote("save",usr.key)
			if ("custom")
				if (usr.client.holder)
					initiate_vote("custom",usr.key)
			if ("gamemode")
				if (usr.client.holder)
					initiate_vote("gamemode",usr.key)
			else
				var/t = round(text2num(href_list["vote"]))
				if (t) // It starts from TRUE, so there's no problem
					submit_vote(usr.ckey, t, text2num(href_list["generation"]))
		usr.vote()


/mob/verb/vote()
	set category = "OOC"
	set name = "Vote"

	if (vote)
		src << browse(vote.interface(client),"window=vote;size=500x800")
