// Disabled surface service. Issuance requires explicit registration and enablement.
/obj/effect/extraction_surface_source
	name = "surface loot source"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	invisibility = 101
	var/source_id = 0
	var/pool_id = ""
	var/support_kind = "floor"
	var/support_type = null
	var/tmp/datum/extraction_surface_service/service
	var/tmp/list/profile
	var/tmp/obj/item/live_root
	var/tmp/atom/authorized_destination
	var/tmp/busy = FALSE
	var/tmp/quarantined = FALSE
	proc/schema_valid()
		if (!isnum(source_id) || round(source_id) != source_id || source_id < 1 || source_id > 128) return FALSE
		if (!(pool_id in list("parking_fuel", "parking_wheel", "repair_parts", "canned_food", "register_cash"))) return FALSE
		if (!(support_kind in list("floor", "shelf", "table", "register"))) return FALSE
		if (support_kind == "floor") return isnull(support_type)
		return ispath(support_type, /obj/structure)
	proc/pool_enabled()
		return service && service.enabled && (pool_id in list("parking_fuel", "parking_wheel", "repair_parts"))
	persistence_runtime_var(key)
		if (key in list("service", "profile", "live_root", "authorized_destination", "busy", "quarantined")) return TRUE
		return ..()

// Explicit map-owned registration only; constructors never issue or advance epochs.
/datum/extraction_surface_service
	var/enabled = FALSE
	var/obj/map_metadata/extraction_survival/metadata
	var/datum/extraction_account_store/store = new
	var/list/sources = list()
	var/list/epoch_profile
	var/list/issued_ids = list()
	var/list/discovered_roots = list()
	var/list/discovered_ids = list()
	var/list/account_ids = list()
	var/discovery_locked = FALSE
	var/locked = FALSE
	var/tmp/test_fail_materialize_ack = FALSE
	var/tmp/test_fail_claim_ack = FALSE
	New(obj/map_metadata/extraction_survival/M, storage_root = "data/extraction_surface/")
		..()
		metadata = M
		if (!M || !(M.ID in list(MAP_EXTRACTION_SURVIVAL, MAP_EXTRACTION_CITY, MAP_EXTRACTION_MALL)))
			locked = TRUE
			return
		store.root = "[storage_root][ckey(M.ID)]/"
	proc/register_source(obj/effect/extraction_surface_source/S)
		if (locked || !S || !S.schema_valid() || S.service || sources.len >= 128) return FALSE
		var/key = "[S.source_id]"
		var/obj/effect/extraction_surface_source/other = sources[key]
		if (other)
			other.quarantined = TRUE
			S.quarantined = TRUE
			return FALSE
		sources[key] = S
		S.service = src
		return TRUE
	proc/support_valid(obj/effect/extraction_surface_source/S)
		if (!S || S.service != src || sources["[S.source_id]"] != S || !S.schema_valid() || S.quarantined || !metadata || !metadata.mission_z(S.z)) return FALSE
		var/turf/T = get_turf(S)
		if (!T || T.density) return FALSE
		var/approachable = FALSE
		for (var/direction in list(NORTH, SOUTH, EAST, WEST))
			var/turf/near = get_step(T, direction)
			if (!near || near.density) continue
			var/blocked = FALSE
			for (var/atom/movable/A in near)
				if (A.density && !ismob(A)) blocked = TRUE
			if (!blocked) approachable = TRUE
		if (!approachable) return FALSE
		if (S.support_kind == "floor") return isnull(S.support_type)
		var/expected
		if (metadata.ID == MAP_EXTRACTION_MALL)
			switch (S.support_kind)
				if ("shelf") expected = text2path("/obj/structure/table/extraction_mall/shelf")
				if ("table") expected = text2path("/obj/structure/table/extraction_mall")
				if ("register") expected = text2path("/obj/structure/extraction_mall_fixture/register")
		if (!expected || S.support_type != expected) return FALSE
		for (var/obj/structure/support in T)
			if (support.type == expected && support.anchored) return TRUE
		return FALSE
	proc/ensure_epoch()
		if (locked || discovery_locked) return FALSE
		if (epoch_profile) return TRUE
		epoch_profile = store.load_profile("epoch")
		if (!epoch_profile) return quarantine(null)
		if (!epoch_profile["revision"])
			epoch_profile["raid_sequence"] = 1
			if (!store.commit_profile("epoch", epoch_profile)) return quarantine(null)
		var/epoch = epoch_profile["raid_sequence"]
		return isnum(epoch) && round(epoch) == epoch && epoch >= 1 && epoch <= 1000000
	proc/quarantine(obj/effect/extraction_surface_source/S)
		if (S) S.quarantined = TRUE
		else locked = TRUE
		return FALSE
	proc/commit_source(obj/effect/extraction_surface_source/S, list/P)
		if (!store.commit_profile("source[S.source_id]", P)) return quarantine(S)
		S.profile = P
		return TRUE
	proc/pool_path(pool)
		switch (pool)
			if ("parking_fuel") return /obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline
			if ("parking_wheel") return /obj/item/extraction_wheel_crate
			if ("repair_parts") return /obj/item/extraction_salvage
		return null
	proc/prepare_source(obj/effect/extraction_surface_source/S)
		if (!enabled || locked || discovery_locked || !S || S.busy || !S.pool_enabled() || !support_valid(S) || !ensure_epoch()) return FALSE
		if (!S.profile) S.profile = store.load_profile("source[S.source_id]")
		if (!S.profile) return quarantine(S)
		if (S.profile["raid_sequence"] != epoch_profile["raid_sequence"] && S.profile["surface_state"])
			if (S.live_root || S.profile["raid_sequence"] != epoch_profile["raid_sequence"] - 1 || !(S.profile["surface_state"] in list("claimed", "forfeited"))) return quarantine(S)
			var/list/reset = json_decode(json_encode(S.profile))
			reset["surface_retired_entry"] = reset["surface_entry"]
			reset["surface_state"] = null
			reset["surface_claim"] = null
			reset["surface_entry"] = null
			reset["stash"] = list()
			reset["raid_sequence"] = epoch_profile["raid_sequence"]
			if (!commit_source(S, reset)) return FALSE
		if (S.profile["surface_state"])
			if (S.profile["raid_sequence"] != epoch_profile["raid_sequence"] || S.profile["surface_pool"] != S.pool_id) return quarantine(S)
			return S.profile["surface_state"] == "planned"
		var/list/manifest = epoch_profile["surface_sources"]
		if (isnull(manifest)) manifest = list()
		if (!islist(manifest) || manifest.len > 128) return quarantine(null)
		if (!(S.source_id in manifest))
			var/list/E = json_decode(json_encode(epoch_profile))
			E["surface_sources"] = manifest.Copy()
			E["surface_sources"] += S.source_id
			if (!store.commit_profile("epoch", E)) return quarantine(null)
			epoch_profile = E
		// Persist the finite type choice before constructing a private graph.
		var/path = pool_path(S.pool_id)
		if (!path || !metadata.codec.supported(path)) return FALSE
		var/list/P = json_decode(json_encode(S.profile))
		P["raid_sequence"] = epoch_profile["raid_sequence"]
		P["surface_pool"] = S.pool_id
		P["surface_state"] = "planning"
		P["surface_type"] = "[path]"
		if (!commit_source(S, P)) return FALSE
		S.busy = TRUE
		var/obj/item/I
		var/list/entry
		try
			I = new path(null)
			if (metadata.codec.set_raid_provenance(I, TRUE)) entry = metadata.record_item(I)
		catch
			entry = null
		if (I) qdel(I)
		S.busy = FALSE
		if (!entry_valid(S, entry)) return quarantine(S)
		P = json_decode(json_encode(S.profile))
		P["stash"] = list(entry)
		P["surface_entry"] = entry
		P["surface_state"] = "planned"
		return commit_source(S, P)
	proc/materialize_source(obj/effect/extraction_surface_source/S)
		if (!enabled || locked || discovery_locked || !S || S.busy || !S.pool_enabled() || !support_valid(S) || !ensure_epoch() || !S.profile || S.profile["surface_state"] != "planned") return FALSE
		if (S.profile["raid_sequence"] != epoch_profile["raid_sequence"] || S.profile["surface_pool"] != S.pool_id || S.live_root) return quarantine(S)
		var/list/stash = S.profile["stash"]
		if (!islist(stash) || stash.len != 1) return quarantine(S)
		var/list/entry = stash[1]
		var/list/graph = entry["equipment"]
		if (!entry_valid(S, entry) || metadata.raid_items.len + graph["nodes"].len + (S.pool_id == "parking_wheel" ? 1 : 0) > 2048) return quarantine(S)
		var/list/ids = graph_ids(graph)
		if (!ids || issued_ids.len + ids.len > 2048) return quarantine(S)
		for (var/id in ids)
			if (issued_ids[id] || discovered_ids[id] || account_ids[id]) return quarantine(S)
		for (var/id in ids) issued_ids[id] = S.source_id
		var/list/P = json_decode(json_encode(S.profile))
		P["surface_state"] = "materializing"
		if (!commit_source(S, P)) return FALSE
		S.busy = TRUE
		// Decode in private custody, then expose the same root after the intent.
		var/obj/item/I = metadata.codec.decode(graph, null)
		if (!I || !metadata.track_loot(I))
			if (I) qdel(I)
			S.busy = FALSE
			return quarantine(S)
		I.extraction_surface_source = S
		I.anchored = TRUE
		S.authorized_destination = get_turf(S)
		I.forceMove(get_turf(S))
		S.authorized_destination = null
		S.live_root = I
		P = json_decode(json_encode(S.profile))
		P["surface_state"] = "issued"
		if (test_fail_materialize_ack || !support_valid(S) || I.loc != get_turf(S) || !commit_source(S, P))
			I.extraction_surface_source = null
			qdel(I)
			S.live_root = null
			S.busy = FALSE
			return quarantine(S)
		S.busy = FALSE
		return TRUE
	proc/claim_root(obj/effect/extraction_surface_source/S, mob/living/human/H, obj/item/I)
		if (!enabled || locked || discovery_locked || !S || !I || S.busy || !support_valid(S) || !S.profile || S.profile["surface_state"] != "issued" || I != S.live_root || I.extraction_surface_source != S || I.loc != get_turf(S)) return FALSE
		if (!metadata.owned(H) || H.stat != CONSCIOUS || H.lying || H.get_active_hand() || !S.Adjacent(H) || H.z != S.z || H.extraction_session.locked || H.extraction_session.transitioning || H.extraction_session.profile["state"] != "raid" || metadata.round_closing) return FALSE
		var/list/entry = S.profile["stash"][1]
		if (!entry_valid(S, entry) || entry["id"] != I.extraction_item_id || !reconcile_source(S)) return quarantine(S)
		S.busy = TRUE
		H.extraction_session.transitioning = TRUE
		var/list/P = json_decode(json_encode(S.profile))
		P["surface_state"] = "claiming"
		P["surface_claim"] = list("owner" = H.extraction_session.owner, "item" = I.extraction_item_id, "epoch" = P["raid_sequence"])
		if (!commit_source(S, P))
			H.extraction_session.transitioning = FALSE
			S.busy = FALSE
			return FALSE
		I.anchored = FALSE
		S.authorized_destination = H
		var/delivered = H.put_in_active_hand(I) && I.loc == H && H.get_active_hand() == I
		S.authorized_destination = null
		P = json_decode(json_encode(S.profile))
		P["surface_state"] = "claimed"
		P["stash"] = list()
		if (!delivered || test_fail_claim_ack || !commit_source(S, P))
			H.extraction_session.locked = TRUE
			S.authorized_destination = get_turf(S)
			if (I.loc == H) H.drop_from_inventory(I, get_turf(S), TRUE)
			S.authorized_destination = null
			I.anchored = TRUE
			quarantine(S)
		else
			I.extraction_surface_source = null
			S.live_root = null
		H.extraction_session.transitioning = FALSE
		S.busy = FALSE
		return !S.quarantined
	proc/entry_valid(obj/effect/extraction_surface_source/S, list/entry)
		if (!islist(entry) || !islist(entry["equipment"])) return FALSE
		var/list/graph = entry["equipment"]
		if (!graph_ids(graph)) return FALSE
		var/list/root = graph["nodes"][1]
		if (entry["id"] != root["id"] || root["type"] != "[pool_path(S.pool_id)]") return FALSE
		for (var/list/node in graph["nodes"])
			if (!node["found_in_raid"] || node["insurance_token"]) return FALSE
		return TRUE
	proc/graph_ids(list/graph, maximum = 16)
		if (!metadata.codec.validate(graph) || graph["schema"] != 2) return null
		var/list/ids = list()
		for (var/list/node in graph["nodes"])
			if (ids[node["id"]]) return null
			ids[node["id"]] = TRUE
			if (node["packed_wheel"])
				var/id = node["packed_wheel"]["id"]
				if (ids[id]) return null
				ids[id] = TRUE
		return ids.len <= maximum ? ids : null
	proc/reconcile_source(obj/effect/extraction_surface_source/S)
		if (locked || discovery_locked || !S || S.service != src || S.quarantined || !ensure_epoch()) return FALSE
		if (!S.profile) S.profile = store.load_profile("source[S.source_id]")
		if (!S.profile) return quarantine(S)
		var/state = S.profile["surface_state"]
		if (isnull(state)) return TRUE
		if (S.profile["raid_sequence"] != epoch_profile["raid_sequence"] || S.profile["surface_pool"] != S.pool_id) return quarantine(S)
		if (state in list("claimed", "forfeited")) return !S.live_root || quarantine(S)
		if (state == "planned") return !S.live_root || quarantine(S)
		if (state != "issued" || !support_valid(S)) return quarantine(S)
		// No world scan or rematerialization: a missing runtime root stays unresolved.
		var/obj/item/I = S.live_root
		var/list/stash = S.profile["stash"]
		if (!islist(stash) || stash.len != 1 || !entry_valid(S, stash[1])) return quarantine(S)
		var/list/ids = graph_ids(stash[1]["equipment"])
		for (var/id in ids)
			if (account_ids[id] || (issued_ids[id] && issued_ids[id] != S.source_id)) return quarantine(S)
		if (!I)
			I = discovered_roots[stash[1]["id"]]
			if (I && I.loc == get_turf(S) && !I.extraction_surface_source)
				var/list/saved = metadata.codec.encode(I)
				if (!saved || md5(json_encode(saved)) != md5(json_encode(stash[1]["equipment"]))) return quarantine(S)
				if (!metadata.track_loot(I)) return quarantine(S)
				for (var/id in ids) issued_ids[id] = S.source_id
				I.extraction_surface_source = S
				I.anchored = TRUE
				S.live_root = I
		if (!I || I.loc != get_turf(S) || I.extraction_surface_source != S || !islist(stash) || stash.len != 1 || I.extraction_item_id != stash[1]["id"]) return quarantine(S)
		var/list/actual = metadata.codec.encode(I)
		if (!actual || md5(json_encode(actual)) != md5(json_encode(stash[1]["equipment"]))) return quarantine(S)
		return TRUE
	proc/movement_allowed(obj/item/I, atom/destination)
		var/obj/effect/extraction_surface_source/S = I.extraction_surface_source
		return S && S.service == src && S.busy && destination && S.authorized_destination == destination
	proc/observe_disposal(obj/item/I)
		var/obj/effect/extraction_surface_source/S = I.extraction_surface_source
		if (!S || S.service != src) return FALSE
		quarantine(S)
		if (S.profile && S.profile["surface_state"] == "issued")
			var/list/P = json_decode(json_encode(S.profile))
			P["surface_state"] = "disposing"
			P["surface_disposal"] = I.extraction_item_id
			commit_source(S, P)
		// No acknowledgement of engine deletion from a cleanup callback.
		return TRUE
	proc/discover_world_roots(list/roots)
		// Caller supplies loaded roots in bounded batches; never scan the world.
		if (discovery_locked || !islist(roots) || roots.len > 16) return FALSE
		for (var/index in 1 to roots.len)
			if (!istype(roots[index], /obj/item))
				discovery_locked = TRUE
				return FALSE
			var/obj/item/I = roots[index]
			var/list/graph = metadata.codec.encode(I)
			var/list/ids = graph_ids(graph, 2048)
			if (!ids || discovered_ids.len + ids.len > 2048)
				discovery_locked = TRUE
				return FALSE
			for (var/id in ids)
				if (discovered_ids[id] || account_ids[id])
					discovery_locked = TRUE
					return FALSE
			for (var/id in ids) discovered_ids[id] = I
			discovered_roots[I.extraction_item_id] = I
		return TRUE
	proc/discover_account_entries(list/entries)
		if (discovery_locked || !islist(entries) || entries.len > 16) return FALSE
		for (var/index in 1 to entries.len)
			if (!islist(entries[index]))
				discovery_locked = TRUE
				return FALSE
			var/list/entry = entries[index]
			var/list/ids = graph_ids(entry["equipment"], 2048)
			if (!ids || entry["id"] != entry["equipment"]["nodes"][1]["id"] || account_ids.len + ids.len > 2048)
				discovery_locked = TRUE
				return FALSE
			for (var/id in ids)
				if (account_ids[id] || discovered_ids[id])
					discovery_locked = TRUE
					return FALSE
			for (var/id in ids) account_ids[id] = TRUE
		return TRUE
	proc/reconcile_batch(start = 1)
		if (!isnum(start) || round(start) != start || start < 1 || start > sources.len + 1) return FALSE
		var/last = min(sources.len, start + 15)
		for (var/index in start to last)
			var/key = sources[index]
			if (!reconcile_source(sources[key])) return FALSE
		return last + 1
	proc/forfeit_source(obj/effect/extraction_surface_source/S)
		if (!enabled || locked || discovery_locked || !S || S.busy || S.quarantined || !metadata.round_closing || !S.profile) return FALSE
		if (S.profile["surface_state"] in list("claimed", "forfeited")) return !S.live_root
		if (!(S.profile["surface_state"] in list("planned", "issued")) || !reconcile_source(S)) return quarantine(S)
		S.busy = TRUE
		var/list/P = json_decode(json_encode(S.profile))
		P["surface_state"] = "forfeiting"
		if (!commit_source(S, P))
			S.busy = FALSE
			return FALSE
		var/obj/item/I = S.live_root
		if (I)
			I.extraction_surface_source = null
			metadata.raid_items -= I
			qdel(I)
			if (I && I.loc)
				S.busy = FALSE
				return quarantine(S)
		S.live_root = null
		P = json_decode(json_encode(S.profile))
		P["surface_state"] = "forfeited"
		P["stash"] = list()
		var/acknowledged = commit_source(S, P)
		S.busy = FALSE
		return acknowledged
	proc/close_round_batch()
		if (!enabled) return TRUE
		if (locked || !metadata.round_closing || !ensure_epoch()) return FALSE
		var/list/manifest = epoch_profile["surface_sources"]
		if (isnull(manifest)) return TRUE
		if (!islist(manifest) || manifest.len > 128) return quarantine(null)
		var/cursor = epoch_profile["surface_close_cursor"]
		if (isnull(cursor)) cursor = 1
		if (!isnum(cursor) || round(cursor) != cursor || cursor < 1 || cursor > manifest.len + 1) return quarantine(null)
		if (cursor > manifest.len) return TRUE
		var/last = min(manifest.len, cursor + 15)
		for (var/index in cursor to last)
			var/id = manifest[index]
			var/obj/effect/extraction_surface_source/S = sources["[id]"]
			if (!S || !S.profile) return quarantine(null)
			if (S.profile["surface_state"] in list("claimed", "forfeited")) continue
			if (!forfeit_source(S)) return FALSE
		var/list/E = json_decode(json_encode(epoch_profile))
		E["surface_close_cursor"] = last + 1
		if (!store.commit_profile("epoch", E)) return quarantine(null)
		epoch_profile = E
		return last == manifest.len
	proc/advance_epoch(expected)
		// Deliberately restrictive: unresolved issued/forfeited roots require a
		// future authoritative reconciliation path, not a refill or refund.
		if (!enabled || locked || discovery_locked || !ensure_epoch() || expected != epoch_profile["raid_sequence"] || expected >= 1000000 || !metadata.game_over || !metadata.round_closing || metadata.accounts.sessions.len) return FALSE
		var/list/manifest = epoch_profile["surface_sources"]
		if (!islist(manifest) || manifest.len > 128) return FALSE
		for (var/id in manifest)
			var/obj/effect/extraction_surface_source/S = sources["[id]"]
			if (!S || S.busy || S.quarantined || S.live_root || !S.profile || !(S.profile["surface_state"] in list("claimed", "forfeited"))) return FALSE
		var/list/E = json_decode(json_encode(epoch_profile))
		E["raid_sequence"] = expected + 1
		E["surface_sources"] = list()
		E["surface_close_cursor"] = null
		if (!store.commit_profile("epoch", E)) return quarantine(null)
		epoch_profile = E
		issued_ids = list()
		// Only prepare_source may reset a terminal previous-epoch source.
		return TRUE

/obj/map_metadata/extraction_survival
	var/tmp/datum/extraction_surface_service/surface_service
	persistence_runtime_var(key)
		if (key == "surface_service") return TRUE
		return ..()

/obj/item
	var/tmp/obj/effect/extraction_surface_source/extraction_surface_source
	persistence_runtime_var(key)
		if (key == "extraction_surface_source") return TRUE
		return ..()
	forceMove(atom/destination, special_event)
		if (extraction_surface_source)
			var/datum/extraction_surface_service/V = extraction_surface_source.service
			if (!destination)
				if (V) V.observe_disposal(src)
			else if (!V || !V.movement_allowed(src, destination)) return FALSE
		return ..()
	Move(NewLoc, direct)
		if (extraction_surface_source) return FALSE
		return ..()

// The only reagent pool currently allowed; parent handlers must not drain an
// unclaimed world root through a subtype override of the base item guard.
/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline
	attackby(obj/item/I, mob/user)
		if (extraction_surface_source) return
		return ..()
	attack_self(mob/user)
		if (extraction_surface_source) return
		return ..()
	attack_turf(turf/attacked, mob/user, icon_x, icon_y)
		if (extraction_surface_source) return
		return ..()
	attack_obj(obj/attacked, mob/user, icon_x, icon_y)
		if (extraction_surface_source) return
		return ..()
	attack(mob/living/M, mob/living/user, target_zone)
		if (extraction_surface_source) return
		return ..()
