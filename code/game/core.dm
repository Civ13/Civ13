
/hook/roundstart/proc/mainstuff()
	world << "<b><big>The round has started!</big></b>"

	for (var/C in clients)
		winset(C, null, "mainwindow.flash=1")

	// announce after some other stuff, like system setups, are announced
	spawn (3)

		// this may have already happened, do it again w/o announce
		setup_autobalance(0)
		if (map && map.ID == MAP_FOOTBALL)
			var/obj/map_metadata/football/FM = map
			for (var/datum/job/job in job_master.faction_organized_occupations)
				if (istype(job, /datum/job/civilian/football_red/goalkeeper))
					job.title = "[FM.teams[FM.team1][1]] goalkeeper"
					job.selection_color = FM.teams[FM.team1]["main uniform"]["shirt_color"]

				else if (istype(job, /datum/job/civilian/football_red))
					job.title = FM.teams[FM.team1][1]
					job.selection_color = FM.teams[FM.team1]["main uniform"]["shirt_color"]

				else if (istype(job, /datum/job/civilian/football_blue/goalkeeper))
					job.title = "[FM.teams[FM.team2][1]] goalkeeper"
					job.selection_color = FM.teams[FM.team2]["main uniform"]["shirt_color"]

				else if (istype(job, /datum/job/civilian/football_blue))
					job.title = FM.teams[FM.team2][1]
					job.selection_color = FM.teams[FM.team2]["main uniform"]["shirt_color"]
			for (var/obj/effect/step_trigger/goal/red/GR in world)
				GR.assign()
			for (var/obj/effect/step_trigger/goal/blue/GB in world)
				GB.assign()	
		if (map && map.ID == MAP_FOOTBALL_CAMPAIGN)
			var/obj/map_metadata/football_campaign/FM = map
			for (var/datum/job/job in job_master.faction_organized_occupations)
				if (istype(job, /datum/job/civilian/football_red_campaign/goalkeeper))
					job.title = "[FM.teams[FM.team1][1]] goalkeeper"
					job.selection_color = FM.teams[FM.team1]["main uniform"]["shirt_color"]

				else if (istype(job, /datum/job/civilian/football_red_campaign))
					job.title = FM.teams[FM.team1][1]
					job.selection_color = FM.teams[FM.team1]["main uniform"]["shirt_color"]

				else if (istype(job, /datum/job/civilian/football_blue_campaign/goalkeeper))
					job.title = "[FM.teams[FM.team2][1]] goalkeeper"
					job.selection_color = FM.teams[FM.team2]["main uniform"]["shirt_color"]

				else if (istype(job, /datum/job/civilian/football_blue_campaign))
					job.title = FM.teams[FM.team2][1]
					job.selection_color = FM.teams[FM.team2]["main uniform"]["shirt_color"]
			for (var/obj/effect/step_trigger/goal/red/GR in world)
				GR.assign()
			for (var/obj/effect/step_trigger/goal/blue/GB in world)
				GB.assign()	
		// let new players see the join link
		for (var/np in new_player_mob_list)
			if (np:client)
				np:new_player_panel_proc()


	return TRUE