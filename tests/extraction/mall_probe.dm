// Offline production interactions; startup/client identity/waits only are injected.
var/global/mall_fixture_failed = FALSE

/proc/mall_stage(message)
	text2file(message, "stages.txt")

/obj/map_metadata/extraction_survival/New()
	map = src
	icon = null

/obj/map_metadata/extraction_survival/mall
	var/list/fixture_owners = list()
	identity(mob/living/human/H)
		return fixture_owners[H]
	wait_for_extraction(mob/living/human/H, obj/effect/extraction_exit/E)
		return TRUE

/world
	hub = ""
	hub_password = ""
	OpenPort(port)
		if (port == "none") return ..()
		return FALSE
	Export()
		return null
	Error(exception/E)
		mall_fixture_failed = TRUE
		text2file("FAIL: runtime [E] at [E.file]:[E.line]", "result.txt")
		world.log << "Runtime error: [E] at [E.file]:[E.line]"
	New()
		mall_stage("world New entered")
		mall_assert(!world.port, "daemon starts without a listening port")
		world.OpenPort("none")
		spawn(2)
			try
				mall_probe()
				if (!mall_fixture_failed)
					text2file("PASS: native mall floors, stairs, loot, highway policy and extraction", "result.txt")
			catch (var/exception/E)
				mall_fixture_failed = TRUE
				text2file("FAIL: [E] at [E.file]:[E.line]", "result.txt")
				world.log << "FAIL: [E]"
			del(world)

/proc/mall_assert(condition, message)
	if (!condition) throw EXCEPTION(message)

// Shared key assertions use the equipment fixture's assertion interface.
/proc/equipment_assert(condition, message)
	mall_assert(condition, message)

/datum/extraction_loot_pool/mall_fixture
	plan()
		return list(list("type" = "/obj/item/extraction_salvage", "quantity" = 1))


// Bounded native contracts for fixed scenery. These run only when the mall
// fixture is explicitly launched; source additions are not runtime evidence.
/proc/mall_fixture_dressing_probe(mob/living/human/H)
	var/turf/T = get_turf(H)
	// Keep tools off the cabinet turf: native closet initialization collects
	// pre-existing floor items, which would invalidate the empty-stock check.
	var/obj/item/weapon/hammer/hammer = new(H)
	var/obj/item/weapon/wrench/wrench = new(H)
	var/obj/item/weapon/wirecutters/cutters = new(H)
	var/list/types = list(
		/obj/structure/table/extraction_mall,
		/obj/structure/table/extraction_mall/shelf,
		/obj/structure/table/extraction_mall/coatrack,
		/obj/structure/table/extraction_mall/nightstand,
		/obj/structure/bed/wood/extraction_mall,
		/obj/structure/bed/fieldbed/extraction_mall,
		/obj/structure/bed/sofa/extraction_mall,
		/obj/structure/bed/chair/extraction_mall,
		/obj/structure/closet/extraction_mall,
		/obj/structure/closet/fridge/extraction_mall,
		/obj/structure/oven/extraction_mall,
		/obj/structure/sink/extraction_mall,
		/obj/structure/toilet/extraction_mall,
		/obj/structure/extraction_mall_fixture/register,
		/obj/covers/generic_wall/extraction_mall)
	var/items_before = 0
	for (var/obj/item/I in world) items_before++
	for (var/path in types)
		var/obj/O = new path(T)
		mall_assert(O.icon && (O.icon_state || O.overlays.len), "fixed dressing retains a native visible appearance")
		mall_assert(O.anchored, "fixed dressing starts anchored")
		O.attackby(hammer, H)
		O.attackby(wrench, H)
		O.attackby(cutters, H)
		if (istype(O, /obj/structure/table))
			var/obj/structure/table/table = O
			table.health = 0
			table.break_to_parts(TRUE)
			table.table_destroy(1, H)
			table.table_destroy(2, H)
			table.table_destroy(3, H)
			mall_assert(!table.deconstructable && table.density, "fixed display tables remain dense and reject direct yield callbacks")
		if (istype(O, /obj/structure/bed))
			var/obj/structure/bed/bed = O
			var/material/old_material = bed.material
			bed.padding_material = old_material
			bed.remove_padding()
			bed.dismantle()
			bed.add_padding("steel")
			mall_assert(bed.padding_material == old_material && bed.material == old_material, "fixed beds reject direct padding and dismantling callbacks")
		if (istype(O, /obj/structure/oven))
			var/obj/structure/oven/oven = O
			oven.fuel = 10
			oven.attack_hand(H)
			oven.fire_loop()
			oven.process()
			mall_assert(!oven.on && oven.fuel == 10 && !oven.contents.len, "disused ovens cannot accept fuel or manufacture food")
		if (istype(O, /obj/structure/closet))
			mall_assert(!O.contents.len && O.density, "fixed empty cabinets provide no stock")
		if (istype(O, /obj/covers))
			var/obj/covers/cover = O
			cover.health = 0
			cover.try_destroy()
			cover.ex_act(1)
			mall_assert(!cover.amount && cover.density, "fixed walls reject direct destruction callbacks")
		if (path == /obj/structure/sink/extraction_mall)
			mall_assert(!("volume" in O.vars) && !("mosquito_count" in O.vars), "disused sink has no renewable water or mosquito lifecycle")
		mall_assert(O.loc == T && O.anchored, "tool and direct callback probes cannot remove or unfasten mapped fixtures")
		qdel(O)
	var/items_after = 0
	for (var/obj/item/I in world) items_after++
	mall_assert(items_after == items_before, "all fixed fixture constructors and tool/damage callbacks generate no items")
	qdel(hammer)
	qdel(wrench)
	qdel(cutters)
	mall_stage("after fixed dressing contracts")

/proc/mall_probe()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.moved_event = new /decl/observ/moved
	GLOB.destroyed_event = new /decl/observ/destroyed
	mall_stage("before datum reference lists")
	makeDatumRefLists()
	mall_stage("after datum reference lists")
	var/obj/map_metadata/extraction_survival/mall/M = map
	mall_assert(istype(M) && world.maxx == 256 && world.maxy == 256 && world.maxz == 5, "mall dimensions and metadata")
	mall_assert(M.mission_z(1) && M.mission_z(4) && M.mission_z(5) && !M.mission_z(2) && !M.mission_z(3) && !M.mission_z(6), "secure floors excluded by mission policy")
	M.accounts.store.root = "data/mall_accounts/"
	mall_stage("before human constructor")
	var/mob/living/human/H = new(locate(4,4,1))
	mall_stage("after human constructor")
	mall_fixture_dressing_probe(H)
	H.m_intent = "stealth"
	M.fixture_owners[H] = "mallvisitor"
	mall_assert(M.admit(H) && H.z == 2, "native account admitted to private home")
	mall_stage("after home admission")
	var/datum/extraction_session/S = H.extraction_session
	mall_assert(M.deploy(H) && H.z == 1 && S.profile["state"] == "raid", "native foot infil")
	mall_stage("after raid deployment")
	var/obj/structure/extraction_mall_stairs/parking
	for (var/obj/structure/extraction_mall_stairs/stairs in world)
		if (stairs.z == 1)
			parking = stairs
			break
	mall_assert(parking, "parking core exists")
	H.forceMove(get_turf(parking))
	mall_assert(parking.traverse(H) && H.z == 4, "parking to retail production traverse")
	var/obj/structure/extraction_mall_stairs/retail
	for (var/obj/structure/extraction_mall_stairs/stairs in range(3, H))
		if (stairs.destination_z == 5) retail = stairs
	mall_assert(retail && retail.traverse(H) && H.z == 5, "retail to gallery production traverse")
	var/obj/structure/extraction_mall_stairs/gallery = locate() in get_turf(H)
	mall_assert(gallery && gallery.traverse(H) && H.z == 4, "gallery return connection")
	mall_stage("after floor traversal")
	var/old_destination = retail.destination_z
	retail.destination_z = 2
	mall_assert(!retail.traverse(H), "stairs never enter private home")
	retail.destination_z = old_destination
	S.transitioning = TRUE
	mall_assert(!retail.traverse(H), "transitioning actor cannot traverse")
	S.transitioning = FALSE
	H.stat = DEAD
	mall_assert(!retail.traverse(H), "dead actor cannot traverse")
	H.stat = CONSCIOUS
	H.forceMove(locate(5,5,4))
	mall_assert(!retail.traverse(H), "remote actor cannot traverse")
	var/obj/effect/extraction_loot_marker/container
	for (var/obj/effect/extraction_loot_marker/L in extraction_loot_markers)
		mall_assert(L.container_id >= 1 && L.container_id <= 64 && M.mission_z(L.z), "bounded containers occupy raid floors")
		if (L.z == 5) container = L
	H.forceMove(get_turf(container))
	container.test_pool = new /datum/extraction_loot_pool/mall_fixture
	mall_assert(container && container.prepare(M), "gallery container production journal prepared")
	mall_stage("after loot prepare")
	var/list/entry = container.profile["stash"][1]
	var/obj/item/claimed = container.claim(M, H, entry["id"])
	mall_assert(claimed && M.raid_items[claimed] && !container.claim(M, H, entry["id"]), "gallery loot claimed once and tracked")
	mall_stage("after loot claim")
	container_key_catalog_probe()
	var/obj/effect/extraction_loot_marker/keyed/mall_security/cache = locate() in world
	H.forceMove(get_turf(cache))
	var/obj/item/weapon/key/extraction_container/mall_security/key = M.spawn_loot(get_turf(H), /obj/item/weapon/key/extraction_container/mall_security)
	key.forceMove(H)
	mall_assert(!cache.prepare(M) && cache.unlock(M, H, key) && key.uses_remaining == 2, "actual mall cache unlock consumes one use")
	var/key_id = key.extraction_item_id
	cache.test_fail_constructor_after = 0
	mall_assert(!cache.prepare(M) && cache.profile["loot_state"] == "planned" && !cache.profile["stash"]:len, "keyed factory construction failure exposes no reward")
	var/saved_plan = json_encode(cache.profile["loot_plan"])
	cache.profile = null
	cache.test_fail_constructor_after = null
	mall_assert(cache.unlock(M, H, key) && key.uses_remaining == 2 && cache.prepare(M) && json_encode(cache.profile["loot_plan"]) == saved_plan, "construction retry retains paid unlock and exact rewards")
	mall_assert(cache.icon_state == "securecrateopen", "durably unlocked reload restores open sprite")
	var/obj/item/weapon/storage/backpack/bag = new(H)
	var/obj/item/weapon/key/extraction_container/city_evidence/foreign = M.spawn_loot(get_turf(H), /obj/item/weapon/key/extraction_container/city_evidence)
	foreign.forceMove(bag)
	mall_assert(M.track_loot(bag) && M.codec.encode(bag), "foreign key nested bag has durable identities")
	var/foreign_id = foreign.extraction_item_id
	mall_stage("after keyed cache unlock and construction retry")
	for (var/obj/effect/extraction_raid_marker/infil in extraction_raid_markers)
		mall_assert(M.vehicle_entry_allowed(infil) == istype(infil, /obj/effect/extraction_raid_marker/road), "only road markers admit cars")
	var/obj/effect/extraction_exit/highway/highway
	for (var/obj/effect/extraction_exit/E in world)
		mall_assert(M.vehicle_exit_allowed(E) == istype(E, /obj/effect/extraction_exit/highway), "only highway exits admit cars")
		H.forceMove(get_turf(E))
		if (!istype(E, /obj/effect/extraction_exit/highway))
			mall_assert(!M.extract_vehicle(H, E) && !M.vehicle_rider_eligible(H, E), "solo and party vehicle return reject pedestrian exits")
		if (istype(E, /obj/effect/extraction_exit/highway)) highway = E
	H.forceMove(get_turf(highway))
	mall_assert(highway && M.extract_player(H, highway) && H.z == 2 && S.profile["state"] == "home", "native mall foot extraction settles home")
	var/datum/extraction_account_store/disk = new
	disk.root = M.accounts.store.root
	var/list/saved = disk.load_profile(S.owner)
	mall_assert(saved && saved["state"] == "home", "successful key extraction is committed on disk")
	var/found_key = FALSE
	var/found_foreign = FALSE
	for (var/list/saved_entry in saved["stash"])
		var/list/graph = saved_entry["equipment"]
		for (var/list/node in graph["nodes"])
			if (node["id"] == key_id)
				mall_assert(node["scalars"]["uses_remaining"] == 2, "successful extraction preserves remaining key uses")
				found_key = TRUE
			if (node["id"] == foreign_id)
				mall_assert(node["scalars"]["uses_remaining"] == 3 && node["parent"] != 0, "foreign key stays nested with unused charges")
				found_foreign = TRUE
		var/obj/item/restored = M.codec.decode(graph, null)
		mall_assert(restored, "extracted graph restores from disk")
		qdel(restored)
	mall_assert(found_key && found_foreign, "both recovered keys survive extraction settlement")
	mall_assert(M.deploy(H) && key.uses_remaining == 2 && foreign.uses_remaining == 3 && foreign.loc == bag, "later raid retains key charges and nested foreign key")
	H.forceMove(get_turf(highway))
	mall_assert(M.extract_player(H, highway) && key.uses_remaining == 2, "repeat extraction does not recharge key")
	container_key_sprite_codec_probe()
	mall_stage("after final foot extraction")
	mall_assert(!parking.traverse(H) && world.port == 0, "home actor cannot enter stairs and daemon port closed")
