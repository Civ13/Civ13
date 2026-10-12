// Bounded per-round receipts. A pending physical retirement fails closed after
// restart; it cannot be guessed from the absence of a recreated NPC.
/datum/extraction_npc_journal
	var/datum/extraction_account_store/store = new
	var/datum/extraction_service/service
	var/round_id
	var/list/profile
	var/tmp/busy = FALSE
	var/tmp/test_fail_at
	New(datum/extraction_service/S)
		..()
		service = S
		store.root = "[S.store.root]_insurance/_npc/"
	proc/configure(id)
		if (!istext(id) || !length(id) || length(id) > 64) return FALSE
		if (round_id && round_id != id)
			if (!ready()) return FALSE
			profile = null
		round_id = id
		if (!profile) profile = store.load_profile(md5(id))
		return ready()
	proc/ready()
		return !busy && (!round_id || (profile && (!profile["phase"] || profile["phase"] == "complete")))
	proc/recovered(id)
		if (!configure(id)) return null
		var/list/result = list()
		var/list/receipts = profile["npc_receipts"]
		if (!receipts) return result
		if (!islist(receipts) || receipts.len > 128) return null
		for (var/list/receipt in receipts)
			var/list/graphs = receipt["graphs"]
			if (!islist(graphs) || graphs.len > 8 || receipt["digest"] != md5(json_encode(graphs))) return null
			for (var/list/graph in graphs)
				var/datum/extraction_equipment_codec/C = new
				if (graph["schema"] != 2 || !C.validate(graph)) return null
				for (var/list/node in graph["nodes"])
					var/token = node["insurance_token"]
					if (!token) continue
					if (result[token]) return null
					result[token] = list("id" = node["id"], "type" = node["type"])
		return result
	proc/retire(obj/map_metadata/extraction_survival/M, mob/living/simple_animal/hostile/human/extraction/N, obj/effect/extraction_exit/E)
		if (!configure(M.round_id) || !E.npc_eligible(N) || M.accounts != service) return FALSE
		if (!islist(recovered(M.round_id))) return FALSE
		var/list/roots = list()
		for (var/obj/item/I in N.contents) roots += I
		if (!roots.len || roots.len > 8) return FALSE
		var/list/graphs = list()
		var/list/ids = list()
		var/list/prior = profile["npc_receipts"]
		if (prior)
			for (var/list/receipt in prior)
				for (var/list/graph in receipt["graphs"])
					for (var/list/node in graph["nodes"]) ids[node["id"]] = TRUE
		for (var/obj/item/I in roots)
			var/list/graph = M.codec.encode(I)
			if (!graph || graph["schema"] != 2) return FALSE
			for (var/list/node in graph["nodes"])
				if (ids[node["id"]]) return FALSE
				ids[node["id"]] = TRUE
			graphs += list(graph)
		var/list/after = json_decode(json_encode(profile))
		if (!after["npc_receipts"]) after["npc_receipts"] = list()
		var/list/receipts = after["npc_receipts"]
		if (receipts.len >= 128) return FALSE
		receipts += list(list("graphs" = graphs, "digest" = md5(json_encode(graphs)), "fee" = E.extraction_fee, "faction" = N.contractor ? "PMC" : "Scav"))
		after["phase"] = "pending"
		if (length(json_encode(after)) > EXTRACTION_PROFILE_LIMIT - 64) return FALSE
		busy = TRUE
		if (test_fail_at == "intent") store.test_fail_at = "intent"
		if (!store.commit_profile(md5(round_id), after))
			store.test_fail_at = null
			profile = null
			busy = FALSE
			service.insurance_blocked = TRUE
			return FALSE
		profile = after
		N.extraction_credits -= E.extraction_fee
		N.extraction_retired = TRUE
		for (var/obj/item/I in roots)
			M.raid_items -= I
			qdel(I)
			if (I && I.loc)
				busy = FALSE
				return FALSE
		N.gun = null
		N.carried_salvage = null
		N.extraction_target = null
		M.npcs -= N
		qdel(N)
		if (test_fail_at == "retired")
			busy = FALSE
			return FALSE
		after = json_decode(json_encode(profile))
		after["phase"] = "complete"
		var/success = store.commit_profile(md5(round_id), after)
		if (success) profile = after
		busy = FALSE
		return success

/obj/effect/extraction_exit/proc/npc_eligible(mob/living/simple_animal/hostile/human/extraction/N)
	var/obj/map_metadata/extraction_survival/M = map
	if (!istype(M) || M.nomads || !available() || !N || N.extraction_retired || N.stat != CONSCIOUS || !extraction_mission_z(N.z) || !extraction_mission_z(z) || !Adjacent(N) || !(N in M.npcs)) return FALSE
	if (!(allowed_faction in list("all", "PMC", "Scav")) || (allowed_faction != "all" && allowed_faction != (N.contractor ? "PMC" : "Scav"))) return FALSE
	if (!isnum(extraction_fee) || extraction_fee < 0 || extraction_fee > 1000000 || round(extraction_fee) != extraction_fee || N.extraction_credits < extraction_fee) return FALSE
	// NPCs have no private vehicle bay or secured-room owner. These exits are
	// unavailable rather than creating ownership, keys or a free vehicle.
	if (requires_vehicle || istype(src, /obj/effect/extraction_exit/locked_room) || istype(src, /obj/effect/extraction_exit/scheduled)) return FALSE
	if (forbid_backpack)
		var/list/pending = N.contents.Copy()
		var/list/seen = list()
		while (pending.len)
			var/obj/item/I = pending[1]
			pending.Cut(1, 2)
			if (seen[I] || seen.len >= EXTRACTION_EQUIPMENT_NODES) return FALSE
			seen[I] = TRUE
			if (istype(I, /obj/item/weapon/storage/backpack)) return FALSE
			for (var/obj/item/child in I.contents) pending += child
	return TRUE

/mob/living/simple_animal/hostile/human/extraction
	var/extraction_credits = 0
	var/tmp/extraction_retired = FALSE
	var/tmp/obj/effect/extraction_exit/extraction_target
	var/tmp/extraction_started = null
	var/tmp/next_extraction_decision = 0
	proc/extraction_tick(obj/map_metadata/extraction_survival/M)
		if (extraction_retired || M.nomads || target_mob || stat != CONSCIOUS || !M.ensure_round()) return FALSE
		if (!extraction_target && world.time >= next_extraction_decision)
			next_extraction_decision = world.time + 5 SECONDS
			// Local bounded perception, no world or global exit scan.
			var/checked = 0
			for (var/obj/effect/extraction_exit/E in view(12, src))
				if (++checked > 16) break
				if (!E.available() || E.requires_vehicle || istype(E, /obj/effect/extraction_exit/locked_room) || istype(E, /obj/effect/extraction_exit/scheduled)) continue
				if (E.allowed_faction != "all" && E.allowed_faction != (contractor ? "PMC" : "Scav")) continue
				if (E.extraction_fee > extraction_credits) continue
				extraction_target = E
				break
		if (!extraction_target) return FALSE
		if (extraction_target.npc_eligible(src))
			if (isnull(extraction_started)) extraction_started = world.time
			if (world.time >= extraction_started + 10 SECONDS)
				if (!M.accounts.npc_journal) M.accounts.npc_journal = new(M.accounts)
				return M.accounts.npc_journal.retire(M, src, extraction_target)
			return TRUE
		extraction_started = null
		if (Adjacent(extraction_target))
			extraction_target = null
			return FALSE
		if (!extraction_target.available() || extraction_target.z != z || get_dist(src, extraction_target) > 12)
			extraction_target = null
			return FALSE
		if (world.time >= next_step)
			next_step = world.time + 1 SECOND
			route = cirrAstar(get_turf(src), get_turf(extraction_target), 5, 64)
			while (route.len && route[1] == get_turf(src)) route.Cut(1, 2)
			if (route.len) step_towards(src, route[1])
		return TRUE
