// Explicit maintenance snapshot only. Ordinary admission never invents ownership.
/obj/effect/extraction_house_marker
	var/replica_owner
	var/replica_revision = 0
	var/replica_digest
	proc/admission_available()
		// Every partial binding is occupied, including empty owner/digest strings
		// and a missing/non-numeric revision. Only the exact default is free.
		return !session && isnull(replica_owner) && isnum(replica_revision) && replica_revision == 0 && isnull(replica_digest)
	get_saved_vars()
		. = ..()
		. |= list("room", "replica_owner", "replica_revision", "replica_digest")
		. -= "session"
	persistence_runtime_var(key)
		if (key == "session") return TRUE
		return ..()

/datum/extraction_surface_service
	var/list/account_replica_roots = list()
	var/list/canonical_home_roots = list()
	var/tmp/list/home_retirement_refs = list()
	var/tmp/home_retirement_fail_at
	proc/home_retirement_store()
		var/datum/extraction_account_store/J = new
		J.root = "[metadata.accounts.store.root]_home_replica/"
		return J
	proc/home_retirement_available()
		return !enabled && !discovery_locked && !world_inventory_started && !account_inventory_names && !metadata.accounts.sessions.len && !extraction_account_read_leases.len
	proc/home_retirement_matches(owner, obj/effect/extraction_house_marker/H, list/P, list/B)
		return P && home_replica_valid(P) && islist(B) && json_encode(P["home_replica"]) == json_encode(B) && replica_house(B) == H && !H.session && H.replica_owner == owner && H.replica_revision == B["revision"] && H.replica_digest == extraction_sha256(json_encode(B))
	proc/prepare_home_retirement(owner, obj/effect/extraction_house_marker/H, list/roots)
		// This receipt authorizes retirement only. It never authorizes account
		// decode or marker release without an authoritative durable world save.
		if (!home_retirement_available() || !H || !islist(roots) || roots.len > 64) return FALSE
		var/list/P = metadata.accounts.store.load_profile(owner)
		var/list/B = P ? P["home_replica"] : null
		if (!account_profile_ids(P) || !home_retirement_matches(owner, H, P, B) || roots.len != B["roots"].len) return FALSE
		var/datum/extraction_account_store/J = home_retirement_store()
		var/list/receipt = J.load_profile(owner)
		if (!receipt) return FALSE
		// Never reinterpret a replay or restart as a fresh retirement request.
		if (receipt["home_retirement"])
			var/list/prior = receipt["home_retirement"]
			if (!islist(prior) || prior.len != 3) return FALSE
			var/list/previous_roots = home_retirement_refs[owner]
			if (!islist(previous_roots) || previous_roots.len != roots.len || prior["phase"] != "prepared" || prior["account_digest"] != extraction_sha256(json_encode(P)) || json_encode(prior["binding"]) != json_encode(B)) return FALSE
			for (var/index in 1 to roots.len)
				if (previous_roots[index] != roots[index]) return FALSE
			return TRUE
		var/list/seen = list()
		for (var/index in 1 to roots.len)
			if (!istype(roots[index], /obj/item)) return FALSE
			var/obj/item/I = roots[index]
			var/list/R = B["roots"][I.extraction_item_id]
			var/list/graph = metadata.codec.encode(I, FALSE)
			if (!R || seen[I.extraction_item_id] || !graph || R["digest"] != extraction_sha256(json_encode(graph)) || json_encode(R["placement"]) != json_encode(replica_placement(I, H))) return FALSE
			seen[I.extraction_item_id] = TRUE
		receipt["home_retirement"] = list("phase" = "prepared", "account_digest" = extraction_sha256(json_encode(P)), "binding" = json_decode(json_encode(B)))
		if (home_retirement_fail_at == "prepare_intent") J.test_fail_at = "intent"
		if (!J.commit_profile(owner, receipt)) return FALSE
		home_retirement_refs[owner] = roots.Copy()
		return TRUE
	proc/retire_home_replica(owner, obj/effect/extraction_house_marker/H)
		if (!home_retirement_available() || !H) return FALSE
		var/datum/extraction_account_store/J = home_retirement_store()
		var/list/receipt = J.load_profile(owner)
		var/list/R = receipt ? receipt["home_retirement"] : null
		var/list/P = metadata.accounts.store.load_profile(owner)
		if (!islist(R) || R.len != 3 || !home_retirement_matches(owner, H, P, R["binding"]) || R["account_digest"] != extraction_sha256(json_encode(P))) return FALSE
		if (R["phase"] == "retired") return home_retirement_refs[owner] == "retired"
		var/list/roots = home_retirement_refs[owner]
		if (R["phase"] != "prepared" || !islist(roots) || roots.len != R["binding"]["roots"].len) return FALSE
		// Preflight all remaining actual roots before any further retirement.
		for (var/obj/item/I in roots)
			if (!I || !I.loc) continue
			var/list/expected = R["binding"]["roots"][I.extraction_item_id]
			var/list/graph = metadata.codec.encode(I, FALSE)
			if (!expected || !graph || expected["digest"] != extraction_sha256(json_encode(graph)) || json_encode(expected["placement"]) != json_encode(replica_placement(I, H))) return FALSE
		var/count = 0
		for (var/obj/item/I in roots)
			if (I && I.loc) qdel(I)
			if (I && I.loc) return FALSE
			count++
			if (home_retirement_fail_at == "retire[count]") return FALSE
		R["phase"] = "retired"
		if (home_retirement_fail_at == "retirement_snapshot") J.test_fail_at = "snapshot"
		if (!J.commit_profile(owner, receipt)) return FALSE
		home_retirement_refs[owner] = "retired"
		// Binding/privacy remains reserved across crashes and old-world reloads.
		// Missing roots after restart are not evidence of a saved retirement.
		return TRUE
	proc/replica_house(list/binding)
		if (!islist(binding) || extraction_house_markers.len > 32) return null
		var/obj/effect/extraction_house_marker/result
		for (var/obj/effect/extraction_house_marker/H in extraction_house_markers)
			if (H.room != binding["room"] || H.x != binding["x"] || H.y != binding["y"] || H.z != binding["z"]) continue
			if (result) return null
			result = H
		return result
	proc/replica_placement(obj/item/I, obj/effect/extraction_house_marker/H)
		// Initial contract is floor roots only. Bodies, benches, secure crates and
		// vehicle cargo require separate canonical placement contracts.
		if (!I || !H || !istype(I.loc, /turf/floor/plating/extraction_house)) return null
		var/turf/T = I.loc
		if (T.z != H.z || get_dist(T, H) > 4 || extraction_house_markers.len > 32) return null
		for (var/obj/effect/extraction_house_marker/other in extraction_house_markers)
			if (other != H && other.z == T.z && get_dist(T, other) <= 4) return null
		return list(T.x, T.y, T.z, "floor")
	proc/home_replica_valid(list/P)
		var/list/B = P["home_replica"]
		if (isnull(B)) return TRUE
		if (!islist(B) || B.len != 8 || B["schema"] != 1 || B["map_id"] != metadata.ID || B["revision"] != P["revision"] || P["state"] != "home" || P["owner"] == "extractionmarket" || !islist(B["roots"]) || B["roots"].len != P["stash"].len) return FALSE
		for (var/key in list("room", "x", "y", "z"))
			if (!isnum(B[key]) || round(B[key]) != B[key] || B[key] < 1) return FALSE
		if (B["room"] > 32 || B["x"] > world.maxx || B["y"] > world.maxy || B["z"] > world.maxz) return FALSE
		for (var/index in 1 to P["stash"].len)
			var/list/E = P["stash"][index]
			var/list/R = B["roots"][E["id"]]
			if (!islist(R) || R.len != 2 || R["digest"] != extraction_sha256(json_encode(E["equipment"])) || E["secure"] || !islist(R["placement"]) || R["placement"].len != 4 || R["placement"][4] != "floor") return FALSE
			var/list/place = R["placement"]
			for (var/axis in 1 to 3)
				if (!isnum(place[axis]) || round(place[axis]) != place[axis] || place[axis] < 1) return FALSE
			if (place[3] != B["z"] || abs(place[1] - B["x"]) > 4 || abs(place[2] - B["y"]) > 4 || place[1] > world.maxx || place[2] > world.maxy) return FALSE
		return TRUE
	proc/index_home_replica(list/P)
		if (!home_replica_valid(P)) return FALSE
		var/list/B = P["home_replica"]
		if (!B) return TRUE
		for (var/id in B["roots"])
			if (account_replica_roots[id]) return FALSE
			account_replica_roots[id] = list("owner" = P["owner"], "binding" = B)
		return TRUE
	proc/approved_home_replica(obj/item/I, list/graph, list/ids)
		if (!I || !islist(graph) || !islist(ids) || !ids.len || json_encode(graph_ids(graph, 2048)) != json_encode(ids)) return FALSE
		var/list/record = account_replica_roots[I.extraction_item_id]
		if (!record || !account_inventory_complete || !account_inventory_lease_valid()) return FALSE
		var/list/B = record["binding"]
		var/obj/effect/extraction_house_marker/H = replica_house(B)
		if (!H || H.session || H.replica_owner != record["owner"] || H.replica_revision != B["revision"] || H.replica_digest != extraction_sha256(json_encode(B))) return FALSE
		var/list/R = B["roots"][I.extraction_item_id]
		if (!R || extraction_sha256(json_encode(graph)) != R["digest"] || json_encode(replica_placement(I, H)) != json_encode(R["placement"])) return FALSE
		for (var/id in ids)
			if (!account_ids[id] || (discovered_ids[id] && discovered_ids[id] != I)) return FALSE
		return TRUE
	proc/bind_home_replica(owner, obj/effect/extraction_house_marker/H, list/roots)
		// Host must own an exclusive maintenance window and subsequently save the
		// marker with the world. Interrupted or stale world copies fail closed.
		if (enabled || discovery_locked || world_inventory_started || account_inventory_names || metadata.accounts.sessions.len || !H || !H.admission_available() || !islist(roots) || roots.len > 64) return FALSE
		var/list/P = metadata.accounts.store.load_profile(owner)
		if (!account_profile_ids(P) || !isnull(P["home_replica"]) || (islist(P["garage"]) && P["garage"].len) || roots.len != P["stash"].len) return FALSE
		var/list/B = list("schema" = 1, "map_id" = metadata.ID, "revision" = P["revision"] + 1, "room" = H.room, "x" = H.x, "y" = H.y, "z" = H.z, "roots" = list())
		if (replica_house(B) != H) return FALSE
		var/list/entries = list()
		for (var/list/E in P["stash"]) entries[E["id"]] = E
		for (var/index in 1 to roots.len)
			if (!istype(roots[index], /obj/item)) return FALSE
			var/obj/item/I = roots[index]
			var/list/E = entries[I.extraction_item_id]
			var/list/place = replica_placement(I, H)
			var/list/graph = metadata.codec.encode(I, FALSE)
			if (!E || E["secure"] || !place || !graph || B["roots"][I.extraction_item_id] || json_encode(graph) != json_encode(E["equipment"])) return FALSE
			B["roots"][I.extraction_item_id] = list("digest" = extraction_sha256(json_encode(graph)), "placement" = place)
		P["home_replica"] = B
		var/list/check = json_decode(json_encode(P))
		check["revision"]++
		if (!home_replica_valid(check) || !metadata.accounts.store.commit_profile(owner, P)) return FALSE
		H.replica_owner = owner
		H.replica_revision = P["revision"]
		H.replica_digest = extraction_sha256(json_encode(B))
		return TRUE
