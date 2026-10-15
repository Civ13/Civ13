// Explicit round-end disk inventory, never a world scan or recurring timer.
// This read-only index is not authority to create returned items.
#define EXTRACTION_INSURANCE_INDEX_NODES 4096
#define EXTRACTION_INSURANCE_INDEX_ACCOUNTS 4096

/datum/extraction_insurance_inventory
	var/datum/extraction_service/service
	var/last_error
	var/list/revisions
	var/list/claims
	var/list/recovered
	var/list/current_owners
	var/tmp/datum/test_access_observer
	New(datum/extraction_service/S)
		..()
		service = S
	proc/fail(message)
		last_error = message
		return null
	proc/build(round_id)
		if (!service || !service.settlement_ready() || !istext(round_id) || !length(round_id) || length(round_id) > 64) return fail("Insurance inventory unavailable")
		service.insurance_busy = TRUE
		var/list/result
		try
			result = index_round(round_id)
		catch
			last_error = "Insurance inventory requires recovery"
		service.insurance_busy = FALSE
		return result
	proc/revalidate()
		// A consumer must retain this service gate through its durable receipt.
		if (!service || !service.insurance_busy || !islist(revisions)) return FALSE
		var/list/files = flist(service.store.root)
		if (files.len > EXTRACTION_INSURANCE_INDEX_ACCOUNTS) return FALSE
		var/count = 0
		for (var/name in files)
			if (copytext(name, length(name), 0) != "/") continue
			var/owner = copytext(name, 1, length(name))
			if (owner == "_settlement" || owner == "_insurance" || owner == "_bot" || owner == "_mail") continue
			if (!revisions[owner]) return FALSE
			count++
			var/list/P = service.store.load_profile(owner)
			if (!P || md5(json_encode(P)) != revisions[owner]["digest"]) return FALSE
		return count == revisions.len
	proc/index_round(round_id)
		revisions = list()
		claims = list()
		recovered = list()
		current_owners = list()
		var/list/accounts = list()
		var/list/wanted_ids = list()
		var/list/files = flist(service.store.root)
		if (files.len > EXTRACTION_INSURANCE_INDEX_ACCOUNTS) return fail("Insurance account inventory exceeds budget")
		for (var/name in files)
			if (copytext(name, length(name), 0) != "/") continue
			var/owner = copytext(name, 1, length(name))
			if (owner == "_settlement" || owner == "_insurance" || owner == "_bot" || owner == "_mail") continue
			if (!service.store.valid_owner(owner)) return fail("Unknown account directory")
			accounts += owner
			var/datum/extraction_mail_store/mail = service.mail_service()
			if (!mail.ready_owner(owner)) return fail("Unresolved insurance mail transaction")
			var/list/P = service.store.load_profile(owner)
			if (!P || !service.insurance_profile_valid(P)) return fail("Unresolved account ownership records")
			revisions[owner] = list("revision" = P["revision"], "digest" = md5(json_encode(P)))
			var/list/archive = P["insurance_claims"]
			if (!archive) continue
			for (var/list/claim in archive)
				if (claim["round"] != round_id) continue
				for (var/list/node in claim["entry"]["equipment"]["nodes"])
					var/token = node["insurance_token"]
					if (claims[token] || claims.len >= EXTRACTION_INSURANCE_INDEX_NODES) return fail("Insurance claim index exceeds budget or repeats tokens")
					claims[token] = list("owner" = owner, "id" = node["id"], "sequence" = claim["sequence"], "type" = node["type"])
					wanted_ids[node["id"]] = TRUE
		if (test_access_observer && !call(test_access_observer, "check")(service)) return fail("Insurance inventory exposed an ungated account")
		// Only IDs and tokens relevant to this round enter the memory index.
		for (var/owner in accounts)
			var/list/P = service.store.load_profile(owner)
			if (!P || md5(json_encode(P)) != revisions[owner]["digest"]) return fail("Account changed during insurance inventory")
			var/list/tokens = P["insurance_recovered"]
			if (tokens)
				for (var/token in tokens)
					if (claims[token]) recovered[token] = TRUE
			var/list/ids = service.store.recovery_ids(P)
			if (!islist(ids)) return fail("Stored ownership identities require reconciliation")
			for (var/id in ids)
				if (!wanted_ids[id]) continue
				if (current_owners[id]) return fail("Stored identity is held by multiple accounts")
				current_owners[id] = owner
		var/datum/extraction_mail_store/mail = service.mail_service()
		for (var/id in wanted_ids)
			var/list/stored = mail.identity(id)
			if (!stored) return fail("Mail ownership index requires recovery")
			if (stored["active"])
				if (current_owners[id]) return fail("Stored identity is duplicated in mail")
				current_owners[id] = stored["mail_owner"]
		var/list/result = list()
		if (!service.npc_journal) service.npc_journal = new(service)
		var/list/npc_recovered = service.npc_journal.recovered(round_id)
		if (!islist(npc_recovered)) return fail("NPC extraction retirement requires recovery")
		for (var/token in npc_recovered)
			var/list/claim = claims[token]
			if (!claim) continue
			var/list/retired = npc_recovered[token]
			if (claim["id"] != retired["id"] || claim["type"] != retired["type"]) return fail("NPC extraction token does not match insured identity")
			recovered[token] = TRUE
		var/list/unrecovered_ids = list()
		for (var/token in claims)
			var/list/claim = claims[token]
			var/status = recovered[token] ? "recovered" : (current_owners[claim["id"]] ? "stored" : "unrecovered")
			if (status == "unrecovered")
				if (unrecovered_ids[claim["id"]]) return fail("Competing unrecovered claims require reconciliation")
				unrecovered_ids[claim["id"]] = TRUE
			result[token] = list("owner" = claim["owner"], "id" = claim["id"], "sequence" = claim["sequence"], "status" = status)
		return result
