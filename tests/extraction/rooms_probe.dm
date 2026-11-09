// Extraction safe-house rooms: account-held room levels, real-time work and the
// contacts desk discount, through a real private-room account.
/proc/extraction_rooms_probe(obj/map_metadata/extraction_survival/M)
	for (var/id in extraction_safehouse_rooms())
		equipment_assert(extraction_room_limits()[id] == length(extraction_safehouse_rooms()[id]["costs"]), "the store's limit for [id] matches its costs")
	equipment_assert(extraction_room_limits().len == extraction_safehouse_rooms().len && extraction_room_work().len == extraction_safehouse_recipes().len, "the store knows every room and every kind of work")
	for (var/id in extraction_safehouse_recipes())
		var/list/work = extraction_room_work()[id]
		equipment_assert(work && work["room"] == extraction_safehouse_recipes()[id]["room"] && work["level"] == extraction_safehouse_recipes()[id]["level"], "the store's record of [id] matches the recipe")
	var/list/base = list("level" = 2, "rooms" = list("racks" = 1, "workbench" = 2), "jobs" = list(list("id" = md5("a"), "room" = "workbench", "recipe" = "magazine", "done" = "14000000")))
	equipment_assert(extraction_rooms_valid(base) && extraction_rooms_valid(list("level" = 1)), "room levels and a running job are a valid profile")
	var/list/bad = json_decode(json_encode(base))
	bad["rooms"]["racks"] = 3
	equipment_assert(!extraction_rooms_valid(bad), "a room above the house level is refused")
	bad = json_decode(json_encode(base))
	bad["rooms"]["vault"] = 1
	equipment_assert(!extraction_rooms_valid(bad), "an unknown room is refused")
	bad = json_decode(json_encode(base))
	bad["rooms"]["workbench"] = 1
	equipment_assert(!extraction_rooms_valid(bad), "work above its room's level is refused")
	bad = json_decode(json_encode(base))
	bad["jobs"] += list(list("id" = md5("b"), "room" = "workbench", "recipe" = "handle", "done" = "1"))
	equipment_assert(!extraction_rooms_valid(bad), "a room runs one job at a time")
	bad = json_decode(json_encode(base))
	bad["jobs"][1]["done"] = "soon"
	equipment_assert(!extraction_rooms_valid(bad), "a malformed finish time is refused")
	bad = json_decode(json_encode(base))
	bad["jobs"][1]["recipe"] = "gold_from_nothing"
	equipment_assert(!extraction_rooms_valid(bad), "unknown work is refused")
	equipment_assert(extraction_profile_capacity(list("level" = 1, "rooms" = list("racks" = 1))) == 24 && extraction_profile_capacity(list("level" = 4, "rooms" = list("racks" = 3))) == 64, "racks add 8 spaces a level, never past 64")

	// The contacts desk at its highest level still never lets a loop profit.
	var/list/traders = extraction_specialist_traders()
	for (var/seller in traders)
		for (var/list/entry in traders[seller]["stock"])
			var/obj/item/product = extraction_trader_product(entry)
			var/list/graph = M.codec.encode(product)
			for (var/buyer in traders)
				var/value = 0
				for (var/list/node in graph["nodes"])
					value += extraction_trader_policy.value(node, traders[buyer]["policy"])
				equipment_assert(round(value * (traders[buyer]["spread_bps"] + 1500) / 10000) <= entry["price"] * 0.85, "with a level 3 desk, [buyer] still pays less than [seller] charges for [entry["label"]]")
			qdel(product)
	for (var/recipe_id in extraction_safehouse_recipes())
		var/obj/item/output = extraction_trader_product(extraction_safehouse_recipes()[recipe_id])
		var/list/output_graph = M.codec.encode(output)
		equipment_assert(output_graph && M.codec.validate(output_graph), "[recipe_id] makes supported stash equipment")
		qdel(output)

	var/old = extraction_fx
	var/datum/extraction_fx/fx = new
	fx.fetching = FALSE
	fx.cache_loaded = TRUE
	fx.accept(fx.parse(traders_ecb_xml(time2text(world.realtime, "YYYY-MM-DD"), "0.87710"), "probe"), FALSE)
	extraction_fx = fx
	var/mob/living/human/H = new(locate(3,3,1))
	H.m_intent = "stealth"
	M.test_owners[H] = "roombuilder"
	equipment_assert(M.admit(H), "room builder admitted")
	var/datum/extraction_session/S = H.extraction_session
	H.forceMove(get_turf(S.house))
	var/turf/room = get_turf(S.house)
	M.test_trade_confirmation = TRUE
	new /obj/item/stack/material/wood(room, 8, FALSE)
	for (var/i in 1 to 3) new /obj/item/extraction_salvage(room)
	var/roots_before = M.home_roots(S).len
	equipment_assert(!M.room_upgrade(H, "racks") && extraction_room_level(S.profile, "racks") == 0 && M.home_roots(S).len == roots_before, "8 wood is not enough for racks, and nothing is taken")
	new /obj/item/stack/material/wood(room, 12, FALSE)
	equipment_assert(M.room_upgrade(H, "racks") && extraction_room_level(S.profile, "racks") == 1 && S.capacity() == 24, "3 parts and 10 wood build racks: 24 spaces")
	var/wood_left = 0
	var/parts_left = 0
	for (var/obj/item/I in M.home_roots(S))
		if (istype(I, /obj/item/stack/material/wood)) wood_left += I:amount
		if (istype(I, /obj/item/extraction_salvage)) parts_left++
	equipment_assert(wood_left == 10 && !parts_left && json_encode(M.records(M.home_roots(S))) == json_encode(S.profile["stash"]), "exactly 3 parts and 10 wood were taken and the room matches the saved stash")
	equipment_assert(!M.room_upgrade(H, "racks"), "racks level 2 waits for house level 2")
	for (var/i in 1 to 3) new /obj/item/extraction_salvage(room)
	equipment_assert(M.room_upgrade(H, "workbench"), "the workbench is built")
	equipment_assert(!M.room_start(H, "magazine"), "magazines need a level 2 workbench")
	new /obj/item/stack/material/wood(room, 4, FALSE)
	equipment_assert(M.room_start(H, "handle") && length(S.profile["jobs"]) == 1, "the workbench starts a handle")
	equipment_assert(!M.room_start(H, "handle"), "one job per room")
	equipment_assert(!M.room_collect(H) && !(locate(/obj/item/weapon/material/handle) in room), "unfinished work cannot be collected")
	equipment_assert(M.release(S) && M.admit(H), "rooms and work survive release and reload")
	S = H.extraction_session
	H.forceMove(get_turf(S.house))
	equipment_assert(extraction_room_level(S.profile, "workbench") == 1 && length(S.profile["jobs"]) == 1 && S.capacity() == 24, "reloaded account keeps its rooms, job and capacity")
	var/list/candidate = S.copy_profile()
	candidate["jobs"][1]["done"] = num2text(extraction_minutes_now() - 1, 12)
	equipment_assert(S.commit(candidate), "time passes for the job")
	equipment_assert(M.room_collect(H) == 1 && (locate(/obj/item/weapon/material/handle) in room) && !length(S.profile["jobs"]), "the finished handle is collected once")
	equipment_assert(!M.room_collect(H), "collected work cannot be collected twice")

	// The contacts desk lowers trader prices.
	new /obj/item/stack/money/european/euro100(room, 1, FALSE)
	new /obj/item/stack/money/european/euro20(room, 1, FALSE)
	equipment_assert(M.room_upgrade(H, "contacts") && extraction_room_level(S.profile, "contacts") == 1 && M.money_total(S, "EUR") == 20, "€100 builds the contacts desk")
	equipment_assert(M.trader_buy(H, "armourer", 1, "EUR") && M.money_total(S, "EUR") == 1, "a level 1 desk takes the €20 magazine down to €19")
	var/list/tampered = S.copy_profile()
	tampered["rooms"]["contacts"] = 3
	equipment_assert(!M.accounts.store.valid_profile(tampered, S.owner), "a saved desk above the house level is refused")
	equipment_assert(M.release(S), "room fixture releases its account")
	M.round_participants -= "roombuilder"
	qdel(H)
	extraction_fx = old
