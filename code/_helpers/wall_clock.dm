// Wall-clock jumps after the host freezes the server.
//
// scripts/gaia-host can suspend dd.exe while nobody is online and resume it
// when someone connects. BYOND does not replay missed ticks: world.time picks
// up exactly where it stopped, so the simulation simply paused. world.timeofday
// and world.realtime, however, have moved on by the whole frozen period, which
// may be hours or days. A host sleep/hibernate or a VM pause looks the same.
//
// world.realtime is a float that is only accurate to about 51 seconds today,
// and world.timeofday is precise but wraps every day, so elapsed wall time is
// timeofday's difference plus the whole days that realtime says passed.

// Wall time that ran ahead of world.time within one one-second sample before
// the gap counts as a freeze rather than server lag.
#define WALL_CLOCK_JUMP_THRESHOLD 600

var/global/wall_clock_last_timeofday = null
var/global/wall_clock_last_realtime = 0
var/global/wall_clock_last_world_time = 0
var/global/wall_clock_jumps = 0
var/global/wall_clock_frozen_total = 0
var/global/wall_clock_watch_started = FALSE

// Deciseconds of wall time between two (timeofday, realtime) readings.
/proc/wall_clock_elapsed(old_timeofday, old_realtime, new_timeofday, new_realtime)
	var/delta_timeofday = new_timeofday - old_timeofday
	var/days = round((new_realtime - old_realtime - delta_timeofday) / 864000 + 0.5)
	return delta_timeofday + days * 864000

/proc/start_wall_clock_watch()
	set waitfor = FALSE
	if (wall_clock_watch_started)
		return
	wall_clock_watch_started = TRUE
	wall_clock_sample()
	while (TRUE)
		sleep(10)
		wall_clock_sample()

// Returns how far wall time ran ahead of world.time since the last sample.
/proc/wall_clock_sample(now_timeofday = world.timeofday, now_realtime = world.realtime, now_world_time = world.time)
	if (isnull(wall_clock_last_timeofday))
		wall_clock_last_timeofday = now_timeofday
		wall_clock_last_realtime = now_realtime
		wall_clock_last_world_time = now_world_time
		return 0
	var/wall = wall_clock_elapsed(wall_clock_last_timeofday, wall_clock_last_realtime, now_timeofday, now_realtime)
	var/gap = wall - (now_world_time - wall_clock_last_world_time)
	wall_clock_last_timeofday = now_timeofday
	wall_clock_last_realtime = now_realtime
	wall_clock_last_world_time = now_world_time
	if (gap >= WALL_CLOCK_JUMP_THRESHOLD)
		wall_clock_resumed(gap)
	return gap

// The world was paused for gap deciseconds of wall time. Schedules that count
// the world's own running time move forward by the gap; real-world cooldowns
// (bans, respawn and faction timers) deliberately keep counting.
/proc/wall_clock_resumed(gap)
	wall_clock_jumps++
	wall_clock_frozen_total += gap
	log_world("Wall clock ran [round(gap / 10)] seconds ahead of world.time; the server was suspended or stalled. Shifting wall-clock schedules.")
	// The periodic save counts world activity; a frozen world changed nothing.
	if (nextsave)
		nextsave += gap
	if (Master)
		Master.init_timeofday += gap
		Master.tickdrift = 0
	if (processes)
		if (processes.time_track)
			processes.time_track.first_run = TRUE
		if (processes.ticker)
			processes.ticker.lastTickerTime = world.timeofday
