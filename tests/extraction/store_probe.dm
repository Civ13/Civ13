#include "../../code/modules/1713/extraction/account_store.dm"
#include "../../code/modules/1713/extraction/transactions.dm"

/world
	fps = 10

/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

var/store_failures = 0

/proc/store_assert(condition, message)
	if (!condition)
		store_failures++
		world.log << "FAIL: [message]"

/world/New()
	world.OpenPort("none")
	var/datum/extraction_account_store/S = new
	store_assert(!S.load_profile("../other") && !S.load_profile("Guest123"), "identity rejection")
	var/list/P = S.load_profile("fixture")
	store_assert(P && P["level"] == 1, "new account")
	store_assert(S.commit_profile("fixture", P), "initial commit: [S.last_error]")
	var/list/stale = P.Copy()
	P["level"] = 2
	store_assert(S.commit_profile("fixture", P), "second commit")
	store_assert(!S.commit_profile("fixture", stale), "stale snapshot cannot overwrite newest")
	S = new
	P = S.load_profile("fixture")
	store_assert(P && P["level"] == 2, "restart newest generation")
	store_assert(S.load_profile("other")["level"] == 1, "cross-account isolation")
	for (var/i in 1 to 20)
		P["raid_sequence"] = i
		store_assert(S.commit_profile("fixture", P), "bounded slot reuse")
	store_assert(flist("data/extraction_accounts/fixture/").len <= 6, "bounded disk files")
	S.test_fail_at = "intent"
	store_assert(!S.commit_profile("fixture", P), "intent interruption")
	S = new
	store_assert(!S.load_profile("fixture"), "no rollback after restart")
	store_assert(!S.commit_profile("fixture", P), "pending intent blocks writes")
	P = S.load_profile("snapshotfailure")
	store_assert(S.commit_profile("snapshotfailure", P), "second fixture")
	S.test_fail_at = "snapshot"
	store_assert(!S.commit_profile("snapshotfailure", P), "snapshot interruption")
	S = new
	store_assert(!S.load_profile("snapshotfailure"), "snapshot crash blocks rollback")
	P = S.load_profile("corrupt")
	store_assert(S.commit_profile("corrupt", P), "corrupt fixture commit")
	fdel(S.path_for("corrupt", 0, "snapshot"))
	text2file("broken", S.path_for("corrupt", 0, "snapshot"))
	store_assert(!S.load_profile("corrupt"), "digest rejects corruption")
	P = S.load_profile("unsupported")
	P["schema"] = 999
	store_assert(!S.commit_profile("unsupported", P), "future schema rejected")
	S.busy = TRUE
	store_assert(!S.commit_profile("other", S.load_profile("other")), "concurrent writer rejected")
	transaction_probe()
	text2file(store_failures ? "FAIL: [store_failures] journal assertions" : "PASS: account journal restart, isolation, bounds, crash and corruption", "result.txt")
	shutdown()

/proc/transaction_probe()
	var/datum/extraction_service/service = new
	var/datum/extraction_session/S = service.open("raider")
	store_assert(S && !service.open("raider"), "duplicate login rejected")
	var/list/gear = list(list("id" = "rifle", "equipment" = list()), list("id" = "bag", "equipment" = list()))
	store_assert(S.checkpoint_home(gear), "home checkpoint")
	store_assert(!S.begin_raid(list("unknown")), "unknown selection rejected")
	var/list/raid = S.begin_raid(list("rifle"))
	store_assert(raid && S.profile["stash"].len == 1, "raid durable debit")
	store_assert(!S.begin_raid(list("bag")), "second concurrent raid rejected")
	store_assert(!S.extract(99, gear), "wrong raid extraction rejected")
	store_assert(S.extract(raid["sequence"], list(gear[1])), "successful extraction")
	store_assert(!S.extract(raid["sequence"], list(gear[1])), "extraction replay rejected")
	raid = S.begin_raid(list("rifle"))
	store_assert(S.forfeit(raid["sequence"]), "death forfeiture")
	store_assert(!S.extract(raid["sequence"], list(gear[1])), "dead raid cannot extract")
	raid = S.begin_raid(list("bag"))
	S.close()
	service = new
	S = service.open("raider")
	store_assert(S && S.profile["stash"].len == 0 && S.profile["state"] == "home", "restart forfeits issued gear")
	var/list/salvage = list()
	var/list/ids = list()
	for (var/i in 1 to 5)
		salvage += list(list("id" = "scrap[i]", "equipment" = list(), "salvage" = TRUE))
		ids += "scrap[i]"
	store_assert(S.checkpoint_home(salvage), "salvage checkpoint")
	store_assert(!S.upgrade(list("scrap1")), "insufficient upgrade cost")
	store_assert(S.upgrade(ids) && S.profile["level"] == 2 && S.profile["stash"].len == 0, "upgrade consumes materials atomically")
	store_assert(!S.upgrade(ids), "upgrade replay rejected")
	S.close()
	store_assert(!S.checkpoint_home(gear), "closed session rejected")
