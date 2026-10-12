// Accelerated injected clock, actual account commits and physical actors.
/proc/extraction_city_recipe(list/recipes, result_path)
	for (var/entry in recipes)
		if (istype(entry, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/group = entry
			var/datum/stack_recipe/nested = extraction_city_recipe(group.recipes, result_path)
			if (nested) return nested
		else if (istype(entry, /datum/stack_recipe))
			var/datum/stack_recipe/recipe = entry
			if (recipe.result_type == result_path) return recipe
	return null

/proc/extraction_city_research_probe(obj/map_metadata/extraction_survival/modern_city/M, obj/structure/research_bench/B)
	craftlist_lists["global"] = list()
	for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
		if (findtext(line, "RECIPE: ") && !findtext(line, "//")) craftlist_lists["global"] += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	build_research_tree()
	var/faction = "city_research_fixture"
	M.faction_baseline_era[faction] = 8
	B.faction = faction
	var/material/planks = new /material/wood/soft
	planks.generate_recipes_civs(list(210,210,210), "global", faction)
	var/datum/stack_recipe/bench_recipe = extraction_city_recipe(planks.recipes, /obj/structure/research_bench)
	equipment_assert(bench_recipe && bench_recipe.req_amount == 8, "paid planks reach the ordinary eight-plank research bench recipe")
	var/material/cloth = new /material/cloth
	cloth.generate_recipes_civs(list(210,210,210), "global", faction)
	equipment_assert(!extraction_city_recipe(cloth.recipes, /obj/item/clothing/under/customuniform), "Modern baseline does not grant specialist uniform recipes")
	// Exercise production study accounting directly, without accelerated passive
	// researcher presence or granting DONE flags in the fixture.
	for (var/node_id in list("classical_dress", "tailoring", "fine_garments", "textile_mills", "ready_made"))
		var/datum/research_node/N = get_research_node(node_id)
		equipment_assert(N && B.can_assign_node(node_id), "laboratory can study prerequisite [node_id]")
		equipment_assert(!M.add_research_ticks(faction, node_id, N.cost_ticks - 1) && !M.is_node_done(faction, node_id), "incomplete [node_id] study preserves its gate")
		equipment_assert(M.add_research_ticks(faction, node_id, 1), "final paid study tick completes [node_id]")
	cloth.generate_recipes_civs(list(210,210,210), "global", faction)
	equipment_assert(extraction_city_recipe(cloth.recipes, /obj/item/clothing/under/customuniform), "earned specialist study unlocks the production Modern uniform recipe")
	var/material/kevlar = new /material/kevlar
	kevlar.generate_recipes_civs(list(210,210,210), "global", faction)
	equipment_assert(!extraction_city_recipe(kevlar.recipes, /obj/item/clothing/accessory/armor/nomads/civiliankevlar), "paid kevlar does not bypass Modern Armor research")
	for (var/node_id in list("mail_plate", "trench_warfare", "modern_armor"))
		var/datum/research_node/N = get_research_node(node_id)
		if (node_id == "modern_armor")
			B.tier = 5
			equipment_assert(!B.can_assign_node(node_id), "Modern Armor rejects a tier-five research station")
			B.tier = 6
		equipment_assert(N && B.can_assign_node(node_id) && M.add_research_ticks(faction, node_id, N.cost_ticks), "earned armor prerequisite [node_id] completes at the proper station")
	kevlar.generate_recipes_civs(list(210,210,210), "global", faction)
	var/datum/stack_recipe/armor_recipe = extraction_city_recipe(kevlar.recipes, /obj/item/clothing/accessory/armor/nomads/civiliankevlar)
	equipment_assert(armor_recipe && armor_recipe.req_amount == 10, "earned Modern Armor unlocks the actual ten-kevlar armor recipe")
	B.faction = null
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
	var/obj/structure/research_bench/laboratory = locate() in locate(42,42,1)
	equipment_assert(laboratory && laboratory.tier == 6 && !laboratory.assigned_node && !laboratory.faction, "public city laboratory supplies station capacity without granting faction research")
	extraction_city_research_probe(M, laboratory)
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
