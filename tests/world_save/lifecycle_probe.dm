var/list/clients = list()
/obj/map_metadata/var/ID = "fixture"
/datum/controller/gameticker/var/current_state = GAME_STATE_PLAYING
var/shutdown_calls = 0
var/allow_native_shutdown = FALSE
var/change_final_marker = FALSE
var/lifecycle_reclaim_ok = TRUE
/proc/lifecycle_native_shutdown()
	shutdown_calls++
	var/list/I = persistence_restart.read_intent()
	check(I["lifecycle_operation"] == persistence_restart.lifecycle_operation && I["lifecycle_session"] == persistence_restart.lifecycle_session && persistence_lifecycle_hex(I["lifecycle_operation"]), "shutdown intent missing acknowledged request binding")
	if(allow_native_shutdown)
		text2file(json_encode(list("done" = TRUE, "checks" = checks, "failures" = failures, "intent_durable" = persistence_restart.exists())), "result.json")
		del(world)
/datum/persistence_restart_transaction/probe/current_identity()
	identity_calls++
	if(!validation_ok) throw EXCEPTION("fixture invalid generation")
	var/list/I = identity.Copy()
	if(lifecycle_operation)
		I["lifecycle_operation"] = lifecycle_operation
		I["lifecycle_session"] = lifecycle_session
	if(change_final_marker && identity_calls == 3)
		fdel("map_saves/save_complete.txt")
		text2file("round-v2:changed", "map_saves/save_complete.txt")
	if(change_before_restart && identity_calls > 1) I["generation"] = "round-v2:replacement"
	return I
/datum/nomads_lifecycle_control/probe
	var/fixture_token = "fedcba9876543210fedcba9876543210"
	var/fixture_revision = "0123456789abcdef0123456789abcdef01234567"
/datum/nomads_lifecycle_control/probe/read_token()
	return fixture_token
/datum/nomads_lifecycle_control/probe/read_revision()
	return fixture_revision
/proc/lifecycle_request(datum/nomads_lifecycle_control/probe/L, action = "status")
	var/list/I = list("nomads_lifecycle" = "1", "token" = L.fixture_token, "action" = action)
	if(action == "save_shutdown")
		I["session"] = L.boot_session()
		I["operation"] = md5("operation-[checks]")
	return I
/proc/lifecycle_reply(datum/nomads_lifecycle_control/probe/L, list/I, addr = "127.0.0.1:12345")
	return json_decode(L.handle(I, addr))
/world/New()
	world.OpenPort("none")
	spawn(0)
		var/datum/persistence_restart_transaction/probe/T = new_transaction()
		var/datum/nomads_lifecycle_control/probe/L = new
		var/list/I = lifecycle_request(L)
		var/list/R = lifecycle_reply(L, I)
		check(R["ok"] && R["ready"] && nomads_lifecycle_hex(R["session"], 32), "ready status invalid")
		check(!("token" in R) && !findtext(json_encode(R), L.fixture_token), "status exposed token")
		R = lifecycle_reply(L, I, "192.0.2.1:12345")
		check(!R["ok"], "nonloopback accepted")
		I["token"] = "wrong"
		R = lifecycle_reply(L, I)
		check(!R["ok"], "wrong token accepted")
		I = lifecycle_request(L)
		L.fixture_token = null
		R = lifecycle_reply(L, I)
		check(!R["ok"], "missing token enabled endpoint")
		L.fixture_token = "fedcba9876543210fedcba9876543210"
		L.fixture_revision = "invalid"
		R = lifecycle_reply(L, I)
		check(!R["ok"], "invalid revision enabled endpoint")
		L.fixture_revision = "0123456789abcdef0123456789abcdef01234567"
		I["extra"] = "reject"
		R = lifecycle_reply(L, I)
		check(!R["ok"], "unknown field accepted")
		I = lifecycle_request(L, "eval")
		R = lifecycle_reply(L, I)
		check(!R["ok"], "unknown action accepted")
		I = lifecycle_request(L, "save_shutdown")
		I["session"] = md5("old boot")
		R = lifecycle_reply(L, I)
		check(!R["ok"] && !T.saves, "stale session saved")
		I = lifecycle_request(L, "save_shutdown")
		T.busy = TRUE
		R = lifecycle_reply(L, I)
		check(!R["ok"] && !T.saves, "busy transaction admitted")
		T.busy = FALSE
		persistence_save_in_progress = TRUE
		R = lifecycle_reply(L, I)
		check(!R["ok"] && !T.saves, "active save admitted")
		persistence_save_in_progress = FALSE
		map_storage.dimension_recovery_required = TRUE
		R = lifecycle_reply(L, I)
		check(!R["ok"] && !T.saves, "dimension failure admitted")
		map_storage.dimension_recovery_required = FALSE
		T.startup_hold = TRUE
		R = L.snapshot()
		check(!R["ready"], "recovery hold reported ready")
		T.startup_hold = FALSE
		T.import_started = TRUE
		T.import_complete = TRUE
		R = L.snapshot()
		check(!R["ready"], "incomplete reclaim reported ready")
		T.players_ready = TRUE
		R = L.snapshot()
		check(R["ready"], "completed reclaim not ready")
		T = new_transaction()
		T.save_ok = FALSE
		R = lifecycle_reply(L, I)
		check(R["ok"] && R["busy"], "accepted operation did not reserve synchronously")
		R = lifecycle_reply(L, I)
		check(!R["ok"], "operation replay accepted")
		var/list/other = lifecycle_request(L, "save_shutdown")
		R = lifecycle_reply(L, other)
		check(!R["ok"], "concurrent operation admitted")
		sleep(2)
		check(T.saves == 1 && !shutdown_calls && !L.busy && L.last_error && !T.exists(), "failed save shutdown or retained lock")
		R = lifecycle_reply(L, I)
		check(!R["ok"] && T.saves == 1, "failed operation replay saved again")
		T = new_transaction()
		T.validation_ok = FALSE
		I = lifecycle_request(L, "save_shutdown")
		R = lifecycle_reply(L, I)
		sleep(2)
		check(!shutdown_calls && !T.exists() && !L.busy, "invalid save shutdown")
		T = new_transaction()
		T.change_before_restart = TRUE
		I = lifecycle_request(L, "save_shutdown")
		R = lifecycle_reply(L, I)
		sleep(2)
		check(!shutdown_calls && !T.exists(), "stale generation shutdown")
		T = new_transaction()
		change_final_marker = TRUE
		var/before = shutdown_calls
		T.execute(TRUE, md5("final-operation"), L.boot_session())
		check(shutdown_calls == before && !T.exists(), "changed final generation reached shutdown")
		before = shutdown_calls
		change_final_marker = FALSE
		for(var/n = L.used_operations.len, n < 64, n++) L.used_operations += md5("limit-[n]")
		I = lifecycle_request(L, "save_shutdown")
		R = lifecycle_reply(L, I)
		check(!R["ok"] && L.used_operations.len == 64, "operation history evicted old replay protection")
		I["operation"] = L.used_operations[1]
		R = lifecycle_reply(L, I)
		check(!R["ok"], "old operation replay after capacity")
		T = new_transaction()
		var/list/bound = T.identity.Copy()
		bound["lifecycle_operation"] = md5("binding")
		text2file(json_encode(bound), T.intent_path)
		var/rejected = FALSE
		try
			T.read_intent()
		catch(var/exception/e)
			rejected = !!e
		check(rejected, "partial lifecycle intent accepted")
		fdel(T.intent_path)
		bound["lifecycle_session"] = md5("binding-session")
		T.publish(bound)
		check(T.detect_startup() && T.resume_startup() && T.players_ready && !T.exists(), "bound intent did not recover and consume")
		T = new_transaction()
		T.publish(T.identity)
		T.detect_startup()
		lifecycle_reclaim_ok = FALSE
		T.resume_startup()
		R = L.snapshot()
		check(!T.players_ready && !R["ready"], "failed reclaim sweep reported ready")
		lifecycle_reclaim_ok = TRUE
		check(shutdown_calls == before, "denied requests reached shutdown")
		T = new_transaction()
		L = new
		allow_native_shutdown = TRUE
		I = lifecycle_request(L, "save_shutdown")
		R = lifecycle_reply(L, I)
		sleep(10)
		check(FALSE, "valid shutdown failed to terminate world")
		text2file(json_encode(list("done" = FALSE, "checks" = checks, "failures" = failures)), "result.json")
		shutdown()
