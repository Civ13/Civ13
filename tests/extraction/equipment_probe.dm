/world
	hub = ""
	hub_password = ""
#ifndef EXTRACTION_MODE_PROBE
#ifdef EXTRACTION_VEHICLE_PROCESS_PROBE
	maxx = 24
	maxy = 24
#else
#ifdef EXTRACTION_GROUP_PROCESS_PROBE
	maxx = 24
	maxy = 24
#else
	maxx = 8
	maxy = 8
#endif
#endif
	maxz = 1
#endif
	turf = /turf
	area = /area

var/equipment_failures = 0
var/equipment_completed = FALSE

/datum/insurance_gate_observer
	proc/check(datum/extraction_service/S)
		return !S.open("inventoryvisitor") && !S.sessions["insured"].active() && !S.sessions["insured"].checkpoint_home(list())

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
#ifdef EXTRACTION_VEHICLE_PROCESS_PROBE
		run_vehicle_process_probe()
#else
#ifdef EXTRACTION_GROUP_PROCESS_PROBE
		run_group_process_probe()
#else
#ifdef EXTRACTION_RETURNS_PROCESS_PROBE
		run_insurance_process_probe()
#else
		run_equipment_probe()
#endif
#endif
#endif

/proc/equipment_medical_stack_probe(datum/extraction_equipment_codec/C)
	var/list/paths = list(/obj/item/stack/medical/bruise_pack/bint, /obj/item/stack/medical/splint)
	for (var/path in paths)
		var/obj/item/stack/medical/I = new path(null)
		I.amount = 2
		var/list/graph = C.encode(I)
		equipment_assert(graph, "exact pharmacy stack serializes actual quantity")
		var/obj/item/stack/medical/restored = C.decode(graph, locate(3,7,1))
		equipment_assert(restored && restored.type == path && restored.amount == 2 && restored.extraction_item_id == I.extraction_item_id, "pharmacy stack roundtrip preserves actual type quantity and identity")
		for (var/invalid in list(0, -1, 1.5, initial(I.max_amount) + 1))
			graph["nodes"][1]["scalars"]["amount"] = invalid
			equipment_assert(!C.validate(graph), "pharmacy stack rejects empty fractional and oversized quantity")
		qdel(I)
		qdel(restored)
	equipment_assert(!C.supported(/obj/item/stack/medical/bruise_pack/bint/medic) && !C.supported(/obj/item/stack/medical/splint/small), "pharmacy codec does not admit uncatalogued medical subtypes")

/proc/equipment_workshop_material_probe(datum/extraction_equipment_codec/C)
	equipment_workshop_wheel_install_probe()
	var/obj/item/extraction_generator_kit/kit = new(null)
	var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/tank = kit.tank()
	equipment_assert(tank && !tank.reagents.total_volume && !kit.engine && !kit.cable, "paid generator has an actual empty tank and no free supply")
	tank.reagents.add_reagent("gasoline", 17, safety = TRUE)
	kit.generator_broken = TRUE
	var/list/power_record = C.encode(kit)
	var/obj/item/extraction_generator_kit/power_restored = C.decode(power_record, locate(1,1,1))
	var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/restored_tank = power_restored?.tank()
	equipment_assert(power_restored && power_restored.generator_broken && restored_tank?.reagents.get_reagent_amount("gasoline") == 17 && !power_restored.engine && !power_restored.cable, "generator reload preserves paid fuel and damage without restoring live supply or callbacks")
	var/list/bad_power = json_decode(json_encode(power_record))
	bad_power["nodes"][1]["scalars"]["generator_broken"] = 100
	equipment_assert(!C.validate(bad_power), "generator condition cannot become arbitrary supply state")
	bad_power = json_decode(json_encode(power_record))
	bad_power["nodes"].Cut(2)
	equipment_assert(!C.validate(bad_power), "missing actual fuel container rejects before generator restoration")
	equipment_assert(!kit.install(null), "unowned generator cannot create a native power installation")
	qdel(kit)
	qdel(power_restored)
	var/obj/item/extraction_wheel_crate/boxed = new(null)
	boxed.wheel.wconfig.current_health = 31
	var/list/wheel_record = C.encode(boxed)
	equipment_assert(wheel_record && C.validate(wheel_record), "paid wheel crate contains supported actual native wheel")
	var/obj/item/extraction_wheel_crate/restored_wheel = C.decode(wheel_record, locate(1,1,1))
	equipment_assert(restored_wheel && restored_wheel.contents.len == 1 && restored_wheel.wheel.loc == restored_wheel && restored_wheel.wheel.extraction_vehicle_part_id == boxed.wheel.extraction_vehicle_part_id && restored_wheel.wheel.wconfig.current_health == 31 && !restored_wheel.wheel.axis && !restored_wheel.wheel.connected, "wheel restoration preserves actual loose component identity and wear without free duplicate")
	var/list/bad_wheel = json_decode(json_encode(wheel_record))
	bad_wheel["nodes"][1]["packed_wheel"]["config"]["base_speed"] = 999
	equipment_assert(!C.validate(bad_wheel), "wheel payload cannot upgrade native performance")
	bad_wheel = json_decode(json_encode(wheel_record))
	bad_wheel["nodes"][1]["packed_wheel"]["id"] = bad_wheel["nodes"][1]["id"]
	equipment_assert(!C.validate(bad_wheel), "wheel and crate cannot share an ownership identity")
	boxed.wheel.anchored = TRUE
	equipment_assert(!C.encode(boxed), "anchored wheel cannot become a portable paid component")
	qdel(boxed)
	qdel(restored_wheel)
	var/obj/item/stack/material/glass/glass = new(null)
	glass.amount = 6
	var/list/glass_record = C.encode(glass)
	equipment_assert(glass_record && C.validate(glass_record), "paid workshop glass is supported")
	var/obj/item/stack/material/glass/restored_glass = C.decode(glass_record, locate(1,1,1))
	equipment_assert(restored_glass && restored_glass.amount == 6 && restored_glass.extraction_item_id == glass.extraction_item_id, "glass restoration preserves amount and identity")
	var/obj/item/stack/cable_coil/cable = new(null)
	cable.amount = 10
	cable.cable_color = "red"
	var/list/cable_record = C.encode(cable)
	equipment_assert(cable_record && C.validate(cable_record), "paid workshop cable is supported")
	var/obj/item/stack/cable_coil/restored_cable = C.decode(cable_record, locate(1,1,1))
	var/obj/item/stack/cable_coil/second_cable = C.decode(cable_record, locate(1,1,1))
	equipment_assert(restored_cable && second_cable && restored_cable != second_cable && restored_cable.amount == 10 && second_cable.amount == 10 && restored_cable.cable_color == "red" && restored_cable.extraction_item_id == cable.extraction_item_id, "cable restores isolated amount, color and identity without constructor merging")
	equipment_assert(!restored_cable.throwing && !second_cable.throwing, "restoration releases temporary stack crossing guard")
	cable_record["nodes"][1]["scalars"]["amount"] = 51
	equipment_assert(!C.validate(cable_record), "oversized cable stock rejects before construction")
	cable_record["nodes"][1]["scalars"]["amount"] = 0
	equipment_assert(!C.validate(cable_record), "empty cable stock rejects before construction")
	cable_record["nodes"][1]["scalars"]["amount"] = 10
	cable_record["nodes"][1]["scalars"]["cable_color"] = "invalid"
	equipment_assert(!C.validate(cable_record), "unknown cable color rejects before construction")
	qdel(glass)
	qdel(restored_glass)
	qdel(cable)
	qdel(restored_cable)
	qdel(second_cable)

/proc/equipment_workshop_wheel_install_probe()
	var/obj/structure/car_workshop/extraction_private/W = new(null)
	var/obj/structure/vehicleparts/axis/car/A = new(null)
	A.wheels = list()
	A.corners = list()
	W.paid_wheels = list()
	var/list/originals = list()
	for (var/i in 1 to 4)
		var/obj/structure/vehicleparts/frame/car/F = new(locate(i,7,1))
		F.axis = A
		A.corners += F
		var/obj/structure/vehicleparts/movement/template = new(F)
		template.axis = A
		template.connected = F
		F.mwheel = template
		A.wheels += template
		var/obj/item/extraction_wheel_crate/C = new(null)
		C.wheel.wconfig.current_health = 20 + i
		originals += C.wheel
		W.paid_wheels += C
	var/list/templates = A.wheels.Copy()
	var/list/full = W.paid_wheels.Copy()
	W.busy = TRUE
	W.powerneeded = 20
	equipment_assert(!W.draw_cable_power(), "unconnected private press cannot manufacture native power")
	W.finish_work()
	equipment_assert(!W.busy && !W.powerneeded && !W.paid_wheels && !W.build_session, "cancel cleanup releases busy power and all paid preview references")
	W.paid_wheels = full.Copy()
	W.paid_wheels.len = 3
	equipment_assert(!W.install_paid_wheels(A) && A.wheels.len == 4 && originals[1]:loc == full[1], "missing paid wheel preserves all original crates and template layout")
	W.paid_wheels = list(full[1], full[1], full[3], full[4])
	equipment_assert(!W.install_paid_wheels(A) && A.wheels[1] == templates[1], "duplicate paid crate rejects before any wheel retirement")
	W.paid_wheels = full
	equipment_assert(W.install_paid_wheels(A) && A.wheels.len == 4, "native attachment substitutes exactly four paid original wheels")
	for (var/i in 1 to 4)
		var/obj/structure/vehicleparts/movement/original = originals[i]
		equipment_assert((original in A.wheels) && original.axis == A && original.connected == A.corners[i] && original.loc == A.corners[i] && original.wconfig.current_health == 20 + i && length(original.extraction_vehicle_part_id), "assembled wheel retains actual identity and paid wear")
	for (var/obj/structure/vehicleparts/frame/F in A.corners.Copy()) qdel(F)
	qdel(A)
	qdel(W)

/proc/equipment_workshop_reservation_probe(datum/extraction_equipment_codec/C)
	var/datum/extraction_service/service = new
	var/datum/extraction_session/S = service.open("componentbuilder")
	equipment_assert(S, "construction reservation fixture opens isolated account")
	var/list/candidate = S.copy_profile()
	candidate["level"] = 2 // Fixture prerequisite, not evidence of earned upgrade.
	var/list/items = list()
	var/list/entries = list()
	var/list/payment = list()
	var/list/paths = list(/obj/item/stack/material/steel, /obj/item/stack/material/glass, /obj/item/stack/material/cloth, /obj/item/stack/cable_coil)
	var/list/amounts = list(40, 6, 4, 10)
	for (var/i in 1 to paths.len)
		var/path = paths[i]
		var/obj/item/stack/I = new path(null)
		I.amount = amounts[i]
		items += I
	for (var/i in 1 to 4) items += new /obj/item/extraction_wheel_crate(null)
	for (var/obj/item/I in items)
		var/list/graph = C.encode(I)
		equipment_assert(graph, "reservation uses actual supported component graph")
		entries += list(list("id" = I.extraction_item_id, "equipment" = graph, "secure" = FALSE))
		payment += I.extraction_item_id
	candidate["stash"] = entries
	equipment_assert(S.commit(candidate), "construction fixture checkpoints actual paid input identities")
	var/obj/structure/car_workshop/W = new(null)
	var/list/required = W.costs("ASNO Piccolino")
	qdel(W)
	var/before = json_encode(S.profile)
	var/list/plan = S.plan_vehicle_construction(payment, S.profile["revision"], required)
	equipment_assert(plan && !plan["stash"].len && plan["garage_purchase"]["inputs"].len == 8 && json_encode(S.profile) == before, "pure native-cost reservation preserves full paid graph evidence without mutating account")
	equipment_assert(!S.plan_vehicle_construction(payment, S.profile["revision"] - 1, required), "stale construction quote cannot reserve components")
	var/list/discount = required.Copy()
	discount["steel"] = 1
	equipment_assert(!S.plan_vehicle_construction(payment, S.profile["revision"], discount), "caller cannot discount production workshop recipe")
	var/list/missing = payment.Copy()
	missing.len--
	equipment_assert(!S.plan_vehicle_construction(missing, S.profile["revision"], required), "missing fourth native wheel rejects construction reservation")
	equipment_assert(S.commit(plan), "construction reservation is durable before physical components retire")
	var/obj/structure/car_workshop/extraction_private/interrupted = new(null)
	interrupted.build_session = S
	interrupted.busy = TRUE
	interrupted.finish_work()
	equipment_assert(S.locked && !interrupted.busy && !interrupted.build_session, "paid interruption locks account while releasing runtime work references")
	qdel(interrupted)
	var/list/loaded = service.store.load_profile(S.owner)
	equipment_assert(loaded && loaded["garage_purchase"]["status"] == "pending" && json_encode(loaded["garage_purchase"]["inputs"]) == json_encode(plan["garage_purchase"]["inputs"]), "native journal retains exact interrupted construction component evidence")
	S.close()
	equipment_assert(!service.open("componentbuilder"), "interrupted paid construction quarantines admission instead of refunding or reissuing components")
	for (var/obj/item/I in items) qdel(I)

/proc/run_equipment_probe()
	try
		GLOB.all_observable_events = list()
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.moved_event = new /decl/observ/moved
		GLOB.destroyed_event = new /decl/observ/destroyed
#ifdef EXTRACTION_NPC_PROBE
		extraction_npc_probe()
#else
		run_economy_probe()
		var/datum/extraction_equipment_codec/C = new
		container_key_catalog_probe()
		equipment_container_key_codec_probe(C)
		container_key_sprite_codec_probe()
		vehicle_key_identity_probe(C)
		equipment_medical_stack_probe(C)
		equipment_workshop_material_probe(C)
		equipment_workshop_reservation_probe(C)
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
		equipment_projection_probe(C, record, G.extraction_item_id, O.extraction_item_id, G.serial)
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
		equipment_insurance_returns_probe(C)
#ifdef EXTRACTION_MODE_PROBE
#ifdef EXTRACTION_CITY_PROBE
		extraction_city_probe()
#else
		extraction_mode_probe()
#endif
#endif
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
	var/datum/extraction_insurance_inventory/inventory = new(S)
	inventory.test_access_observer = new /datum/insurance_gate_observer
	var/list/index = inventory.build("industrial1")
	equipment_assert(index && index[token]["status"] == "recovered" && index[new_token]["status"] == "unrecovered" && A.active(), "bounded round inventory separates old recovery from new claim and releases access gate")
	var/list/no_round = inventory.build("otherround")
	equipment_assert(islist(no_round) && !no_round.len, "other round has no claim candidates")
	var/datum/extraction_session/holder = S.open("holder")
	equipment_assert(holder.checkpoint_home(next["issued"]), "fixture materializes stored ownership without recovery marker")
	index = inventory.build("industrial1")
	equipment_assert(index && index[new_token]["status"] == "stored", "current stored owner excludes return even without its recovery marker")
	var/datum/extraction_session/conflict = S.open("conflict")
	equipment_assert(conflict.checkpoint_home(next["issued"]), "fixture injects competing stored node identities")
	equipment_assert(!inventory.build("industrial1") && A.active(), "conflicting stored ownership blocks planning without retaining service gate")
	equipment_assert(conflict.checkpoint_home(list()) && holder.checkpoint_home(list()), "fixture clears conflicting ownership")
	equipment_assert(!inventory.revalidate(), "unfrozen inventory cannot authorize a later write")
	S.insurance_busy = TRUE
	equipment_assert(!inventory.revalidate(), "changed account revisions invalidate a prior inventory")
	S.insurance_busy = FALSE
	equipment_assert(inventory.build("industrial1"), "refresh ownership index after changed accounts")
	S.insurance_busy = TRUE
	equipment_assert(inventory.revalidate(), "unchanged exact profiles validate under retained service gate")
	S.insurance_busy = FALSE
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
	var/list/pending = S.store.load_profile("pendingaccount")
	S.store.test_fail_at = "intent"
	equipment_assert(!S.store.commit_profile("pendingaccount", pending), "inject unresolved nonparticipant account journal")
	S.store.test_fail_at = null
	equipment_assert(!inventory.build("industrial1") && !S.insurance_busy, "unresolved nonparticipant journal prevents insurance inference and releases read gate")

/proc/equipment_insurance_returns_probe(datum/extraction_equipment_codec/C)
	equipment_insurance_shards_probe(C)
	equipment_insurance_generation_probe(C)
	equipment_paid_insurance_probe(C)
	equipment_partial_insurance_probe(C)
	equipment_insurance_capacity_probe(C)
	var/list/cuts = list("before_prepare", "after_prepare", "retire1", "retirement_intent", "retirement_snapshot", "after_retirement", "mail_intent", "mail_snapshot", "apply1", "round_intent", "round_snapshot", "finalize_intent", "finalize_snapshot")
	for (var/i in 1 to cuts.len)
		var/cut = cuts[i]
		var/datum/extraction_service/S = new
		S.store.root = "data/insurance_returns[i]/"
		var/datum/extraction_session/A = S.open("returnowner")
		var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(6,5,1))
		G.health = 101
		G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(G)
		var/list/record = C.encode(G)
		var/id = G.extraction_item_id
		qdel(G)
		equipment_assert(A.checkpoint_home(list(list("id" = id, "equipment" = record))), "return fixture provisions native gun")
		var/list/issued = A.begin_raid(list(id), "PMC", list(id), "returnround")
		G = C.decode(issued["issued"][1]["equipment"], locate(6,5,1))
		G.health = 83
		equipment_assert(A.forfeit(issued["sequence"]), "return fixture records death without payout")
		A.close()
		var/datum/extraction_insurance_returns/returns = new(S, C)
		returns.test_fail_at = cut
		equipment_assert(!returns.prepare("returnround", list(G)), "[cut] interruption does not acknowledge payout")
		returns.test_fail_at = null
		if (cut == "before_prepare")
			equipment_assert(G.loc && returns.ready(), "unaccepted plan leaves physical gun and service available")
			equipment_assert(returns.prepare("returnround", list(G)), "retry unaccepted return plan")
		else if (cut == "after_prepare" || cut == "retire1")
			equipment_assert(!returns.ready() && !S.open("returnowner"), "prepared return remains inaccessible before retirement receipt")
			equipment_assert(returns.retire(), "same-world retirement resumes exact retained physical references")
		else
			S = new
			S.store.root = "data/insurance_returns[i]/"
			returns = new(S, C)
			equipment_assert(returns.ready(), "[cut] native journal reopen finishes only retired account projections")
		equipment_assert(!G || !G.loc, "physical source retired before returned ownership is exposed")
		A = S.open("returnowner")
		equipment_assert(A && !A.profile["stash"].len && !A.profile["insurance_claims"].len && equipment_mail_entries(A.service, A.owner).len == 1, "[cut] claim resolution and bounded mailbox credit commit together")
		var/list/entry = equipment_mail_entries(A.service, A.owner)[1]
		var/obj/item/weapon/gun/projectile/pistol/m9beretta/restored = C.decode(entry["equipment"], locate(7,5,1))
		equipment_assert(restored && restored.extraction_item_id == id && restored.health == 83 && restored.ammo_magazine && !restored.ammo_magazine.stored_ammo.len, "returned actual gun keeps lost condition and identity without insured ammunition")
		qdel(restored)
		equipment_assert(!A.claim_insurance_mail(list(id)), "loss closure and journal reopen cannot unlock pending return")
		A.close()
		equipment_assert(returns.prepare("additionalfullround", list()), "a separate full completed round advances durable eligibility")
		A = S.open("returnowner")
		equipment_assert(A.claim_insurance_mail(list(id)) && !equipment_mail_entries(A.service, A.owner).len && A.profile["stash"].len == 1, "claim moves one mailbox graph into persisted stash")
		equipment_assert(!A.claim_insurance_mail(list(id)), "mailbox claim replay cannot produce another stored copy")
		A.close()
		equipment_assert(!returns.prepare("returnround", list()), "resolved round cannot replay payout")

/proc/equipment_insurance_generation_probe(datum/extraction_equipment_codec/C)
	var/datum/extraction_service/S = new
	S.store.root = "data/insurance_generations/"
	var/datum/extraction_insurance_returns/R = new(S, C)
	equipment_assert(R.ready() && R.profile["completed_generation"] == 0, "new storage starts with no completed rounds")
	equipment_assert(R.prepare("earlyround", list(), FALSE) && R.profile["completed_generation"] == 0, "early closure retains completed generation")
	equipment_assert(R.prepare("fullround", list()) && R.profile["completed_generation"] == 1, "full closure advances completed generation exactly once")
	R = new(S, C)
	equipment_assert(R.ready() && R.profile["completed_generation"] == 1 && !R.prepare("earlyround", list()), "restart and historical round replay cannot fabricate a completion")
	var/list/P = json_decode(json_encode(R.profile))
	P["completed_generation"] = 16777214
	equipment_assert(R.journal.commit_profile("world", P), "fixture provisions exact native counter boundary on disk")
	R = new(S, C)
	equipment_assert(R.ready() && !R.prepare("overflowround", list()) && R.profile["completed_generation"] == 16777214, "counter overflow fails closed without losing existing records")
	equipment_assert(!extraction_insurance_generation(-1) && !extraction_insurance_generation(0.5) && !extraction_insurance_generation(16777216), "invalid or inexact generation values are rejected")

/proc/equipment_insurance_capacity_probe(datum/extraction_equipment_codec/C)
	var/datum/extraction_service/S = new
	S.store.root = "data/return_capacity/"
	var/datum/extraction_session/A = S.open("capacityowner")
	var/obj/item/extraction_salvage/part = new(locate(1,6,1))
	var/list/template = C.encode(part)
	qdel(part)
	var/list/P = A.copy_profile()
	P["insurance_mailbox"] = list()
	for (var/i in 1 to 64)
		var/list/graph = json_decode(json_encode(template))
		var/id = md5("existingreturn[i]")
		graph["nodes"][1]["id"] = id
		P["insurance_mailbox"] += list(list("id" = id, "equipment" = graph))
	equipment_assert(A.commit(P), "mailbox capacity fixture stores 64 distinct native graph roots")
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(1,6,1))
	var/list/record = C.encode(G)
	var/id = G.extraction_item_id
	qdel(G)
	equipment_assert(A.checkpoint_home(list(list("id" = id, "equipment" = record))), "capacity fixture provisions insurable gun")
	var/list/raid = A.begin_raid(list(id), "PMC", list(id), "capacityround")
	G = C.decode(raid["issued"][1]["equipment"], locate(1,6,1))
	var/token = G.extraction_insurance_token
	equipment_assert(A.forfeit(raid["sequence"]), "capacity fixture forfeits issued graph")
	A.close()

	var/datum/extraction_insurance_returns/returns = new(S, C)
	G.extraction_insurance_token = md5("forgedphysicaltoken")
	equipment_assert(!returns.prepare("capacityround", list(G)) && G.loc && returns.ready(), "forged physical token cannot silently void or redirect original claim")
	G.extraction_insurance_token = token
	returns.test_fail_at = "after_prepare"
	equipment_assert(!returns.prepare("capacityround", list(G)) && G.loc, "prepare persists plan before physical retirement")
	returns.test_fail_at = null
	G.health--
	equipment_assert(!returns.retire() && G.loc && !returns.ready(), "changed physical condition after receipt blocks retirement and payout")
	G.health++
	equipment_assert(returns.retire() && (!G || !G.loc), "exact restored fixture condition permits original retirement plan")
	A = S.open("capacityowner")
	equipment_assert(A && equipment_mail_entries(A.service, A.owner).len == 65 && !A.profile["insurance_mailbox"].len, "legacy migration plus surviving gun retains 65 returns without a mailbox cap")
	P = A.copy_profile()
	P["stash"] = list()
	for (var/i in 1 to 16)
		var/list/graph = json_decode(json_encode(template))
		var/stash_id = md5("fullstash[i]")
		graph["nodes"][1]["id"] = stash_id
		P["stash"] += list(list("id" = stash_id, "equipment" = graph))
	equipment_assert(A.commit(P), "capacity fixture fills home stash")
	var/revision = A.profile["revision"]
	equipment_assert(!A.claim_insurance_mail(list(id)) && A.profile["revision"] == revision && equipment_mail_entries(A.service, A.owner).len == 65, "full stash withholds delivery without losing mailbox graph or advancing revision")
	P = A.copy_profile()
	P["stash"].Cut(1,2)
	equipment_assert(A.commit(P), "legacy fixture frees exactly one finite stash slot")
	var/legacy_id = md5("latelegacyreturn")
	var/list/legacy_graph = json_decode(json_encode(template))
	legacy_graph["nodes"][1]["id"] = legacy_id
	P = A.copy_profile()
	P["insurance_mailbox"] = list(list("id" = legacy_id, "equipment" = legacy_graph))
	equipment_assert(A.commit(P), "fixture adds a historical unstamped return after current completion")
	equipment_assert(!A.claim_insurance_mail(list(legacy_id)), "legacy unstamped return receives conservative persisted future eligibility")
	var/list/legacy_index = returns.mail.identity(legacy_id)
	var/list/legacy_page = returns.mail.page(A.owner, legacy_index["sequence"])
	equipment_assert(legacy_page["entries"][legacy_page["entries"].len]["eligible_generation"] == returns.profile["completed_generation"] + 1, "migration persists conservative eligibility in shard")
	A.close()
	A = S.open("capacityowner")
	equipment_assert(!A.claim_insurance_mail(list(legacy_id)), "legacy reconnect preserves pending generation rather than resetting or unlocking it")
	A.close()
	equipment_assert(returns.prepare("legacyadditionalround", list()), "legacy return waits for a separate full completed round")
	A = S.open("capacityowner")
	equipment_assert(A.claim_insurance_mail(list(legacy_id)) && equipment_mail_entries(A.service, A.owner).len == 65, "eligible legacy graph moves once into finite available stash space")
	A.close()

/proc/equipment_paid_insurance_probe(datum/extraction_equipment_codec/C)
	var/datum/extraction_service/S = new
	S.store.root = "data/paid_insurance/"
	var/datum/extraction_insurance_returns/R = new(S, C)
	var/datum/extraction_session/A = S.open("paidowner")
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(2,6,1))
	if (G.ammo_magazine) qdel(G.ammo_magazine)
	G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(G)
	var/list/graph = C.encode(G)
	var/id = G.extraction_item_id
	qdel(G)
	var/list/stash = list(list("id" = id, "equipment" = graph))
	for (var/i in 1 to 4)
		var/obj/item/extraction_salvage/I = new(locate(2,6,1))
		var/list/part = C.encode(I)
		stash += list(list("id" = I.extraction_item_id, "equipment" = part))
		qdel(I)
	equipment_assert(A.checkpoint_home(stash), "paid fixture provisions gun, magazine and four obtainable workshop parts")
	var/list/offer = R.quote(A, list(id), "paidround")
	equipment_assert(offer && offer["cost"] == 3 && offer["payment"].len == 3, "paid quote charges actual gun, default iron sight and magazine, excluding all ammunition")
	equipment_assert(A.checkpoint_home(stash) && !R.paid_deploy(A, offer, "PMC"), "stale paid quote cannot debit account or issue claims")
	offer = R.quote(A, list(id), "paidround")
	var/list/forged = json_decode(json_encode(offer))
	forged["cost"] = 0
	equipment_assert(!R.paid_deploy(A, forged, "PMC") && A.profile["stash"].len == 5, "altered quote cannot bypass payment")
	var/list/raid = R.paid_deploy(A, offer, "PMC")
	equipment_assert(raid && A.profile["stash"].len == 1 && A.profile["insurance_claims"].len == 1, "payment, issuance, sequence and stash debit commit together")
	equipment_assert(!R.paid_deploy(A, offer, "PMC"), "paid deployment replay cannot charge or issue twice")
	G = C.decode(raid["issued"][1]["equipment"], locate(2,6,1))
	G.health = 61
	equipment_assert(A.forfeit(raid["sequence"]), "paid raid loss commits without payout")
	A.close()
	equipment_assert(R.prepare("paidround", list(G)), "paid lost gear retires through native return consumer")
	A = S.open("paidowner")
	equipment_assert(A && A.profile["stash"].len == 1 && equipment_mail_entries(A.service, A.owner).len == 1, "paid claim returns gear once without refunding consumed premium")
	A.close()

/proc/equipment_partial_insurance_probe(datum/extraction_equipment_codec/C)
	equipment_scope_insurance_probe(C)
	var/datum/extraction_service/S = new
	S.store.root = "data/partial_insurance/"
	var/datum/extraction_session/A = S.open("nestedowner")
	var/obj/item/weapon/storage/backpack/bag = new(locate(3,6,1))
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(bag)
	var/list/graph = C.encode(bag)
	var/bag_id = bag.extraction_item_id
	var/gun_id = G.extraction_item_id
	qdel(bag)
	equipment_assert(A.checkpoint_home(list(list("id" = bag_id, "equipment" = graph))), "partial recovery provisions insured bag with nested actual gun")
	var/list/raid = A.begin_raid(list(bag_id), "PMC", list(bag_id), "partialround")
	bag = C.decode(raid["issued"][1]["equipment"], locate(3,6,1))
	G = locate(/obj/item/weapon/gun/projectile/pistol/m9beretta) in bag
	G.forceMove(locate(3,6,1))
	G.health = 63
	equipment_assert(A.forfeit(raid["sequence"]), "partial recovery forfeits original issued bag")
	A.close()
	var/datum/extraction_session/B = S.open("bagrecoverer")
	var/list/other = B.begin_raid(list())
	equipment_assert(B.extract(other["sequence"], list(list("id" = bag_id, "equipment" = C.encode(bag)))), "another account recovers only empty insured parent bag")
	qdel(bag)
	B.close()
	var/datum/extraction_insurance_returns/R = new(S, C)
	equipment_assert(R.prepare("partialround", list(G)), "unrecovered detached insured child retires independently of recovered parent")
	A = S.open("nestedowner")
	equipment_assert(equipment_mail_entries(A.service, A.owner).len == 1 && equipment_mail_entries(A.service, A.owner)[1]["id"] == gun_id, "partial return credits actual gun without recreating recovered parent")
	var/list/entry = equipment_mail_entries(A.service, A.owner)[1]
	G = C.decode(entry["equipment"], locate(3,6,1))
	equipment_assert(G && G.extraction_item_id == gun_id && G.health == 63 && istype(G.loc, /turf), "partial returned child retains current condition and independent root placement")
	qdel(G)
	A.close()
	B = S.open("bagrecoverer")
	equipment_assert(B.profile["stash"].len == 1 && B.profile["stash"][1]["id"] == bag_id && !equipment_mail_entries(B.service, B.owner).len, "recovered parent ownership remains unchanged with no duplicate insurance credit")
	B.close()

/proc/vehicle_key_identity_probe(datum/extraction_equipment_codec/C)
	var/datum/vehicle_key_service/original = vehicle_key_service
	vehicle_key_service = new
	vehicle_key_service.store.root = "data/vehicle_key_identity_probe/"
	var/obj/structure/vehicleparts/axis/car/A = new(null)
	equipment_assert(!A.keyed_vehicle_id && A.key_generation == 0, "vehicle constructor never mints keyed identity")
	var/obj/item/vehicle_key/K = vehicle_key_service.issue_constructed(A, locate(1, 1, 1))
	equipment_assert(K && K.matches(A) && vehicle_key_service.ready_vehicle(A), "paid construction issuance binds stable vehicle and key generation")
	var/id = A.keyed_vehicle_id
	equipment_assert(!vehicle_key_service.issue_constructed(A, locate(1, 1, 1)) && A.keyed_vehicle_id == id, "construction retry never reissues or changes identity")
	var/list/graph = C.encode(K)
	equipment_assert(graph && C.validate(graph), "vehicle key graph validates exact binding")
	var/savefile/F = new("data/vehicle_key_graph.sav")
	F["key"] << graph
	var/list/reloaded
	F["key"] >> reloaded
	var/obj/item/vehicle_key/copy = C.decode(reloaded, null)
	equipment_assert(copy && copy.matches(A) && copy.extraction_item_id == K.extraction_item_id, "native disk key graph preserves binding and item identity")
	copy.vehicle_id = new_extraction_item_id()
	equipment_assert(!copy.matches(A), "wrong vehicle key rejected")
	copy.vehicle_id = id
	copy.key_generation = 0
	equipment_assert(!C.encode(copy), "zero-generation vehicle key rejected by codec")
	copy.key_generation = 1
	var/list/P = vehicle_key_service.store.load_profile(id)
	P["vehicle_key_state"] = "pending"
	equipment_assert(vehicle_key_service.store.commit_profile(id, P) && !vehicle_key_service.ready_vehicle(A), "interrupted service quarantines vehicle without key reissue")
	P["vehicle_key_state"] = "committed"
	P["key_generation"] = 2
	equipment_assert(vehicle_key_service.store.commit_profile(id, P), "fixture durable generation transition")
	A.key_generation = 2
	equipment_assert(!K.matches(A) && !copy.matches(A), "generation transition invalidates every old copy")
	A.after_load()
	equipment_assert(A.keyed_vehicle_id == id && A.key_generation == 2, "load preserves vehicle identity and generation without minting")
	qdel(copy)
	qdel(K)
	qdel(A)
	vehicle_key_service = original

/proc/equipment_container_key_codec_probe(datum/extraction_equipment_codec/C)
	for (var/path in extraction_container_key_catalog())
		var/obj/item/weapon/key/extraction_container/K = new path(null)
		K.uses_remaining = 2
		var/list/graph = C.encode(K)
		equipment_assert(graph, "catalogued key serializes finite uses")
		var/obj/item/weapon/key/extraction_container/restored = C.decode(graph, locate(3,7,1))
		equipment_assert(restored && restored.type == K.type && restored.uses_remaining == 2 && restored.extraction_item_id == K.extraction_item_id, "key codec preserves actual identity target subtype and remaining uses")
		for (var/invalid in list(0, -1, 1.5, 4))
			graph["nodes"][1]["scalars"]["uses_remaining"] = invalid
			equipment_assert(!C.validate(graph), "key codec rejects exhausted fractional and oversized use payloads")
		graph["nodes"][1]["scalars"]["uses_remaining"] = 2
		graph["nodes"][1]["scalars"]["target_map"] = "forged"
		equipment_assert(!C.validate(graph), "key codec rejects target injection")
		qdel(K)
		qdel(restored)
	equipment_assert(!C.supported(/obj/item/weapon/key/extraction_container) && !C.supported(/obj/item/weapon/key/extraction_container/uncatalogued_probe), "key codec excludes base and uncatalogued types")
