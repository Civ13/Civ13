// Offline production interactions; startup/client identity/waits only are injected.
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
		text2file("FAIL: runtime [E] at [E.file]:[E.line]", "result.txt")
		world.log << "Runtime error: [E] at [E.file]:[E.line]"
	New()
		world.OpenPort("none")
		spawn(2)
			try
				mall_probe()
				text2file("PASS: native mall floors, stairs, loot, highway policy and extraction", "result.txt")
			catch (var/exception/E)
				text2file("FAIL: [E]", "result.txt")
				world.log << "FAIL: [E]"
			del(world)

/proc/mall_assert(condition, message)
	if (!condition) throw EXCEPTION(message)

/datum/extraction_loot_pool/mall_fixture
	plan()
		return list(list("type" = "/obj/item/extraction_salvage", "quantity" = 1))

/proc/mall_probe()
	makeDatumRefLists()
	var/obj/map_metadata/extraction_survival/mall/M = map
	mall_assert(istype(M) && world.maxx == 256 && world.maxy == 256 && world.maxz == 5, "mall dimensions and metadata")
	mall_assert(M.mission_z(1) && M.mission_z(4) && M.mission_z(5) && !M.mission_z(2) && !M.mission_z(3) && !M.mission_z(6), "secure floors excluded by mission policy")
	M.accounts.store.root = "data/mall_accounts/"
	var/mob/living/human/H = new(locate(4,4,1))
	H.m_intent = "stealth"
	M.fixture_owners[H] = "mallvisitor"
	mall_assert(M.admit(H) && H.z == 2, "native account admitted to private home")
	var/datum/extraction_session/S = H.extraction_session
	mall_assert(M.deploy(H) && H.z == 1 && S.profile["state"] == "raid", "native foot infil")
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
	var/list/entry = container.profile["stash"][1]
	var/obj/item/claimed = container.claim(M, H, entry["id"])
	mall_assert(claimed && M.raid_items[claimed] && !container.claim(M, H, entry["id"]), "gallery loot claimed once and tracked")
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
	mall_assert(!parking.traverse(H) && world.port == 0, "home actor cannot enter stairs and daemon port closed")
