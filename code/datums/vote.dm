var/datum/vote/vote = new()

var/global/list/round_voters = list() //Keeps track of the individuals voting for a given round, for use in forcedrafting.

/datum/vote
	var/initiator = null
	var/started_time = null
	var/time_remaining = 0
	var/mode = null
	var/question = null
	var/default = null
	var/list/choices = list()
	var/list/gamemode_names = list()
	var/list/voted = list()
	var/list/voting = list()
	var/list/current_votes = list()
	var/list/additional_text = list()
	var/auto_muted = FALSE
	var/win_threshold = 0.00
	var/list/callback = null
	var/list/disabled[10]

	New()
		if (vote != src)
			if (istype(vote))
				del(vote)
			vote = src

	proc/process()	//called by master_controller
		if (mode)
			// No more change mode votes after the game has started.
			// 3 is GAME_STATE_PLAYING, but that #define is undefined for some reason
			if (mode == "gamemode" && ticker.current_state >= 2)
				world << "<b>Voting aborted due to game start.</b>"
				reset()
				return

			// Calculate how much time is remaining by comparing current time, to time of vote start,
			// plus vote duration
			time_remaining = round((started_time + config.vote_period - world.time)/10)

			if (time_remaining < 0)
				result()
				for (var/client/C in voting)
					if (C)
						C << browse(null,"window=vote")
				reset()
			else
				voting.Cut()
				for (var/client/C in voting)
					if (C)
						C << browse(vote.interface(C),"window=vote")

	proc/autogamemode()
		return//I hate autogamemode vote.
		//initiate_vote("gamemode","the server", TRUE)
		//log_debug("The server has called a gamemode vote")

	proc/reset()
		initiator = null
		time_remaining = 0
		mode = null
		question = null
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

		/* // no more - kachnov
		//default-vote for everyone who didn't vote
		if (!config.vote_no_default && choices.len)
			var/non_voters = (clients.len - total_votes)
			if (non_voters > 0)
				if (mode == "restart")
					choices["Continue Playing"] += non_voters
					if (choices["Continue Playing"] >= greatest_votes)
						greatest_votes = choices["Continue Playing"]
				else if (mode == "gamemode")
					if (master_mode in choices)
						choices[master_mode] += non_voters
						if (choices[master_mode] >= greatest_votes)
							greatest_votes = choices[master_mode]
		*/

		//get all options with that many votes and return them in a list
		. = list()
		if (greatest_votes && greatest_votes >= vote_threshold)
			for (var/option in choices)
				if (choices[option] == greatest_votes)
					. += utf8_to_cp1251(option)
		return .

	proc/announce_result()
		var/list/winners = get_result()
		var/text
		if (!winners.len)
			if (default)
				winners += default
		if (winners.len)
			if (winners.len > 1)
			//	if (mode != "gamemode") // Here we are making sure we don't announce potential game modes
				text = "<b>Vote Tied Between:</b>\n"
				for (var/option in winners)
					text += "\t[option]\n"
			. = pick(winners)

			for (var/key in current_votes)
				if (choices[current_votes[key]] == .)
					round_voters += key // Keep track of who voted for the winning round.
			text += "<b>Vote Result: <span class = 'ping'>[.]</span></b><br>"
			text += "<b>The vote has ended. </b>" // What will be shown if it is a gamemode vote that isn't extended
			if (callback)
				if (callback.len == 2)
					call(callback[1], callback[2])(.)
				callback = null
		else
			text += "<b>Vote Result: Inconclusive - Neither option had enough votes!</b>"
		/*	if (mode == "add_antagonist")
				antag_add_failed = TRUE*/
		log_vote(text)
		world << "<font color='purple'>[text]</font>"
		return .

	proc/result()
		. = announce_result()
		var/restart = FALSE
		if (.)
			switch(mode)
				if ("restart")
					if (. == "Restart Round")
						restart = TRUE
				if ("map")
					processes.mapswap.finished_at = world.time
/*				if ("gamemode")
					if (master_mode != .)
						world.save_mode(.)
						if (ticker && ticker.mode)
							restart = TRUE
						else
							master_mode = .*/
			/*	if ("add_antagonist")
					if (isnull(.) || . == "None")
						antag_add_failed = TRUE
					else
						additional_antag_types |= antag_names_to_ids[.]*/

/*		if (mode == "gamemode") //fire this even if the vote fails.
			if (!round_progressing)
				round_progressing = TRUE
				world << "<font color='red'><b>The round will start soon.</b></font>"*/

		if (restart)
			world << "Round ending due to vote."
			log_game("Ending the round due to restart vote.")
			if (map)
				map.next_win = world.time - 100
			else
				ticker.finished = TRUE

		return .

	proc/submit_vote(var/ckey, var/vote)
		if (mode)
			if (config.vote_no_dead && usr.stat == DEAD && !usr.client.holder)
				return FALSE
			if (vote && vote >= 1 && vote <= choices.len)
				if (current_votes[ckey])
					choices[choices[current_votes[ckey]]]--
				voted += usr.ckey
				choices[choices[vote]]++	//check this
				current_votes[ckey] = vote
				return vote
		return FALSE

	proc/initiate_vote(var/vote_type, var/initiator_key, var/automatic = FALSE, var/list/_callback = list())
		if (!mode)
			if (started_time != null && !(check_rights(R_ADMIN) || automatic))
				var/next_allowed_time = (started_time + config.vote_delay)
				if (next_allowed_time > world.time)
					return FALSE

			reset()
			win_threshold = 0.00
			default = null

			switch(vote_type)
				if ("restart")
					choices.Add("Restart Round","Continue Playing")
					win_threshold = 0.67
				if ("map")
					for (var/map in processes.mapswap.maps)
						if (!default)
							default = map
						map = capitalize(lowertext(map))
						choices.Add(map)
						choices[map] = 0
					for (var/map in processes.mapswap.maps)
						if (clients.len < processes.mapswap.maps[map])
							disabled[capitalize(lowertext(map))] = "[processes.mapswap.maps[map]] players needed"
				if ("custom")
					question = cp1251_to_utf8(rhtml_encode(input(usr,"What is the vote for?") as text|null))
					if (!question)	return FALSE
					for (var/i=1,i<=10,i++)
						var/option = cp1251_to_utf8(capitalize(rhtml_encode(input(usr,"Please enter an option or hit cancel to finish") as text|null)))
						if (!option || mode || !usr.client)	break
						choices.Add(option)
					if (!choices.len)
						choices.Add("Yes")
						choices.Add("No")
				else
					return FALSE
			mode = vote_type
			initiator = initiator_key
			started_time = world.time
			var/text = "[capitalize(mode)] vote started by [initiator]."
			if (mode == "custom")
				text += "\n[utf8_to_cp1251(question)]"

			log_vote(text)
			world << "<span class = 'deadsay'><b>[text]</b>\nType <b>vote</b> or click <a href='?src=\ref[src]'>here</a> to place your votes.\nYou have [config.vote_period/10] seconds to vote.</span>"
		/*	switch(vote_type)
				if ("gamemode")
					world << sound('sound/ambience/alarm4.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3)
				if ("custom")
					world << sound('sound/ambience/alarm4.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3)
				if ("restart")
					world << sound('sound/ambience/alarm4.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3)
*/
			world << sound('sound/ambience/alarm4.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3)
			if (mode == "gamemode" && round_progressing)
				round_progressing = FALSE
				world << "<font color='red'><b>Round start has been delayed.</b></font>"
			time_remaining = round(config.vote_period/10)
			callback = _callback
			return TRUE
		return FALSE

	proc/interface(var/client/C)
		if (!C)	return
		var/admin = FALSE
		if (C.holder)
			if (C.holder.rights & R_ADMIN)
				admin = TRUE
		voting |= C

		. = "<html><head><title>Voting Panel</title></head><body>"
		if (mode)
			if (question)	. += "<h2>Vote: '[question]'</h2>"
			else			. += "<h2>Vote: [capitalize(mode)]</h2>"
			. += "Time Left: [time_remaining] s<hr>"
			. += "<table width = '100%'><tr><td align = 'center'><b>Choices</b></td><td align = 'center'><b>Votes</b></td>"
			if (capitalize(mode) == "Gamemode") .+= "<td align = 'center'><b>Minimum Players</b></td></tr>"

			for (var/i = 1, i <= choices.len, i++)
				var/votes = choices[choices[i]]
				if (!votes)	votes = 0
				. += "<tr>"

				if (disabled.Find(choices[i]))
					. += "<td><font color = 'grey'>DISABLED ([disabled[choices[i]]]): [choices[i]]</td><td align = 'center'>[votes]</font></td>"
				else if (current_votes[C.ckey] == i)
					. += "<td><b><a href='?src=\ref[src];vote=[i]'>[choices[i]]</a></b></td><td align = 'center'>[votes]</td>"
				else
					. += "<td><a href='?src=\ref[src];vote=[i]'>[choices[i]]</a></td><td align = 'center'>[votes]</td>"
				if (additional_text.len >= i)
					. += additional_text[i]
				. += "</tr>"

			. += "</table><hr>"
			if (admin && mode != "map")
				. += "(<a href='?src=\ref[src];vote=cancel'>Cancel Vote</a>) "
		else
			. += "<h2>Start a vote:</h2><hr><ul><li>"
			//restart
			if (admin || config.allow_vote_restart)
				. += "<a href='?src=\ref[src];vote=restart'>Restart</a>"
			else
				. += "<font color='grey'>Restart (Disallowed)</font>"
			. += "</li><li>"
			if (admin)
				. += "\t(<a href='?src=\ref[src];vote=toggle_restart'>[config.allow_vote_restart?"Allowed":"Disallowed"]</a>)"
		//	. += "</li><li>"
			//gamemode
			/*
			if (trialmin || config.allow_vote_mode)
				. += "<a href='?src=\ref[src];vote=gamemode'>GameMode</a>"
			else
				. += "<font color='grey'>GameMode (Disallowed)</font>"
			if (trialmin)
				. += "\t(<a href='?src=\ref[src];vote=toggle_gamemode'>[config.allow_vote_mode?"Allowed":"Disallowed"]</a>)"
			. += "</li><li>"
			//extra antagonists
			if (!antag_add_failed && config.allow_extra_antags)
				. += "<a href='?src=\ref[src];vote=add_antagonist'>Add Antagonist Type</a>"
			else
				. += "<font color='grey'>Add Antagonist Type (Disallowed)</font>"
			. += "</li>"*/
			//custom
			if (admin)
				. += "<li><a href='?src=\ref[src];vote=custom'>Custom</a></li>"
			. += "</ul><hr>"
		. += "<a href='?src=\ref[src];vote=close' style='position:absolute;right:50px'>Close</a></body></html>"
		return .


	Topic(href,href_list[],hsrc)
		if (!usr || !usr.client)	return	//not necessary but meh...just in-case somebody does something stupid
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
					initiate_vote("restart",usr.key)
		/*	if ("gamemode")
				if (config.allow_vote_mode || usr.client.holder)
					initiate_vote("gamemode",usr.key)
			if ("add_antagonist")
				if (config.allow_extra_antags)
					initiate_vote("add_antagonist",usr.key)*/
			if ("custom")
				if (usr.client.holder)
					initiate_vote("custom",usr.key)
			else
				var/t = round(text2num(href_list["vote"]))
				if (t) // It starts from TRUE, so there's no problem
					submit_vote(usr.ckey, t)
		usr.vote()


/mob/verb/vote()
	set category = "OOC"
	set name = "Vote"

	if (vote)
		src << browse(vote.interface(client),"window=vote")
