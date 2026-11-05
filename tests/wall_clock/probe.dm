// Fixture probe for code/_helpers/wall_clock.dm and the midnight rollover in
// code/_helpers/time.dm. Stubs stand in for the globals the shift touches.
var/nextsave = 0
/datum/controller/master
	var/init_timeofday = 0
	var/tickdrift = 0
var/datum/controller/master/Master = new
/process/time_track
	var/first_run = FALSE
/process/ticker
	var/lastTickerTime = 0
/datum/process_list
	var/process/time_track/time_track = new
	var/process/ticker/ticker = new
var/datum/process_list/processes = new
var/list/wall_clock_probe_log = list()
/proc/log_world(text)
	wall_clock_probe_log += text
	world.log << text

var/wall_clock_probe_failures = 0
/proc/wall_clock_expect(name, actual, expected)
	if (actual != expected)
		wall_clock_probe_failures++
		world.log << "FAIL: [name]: expected [expected], got [actual]"
	else
		world.log << "ok: [name]"

// world.realtime is a float with about 51 s of resolution at today's values.
/proc/wall_clock_coarse(value)
	return round(value / 512) * 512

/world/New()
	..()
	if (world.params["live"])
		start_wall_clock_watch()
		world.log << "LIVE: watching"
		return
	var/R = 8471732224
	// Three days and two hours frozen, starting at 22:13.
	var/frozen = 3 * 864000 + 72000
	var/new_tod = (800000 + frozen) % 864000
	var/new_real = wall_clock_coarse(R + frozen)
	wall_clock_expect("elapsed over days", wall_clock_elapsed(800000, R, new_tod, new_real), frozen)
	wall_clock_expect("elapsed over one midnight", wall_clock_elapsed(863995, R, 5, R), 10)
	wall_clock_expect("elapsed within a day", wall_clock_elapsed(1000, R, 1600, R + 512), 600)

	midnight_rollovers = 0
	rollovercheck_last_timeofday = 800000
	rollovercheck_last_realtime = R
	wall_clock_expect("rollovers after a multi-day freeze", update_midnight_rollover(new_tod, new_real), 4)
	wall_clock_expect("REALTIMEOFDAY advanced by the freeze", new_tod + 864000 * midnight_rollovers - 800000, frozen)
	midnight_rollovers = 0
	rollovercheck_last_timeofday = 863995
	rollovercheck_last_realtime = R
	wall_clock_expect("ordinary midnight rollover", update_midnight_rollover(5, R), 1)
	rollovercheck_last_timeofday = 1000
	rollovercheck_last_realtime = R
	wall_clock_expect("no rollover within a day", update_midnight_rollover(2000, R), 1)

	nextsave = R + 216000
	Master.init_timeofday = 5000
	Master.tickdrift = 999
	wall_clock_sample(800000, R, 100)
	wall_clock_expect("lag below threshold ignored", wall_clock_sample(800300, R, 100) < WALL_CLOCK_JUMP_THRESHOLD && !wall_clock_jumps, TRUE)
	var/gap = wall_clock_sample(new_tod, new_real, 110)
	wall_clock_expect("freeze gap", gap, frozen - 300 - 10)
	wall_clock_expect("freeze counted", wall_clock_jumps, 1)
	wall_clock_expect("autosave shifted", nextsave, R + 216000 + gap)
	wall_clock_expect("MC baseline shifted", Master.init_timeofday, 5000 + gap)
	wall_clock_expect("MC drift reset", Master.tickdrift, 0)
	wall_clock_expect("dilation sample skipped", processes.time_track.first_run, TRUE)
	wall_clock_expect("freeze logged", length(wall_clock_probe_log), 1)
	world.log << (wall_clock_probe_failures ? "RESULT: FAIL" : "RESULT: PASS")
	shutdown()
