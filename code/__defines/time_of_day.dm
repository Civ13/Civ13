#define BASIC_LIGHT_AMOUNT 0.05
#define MAX_LIGHT_AMOUNT 1.00
//#define ALWAYS_DAY
var/time_of_day = "Morning"
var/list/times_of_day = list("Early Morning", "Morning", "Midday", "Afternoon", "Evening", "Night")
// from lightest to darkest: midday, afternoon, morning, early morning, evening, night
var/list/time_of_day2luminosity = list(
	"Early Morning" = BASIC_LIGHT_AMOUNT * 10,
	"Morning" = BASIC_LIGHT_AMOUNT * 15,
	"Afternoon" = BASIC_LIGHT_AMOUNT * 18,
	"Midday" = MAX_LIGHT_AMOUNT,
	"Evening" = BASIC_LIGHT_AMOUNT * 7,
	"Night" = BASIC_LIGHT_AMOUNT * 2,)

var/list/time_of_day2ticks = list(
	"Early Morning" = 20*60,
	"Morning" = 20*60,
	"Afternoon" = 20*60,
	"Midday" = 20*60,
	"Evening" = 20*60,
	"Night" = 20*60,)

/proc/isDarkOutside()
	if (list("Evening", "Night").Find(time_of_day))
		return 1
	return 0

/proc/pick_TOD()

	if (map && times_of_day.len != map.times_of_day.len)
		times_of_day = map.times_of_day
	// attempt to fix broken BYOND probability

	// do not shuffle the actual list, we need it to stay in order
	var/list/c_times_of_day = shuffle(times_of_day)
	#ifdef ALWAYS_DAY
	return "Midday"
	#else
	// chance of midday: ~52%. Chance of afternoon: ~27%. Chance of any other: ~21%
	if (map && map.ID == MAP_NOMADS_WASTELAND_2 || MAP_PIONEERS_WASTELAND_2)
		return "Morning"
	else
		if (prob(50))
			if (prob(75))
				return "Midday"
			else
				return "Afternoon"
		else
			return pick(c_times_of_day)
	#endif

/proc/progress_time_of_day(var/caller = null, var/force = FALSE)
	if(config.daynight_on || force)
		var/TOD_position_in_list = 1
		for (var/v in 1 to times_of_day.len)
			if (times_of_day[v] == time_of_day)
				TOD_position_in_list = v

		++TOD_position_in_list
		if (TOD_position_in_list > times_of_day.len)
			TOD_position_in_list = 1

		for (var/v in 1 to times_of_day.len)
			if (v == TOD_position_in_list)
				update_lighting(times_of_day[v], admincaller = caller)

/proc/TOD_loop()
	spawn while (1)
		if (TOD_may_automatically_change)
			TOD_may_automatically_change = FALSE
			progress_time_of_day()
		sleep (100)

/proc/clock_time()
	if (game_hour > 780)
		game_hour -= 720
	var/hr = Floor(game_hour/60)
	var/min = game_hour-hr
	if (min >= 60)
		min -= 60
	var/ampm = "AM"
	switch(time_of_day)
		if ("Early Morning") //03-07
			hr+=3
			ampm = "AM"
		if ("Morning") //07-11
			hr+=7
			ampm = "AM"
		if ("Midday") //11-15
			hr+=11
			if (hr<12)
				ampm = "AM"
			else
				ampm = "PM"
			if (hr>=13)
				hr -= 12
		if ("Afternoon") //15-19
			ampm = "PM"
			hr+=3
		if ("Evening") //19-23
			hr+=7
			ampm = "PM"
		if ("Night") //23-03
			hr+=11
			if (hr<12)
				ampm = "PM"
			else
				ampm = "AM"
			if (hr>=12)
				hr -= 12
	var/str_min = "[min]"
	var/str_hr = "[hr]"
	if (min < 10)
		str_min = "0[min]"
	if (hr < 10)
		str_hr = "0[hr]"
	return "[str_hr]:[str_min] [ampm]"
#undef MAX_LIGHT_AMOUNT
#undef BASIC_LIGHT_AMOUNT