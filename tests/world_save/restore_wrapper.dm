// Actual gameticker wrapper with injected storage/provider effects only.
// This fixture does not implement durable custody or immutable readers.
/map_storage/wrapper_fixture
	var/failure_stage = ""
	var/metadata_result = TRUE
	var/list/events = list()
	var/datum/persistence_restore_attempt/wrapper_fixture/observed_attempt
	proc/event(value)
		check(persistence_save_in_progress, "wrapper callback retains operation lock")
		events += value
	validate_world_save()
		event("validate")
		if(failure_stage == "preflight")
			last_error = "fixture preflight primary"
			return FALSE
		return TRUE
	ClearMap()
		event("clear")
		if(failure_stage == "clear")
			throw EXCEPTION("fixture clear primary")
	Load_World()
		event("world")
		if(failure_stage == "world_false")
			last_error = "fixture world primary"
			return FALSE
		if(failure_stage == "world_throw")
			throw EXCEPTION("fixture world primary")
		return TRUE
	load_map_metadata()
		event("metadata")
		if(failure_stage == "metadata_throw")
			throw EXCEPTION("fixture metadata primary")
		return metadata_result
	clear_bookkeeping()
		event("bookkeeping")
		if(failure_stage == "bookkeeping")
			throw EXCEPTION("fixture bookkeeping cleanup")
		return ..()

/datum/persistence_restore_policy/wrapper_fixture
	var/mode = ""
	begin_attempt(map_storage/wrapper_fixture/storage)
		storage.event("begin")
		if(mode == "missing")
			return null
		if(mode == "begin_throw")
			throw EXCEPTION("fixture begin primary")
		var/datum/persistence_restore_attempt/wrapper_fixture/attempt = new
		attempt.storage = storage
		attempt.policy = src
		storage.observed_attempt = attempt
		if(mode == "foreign")
			attempt.storage = null
		if(mode == "foreign_policy")
			attempt.policy = null
		return attempt

/datum/persistence_restore_attempt/wrapper_fixture
	var/release_calls = 0
	var/fail_calls = 0
	var/failure_phase
	var/original_failure
	var/mutated = FALSE
	before_mutation()
		var/map_storage/wrapper_fixture/S = storage
		var/datum/persistence_restore_policy/wrapper_fixture/P = policy
		S.event("reserve")
		if(P.mode == "reservation")
			return FALSE
		if(P.mode == "binding")
			S.restore_policy = null
		return TRUE
	fail(phase, original, mutation_started)
		var/map_storage/wrapper_fixture/S = storage
		var/datum/persistence_restore_policy/wrapper_fixture/P = policy
		S.event("fail")
		fail_calls++
		failure_phase = phase
		original_failure = original
		mutated = mutation_started
		if(P.mode == "fail_throw")
			throw EXCEPTION("fixture failure cleanup")
		if(P.mode == "wrong_outcome")
			return null
		var/datum/persistence_restore_failure/outcome = new
		outcome.attempt = src
		outcome.recovery_retained = P.mode != "lost_recovery"
		if(P.mode == "foreign_outcome")
			outcome.attempt = null
		return outcome
	release_transients()
		var/map_storage/wrapper_fixture/S = storage
		var/datum/persistence_restore_policy/wrapper_fixture/P = policy
		S.event("release")
		release_calls++
		if(P.mode == "release_throw")
			throw EXCEPTION("fixture release cleanup")
		return P.mode != "release_false"

/proc/wrapper_case(stage, provider_mode, metadata_result, expected)
	var/map_storage/original_storage = map_storage
	var/map_storage/wrapper_fixture/S = new("WRAPPER")
	S.failure_stage = stage
	S.metadata_result = metadata_result
	if(!isnull(provider_mode))
		if(provider_mode == "default")
			S.restore_policy = new /datum/persistence_restore_policy
		else
			var/datum/persistence_restore_policy/wrapper_fixture/P = new
			P.mode = provider_mode
			S.restore_policy = P
	map_storage = S
	var/datum/controller/gameticker/ticker = new
	var/result
	var/admin_errors = errors.len
	try
		result = ticker.loadmap()
	catch(var/exception/e)
		map_storage = original_storage
		persistence_save_in_progress = FALSE
		throw e
	map_storage = original_storage
	check(result == expected, (stage == "" && isnull(provider_mode) && metadata_result != TRUE) ? "metadata exact TRUE required" : "wrapper result [stage]/[provider_mode]/[metadata_result]")
	check(!persistence_save_in_progress, "wrapper releases operation lock")
	check(errors.len == admin_errors + (expected ? 0 : 1), "wrapper reports each failed attempt once")
	if(expected)
		check(jointext(S.events, ",") == (isnull(provider_mode) ? "validate,clear,world,metadata" : "begin,validate,reserve,clear,world,metadata,release"), "wrapper success callback order")
	else
		check(S.events[S.events.len] == "bookkeeping", "wrapper failure clears bookkeeping")
		check(length(S.last_error), "wrapper failure retains primary error")
	return S

/proc/check_restore_wrapper()
	var/initial_errors = errors.len
	var/map_storage/wrapper_fixture/S = wrapper_case("", null, TRUE, TRUE)
	S = wrapper_case("", "", TRUE, TRUE)
	check(S.observed_attempt.release_calls == 1 && !S.observed_attempt.fail_calls, "successful attempt released once")
	check(S.persistence_runtime_var("restore_policy") && S.persistence_runtime_var("restore_cleanup_error") && S.persistence_runtime_var("persistence_export_frame"), "wrapper runtime exclusions preserve parent")
	check(S.observed_attempt.persistence_runtime_var("storage") && S.observed_attempt.persistence_runtime_var("policy") && S.observed_attempt.persistence_runtime_var("persistence_export_frame"), "attempt runtime exclusions preserve parent")
	for(var/value in list(FALSE, 2))
		S = wrapper_case("", null, value, FALSE)
		check(findtext(S.last_error, "World metadata restoration rejected"), "metadata exact TRUE required")
	S = wrapper_case("metadata_throw", null, TRUE, FALSE)
	check(findtext(S.last_error, "fixture metadata primary"), "metadata exception preserved")
	for(var/stage in list("preflight", "clear", "world_false", "world_throw", "metadata_throw"))
		S = wrapper_case(stage, "", TRUE, FALSE)
		var/datum/persistence_restore_attempt/wrapper_fixture/A = S.observed_attempt
		var/expected_phase = stage == "preflight" ? "preflight" : (stage == "clear" ? "clear" : (stage == "metadata_throw" ? "metadata" : "world"))
		check(A.failure_phase == expected_phase && A.mutated == (stage != "preflight"), "wrapper records phase and conservative mutation boundary")
		check(A.fail_calls == 1 && A.release_calls == 1, "wrapper failure notified and released once")
		check(A.original_failure == S.last_error, "wrapper passes original failure to provider")
		check(jointext(S.events, ",") == (stage == "preflight" ? "begin,validate,fail,release,bookkeeping" : (stage == "clear" ? "begin,validate,reserve,clear,fail,release,bookkeeping" : (stage == "metadata_throw" ? "begin,validate,reserve,clear,world,metadata,fail,release,bookkeeping" : "begin,validate,reserve,clear,world,fail,release,bookkeeping"))), "wrapper failure callback order")
	for(var/mode in list("default", "missing", "begin_throw", "foreign", "foreign_policy", "reservation", "binding"))
		S = wrapper_case("", mode, TRUE, FALSE)
		check(!("clear" in S.events) && !("world" in S.events), "provider rejection precedes mutation")
		if(mode == "reservation" || mode == "binding")
			check(!S.observed_attempt.mutated && S.observed_attempt.fail_calls == 1 && S.observed_attempt.release_calls == 1, "owned pre-mutation rejection releases once")
	for(var/mode in list("fail_throw", "wrong_outcome", "foreign_outcome", "lost_recovery", "release_throw", "release_false"))
		S = wrapper_case("world_false", mode, TRUE, FALSE)
		check(findtext(S.last_error, "fixture world primary"), "cleanup preserves primary failure")
		check(length(S.restore_cleanup_error), "failed cleanup remains separately visible")
		check(S.observed_attempt.fail_calls == 1 && S.observed_attempt.release_calls == 1, "failed cleanup attempted once")
		if(mode == "wrong_outcome" || mode == "foreign_outcome" || mode == "lost_recovery")
			check(findtext(S.restore_cleanup_error, "retained recovery custody"), "typed retained recovery receipt required")
	S = wrapper_case("bookkeeping", "", FALSE, FALSE)
	check(findtext(S.last_error, "World metadata restoration rejected") && findtext(S.restore_cleanup_error, "fixture bookkeeping cleanup"), "bookkeeping failure preserves primary metadata failure")
	for(var/mode in list("release_throw", "release_false"))
		S = wrapper_case("", mode, TRUE, FALSE)
		check(S.observed_attempt.failure_phase == "release" && S.observed_attempt.mutated && S.observed_attempt.release_calls == 1, "success-path release failure retains recovery without second release")
	var/map_storage/original_storage = map_storage
	S = new("BUSY")
	map_storage = S
	persistence_save_in_progress = TRUE
	var/datum/controller/gameticker/ticker = new
	var/result = ticker.loadmap()
	map_storage = original_storage
	persistence_save_in_progress = FALSE
	check(result == FALSE && !S.events.len, "busy wrapper rejects before provider or storage effects")
	// Remove only the expected injected admin reports before disk round trips.
	errors.Cut(initial_errors + 1)
	world.log << "PASS: actual restore wrapper ordering and failure custody"
