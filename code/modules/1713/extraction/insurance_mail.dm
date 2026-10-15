// Bounded shard plans. Callers must durably journal the complete plan before
// applying it, and hold their existing account/round gate until completion.
/datum/extraction_mail_store
	var/datum/extraction_service/service
	var/datum/extraction_equipment_codec/codec
	var/datum/extraction_account_store/journal = new
	var/last_error
	New(datum/extraction_service/S, datum/extraction_equipment_codec/C)
		..()
		service = S
		codec = C
		journal.root = "[S.store.root]_mail/"
	proc/fail(message)
		last_error = message
		return null
	proc/shard_key(owner, kind, sequence)
		return md5(json_encode(list(owner, kind, sequence)))
	proc/metadata(owner)
		if (!service.store.valid_owner(owner)) return fail("Invalid mail owner")
		var/list/P = journal.load_profile(shard_key(owner, "meta", null))
		if (!P) return fail("Mail metadata requires recovery")
		if (!P["revision"])
			P["mail_owner"] = owner
			P["head"] = "1"
			P["tail"] = "1"
			P["cursor_key"] = "[md5("[world.realtime]:[rand(1, 1000000000)]:[rand(1, 1000000000)]")][md5("[rand(1, 1000000000)]:[rand(1, 1000000000)]")]"
		if (P["mail_owner"] != owner || !extraction_mail_sequence(P["head"]) || !extraction_mail_sequence(P["tail"]) || !istext(P["cursor_key"]) || length(P["cursor_key"]) != 64) return fail("Invalid mail metadata")
		return P
	proc/page(owner, sequence)
		if (!extraction_mail_sequence(sequence)) return fail("Invalid mail page")
		var/list/P = journal.load_profile(shard_key(owner, "page", sequence))
		if (!P) return fail("Mail page requires recovery")
		if (!P["revision"])
			P["mail_owner"] = owner
			P["sequence"] = sequence
			P["entries"] = list()
		var/list/entries = P["entries"]
		if (P["mail_owner"] != owner || P["sequence"] != sequence || !islist(entries) || entries.len > 8) return fail("Invalid mail page")
		var/datum/extraction_session/validator = new
		if (!validator.valid_entries(entries, 8)) return fail("Invalid mail graphs")
		for (var/list/E in entries)
			if (E["equipment"]["schema"] != 2 || !codec.validate(E["equipment"])) return fail("Unsupported mail graph")
			if (!extraction_insurance_generation(E["returned_generation"]) || !extraction_insurance_generation(E["eligible_generation"]) || E["eligible_generation"] != E["returned_generation"] + 1) return fail("Invalid mail eligibility")
		return P
	proc/identity(id)
		if (!istext(id) || !length(id) || length(id) > 80) return fail("Invalid mail identity")
		var/list/P = journal.load_profile(shard_key(null, "node", id))
		if (!P || (P["revision"] && P["item_id"] != id)) return fail("Mail identity requires recovery")
		return P
	proc/operation(list/operations, owner, list/before, list/after)
		if (!before || !after || operations.len >= 4096) return FALSE
		// Defaults added by readers are not committed preceding-state bytes.
		if (!before["revision"]) before = journal.load_profile(owner)
		if (!before) return FALSE
		after["revision"] = before["revision"] + 1
		operations += list(list("owner" = owner, "before" = before, "after" = after))
		return TRUE
	proc/plan_append(owner, list/entries)
		if (!islist(entries) || entries.len > 2048) return fail("Mail append exceeds transaction budget")
		var/list/meta = metadata(owner)
		if (!meta) return null
		var/list/updated = json_decode(json_encode(meta))
		var/sequence = meta["tail"]
		var/list/old = page(owner, sequence)
		if (!old) return null
		var/list/current = json_decode(json_encode(old))
		var/list/operations = list()
		var/list/seen = list()
		var/datum/extraction_session/validator = new
		for (var/list/E in entries)
			if (!validator.valid_entries(list(E), 1) || E["equipment"]["schema"] != 2 || !extraction_insurance_generation(E["returned_generation"]) || !extraction_insurance_generation(E["eligible_generation"]) || E["eligible_generation"] != E["returned_generation"] + 1) return fail("Invalid returned graph")
			if (current["entries"].len == 8)
				var/next = extraction_mail_next(sequence)
				if (!next) return fail("Mail sequence cannot advance safely")
				current["next"] = next
				if (!operation(operations, shard_key(owner, "page", sequence), old, current)) return null
				sequence = next
				old = page(owner, sequence)
				if (!old || old["revision"]) return fail("Mail append page already exists")
				current = json_decode(json_encode(old))
			for (var/list/node in E["equipment"]["nodes"])
				var/id = node["id"]
				if (seen[id]) return fail("Repeated return identity")
				seen[id] = TRUE
				var/list/before = identity(id)
				if (!before || before["active"]) return fail("Return identity already stored")
				var/list/after = json_decode(json_encode(before))
				after["item_id"] = id
				after["mail_owner"] = owner
				after["entry_id"] = E["id"]
				after["sequence"] = sequence
				after["active"] = TRUE
				if (!operation(operations, shard_key(null, "node", id), before, after)) return null
			current["entries"] += list(json_decode(json_encode(E)))
		if (!operation(operations, shard_key(owner, "page", sequence), old, current)) return null
		updated["tail"] = sequence
		if (!operation(operations, shard_key(owner, "meta", null), meta, updated)) return null
		if (length(json_encode(operations)) > EXTRACTION_PROFILE_LIMIT - 1024) return fail("Mail transaction exceeds byte budget")
		return operations
	proc/apply(list/operations)
		if (!service.settlement) service.settlement = new(service)
		if (!islist(operations) || operations.len > 4096) return FALSE
		if (!operations.len) return TRUE
		if (!journal.write_phase("[journal.root]format.json", "{\"schema\":1}")) return FALSE
		for (var/list/part in operations)
			if (!service.settlement.apply_projection(journal, part["owner"], part["before"], part["after"])) return FALSE
		return TRUE
	proc/plan_claim(owner, list/selected_ids, generation)
		if (!islist(selected_ids) || !selected_ids.len || selected_ids.len > 16 || !extraction_insurance_generation(generation)) return fail("Invalid mail selection")
		var/list/meta = metadata(owner)
		if (!meta) return null
		var/list/pages = list()
		var/list/selected = list()
		var/list/claimed = list()
		var/list/operations = list()
		for (var/id in selected_ids)
			if (selected[id]) return fail("Repeated mail selection")
			selected[id] = TRUE
			var/list/index = identity(id)
			if (!index || !index["active"] || index["mail_owner"] != owner || index["entry_id"] != id) return fail("Mail selection is not owned")
			var/sequence = index["sequence"]
			if (!pages[sequence]) pages[sequence] = page(owner, sequence)
			var/list/P = pages[sequence]
			if (!P) return null
			var/list/found
			for (var/list/E in P["entries"])
				if (E["id"] == id) found = E
			if (!found || generation < found["eligible_generation"]) return fail("Mail return is pending")
			for (var/list/node in found["equipment"]["nodes"])
				var/list/before = identity(node["id"])
				if (!before || !before["active"] || before["mail_owner"] != owner || before["entry_id"] != id || before["sequence"] != sequence) return fail("Mail identity changed")
				var/list/after = json_decode(json_encode(before))
				after["active"] = FALSE
				if (!operation(operations, shard_key(null, "node", node["id"]), before, after)) return null
			claimed += list(json_decode(json_encode(found)))
		for (var/sequence in pages)
			var/list/before = pages[sequence]
			var/list/after = json_decode(json_encode(before))
			var/list/remaining = list()
			for (var/list/E in after["entries"])
				if (!selected[E["id"]]) remaining += list(E)
			after["entries"] = remaining
			if (!operation(operations, shard_key(owner, "page", sequence), before, after)) return null
		var/list/updated = json_decode(json_encode(meta))
		if (!operation(operations, shard_key(owner, "meta", null), meta, updated)) return null
		if (length(json_encode(operations)) > EXTRACTION_PROFILE_LIMIT - 1024) return fail("Mail claim exceeds transaction byte budget")
		return list("entries" = claimed, "operations" = operations)
	proc/transaction_final(list/P)
		var/list/final = json_decode(json_encode(P))
		final["phase"] = "complete"
		final["account_before"] = null
		final["account_after"] = null
		final["operations"] = null
		final["plan_digest"] = null
		return final
	proc/ready_owner(owner)
		var/receipt_key = shard_key(owner, "transaction", null)
		var/list/P = journal.load_profile(receipt_key)
		if (!P)
			// An interrupted final acknowledgement may be repaired from the
			// exact preceding pending receipt. Never infer a missing new plan.
			var/list/A = journal.read_slot(receipt_key, 0)
			var/list/B = journal.read_slot(receipt_key, 1)
			if (!A || !B) return FALSE
			var/list/latest = A["generation"] > B["generation"] ? A : B
			var/list/previous = A["generation"] > B["generation"] ? B : A
			P = previous["profile"]
			if (!latest["pending"] || previous["pending"] || !P || P["phase"] != "pending" || latest["generation"] != previous["generation"] + 1) return FALSE
			var/list/final = transaction_final(P)
			final["revision"]++
			if (!service.settlement) service.settlement = new(service)
			if (!service.settlement.apply_projection(journal, receipt_key, P, final)) return FALSE
			P = final
		if (!P["revision"] || P["phase"] == "complete") return TRUE
		if (P["phase"] != "pending" || P["mail_owner"] != owner || !islist(P["operations"]) || P["operations"].len > 4096 || P["plan_digest"] != md5(json_encode(list(owner, P["account_before"], P["account_after"], P["operations"])))) return FALSE
		if (!service.settlement) service.settlement = new(service)
		if (!service.settlement.apply_projection(service.store, owner, P["account_before"], P["account_after"]) || !apply(P["operations"])) return FALSE
		var/list/final = transaction_final(P)
		return journal.commit_profile(receipt_key, final)
	proc/transact(datum/extraction_session/S, list/operations, list/after)
		if (!S.active() || S.service != service || !ready_owner(S.owner) || !islist(operations) || !service.insurance_profile_valid(after) || !S.valid_entries(after["stash"], S.capacity())) return FALSE
		var/receipt_key = shard_key(S.owner, "transaction", null)
		var/list/P = journal.load_profile(receipt_key)
		if (!P) return FALSE
		P["phase"] = "pending"
		P["mail_owner"] = S.owner
		P["account_before"] = S.copy_profile()
		after["revision"] = S.profile["revision"] + 1
		P["account_after"] = after
		P["operations"] = operations
		P["plan_digest"] = md5(json_encode(list(S.owner, P["account_before"], after, operations)))
		if (length(json_encode(P)) > EXTRACTION_PROFILE_LIMIT - 64) return FALSE
		if (!journal.commit_profile(receipt_key, P) || !ready_owner(S.owner))
			S.locked = TRUE
			return FALSE
		S.profile = service.store.load_profile(S.owner)
		return !!S.profile
	proc/cursor(owner, list/meta, sequence)
		var/body = "[meta["revision"]]:[sequence]"
		return "[body]:[extraction_hmac_sha256(meta["cursor_key"], "civ13.insurance.cursor.v1:[owner]:[body]")]"
	proc/inspect(owner, account_revision, generation, supplied_cursor)
		last_error = null
		if (!extraction_insurance_generation(generation)) return fail("Invalid completed generation")
		var/list/meta = metadata(owner)
		if (!meta) return null
		var/sequence = meta["head"]
		if (!isnull(supplied_cursor))
			if (!istext(supplied_cursor) || length(supplied_cursor) > 256) return fail("invalid_cursor")
			var/list/fields = splittext(supplied_cursor, ":")
			if (fields.len != 3 || !extraction_mail_sequence(fields[2])) return fail("invalid_cursor")
			if (fields[1] != "[meta["revision"]]") return fail("stale_cursor")
			sequence = fields[2]
			var/list/expected = splittext(cursor(owner, meta, sequence), ":")
			if (!extraction_ipc_equal(fields[3], expected[3])) return fail("invalid_cursor")
		var/list/P = page(owner, sequence)
		if (!P) return null
		var/list/results = list()
		for (var/list/E in P["entries"])
			var/list/node = E["equipment"]["nodes"][1]
			var/path = text2path(node["type"])
			if (!codec.supported(path)) return fail("Unknown mail catalog entry")
			var/list/scalars = node["scalars"]
			for (var/field in list("health", "maxhealth"))
				var/value = scalars[field]
				if (!isnull(value) && (!isnum(value) || isinf(value) || isnan(value))) return fail("Invalid mail condition")
			var/catalog_name = initial(path:name)
			if (!extraction_ipc_identifier(E["id"], FALSE, 80) || length(extraction_crypto_bytes(node["type"])) > 160 || length(extraction_crypto_bytes(catalog_name)) > 128) return fail("Mail catalog projection exceeds contract")
			results += list(list("item_id" = E["id"], "type" = node["type"], "name" = catalog_name, "condition" = list("health" = scalars["health"], "maxhealth" = scalars["maxhealth"]), "found_in_raid" = !!node["found_in_raid"], "returned_generation" = E["returned_generation"], "eligible_generation" = E["eligible_generation"], "state" = generation >= E["eligible_generation"] ? "eligible" : "pending"))
		var/list/result = list("account_revision" = account_revision, "mail_revision" = meta["revision"], "completed_generation" = generation, "expiration" = "to be implemented", "entries" = results, "next_cursor" = P["next"] ? cursor(owner, meta, P["next"]) : null)
		if (length(extraction_crypto_bytes(json_encode(result))) > 8192) return fail("Mail inspection exceeds byte budget")
		return result

// Text sequences avoid coupling total retained entries to native integer range.
/proc/extraction_mail_sequence(value)
	if (!istext(value) || !length(value) || length(value) > 100 || copytext(value, 1, 2) == "0") return FALSE
	for (var/i = 1, i <= length(value), i++)
		var/n = text2ascii(value, i)
		if (n < 48 || n > 57) return FALSE
	return TRUE

/proc/extraction_mail_next(value)
	if (!extraction_mail_sequence(value)) return null
	var/result = ""
	var/carry = 1
	for (var/i = length(value), i >= 1, i--)
		var/n = text2ascii(value, i) - 48 + carry
		carry = n >= 10
		result = "[n % 10][result]"
	if (carry) result = "1[result]"
	return extraction_mail_sequence(result) ? result : null
