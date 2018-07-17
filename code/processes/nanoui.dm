/process/nanoUI/setup()
	name = "nanoui"
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	schedule_interval = 0.5 SECONDS // every half second (more responsive) - Kachnov
	priority = PROCESS_PRIORITY_MEDIUM
	processes.nanoUI = src

/process/nanoUI/fire()
	for (current in current_list)
		var/datum/nanoui/NUI = current
		if (!isDeleted(NUI))
			try
				// runtime prevention
				if (NUI.state && NUI.user)
					NUI.process()
			catch(var/exception/e)
				catchException(e, NUI)
		else
			catchBadType(NUI)
			nanomanager.processing_uis -= NUI

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/nanoUI/reset_current_list()
	PROCESS_USE_FASTEST_LIST(nanomanager.processing_uis)

/process/nanoUI/statProcess()
	..()
	stat(null, "[nanomanager.processing_uis.len] UIs")

/process/nanoUI/htmlProcess()
	return ..() + "[nanomanager.processing_uis.len] UIs"