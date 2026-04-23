/process/battle_report
	var/BR_ticks = 0
	var/max_BR_ticks = 600 // 10 minutes
	var/pirates_deaths_this_cycle = 0
	var/british_deaths_this_cycle = 0
	var/next_can_grant_points = -1

/process/battle_report/setup()
	name = "battle report"
	is_subsystem_member = TRUE
	schedule_interval = 2 SECONDS
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
		BR_ticks = 0
		british_deaths_this_cycle = 0
		pirates_deaths_this_cycle = 0