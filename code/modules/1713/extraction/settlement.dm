// One bounded shared receipt gates account access while projections are pending.
// Internal game authority only: this is not a network or bot command handler.
#define EXTRACTION_SETTLEMENT_PARTICIPANTS 16
#define EXTRACTION_SETTLEMENT_HISTORY 128

/datum/extraction_settlement
	var/datum/extraction_service/service
	var/datum/extraction_account_store/journal = new
	var/list/profile
	var/blocked = FALSE
	var/busy = FALSE
	var/test_fail_at
	var/datum/test_access_observer
	var/last_error
	New(datum/extraction_service/S)
		..()
		service = S
	proc/fail(message)
		last_error = message
		blocked = TRUE
		return FALSE
	proc/ready()
		if (busy || blocked) return FALSE
		if (!profile)
			journal.root = "[service.store.root]_settlement/"
			profile = journal.load_profile("world")
			if (!profile && !repair_journal()) return fail("Shared journal requires recovery")
			if (!profile["sequence"]) profile["sequence"] = 0
			if (!profile["history"]) profile["history"] = list()
			if (!profile["phase"]) profile["phase"] = "committed"
		if (profile["phase"] == "pending") return settle()
		if (profile["phase"] != "committed" || !isnum(profile["sequence"]) || profile["sequence"] < 0 || round(profile["sequence"]) != profile["sequence"] || profile["sequence"] > 1000000 || !islist(profile["history"]) || profile["history"].len > EXTRACTION_SETTLEMENT_HISTORY) return fail("Invalid shared journal state")
		return TRUE
	proc/wallet(list/P)
		return isnull(P["credits"]) ? 0 : P["credits"]
	proc/valid_wallet(list/P)
		var/value = wallet(P)
		// Sixteen participant sums remain exactly representable by DM numbers.
		return isnum(value) && value >= 0 && value <= 1000000 && round(value) == value
	proc/valid_participants(list/parts)
		if (!islist(parts) || parts.len < 1 || parts.len > EXTRACTION_SETTLEMENT_PARTICIPANTS) return FALSE
		var/list/owners = list()
		var/list/before_ids = list()
		var/list/after_ids = list()
		var/list/before_graphs = list()
		var/list/after_graphs = list()
		var/before_money = 0
		var/after_money = 0
		for (var/list/part in parts)
			if (!islist(part) || !service.store.valid_owner(part["owner"]) || owners[part["owner"]]) return FALSE
			var/owner = part["owner"]
			owners[owner] = TRUE
			var/list/before = part["before"]
			var/list/after = part["after"]
			if (!service.store.valid_profile(before, owner) || !service.store.valid_profile(after, owner) || before["state"] != "home" || after["state"] != "home" || after["revision"] != before["revision"] + 1 || before["level"] != after["level"] || before["raid_sequence"] != after["raid_sequence"] || !valid_wallet(before) || !valid_wallet(after)) return FALSE
			var/datum/extraction_session/validator = new
			if (!validator.valid_entries(before["stash"], before["level"] * 16) || !validator.valid_entries(after["stash"], after["level"] * 16)) return FALSE
			var/list/old_ids = service.store.recovery_ids(before)
			var/list/new_ids = service.store.recovery_ids(after)
			if (!islist(old_ids) || !islist(new_ids)) return FALSE
			for (var/list/entry in before["stash"]) before_graphs[entry["id"]] = md5(json_encode(entry["equipment"]))
			for (var/list/entry in after["stash"]) after_graphs[entry["id"]] = md5(json_encode(entry["equipment"]))
			for (var/id in old_ids)
				if (before_ids[id]) return FALSE
				before_ids[id] = TRUE
			for (var/id in new_ids)
				if (after_ids[id]) return FALSE
				after_ids[id] = TRUE
			before_money += wallet(before)
			after_money += wallet(after)
		if (before_money != after_money || before_ids.len != after_ids.len || before_ids.len > 4096) return FALSE
		for (var/id in before_ids)
			if (!after_ids[id]) return FALSE
		if (before_graphs.len != after_graphs.len) return FALSE
		for (var/id in before_graphs)
			if (after_graphs[id] != before_graphs[id]) return FALSE
		return TRUE
	proc/repair_journal()
		var/list/A = journal.read_slot("world", 0)
		var/list/B = journal.read_slot("world", 1)
		if (!A || !B || A["generation"] == B["generation"]) return FALSE
		var/slot = A["generation"] > B["generation"] ? 0 : 1
		var/list/latest = slot == 0 ? A : B
		var/list/previous = slot == 0 ? B : A
		if (!latest["pending"] || previous["pending"] || latest["generation"] != previous["generation"] + 1) return FALSE
		var/list/before = previous["profile"]
		if (!previous["generation"]) before = list("schema" = 1, "owner" = "world", "revision" = 0, "level" = 1, "stash" = list(), "state" = "home", "raid_sequence" = 0)
		var/list/intent = json_decode(file2text(journal.path_for("world", slot, "intent")))
		var/payload = file2text(journal.path_for("world", slot, "snapshot"))
		var/list/candidate
		if (istext(payload) && length(payload) <= EXTRACTION_PROFILE_LIMIT && md5(payload) == intent["digest"])
			try
				candidate = json_decode(payload)
			catch
				return FALSE
		if (before["phase"] == "pending")
			// A prior committed receipt authorizes only its exact final state.
			profile = before
			if (!valid_participants(profile["participants"]) || md5(json_encode(profile["participants"])) != profile["request_digest"]) return FALSE
			for (var/list/part in profile["participants"])
				if (!apply_projection(service.store, part["owner"], part["before"], part["after"])) return FALSE
			candidate = final_profile()
			candidate["revision"] = latest["generation"]
			if (md5("[json_encode(candidate)]\n") != intent["digest"]) return FALSE
		else
			// A complete initial receipt may lack only its commit acknowledgement.
			// An intent alone cannot reconstruct an unknown new transaction.
			if (!candidate || candidate["phase"] != "pending" || candidate["sequence"] != (before["sequence"] ? before["sequence"] : 0) + 1 || !valid_participants(candidate["participants"]) || md5(json_encode(candidate["participants"])) != candidate["request_digest"]) return FALSE
		if (!journal.valid_profile(candidate, "world") || candidate["revision"] != latest["generation"] || !apply_projection(journal, "world", before, candidate)) return FALSE
		profile = candidate
		return TRUE
	// Only released accounts can participate: their home representations have
	// already been retired. Future live adapters must prepare that boundary first.
	proc/submit(sequence, list/parts)
		if (!ready()) return FALSE
		var/digest = md5(json_encode(parts))
		var/list/history = profile["history"]
		for (var/list/receipt in history)
			if (receipt["sequence"] == sequence) return receipt["digest"] == digest
		if (!isnum(sequence) || round(sequence) != sequence || sequence != profile["sequence"] + 1 || sequence > 1000000 || !valid_participants(parts)) return FALSE
		for (var/list/part in parts)
			if (service.sessions[part["owner"]]) return FALSE
			var/list/current = service.store.load_profile(part["owner"])
			if (!current || md5(json_encode(current)) != md5(json_encode(part["before"]))) return FALSE
		// Check nonparticipant ownership too. Existing duplicates are not made
		// legitimate by moving them through a shared transaction.
		if (!outside_ownership_clear(parts)) return FALSE
		if (test_fail_at == "before_receipt") return FALSE
		var/list/candidate = json_decode(json_encode(profile))
		candidate["sequence"] = sequence
		candidate["phase"] = "pending"
		candidate["participants"] = json_decode(json_encode(parts))
		candidate["request_digest"] = digest
		busy = TRUE
		var/success = journal.commit_profile("world", candidate)
		busy = FALSE
		if (!success) return fail("Shared receipt write interrupted")
		profile = candidate
		if (test_fail_at == "after_receipt") return fail("Injected interruption after receipt")
		return settle()
	proc/outside_ownership_clear(list/parts)
		var/list/owners = list()
		var/list/claimed = list()
		for (var/list/part in parts)
			owners[part["owner"]] = TRUE
			var/list/ids = service.store.recovery_ids(part["before"])
			for (var/id in ids) claimed[id] = TRUE
		var/list/files = flist(service.store.root)
		if (files.len > 4096) return FALSE
		for (var/name in files)
			if (copytext(name, length(name), 0) != "/") continue
			var/owner = copytext(name, 1, length(name))
			if (owners[owner] || owner == "_settlement") continue
			if (!service.store.valid_owner(owner)) return FALSE
			var/list/P = service.store.load_profile(owner)
			if (!P) return FALSE
			var/list/ids = service.store.recovery_ids(P)
			if (!islist(ids)) return FALSE
			for (var/id in ids)
				if (claimed[id]) return FALSE
		return TRUE
	// Exact forward projection from a committed shared receipt. This may finish
	// an incomplete account slot, including a missing snapshot, because the full
	// intended candidate and its preceding state are already durable authority.
	proc/apply_projection(datum/extraction_account_store/store, owner, list/before, list/after)
		if (store.busy) return FALSE
		var/list/A = store.read_slot(owner, 0)
		var/list/B = store.read_slot(owner, 1)
		if (!A || !B) return FALSE
		var/slot = A["generation"] > B["generation"] ? 0 : 1
		var/list/latest = slot == 0 ? A : B
		var/payload = json_encode(after)
		var/digest = md5("[payload]\n")
		if (latest["generation"] == after["revision"])
			if (!latest["pending"]) return md5(json_encode(latest["profile"])) == md5(payload)
			var/list/intent = json_decode(file2text(store.path_for(owner, slot, "intent")))
			if (intent["digest"] != digest) return FALSE
			var/list/previous = slot == 0 ? B : A
			if (previous["pending"] || previous["generation"] != before["revision"] || (previous["generation"] && md5(json_encode(previous["profile"])) != md5(json_encode(before)))) return FALSE
			store.busy = TRUE
			var/success = store.write_phase(store.path_for(owner, slot, "snapshot"), payload)
			if (success) success = store.write_phase(store.path_for(owner, slot, "commit"), json_encode(list("generation" = after["revision"], "digest" = digest)))
			store.busy = FALSE
			var/list/check = store.read_slot(owner, slot)
			return success && check && !check["pending"] && check["generation"] == after["revision"]
		if (latest["pending"] || latest["generation"] != before["revision"]) return FALSE
		var/list/current = store.load_profile(owner)
		if (!current || md5(json_encode(current)) != md5(json_encode(before))) return FALSE
		var/list/candidate = json_decode(payload)
		candidate["revision"] = before["revision"]
		return store.commit_profile(owner, candidate)
	proc/final_profile()
		var/list/final = json_decode(json_encode(profile))
		var/list/history = final["history"]
		history += list(list("sequence" = profile["sequence"], "digest" = profile["request_digest"]))
		if (history.len > EXTRACTION_SETTLEMENT_HISTORY) history.Cut(1, history.len - EXTRACTION_SETTLEMENT_HISTORY + 1)
		final["phase"] = "committed"
		final["participants"] = null
		return final
	proc/settle()
		if (busy || blocked || profile["phase"] != "pending" || !valid_participants(profile["participants"]) || md5(json_encode(profile["participants"])) != profile["request_digest"]) return fail("Invalid pending shared receipt")
		busy = TRUE
		var/list/parts = profile["participants"]
		for (var/i in 1 to parts.len)
			if (test_access_observer && !call(test_access_observer, "check")(service))
				busy = FALSE
				return fail("Injected access observer found partial visibility")
			if (test_fail_at == "before_apply[i]")
				busy = FALSE
				return fail("Injected interruption before participant apply")
			var/list/part = parts[i]
			if (!apply_projection(service.store, part["owner"], part["before"], part["after"]))
				busy = FALSE
				return fail("Participant projection requires reconciliation")
			if (test_fail_at == "after_apply[i]")
				busy = FALSE
				return fail("Injected interruption after participant apply")
		if (test_fail_at == "before_finalize")
			busy = FALSE
			return fail("Injected interruption before finalization")
		var/list/final = final_profile()
		if (test_fail_at == "finalize_intent") journal.test_fail_at = "intent"
		if (test_fail_at == "finalize_snapshot") journal.test_fail_at = "snapshot"
		var/success = journal.commit_profile("world", final)
		busy = FALSE
		if (!success) return fail("Shared finalization requires recovery")
		profile = final
		if (test_fail_at == "after_finalize") return fail("Injected interruption after finalization")
		return TRUE
