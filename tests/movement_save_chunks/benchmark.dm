// Synthetic isolated memory fixture. No production files, clients or listeners.
// Includes the production serializer; the only baseline change disables its roster.
world
	maxx = 32
	maxy = 32
	maxz = 1
	fps = 20
	visibility = 0
	sleep_offline = FALSE
var/list/mob_list = list()
var/benchmark_baseline = FALSE
var/benchmark_inject_failure = FALSE
var/benchmark_injected = FALSE
var/benchmark_attempt = 0
var/benchmark_capture_logged = FALSE
var/benchmark_replay_logged = FALSE
var/benchmark_heartbeat_running = FALSE
var/benchmark_heartbeat_gap = 0
var/benchmark_heartbeat_count = 0
var/benchmark_peak_roster = 0
var/benchmark_peak_nodes = 0
var/benchmark_peak_edges = 0
var/benchmark_peak_bytes = 0
var/benchmark_peak_paths = 0
var/benchmark_peak_entry_pins = 0
var/benchmark_peak_list_pins = 0
var/benchmark_peak_tick_usage = 0
/mob/living/simple_animal/memory_benchmark
	var/payload
	New()
		..()
		mob_list += src
	Del()
		mob_list -= src
		..()
	before_save()
		if(benchmark_inject_failure && !benchmark_injected)
			benchmark_injected = TRUE
			throw EXCEPTION("BENCHMARK_INJECTED_CAPTURE_FAILURE")
		return ..()
/map_storage/memory_benchmark/prepare_moving_save_roster()
	if(benchmark_baseline) return
	. = ..()
	benchmark_peak_roster = max(benchmark_peak_roster, moving_save_roots.len)
/map_storage/memory_benchmark/record_save_capture_path(savefile/F, path)
	. = ..()
	if(moving_save_chunk)
		if(!benchmark_capture_logged)
			benchmark_capture_logged = TRUE
			benchmark_phase("capture")
		benchmark_peak_nodes = max(benchmark_peak_nodes, moving_save_chunk.nodes)
		benchmark_peak_edges = max(benchmark_peak_edges, moving_save_chunk.edges)
		benchmark_peak_bytes = max(benchmark_peak_bytes, moving_save_chunk.reserved_bytes)
		benchmark_peak_paths = max(benchmark_peak_paths, moving_save_chunk.paths.len)
		benchmark_peak_tick_usage = max(benchmark_peak_tick_usage, world.tick_usage - moving_save_chunk.start_usage)
/map_storage/memory_benchmark/save_work_check()
	if(benchmark_capture_logged && !moving_save_chunk && !benchmark_replay_logged)
		benchmark_replay_logged = TRUE
		benchmark_phase("replay")
	benchmark_peak_entry_pins = max(benchmark_peak_entry_pins, saving_reference_pins.len)
	benchmark_peak_list_pins = max(benchmark_peak_list_pins, saving_list_pins.len)
	return ..()
/proc/benchmark_phase(phase)
	world.log << "BENCHMARK_PHASE [json_encode(list("phase" = phase, "attempt" = benchmark_attempt, "clock" = world.timeofday, "baseline" = benchmark_baseline, "roster" = benchmark_peak_roster, "nodes" = benchmark_peak_nodes, "edges" = benchmark_peak_edges, "logical_bytes" = benchmark_peak_bytes, "paths" = benchmark_peak_paths, "entry_pins" = benchmark_peak_entry_pins, "list_pins" = benchmark_peak_list_pins, "capture_tick_usage" = benchmark_peak_tick_usage, "heartbeat_gap_ds" = benchmark_heartbeat_gap, "heartbeat_count" = benchmark_heartbeat_count))]"
/proc/benchmark_heartbeat()
	var/previous = world.timeofday
	while(benchmark_heartbeat_running)
		sleep(1)
		var/now = world.timeofday
		benchmark_heartbeat_gap = max(benchmark_heartbeat_gap, (now - previous + 864000) % 864000)
		benchmark_heartbeat_count++
		previous = now
/proc/benchmark_manifest(directory)
	var/list/result = list()
	for(var/name in flist(directory))
		if(name == "map.txt" || name == "round.json" || name == "save_complete.txt" || copytext(name, max(1, length(name)-3)) == ".sav")
			result[name] = md5(file("[directory][name]"))
	return result
/proc/benchmark_verify_backup(list/expected)
	var/list/current = benchmark_manifest("map_backups/")
	if(current.len != expected.len) throw EXCEPTION("Benchmark backup membership changed")
	for(var/name in expected)
		if(current[name] != expected[name]) throw EXCEPTION("Benchmark backup bytes changed: [name]")
/world/OpenPort(port)
	return ..("none")
/world/New()
	OpenPort("none")
	..()
	try
		var/count = text2num(world.params["count"])
		var/payload_bytes = text2num(world.params["payload"])
		if(!(count in list(64, 512, 2048, 8193)) || !(payload_bytes in list(128, 1024, 16384, 65536)) || count * payload_bytes > 134217728)
			throw EXCEPTION("Benchmark workload outside approved bounds")
		benchmark_baseline = world.params["baseline"] == "1"
		map_storage = new /map_storage/memory_benchmark
		map = new /obj/map_metadata(locate(1,1,1))
		benchmark_phase("before_construction")
		var/text = "0123456789abcdef"
		while(length(text) < payload_bytes) text += text
		for(var/i = 1, i <= count, i++)
			var/mob/living/simple_animal/memory_benchmark/A = new(locate(1 + ((i-1) % 32), 1 + (round((i-1)/32) % 32), 1))
			A.name = "benchmark animal [i]"
			var/suffix = "-[i]"
			A.payload = "[copytext(text, 1, payload_bytes - length(suffix) + 1)][suffix]"
			if(i % 64 == 0) sleep(0)
		benchmark_phase("after_construction")
		benchmark_heartbeat_running = TRUE
		spawn(0) benchmark_heartbeat()
		var/list/last_good
		for(benchmark_attempt = 1, benchmark_attempt <= 7, benchmark_attempt++)
			benchmark_inject_failure = benchmark_attempt >= 4 && benchmark_attempt <= 6
			benchmark_injected = FALSE
			benchmark_capture_logged = FALSE
			benchmark_replay_logged = FALSE
			benchmark_phase("before_save")
			var/refused = FALSE
			try
				if(!map_storage.Save_World()) throw EXCEPTION("Benchmark save returned false")
			catch(var/exception/error)
				if(!benchmark_inject_failure || !findtext("[error]", "BENCHMARK_INJECTED_CAPTURE_FAILURE")) throw error
				refused = TRUE
			if(refused != benchmark_inject_failure || (benchmark_inject_failure && !benchmark_injected)) throw EXCEPTION("Benchmark failure injection was not observed")
			if(map_storage.moving_save_chunk || map_storage.moving_save_roots.len || map_storage.saving_reference_pins.len || map_storage.saving_list_pins.len || persistence_save_in_progress)
				throw EXCEPTION("Benchmark attempt retained live capture ownership")
			if(refused)
				if(fexists("map_saves/save_complete.txt")) throw EXCEPTION("Benchmark failed attempt published a marker")
				benchmark_verify_backup(last_good)
			else
				if(!fexists("map_saves/save_complete.txt")) throw EXCEPTION("Benchmark successful attempt has no marker")
				last_good = benchmark_manifest("map_saves/")
			benchmark_phase(refused ? "after_refusal_cleanup" : "after_success_cleanup")
			sleep(10)
			benchmark_phase("after_idle")
		benchmark_heartbeat_running = FALSE
		benchmark_phase("complete")
		text2file("PASS", "result.txt")
	catch(var/exception/error)
		benchmark_heartbeat_running = FALSE
		world.log << "FAIL: [error] ([error.file]:[error.line])"
		text2file("FAIL", "result.txt")
	del(world)
