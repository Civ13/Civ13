// Internal round-end consumer. No network entry point or client authority.
/datum/extraction_insurance_returns
	var/datum/extraction_service/service
	var/datum/extraction_equipment_codec/codec
	var/datum/extraction_account_store/journal = new
	var/list/profile
	var/tmp/list/retirement_refs
	var/tmp/busy = FALSE
	var/tmp/test_fail_at
	var/last_error
	New(datum/extraction_service/S, datum/extraction_equipment_codec/C)
		..()
		service = S
		codec = C
		journal.root = "[S.store.root]_insurance/"
		S.insurance_gate = src
	proc/fail(message)
		last_error = message
		return FALSE
	proc/ready()
		if (busy || !service || !codec) return FALSE
		if (!profile)
			profile = journal.load_profile("world")
			if (!profile && !repair_phase()) return fail("Insurance receipt requires recovery")
			if (!profile["phase"]) profile["phase"] = "complete"
		if (profile["phase"] == "retired") return finish()
		return profile["phase"] == "complete"
	proc/insurable(path)
		// Reusable equipment only. Ammunition, projectiles, keys and salvage are
		// deliberately excluded; this table never restores consumed supplies.
		return codec.supported(path) && (ispath(path, /obj/item/weapon/gun) || ispath(path, /obj/item/weapon/attachment) || ispath(path, /obj/item/weapon/gun_mount) || ispath(path, /obj/item/ammo_magazine) || ispath(path, /obj/item/clothing) || ispath(path, /obj/item/weapon/storage) || ispath(path, /obj/item/weapon/material) || ispath(path, /obj/item/blackpowder_part))
	proc/quote(datum/extraction_session/S, list/selected_ids, round_id)
		if (!ready() || !S.active() || S.service != service || S.profile["state"] != "home" || !islist(selected_ids) || selected_ids.len > 16 || !istext(round_id) || !length(round_id) || length(round_id) > 64) return null
		var/list/wanted = list()
		for (var/id in selected_ids)
			if (!istext(id) || wanted[id]) return null
			wanted[id] = TRUE
		var/list/insured = list()
		var/list/payment = list()
		var/cost = 0
		var/found = 0
		for (var/list/entry in S.profile["stash"])
			var/list/graph = entry["equipment"]
			if (wanted[entry["id"]])
				found++
				if (graph["schema"] != 2 || !codec.validate(graph)) return null
				if (!insurable(text2path(graph["nodes"][1]["type"]))) continue
				insured += entry["id"]
				for (var/list/node in graph["nodes"])
					if (insurable(text2path(node["type"]))) cost++
			else if (graph["schema"] == 2 && graph["nodes"].len == 1 && graph["nodes"][1]["type"] == "/obj/item/extraction_salvage") payment += entry["id"]
		if (found != wanted.len || !cost || cost > 64 || payment.len < cost) return null
		payment.Cut(cost + 1)
		return list("revision" = S.profile["revision"], "round" = round_id, "selected" = selected_ids.Copy(), "insured" = insured, "payment" = payment, "cost" = cost)
	proc/paid_deploy(datum/extraction_session/S, list/offer, faction)
		if (!islist(offer)) return null
		var/list/current = quote(S, offer["selected"], offer["round"])
		if (!current || json_encode(current) != json_encode(offer)) return null
		return S.begin_raid(current["selected"], faction, current["insured"], current["round"], current["payment"], current["revision"])
	proc/prepare(round_id, list/roots)
		if (!ready() || service.sessions.len || !islist(roots) || roots.len > 2048) return fail("Release accounts before round-end preparation")
		if (profile["resolved_round"] == round_id) return fail("Round already resolved")
		var/datum/extraction_insurance_inventory/inventory = new(service)
		var/list/index = inventory.build(round_id)
		if (!islist(index)) return fail(inventory.last_error)
		service.insurance_busy = TRUE
		busy = TRUE
		var/list/candidate
		try
			candidate = plan(round_id, roots, inventory, index)
		catch
			candidate = null
		if (!candidate)
			busy = FALSE
			service.insurance_busy = FALSE
			return fail("Round-end plan rejected before retirement")
		if (test_fail_at == "before_prepare")
			busy = FALSE
			service.insurance_busy = FALSE
			return FALSE
		var/success = journal.commit_profile("world", candidate)
		busy = FALSE
		service.insurance_busy = FALSE
		if (!success)
			profile = null
			return fail("Insurance preparation write interrupted")
		profile = candidate
		retirement_refs = roots.Copy()
		if (test_fail_at == "after_prepare") return FALSE
		return retire()
	proc/plan(round_id, list/roots, datum/extraction_insurance_inventory/inventory, list/index)
		if (!inventory.revalidate()) return null
		var/list/returned = list()
		var/list/physical = list()
		var/list/identities = list()
		var/list/insured_ids = list()
		for (var/token in inventory.claims)
			var/list/claim = inventory.claims[token]
			insured_ids[claim["id"]] = TRUE
		var/total_nodes = 0
		for (var/obj/item/I in roots)
			var/turf/T = get_turf(I)
			if (!I.loc || !T || T.z != 1 || istype(I.loc, /obj/item)) return null
			var/list/record = codec.encode(I)
			if (!record) return null
			var/list/nodes = record["nodes"]
			total_nodes += nodes.len
			if (total_nodes > 2048) return null
			var/list/owner_ids = list()
			for (var/list/node in nodes)
				if (identities[node["id"]]) return null
				identities[node["id"]] = TRUE
				var/token = node["insurance_token"]
				var/list/claim = index[token]
				if (!claim)
					if (insured_ids[node["id"]]) return null
					continue
				var/list/source = inventory.claims[token]
				if (source["id"] != node["id"] || source["type"] != node["type"]) return null
				if (claim["status"] != "unrecovered") continue
				if (!insurable(text2path(node["type"]))) continue
				if (!owner_ids[claim["owner"]]) owner_ids[claim["owner"]] = list()
				owner_ids[claim["owner"]] += node["id"]
			for (var/owner in owner_ids)
				var/list/projected = codec.project_identities(record, owner_ids[owner])
				if (!islist(projected)) return null
				if (!returned[owner]) returned[owner] = list()
				for (var/list/graph in projected)
					returned[owner] += list(list("id" = graph["nodes"][1]["id"], "equipment" = graph))
			physical += list(list("id" = I.extraction_item_id, "digest" = md5(json_encode(record))))
		var/list/parts = list()
		for (var/owner in inventory.revisions)
			var/list/before = service.store.load_profile(owner)
			var/list/after = json_decode(json_encode(before))
			var/list/archive = after["insurance_claims"]
			var/list/remaining = list()
			if (archive)
				for (var/list/claim in archive)
					if (claim["round"] != round_id) remaining += list(claim)
			var/list/old_tokens = after["insurance_recovered"]
			var/list/tokens = list()
			if (old_tokens)
				for (var/token in old_tokens)
					if (!index[token]) tokens += token
			if ((!archive || archive.len == remaining.len) && (!old_tokens || old_tokens.len == tokens.len) && !returned[owner]) continue
			after["insurance_claims"] = remaining
			after["insurance_recovered"] = tokens
			if (!after["insurance_mailbox"]) after["insurance_mailbox"] = list()
			var/list/mailbox = after["insurance_mailbox"]
			for (var/list/entry in returned[owner]) mailbox += list(entry)
			if (!service.insurance_profile_valid(after)) return null
			after["revision"]++
			parts += list(list("owner" = owner, "before" = before, "after" = after))
			if (parts.len > 32) return null
		var/list/candidate = json_decode(json_encode(profile))
		candidate["phase"] = "prepared"
		candidate["round"] = round_id
		candidate["parts"] = parts
		candidate["physical"] = physical
		candidate["plan_digest"] = md5(json_encode(list(parts, physical)))
		if (length(json_encode(candidate)) > EXTRACTION_PROFILE_LIMIT - 64) return null
		return candidate
	proc/retire()
		if (busy || profile["phase"] != "prepared" || !islist(retirement_refs) || !valid_receipt()) return FALSE
		busy = TRUE
		var/list/current = list()
		for (var/obj/item/I in retirement_refs)
			if (!I.loc) continue
			var/list/graph = codec.encode(I)
			if (!graph || current[I.extraction_item_id])
				busy = FALSE
				return fail("Physical retirement graph changed")
			current[I.extraction_item_id] = md5(json_encode(graph))
		for (var/list/expected in profile["physical"])
			if (current[expected["id"]] && current[expected["id"]] != expected["digest"])
				busy = FALSE
				return fail("Physical retirement identity changed")
			current -= expected["id"]
		if (current.len)
			busy = FALSE
			return fail("Unexpected physical retirement root")
		var/count = 0
		for (var/obj/item/I in retirement_refs)
			if (I.loc) qdel(I)
			if (I && I.loc)
				busy = FALSE
				return fail("Physical item retirement failed")
			count++
			if (test_fail_at == "retire[count]")
				busy = FALSE
				return FALSE
		var/list/retired = json_decode(json_encode(profile))
		retired["phase"] = "retired"
		if (test_fail_at == "retirement_intent") journal.test_fail_at = "intent"
		if (test_fail_at == "retirement_snapshot") journal.test_fail_at = "snapshot"
		var/success = journal.commit_profile("world", retired)
		journal.test_fail_at = null
		busy = FALSE
		if (!success)
			profile = null
			return fail("Physical retirement receipt interrupted")
		profile = retired
		retirement_refs = null
		if (test_fail_at == "after_retirement") return FALSE
		return finish()
	proc/valid_receipt()
		return islist(profile["parts"]) && profile["parts"].len <= 32 && islist(profile["physical"]) && profile["physical"].len <= 2048 && profile["plan_digest"] == md5(json_encode(list(profile["parts"], profile["physical"])))
	proc/final_profile()
		var/list/final = json_decode(json_encode(profile))
		final["phase"] = "complete"
		final["resolved_round"] = profile["round"]
		final["parts"] = null
		final["physical"] = null
		final["plan_digest"] = null
		return final
	proc/finish()
		if (busy || service.sessions.len || profile["phase"] != "retired" || !valid_receipt()) return FALSE
		busy = TRUE
		if (!service.settlement) service.settlement = new(service)
		var/i = 0
		for (var/list/part in profile["parts"])
			i++
			if (!service.settlement.apply_projection(service.store, part["owner"], part["before"], part["after"]))
				busy = FALSE
				return fail("Insurance account projection requires recovery")
			if (test_fail_at == "apply[i]")
				busy = FALSE
				return FALSE
		var/list/final = final_profile()
		if (test_fail_at == "finalize_intent") journal.test_fail_at = "intent"
		if (test_fail_at == "finalize_snapshot") journal.test_fail_at = "snapshot"
		var/success = journal.commit_profile("world", final)
		journal.test_fail_at = null
		busy = FALSE
		if (!success)
			profile = null
			return fail("Insurance finalization interrupted")
		profile = final
		return TRUE
	proc/repair_phase()
		var/list/A = journal.read_slot("world", 0)
		var/list/B = journal.read_slot("world", 1)
		if (!A || !B) return FALSE
		var/list/latest = A["generation"] > B["generation"] ? A : B
		var/list/previous = A["generation"] > B["generation"] ? B : A
		if (!latest["pending"] || previous["pending"] || latest["generation"] != previous["generation"] + 1 || !previous["profile"]) return FALSE
		profile = previous["profile"]
		if (!valid_receipt()) return FALSE
		var/list/after
		if (profile["phase"] == "prepared")
			after = json_decode(json_encode(profile))
			after["phase"] = "retired"
		else if (profile["phase"] == "retired") after = final_profile()
		else return FALSE
		after["revision"]++
		if (!service.settlement) service.settlement = new(service)
		if (!service.settlement.apply_projection(journal, "world", profile, after)) return FALSE
		profile = after
		return TRUE
