/client/proc/change_time_of_day()
	set category = "Special"
	set name = "Change Time of Day"
	if (!processes.time_of_day || !processes.time_of_day.fires_at_gamestates.Find(ticker.current_state))
		src << "<span class = 'warning'>You can't change the time of day right now.</span>"
		return
	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return
	src << "<span class = 'warning'>Updating lights, please wait...</span>"
	progress_time_of_day(caller = src)
