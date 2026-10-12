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
#ifdef EXTRACTION_MODE_PROBE
		extraction_mode_probe()
#endif
		equipment_completed = TRUE
	catch (var/exception/E)
		equipment_failures++
		world.log << "FAIL: [E] at [E.file]:[E.line]"
	text2file(equipment_completed && !equipment_failures ? "PASS: production equipment disk roundtrip, nested optics, ammo, condition and schema rejection" : "FAIL: equipment verification", "result.txt")
	shutdown()
