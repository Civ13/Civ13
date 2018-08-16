/process/battle_report
	var/BR_ticks = 0
	var/max_BR_ticks = 600 // 10 minutes
	var/pirates_deaths_this_cycle = 0
	var/british_deaths_this_cycle = 0
	var/next_can_grant_points = -1

/process/battle_report/setup()
	name = "Battle Report"
	schedule_interval = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.battle_report = src

/process/battle_report/statProcess()
	..()
	stat(null, "Next battle report: [max_BR_ticks - BR_ticks] seconds")

/process/battle_report/htmlProcess()
	return ..() + "Next battle report: [max_BR_ticks - BR_ticks] seconds"

/process/battle_report/fire()
	++BR_ticks
	if (BR_ticks >= max_BR_ticks)
		show_global_battle_report(null)
/*
		var/pirates_death_coeff = (pirates_deaths_this_cycle+1)/(alive_pirates.len + 1)
		var/british_death_coeff = (british_deaths_this_cycle+1)/(alive_british.len + 1)

		// because admins can cause this to happen a lot
		if (world.time >= next_can_grant_points && map && map.faction1_can_cross_blocks())

			if (pirates_deaths_this_cycle && pirates_death_coeff > soviet_death_coeff)
				radio2soviets("Due to your triumphs in the battlefield, we are rewarding you with 200 supply points, comrades.")
				processes.supply.points[SOVIET] += 200

			else if (soviet_deaths_this_cycle && soviet_death_coeff > pirates_death_coeff)
				radio2germans("Due to your triumphs in the battlefield, we are rewarding you with 200 supply points.")
				if (german_supplytrain_master)
					german_supplytrain_master.supply_points += 200
				else
					processes.supply.points[GERMAN] += 200

			next_can_grant_points = world.time + 5500
*/
		BR_ticks = 0
		british_deaths_this_cycle = 0
		pirates_deaths_this_cycle = 0