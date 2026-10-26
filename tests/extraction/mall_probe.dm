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
	// Deterministic client choices only; production account/physical debits remain.
	choose_upgrade_parts(datum/extraction_session/S)
		var/list/ids = list()
		for (var/list/entry in S.profile["stash"])
			if (entry["salvage"] && ids.len < S.profile["level"] * 5) ids += entry["id"]
		return ids
	confirm_house_upgrade(datum/extraction_session/S, list/ids)
		return TRUE
	confirm_car_purchase(mob/living/human/H)
		return TRUE

/world
	hub = ""
	hub_password = ""
	visibility = 0
	OpenPort(port)
		if (port == "none") return ..()
		return FALSE
	Export()
		return null
	Topic()
		return null
	Error(exception/E)
		mall_fixture_failed = TRUE
		text2file("FAIL: runtime [E] at [E.file]:[E.line]", "result.txt")
		world.log << "Runtime error: [E] at [E.file]:[E.line]"
	New()
		world.OpenPort("none")
		mall_stage("world New entered")
		spawn(2)
			try
				mall_assert(!world.port && !world.visibility, "daemon closes listening port and hides fixture")
				mall_assert(!world.OpenPort(0) && !world.port, "daemon rejects reopening listening port")
				mall_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned native runtime")
				mall_stage("network closed and reopen refused")
				mall_probe()
				if (!mall_fixture_failed)
					text2file("PASS: native mall floors, stairs, loot, highway policy and extraction", "result.txt")
			catch (var/exception/E)
				mall_fixture_failed = TRUE
				text2file("FAIL: [E] at [E.file]:[E.line]", "result.txt")
				world.log << "FAIL: [E] at [E.file]:[E.line]"
			del(world)
			return

/client/New()
	del(src)
	return null

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

// Test-only living occupancy has no AI or constructor side effects.
/mob/living/mall_fixture_occupant
	New()
		return

/obj/effect/mall_fixture_blocker
	density = TRUE
	anchored = TRUE

/proc/mall_all_stairs_probe(mob/living/human/H)
	var/turf/starting = get_turf(H)
	var/list/cores = list()
	var/list/by_floor = list("1" = 0, "4" = 0, "5" = 0)
	var/list/directed = list()
	var/list/parking_positions = list()
	for (var/obj/structure/extraction_mall_stairs/stairs in world)
		var/edge = "[stairs.x],[stairs.y],[stairs.z],[stairs.destination_z]"
		mall_assert(!directed[edge], "each mapped directed stair has a unique position and destination")
		directed[edge] = TRUE
		cores += stairs
		by_floor["[stairs.z]"]++
		if (stairs.z == 1)
			var/position = "[stairs.x],[stairs.y]"
			mall_assert(!parking_positions[position], "each parking stair identifies a distinct core")
			parking_positions[position] = stairs
	mall_assert(cores.len == 24 && by_floor["1"] == 6 && by_floor["4"] == 12 && by_floor["5"] == 6, "all six cores expose all four directed stair connections")
	mall_assert(parking_positions.len == 6, "six distinct parking positions define the six mapped cores")
	for (var/position in parking_positions)
		var/obj/structure/extraction_mall_stairs/parking = parking_positions[position]
		var/x = parking.x
		var/y = parking.y
		mall_assert(directed["[x],[y],1,4"] && directed["[x],[y],4,1"] && directed["[x + 2],[y],4,5"] && directed["[x + 2],[y],5,4"], "each distinct core has its exact four directed parking retail and gallery edges")
	for (var/obj/structure/extraction_mall_stairs/stairs in cores)
		var/turf/source = get_turf(stairs)
		var/turf/landing = locate(stairs.x, stairs.y, stairs.destination_z)
		mall_assert(landing, "every stair has an actual landing")
		var/obj/structure/extraction_mall_stairs/reciprocal = locate() in landing
		mall_assert(reciprocal && reciprocal.destination_z == stairs.z, "every stair has its mapped reciprocal connection")
		H.forceMove(source)
		mall_assert(stairs.traverse(H) && get_turf(H) == landing, "every directed stair traverses to its exact landing")
		mall_assert(reciprocal.traverse(H) && get_turf(H) == source, "every directed stair returns to its exact source")
		var/old_density = landing.density
		landing.density = TRUE
		mall_assert(!stairs.traverse(H) && get_turf(H) == source, "all cores reject dense destination turf without moving the actor")
		landing.density = old_density
		var/obj/effect/mall_fixture_blocker/blocker = new(landing)
		mall_assert(!stairs.traverse(H) && get_turf(H) == source, "all cores reject dense destination occupancy without moving the actor")
		blocker.forceMove(null)
		qdel(blocker)
		var/mob/living/mall_fixture_occupant/occupant = new(landing)
		occupant.density = FALSE
		mall_assert(!stairs.traverse(H) && get_turf(H) == source, "all cores reject a non-dense living occupant without moving the actor")
		occupant.forceMove(null)
		qdel(occupant)
		reciprocal.forceMove(null)
		mall_assert(!stairs.traverse(H) && get_turf(H) == source, "all cores reject a missing return stair without moving the actor")
		reciprocal.forceMove(landing)
		var/old_return = reciprocal.destination_z
		reciprocal.destination_z = 3
		mall_assert(!stairs.traverse(H) && get_turf(H) == source, "all cores reject a mismatched return stair without moving the actor")
		reciprocal.destination_z = old_return
		mall_assert(stairs.traverse(H) && reciprocal.traverse(H) && get_turf(H) == source, "restored landings permit the same round trip")
	H.forceMove(starting)
	mall_stage("after all-core round trips and landing denials")

// Compare the actor/source's actual item graphs and the exact raid registry.
// This avoids unrelated world-item counts while detecting a refused call that
// silently creates, removes, replaces or relocates an item and returns null.
/proc/mall_loot_identity_snapshot(obj/map_metadata/extraction_survival/mall/M, mob/living/human/H, turf/source)
	var/list/pending = list()
	for (var/obj/item/I in H.contents) pending += I
	for (var/obj/item/I in source.contents) pending += I
	var/list/physical = list()
	var/index = 1
	while (index <= pending.len)
		var/obj/item/I = pending[index++]
		var/identity = "\ref[I]"
		if (physical[identity]) continue
		physical[identity] = list("id" = I.extraction_item_id, "location" = "\ref[I.loc]")
		for (var/obj/item/child in I.contents) pending += child
	var/list/tracked = list()
	for (var/obj/item/I in M.raid_items)
		tracked["\ref[I]"] = list("id" = I.extraction_item_id, "location" = "\ref[I.loc]", "expiry" = M.raid_items[I])
	return json_encode(list("physical" = physical, "tracked" = tracked, "registry_count" = M.raid_items.len))

/proc/mall_claim_accessible(mob/living/human/H, obj/item/I, turf/source)
	return I && ((I.loc == H && (H.l_hand == I || H.r_hand == I)) || (source && I.loc == source))

/proc/mall_all_floor_loot_probe(obj/map_metadata/extraction_survival/mall/M, mob/living/human/H)
	var/list/counts = list("1" = 0, "4" = 0, "5" = 0)
	var/list/ordinary = list()
	for (var/obj/effect/extraction_loot_marker/L in extraction_loot_markers)
		mall_assert(L.container_id >= 1 && L.container_id <= 64 && M.mission_z(L.z), "bounded containers occupy raid floors")
		counts["[L.z]"]++
		if (!L.keyed() && !ordinary["[L.z]"]) ordinary["[L.z]"] = L
	mall_assert(counts["1"] == 6 && counts["4"] == 18 && counts["5"] == 40, "actual loaded containers populate all three raid floors")
	var/list/claimed_ids = list()
	for (var/level in list(1, 4, 5))
		var/obj/effect/extraction_loot_marker/container = ordinary["[level]"]
		mall_assert(container, "each raid floor has an ordinary source")
		H.forceMove(get_turf(container))
		container.test_pool = new /datum/extraction_loot_pool/mall_fixture
		mall_assert(container.prepare(M) && container.profile["stash"]:len == 1, "each floor prepares one injected outcome through the production journal")
		var/saved_plan = json_encode(container.profile["loot_plan"])
		var/list/entry = container.profile["stash"][1]
		var/entry_id = entry["id"]
		var/turf/source = get_turf(container)
		var/obj/item/claimed = container.claim(M, H, entry_id)
		mall_assert(mall_claim_accessible(H, claimed, source) && claimed.extraction_item_id == entry_id && M.raid_items[claimed], "each floor issues the original planned identity through actual hands or its accessible source floor")
		mall_assert(!(entry_id in claimed_ids), "different floor sources issue distinct identities")
		claimed_ids += entry_id
		var/before_repeat = mall_loot_identity_snapshot(M, H, source)
		mall_assert(!container.claim(M, H, entry_id) && !container.profile["stash"]:len && mall_claim_accessible(H, claimed, source) && claimed.extraction_item_id == entry_id && mall_loot_identity_snapshot(M, H, source) == before_repeat, "ordinary container claim is unique before reopening")
		container.profile = null
		mall_assert(container.prepare(M) && json_encode(container.profile["loot_plan"]) == saved_plan && !container.profile["stash"]:len && mall_loot_identity_snapshot(M, H, source) == before_repeat, "ordinary source reload preserves its exact consumed plan")
		var/before_reopened_repeat = mall_loot_identity_snapshot(M, H, source)
		mall_assert(!container.claim(M, H, entry_id) && mall_claim_accessible(H, claimed, source) && claimed.extraction_item_id == entry_id && mall_loot_identity_snapshot(M, H, source) == before_reopened_repeat, "ordinary source reload cannot repeat delivery or replace the actual item")
	mall_stage("after ordinary source claim and reopen on all floors")

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
	mall_assert(retail && retail.x == parking.x + 2 && retail.y == parking.y && retail.z == 4 && get_dist(H, retail) == 2, "mapped retail stair is two tiles from parking landing")
	// Only the approach is injected; traversal must still pass production adjacency.
	H.forceMove(get_turf(retail))
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
	mall_all_stairs_probe(H)
	mall_all_floor_loot_probe(M, H)
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
	// All seven existing omission controls reach their assertions before this case.
	mall_vehicle_route_probe(M)

// Actual default-map driving, not a relocated flat-fixture car or client-input claim.
/proc/mall_car_budget(deadline)
	mall_assert(world.realtime < deadline, "actual mall car case stays within shared 45 second deadline")

// Model selecting the key for each click, then restore the prior active hand.
// In the driver's seat this preserves the real wheel as the active input item.
/proc/mall_car_use_key(mob/living/human/H, obj/structure/vehicleparts/frame/door, obj/item/weapon/key/extraction_room/key)
	var/obj/item/prior_active = H.get_active_hand()
	if (prior_active != key) H.swap_hand()
	mall_assert(H.get_active_hand() == key && key.loc == H && H.Adjacent(door), "real door input uses the original held active key beside the car")
	door.attackby(key, H)
	if (prior_active != key) H.swap_hand()
	mall_assert(H.get_active_hand() == prior_active, "real key input restores the prior active hand including the driver's wheel")

// Explicit cardinal input adapter. Every step still executes production Move,
// frame CanPass/CheckExit and turf callbacks; no actor/vehicle forceMove here.
/proc/mall_car_walk(mob/living/human/H, turf/target, deadline, horizontal_first = TRUE)
	mall_assert(target && H.z == target.z && get_dist(H, target) <= 16, "car walking waypoint is bounded on the actual map")
	var/steps = 0
	while (get_turf(H) != target)
		mall_car_budget(deadline)
		mall_assert(++steps <= 32, "car walking input has a bounded number of steps")
		var/direction
		if ((horizontal_first && H.x != target.x) || H.y == target.y)
			direction = H.x < target.x ? EAST : WEST
		else
			direction = H.y < target.y ? NORTH : SOUTH
		var/turf/before = get_turf(H)
		mall_assert(step(H, direction) && get_turf(H) == get_step(before, direction), "car actor walks through real map callbacks without teleporting")
		sleep(0)

// Observe the real asynchronous wheel-started movement loop one tick at a time.
// Turns legitimately move the axis anchor, so each straight leg starts afresh.
/proc/mall_car_drive_leg(mob/living/human/H, obj/structure/vehicleparts/axis/A, direction, coordinate, deadline)
	var/steps = 0
	var/last_move = world.realtime
	var/turf/previous = get_turf(A)
	while ((direction == SOUTH ? A.y : A.x) != coordinate)
		mall_car_budget(deadline)
		mall_assert(A.dir == direction && A.moving && A.currentspeed > 0 && A.engine.on && A.driver == H && H.buckled == A.wheel.drivingchair && A.wheel.loc == H && H.get_active_hand() == A.wheel, "real driver engine active wheel and direction remain linked during mall travel")
		mall_assert((direction == SOUTH ? A.y : A.x) > coordinate, "real movement cannot overshoot the mall route waypoint")
		sleep(1)
		var/turf/current = get_turf(A)
		if (current != previous)
			mall_assert(current == get_step(previous, direction), "actual mall driving advances exactly one production road tile")
			mall_assert(++steps <= 110, "actual mall straight leg has a bounded translation count")
			previous = current
			last_move = world.realtime
		mall_assert(world.realtime - last_move < 20, "actual mall car movement cannot silently stall")
	return steps

/proc/mall_vehicle_route_probe(obj/map_metadata/extraction_survival/mall/M)
	var/started = world.realtime
	var/deadline = started + 450
	mall_stage("before actual mall car purchase and travel")
	// Real turf Enter callbacks need this clock, not its client scheduler loop.
	if (!movementMachine) movementMachine = new
	mall_assert(movementMachine && movementMachine.ticks == 0, "actual mall walking has the production movement clock without scheduler startup")
	var/mob/living/human/H = new(locate(4,4,1))
	H.m_intent = "stealth"
	M.fixture_owners[H] = "mallcarvisitor"
	mall_assert(M.admit(H) && H.z == 2, "car visitor receives a real private account")
	var/datum/extraction_session/S = H.extraction_session
	for (var/i in 1 to 5) new /obj/item/extraction_salvage(get_turf(S.house))
	mall_assert(M.upgrade_house(S) && S.profile["level"] == 2, "car visitor pays production house upgrade before dealer purchase")
	for (var/i in 1 to EXTRACTION_CAR_PRICE) new /obj/item/extraction_salvage(get_turf(S.house))
	mall_assert(M.save_home(S), "car purchase inputs receive durable equipment identities")
	var/list/payment = list()
	for (var/obj/item/extraction_salvage/I in M.home_roots(S)) payment += I
	mall_assert(payment.len == EXTRACTION_CAR_PRICE && M.buy_car(H), "car visitor purchases with exactly the actual required workshop parts")
	for (var/obj/item/I in payment)
		mall_assert(QDELETED(I), "paid car purchase consumes every physical payment part")
	var/obj/structure/vehicleparts/axis/A = S.garage_vehicle
	mall_assert(A && S.profile["garage"].len == 1 && S.profile["garage_purchase"]["status"] == "complete" && !M.buy_car(H), "paid car is acknowledged once and cannot be bought into an occupied bay")
	var/obj/structure/engine/internal/E = A.engine
	var/obj/item/tank = E.fueltank
	mall_assert(tank.reagents.total_volume == 0, "paid dealer car has no constructor fuel")
	// Explicit fixture supply; no claim that buying a car grants gasoline or keys.
	tank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	mall_assert(tank.reagents.total_volume == 100, "car fixture supplies exactly its measured fuel input")
	var/obj/structure/vehicleparts/frame/damaged = A.loc
	damaged.w_front[5] = 0.05
	var/obj/structure/table/carboot/boot
	for (var/obj/structure/table/carboot/B in S.garage_parts) boot = B
	mall_assert(boot, "dealer car provides an actual mapped boot component")
	var/obj/item/weapon/storage/backpack/bag = new(get_turf(boot))
	var/obj/item/extraction_salvage/child = new(bag)
	child.health = 37
	// Unlike cache tokens, this existing supported loot key opens legacy car doors.
	var/obj/item/weapon/key/extraction_room/key = new(get_turf(H))
	mall_assert(H.put_in_active_hand(key) && M.save_home(S), "car fixture owns a supported held door key and nested boot cargo before deployment")
	var/list/initial_record = M.vehicle_codec.encode(A)
	mall_assert(initial_record && M.vehicle_codec.validate(initial_record), "actual paid vehicle graph and cargo encode before deployment")
	var/list/part_refs = M.vehicle_codec.objects.Copy()
	var/list/part_ids = list()
	var/list/wanted_ids = list()
	for (var/obj/O in part_refs)
		mall_assert(O.extraction_vehicle_part_id && !wanted_ids[O.extraction_vehicle_part_id], "initial vehicle part identities are nonempty and distinct")
		part_ids[O] = O.extraction_vehicle_part_id
		wanted_ids[O.extraction_vehicle_part_id] = TRUE
	var/bag_id = bag.extraction_item_id
	var/child_id = child.extraction_item_id
	var/key_id = key.extraction_item_id
	mall_assert(bag_id && child_id && key_id && bag_id != child_id && bag_id != key_id && child_id != key_id && !wanted_ids[bag_id] && !wanted_ids[child_id] && !wanted_ids[key_id], "car fixture cargo and held key have distinct durable identities disjoint from vehicle parts")
	wanted_ids[bag_id] = TRUE
	wanted_ids[child_id] = TRUE
	wanted_ids[key_id] = TRUE
	var/obj/effect/extraction_raid_marker/road/entry
	for (var/obj/effect/extraction_raid_marker/road/R in extraction_raid_markers)
		if (!entry || R.y < entry.y) entry = R
	var/obj/effect/extraction_exit/highway/highway
	for (var/obj/effect/extraction_exit/highway/X in world)
		if (!highway || X.x < highway.x) highway = X
	mall_assert(entry && entry.x == 89 && entry.y == 19 && entry.z == 1 && highway && highway.x == 15 && highway.y == 12 && highway.z == 1, "car route uses actual default mall south entry and west highway")
	var/list/original_markers = extraction_raid_markers
	var/deployed = FALSE
	extraction_raid_markers = list(entry)
	try
		deployed = M.deploy_vehicle(H)
	catch (var/exception/failure)
		extraction_raid_markers = original_markers
		throw failure
	extraction_raid_markers = original_markers
	mall_assert(deployed && S.raid_vehicle == A && !S.garage_vehicle && S.profile["state"] == "raid" && !S.profile["garage"].len && M.raid_vehicles[A], "production deployment debits the garage and moves the same actual owned car")
	mall_assert(get_dist(A, entry) <= 4 && A.z == 1 && A.dir == SOUTH && A.maxdist == 3 && A.components.len == 9, "actual car arrives beside the real south road marker with its native turning footprint")
	mall_assert(M.raid_items[bag] && M.raid_items[child] && M.raid_items[key], "deployed nested cargo and carried key enter actual raid custody")
	var/obj/structure/bed/chair/drivers/car/seat = A.wheel.drivingchair
	var/obj/structure/vehicleparts/frame/door = A.wheel.control
	mall_assert(seat && door && door.axis == A && seat.axis == A, "paid car retains production driver and door links")
	// Walk around the current SOUTH-facing three-square footprint to its east.
	if (H.x <= A.x && H.y >= A.y && H.y <= A.y + 2)
		mall_car_walk(H, locate(H.x, A.y - 1, 1), deadline, FALSE)
	mall_car_walk(H, locate(A.x + 1, H.y, 1), deadline)
	mall_car_walk(H, locate(seat.x + 1, seat.y, 1), deadline, FALSE)
	mall_assert(H.Adjacent(door), "driver reaches the actual closed car door on foot")
	if (!door.doorcode) mall_car_use_key(H, door, key)
	if (!door.w_left[7]) mall_car_use_key(H, door, key)
	mall_assert(door.doorcode == key.code && door.w_left[7], "existing supported key opens the real driver door through production attackby")
	mall_car_walk(H, get_turf(seat), deadline)
	H.swap_hand()
	mall_assert(!H.get_active_hand() && H.get_inactive_hand() == key, "driver keeps the original key and frees the active hand for the wheel")
	seat.user_buckle_mob(H, H)
	mall_assert(H.buckled == seat && A.driver == H && H.get_active_hand() == A.wheel, "production buckling supplies the real steering wheel")
	mall_car_use_key(H, door, key)
	mall_assert(!door.w_left[7], "real driver closes the keyed door before travel")
	A.wheel.attack_self(H)
	mall_assert(E.on && !A.moving, "production steering input starts the actual engine")
	A.wheel.attack_self(H)
	var/south_steps = mall_car_drive_leg(H, A, SOUTH, highway.y + 1, deadline)
	mall_assert(A.wheel.turndir(H, "right") && A.dir == WEST, "real steering turns from south into the mall highway ring")
	for (var/i in 1 to 3) A.wheel.attack_self(H)
	mall_assert(A.currentspeed == 4, "production steering input selects bounded native top gear")
	var/west_steps = mall_car_drive_leg(H, A, WEST, highway.x + 1, deadline)
	// The private bay is SOUTH-shaped. Preserve its production geometry check.
	mall_assert(A.wheel.turndir(H, "left") && A.dir == SOUTH, "real steering returns the car to its private-bay orientation")
	for (var/i in 1 to 4) A.wheel.secondary_attack_self(H)
	A.wheel.secondary_attack_self(H)
	while (A.movement_processes)
		mall_car_budget(deadline)
		sleep(1)
	mall_assert(!A.moving && !A.currentspeed && !E.on && !A.transforming_vehicle && A.driver == H && M.vehicle_at_exit(A, highway), "actual driven car parks and stops next to the real highway")
	mall_assert(south_steps + west_steps >= 60 && tank.reagents.total_volume > 0 && tank.reagents.total_volume < 100, "actual road travel moves the car and consumes its supplied fuel")
	mall_car_use_key(H, door, key)
	mall_assert(door.w_left[7] && seat.user_unbuckle_mob(H) == H && !H.buckled && !A.driver && A.wheel.loc == seat, "real driver opens the door and leaves the stopped car without duplicating its wheel")
	mall_car_walk(H, get_step(get_turf(seat), EAST), deadline)
	mall_car_use_key(H, door, key)
	mall_assert(!door.w_left[7], "former driver closes the original real door after leaving")
	mall_car_walk(H, locate(H.x, highway.y - 1, 1), deadline, FALSE)
	mall_car_walk(H, locate(highway.x, highway.y - 1, 1), deadline)
	mall_assert(highway.eligible(H), "former driver walks adjacent to the actual highway exit")
	var/final_fuel = tank.reagents.total_volume
	var/list/stopped_record = M.vehicle_codec.encode(A)
	mall_assert(stopped_record && M.garage_record_fits(S, stopped_record), "actual post-drive graph fits the normal unchanged private bay")
	var/sequence = S.profile["raid_sequence"]
	mall_assert(M.extract_vehicle(H, highway, A) && S.profile["state"] == "home" && S.garage_vehicle == A && S.profile["garage"].len == 1 && !M.raid_vehicles[A] && !S.raid_vehicle, "production highway return banks the same actual driven car once")
	mall_assert(A.engine == E && E.fueltank == tank && tank.reagents.total_volume == final_fuel && damaged.w_front[5] == 0.05 && bag.extraction_item_id == bag_id && child.extraction_item_id == child_id && child.loc == bag && child.health == 37 && key.extraction_item_id == key_id && key.code == 81732, "same engine tank fuel wear and nested cargo/key identities survive actual mall return")
	for (var/obj/O in part_refs)
		mall_assert(!QDELETED(O) && O.extraction_vehicle_part_id == part_ids[O], "actual mall return preserves each original vehicle part reference and identity")
	// Production tick prunes nested raid references after they leave mission z.
	// Immediate atomic registry emptiness is not the return transaction contract.
	var/banked_sequence = S.profile["raid_sequence"]
	var/banked_credits = S.profile["credits"]
	var/banked_level = S.profile["level"]
	M.tick()
	mall_assert(!M.raid_items[bag] && !M.raid_items[child] && !M.raid_items[key] && S.profile["state"] == "home" && S.profile["raid_sequence"] == banked_sequence && S.profile["credits"] == banked_credits && S.profile["level"] == banked_level && S.garage_vehicle == A && tank.reagents.total_volume == final_fuel && child.loc == bag, "normal production tick releases returned nested raid references without changing banked gameplay state or custody")
	mall_assert(json_encode(S.profile["garage"][1]) == json_encode(stopped_record) && json_encode(M.vehicle_codec.encode(A)) == json_encode(stopped_record), "garage credit matches the exact measured stopped graph without fuel recharge or cargo replacement")
	var/datum/extraction_account_store/disk = new
	disk.root = M.accounts.store.root
	var/list/saved = disk.load_profile(S.owner)
	var/list/owned_ids = disk.recovery_ids(saved)
	mall_assert(saved && saved["state"] == "home" && saved["garage"].len == 1 && owned_ids && owned_ids[bag_id] && owned_ids[child_id] && owned_ids[key_id] && json_encode(saved["garage"][1]) == json_encode(stopped_record), "reopened account disk owns the exact returned car and cargo graph without duplicate custody")
	var/list/physical_counts = list()
	for (var/obj/O in world)
		var/list/atom_ids = list()
		if (wanted_ids[O.extraction_vehicle_part_id]) atom_ids[O.extraction_vehicle_part_id] = TRUE
		if (istype(O, /obj/item))
			var/obj/item/I = O
			if (wanted_ids[I.extraction_item_id]) atom_ids[I.extraction_item_id] = TRUE
		// An atom carrying both namespaces is counted once per identity, not twice.
		for (var/id in atom_ids) physical_counts[id]++
	for (var/id in wanted_ids)
		mall_assert(physical_counts[id] == 1 && owned_ids[id], "returned mall part cargo and key identities each have one physical atom and one account owner")
	var/revision = S.profile["revision"]
	mall_assert(!S.credit_vehicle_extraction(sequence, list(), stopped_record) && S.profile["revision"] == revision, "actual mall vehicle return cannot credit the raid a second time")
	mall_car_budget(deadline)
	mall_assert(!world.port, "actual mall car case keeps the fixture network closed")
	mall_stage("actual mall car receipt [json_encode(list("car_id" = A.extraction_vehicle_part_id, "bag_id" = bag_id, "child_id" = child_id, "key_id" = key_id, "south_steps" = south_steps, "west_steps" = west_steps, "fuel_before" = 100, "fuel_after" = final_fuel, "elapsed_deciseconds" = world.realtime - started, "garage_revision" = revision))]")
