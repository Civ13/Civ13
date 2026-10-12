// One authoritative server owns this directory. Sessions are capped and exclusive.
#define EXTRACTION_SESSION_LIMIT 32

/datum/extraction_service
	var/datum/extraction_account_store/store = new
	var/list/sessions = list()
	var/last_error
	var/datum/extraction_settlement/settlement
	proc/settlement_ready()
		if (!settlement) settlement = new(src)
		return settlement.ready()

/datum/extraction_session
	var/owner
	var/list/profile
	var/datum/extraction_service/service
	var/tmp/closed = FALSE
	var/tmp/locked = FALSE

/datum/extraction_service/proc/open(owner)
	last_error = null
	if (!settlement_ready())
		last_error = settlement.last_error
		return null
	if (sessions[owner] || sessions.len >= EXTRACTION_SESSION_LIMIT)
		last_error = "Account already active or server session capacity reached"
		return null
	var/list/P = store.load_profile(owner)
	if (!P)
		last_error = store.last_error
		return null
	// An old raid cannot be reconstructed as a free second copy of issued gear.
	if (P["state"] == "raid")
		P["state"] = "home"
		if (!store.commit_profile(owner, P))
			last_error = store.last_error
			return null
	var/datum/extraction_session/S = new
	S.owner = owner
	S.profile = P
	S.service = src
	sessions[owner] = S
	return S

/datum/extraction_session/proc/active()
	return !closed && !locked && service && service.settlement_ready() && service.sessions[owner] == src

/datum/extraction_session/proc/commit(list/candidate)
	if (!active()) return FALSE
	if (!service.store.commit_profile(owner, candidate))
		// A failed phase may have a durable intent. Stop all further mutations.
		locked = TRUE
		service.last_error = service.store.last_error
		return FALSE
	profile = candidate
	return TRUE

/datum/extraction_session/proc/copy_profile()
	return json_decode(json_encode(profile))

/datum/extraction_session/proc/capacity()
	return profile["level"] * 16

// Entries are opaque equipment graphs here; the production codec validates the
// actual type/field/content schema before any game object is materialized.
/datum/extraction_session/proc/valid_entries(list/entries, max_roots)
	if (!islist(entries) || entries.len > max_roots) return FALSE
	var/list/ids = list()
	var/list/node_ids = list()
	var/total_nodes = 0
	for (var/list/entry in entries)
		if (!islist(entry) || !istext(entry["id"]) || !length(entry["id"]) || length(entry["id"]) > 80 || ids[entry["id"]] || !islist(entry["equipment"])) return FALSE
		ids[entry["id"]] = TRUE
		if (!isnull(entry["secure"]) && !(entry["secure"] in list(FALSE, TRUE))) return FALSE
		var/list/equipment = entry["equipment"]
		if (equipment["schema"] in list(1, 2))
			var/list/graph = equipment["nodes"]
			if (!islist(graph) || graph.len < 1 || graph.len > 512) return FALSE
			total_nodes += graph.len
			if (total_nodes > 2048) return FALSE
		if (equipment["schema"] == 2)
			var/list/nodes = equipment["nodes"]
			if (!islist(nodes) || !nodes.len) return FALSE
			for (var/list/node in nodes)
				var/id = node["id"]
				if (!istext(id) || !length(id) || length(id) > 80 || node_ids[id]) return FALSE
				node_ids[id] = TRUE
			var/list/root = nodes[1]
			if (root["id"] != entry["id"]) return FALSE
	return TRUE

// Persist the debit before returning equipment to the caller. Caller must
// retire its home representations before materializing any raid representation.
/datum/extraction_session/proc/begin_raid(list/selected_ids, raid_faction = "PMC")
	if (!active() || profile["state"] != "home" || !islist(selected_ids) || selected_ids.len > 16 || !(raid_faction in list("PMC", "Scav"))) return null
	var/list/candidate = copy_profile()
	var/list/stash = candidate["stash"]
	if (!valid_entries(stash, capacity())) return null
	var/list/wanted = list()
	for (var/id in selected_ids)
		if (!istext(id) || wanted[id]) return null
		wanted[id] = TRUE
	var/list/remaining = list()
	var/list/issued = list()
	for (var/list/entry in stash)
		if (wanted[entry["id"]]) issued += list(entry)
		else remaining += list(entry)
	if (issued.len != wanted.len) return null
	for (var/list/entry in issued)
		var/list/equipment = entry["equipment"]
		if (equipment["schema"] == 2)
			for (var/list/node in equipment["nodes"]) node["found_in_raid"] = FALSE
	candidate["stash"] = remaining
	candidate["raid_sequence"]++
	candidate["state"] = "raid"
	candidate["raid_faction"] = raid_faction
	if (!commit(candidate)) return null
	return list("sequence" = profile["raid_sequence"], "issued" = issued)

/datum/extraction_session/proc/extract(sequence, list/loot)
	if (!active() || profile["state"] != "raid" || sequence != profile["raid_sequence"] || !valid_entries(loot, 16)) return FALSE
	var/list/candidate = copy_profile()
	var/list/stash = candidate["stash"]
	for (var/list/entry in loot) stash += list(entry)
	if (!valid_entries(stash, capacity())) return FALSE
	candidate["state"] = "home"
	return commit(candidate)

/datum/extraction_session/proc/forfeit(sequence)
	if (!active() || profile["state"] != "raid" || sequence != profile["raid_sequence"]) return FALSE
	var/list/candidate = copy_profile()
	candidate["state"] = "home"
	return commit(candidate)

// Credit shipped roots while keeping the raid active. Stable node identities in
// the stash reject replay and overlapping nested shipments without receipt growth.
/datum/extraction_session/proc/deposit(sequence, list/shipment)
	if (!active() || profile["state"] != "raid" || sequence != profile["raid_sequence"] || !valid_entries(shipment, 16) || !shipment.len) return FALSE
	var/list/candidate = copy_profile()
	var/list/stash = candidate["stash"]
	for (var/list/entry in shipment) stash += list(entry)
	if (!valid_entries(stash, capacity())) return FALSE
	return commit(candidate)

// Only home sessions may replace their materialized home stash. Integration
// holds a session lock around serialization and freezes interactions until commit.
/datum/extraction_session/proc/checkpoint_home(list/entries)
	if (!active() || profile["state"] != "home" || !valid_entries(entries, capacity())) return FALSE
	var/list/candidate = copy_profile()
	candidate["stash"] = entries
	return commit(candidate)

// Upgrades consume whole stored salvage entries in the same durable snapshot.
/datum/extraction_session/proc/upgrade(list/salvage_ids)
	if (!active() || profile["state"] != "home" || profile["level"] >= 4 || !islist(salvage_ids) || salvage_ids.len != profile["level"] * 5) return FALSE
	var/list/wanted = list()
	for (var/id in salvage_ids)
		if (!istext(id) || wanted[id]) return FALSE
		wanted[id] = TRUE
	var/list/candidate = copy_profile()
	var/list/stash = candidate["stash"]
	var/list/remaining = list()
	var/consumed = 0
	for (var/list/entry in stash)
		if (wanted[entry["id"]])
			if (entry["salvage"] != TRUE) return FALSE
			consumed++
		else remaining += list(entry)
	if (consumed != wanted.len) return FALSE
	candidate["stash"] = remaining
	candidate["level"]++
	return commit(candidate)

/datum/extraction_session/proc/close()
	if (service && service.sessions[owner] == src) service.sessions -= owner
	closed = TRUE
	profile = null
	service = null
