// Read-only auxiliary ownership census. Never call ready(), repair or decode.
// The account-root lease remains held; external writer exclusion is host-owned.
/datum/extraction_surface_service
	var/list/auxiliary_records
	var/auxiliary_cursor = 1
	var/auxiliary_verify_cursor = 1
	var/list/mail_meta = list()
	var/list/mail_pages = list()
	var/list/mail_expected_nodes = list()
	var/list/mail_active_nodes = list()
	var/mail_meta_cursor = 1
	var/mail_sequence
	var/list/mail_seen_pages = list()
	var/mail_node_cursor = 1
	proc/auxiliary_manifest()
		var/list/result = list()
		var/account_root = metadata.accounts.store.root
		for (var/kind in list("settlement", "groups", "insurance", "rounds", "npc", "bot", "mail"))
			var/suffix
			switch (kind)
				if ("settlement") suffix = "_settlement/"
				if ("groups") suffix = "_settlement/groups/"
				if ("insurance") suffix = "_insurance/"
				if ("rounds") suffix = "_insurance/_rounds/"
				if ("npc") suffix = "_insurance/_npc/"
				if ("bot") suffix = "_bot/"
				if ("mail") suffix = "_mail/"
			var/root = "[account_root][suffix]"
			var/list/files = flist(root)
			if (!islist(files) || files.len > 4096) return null
			if (kind == "mail" && files.len && file2text("[root]format.json") != "{\"schema\":1}\n") return null
			for (var/name in files)
				if (kind == "settlement" && name == "groups/") continue
				if (kind == "insurance" && (name in list("_rounds/", "_npc/"))) continue
				if (kind == "mail" && name == "format.json") continue
				if (copytext(name, length(name)) != "/") return null
				var/owner = copytext(name, 1, length(name))
				if ((kind in list("settlement", "groups", "insurance", "bot")) && owner != "world") return null
				if (!(kind in list("settlement", "groups", "insurance", "bot")) && (!extraction_ipc_identifier(owner, FALSE, 32) || length(owner) != 32)) return null
				if (result.len >= 4096) return null
				result["[kind]/[owner]"] = list("kind" = kind, "root" = root, "owner" = owner)
		return result
	proc/begin_auxiliary_inventory()
		if (enabled || discovery_locked || auxiliary_records || !account_inventory_complete || !account_inventory_lease_valid() || metadata.accounts.sessions.len) return discovery_fail()
		auxiliary_records = auxiliary_manifest()
		if (!islist(auxiliary_records)) return discovery_fail()
		return TRUE
	proc/auxiliary_record_valid(list/record, list/P)
		if (!islist(P) || !P["revision"] || P["state"] != "home" || !islist(P["stash"]) || P["stash"].len || (!isnull(P["garage"]) && (!islist(P["garage"]) || P["garage"].len)) || (!isnull(P["insurance_mailbox"]) && (!islist(P["insurance_mailbox"]) || P["insurance_mailbox"].len)) || !isnull(P["garage_purchase"]) || P["pending_delivery"] || P["pending_item"]) return FALSE
		var/kind = record["kind"]
		if (kind in list("settlement", "groups"))
			if (P["phase"] != "committed" || !isnull(P["participants"]) || !isnum(P["sequence"]) || P["sequence"] < 0 || P["sequence"] > 1000000 || round(P["sequence"]) != P["sequence"] || !islist(P["history"]) || P["history"].len > 128) return FALSE
			for (var/index in 1 to P["history"].len)
				var/list/entry = P["history"][index]
				if (!islist(entry) || !isnum(entry["sequence"]) || entry["sequence"] < 1 || entry["sequence"] > P["sequence"] || !extraction_ipc_identifier(entry["digest"], FALSE, 32) || length(entry["digest"]) != 32) return FALSE
			return TRUE
		if (kind == "insurance")
			return P["phase"] == "complete" && extraction_insurance_generation(P["completed_generation"]) && isnull(P["parts"]) && isnull(P["physical"]) && isnull(P["mail_operations"]) && isnull(P["round_marker"])
		if (kind == "rounds")
			return istext(P["resolved_round"]) && length(P["resolved_round"]) && length(P["resolved_round"]) <= 64 && md5(P["resolved_round"]) == record["owner"] && extraction_insurance_generation(P["completed_generation"]) && extraction_ipc_identifier(P["plan_digest"], FALSE, 32) && length(P["plan_digest"]) == 32
		if (kind == "npc")
			if (P["phase"] != "complete" || !islist(P["npc_receipts"]) || P["npc_receipts"].len > 128) return FALSE
			for (var/index in 1 to P["npc_receipts"].len)
				var/list/receipt = P["npc_receipts"][index]
				if (!islist(receipt) || !islist(receipt["graphs"]) || receipt["graphs"].len > 8 || receipt["digest"] != md5(json_encode(receipt["graphs"])) || !isnum(receipt["fee"]) || receipt["fee"] < 0 || receipt["fee"] > 1000000 || !(receipt["faction"] in list("PMC", "Scav"))) return FALSE
				for (var/graph_index in 1 to receipt["graphs"].len)
					if (!graph_ids(receipt["graphs"][graph_index], 2048)) return FALSE
			// Complete retirement histories are not current owned graphs or tombstones.
			return TRUE
		if (kind == "bot")
			if (!islist(P["receipts"]) || P["receipts"].len > 1000 || !islist(P["quotes"]) || P["quotes"].len > 64) return FALSE
			for (var/id in P["receipts"])
				var/list/receipt = P["receipts"][id]
				if (!islist(receipt) || extraction_sha256(receipt["request_id"]) != id || !extraction_ipc_receipt(receipt["response"], receipt["request_id"], receipt["discord_id"], receipt["request_digest"])) return FALSE
			return TRUE
		return kind == "mail" && census_mail_record(record["owner"], P)
	proc/census_mail_record(key, list/P)
		var/owner = P["mail_owner"]
		if (!metadata.accounts.store.valid_owner(owner)) return FALSE
		if (!isnull(P["item_id"]))
			if (!isnull(P["head"]) || !isnull(P["phase"]) || !isnull(P["entries"])) return FALSE
			var/id = P["item_id"]
			if (!extraction_ipc_identifier(id, FALSE, 80) || key != md5(json_encode(list(null, "node", id))) || !(P["active"] in list(TRUE, FALSE)) || !extraction_ipc_identifier(P["entry_id"], FALSE, 80) || !extraction_mail_sequence(P["sequence"])) return FALSE
			if (P["active"])
				if (mail_active_nodes[id] || mail_active_nodes.len >= 2048) return FALSE
				mail_active_nodes[id] = list(owner, P["sequence"], P["entry_id"])
			return TRUE
		if (!account_inventory_names[owner]) return FALSE
		if (!isnull(P["head"]))
			if (!isnull(P["sequence"]) || !isnull(P["phase"]) || !isnull(P["entries"])) return FALSE
			if (key != md5(json_encode(list(owner, "meta", null))) || P["head"] != "1" || !extraction_mail_sequence(P["tail"]) || !extraction_ipc_identifier(P["cursor_key"], FALSE, 64) || length(P["cursor_key"]) != 64 || mail_meta[owner]) return FALSE
			mail_meta[owner] = list("tail" = P["tail"])
			return TRUE
		if (!isnull(P["phase"]))
			if (!isnull(P["sequence"]) || !isnull(P["entries"])) return FALSE
			return key == md5(json_encode(list(owner, "transaction", null))) && P["phase"] == "complete" && isnull(P["account_before"]) && isnull(P["account_after"]) && isnull(P["operations"]) && isnull(P["plan_digest"])
		var/sequence = P["sequence"]
		if (!extraction_mail_sequence(sequence) || key != md5(json_encode(list(owner, "page", sequence))) || !islist(P["entries"]) || P["entries"].len > 8 || mail_pages[key]) return FALSE
		if (!isnull(P["next"]) && P["next"] != extraction_mail_next(sequence)) return FALSE
		mail_pages[key] = list("owner" = owner, "sequence" = sequence, "next" = P["next"])
		for (var/index in 1 to P["entries"].len)
			var/list/entry = P["entries"][index]
			if (!islist(entry) || !extraction_insurance_generation(entry["returned_generation"]) || entry["eligible_generation"] != entry["returned_generation"] + 1 || !extraction_insurance_generation(entry["eligible_generation"])) return FALSE
			var/list/ids = graph_ids(entry["equipment"], 2048)
			if (!ids || entry["id"] != entry["equipment"]["nodes"][1]["id"] || account_ids.len + ids.len > 2048) return FALSE
			for (var/id in ids)
				if (account_ids[id] || discovered_ids[id] || epoch_profile["surface_retired_ids"]?[id]) return FALSE
			for (var/id in ids) account_ids[id] = TRUE
			for (var/list/node in entry["equipment"]["nodes"])
				if (mail_expected_nodes[node["id"]]) return FALSE
				mail_expected_nodes[node["id"]] = list(owner, sequence, entry["id"])
		return TRUE
	proc/auxiliary_inventory_batch()
		if (enabled || discovery_locked || !islist(auxiliary_records) || !account_inventory_lease_valid() || metadata.accounts.sessions.len) return discovery_fail()
		if (auxiliary_cursor > auxiliary_records.len) return auxiliary_cursor
		var/last = min(auxiliary_records.len, auxiliary_cursor + 15)
		for (var/index in auxiliary_cursor to last)
			var/list/record = auxiliary_records[auxiliary_records[index]]
			var/datum/extraction_account_store/journal = new
			journal.root = record["root"]
			var/list/P = journal.load_profile(record["owner"])
			if (!auxiliary_record_valid(record, P)) return discovery_fail()
			record["digest"] = md5(json_encode(P))
		auxiliary_cursor = last + 1
		return auxiliary_cursor
	proc/auxiliary_inventory_verify_batch()
		if (enabled || discovery_locked || !islist(auxiliary_records) || auxiliary_cursor <= auxiliary_records.len || !account_inventory_lease_valid() || metadata.accounts.sessions.len) return discovery_fail()
		var/list/current = auxiliary_manifest()
		if (!islist(current) || current.len != auxiliary_records.len) return discovery_fail()
		for (var/key in current)
			var/list/record = auxiliary_records[key]
			if (!record || record["root"] != current[key]["root"] || record["owner"] != current[key]["owner"]) return discovery_fail()
		if (auxiliary_verify_cursor > auxiliary_records.len) return auxiliary_verify_cursor
		var/last = min(auxiliary_records.len, auxiliary_verify_cursor + 15)
		for (var/index in auxiliary_verify_cursor to last)
			var/list/record = auxiliary_records[auxiliary_records[index]]
			var/datum/extraction_account_store/journal = new
			journal.root = record["root"]
			var/list/P = journal.load_profile(record["owner"])
			if (!P || md5(json_encode(P)) != record["digest"]) return discovery_fail()
		auxiliary_verify_cursor = last + 1
		return auxiliary_verify_cursor
	proc/finish_auxiliary_inventory_batch()
		if (enabled || discovery_locked || !islist(auxiliary_records) || auxiliary_verify_cursor <= auxiliary_records.len || !account_inventory_lease_valid() || metadata.accounts.sessions.len) return discovery_fail()
		// Traverse at most sixteen actual pages; no missing-page assumptions except
		// the source's empty, never-materialized initial page at sequence one.
		for (var/step in 1 to 16)
			if (mail_meta_cursor > mail_meta.len) break
			var/owner = mail_meta[mail_meta_cursor]
			if (!mail_sequence) mail_sequence = "1"
			var/key = md5(json_encode(list(owner, "page", mail_sequence)))
			var/list/page = mail_pages[key]
			if (!page)
				if (mail_sequence != "1" || mail_meta[owner]["tail"] != "1") return discovery_fail()
			else
				if (mail_seen_pages[key]) return discovery_fail()
				mail_seen_pages[key] = TRUE
				if (mail_sequence == mail_meta[owner]["tail"])
					if (page["next"]) return discovery_fail()
				else
					if (!page["next"]) return discovery_fail()
					mail_sequence = page["next"]
					continue
			mail_meta_cursor++
			mail_sequence = null
		if (mail_meta_cursor <= mail_meta.len) return TRUE
		if (mail_seen_pages.len != mail_pages.len || mail_active_nodes.len != mail_expected_nodes.len) return discovery_fail()
		if (mail_node_cursor <= mail_expected_nodes.len)
			var/last = min(mail_expected_nodes.len, mail_node_cursor + 15)
			for (var/index in mail_node_cursor to last)
				var/id = mail_expected_nodes[index]
				if (json_encode(mail_expected_nodes[id]) != json_encode(mail_active_nodes[id])) return discovery_fail()
			mail_node_cursor = last + 1
		auxiliary_inventory_complete = mail_node_cursor > mail_expected_nodes.len
		return TRUE
