// Player-facing season progress: how far into the current season the world is
// and roughly how long until the next change. Read-only; it never schedules,
// cancels or alters a season transition.
/obj/map_metadata
	var/tmp/season_change_started = 0 // world.time the current season timer began
	var/tmp/season_change_due = 0 // world.time the next season change is expected

// Call wherever a season change is scheduled, with the same delay as the timer.
/obj/map_metadata/proc/season_note_next_change(var/delay)
	if (!isnum(delay) || delay <= 0)
		return
	season_change_started = world.time
	season_change_due = world.time + delay

// Returns list(started, due) in world.time, or null when no change is known.
/obj/map_metadata/proc/season_change_window()
	var/started = season_change_started
	var/due = season_change_due
	// Durable maps keep the authoritative deadline in the timer queue, which
	// survives a world save/load even though the tmp vars above do not.
	if (durable_callbacks && islist(durable_callbacks.pending["season_loop"]))
		var/list/row = durable_callbacks.pending["season_loop"]
		var/deadline = row["deadline"]
		if (isnum(deadline) && deadline != due)
			due = deadline
			started = min(world.time, due - season_loop_delay())
	if (due <= world.time || due <= started)
		return null
	return list(started, due)

/obj/map_metadata/proc/season_progress_text()
	if (season_retired || !config || !config.seasons_on)
		return null
	var/list/window = season_change_window()
	if (!window)
		return null
	var/started = window[1]
	var/due = window[2]
	var/fraction = (world.time - started) / (due - started)
	var/quarter = clamp(round(fraction * 4) + 1, 1, 4)
	var/remaining = due - world.time
	var/time_left = remaining < 600 ? "under a minute" : "~[ceil(remaining / 600)] min"
	return "quarter [quarter]/4, [time_left] until it changes"

/proc/get_season_with_progress()
	var/text = get_season()
	if (map)
		var/progress = map.season_progress_text()
		if (progress)
			text += " ([progress])"
	return text
