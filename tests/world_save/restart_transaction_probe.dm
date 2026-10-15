// No production startup, network, real restart, account or external files.
#define TRUE 1
#define FALSE 0
#define EXCEPTION(message) new /exception(message)
var/persistence_save_in_progress = FALSE
var/map_storage/map_storage = new
var/obj/map_metadata/map = new
var/datum/controller/gameticker/ticker = new
var/delete_failure = FALSE
var/native_calls = 0
var/ordinary_calls = 0
var/checks = 0
var/failures = 0
/map_storage
	var/last_error
/map_storage/proc/validate_world_save()
	return TRUE
/map_storage/proc/read_round_state()
	return list("version" = 2, "generation" = "round-v2:probe")
/obj/map_metadata/proc/uses_durable_metadata()
	return TRUE
/datum/controller/gameticker/proc/savemap(datum/owner)
	return TRUE
/datum/controller/gameticker/proc/loadmap(datum/owner)
	return TRUE
/proc/to_chat(target, message)
	return
/proc/message_admins(message)
	return
/proc/trim(value)
	return replacetext(value, "\n", "")
/proc/restart_delete_adapter(path)
	if(delete_failure) return FALSE
	return fdel(path)
/proc/fixture_native_reboot(reason)
	native_calls++
	return FALSE
/proc/fixture_ordinary_reboot(reason)
	ordinary_calls++
	return TRUE
/proc/check(condition, message)
	checks++
	if(!condition)
		failures++
		world.log << "FAIL: [message]"

/datum/persistence_restart_transaction/probe
	var/save_ok = TRUE
	var/load_ok = TRUE
	var/validation_ok = TRUE
	var/saves = 0
	var/loads = 0
	var/restarts = 0
	var/concurrent = FALSE
	var/change_before_restart = FALSE
	var/identity_calls = 0
	var/list/identity = list("version" = 1, "generation" = "round-v2:probe", "metadata" = "metadata-digest", "round" = "round-digest")
/datum/persistence_restart_transaction/probe/supported()
	return TRUE
/datum/persistence_restart_transaction/probe/save_generation()
	saves++
	if(concurrent) check(!execute(), "concurrent transaction admitted")
	if(save_ok)
		fdel("map_saves/save_complete.txt")
		text2file(identity["generation"], "map_saves/save_complete.txt")
	return save_ok
/datum/persistence_restart_transaction/probe/load_generation()
	loads++
	return load_ok
/datum/persistence_restart_transaction/probe/current_identity()
	identity_calls++
	if(!validation_ok) throw EXCEPTION("fixture invalid generation")
	var/list/I = identity.Copy()
	if(change_before_restart && identity_calls > 1) I["generation"] = "round-v2:replacement"
	return I
/datum/persistence_restart_transaction/probe/request_restart()
	restarts++
	fcopy(intent_path, "crash-boundary.json")
	return ..()

/proc/new_transaction()
	fdel("map_saves/restart_intent.json")
	persistence_save_in_progress = FALSE
	var/datum/persistence_restart_transaction/probe/T = new
	persistence_restart = T
	return T

/world/New()
	world.OpenPort("none")
	spawn(0)
		var/datum/persistence_restart_transaction/probe/T = new_transaction()
		check(!T.detect_startup(), "missing intent imposed startup hold")
		T.save_ok = FALSE
		check(!T.execute() && T.saves == 1 && !T.exists() && !T.restarts && !T.busy, "failed save restarted or locked server")
		T = new_transaction()
		T.concurrent = TRUE
		check(!T.execute() && T.saves == 1 && T.restarts == 1 && !T.busy && !T.exists(), "returned restart did not cancel matching intent/release guard")
		check(native_calls == 1, "immediate native adapter not called once")
		// Simulate process loss AFTER durable publication, BEFORE native reboot.
		fcopy("crash-boundary.json", T.intent_path)
		T = new
		persistence_restart = T
		check(T.detect_startup() && persistence_save_in_progress, "durable intent did not hold startup")
		check(!world.Reboot(0) && !ordinary_calls, "normal reboot bypassed recovery hold")
		check(T.resume_startup() && T.loads == 1 && !T.exists() && !T.startup_hold && !persistence_save_in_progress, "startup recovery failed to consume after successful load")
		check(!T.resume_startup() && T.loads == 1, "consumed intent imported twice")
		T = new_transaction()
		T.publish(T.identity)
		T.detect_startup()
		T.validation_ok = FALSE
		check(!T.resume_startup() && T.exists() && T.startup_hold && persistence_save_in_progress && !T.loads, "invalid generation allowed startup/mutation")
		T.validation_ok = TRUE
		check(T.resume_startup() && T.loads == 1, "repaired preflight could not resume")
		T = new_transaction()
		T.publish(T.identity)
		T.detect_startup()
		T.load_ok = FALSE
		check(!T.resume_startup() && T.exists() && T.startup_hold && persistence_save_in_progress, "failed import discarded intent or released hold")
		T.load_ok = TRUE
		check(!T.resume_startup() && T.loads == 1, "failed destructive import retried in same world")
		T = new_transaction()
		T.change_before_restart = TRUE
		check(!T.execute() && !T.restarts && !T.exists() && !T.busy, "stale completed generation restarted")
		T = new_transaction()
		text2file("{broken", T.intent_path)
		T.detect_startup()
		check(!T.resume_startup() && !T.loads && T.exists() && T.startup_hold, "malformed intent allowed fresh world")
		T = new_transaction()
		T.publish(T.identity)
		T.detect_startup()
		delete_failure = TRUE
		check(!T.resume_startup() && T.loads == 1 && T.exists() && T.startup_hold, "failed consumption claimed completion")
		delete_failure = FALSE
		check(T.resume_startup() && T.loads == 1 && !T.exists(), "consumption retry reimported world")
		T = new_transaction()
		T.publish(T.identity)
		var/list/other = T.identity.Copy()
		other["generation"] = "round-v2:other"
		var/rejected = FALSE
		try
			T.consume(other)
		catch(var/exception/e)
			rejected = !!e
		check(rejected && T.exists(), "cleanup deleted another operation's intent")
		T = new_transaction()
		delete_failure = TRUE
		check(!T.execute() && !T.busy && T.exists() && findtext(T.last_error, "cleanup FAILED"), "restart return with failed cleanup hid unresolved intent")
		delete_failure = FALSE
		check(!T.execute() && T.saves == 1, "unresolved intent allowed overwrite")
		T = new_transaction()
		T.busy = TRUE
		T.expected_generation = "round-v2:probe"
		text2file("round-v2:replacement", "map_saves/save_complete.txt")
		var/before = native_calls
		check(!world.Reboot(0, T.expected_generation) && native_calls == before, "last native generation guard bypassed")
		check(!world.Reboot(0) && !ordinary_calls, "ordinary reboot bypassed active save")
		text2file(json_encode(list("done" = TRUE, "checks" = checks, "failures" = failures)), "result.json")
		shutdown()
