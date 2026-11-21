// The world calendar (docs/world-calendar.md).
//
// Every region is its own world, so each used to keep its own clock and its
// own season timer, counted from its own boot and save. Regions with a
// world_longitude now read both from the real clock (UTC) instead, so all of
// them agree and stay in step through restarts and handovers, with no
// messages between servers:
//
// - Time of day: a game day is 2 real hours (six 20-minute phases), and every
//   region shows the same moment moved by its time zone, one hour per 15
//   degrees of longitude. Real midnight UTC is game midnight at longitude 0.
// - Seasons: each season lasts config.season_duration_minutes (60 by
//   default). Southern regions (sun_latitude below 0) have the opposite
//   season. The world still steps through its ordinary season transitions
//   (terrain, water, plants), one at a time, until it matches the calendar.
//
// Admin "Change Time of Day" and "Change the Season" still work; they hold
// until the calendar's next phase or season, then the world resyncs.

#define WORLD_CALENDAR_DAY_MINUTES 120 // real minutes in a game day
#define WORLD_CALENDAR_PHASE_MINUTES 240 // game minutes in a time of day phase
#define WORLD_CALENDAR_RESYNC 300 // ds between season catch-up requests

/obj/map_metadata
	// Degrees east (+) or west (-). Null keeps this map's own clock and seasons.
	var/world_longitude = null

// Map data, not world state: never saved.
/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "world_longitude")
		return TRUE
	return ..(key)

var/global/list/world_calendar_phases = list("Early Morning", "Morning", "Midday", "Afternoon", "Evening", "Night")
var/global/list/world_calendar_seasons = list(SEASON_SPRING, SEASON_SUMMER, SEASON_FALL, SEASON_WINTER)
// list(days since 2000, deciseconds into the UTC day): probes set it.
var/global/world_calendar_test_now = null
var/global/world_calendar_tod_hold = 0 // world.time an admin-set time of day stands until
var/global/world_calendar_season_hold = 0 // world.time an admin-set season stands until
var/global/world_calendar_season_requested = 0

/proc/world_calendar_fmod(x, m)
	return x - round(x / m) * m

// TRUE when this world follows the shared calendar.
/proc/world_calendar_synced()
	return map && isnum(map.world_longitude)

/proc/world_calendar_daynight()
	if (!world_calendar_synced() || !config || !config.daynight_on || map.no_time_of_day_cycle)
		return FALSE
	var/list/phases = map.times_of_day
	if (!islist(phases) || phases.len != world_calendar_phases.len)
		return FALSE
	for (var/i = 1 to phases.len)
		if (phases[i] != world_calendar_phases[i])
			return FALSE
	return TRUE

/proc/world_calendar_seasons_on()
	return world_calendar_synced() && config && config.seasons_on && isnull(map.season_cycle) && !map.season_retired

// list(days since 2000, deciseconds into the UTC day). world.realtime is a
// float too coarse for minutes, so the time of day comes from world.timeofday
// moved to UTC, and realtime only picks the day.
/proc/world_calendar_now()
	if (islist(world_calendar_test_now))
		return world_calendar_test_now
	var/tod = world.timeofday - round(world.timezone * 36000)
	tod = world_calendar_fmod(tod, 864000)
	var/day = round(world.realtime / 864000)
	var/approx = world.realtime - day * 864000
	if (tod - approx > 432000)
		day--
	else if (approx - tod > 432000)
		day++
	return list(day, tod)

// Real minutes since the calendar's start, modulo span (whole minutes).
/proc/world_calendar_minutes_mod(span)
	var/list/now = world_calendar_now()
	var/day_part = world_calendar_fmod(world_calendar_fmod(now[1], span) * world_calendar_fmod(1440, span), span)
	return world_calendar_fmod(day_part + now[2] / 600, span)

// Whole hours this longitude is ahead of UTC.
/proc/world_calendar_zone(longitude)
	return round(longitude / 15 + 0.5)

// Game minute of the local day, 0 to 1440.
/proc/world_calendar_local_minute(longitude)
	var/game = world_calendar_minutes_mod(WORLD_CALENDAR_DAY_MINUTES) * (1440 / WORLD_CALENDAR_DAY_MINUTES)
	return world_calendar_fmod(game + world_calendar_zone(longitude) * 60, 1440)

// list(phase, game minutes into it) for a game minute of the day. Night runs
// 23:00 to 03:00, as clock_time() reads it.
/proc/world_calendar_phase_at(minute)
	var/since = world_calendar_fmod(minute - 180, 1440)
	var/index = clamp(round(since / WORLD_CALENDAR_PHASE_MINUTES) + 1, 1, world_calendar_phases.len)
	return list(world_calendar_phases[index], since - (index - 1) * WORLD_CALENDAR_PHASE_MINUTES)

/proc/world_calendar_phase(longitude = null)
	if (isnull(longitude))
		longitude = map ? map.world_longitude : 0
	var/list/p = world_calendar_phase_at(world_calendar_local_minute(longitude))
	return p[1]

/proc/world_calendar_season_minutes()
	var/minutes = config ? config.season_duration_minutes : 60
	if (!isnum(minutes) || minutes < 1 || minutes > 1440)
		minutes = 60
	return round(minutes)

// list(season, real minutes into it, real minutes left) for a hemisphere
// (1 north, -1 south).
/proc/world_calendar_season(hemisphere = null)
	if (isnull(hemisphere))
		hemisphere = (map && isnum(map.sun_latitude) && map.sun_latitude < 0) ? -1 : 1
	var/length = world_calendar_season_minutes()
	var/pos = world_calendar_minutes_mod(length * 4)
	var/index = clamp(round(pos / length), 0, 3)
	var/elapsed = pos - index * length
	if (hemisphere < 0)
		index = (index + 2) % 4
	return list(world_calendar_seasons[index + 1], elapsed, length - elapsed)

// Deciseconds until the calendar's next time of day phase here.
/proc/world_calendar_phase_left()
	var/list/p = world_calendar_phase_at(world_calendar_local_minute(map.world_longitude))
	return round((WORLD_CALENDAR_PHASE_MINUTES - p[2]) * 600 / (1440 / WORLD_CALENDAR_DAY_MINUTES)) + 10

// TRUE when the world should step its season toward the calendar now.
/proc/world_calendar_season_due()
	if (!world_calendar_seasons_on() || world.time < world_calendar_season_hold || persistence_save_in_progress)
		return FALSE
	if (!(season in world_calendar_seasons) || map.season_busy)
		return FALSE
	for (var/i = 1, i <= map.season_queue.len, i += 4)
		if (map.season_queue[i] == "transition")
			return FALSE
	var/list/c = world_calendar_season()
	return c[1] != season

// The time of day process calls this every 10 s. TRUE when the calendar
// drives this world's day.
/proc/world_calendar_tick()
	if (!world_calendar_synced())
		return FALSE
	if (world.time >= world_calendar_season_requested + WORLD_CALENDAR_RESYNC && world_calendar_season_due())
		world_calendar_season_requested = world.time
		map.seasons(FALSE)
	if (!world_calendar_daynight())
		return FALSE
	world_calendar_set_clock()
	if (world.time >= world_calendar_tod_hold && !(processes && processes.time_of_day_change && processes.time_of_day_change.updating_lighting))
		if (world_calendar_phase() != time_of_day)
			TOD_may_automatically_change = TRUE
	return TRUE

// Puts game_hour (minutes into the phase) and the phase timer on the calendar.
/proc/world_calendar_set_clock()
	var/list/p = world_calendar_phase_at(world_calendar_local_minute(map.world_longitude))
	game_hour = round(p[2])
	if (processes && processes.time_of_day)
		processes.time_of_day.TOD_ticks = round(p[2] * 60 / (1440 / WORLD_CALENDAR_DAY_MINUTES))

// A restored world takes the calendar's time of day before its daylight is
// applied, rather than the saved one.
/proc/world_calendar_restore()
	if (!world_calendar_daynight())
		return
	time_of_day = world_calendar_phase()
	world_calendar_set_clock()
	TOD_may_automatically_change = FALSE

// "Local time is 3 hours behind Gaia" style line for status and admin tools.
/proc/world_calendar_summary()
	if (!world_calendar_synced())
		return null
	var/zone = world_calendar_zone(map.world_longitude)
	var/list/c = world_calendar_season()
	return "UTC[zone >= 0 ? "+" : ""][zone], [time_of_day], [capitalize(lowertext(c[1]))] ([round(c[3])] min left)"

#undef WORLD_CALENDAR_DAY_MINUTES
#undef WORLD_CALENDAR_PHASE_MINUTES
#undef WORLD_CALENDAR_RESYNC
