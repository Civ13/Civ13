// Specialist traders: each dealer takes only some coins and trades only in its
// own goods; buy-back can never beat the sale price.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/specialist_trader_probe/New()
	return
/mob/living/human/specialist_trader_probe/New()
	return
/mob/living/human/specialist_trader_probe/update_icons()
	return
var/trader_failures = 0
var/trader_runtime_error = FALSE
/proc/trader_check(condition, label)
	if (!condition)
		trader_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	trader_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Copper's worth of coin of these kinds on the mob and its tile.
/proc/trader_coins_near(mob/M, list/kinds)
	. = 0
	var/turf/T = get_turf(M)
	for (var/obj/item/stack/money/C in M.contents + T.contents)
		if (QDELETED(C))
			continue
		var/root = specialist_trader_coin_root(C.type)
		if (root && (!kinds || (root in kinds)))
			. += C.amount * specialist_trader_coin_units(C.type)

/proc/trader_clear(turf/T, mob/living/human/H = null)
	for (var/obj/item/I in T)
		qdel(I)
	if (H)
		for (var/obj/item/I in H)
			qdel(I)
		H.l_hand = null
		H.r_hand = null
		H.l_store = null
		H.r_store = null

/proc/trader_give(mob/living/human/H, path, amount, slot = "r_hand")
	var/obj/item/stack/money/C = new path(H)
	C.amount = amount
	H.vars[slot] = C
	return C

/proc/trader_checks()
	if (!research_nodes.len)
		build_research_tree()
	for (var/kind in list("armourer", "apothecary", "scrap_dealer", "provisioner", "jeweller"))
		trader_check(get_recipe_node_req("/obj/structure/specialist_trader/[kind]") == "early_economy", "Trade & Coinage research gates the [kind]'s post")
		trader_check(specialist_trader_get(kind), "the [kind] exists")
	map.ordinal_age = 6

	// Prices fit the dealer's coins; nobody buys anything back for more than half
	// what any dealer sells it for.
	var/turf/spot = locate(10, 10, 1)
	for (var/id in specialist_traders)
		var/datum/specialist_trader/T = specialist_traders[id]
		var/unit = T.smallest_unit(T.accepts)
		for (var/n = 1, n <= T.catalogue.len, n++)
			var/list/entry = T.catalogue[n].Copy()
			entry[5] = T.prices[n]
			world.log << "PRICE [id] [entry[2]] x [entry[1]] = [entry[5]] copper (ages [entry[3]]-[entry[4]], [entry[6]] per restock)"
			trader_check(entry[5] > 0 && entry[5] % unit == 0, "[id] sells [entry[1]] for whole [specialist_trader_coin_name(T.accepts[1])] coins ([entry[5]])")
			trader_check(entry[3] <= entry[4] && entry[6] > 0, "[id]'s [entry[1]] has an age range and stock")
			var/path = entry[1]
			var/obj/item/I = new path(spot)
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				S.amount = entry[2]
			else
				entry[5] = entry[5] / entry[2]
			trader_check(T.deals_in(I), "[id] buys back what it sells ([path])")
			for (var/other_id in specialist_traders)
				var/datum/specialist_trader/B = specialist_traders[other_id]
				var/offer = B.offer_for(I, null)
				if (isnum(offer))
					trader_check(offer <= entry[5] * 0.5, "[other_id] pays at most half of [id]'s price for [path] ([offer] of [entry[5]])")
			qdel(I)

	// Each dealer keeps to its own goods.
	var/datum/specialist_trader/armourer = specialist_trader_get("armourer")
	var/datum/specialist_trader/provisioner = specialist_trader_get("provisioner")
	var/datum/specialist_trader/scrap = specialist_trader_get("scrap_dealer")
	var/datum/specialist_trader/jeweller = specialist_trader_get("jeweller")
	var/obj/item/bread = new /obj/item/weapon/reagent_containers/food/snacks/sliceable/bread(spot)
	var/obj/item/helmet = new /obj/item/clothing/head/helmet/ww2(spot)
	var/obj/item/stack/material/gold/bar = new(spot)
	var/obj/item/stack/money/gems/gem = new(spot)
	trader_check(!armourer.deals_in(bread) && provisioner.deals_in(bread), "bread goes to the provisioner, not the armourer")
	trader_check(armourer.deals_in(helmet) && !provisioner.deals_in(helmet), "a helmet goes to the armourer, not the provisioner")
	trader_check(!scrap.deals_in(bar) && jeweller.deals_in(bar), "gold bars go to the jeweller, not the scrap dealer")
	trader_check(jeweller.deals_in(gem) && !armourer.deals_in(gem), "gems go to the jeweller")
	var/obj/item/stack/money/silvercoin/loose = new(spot)
	for (var/id in specialist_traders)
		var/datum/specialist_trader/T = specialist_traders[id]
		trader_check(!T.deals_in(loose), "the [id] does not buy coins as goods")
	// Worn-out gear is refused by dealers that care about condition.
	helmet.maxhealth = 100
	helmet.health = 20
	trader_check(!isnum(armourer.offer_for(helmet, null)), "the armourer refuses a helmet at 20% condition")
	helmet.health = 100
	trader_clear(spot)

	// Paying: only accepted coins count, the smallest go first, change is given.
	var/mob/living/human/specialist_trader_probe/H = new(locate(5, 5, 1))
	var/obj/structure/specialist_trader/armourer/post = new(locate(5, 6, 1))
	var/obj/structure/specialist_trader/armourer/second = new(locate(6, 6, 1))
	trader_check(post.name == "armourer's post" && findtext(post.desc, "takes gold or silver coins"), "the post names its dealer's coins ([post.desc])")
	armourer.restock_if_due()
	var/helmet_index = 0
	for (var/i = 1, i <= armourer.catalogue.len, i++)
		var/list/entry = armourer.catalogue[i]
		if (entry[1] == /obj/item/clothing/head/helmet/ww2)
			helmet_index = i
	trader_check(helmet_index, "the armourer sells a WW2 helmet in age 6")
	var/price = armourer.prices[helmet_index]
	trader_give(H, /obj/item/stack/money/coppercoin, 5000)
	trader_check(!post.buy(H, helmet_index) && trader_coins_near(H, null) == 5000, "copper coins do not buy from the armourer, and none are taken")
	qdel(H.r_hand)
	H.r_hand = null
	trader_give(H, /obj/item/stack/money/goldcoin, 4, "l_hand")
	trader_give(H, /obj/item/stack/money/silvercoin, 3, "r_store")
	var/before_stock = armourer.stock_left[helmet_index]
	trader_check(post.buy(H, helmet_index), "silver and gold buy the helmet ([price] copper)")
	trader_check(trader_coins_near(H, null) == 190 - price, "the buyer pays exactly the price and gets change ([trader_coins_near(H, null)] left of 190)")
	var/turf/HT = get_turf(H)
	trader_check(locate(/obj/item/clothing/head/helmet/ww2) in (H.contents + HT.contents), "the buyer gets the helmet")
	trader_check(second.trader() == post.trader() && armourer.stock_left[helmet_index] == before_stock - 1, "both armourer's posts share one stock")
	armourer.stock_left[helmet_index] = 0
	trader_give(H, /obj/item/stack/money/goldcoin, 100, "l_hand")
	trader_check(!second.buy(H, helmet_index), "a sold-out item cannot be bought at the other post")
	trader_clear(get_turf(H), H)
	H.l_hand = null
	H.r_hand = null
	H.r_store = null

	// Selling: coins come out of the dealer's purse in the dealer's own coins.
	var/obj/item/clothing/head/helmet/ww2/old = new(H)
	H.r_hand = old
	var/offer = armourer.offer_for(old, H)
	var/purse = armourer.purse
	trader_check(isnum(offer) && offer > 0, "the armourer offers for a helmet ([offer])")
	trader_check(post.sell(H, old, FALSE) && QDELETED(old), "the helmet is sold and taken")
	trader_check(armourer.purse == purse - offer && trader_coins_near(H, list(/obj/item/stack/money/goldcoin, /obj/item/stack/money/silvercoin)) == offer && !trader_coins_near(H, list(/obj/item/stack/money/coppercoin)), "the armourer pays [offer] copper's worth in silver and gold from the purse")
	armourer.purse = 0
	var/obj/item/clothing/head/helmet/ww2/another = new(H)
	H.r_hand = another
	trader_check(!post.sell(H, another, FALSE) && !QDELETED(another), "an empty purse buys nothing until the next restock")
	armourer.next_restock = world.time
	armourer.restock_if_due()
	trader_check(armourer.purse == armourer.purse_per_restock && armourer.stock_left[helmet_index] == armourer.catalogue[helmet_index][6], "a restock refills the purse and the stock")
	trader_clear(get_turf(H), H)
	H.r_hand = null

	// The jeweller changes coins for a twentieth.
	var/obj/structure/specialist_trader/jeweller/jpost = new(locate(4, 6, 1))
	var/obj/item/stack/money/coppercoin/change = trader_give(H, /obj/item/stack/money/coppercoin, 100)
	trader_check(jpost.change_coins(H, change, /obj/item/stack/money/silvercoin), "the jeweller changes copper into silver")
	trader_check(trader_coins_near(H, list(/obj/item/stack/money/silvercoin)) == 90 && trader_coins_near(H, list(/obj/item/stack/money/coppercoin)) == 5, "100 copper becomes 9 silver and 5 copper back")
	trader_clear(get_turf(H), H)
	H.r_hand = null
	var/obj/item/stack/money/coppercoin/few = trader_give(H, /obj/item/stack/money/coppercoin, 30)
	trader_check(!jpost.change_coins(H, few, /obj/item/stack/money/goldcoin) && !QDELETED(few), "too few coins for one gold coin are handed back untouched")

	// Research: an item gated by a node the buyer's faction lacks is not sold.
	var/gated = 0
	for (var/id in specialist_traders)
		var/datum/specialist_trader/T = specialist_traders[id]
		for (var/list/entry in T.catalogue)
			var/node = get_recipe_node_req("[entry[1]]")
			if (node)
				gated++
				trader_check(T.entry_researched(entry, H) == map.is_node_done(H.civilization, node), "[id]'s [entry[1]] follows the [node] research")
	world.log << "catalogue entries gated by research: [gated]"

/proc/trader_run()
	try
		trader_checks()
	catch(var/exception/e)
		trader_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = trader_failures, "runtime_error" = trader_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/specialist_trader_probe
		trader_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		trader_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		trader_run()
