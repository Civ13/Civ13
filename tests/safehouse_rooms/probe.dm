// Safe house rooms: parties build rooms up with supplies handed in at a depot,
// and rooms take on timed work collected at any depot of the land.
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
/obj/map_metadata/safehouse_rooms_probe/New()
	return
/mob/living/human/safehouse_rooms_probe/New()
	return
/mob/living/human/safehouse_rooms_probe/update_icons()
	return
var/rooms_failures = 0
var/rooms_runtime_error = FALSE
/proc/rooms_check(condition, label)
	if (!condition)
		rooms_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rooms_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/rooms_count(atom/A, path)
	. = 0
	for (var/obj/item/I in A)
		if (istype(I, path))
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				. += S.amount
			else
				.++

// Moves every job of party's record `minutes` into the past.
/proc/rooms_age_jobs(party, minutes)
	var/list/record = safehouse_record(party)
	for (var/list/job in record["jobs"])
		job["done"] = num2text(text2num(job["done"]) - minutes, 12)
	safehouse_record_store(record, null)

/proc/rooms_checks()
	if (!research_nodes.len)
		build_research_tree()
	map.ordinal_age = 6
	var/mob/living/human/safehouse_rooms_probe/H = new(locate(5, 5, 1))
	H.persistence_owner_ckey = "probeplayer"
	var/party = party_train_party_of(H)
	var/obj/structure/safehouse_depot/depot = new(locate(4, 4, 1))
	var/obj/structure/safehouse_depot/far_depot = new(locate(15, 15, 1))
	rooms_check(safehouse_capacity(party) == 20, "a safe house starts with 20 shipment spaces")

	// Building the stash from what the player holds.
	var/obj/item/stack/material/wood/few = new(H, 10, FALSE)
	H.r_hand = few
	rooms_check(!safehouse_upgrade(depot, party, "stash", H) && few.amount == 10 && safehouse_level(party, "stash") == 0, "10 wood is not enough for the stash, and none is taken")
	qdel(few)
	var/obj/item/stack/material/wood/wood = new(H, 35, FALSE)
	H.r_hand = wood
	rooms_check(safehouse_upgrade(depot, party, "stash", H), "35 wood builds the stash")
	rooms_check(wood.amount == 5 && safehouse_level(party, "stash") == 1 && safehouse_capacity(party) == 30, "the stash takes 30 wood and keeps 30 shipments (wood left [wood.amount])")
	rooms_check("rooms" in depot.get_saved_vars(), "the depot's rooms are a saved field")
	rooms_check(safehouse_level(party, "stash") == 1 && safehouse_record_holder(party), "every depot in the land finds the same rooms")
	rooms_check(safehouse_level("ckey:someoneelse", "stash") == 0, "another party's safe house has no stash")
	H.r_hand = null
	qdel(wood)

	// Work needs its room; supplies can come from a crate next to the depot.
	rooms_check(!safehouse_recipe("dried_meat").available(party, H), "drying meat needs a kitchen")
	var/obj/structure/closet/crate/crate = new(locate(5, 4, 1))
	for (var/obj/item/I in crate.contents.Copy())
		qdel(I)
	new /obj/item/stack/material/wood(crate, 20, FALSE)
	new /obj/item/stack/material/stone(crate, 25, FALSE)
	crate.close()
	rooms_check(safehouse_upgrade(depot, party, "kitchen", H), "a crate of wood and stone builds the kitchen")
	rooms_check(!rooms_count(crate, /obj/item/stack/material/wood) && rooms_count(crate, /obj/item/stack/material/stone) == 5, "the kitchen takes 20 wood and 20 stone from the crate")
	for (var/n in 1 to 4)
		new /obj/item/weapon/reagent_containers/food/snacks/meat(crate)
	rooms_check(safehouse_recipe("dried_meat").available(party, H), "the kitchen can dry meat")
	rooms_check(safehouse_start_work(far_depot, party, "dried_meat", H) == FALSE, "work at a depot without the crate next to it finds no meat")
	rooms_check(safehouse_start_work(depot, party, "dried_meat", H), "the kitchen starts drying meat")
	rooms_check(rooms_count(crate, /obj/item/weapon/reagent_containers/food/snacks/meat) == 1, "drying takes 3 of the 4 meat")
	new /obj/item/weapon/reagent_containers/food/snacks/meat(crate)
	new /obj/item/weapon/reagent_containers/food/snacks/meat(crate)
	rooms_check(!safehouse_start_work(depot, party, "dried_meat", H) && rooms_count(crate, /obj/item/weapon/reagent_containers/food/snacks/meat) == 3, "a room does one job at a time and takes nothing for a second")
	var/turf/feet = get_turf(H)
	rooms_check(!safehouse_collect(depot, party, H).len && !rooms_count(feet, /obj/item/weapon/reagent_containers/food/snacks/driedmeat), "unfinished work cannot be collected")

	// The record is plain saved text; a reloaded depot still holds it.
	var/list/saved = depot.rooms.Copy()
	var/list/record = safehouse_record_decode(saved[1])
	rooms_check(record && record["party"] == party && record["rooms"]["kitchen"] == 1 && length(record["jobs"]) == 1, "the saved record names the party, its rooms and the job")
	rooms_check(!safehouse_record_decode(replacetext(saved[1], "\"kitchen\":1", "\"kitchen\":7")), "a record edited past level 3 is refused")
	rooms_check(!safehouse_record_decode(replacetext(saved[1], "dried_meat", "gold_from_nothing")), "a record naming unknown work is refused")

	// Time passes (real time, so it runs while nobody is on).
	rooms_age_jobs(party, 31)
	var/list/goods = safehouse_collect(far_depot, party, H)
	rooms_check(goods.len == 3 && rooms_count(feet, /obj/item/weapon/reagent_containers/food/snacks/driedmeat) == 3, "finished work is collected at another depot: 3 dried meat")
	rooms_check(!length(safehouse_record(party)["jobs"]) && !safehouse_collect(depot, party, H).len, "collected work is gone and cannot be collected twice")
	for (var/obj/item/I in feet)
		qdel(I)

	// The contacts desk: better trader prices both ways, still no arbitrage.
	var/datum/specialist_trader/armourer = specialist_trader_get("armourer")
	var/obj/item/clothing/suit/armor/armour = new(locate(10, 10, 1))
	var/plain_offer = armourer.offer_for(armour, H)
	var/index = 0
	for (var/i in 1 to armourer.catalogue.len)
		var/list/entry = armourer.catalogue[i]
		if (entry[1] == /obj/item/clothing/head/helmet/ww2)
			index = i
	var/plain_price = armourer.price_for(index, H)
	var/obj/item/stack/money/goldcoin/gold = new(H, 200, FALSE)
	H.r_hand = gold
	rooms_check(safehouse_upgrade(depot, party, "contacts", H) == FALSE, "the contacts desk wants wood and silver, not gold")
	gold.amount = 200
	var/obj/item/stack/money/silvercoin/silver = new(crate, 100, FALSE)
	new /obj/item/stack/material/wood(crate, 10, FALSE)
	rooms_check(safehouse_upgrade(depot, party, "contacts", H) && QDELETED(silver), "100 silver and 10 wood build the contacts desk")
	rooms_check(safehouse_upgrade(depot, party, "contacts", H) && gold.amount == 150, "50 gold builds it to level 2")
	rooms_check(armourer.rate_bonus(H) == 0.1, "level 2 gives 10% better terms (got [armourer.rate_bonus(H)])")
	var/better_offer = armourer.offer_for(armour, H)
	var/better_price = armourer.price_for(index, H)
	rooms_check(better_offer > plain_offer && better_price < plain_price, "the armourer pays more ([plain_offer] -> [better_offer]) and charges less ([plain_price] -> [better_price])")
	var/obj/item/clothing/head/helmet/ww2/sold = new(locate(10, 10, 1))
	var/resale = armourer.offer_for(sold, H)
	rooms_check(isnum(resale) && resale <= better_price * 0.5, "buying a helmet back still pays at most half its cheaper price ([resale] of [better_price])")

	// A renamed party keeps its rooms; a deleted depot hands its records on.
	safehouse_rename(party, "ckey:renamed")
	rooms_check(safehouse_level("ckey:renamed", "kitchen") == 1 && safehouse_level(party, "kitchen") == 0, "a renamed party keeps its rooms")
	safehouse_rename("ckey:renamed", party)
	var/obj/structure/safehouse_depot/holder = safehouse_record_holder(party)[1]
	var/obj/structure/safehouse_depot/other = holder == depot ? far_depot : depot
	qdel(holder)
	rooms_check(safehouse_level(party, "contacts") == 2 && other.rooms.len == 1, "a deleted depot's rooms move to another depot")

/proc/rooms_run()
	try
		rooms_checks()
	catch(var/exception/e)
		rooms_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rooms_failures, "runtime_error" = rooms_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/safehouse_rooms_probe
		rooms_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		rooms_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		rooms_run()
