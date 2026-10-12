// Bounded two-slot account journal. Incomplete transfers fail closed.
#define EXTRACTION_STORE_VERSION 1
#define EXTRACTION_PROFILE_LIMIT 2097152

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
	if (islist(P) && !isnull(P["raid_faction"]) && !(P["raid_faction"] in list("PMC", "Scav"))) return FALSE
	if (!islist(P)) return FALSE
	var/list/stash = P["stash"]
	return P["schema"] == EXTRACTION_STORE_VERSION && P["owner"] == owner && isnum(P["revision"]) && P["revision"] >= 0 && round(P["revision"]) == P["revision"] && isnum(P["level"]) && P["level"] >= 1 && P["level"] <= 4 && round(P["level"]) == P["level"] && islist(stash) && stash.len <= 64 && (P["state"] == "home" || P["state"] == "raid") && isnum(P["raid_sequence"]) && P["raid_sequence"] >= 0 && round(P["raid_sequence"]) == P["raid_sequence"]

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
	var/list/stash = P["stash"]
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
	if (!wanted.len) return TRUE
	var/list/entries = flist(root)
	if (entries.len > 4096) return fail("Offline ownership inventory exceeds 4096 entries")
	for (var/name in entries)
		if (copytext(name, length(name), 0) != "/") continue
		var/other = copytext(name, 1, length(name))
		if (other == owner) continue
		if (!valid_owner(other)) return fail("Unknown directory in ownership inventory")
		var/list/other_profile = load_profile(other)
		if (!other_profile) return fail("Other account unresolved; preserve ownership evidence")
		var/list/ids = recovery_ids(other_profile)
		if (!islist(ids)) return fail("Other account equipment identities require reconciliation")
		for (var/id in wanted)
			if (ids[id]) return fail("Recovered identity is already held by another account")
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
