/client/proc/change_time_of_day()
	set category = "Debug"
	set name = "Change Time of Day"
	if (!processes.time_of_day || !processes.time_of_day.fires_at_gamestates.Find(ticker.current_state))
		src << "<span class = 'warning'>You can't change the time of day right now.</span>"
		return
	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return
	src << "<span class = 'warning'>Updating lights, please wait...</span>"
	progress_time_of_day(caller = src, force = TRUE)

/client/proc/change_wind_dir()
	set category = "Debug"
	set name = "Change Wind Direction (USE VAR EDIT!)"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return
	var/oldwind = map.winddirection
	map.winddirection = pick("North", "South", "East", "West")
	switch (map.windspeedvar)
		if (0)
			map.windspeed = "calm"
			map.winddesc = "No wind."
		if (1)
			map.windspeed = "a light breeze"
			map.winddesc = "A light [map.winddirection]ern breeze."
		if (2)
			map.windspeed = "a moderate breeze"
			map.winddesc = "A moderate [map.winddirection]ern breeze."
		if (3)
			map.windspeed = "a strong breeze"
			map.winddesc = "A strong [map.winddirection]ern breeze."
		if (4)
			map.windspeed = "a gale"
			map.winddesc = "A [map.winddirection]ern gale."

	if (map.winddirection != oldwind)
		world << "<big>The wind changes direction. It is now blowing from the <b>[map.winddirection]</b>.</big>"

/client/proc/change_wind_spd()
	set category = "Debug"
	set name = "Change Wind Speed (USE VAR EDIT!)"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/oldspeed = map.windspeedvar
	map.windspeedvar += pick(-1,0,1)
	if (map.windspeedvar > 4)
		map.windspeedvar = 4
	if (map.windspeedvar < 0)
		map.windspeedvar = 0

	switch (map.windspeedvar)
		if (0)
			map.windspeed = "calm"
			map.winddesc = "No wind."
		if (1)
			map.windspeed = "a light breeze"
			map.winddesc = "A light [map.winddirection]ern breeze."
		if (2)
			map.windspeed = "a moderate breeze"
			map.winddesc = "A moderate [map.winddirection]ern breeze."
		if (3)
			map.windspeed = "a strong breeze"
			map.winddesc = "A strong [map.winddirection]ern breeze."
		if (4)
			map.windspeed = "a gale"
			map.winddesc = "A [map.winddirection]ern gale."

	if (map.windspeedvar != oldspeed)
		world << "<big>The wind changes strength. It is now <b>[map.windspeed]</b>.</big>"
