// Proc profiling. If config/profile-dump.txt exists at startup, BYOND's profiler
// runs from boot and writes a JSON snapshot to data/profile/ every
// profile_dump_interval. Debug admins can also start, stop or snapshot it in game
// (Debug > Profiler). Snapshots are cumulative since the profiler was started.
var/global/profile_dump_interval = 6000 // deciseconds (10 minutes)
var/global/profile_dump_running = FALSE

/proc/profile_dump_write()
	var/snapshot = world.Profile(PROFILE_REFRESH, null, "json")
	if (!snapshot)
		return null
	var/path = "data/profile/[time2text(world.realtime, "YYYYMMDD-hhmmss")].json"
	text2file(snapshot, path)
	return path

/hook/startup/proc/start_profile_dump()
	if (!fexists("config/profile-dump.txt"))
		return TRUE
	world.Profile(PROFILE_START)
	profile_dump_running = TRUE
	world.log << "PROFILE_DUMP enabled: snapshot every [profile_dump_interval / 10]s to data/profile/"
	spawn(profile_dump_interval)
		while (profile_dump_running)
			profile_dump_write()
			sleep(profile_dump_interval)
	return TRUE

/client/proc/profile_dump()
	set category = "Debug"
	set name = "Profiler"
	set desc = "Start, stop or snapshot BYOND's proc profiler to data/profile/."
	if (!check_rights(R_DEBUG))
		return
	var/choice = WWinput(usr, "The profiler is [profile_dump_running ? "running" : "stopped"].", "Profiler", "Cancel", list("Start", "Snapshot", "Stop", "Cancel"))
	switch (choice)
		if ("Start")
			world.Profile(PROFILE_START)
			profile_dump_running = TRUE
			message_admins("[key_name(usr)] started the proc profiler.")
		if ("Snapshot")
			var/path = profile_dump_write()
			to_chat(usr, path ? "Profiler snapshot written to [path]." : "The profiler returned no data; start it first.")
		if ("Stop")
			var/path = profile_dump_write()
			world.Profile(PROFILE_STOP)
			profile_dump_running = FALSE
			message_admins("[key_name(usr)] stopped the proc profiler[path ? "; final snapshot [path]" : ""].")
