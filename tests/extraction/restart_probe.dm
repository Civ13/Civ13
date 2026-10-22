#include "../../code/modules/1713/extraction/account_store.dm"
#include "../../code/modules/1713/extraction/transactions.dm"
#include "../../code/modules/1713/extraction/settlement.dm"

/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

var/restart_failures = 0

/proc/restart_first_id(datum/extraction_session/S)
	var/list/stash = S.profile["stash"]
	if (!stash.len) return null
	var/list/entry = stash[1]
	return entry["id"]

/proc/restart_assert(value, message)
	if (!value)
		restart_failures++
		world.log << "FAIL: [message]"

/world/New()
	world.OpenPort("none")
	var/phase = world.params["phase"]
	var/datum/extraction_service/service = new
	var/datum/extraction_session/A = service.open("restartalice")
	var/datum/extraction_session/B = service.open("restartbob")
	restart_assert(A && B, "two distinct accounts open after native process startup")
	if (A && B)
		if (phase == "write")
			var/list/entries = list(list("id" = "retained", "equipment" = list()))
			var/list/cost = list()
			for (var/i in 1 to 5)
				entries += list(list("id" = "paid[i]", "equipment" = list(), "salvage" = TRUE))
				cost += "paid[i]"
			restart_assert(A.checkpoint_home(entries) && A.upgrade(cost), "paid upgrade commits with retained item")
			restart_assert(B.checkpoint_home(list(list("id" = "bobonly", "equipment" = list()))), "separate account stash commits")
		else if (phase == "reload")
			restart_assert(A.profile["level"] == 2 && A.profile["stash"]:len == 1 && restart_first_id(A) == "retained", "actual process restart retains paid level and stash")
			restart_assert(B.profile["level"] == 1 && B.profile["stash"]:len == 1 && restart_first_id(B) == "bobonly", "restart preserves other account isolation")
			restart_assert(!service.open("restartalice"), "duplicate account rejected")
			restart_assert(A.begin_raid(list("retained")), "raid debit persisted before process exits")
		else if (phase == "recover")
			restart_assert(A.profile["level"] == 2 && A.profile["state"] == "home" && A.profile["stash"]:len == 0, "next native process forfeits interrupted raid without copying issued item")
			restart_assert(B.profile["stash"]:len == 1 && restart_first_id(B) == "bobonly", "unrelated private stash remains retained")
		else
			restart_assert(FALSE, "unknown phase rejected")
	text2file(restart_failures ? "FAIL: [restart_failures] native restart assertions" : "PASS: native process [phase], account isolation and durable paid upgrade", "result.txt")
	shutdown()
