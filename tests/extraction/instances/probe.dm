#define TRUE 1
#define FALSE 0
#include "../../../code/modules/1713/extraction/instances.dm"

/var/instance_probe_failures = 0

/world
	hub = ""
	hub_password = ""
	visibility = 0

/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

/client/New()
	world.log << "FAIL: unexpected client rejected"
	shutdown()
	return

/proc/check(value, label)
	if (!value)
		instance_probe_failures++
		world.log << "FAIL: [label]"
		return
	world.log << "PASS: [label]"

/proc/record(id, party)
	return list("schema" = 1, "instance_id" = id, "party_id" = party, "kind" = "dagger", "template_id" = "dagger_home_draft_v4", "template_revision" = 1)

/proc/template()
	return list("schema" = 1, "template_id" = "dagger_home_draft_v4", "revision" = 1, "width" = 30, "height" = 102, "decks" = list(list("layer" = 1, "id" = "ground"), list("layer" = 2, "id" = "upper_1"), list("layer" = 3, "id" = "upper_2"), list("layer" = 4, "id" = "roof")), "berths" = list("raid_west", "raid_east"))

/proc/registry_state(datum/extraction_instance_registry/R)
	var/list/entries = list()
	for (var/id in R.homes)
		var/list/entry = R.homes[id]
		var/datum/extraction_instance_token/token = entry["token"]
		entries += list(list(id, entry["signature"], entry["bottom"], entry["top"], "\ref[token]"))
	return json_encode(list(entries, R.logical_bindings))

/world/New()
	..()
	world.OpenPort("none")
	var/list/A = record("home_a", "party_a")
	var/list/B = record("home_b", "party_b")
	var/list/T = template()
	var/datum/extraction_instance_ledger/L = new
	check(L.register(A) && L.register(B) && L.register(A), "distinct logical identities and idempotent registration")
	var/list/saved = json_decode(json_encode(L.snapshot()))
	var/datum/extraction_instance_ledger/restored = new
	check(restored.restore(saved), "logical JSON roundtrip into fresh ledger")
	var/list/bad = extraction_instance_copy(saved)
	var/list/items = bad["instances"]
	items += list("malformed")
	check(!restored.restore(bad) && json_encode(restored.snapshot()) == json_encode(saved), "invalid restore has zero mutation")
	var/datum/extraction_instance_registry/R = new("map_a", "load_1")
	var/list/bounds = list(200, 200, 20)
	var/datum/extraction_instance_token/a = R.reserve_home(A, T, list(1,1,1), bounds, "map_a", "load_1")
	check(a && R.reserve_home(A, T, list(1,1,1), bounds, "map_a", "load_1") == a, "identical acquire returns same lease")
	check(!R.reserve_home(A, T, list(1,1,9), bounds, "map_a", "load_1"), "changed acquire cannot move existing home")
	// Rejected acquisitions get independent registries. A successful mutant
	// must not poison the later disjoint-allocation or release assertions.
	var/datum/extraction_instance_registry/scope_probe = new("map_a", "load_1")
	check(!scope_probe.reserve_home(B, T, list(1,1,5), bounds, "other_map", "load_1") && !scope_probe.reserve_home(B, T, list(1,1,5), bounds, "map_a", "old_load"), "wrong scope acquire rejected")
	var/datum/extraction_instance_registry/overlap_probe = new("map_a", "load_1")
	var/datum/extraction_instance_token/overlap_seed = overlap_probe.reserve_home(A, T, list(1,1,1), bounds, "map_a", "load_1")
	check(overlap_seed && !overlap_probe.reserve_home(B, T, list(100,1,1), bounds, "map_a", "load_1") && overlap_probe.homes.len == 1, "XY-separated homes cannot share z interval")
	check(R.reserve_home(B, T, list(1,1,5), bounds, "map_a", "load_1"), "second party gets disjoint four-deck block")
	var/datum/extraction_instance_registry/stale_home_probe = new("map_a", "load_1")
	var/datum/extraction_instance_token/stale_home_seed = stale_home_probe.reserve_home(A, T, list(1,1,1), bounds, "map_a", "load_1")
	var/stale_home_before = registry_state(stale_home_probe)
	check(stale_home_seed && !stale_home_probe.release_home("home_a", stale_home_seed, "map_a", "old_load") && registry_state(stale_home_probe) == stale_home_before, "stale generation release preserves registry")
	check(R.release_home("home_a", a, "map_a", "load_1") && !R.release_home("home_a", a, "map_a", "load_1"), "release replay rejected")
	var/before_rejection = registry_state(R)
	check(!R.reserve_home(record("home_a", "party_attacker"), T, list(1,1,9), bounds, "map_a", "load_1") && registry_state(R) == before_rejection, "released identity cannot change party and rejection has zero mutation")
	var/list/changed_record = record("home_a", "party_a")
	var/list/changed_template = template()
	changed_record["template_revision"] = 2
	changed_template["revision"] = 2
	check(!R.reserve_home(changed_record, changed_template, list(1,1,9), bounds, "map_a", "load_1") && registry_state(R) == before_rejection, "released identity cannot change template revision")
	changed_template = template()
	changed_template["width"] = 31
	check(!R.reserve_home(A, changed_template, list(1,1,9), bounds, "map_a", "load_1") && registry_state(R) == before_rejection, "released template binding cannot change geometry")
	var/datum/extraction_instance_token/reallocated = R.reserve_home(A, T, list(1,1,9), bounds, "map_a", "load_1")
	check(reallocated && reallocated != a && !R.release_home("home_a", a, "map_a", "load_1"), "reallocation keeps logical ID and rejects old handle")
	var/list/invalid = template()
	var/list/decks = invalid["decks"]
	decks.Cut(4,5)
	check(!R.reserve_home(record("bad", "party_c"), invalid, list(1,1,13), bounds, "map_a", "load_1"), "missing deck rejected")
	invalid = template()
	decks = invalid["decks"]
	var/list/duplicate = decks[4]
	duplicate["layer"] = 3
	check(!R.reserve_home(record("bad", "party_c"), invalid, list(1,1,13), bounds, "map_a", "load_1"), "duplicate layer rejected")
	duplicate["layer"] = 4
	duplicate["id"] = "ground"
	check(!R.reserve_home(record("bad", "party_c"), invalid, list(1,1,13), bounds, "map_a", "load_1"), "duplicate deck ID rejected")
	check(!R.reserve_home(record("bad", "party_c"), T, list(180,1,13), bounds, "map_a", "load_1") && R.homes.len == 2, "out of bounds has zero mutation")
	check(!R.reserve_home(record("bad", "party_c"), T, list(1,1,18), bounds, "map_a", "load_1") && !R.reserve_home(record("bad", "party_c"), T, list(1,1,12.5), bounds, "map_a", "load_1"), "upper z bound and fractional origin rejected")
	invalid = template()
	invalid["schema"] = 2
	check(!R.reserve_home(record("bad", "party_c"), invalid, list(1,1,13), bounds, "map_a", "load_1"), "unknown template version rejected")
	invalid = template()
	invalid["revision"] = 2
	check(!R.reserve_home(record("bad", "party_c"), invalid, list(1,1,13), bounds, "map_a", "load_1"), "mismatched template revision rejected")
	var/datum/extraction_instance_token/west = R.acquire_berth("raid_1", "raid_west", "map_a", "load_1")
	check(west && !R.acquire_berth("raid_1", "raid_west", "map_a", "load_1") && R.acquire_berth("raid_1", "raid_east", "map_a", "load_1"), "occupied west leaves east usable")
	check(!R.release_home("home_a", west, "map_a", "load_1"), "berth token cannot release home")
	var/datum/extraction_instance_registry/stale_berth_probe = new("map_a", "load_1")
	var/datum/extraction_instance_token/stale_berth_seed = stale_berth_probe.acquire_berth("raid_1", "raid_west", "map_a", "load_1")
	check(stale_berth_seed && !stale_berth_probe.release_berth("raid_1", "raid_west", stale_berth_seed, "map_a", "old_load") && stale_berth_probe.berth_tokens["raid_1:raid_west"] == stale_berth_seed, "stale berth release rejected")
	check(R.release_berth("raid_1", "raid_west", west, "map_a", "load_1") && !R.release_berth("raid_1", "raid_west", west, "map_a", "load_1"), "berth release replay rejected")
	check(R.acquire_berth("raid_1", "raid_west", "map_a", "load_1") && !R.release_berth("raid_1", "raid_west", west, "map_a", "load_1"), "old berth handle cannot release new claim")
	check(!R.acquire_berth("raid_1", "unknown", "map_a", "load_1"), "unknown berth rejected")
	var/datum/extraction_instance_registry/fresh = new("map_a", "load_2")
	var/list/fresh_snapshot = restored.snapshot()
	var/list/fresh_records = fresh_snapshot["instances"]
	check(fresh.reserve_home(fresh_records[1], T, list(1,1,1), bounds, "map_a", "load_2") && fresh.reserve_home(fresh_records[2], T, list(1,1,5), bounds, "map_a", "load_2"), "fresh registry rebuilt before future decode")
	check(!fresh.release_home("home_a", reallocated, "map_a", "load_2"), "prior registry handle rejected")
	var/datum/extraction_instance_limits/small = new
	small.max_instances = 1
	small.max_width = 29
	var/datum/extraction_instance_registry/limited = new("map_a", "load_3", small)
	check(!limited.reserve_home(A, T, list(1,1,1), bounds, "map_a", "load_3") && !limited.homes.len, "configured width budget fails closed")
	small.max_width = 30
	check(limited.reserve_home(A, T, list(1,1,1), bounds, "map_a", "load_3") && !limited.reserve_home(B, T, list(1,1,5), bounds, "map_a", "load_3") && limited.homes.len == 1, "configured instance budget fails closed")
	var/list/unknown = record("bad", "party_c")
	unknown["x"] = 1
	check(!L.register(unknown) && L.records.len == 2, "unknown logical field rejected")
	unknown = record("bad", "party_c")
	unknown["schema"] = 2
	check(!L.register(unknown), "unknown logical version rejected")
	bad = extraction_instance_copy(saved)
	items = bad["instances"]
	items += list(record("home_a", "party_a"))
	check(!restored.restore(bad) && json_encode(restored.snapshot()) == json_encode(saved), "duplicate logical ID restore has zero mutation")
	var/list/detached = L.snapshot()
	var/list/detached_items = detached["instances"]
	var/list/detached_record = detached_items[1]
	detached_record["party_id"] = "changed"
	check(json_encode(L.snapshot()) == json_encode(saved), "snapshot mutation cannot change ledger")
	if (!instance_probe_failures) world.log << "INSTANCE PROBE COMPLETE"
	else world.log << "INSTANCE PROBE FAILED: [instance_probe_failures]"
	shutdown()
