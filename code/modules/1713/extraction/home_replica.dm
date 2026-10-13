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
