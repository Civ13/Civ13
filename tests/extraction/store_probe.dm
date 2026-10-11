#include "../../code/modules/1713/extraction/account_store.dm"

/world
	fps = 10

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
	text2file(store_failures ? "FAIL: [store_failures] journal assertions" : "PASS: account journal restart, isolation, bounds, crash and corruption", "result.txt")
	shutdown()
