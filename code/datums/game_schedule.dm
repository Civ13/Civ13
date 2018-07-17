var/datum/game_schedule/global_game_schedule = null

/datum/game_schedule
	var/enabled = FALSE
	// when the game is open to non-staff, UTC (5 hours ahead of EST)
	var/starttime = 16 // MUST be an integer
	// when the game is closed to non-staff, UTC (5 hours ahead of EST)
	var/endtime = 21 // MUST be an integer
	// days the game is CLOSED
	var/list/days_closed = list()
	// days the game is always open (WIP!)
	var/list/days_always_open = list()
	// a reference realtime, date (in DD-MM-YY format) and day:
	// this is not 100% accurate, but because starttime, endtime, are
	// independent of this, it doesn't matter
	var/refdate = "5619460480:22-10-17:Sunday"
	// DO NOT CHANGE THIS **EVER** OR ALL BANS AND STUFF BREAK
	var/refdate_static = "5619460480:22-10-17:Sunday"
	// the time in hours (decimal)
	var/time = -1
	// the day
	var/day = "Sunday"
	/* date info (WIP): probably will be retrieved from a text file that the bot writes to
	 * we only need it to display exact dates such as in bans - Kachnov */
	var/date = list(
		"day" = 1,
		"month" = 1,
		"year" = 2000)
	// stored value of world.realtime at the time of creation
	var/realtime = -1
	// and so we can read realtime it in standard notation
	var/realtime_as_string = ""
	// other stored strings
	var/scheduleString = ""
	var/dateInfoString = ""
	// admin
	var/forceClosed = FALSE
	var/forceOpened = FALSE

/datum/game_schedule/New()
	update()
	loadFromDB()
	saveToDB()

/datum/game_schedule/proc/update()

	if (!enabled)
		world_is_open = TRUE
		return TRUE

	time = getCurrentTime()

	world_is_open = FALSE

	if (time >= starttime)
		if (time <= endtime)
			world_is_open = TRUE
		else if (time >= endtime)
			if (endtime <= starttime)
				world_is_open = TRUE
	else if (time <= starttime)
		if (time <= endtime)
			world_is_open = TRUE

	// determine the day by counting from refdate's day
	var/split = splittext(refdate, ":")
	var/ref_realtime = text2num(split[1])
//	var/ref_date = split[2] // currently unused: commented out to avoid errors
	var/ref_day = split[3]
	var/days_elapsed = round((world.realtime - ref_realtime)/864000)
	for (var/v in 1 to days_elapsed)
		ref_day = nextDay(ref_day)

	day = ref_day
	realtime = world.realtime
	realtime_as_string = num2text(realtime, 20)

	// hard overrides for opening or closing the world
	if (days_closed.Find(day))
		world_is_open = FALSE
	else if (days_always_open.Find(day))
		world_is_open = TRUE

	if (forceOpened)
		world_is_open = TRUE

 	// overrides forceOpened
	if (forceClosed)
		world_is_open = FALSE

	return TRUE

/datum/game_schedule/proc/forceClose()
	forceClosed = TRUE
	update()
	for (var/client/C in clients)
		if (!C.holder && !C.isPatron("$10+"))
			C << "<span class = 'userdanger'>The server has been closed.</span>"
			spawn (1)
				del C
	saveToDB()

/datum/game_schedule/proc/unforceClose()
	forceClosed = FALSE
	update()
	saveToDB()

/datum/game_schedule/proc/forceOpen()
	forceOpened = TRUE
	update()
	saveToDB()

/datum/game_schedule/proc/unforceOpen()
	forceOpened = FALSE
	update()
	saveToDB()

/datum/game_schedule/proc/saveToDB()
	var/spawntime = FALSE
	if (!database)
		spawntime = 100
	spawn (spawntime)
		var/list/tablecheck = database.execute("SELECT * FROM misc WHERE key = 'game_schedule_metadata';")
		if (!islist(tablecheck) || isemptylist(tablecheck))
			var/emptystr = ""
			database.execute("INSERT INTO misc (key, val) VALUES ('game_schedule_metadata', '[emptystr]');")
		spawn (5)
			database.execute("UPDATE misc SET val = '[forceOpened]&[forceClosed]' WHERE key = 'game_schedule_metadata';")

/datum/game_schedule/proc/loadFromDB()
	var/spawntime = FALSE
	if (!database)
		spawntime = 100
	spawn (spawntime)
		var/list/tables = database.execute("SELECT * FROM misc WHERE key = 'game_schedule_metadata';")
		if (islist(tables) && !isemptylist(tables))
			if (tables["val"])
				var/list/metadata = splittext(tables["val"], "&")
				forceOpened = text2num(metadata[1])
				forceClosed = text2num(metadata[2])

/datum/game_schedule/proc/getCurrentTime(var/unit = "hours")
	// first, get the number of seconds that have elapsed since FALSE0:00:00 today
	. = world.timeofday/10
	// now convert that to minutes
	. /= 60
	// now convert that to hours
	. /= 60
	// now we've returned the current time

	switch (unit)
		if ("hours")
			return .
		if ("minutes")
			return .*60
		if ("seconds")
			return .*60*60
		if ("deciseconds")
			return .*60*60*10

/datum/game_schedule/proc/getNewRealtime()
	var/reftime = text2num(splittext(refdate_static, ":")[1])
	reftime += getCurrentTime("deciseconds")

/datum/game_schedule/proc/getScheduleAsString()
	. = "from [starttime] to [endtime] UTC"
	if (days_closed.len)
		. += ", but is closed on "
		if (days_closed.len > 1)
			for (var/day in days_closed)
				. += day
				if (days_closed[days_closed.len] != day)
					if (days_closed[days_closed.len-1] == day)
						. += " and "
					else
						. += ", "
		else
			. += "[days_closed[1]]"
	if (days_always_open.len)
		. += ", and is always open on "
		if (days_always_open.len > 1)
			for (var/day in days_always_open)
				. += day
				if (days_always_open[days_always_open.len] != day)
					if (days_always_open[days_always_open.len-1] == day)
						. += " and "
					else
						. += ", "
		else
			. += "[days_always_open[1]]"

	scheduleString = .

/datum/game_schedule/proc/getDayInfoAsString()
	. = "[day], [getCurrentTime()] UTC"
	dateInfoString = .

/datum/game_schedule/proc/getDateInfoAsString()
	return replacetext(time2text(world.realtime, "DDD MMM DD hh:mm:ss YYYY"), "/", ".")

/proc/nextDay(day)
	switch (day)
		if ("Monday")
			return "Tuesday"
		if ("Tuesday")
			return "Wednesday"
		if ("Wednesday")
			return "Thursday"
		if ("Thursday")
			return "Friday"
		if ("Friday")
			return "Saturday"
		if ("Saturday")
			return "Sunday"
		if ("Sunday")
			return "Monday"