/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

/proc/ipc_assert(condition, message)
	if (!condition) throw EXCEPTION(message)

/world/Error(exception/error)
	text2file("FAIL: runtime [error]", "result.txt")
	shutdown()

/world/New()
	world.OpenPort("none")
	try
		var/datum/extraction_account_store/accounts = new
		var/datum/extraction_ipc_service/service = new(accounts)
		service.key = "0123456789abcdef0123456789abcdef"
		ipc_assert(!service.ready(), "disabled service refuses startup")
		service.enabled = TRUE
		var/list/params = world.params
		if (params["phase"] == "issue")
			var/list/account = accounts.load_profile("alice")
			account["level"] = 2
			account["stash"] = list(list("id" = "saved-rifle", "equipment" = list()), list("id" = "saved-bag", "equipment" = list(), "secure" = TRUE))
			ipc_assert(accounts.commit_profile("alice", account), "create authoritative saved account")
			var/list/challenge = service.issue_challenge("alice", "1000", "1300")
			ipc_assert(islist(challenge) && service.profile["revision"] == 1, "durable game-origin challenge")
			text2file(json_encode(challenge), "challenge.json")
		else
			ipc_assert(service.ready(), "restart loads valid signed-service journal")
			var/before_replay_revision = service.profile["revision"]
			var/list/requests = json_decode(file2text(params["phase"] == "process" ? "requests.json" : "replay.json"))
			for (var/list/test in requests)
				var/list/response = service.process_wire(test["wire"], "1000")
				ipc_assert(islist(response) && response["status"] == test["status"] && response["reason"] == test["reason"], "request [test["id"]] expected [test["reason"]], got [json_encode(response)]")
				if (test["items"])
					var/list/data = response["data"]
					ipc_assert(length(data["items"]) == test["items"] && data["revision"] == 1 && data["level"] == 2, "bound saved account page")
			ipc_assert(service.profile["links"]["123"] == "alice" && service.profile["owners"]["alice"] == "123" && length(service.profile["links"]) == 1, "one durable actor/owner binding")
			if (params["phase"] == "replay") ipc_assert(service.profile["revision"] == before_replay_revision, "receipt replay has no new mutation")
			var/revision = service.profile["revision"]
			ipc_assert(!service.process_wire("tampered", "1000") && service.profile["revision"] == revision, "unauthenticated input has no journal effect")
			if (params["phase"] == "replay")
				var/datum/extraction_account_store/failed_accounts = new
				failed_accounts.root = "data/interrupted/"
				var/datum/extraction_ipc_service/interrupted = new(failed_accounts)
				interrupted.enabled = TRUE
				interrupted.key = service.key
				interrupted.test_fail_at = "intent"
				ipc_assert(!interrupted.issue_challenge("alice", "1000", "1300") && interrupted.blocked, "incomplete durable link journal locks adapter")
				interrupted = new(failed_accounts)
				interrupted.enabled = TRUE
				interrupted.key = service.key
				ipc_assert(!interrupted.ready() && interrupted.blocked, "restart refuses rollback of pending link intent")
		text2file("PASS: native IPC [params["phase"]] actor binding, receipts and isolated storage", "result.txt")
	catch (var/exception/error)
		text2file("FAIL: [error]", "result.txt")
	shutdown()
