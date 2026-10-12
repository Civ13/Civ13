/proc/extraction_progression_probe(obj/map_metadata/extraction_survival/M)
	var/mob/living/human/H = new(locate(3,3,1))
	H.m_intent = "stealth"
	M.test_owners[H] = "supplybuyer"
	equipment_assert(M.admit(H), "supply buyer admitted to bound private room")
	var/datum/extraction_session/S = H.extraction_session
	equipment_assert(!M.buy_supplies(H, "Wooden handle") && !M.buy_supplies(H, "UNKNOWN"), "insufficient game balance and unknown server offer rejected")
	for (var/i in 1 to 3) new /obj/item/extraction_salvage(get_turf(S.house))
	for (var/i in 1 to 3) equipment_assert(M.exchange_salvage(H), "actual uninsured workshop part exchanges once through native snapshot")
	equipment_assert(M.game_credits(S) == 30 && M.home_roots(S).len == 4 && !M.exchange_salvage(H), "three original payments retire with no replay or bot balance")
	equipment_assert(!M.buy_supplies(H, "Gasoline jerrycan"), "house level gates advanced supply purchase before payment")
	M.test_supply_confirmation = FALSE
	equipment_assert(!M.buy_supplies(H, "Wooden handle") && M.game_credits(S) == 30 && M.home_roots(S).len == 4, "declined supply confirmation exposes no paid product")
	M.test_supply_confirmation = "move"
	equipment_assert(!M.buy_supplies(H, "Wooden handle") && M.game_credits(S) == 30 && M.home_roots(S).len == 4, "yielded purchase revalidates private physical access")
	H.forceMove(get_turf(S.house))
	M.test_supply_confirmation = TRUE
	equipment_assert(M.buy_supplies(H, "Iron pickaxe head") && M.buy_supplies(H, "Wooden handle"), "earned game credits purchase usable production tool inputs")
	equipment_assert(M.game_credits(S) == 0 && S.profile["stash"].len == 6 && !M.buy_supplies(H, "Wooden handle"), "payment and product share one snapshot without refund or reissue")
	var/obj/item/weapon/material/part/pickaxe/head
	var/obj/item/weapon/material/handle/handle
	for (var/obj/item/I in M.home_roots(S))
		if (istype(I, /obj/item/weapon/material/part/pickaxe)) head = I
		if (istype(I, /obj/item/weapon/material/handle)) handle = I
	equipment_assert(head?.material?.name == "iron" && handle?.material?.name == "wood" && !head.extraction_found_in_raid && !handle.extraction_found_in_raid, "paid inputs retain actual materials and no invented raid provenance")
	var/head_id = head.extraction_item_id
	equipment_assert(M.release(S) && M.admit(H), "supply ownership survives native account release and restoration")
	S = H.extraction_session
	var/found = 0
	for (var/obj/item/I in M.home_roots(S))
		if (I.extraction_item_id == head_id) found++
	equipment_assert(found == 1 && M.game_credits(S) == 0, "native reload preserves one purchased identity and spent game balance")
	equipment_assert(M.release(S), "supply fixture releases private account")
	M.round_participants -= "supplybuyer"
	qdel(H)
	// Exercise every fixed offer's actual constructor and full graph, including
	// ammunition descendants, rather than trusting the type catalog's strings.
	var/list/offers = M.supply_catalog()
	for (var/label in offers)
		var/list/offer = offers[label]
		var/path = offer["type"]
		var/obj/item/I = new path(null, offer["material"])
		if (istype(I, /obj/item/stack/material)) I:amount = offer["amount"]
		var/list/graph = M.codec.encode(I)
		equipment_assert(graph && M.codec.validate(graph), "fixed offer [label] has a supported actual equipment graph")
		var/obj/item/restored = M.codec.decode(graph, locate(3,3,1))
		equipment_assert(restored && json_encode(M.codec.encode(restored)) == json_encode(graph), "fixed offer [label] restores exact graph without default ammunition or fuel")
		qdel(I)
		qdel(restored)
	var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline/can = new(null)
	can.reagents.clear_reagents()
	can.reagents.add_reagent("gasoline", 37.5, safety = TRUE)
	can.flags |= OPENCONTAINER
	var/list/fuel_graph = M.codec.encode(can)
	var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/reloaded = M.codec.decode(fuel_graph, locate(3,3,1))
	equipment_assert(reloaded && reloaded.reagents.total_volume == 37.5 && reloaded.reagents.get_reagent_amount("gasoline") == 37.5 && reloaded.is_open_container(), "partially used open fuel can restores its exact remaining quantity")
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank = new(locate(3,3,1))
	tank.reagents.clear_reagents()
	tank.flags |= OPENCONTAINER
	var/mob/living/human/fuel_user = new(locate(3,3,1))
	equipment_assert(reloaded.attack_obj(tank, fuel_user) && tank.reagents.get_reagent_amount("gasoline") == 30 && reloaded.reagents.total_volume == 7.5, "restored paid-offer fuel reaches a production vehicle tank through ordinary pouring")
	qdel(tank)
	qdel(fuel_user)
	var/list/bad = json_decode(json_encode(fuel_graph))
	bad["nodes"][1]["fuel"][1]["volume"] = 151
	equipment_assert(!M.codec.decode(bad, locate(3,3,1)), "oversized fuel payload rejected before constructors")
	qdel(can)
	qdel(reloaded)
	var/obj/item/stack/material/cloth/cloth = new(null)
	cloth.amount = 7
	var/list/cloth_graph = M.codec.encode(cloth)
	var/obj/item/stack/material/cloth/first = M.codec.decode(cloth_graph, locate(3,3,1))
	var/obj/item/stack/material/cloth/second = M.codec.decode(cloth_graph, locate(3,3,1))
	equipment_assert(first && second && first != second && first.amount == 7 && second.amount == 7, "stack restoration does not constructor-merge or manufacture quantities")
	bad = json_decode(json_encode(cloth_graph))
	bad["nodes"][1]["scalars"]["amount"] = 51
	equipment_assert(!M.codec.decode(bad, locate(3,3,1)), "oversized stack rejected before restoration")
	qdel(cloth)
	qdel(first)
	qdel(second)
