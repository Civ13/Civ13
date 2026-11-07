// Read-only status text. TOD_ticks and time_of_day2ticks are seconds, unlike
// world.time. Use the process counter, not a new wall-clock deadline, so a
// delayed process or restored world does not claim progress that never ran.
/process/time_of_day/proc/progress_text()
	if (!config || !config.daynight_on || !roundstart_time || !TOD_loop_started || persistence_save_in_progress)
		return null
	if (disabled || paused || killed || !main || !main.isRunning || !may_fire())
		return null
	if (!isnum(schedule_interval) || schedule_interval <= 0)
		return null
	if (!map || !islist(map.times_of_day) || map.times_of_day.len < 2 || !islist(times_of_day) || times_of_day.len < 2)
		return null
	// Match progress_time_of_day's last matching position and wrap, including
	// a custom/restored global cycle rather than the default six phase names.
	var/position = 0
	for (var/i = 1 to times_of_day.len)
		if (times_of_day[i] == time_of_day)
			position = i
	if (!position)
		return null
	var/next_phase = times_of_day[(position % times_of_day.len) + 1]
	if (!istext(next_phase) || !length(next_phase) || next_phase == time_of_day)
		return null
	if (!islist(time_of_day2ticks))
		return null
	var/duration = time_of_day2ticks[time_of_day]
	if (!isnum(duration) || duration <= 0 || !isnum(TOD_ticks) || TOD_ticks < 0)
		return null
	// fire() resets TOD_ticks before TOD_loop consumes the transition gate.
	// Do not briefly show a fresh full phase while the old label is still up.
	if (TOD_may_automatically_change || TOD_ticks >= duration)
		return "changing to [next_phase]"
	var/quarter = clamp(round(TOD_ticks / duration * 4) + 1, 1, 4)
	var/remaining = duration - TOD_ticks
	var/time_left = remaining < 60 ? "under a minute" : "~[ceil(remaining / 60)] min"
	return "quarter [quarter]/4, [time_left] until [next_phase]"

/proc/get_time_of_day_with_progress()
	var/text = time_of_day
	if (processes && processes.time_of_day)
		var/progress = processes.time_of_day.progress_text()
		if (progress)
			text += " ([progress])"
	return text
