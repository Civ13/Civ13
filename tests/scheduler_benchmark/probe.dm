#define TRUE 1
#define FALSE 0
var/failures = 0
/processScheduler
	var/list/last_twenty_run_times = list()
/process
	var/processScheduler/main
	var/schedule_interval = 10
	var/runtime_history_reset_at = 0
/world
	fps = 10
/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE
/world/Error(exception/E)
	world.log << "RUNTIME [E]"
	failures++
/world/New()
	OpenPort("none")
	spawn(0)
		var/list/params = params2list(world.params)
		var/count = text2num(params["count"])
		var/healthy = text2num(params["healthy"])
		var/processScheduler/S = new
		var/process/P = new
		P.main = S
		S.last_twenty_run_times[P] = list(healthy ? 0.001 : 20)
		var/accepted = 0
		var/start = world.timeofday
		for (var/i in 1 to count)
			accepted += P.may_run(10)
		var/admission_elapsed = world.timeofday - start
		if (admission_elapsed < 0) admission_elapsed += 864000
		if (accepted != (healthy ? count : 0)) failures++
		text2file(json_encode(list("phase"="pending", "count"=count, "healthy"=healthy)), "pending.json")
		sleep(12)
		if (!P.may_run(10)) failures++
		var/list/history = S.last_twenty_run_times[P]
		if (history.len != (healthy ? 1 : 0)) failures++
		if (world.port || world.OpenPort(12345)) failures++
		text2file(json_encode(list("count"=count, "healthy"=healthy, "accepted"=accepted, "admission_deciseconds"=admission_elapsed, "failures"=failures)), "result.json")
		// Keep the completed process alive for separate settled OS-memory samples.
		sleep(5)
		del(world)
