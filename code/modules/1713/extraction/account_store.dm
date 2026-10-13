// Bounded two-slot account journal. Incomplete transfers fail closed.
#define EXTRACTION_STORE_VERSION 1
#define EXTRACTION_PROFILE_LIMIT 2097152
#define EXTRACTION_CAR_PRICE 25

// In-process read leases cover every store instance and child journal path.
// They do not establish an OS lock against another server or external writer.
var/global/list/extraction_account_read_leases = list()

/proc/extraction_store_path(path)
	if (!istext(path) || !length(path) || length(path) > 512) return null
	var/canonical = lowertext(replacetext(path, "\\", "/"))
	if (copytext(canonical, 1, 2) == "/" || findtext(canonical, "//")) return null
	var/alphabet = "abcdefghijklmnopqrstuvwxyz0123456789_-/"
	for (var/index in 1 to length(canonical))
		if (!findtextEx(alphabet, copytext(canonical, index, index + 1))) return null
	return canonical

/datum/extraction_account_read_lease
	var/datum/extraction_account_store/store
	var/root
	var/active = TRUE

/datum/extraction_account_store/proc/acquire_read_lease()
	var/canonical = extraction_store_path(root)
	if (busy || !canonical || copytext(canonical, length(canonical)) != "/" || extraction_account_read_leases.len >= 8) return fail("Account inventory lease unavailable")
	for (var/datum/extraction_account_read_lease/existing in extraction_account_read_leases)
		if (findtext(canonical, existing.root) == 1 || findtext(existing.root, canonical) == 1) return fail("Account inventory already leased")
	var/datum/extraction_account_read_lease/lease = new
	lease.store = src
	lease.root = canonical
	extraction_account_read_leases += lease
	return lease

/datum/extraction_account_store/proc/read_lease_valid(datum/extraction_account_read_lease/lease)
	return lease && lease.active && lease.store == src && lease.root == extraction_store_path(root) && (lease in extraction_account_read_leases)

/datum/extraction_account_store/proc/release_read_lease(datum/extraction_account_read_lease/lease)
	if (!lease || lease.store != src || !lease.active || !(lease in extraction_account_read_leases)) return FALSE
	lease.active = FALSE
	extraction_account_read_leases -= lease
	return TRUE

/datum/extraction_account_store/proc/inventory_write_blocked(path)
	if (!extraction_account_read_leases.len) return FALSE
	// Phase filenames include a dot. Canonicalize the directory, not suffix.
	var/last_slash = 0
	var/normalized = replacetext(path, "\\", "/")
	for (var/index in 1 to length(normalized))
		if (copytext(normalized, index, index + 1) == "/") last_slash = index
	var/directory = extraction_store_path(copytext(normalized, 1, last_slash + 1))
	if (!directory) return TRUE
	for (var/datum/extraction_account_read_lease/lease in extraction_account_read_leases)
		if (findtext(directory, lease.root) == 1) return TRUE
	return FALSE

/datum/extraction_account_store
	var/root = "data/extraction_accounts/"
	var/last_error
	var/tmp/busy = FALSE
	var/tmp/test_fail_at = null

/datum/extraction_account_store/proc/valid_owner(owner)
	return istext(owner) && length(owner) > 0 && length(owner) <= 64 && ckey(owner) == owner && findtext(owner, "guest") != 1

/datum/extraction_account_store/proc/path_for(owner, slot, suffix)
	return "[root][owner]/[slot].[suffix]"

/datum/extraction_account_store/proc/fail(message)
	last_error = message
	return null

/datum/extraction_account_store/proc/valid_profile(list/P, owner)
	if (islist(P) && !isnull(P["credits"]) && (!isnum(P["credits"]) || P["credits"] < 0 || P["credits"] > 1000000 || round(P["credits"]) != P["credits"])) return FALSE
	if (islist(P) && !isnull(P["raid_faction"]) && !(P["raid_faction"] in list("PMC", "Scav"))) return FALSE
	if (!islist(P)) return FALSE
	if (!isnull(P["garage"]) && !valid_garage(P["garage"])) return FALSE
	if (!isnull(P["garage_purchase"]) && !valid_garage_purchase(P["garage_purchase"])) return FALSE
	var/list/stash = P["stash"]
	return P["schema"] == EXTRACTION_STORE_VERSION && P["owner"] == owner && isnum(P["revision"]) && P["revision"] >= 0 && round(P["revision"]) == P["revision"] && isnum(P["level"]) && P["level"] >= 1 && P["level"] <= 4 && round(P["level"]) == P["level"] && islist(stash) && stash.len <= 64 && (P["state"] == "home" || P["state"] == "raid") && isnum(P["raid_sequence"]) && P["raid_sequence"] >= 0 && round(P["raid_sequence"]) == P["raid_sequence"]

// Core storage checks identity/shape without depending on gameplay constructors.
// The vehicle codec validates every type, field, link and tank before decode.
/datum/extraction_account_store/proc/valid_garage(list/garage)
	if (!islist(garage) || garage.len > 1) return FALSE
	var/list/ids = list()
	for (var/i in 1 to garage.len)
		var/list/vehicle = garage[i]
		if (!islist(vehicle) || vehicle["schema"] != 1 || !islist(vehicle["nodes"])) return FALSE
		var/list/nodes = vehicle["nodes"]
		if (!nodes.len || nodes.len > 128 || !islist(nodes[1]) || nodes[1]["id"] != vehicle["id"]) return FALSE
		for (var/j in 1 to nodes.len)
			var/list/node = nodes[j]
			if (!islist(node) || !istext(node["id"]) || !length(node["id"]) || length(node["id"]) > 80 || ids[node["id"]] || !istext(node["type"])) return FALSE
			ids[node["id"]] = TRUE
		if (!isnull(vehicle["cargo"]))
			var/list/cargo = vehicle["cargo"]
			if (!islist(cargo) || cargo.len > 8) return FALSE
			for (var/k in 1 to cargo.len)
				var/list/entry = cargo[k]
				if (!islist(entry) || !istext(entry["id"]) || !islist(entry["equipment"])) return FALSE
	return TRUE

/datum/extraction_account_store/proc/valid_garage_purchase(list/purchase)
	if (!islist(purchase) || !istext(purchase["id"]) || !length(purchase["id"]) || length(purchase["id"]) > 80 || purchase["model"] != "piccolino" || !(purchase["status"] in list("pending", "complete", "forfeited")) || !isnum(purchase["paid_revision"]) || purchase["paid_revision"] < 1 || round(purchase["paid_revision"]) != purchase["paid_revision"]) return FALSE
	var/list/payment = purchase["payment"]
	if (!islist(payment)) return FALSE
	if (purchase["kind"] == "components")
		var/list/inputs = purchase["inputs"]
		if (!payment.len || payment.len > 64 || !islist(inputs) || inputs.len != payment.len) return FALSE
		for (var/i in 1 to inputs.len)
			var/list/input = inputs[i]
			if (!islist(input) || input["id"] != payment[i] || !islist(input["equipment"]) || !islist(input["equipment"]["nodes"]) || input["equipment"]["nodes"].len != 1) return FALSE
	else if (!isnull(purchase["kind"]) || payment.len != EXTRACTION_CAR_PRICE) return FALSE
	var/list/ids = list()
	for (var/id in payment)
		if (!istext(id) || !length(id) || length(id) > 80 || ids[id]) return FALSE
		ids[id] = TRUE
	return TRUE

// A newer intent without its exact committed payload blocks automatic rollback.
// The older slot may contain equipment already issued to an interrupted raid.
/datum/extraction_account_store/proc/read_slot(owner, slot)
	var/intent_path = path_for(owner, slot, "intent")
	if (!fexists(intent_path)) return list("generation" = 0)
	var/list/intent
	try
		intent = json_decode(file2text(intent_path))
	catch
		return fail("Malformed intent; preserve both slots for recovery")
	if (!islist(intent) || intent["owner"] != owner || intent["schema"] != EXTRACTION_STORE_VERSION || !isnum(intent["generation"]) || intent["generation"] < 1 || round(intent["generation"]) != intent["generation"])
		return fail("Invalid account intent")
	var/list/commit
	try
		commit = json_decode(file2text(path_for(owner, slot, "commit")))
	catch
		commit = null
	if (!islist(commit) || commit["generation"] != intent["generation"] || commit["digest"] != intent["digest"])
		return list("generation" = intent["generation"], "pending" = TRUE)
	var/payload = file2text(path_for(owner, slot, "snapshot"))
	if (!istext(payload) || length(payload) > EXTRACTION_PROFILE_LIMIT || md5(payload) != intent["digest"])
		return list("generation" = intent["generation"], "pending" = TRUE)
	var/list/profile
	try
		profile = json_decode(payload)
	catch
		return fail("Malformed committed snapshot")
	if (!valid_profile(profile, owner) || profile["revision"] != intent["generation"]) return fail("Invalid or unsupported profile")
	return list("generation" = intent["generation"], "profile" = profile)

/datum/extraction_account_store/proc/load_profile(owner)
	last_error = null
	if (!valid_owner(owner)) return fail("Stable registered account required")
	var/list/A = read_slot(owner, 0)
	var/list/B = read_slot(owner, 1)
	if (!A || !B) return null
	var/list/latest = A["generation"] > B["generation"] ? A : B
	if (latest["pending"]) return fail("Incomplete newest transfer; account locked for recovery")
	if (!latest["generation"])
		return list("schema" = EXTRACTION_STORE_VERSION, "owner" = owner, "revision" = 0, "level" = 1, "stash" = list(), "state" = "home", "raid_sequence" = 0)
	return latest["profile"]

// Native DM has no portable atomic rename. Each flushed, verified phase is
// copied into an inactive slot; its intent is the durable recovery barrier.
/datum/extraction_account_store/proc/write_phase(path, payload)
	if (inventory_write_blocked(path)) return fail("Account inventory holds a read lease")
	var/temp = "[path].pending"
	if (fexists(temp) && !fdel(temp)) return FALSE
	text2file(payload, temp)
	// text2file appends a newline; compare the exact durable representation.
	var/durable = "[payload]\n"
	if (file2text(temp) != durable) return FALSE
	if (!fcopy(temp, path) || file2text(path) != durable) return FALSE
	fdel(temp)
	return TRUE

/datum/extraction_account_store/proc/commit_profile(owner, list/P)
	last_error = null
	if (busy || !valid_owner(owner) || !valid_profile(P, owner)) return fail("Invalid or concurrent write")
	busy = TRUE
	var/list/A = read_slot(owner, 0)
	var/list/B = read_slot(owner, 1)
	if (!A || !B || A["pending"] || B["pending"])
		busy = FALSE
		return fail("Account requires recovery")
	var/generation = max(A["generation"], B["generation"]) + 1
	if (P["revision"] != generation - 1 || generation > 1000000)
		busy = FALSE
		return fail("Stale revision or exhausted generation budget")
	var/list/candidate = P.Copy()
	candidate["revision"] = generation
	var/payload = json_encode(candidate)
	if (length(payload) > EXTRACTION_PROFILE_LIMIT)
		busy = FALSE
		return fail("Profile exceeds byte budget")
	var/slot = A["generation"] <= B["generation"] ? 0 : 1
	var/digest = md5("[payload]\n")
	var/intent = json_encode(list("schema" = EXTRACTION_STORE_VERSION, "owner" = owner, "generation" = generation, "digest" = digest))
	var/success = write_phase(path_for(owner, slot, "intent"), intent)
	if (success && test_fail_at != "intent") success = write_phase(path_for(owner, slot, "snapshot"), payload)
	else success = FALSE
	if (success && test_fail_at != "snapshot") success = write_phase(path_for(owner, slot, "commit"), json_encode(list("generation" = generation, "digest" = digest)))
	else success = FALSE
	busy = FALSE
	if (!success) return fail("Interrupted transfer; account locked for recovery")
	var/list/check = read_slot(owner, slot)
	if (!check || check["pending"] || check["generation"] != generation) return fail("Commit readback failed")
	P["revision"] = generation
	return TRUE

// OFFLINE operator recovery only. Never called by login, map startup or timers.
// The caller must stop the sole server using this directory and preserve it.
// Complete only the exact intended bytes; never reconstruct from an older slot.
/datum/extraction_account_store/proc/recover_snapshot(owner, generation, digest)
	last_error = null
	if (busy || !valid_owner(owner) || !isnum(generation) || !istext(digest) || length(digest) != 32) return fail("Invalid recovery request")
	var/list/A = read_slot(owner, 0)
	var/list/B = read_slot(owner, 1)
	if (!A || !B || A["generation"] == B["generation"]) return fail("Ambiguous recovery slots")
	var/slot = A["generation"] > B["generation"] ? 0 : 1
	var/list/latest = slot == 0 ? A : B
	var/list/previous = slot == 0 ? B : A
	if (!latest["pending"] || previous["pending"] || latest["generation"] != generation || generation != previous["generation"] + 1 || generation > 1000000) return fail("Recovery requires the next incomplete revision")
	var/list/intent
	var/list/candidate
	var/payload = file2text(path_for(owner, slot, "snapshot"))
	try
		intent = json_decode(file2text(path_for(owner, slot, "intent")))
		candidate = json_decode(payload)
	catch
		return fail("Intended snapshot unavailable; retain lock and evidence")
	if (!istext(payload) || length(payload) > EXTRACTION_PROFILE_LIMIT || intent["digest"] != digest || md5(payload) != digest || !valid_profile(candidate, owner) || candidate["revision"] != generation) return fail("Intended snapshot does not match recovery request")
	if (!recovery_ownership_clear(owner, candidate)) return null
	// One bounded receipt blocks accidental repeated recovery or evidence overwrite.
	var/receipt = "[root][owner]/recovery.latest.json"
	if (fexists(receipt)) return fail("Archive existing recovery receipt before another recovery")
	busy = TRUE
	var/evidence = json_encode(list("schema" = 1, "owner" = owner, "generation" = generation, "digest" = digest, "intent" = file2text(path_for(owner, slot, "intent")), "snapshot" = payload, "previous_commit" = file2text(path_for(owner, slot, "commit"))))
	var/success = write_phase(receipt, evidence)
	if (success) success = write_phase(path_for(owner, slot, "commit"), json_encode(list("generation" = generation, "digest" = digest)))
	busy = FALSE
	if (!success) return fail("Recovery write interrupted; preserve receipt and slots")
	var/list/check = read_slot(owner, slot)
	if (!check || check["pending"] || check["generation"] != generation) return fail("Recovery readback failed")
	return check["profile"]

/datum/extraction_account_store/proc/recovery_ids(list/P)
	var/list/ids = list()
	if (!isnull(P["garage"]))
		if (!valid_garage(P["garage"])) return null
		for (var/list/vehicle in P["garage"])
			for (var/list/node in vehicle["nodes"]) ids[node["id"]] = TRUE
	var/list/stash = P["stash"].Copy()
	if (islist(P["garage_purchase"]) && P["garage_purchase"]["kind"] == "components" && P["garage_purchase"]["status"] == "pending")
		stash += P["garage_purchase"]["inputs"]
	for (var/list/vehicle in P["garage"])
		for (var/list/entry in vehicle["cargo"]) stash += list(entry)
	if (islist(P["insurance_mailbox"]))
		stash = stash.Copy()
		for (var/list/entry in P["insurance_mailbox"]) stash += list(entry)
	for (var/list/entry in stash)
		if (!islist(entry) || !istext(entry["id"]) || !length(entry["id"]) || ids[entry["id"]]) return null
		var/list/graph = entry["equipment"]
		if (!islist(graph)) return null
		if (graph["schema"] == 2)
			var/list/nodes = graph["nodes"]
			if (!islist(nodes) || !nodes.len || nodes.len > 512) return null
			var/list/root_node = nodes[1]
			if (!islist(root_node) || root_node["id"] != entry["id"]) return null
			for (var/list/node in nodes)
				if (!islist(node) || !istext(node["id"]) || !length(node["id"]) || ids[node["id"]] || ids.len >= 2048) return null
				ids[node["id"]] = TRUE
				if (!isnull(node["packed_wheel"]))
					var/list/wheel = node["packed_wheel"]
					if (!islist(wheel) || !istext(wheel["id"]) || !length(wheel["id"]) || length(wheel["id"]) > 80 || ids[wheel["id"]] || ids.len >= 2048) return null
					ids[wheel["id"]] = TRUE
		else
			// Opaque journal fixtures have no schema. Legacy equipment lacks node
			// identities and needs manual reconciliation rather than inferred safety.
			if (graph["schema"]) return null
			ids[entry["id"]] = TRUE
	return ids

// Compare current ownership across the same store before crediting recovered
// items. A failed extraction could leave a physical copy looted by another
// account before shutdown. Pending/malformed other accounts block inference.
/datum/extraction_account_store/proc/recovery_ownership_clear(owner, list/P)
	var/list/wanted = recovery_ids(P)
	if (!islist(wanted)) return fail("Recovery equipment identities require manual reconciliation")
	if (!mail_ownership_clear(wanted)) return fail("Recovered identity remains in insurance mail")
	if (!wanted.len) return TRUE
	var/list/entries = flist(root)
	if (entries.len > 4096) return fail("Offline ownership inventory exceeds 4096 entries")
	for (var/name in entries)
		if (copytext(name, length(name), 0) != "/") continue
		var/other = copytext(name, 1, length(name))
		if (other == "_settlement" || other == "_insurance" || other == "_bot" || other == "_mail") continue
		if (other == owner) continue
		if (!valid_owner(other)) return fail("Unknown directory in ownership inventory")
		var/list/other_profile = load_profile(other)
		if (!other_profile) return fail("Other account unresolved; preserve ownership evidence")
		var/list/ids = recovery_ids(other_profile)
		if (!islist(ids)) return fail("Other account equipment identities require reconciliation")
		for (var/id in wanted)
			if (ids[id]) return fail("Recovered identity is already held by another account")
	return TRUE

/datum/extraction_account_store/proc/mail_ownership_clear(list/ids)
	var/datum/extraction_account_store/mail = new
	mail.root = "[root]_mail/"
	if (!fexists("[mail.root]format.json")) return TRUE
	if (file2text("[mail.root]format.json") != "{\"schema\":1}\n") return FALSE
	for (var/id in ids)
		var/list/index = mail.load_profile(md5(json_encode(list(null, "node", id))))
		if (!index || (index["revision"] && index["item_id"] != id) || index["active"]) return FALSE
	return TRUE

// OFFLINE loot reconciliation after snapshot recovery. The uncertain item is
// permanently retired, not returned to the container or credited to an account.
/datum/extraction_account_store/proc/retire_pending_delivery(owner, generation, item_id)
	var/list/P = load_profile(owner)
	if (!P || P["revision"] != generation || P["loot_state"] != "pending") return fail("Pending delivery revision changed")
	var/list/entry = P["pending_item"]
	if (!islist(entry) || !istext(item_id) || entry["id"] != item_id) return fail("Pending delivery identity changed")
	P["loot_state"] = "ready"
	P["pending_item"] = null
	P["retired_delivery"] = list("id" = item_id, "revision" = generation)
	if (!commit_profile(owner, P)) return null
	return P

// OFFLINE resolution of an acknowledged debit with uncertain car construction.
/datum/extraction_account_store/proc/retire_pending_vehicle(owner, generation, purchase_id)
	var/list/P = load_profile(owner)
	if (!P || P["revision"] != generation || !islist(P["garage_purchase"])) return fail("Pending vehicle revision changed")
	var/list/purchase = P["garage_purchase"]
	if (!istext(purchase_id) || purchase["id"] != purchase_id || purchase["status"] != "pending") return fail("Pending vehicle identity changed")
	var/receipt = "[root][owner]/garage-recovery.latest.json"
	if (fexists(receipt)) return fail("Archive existing garage recovery receipt before another forfeiture")
	if (!write_phase(receipt, json_encode(list("schema" = 1, "action" = "forfeit-uncertain-paid-car", "owner" = owner, "revision" = generation, "purchase" = purchase.Copy(), "before" = P)))) return fail("Garage forfeiture receipt unavailable")
	P["garage"] = list()
	P["garage_purchase"]["status"] = "forfeited"
	P["garage_purchase"]["discarded_revision"] = generation
	if (!commit_profile(owner, P)) return null
	return P

// Explicit OFFLINE loss settlement when the intended bytes cannot be recovered.
// Empty the entire stash rather than guessing which prior items were issued.
// No item, upgrade or delivery can be recreated from the preceding snapshot.
/datum/extraction_account_store/proc/settle_pending_loss(owner, generation, digest)
	if (busy || !valid_owner(owner) || !isnum(generation) || !istext(digest) || length(digest) != 32) return fail("Invalid loss settlement request")
	var/list/A = read_slot(owner, 0)
	var/list/B = read_slot(owner, 1)
	if (!A || !B || A["generation"] == B["generation"]) return fail("Ambiguous settlement slots")
	var/slot = A["generation"] > B["generation"] ? 0 : 1
	var/list/latest = slot == 0 ? A : B
	var/list/previous = slot == 0 ? B : A
	if (!latest["pending"] || previous["pending"] || latest["generation"] != generation || generation != previous["generation"] + 1 || generation > 1000000) return fail("Settlement requires the next incomplete revision")
	var/list/intent = json_decode(file2text(path_for(owner, slot, "intent")))
	if (intent["digest"] != digest) return fail("Settlement intent changed")
	var/list/P = previous["generation"] ? json_decode(json_encode(previous["profile"])) : list("schema" = 1, "owner" = owner, "level" = 1, "raid_sequence" = 0)
	P["revision"] = generation
	P["stash"] = list()
	P["garage"] = list()
	P["state"] = "home"
	P["raid_sequence"]++
	P["loot_state"] = "ready"
	P["loot_plan"] = null
	P["pending_item"] = null
	P["loss_settlement"] = list("revision" = generation, "discarded_intent_digest" = digest)
	if (!valid_profile(P, owner)) return fail("Invalid settlement candidate")
	var/receipt = "[root][owner]/recovery.latest.json"
	if (fexists(receipt)) return fail("Archive existing recovery receipt before loss settlement")
	var/list/evidence = list("schema" = 1, "action" = "discard-account-stash", "owner" = owner, "generation" = generation, "digest" = digest)
	for (var/i in 0 to 1)
		for (var/suffix in list("intent", "snapshot", "commit")) evidence["[i].[suffix]"] = file2text(path_for(owner, i, suffix))
	busy = TRUE
	var/success = write_phase(receipt, json_encode(evidence))
	var/payload = json_encode(P)
	var/new_digest = md5("[payload]\n")
	if (success) success = write_phase(path_for(owner, slot, "intent"), json_encode(list("schema" = 1, "owner" = owner, "generation" = generation, "digest" = new_digest)))
	if (success) success = write_phase(path_for(owner, slot, "snapshot"), payload)
	if (success) success = write_phase(path_for(owner, slot, "commit"), json_encode(list("generation" = generation, "digest" = new_digest)))
	busy = FALSE
	if (!success) return fail("Loss settlement interrupted; preserve receipt and slots")
	var/list/check = read_slot(owner, slot)
	if (!check || check["pending"] || check["generation"] != generation) return fail("Loss settlement readback failed")
	return check["profile"]
/proc/extraction_insurance_generation(value)
	return isnum(value) && value >= 0 && value <= 16777215 && round(value) == value
