// Accelerated injected clock, actual account commits and physical actors.
/obj/map_metadata/extraction_survival/modern_city
	var/test_city_time
	evacuation_time()
		return isnull(test_city_time) ? ..() : test_city_time

/proc/extraction_city_probe()
	makeDatumRefLists()
	var/obj/map_metadata/extraction_survival/modern_city/M = map
	equipment_assert(istype(M) && M.ID == MAP_EXTRACTION_CITY && M.nomads && M.ordinal_age == 8 && M.round_duration == 6 HOURS + 10 SECONDS, "separate Modern Nomads city has a bounded six-hour run")
	M.accounts.store.root = "data/city_accounts/"
	var/obj/effect/extraction_exit/scheduled/north
	var/obj/effect/extraction_exit/scheduled/south
	for (var/obj/effect/extraction_exit/scheduled/E in extraction_city_stations)
		if (E.station_id == "north") north = E
		else if (E.station_id == "south") south = E
	equipment_assert(north && south && extraction_city_stations.len == 2 && extraction_loot_markers.len == 18, "original city has two scheduled stations and eighteen finite containers")
	var/mob/living/human/A = new(locate(3,3,1))
	var/mob/living/human/B = new(locate(3,3,1))
	A.m_intent = "stealth"
	B.m_intent = "stealth"
	var/datum/job/civilian/extraction_survival/modern_city/city_job = new
	city_job.equip(A)
	equipment_assert(city_job.is_nomad && (/mob/living/human/proc/create_faction in A.verbs) && (/mob/living/human/proc/become_leader in A.verbs), "city job exposes production Nomads faction and research leadership controls")
	M.test_owners[A] = "citypresent"
	M.test_owners[B] = "cityabsent"
	equipment_assert(M.admit(A) && M.admit(B), "two real city accounts admitted")
	var/datum/extraction_session/SA = A.extraction_session
	var/datum/extraction_session/SB = B.extraction_session
	for (var/i in 1 to 3) new /obj/item/extraction_salvage(get_turf(SA.house))
	for (var/i in 1 to 3) equipment_assert(M.exchange_salvage(A), "city uses actual salvage and shared durable game currency")
	equipment_assert(M.buy_supplies(A, "Wooden handle") && M.game_credits(SA) == 20, "city purchases production crafting input from earned game balance")
	for (var/obj/item/I in M.home_roots(SA)) I.forceMove(A)
	for (var/obj/item/I in M.home_roots(SB)) I.forceMove(B)
	equipment_assert(M.deploy(A) && M.deploy(B) && !SA.profile["stash"].len && !SB.profile["stash"].len, "two real accounts debit carried loadouts into city")
	A.forceMove(get_turf(north))
	B.forceMove(get_turf(north))
	equipment_assert(M.reserve_evacuation(A, north) && M.reserve_evacuation(B, north) && !north.eligible(A) && !M.extract_player(A, north), "reservation cannot grant early instant extraction")
	B.forceMove(locate(48,10,1))
	var/obj/effect/extraction_drop_box/box = locate(/obj/effect/extraction_drop_box) in get_turf(B)
	var/obj/item/extraction_salvage/shipment = new(B)
	shipment.extraction_found_in_raid = TRUE
	equipment_assert(M.deposit_item(B, shipment, box), "city commits physical shipment before departure")
	var/shipment_id = SB.profile["stash"][1]["id"]
	M.test_city_time = M.departure_due() - 1
	M.evacuation_tick()
	equipment_assert(SA.profile["state"] == "raid" && SB.profile["state"] == "raid" && M.departure_index == 1, "pre-departure warning does not extract anyone")
	M.test_city_time++
	M.evacuation_tick()
	equipment_assert(SA.profile["state"] == "home" && A.z == 2 && SA.profile["stash"].len == 5 && SB.profile["state"] == "raid" && B.z == 1 && M.departure_index == 2, "departure commits only conscious physically present reserved actor")
	equipment_assert(!M.reserve_evacuation(B, north), "next departure rejects the wrong station")
	B.forceMove(get_turf(south))
	equipment_assert(M.reserve_evacuation(B, south), "absent survivor can reserve next announced station")
	M.test_city_time = M.departure_due() + 10 SECONDS
	M.evacuation_tick()
	equipment_assert(SB.profile["state"] == "raid" && M.departure_index == 3 && !M.evacuation_queue.len, "scheduler stall does not grant retroactive late extraction")
	while (M.departure_index <= 6)
		M.test_city_time = M.departure_due()
		M.evacuation_tick()
	equipment_assert(!M.reserve_evacuation(B, south) && M.close_round(), "final departure ends boarding and closes through existing settlement")
	equipment_assert(M.game_over && B.stat == DEAD && !A.extraction_session && !B.extraction_session, "stranding kills remaining raid actor and releases every account")
	var/list/present = M.accounts.store.load_profile("citypresent")
	var/list/absent = M.accounts.store.load_profile("cityabsent")
	equipment_assert(present["state"] == "home" && present["stash"].len == 5 && present["credits"] == 20 && absent["state"] == "home" && absent["stash"].len == 1 && absent["stash"][1]["id"] == shipment_id, "native stranding preserves earned game balance and committed shipment and forfeits unsent loadout")
	qdel(A)
	qdel(B)
