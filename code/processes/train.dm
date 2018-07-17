/process/train
	var/tmpTime = 0
	var/firstTmpTime = TRUE
	var/supplytrain_special_check = FALSE
	var/supplytrain_may_process = FALSE

/process/train/setup()
	name = "train process"
	schedule_interval = 1 SECOND
	start_delay = 10 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.train = src

/process/train/fire()

	if (!map || map.uses_main_train || map.uses_supply_train)
		try
			normal_train_processes()
			tmpTime += schedule_interval
			if (tmpTime >= 1200 || firstTmpTime || supplytrain_special_check)
				tmpTime = 0
				supplytrain_may_process = TRUE // not sure how else to do this without breaking the process
			firstTmpTime = FALSE

		catch(var/exception/e)
			catchException(e)