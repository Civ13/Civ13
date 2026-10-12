/world
	hub = ""
	hub_password = ""
#ifndef EXTRACTION_MODE_PROBE
	maxx = 8
	maxy = 8
	maxz = 1
#endif
	turf = /turf
	area = /area

var/equipment_failures = 0
var/equipment_completed = FALSE

/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

/world/Error(exception/E)
	equipment_failures++
	world.log << "Runtime error: [E] at [E.file]:[E.line]"

/proc/equipment_assert(condition, message)
	if (!condition) throw EXCEPTION(message)

/world/New()
	world.OpenPort("none")
	spawn(2)
		run_equipment_probe()

/proc/run_equipment_probe()
	try
		GLOB.all_observable_events = list()
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.moved_event = new /decl/observ/moved
		GLOB.destroyed_event = new /decl/observ/destroyed
		var/datum/extraction_equipment_codec/C = new
		var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(1,1,1))
		G.health = 123
		G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(G)
		var/original_ammo = G.ammo_magazine.stored_ammo.len
		var/obj/item/weapon/gun_mount/R = new(G)
		var/obj/item/weapon/attachment/scope/adjustable/advanced/reddot/O = new(R)
		O.A_attached = TRUE
		G.optic_rail = R
		G.recompute_configuration()
		equipment_assert(C.set_raid_provenance(G, TRUE), "raid acquisition marks bounded nested graph")
		var/list/record = C.encode(G)
		equipment_assert(record && C.validate(record), "gun graph encodes and validates")
		equipment_projection_probe(C, record, G.extraction_item_id, O.extraction_item_id, G.serial)
		var/datum/extraction_account_store/store = new
		var/list/P = store.load_profile("equipped")
		P["stash"] = list(list("id" = "configuredrifle", "equipment" = record))
		equipment_assert(store.commit_profile("equipped", P), "equipment persists to native disk journal")
		store = new
		P = store.load_profile("equipped")
		var/list/stash = P["stash"]
		var/list/entry = stash[1]
		var/obj/item/weapon/gun/projectile/pistol/m9beretta/restored = C.decode(entry["equipment"], locate(2,1,1))
		equipment_assert(restored && restored.health == 123 && restored.serial == G.serial, "gun condition and serial survive disk roundtrip")
		equipment_assert(restored.ammo_magazine && restored.ammo_magazine.loc == restored && restored.ammo_magazine.stored_ammo.len == original_ammo, "magazine ammo count is exact")
		equipment_assert(restored.optic_rail && restored.scope && restored.scope.loc == restored.optic_rail && restored.scope.A_attached, "nested rail and optic links restored")
		equipment_assert(restored.ergonomics == G.ergonomics, "configuration does not compound on load")
		equipment_assert(restored.extraction_item_id == G.extraction_item_id && restored.extraction_found_in_raid && restored.scope.extraction_item_id == O.extraction_item_id && restored.scope.extraction_found_in_raid, "nested identities and raid provenance survive native disk reload")
		var/list/duplicate = json_decode(json_encode(record))
		var/list/duplicate_nodes = duplicate["nodes"]
		var/list/first_node = duplicate_nodes[1]
		var/list/second_node = duplicate_nodes[2]
		second_node["id"] = first_node["id"]
		equipment_assert(!C.validate(duplicate), "duplicate nested identity rejected before construction")
		var/list/legacy = json_decode(json_encode(record))
		legacy["schema"] = 1
		var/obj/item/migrated = C.decode(legacy, locate(4,2,1))
		equipment_assert(migrated && migrated.extraction_item_id && !migrated.extraction_found_in_raid && C.encode(migrated)["schema"] == 2, "legacy graph migrates conservatively without invented raid provenance")
		equipment_assert(C.set_raid_provenance(restored, FALSE) && !restored.extraction_found_in_raid && !restored.scope.extraction_found_in_raid && restored.scope.extraction_item_id == O.extraction_item_id, "redeployment clears nested provenance without changing identity")
		var/obj/item/ammo_casing/casing = restored.ammo_magazine.stored_ammo[1]
		casing.expend()
		record = C.encode(restored)
		var/obj/item/weapon/gun/projectile/pistol/m9beretta/spent = C.decode(record, locate(3,1,1))
		var/obj/item/ammo_casing/empty = spent.ammo_magazine.stored_ammo[1]
		equipment_assert(!empty.BB, "spent casing stays spent without free ammunition")
		var/list/bad = json_decode(json_encode(record))
		var/list/graph = bad["nodes"]
		var/list/node = graph[1]
		node["type"] = "/mob/living/human"
		equipment_assert(!C.decode(bad, locate(4,1,1)), "player serialization rejected before construction")
		bad = json_decode(json_encode(record))
		graph = bad["nodes"]
		node = graph[1]
		var/list/scalars = node["scalars"]
		scalars["loc"] = "otherhouse"
		equipment_assert(!C.validate(bad), "location injection rejected")
		G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(locate(5,1,1))
		equipment_assert(!C.encode(G), "external equipment reference rejected")
		equipment_settlement_probe(C)
		equipment_insurance_probe(C)
#ifdef EXTRACTION_MODE_PROBE
		extraction_mode_probe()
#endif
		equipment_completed = TRUE
	catch (var/exception/E)
		equipment_failures++
		world.log << "FAIL: [E] at [E.file]:[E.line]"
	text2file(equipment_completed && !equipment_failures ? "PASS: production equipment disk roundtrip, nested optics, ammo, condition and schema rejection" : "FAIL: equipment verification", "result.txt")
	shutdown()

/proc/equipment_settlement_probe(datum/extraction_equipment_codec/C)
	var/datum/extraction_service/S = new
	S.store.root = "data/production_settlement/"
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(1,2,1))
	G.health = 117
	G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(G)
	var/obj/item/weapon/gun_mount/R = new(G)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/reddot/O = new(R)
	O.A_attached = TRUE
	G.optic_rail = R
	G.recompute_configuration()
	equipment_assert(C.set_raid_provenance(G, TRUE), "settlement fixture marks actual nested items")
	var/list/record = C.encode(G)
	var/root_id = G.extraction_item_id
	var/optic_id = O.extraction_item_id
	var/serial = G.serial
	var/ammo_count = G.ammo_magazine.stored_ammo.len
	var/list/A = S.store.load_profile("seller")
	var/list/B = S.store.load_profile("buyer")
	A["stash"] = list(list("id" = root_id, "equipment" = record))
	B["credits"] = 75
	equipment_assert(S.store.commit_profile("seller", A) && S.store.commit_profile("buyer", B), "production graph stored before release")
	qdel(G)
	equipment_assert(!G.loc, "physical source retired before shared settlement")
	var/list/nextA = json_decode(json_encode(A))
	var/list/nextB = json_decode(json_encode(B))
	nextA["revision"]++
	nextB["revision"]++
	nextA["stash"] = list()
	nextA["credits"] = 75
	nextB["stash"] = A["stash"]
	nextB["credits"] = 0
	var/list/parts = list(list("owner" = "seller", "before" = A, "after" = nextA), list("owner" = "buyer", "before" = B, "after" = nextB))
	equipment_assert(S.settlement_ready() && S.settlement.submit(1, parts), "shared ledger transfers actual compiled graph")
	S = new
	S.store.root = "data/production_settlement/"
	var/datum/extraction_session/seller = S.open("seller")
	var/datum/extraction_session/buyer = S.open("buyer")
	equipment_assert(seller && buyer && !seller.profile["stash"].len && seller.profile["credits"] == 75 && buyer.profile["credits"] == 0, "reopened service exposes only settled owners and payment")
	var/list/entry = buyer.profile["stash"][1]
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/restored = C.decode(entry["equipment"], locate(2,2,1))
	equipment_assert(restored && restored.extraction_item_id == root_id && restored.health == 117 && restored.serial == serial && restored.extraction_found_in_raid, "settled actual gun preserves identity condition serial and provenance")
	equipment_assert(restored.scope && restored.scope.extraction_item_id == optic_id && restored.scope.extraction_found_in_raid && restored.scope.loc == restored.optic_rail && restored.ammo_magazine.stored_ammo.len == ammo_count, "settled actual nested optic and ammunition survive reconstruction")
	equipment_assert(S.settlement.submit(1, parts) && !seller.profile["stash"].len && buyer.profile["stash"].len == 1, "settled production graph replay does not create another stored copy")

/proc/equipment_projection_probe(datum/extraction_equipment_codec/C, list/record, gun_id, optic_id, serial)
	var/digest = md5(json_encode(record))
	var/list/all_ids = list()
	var/list/without_optic = list()
	var/list/without_gun = list()
	for (var/list/node in record["nodes"])
		all_ids += node["id"]
		if (node["id"] != optic_id) without_optic += node["id"]
		if (node["id"] != gun_id) without_gun += node["id"]
	var/list/full = C.project_identities(record, all_ids)
	equipment_assert(full && full.len == 1 && md5(json_encode(full[1])) == digest, "full ownership projection preserves exact graph bytes")
	var/list/empty = C.project_identities(record, list())
	equipment_assert(islist(empty) && !empty.len, "fully recovered graph yields no return candidates")
	equipment_assert(!C.project_identities(record, list("unknown")) && !C.project_identities(record, list(gun_id, gun_id)), "unknown and duplicate ownership identities rejected")
	var/list/remainder = C.project_identities(record, without_optic)
	equipment_assert(remainder && remainder.len == 1, "recovered nested optic removed without losing parent gun")
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = C.decode(remainder[1], locate(3,3,1))
	equipment_assert(G && G.extraction_item_id == gun_id && G.serial == serial && G.health == 123 && !G.scope && G.ammo_magazine, "partial gun reconstruction preserves condition and omits recovered optic")
	qdel(G)
	var/list/separated = C.project_identities(record, without_gun)
	equipment_assert(separated && separated.len >= 2, "surviving components become independent roots when gun recovered")
	var/seen_optic = FALSE
	for (var/list/graph in separated)
		var/obj/item/root = C.decode(graph, locate(4,3,1))
		equipment_assert(root && root.extraction_item_id != gun_id, "removed gun never reconstructed through component projection")
		for (var/list/node in graph["nodes"])
			if (node["id"] == optic_id) seen_optic = TRUE
		qdel(root)
	equipment_assert(seen_optic, "independent surviving optic identity retained")
	var/list/optic_only = C.project_identities(record, list(optic_id))
	var/obj/item/weapon/attachment/optic = C.decode(optic_only[1], locate(5,3,1))
	equipment_assert(optic && optic.extraction_item_id == optic_id && !optic.A_attached && optic.extraction_found_in_raid, "orphan optic becomes unattached with identity and provenance intact")
	qdel(optic)
	equipment_assert(md5(json_encode(record)) == digest, "projection never mutates issued source evidence")

/proc/equipment_insurance_probe(datum/extraction_equipment_codec/C)
	var/datum/extraction_service/S = new
	S.store.root = "data/insurance_ownership/"
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(6,3,1))
	G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(G)
	var/list/record = C.encode(G)
	var/root_id = G.extraction_item_id
	qdel(G)
	var/datum/extraction_session/A = S.open("insured")
	equipment_assert(A.checkpoint_home(list(list("id" = root_id, "equipment" = record))), "provision insurance owner actual gun")
	var/list/raid = A.begin_raid(list(root_id), "PMC", list(root_id), "industrial1")
	equipment_assert(raid && A.profile["insurance_claims"].len == 1 && !A.profile["stash"].len, "insurance issuance and stash debit share native account commit")
	var/list/issued = raid["issued"]
	var/list/entry = issued[1]
	var/token = entry["equipment"]["nodes"][1]["insurance_token"]
	G = C.decode(entry["equipment"], locate(6,4,1))
	equipment_assert(G && G.extraction_insurance_token == token && !G.extraction_found_in_raid, "insurance token materializes on actual issued gun")
	var/list/claimed = C.encode(G)
	equipment_assert(claimed["nodes"][1]["insurance_token"] == token, "actual looted gun retains issue-specific token")
	qdel(G)
	equipment_assert(A.forfeit(raid["sequence"]) && A.profile["insurance_claims"].len == 1, "death forfeiture retains issued evidence without returning gear")
	var/datum/extraction_session/B = S.open("looter")
	var/list/other_raid = B.begin_raid(list())
	equipment_assert(B.deposit(other_raid["sequence"], list(list("id" = root_id, "equipment" = claimed))), "other player shipment credits actual claimed graph")
	equipment_assert(token in B.profile["insurance_recovered"], "shipment atomically records original insurer exclusion token")
	equipment_assert(B.forfeit(other_raid["sequence"]) && B.checkpoint_home(list()), "recovered item can be consumed after raid")
	equipment_assert(token in B.profile["insurance_recovered"], "later item consumption cannot resurrect previous claim eligibility")
	A.close()
	B.close()
	S = new
	S.store.root = "data/insurance_ownership/"
	A = S.open("insured")
	B = S.open("looter")
	equipment_assert(A && B && A.profile["insurance_claims"].len == 1 && (token in B.profile["insurance_recovered"]) && !A.profile["stash"].len && !B.profile["stash"].len, "native reopen preserves claims and recovery evidence without payout")
	var/list/bad = A.copy_profile()
	bad["insurance_claims"][1]["entry"]["equipment"]["nodes"][1]["insurance_token"] = md5("forged")
	equipment_assert(!A.commit(bad), "forged issue identity rejected before journal write")
	var/list/reissued = json_decode(json_encode(entry))
	equipment_assert(A.checkpoint_home(list(reissued)), "fixture restores same identity for subsequent issue")
	var/list/next = A.begin_raid(list(root_id), "PMC", list(root_id), "industrial1")
	var/new_token = next["issued"][1]["equipment"]["nodes"][1]["insurance_token"]
	equipment_assert(next && new_token != token && A.profile["insurance_claims"].len == 2, "later issue of same item receives independent claim token")
	equipment_assert(!(new_token in B.profile["insurance_recovered"]), "old recovery receipt does not exclude later independently insured issue")
	var/list/projected = C.project_identities(next["issued"][1]["equipment"], list(root_id))
	equipment_assert(projected && projected[1]["nodes"][1]["insurance_token"] == new_token, "partial return projection preserves exact issue-specific token")
	var/list/bounded = A.copy_profile()
	bounded["raid_sequence"] = 65
	bounded["insurance_claims"] = list()
	for (var/i in 1 to 65)
		var/list/claim = json_decode(json_encode(A.profile["insurance_claims"][1]))
		claim["sequence"] = i
		for (var/list/node in claim["entry"]["equipment"]["nodes"])
			node["insurance_token"] = md5(json_encode(list(A.owner, claim["round"], i, node["id"])))
		bounded["insurance_claims"] += list(claim)
	equipment_assert(!S.insurance_profile_valid(bounded), "claim archive refuses 65 roots instead of evicting ownership evidence")
	bounded["insurance_claims"].Cut(65, 66)
	equipment_assert(S.insurance_profile_valid(bounded), "64-root claim archive remains valid at boundary")
	bounded["insurance_recovered"] = list()
	for (var/i in 1 to 4097) bounded["insurance_recovered"] += md5("recovered[i]")
	equipment_assert(!S.insurance_profile_valid(bounded), "recovery evidence refuses 4097 tokens instead of forgetting exclusions")
	bounded["insurance_recovered"].Cut(4097, 4098)
	equipment_assert(S.insurance_profile_valid(bounded), "4096 recovered tokens remain valid at boundary")
