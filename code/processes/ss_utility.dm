/process/ss_utility
	var/next_ping_track = 0
	var/next_time_track = 0
	var/next_vote = 0
	
/process/ss_utility/setup()
	name = "Utility Subsystem"
	schedule_interval = 10 // 1 second
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.ss_utility = src

/process/ss_utility/fire()
	// Info logic (formerly info.dm)
	// (info.fire was empty, only statProcess had content)
	
	// Time Track logic (formerly time_track.dm)
	if (world.time >= next_time_track)
		do_time_track()
		next_time_track = world.time + 10
		
	// Ping Track logic (formerly ping_track.dm)
	if (world.time >= next_ping_track)
		do_ping_track()
		next_ping_track = world.time + 5
		
	// Vote logic (formerly vote.dm)
	if (world.time >= next_vote)
		if (vote) vote.process()
		next_vote = world.time + 10

	// Client logic (formerly client.dm)
	for (var/client/C in clients)
		C.process()
		PROCESS_TICK_CHECK

/process/ss_utility/proc/do_time_track()
	// Ported from time_track.dm
	var/process/time_track/TT = processes.time_track
	if (TT)
		TT.fire()

/process/ss_utility/proc/do_ping_track()
	// Ported from ping_track.dm
	var/process/ping_track/PT = processes.ping_track
	if (PT)
		PT.fire()

/process/ss_utility/statProcess()
	..()
	stat(null, "Current BYOND tick: #[world.time/world.tick_lag]")
