#define TimeOfGame (get_game_time())
#define TimeOfTick (world.tick_usage*0.01*world.tick_lag)

var/midnight_rollovers = 0
var/rollovercheck_last_timeofday = 0

#define REALTIMEOFDAY (world.timeofday + (864000 * MIDNIGHT_ROLLOVER_CHECK))
#define MIDNIGHT_ROLLOVER_CHECK ( rollovercheck_last_timeofday != world.timeofday ? update_midnight_rollover() : midnight_rollovers )

/proc/update_midnight_rollover()
	if(world.timeofday < rollovercheck_last_timeofday)
		midnight_rollovers++

	rollovercheck_last_timeofday = world.timeofday
	return midnight_rollovers

/proc/get_game_time()
	var/global/time_offset = 0
	var/global/last_time = 0
	var/global/last_usage = 0

	var/wtime = world.time
	var/wusage = world.tick_usage * 0.01

	if (last_time < wtime && last_usage > 1)
		time_offset += last_usage - 1

	last_time = wtime
	last_usage = wusage

	return wtime + (time_offset + wusage) * world.tick_lag

var/roundstart_hour = 0
var/station_date = ""
var/next_station_date_change = 1 DAYS

#define roundduration2text_in_ticks (round_start_time ? world.time - round_start_time : 0)
#define station_time_in_ticks (roundstart_hour HOURS + roundduration2text_in_ticks)

/proc/stationtime2text()
	if (!roundstart_hour) roundstart_hour = pick(2,7,12,17)
	return time2text(station_time_in_ticks, "hh:mm")

/proc/stationdate2text()
	var/update_time = FALSE
	if (station_time_in_ticks > next_station_date_change)
		next_station_date_change += 1 DAYS
		update_time = TRUE
	if (!station_date || update_time)
		var/extra_days = round(station_time_in_ticks / (1 DAYS)) DAYS
		var/timeofday = world.timeofday + extra_days
		station_date = num2text((text2num(time2text(timeofday, "YYYY"))+544)) + "-" + time2text(timeofday, "MM-DD")
	return station_date

/proc/time_stamp()
	return time2text(world.timeofday, "hh:mm:ss")

/* Returns TRUE if it is the selected month and day */
proc/isDay(var/month, var/day)
	if (isnum(month) && isnum(day))
		var/MM = text2num(time2text(world.timeofday, "MM")) // get the current month
		var/DD = text2num(time2text(world.timeofday, "DD")) // get the current day
		if (month == MM && day == DD)
			return TRUE

		// Uncomment this out when debugging!
		//else
			//return TRUE

var/next_duration_update = 0
var/next_duration_update_days= 0
var/last_roundduration2text = 0
var/last_roundduration2text_days = 0
var/round_start_time = 0

/hook/roundstart/proc/start_timer()
	round_start_time = world.time
	return TRUE

/proc/roundduration2text()
	if (!round_start_time)
		return "00:00"
	if (last_roundduration2text && world.time < next_duration_update)
		return last_roundduration2text

	var/mills = roundduration2text_in_ticks // 1/10 of a second, not real milliseconds but whatever
	//var/secs = ((mills % 36000) % 600) / 10 //Not really needed, but I'll leave it here for refrence.. or something
	var/mins = round((mills % 36000) / 600)
	var/hours = round(mills / 36000)

	mins = mins < 10 ? add_zero(mins, TRUE) : mins
	hours = hours < 10 ? add_zero(hours, TRUE) : hours

	last_roundduration2text = "[hours]:[mins]"
	next_duration_update = world.time + 1 MINUTES
	return last_roundduration2text

/proc/roundduration2text_days()
	if (!round_start_time)
		return "0 mins"

	if (last_roundduration2text_days && world.time < next_duration_update_days)
		return last_roundduration2text_days

	var/mills = roundduration2text_in_ticks // 1/10 of a second, not real milliseconds but whatever
	var/mins = round((mills % 36000) / 600)
	var/hours = round(mills / 36000)
	if (hours >= 24)
		var/t_hours = Floor(hours/24)
		hours = hours - (t_hours*24)
	var/days = round(hours/24)
	if (hours >=1 && days >= 1)
		last_roundduration2text_days = "[days] day[days >= 2 ? "s" : ""], [hours] hour[hours >= 2 ? "s" : ""], [mins] min[mins >= 2 ? "s" : ""]"
	else if (hours >=1 && days < 1)
		last_roundduration2text_days = "[hours] hour[hours >= 2 ? "s" : ""], [mins] min[mins >= 2 ? "s" : ""]"
	else
		last_roundduration2text_days = "[mins] min[mins >= 2 ? "s" : ""]"
	next_duration_update_days = world.time + 1 MINUTES
	return last_roundduration2text_days

//Can be useful for things dependent on process timing
/proc/process_schedule_interval(var/process_name)
	var/process/process = processScheduler.getProcess(process_name)
	return process.schedule_interval

//Returns the world time in english
/proc/worldtime2text(time = world.time)
	return "[round(time / 36000)+12]:[(time / 600 % 60) < 10 ? add_zero(time / 600 % 60, 1) : time / 600 % 60]"