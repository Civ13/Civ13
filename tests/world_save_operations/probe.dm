// Production admission/wrapper code; storage adapters expose callback boundaries.
world
	sleep_offline = FALSE
	maxx = 2
	maxy = 2
	maxz = 1
	turf = /turf/floor/dirt
	New()
		..()
		OpenPort("none")
		spawn(0) run_probe()
	Error(exception/E)
		file("unexpected.txt") << "[E] [E.file]:[E.line]"
		shutdown()
	OpenPort(port)
		return port == "none" ? ..("none") : 0

var/checks = 0
var/probe_failure
var/datum/operation_job_adapter/job_master = new
/datum/operation_job_adapter/proc/initialize_position_limits()
	return
/proc/check(condition, label)
	checks++
	if(!condition && !probe_failure)
		probe_failure = label
		text2file(label, "failure.txt")
		text2file("FAIL", "result.txt")
		text2file("[checks]", "checks.txt")
		shutdown()

/map_storage/operation_probe
	var/entries = 0
	var/clears = 0
	var/mode = "ok"
	var/preflight_callback = FALSE
	var/backend_callback = FALSE
	var/finish_callback = FALSE
	var/cleanup_failure = FALSE
	var/result = TRUE
	prepare_saved_dimensions()
		if(preflight_callback) overlap("preflight")
		if(mode == "preflight-throw") throw EXCEPTION("expected preflight")
		return mode != "preflight-false"
	validate_world_save()
		return TRUE
	read_round_state()
		return list("generation" = "probe")
	ClearMap()
		clears++
	load_map_metadata()
		return TRUE
	restore_round_state(datum/controller/gameticker/T, list/state)
		return
	finish_player_restoration()
		if(finish_callback) overlap("client callback")
	clear_bookkeeping()
		if(cleanup_failure) throw EXCEPTION("expected cleanup")
		return ..()
	save_world_contents(datum/persistence_world_operation/operation)
		return backend(operation, "save")
	load_world_contents(datum/persistence_world_operation/operation)
		return backend(operation, "load")
	proc/backend(datum/persistence_world_operation/operation, kind)
		if(!operation || !operation.enter_contents(src, kind)) return FALSE
		entries++
		if(backend_callback)
			overlap("backend callback")
			sleep(1)
			overlap("backend resumed")
		if(mode == "backend-throw") throw EXCEPTION("expected backend")
		return result
	proc/overlap(label)
		var/before_entries = entries
		var/before_clears = clears
		var/datum/persistence_world_operation/owner = persistence_active_operation
		check(!ticker.savemap(), "[label]: wrapper save rejected")
		check(!ticker.loadmap(), "[label]: wrapper load rejected")
		check(!Save_World(), "[label]: direct save rejected")
		check(!Load_World(), "[label]: direct load rejected")
		if(owner.backend_started)
			check(!run_world_operation(owner.kind, owner), "[label]: repeated backend rejected")
		check(entries == before_entries && clears == before_clears, "[label]: no rejected mutation")
		check(persistence_active_operation == owner, "[label]: owner retained")

/proc/fresh_probe()
	// Models a fresh process only between failure scenarios; no production reset API.
	persistence_active_operation = null
	persistence_load_recovery_required = FALSE
	persistence_save_in_progress = FALSE
	persistence_restart.startup_hold = FALSE
	persistence_restart.busy = FALSE
	map_storage = new /map_storage/operation_probe
	return map_storage

/proc/check_idle(label)
	check(!persistence_active_operation && !persistence_save_in_progress && !persistence_load_recovery_required, label)

/proc/run_probe()
	ticker = new
	var/map_storage/operation_probe/S = fresh_probe()
	// The real wrapper sleeps before calling its backend. Race all public paths.
	var/save_done = FALSE
	spawn(0)
		check(ticker.savemap(), "yielding save succeeds")
		save_done = TRUE
	sleep(1)
	check(persistence_active_operation != null, "save acquired before announcement sleep")
	S.overlap("announcement sleep")
	while(!save_done) sleep(1)
	check_idle("save completion releases")
	S.backend_callback = TRUE
	check(S.Save_World(), "direct save callback completes")
	check(S.Load_World(), "direct load callback completes")
	check_idle("direct completion releases")
	S.preflight_callback = TRUE
	S.finish_callback = TRUE
	check(ticker.loadmap(), "load callbacks complete")
	check_idle("load completion releases")

	// An old completion cannot unlock the next operation.
	var/datum/persistence_world_operation/old = begin_persistence_operation(S, "save")
	check(old.finish(TRUE), "first operation finishes")
	var/datum/persistence_world_operation/current = begin_persistence_operation(S, "load")
	check(!old.finish(TRUE), "stale finish rejected")
	check(persistence_active_operation == current && persistence_save_in_progress, "stale finish retains newer lock")
	current.finish(TRUE)

	for(var/fault in list("preflight-false", "preflight-throw"))
		S = fresh_probe()
		S.mode = fault
		check(!ticker.loadmap(), "[fault] rejected")
		check(!S.clears && !S.entries, "[fault] no mutation")
		check_idle("[fault] releases admission")
	S = fresh_probe()
	S.mode = "backend-throw"
	S.cleanup_failure = TRUE
	check(!ticker.savemap(), "failed save handled")
	check_idle("failed save releases after cleanup exception")
	for(var/direct in list(FALSE, TRUE))
		S = fresh_probe()
		S.mode = "backend-throw"
		S.cleanup_failure = TRUE
		try
			if(direct) S.Load_World()
			else ticker.loadmap()
		catch(var/exception/E)
			check(direct && E.name == "expected backend", "only direct backend rethrows")
		check(persistence_load_recovery_required && persistence_save_in_progress && !persistence_active_operation, "mutating failure retains recovery hold")
		check(!ticker.savemap() && !ticker.loadmap() && !S.Save_World() && !S.Load_World(), "recovery hold rejects all entry points")
	S = fresh_probe()
	S.result = FALSE
	check(!S.Load_World(), "false backend rejected")
	check(persistence_load_recovery_required, "false mutating backend retains recovery hold")

	// Startup recovery keeps the legacy busy flag while handing off its identity.
	S = fresh_probe()
	persistence_restart.startup_hold = TRUE
	persistence_restart.busy = TRUE
	persistence_restart.expected_generation = "probe"
	persistence_save_in_progress = TRUE
	check(!ticker.loadmap() && !S.Load_World(), "startup rejects unrelated load")
	var/datum/persistence_restart_transaction/foreign = new
	check(!ticker.loadmap(foreign), "foreign transaction rejected")
	check(ticker.loadmap(persistence_restart), "startup explicit owner admitted")
	check(persistence_save_in_progress && !persistence_active_operation, "startup hold retained after import")
	check(!ticker.savemap(persistence_restart), "startup cannot save")
	text2file(probe_failure ? "FAIL" : "PASS", "result.txt")
	text2file("[checks]", "checks.txt")
	shutdown()
