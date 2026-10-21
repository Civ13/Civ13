#include "../../code/modules/1713/extraction/account_store.dm"
#include "../../code/modules/1713/extraction/transactions.dm"
#include "../../code/modules/1713/extraction/settlement.dm"

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
	var/datum/extraction_account_store/leased_store = new
	leased_store.root = "data/lease_fixture/"
	var/list/lease_profile = leased_store.load_profile("owner")
	store_assert(leased_store.commit_profile("owner", lease_profile), "lease fixture initial account")
	var/datum/extraction_account_read_lease/lease = leased_store.acquire_read_lease()
	store_assert(leased_store.read_lease_valid(lease), "lease has bound root and instance")
	var/datum/extraction_account_store/other_writer = new
	other_writer.root = "DATA/LEASE_FIXTURE/"
	store_assert(!other_writer.acquire_read_lease(), "root aliases cannot acquire competing lease")
	other_writer.root = leased_store.root
	var/list/other_profile = other_writer.load_profile("owner")
	store_assert(!other_writer.commit_profile("owner", other_profile) && other_writer.load_profile("owner")["revision"] == 1, "other instance blocked before durable intent")
	store_assert(!other_writer.write_phase("data/lease_fixture/_settlement/world/0.snapshot", "projection"), "direct child-journal projection blocked")
	store_assert(!other_writer.release_read_lease(lease), "other instance cannot release lease")
	leased_store.root = "data/other_fixture/"
	store_assert(!leased_store.read_lease_valid(lease), "changed store root invalidates census")
	leased_store.root = "data/lease_fixture/"
	store_assert(leased_store.release_read_lease(lease) && !leased_store.read_lease_valid(lease) && !leased_store.release_read_lease(lease), "explicit single release invalidates token")
	store_assert(other_writer.commit_profile("owner", other_profile), "ordinary writes resume after lease release")
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
	var/list/recovery_intent = json_decode(file2text(S.path_for("snapshotfailure", 1, "intent")))
	store_assert(!S.recover_snapshot("snapshotfailure", 2, "00000000000000000000000000000000"), "wrong recovery digest rejected")
	store_assert(!S.recover_snapshot("other", 2, recovery_intent["digest"]), "other account recovery rejected")
	P = S.recover_snapshot("snapshotfailure", 2, recovery_intent["digest"])
	store_assert(P && P["revision"] == 2 && S.load_profile("snapshotfailure"), "exact intended snapshot recovered")
	store_assert(fexists("data/extraction_accounts/snapshotfailure/recovery.latest.json"), "recovery evidence retained")
	store_assert(!S.recover_snapshot("snapshotfailure", 2, recovery_intent["digest"]), "recovery replay rejected")
	recovery_intent = json_decode(file2text(S.path_for("fixture", 0, "intent")))
	store_assert(!S.recover_snapshot("fixture", recovery_intent["generation"], recovery_intent["digest"]), "missing intended snapshot never falls back")
	P = S.settle_pending_loss("fixture", recovery_intent["generation"], recovery_intent["digest"])
	store_assert(P && !P["stash"].len && P["state"] == "home" && P["level"] == 2, "explicit loss settlement unlocks without rollback gear or free upgrade")
	store_assert(!S.settle_pending_loss("fixture", recovery_intent["generation"], recovery_intent["digest"]), "loss settlement replay rejected")
	P = S.load_profile("container1")
	P["loot_state"] = "pending"
	P["pending_item"] = list("id" = "uncertainitem", "equipment" = list())
	store_assert(S.commit_profile("container1", P), "uncertain delivery fixture")
	store_assert(!S.retire_pending_delivery("container1", P["revision"], "wrongitem"), "wrong delivery identity rejected")
	P = S.retire_pending_delivery("container1", P["revision"], "uncertainitem")
	store_assert(P && P["loot_state"] == "ready" && !P["pending_item"] && !P["stash"].len, "uncertain delivery retired without issuing gear")
	store_assert(!S.retire_pending_delivery("container1", 1, "uncertainitem"), "retirement replay rejected")
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
	recovery_ownership_probe()
	text2file(store_failures ? "FAIL: [store_failures] journal assertions" : "PASS: account journal restart, isolation, bounds, crash and corruption", "result.txt")
	shutdown()

/proc/recovery_ownership_probe()
	var/datum/extraction_account_store/S = new
	S.root = "data/recovery_ownership/"
	var/list/A = S.load_profile("alice")
	store_assert(S.commit_profile("alice", A), "recovery ownership initial account")
	A["stash"] = list(list("id" = "gun1", "equipment" = list("schema" = 2, "nodes" = list(list("id" = "gun1"), list("id" = "optic1")))))
	S.test_fail_at = "snapshot"
	store_assert(!S.commit_profile("alice", A), "recovery ownership interrupted credit")
	S.test_fail_at = null
	var/list/B = S.load_profile("bob")
	B["stash"] = list(list("id" = "gun2", "equipment" = list("schema" = 2, "nodes" = list(list("id" = "gun2"), list("id" = "optic1")))))
	store_assert(S.commit_profile("bob", B), "other account acquired nested component")
	var/list/intent = json_decode(file2text(S.path_for("alice", 1, "intent")))
	store_assert(!S.recover_snapshot("alice", 2, intent["digest"]), "nested ownership conflict blocks recovery credit")
	store_assert(!fexists("data/recovery_ownership/alice/recovery.latest.json"), "rejected recovery preserves evidence without receipt")
	B["stash"] = list()
	store_assert(S.commit_profile("bob", B), "other account relinquished conflicting component")
	A = S.recover_snapshot("alice", 2, intent["digest"])
	store_assert(A && A["stash"].len == 1, "ownership-cleared recovery retains exact candidate")

/proc/transaction_probe()
	var/datum/extraction_service/service = new
	var/datum/extraction_session/S = service.open("raider")
	store_assert(S && !service.open("raider"), "duplicate login rejected")
	var/list/valid_graph = list(list("id" = "shape_root", "equipment" = list("schema" = 2, "nodes" = list(list("id" = "shape_root")))))
	store_assert(S.valid_entries(valid_graph, 16), "well-formed account graph accepted")
	var/profile_before = json_encode(S.profile)
	for (var/invalid in list("malformed", 17))
		var/list/bad_entries = json_decode(json_encode(valid_graph))
		bad_entries += invalid
		var/entries_before = json_encode(bad_entries)
		store_assert(!S.valid_entries(bad_entries, 16), "scalar account root rejected [invalid]")
		store_assert(!S.checkpoint_home(bad_entries) && json_encode(S.profile) == profile_before, "scalar roots cannot commit an account checkpoint [invalid]")
		store_assert(json_encode(bad_entries) == entries_before, "rejected account roots remain unchanged [invalid]")
		var/list/bad_nodes = json_decode(json_encode(valid_graph))
		bad_nodes[1]["equipment"]["nodes"] += invalid
		var/nodes_before = json_encode(bad_nodes)
		store_assert(!S.valid_entries(bad_nodes, 16), "scalar equipment node rejected [invalid]")
		store_assert(!S.checkpoint_home(bad_nodes) && json_encode(S.profile) == profile_before, "scalar nodes cannot commit an account checkpoint [invalid]")
		store_assert(json_encode(bad_nodes) == nodes_before, "rejected equipment nodes remain unchanged [invalid]")
	var/list/budget_entries = list()
	for (var/root_index in 1 to 5)
		var/list/nodes = list(list("id" = "budgetroot[root_index]"))
		for (var/node_index in 2 to 512) nodes += list(list("id" = "budget[root_index]node[node_index]"))
		budget_entries += list(list("id" = "budgetroot[root_index]", "equipment" = list("schema" = 2, "nodes" = nodes)))
	store_assert(!S.valid_entries(budget_entries, 16), "aggregate account equipment node budget rejected")
	budget_entries.Cut(5)
	store_assert(S.valid_entries(budget_entries, 16), "exact aggregate node budget accepted")
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
	store_assert(S.deposit(raid["sequence"], list(gear[1])), "shipment commits while raid active")
	store_assert(!S.deposit(raid["sequence"], list(gear[1])), "shipment replay rejected")
	store_assert(S.forfeit(raid["sequence"]), "death forfeiture")
	store_assert(S.profile["stash"].len == 2, "committed shipment survives death")
	store_assert(!S.extract(raid["sequence"], list(gear[1])), "dead raid cannot extract")
	raid = S.begin_raid(list("bag"))
	S.close()
	service = new
	S = service.open("raider")
	store_assert(S && S.profile["stash"].len == 1 && S.profile["state"] == "home", "restart forfeits issued gear and retains shipment")
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
