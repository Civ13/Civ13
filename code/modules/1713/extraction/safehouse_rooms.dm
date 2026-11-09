// Safe-house rooms for Extraction accounts. Rooms are built up with workshop
// parts, materials and money from the private room, are kept in the account
// profile, and take on timed work that runs in real time, even while offline.

/proc/extraction_safehouse_rooms()
	var/static/list/rooms = list(
		"racks" = list("name" = "Storage racks", "about" = "8 more stash spaces per level, up to 64.", "costs" = list(
			list("/obj/item/extraction_salvage" = 3, "/obj/item/stack/material/wood" = 10),
			list("/obj/item/extraction_salvage" = 6, "/obj/item/stack/material/steel" = 10),
			list("/obj/item/extraction_salvage" = 10, "/obj/item/stack/material/steel" = 20))),
		"workbench" = list("name" = "Workbench", "about" = "Makes tool parts, magazines and armour.", "costs" = list(
			list("/obj/item/extraction_salvage" = 3, "/obj/item/stack/material/wood" = 10),
			list("/obj/item/extraction_salvage" = 6, "/obj/item/stack/material/steel" = 10),
			list("/obj/item/extraction_salvage" = 10, "/obj/item/stack/material/kevlar" = 10, "EUR" = 200))),
		"medstation" = list("name" = "Medical station", "about" = "Makes bandages and splints.", "costs" = list(
			list("/obj/item/extraction_salvage" = 3, "/obj/item/stack/material/cloth" = 10),
			list("/obj/item/extraction_salvage" = 6, "EUR" = 100))),
		"contacts" = list("name" = "Contacts desk", "about" = "Traders pay 5% more of an item's value and charge 5% less per level.", "costs" = list(
			list("EUR" = 100),
			list("/obj/item/extraction_salvage" = 5, "GBP" = 150),
			list("EUR" = 400, "GBP" = 300))))
	return rooms

/proc/extraction_safehouse_recipes()
	var/static/list/recipes = list(
		"handle" = list("label" = "Wooden handle", "room" = "workbench", "level" = 1, "minutes" = 5, "inputs" = list("/obj/item/stack/material/wood" = 2), "type" = /obj/item/weapon/material/handle),
		"pickaxe" = list("label" = "Iron pickaxe head", "room" = "workbench", "level" = 1, "minutes" = 20, "inputs" = list("/obj/item/stack/material/iron" = 5), "type" = /obj/item/weapon/material/part/pickaxe, "material" = "iron"),
		"magazine" = list("label" = "AKM magazine", "room" = "workbench", "level" = 2, "minutes" = 30, "inputs" = list("/obj/item/stack/material/steel" = 4), "type" = /obj/item/ammo_magazine/ak47),
		"vest" = list("label" = "Carrier vest", "room" = "workbench", "level" = 3, "minutes" = 60, "inputs" = list("/obj/item/stack/material/kevlar" = 10, "/obj/item/stack/material/steel" = 5), "type" = /obj/item/clothing/accessory/armor/nomads/pcarrierblack),
		"bandages" = list("label" = "5 cloth bandages", "room" = "medstation", "level" = 1, "minutes" = 10, "inputs" = list("/obj/item/stack/material/cloth" = 4), "type" = /obj/item/stack/medical/bruise_pack/bint, "amount" = 5),
		"splints" = list("label" = "2 splints", "room" = "medstation", "level" = 1, "minutes" = 10, "inputs" = list("/obj/item/stack/material/wood" = 4), "type" = /obj/item/stack/medical/splint, "amount" = 2),
		"bandage_bale" = list("label" = "15 cloth bandages", "room" = "medstation", "level" = 2, "minutes" = 20, "inputs" = list("/obj/item/stack/material/cloth" = 8), "type" = /obj/item/stack/medical/bruise_pack/bint, "amount" = 15))
	return recipes

/proc/extraction_needs_text(list/needs)
	var/list/parts = list()
	for (var/key in needs)
		if (key == "EUR" || key == "GBP")
			parts += extraction_money_text(key, needs[key])
			continue
		var/path = text2path(key)
		if (path == /obj/item/extraction_salvage)
			parts += "[needs[key]] workshop parts"
			continue
		var/atom/proto = path
		parts += "[needs[key]] [initial(proto.name)]"
	return jointext(parts, ", ")

// Finds what pays for `needs` among the room's own uninsured roots.
// Returns list("take" = stack -> count, "sold" = items, "change" = currency -> face) or null.
/obj/map_metadata/extraction_survival/proc/room_payment(datum/extraction_session/S, list/needs)
	var/list/take = list()
	var/list/sold = list()
	var/list/change = list()
	var/list/roots = home_roots(S)
	for (var/key in needs)
		var/count = needs[key]
		if (key == "EUR" || key == "GBP")
			var/list/plan = extraction_payment_plan(money_roots(S, key), count)
			if (!plan) return null
			for (var/note in plan["take"]) take[note] = plan["take"][note]
			if (plan["change"]) change[key] = plan["change"]
			continue
		var/path = text2path(key)
		if (path == /obj/item/extraction_salvage)
			for (var/obj/item/extraction_salvage/I in roots)
				if (count <= 0) break
				if (!I.extraction_insurance_token && !I.extraction_secure_stored && !I.contents.len)
					sold += I
					count--
		else
			for (var/obj/item/stack/I in roots)
				if (count <= 0) break
				if (I.type == path && !I.extraction_insurance_token && !I.extraction_secure_stored && !take[I])
					take[I] = min(I.amount, count)
					count -= take[I]
		if (count > 0) return null
	return list("take" = take, "sold" = sold, "change" = change)

/obj/map_metadata/extraction_survival/proc/room_change_notes(list/payment)
	. = list()
	for (var/currency in payment["change"])
		var/list/notes = extraction_make_notes(currency, payment["change"][currency])
		if (!notes)
			for (var/obj/item/I in .) qdel(I)
			return null
		. += notes

/obj/map_metadata/extraction_survival/proc/room_quote_current(mob/living/human/H, digest, expires)
	var/datum/extraction_session/S = H.extraction_session
	return supply_access(H) && world.time <= expires && md5(json_encode(S.profile)) == digest && json_encode(records(home_roots(S))) == json_encode(S.profile["stash"])

/obj/map_metadata/extraction_survival/proc/room_upgrade(mob/living/human/H, room)
	if (!supply_access(H) || !save_home(H.extraction_session)) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	var/list/spec = extraction_safehouse_rooms()[room]
	if (!spec) return FALSE
	var/level = extraction_room_level(S.profile, room) + 1
	if (level > length(spec["costs"]))
		to_chat(H, "The [lowertext(spec["name"])] is already at its highest level.")
		return FALSE
	if (level > S.profile["level"])
		to_chat(H, "Upgrade the house to level [level] first.")
		return FALSE
	var/list/needs = spec["costs"][level]
	if (!room_payment(S, needs))
		to_chat(H, "The [lowertext(spec["name"])] level [level] needs [extraction_needs_text(needs)] in your room.")
		return FALSE
	var/digest = md5(json_encode(S.profile))
	var/expires = world.time + 2 MINUTES
	if (!confirm_trade(H, "Safe house rooms", "Build the [lowertext(spec["name"])] to level [level] for [extraction_needs_text(needs)]? [spec["about"]]") || !room_quote_current(H, digest, expires)) return FALSE
	var/list/payment = room_payment(S, needs)
	var/list/change = payment ? room_change_notes(payment) : null
	if (!change) return FALSE
	var/list/old_rooms = S.profile["rooms"]
	var/list/rooms = islist(old_rooms) ? old_rooms.Copy() : list()
	rooms[room] = level
	if (!trader_commit(S, payment["take"], payment["sold"], change, 0, list("rooms" = rooms)))
		for (var/obj/item/I in change) qdel(I)
		return FALSE
	to_chat(H, "The [lowertext(spec["name"])] is now level [level]. Stash capacity: [S.capacity()].")
	return TRUE

/obj/map_metadata/extraction_survival/proc/room_start(mob/living/human/H, recipe_id)
	if (!supply_access(H) || !save_home(H.extraction_session)) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	var/list/recipe = extraction_safehouse_recipes()[recipe_id]
	if (!recipe || extraction_room_level(S.profile, recipe["room"]) < recipe["level"]) return FALSE
	var/list/jobs = islist(S.profile["jobs"]) ? S.profile["jobs"] : list()
	for (var/list/job in jobs)
		if (job["room"] == recipe["room"])
			to_chat(H, "That room is still busy.")
			return FALSE
	if (jobs.len >= 4 || !room_payment(S, recipe["inputs"]))
		to_chat(H, "[recipe["label"]] needs [extraction_needs_text(recipe["inputs"])] in your room.")
		return FALSE
	var/digest = md5(json_encode(S.profile))
	var/expires = world.time + 2 MINUTES
	if (!confirm_trade(H, "Safe house work", "Make [recipe["label"]] from [extraction_needs_text(recipe["inputs"])]? It is ready in [recipe["minutes"]] minutes, even while you are away.") || !room_quote_current(H, digest, expires)) return FALSE
	var/list/payment = room_payment(S, recipe["inputs"])
	if (!payment) return FALSE
	var/list/new_jobs = json_decode(json_encode(jobs))
	new_jobs += list(list("id" = md5("[S.owner]:[recipe_id]:[S.profile["revision"]]:[world.realtime]"), "room" = recipe["room"], "recipe" = recipe_id, "done" = num2text(extraction_minutes_now() + recipe["minutes"], 12)))
	if (!trader_commit(S, payment["take"], payment["sold"], list(), 0, list("jobs" = new_jobs))) return FALSE
	to_chat(H, "[recipe["label"]] started. Collect it at the terminal in [recipe["minutes"]] minutes.")
	return TRUE

/obj/map_metadata/extraction_survival/proc/room_collect(mob/living/human/H)
	if (!supply_access(H) || !save_home(H.extraction_session)) return 0
	var/datum/extraction_session/S = H.extraction_session
	var/list/jobs = islist(S.profile["jobs"]) ? S.profile["jobs"] : list()
	var/list/kept = list()
	var/list/given = list()
	var/now = extraction_minutes_now()
	for (var/list/job in jobs)
		if (text2num(job["done"]) > now)
			kept += list(job)
			continue
		var/list/recipe = extraction_safehouse_recipes()[job["recipe"]]
		given += extraction_trader_product(recipe)
	if (!given.len)
		to_chat(H, "Nothing is ready yet.")
		return 0
	if (!trader_commit(S, list(), list(), given, 0, list("jobs" = kept)))
		for (var/obj/item/I in given) qdel(I)
		to_chat(H, "Make space in your stash first.")
		return 0
	to_chat(H, "Collected [given.len] finished job\s. They are in your room.")
	return given.len

/obj/map_metadata/extraction_survival/proc/manage_rooms(mob/living/human/H)
	if (!supply_access(H)) return
	var/datum/extraction_session/S = H.extraction_session
	var/list/rooms = extraction_safehouse_rooms()
	var/list/lines = list()
	var/list/options = list()
	var/now = extraction_minutes_now()
	for (var/id in rooms)
		var/level = extraction_room_level(S.profile, id)
		var/max_level = length(rooms[id]["costs"])
		lines += "[rooms[id]["name"]] level [level] of [max_level]"
		if (level < max_level) options["Build [rooms[id]["name"]] to level [level + 1] ([extraction_needs_text(rooms[id]["costs"][level + 1])])"] = list("upgrade", id)
	for (var/list/job in S.profile["jobs"])
		var/left = text2num(job["done"]) - now
		lines += "[extraction_safehouse_recipes()[job["recipe"]]["label"]]: [left > 0 ? "[left] min left" : "ready"]"
	for (var/recipe_id in extraction_safehouse_recipes())
		var/list/recipe = extraction_safehouse_recipes()[recipe_id]
		if (extraction_room_level(S.profile, recipe["room"]) >= recipe["level"]) options["Make [recipe["label"]] ([extraction_needs_text(recipe["inputs"])], [recipe["minutes"]] min)"] = list("start", recipe_id)
	if (length(S.profile["jobs"])) options["Collect finished work"] = list("collect")
	var/list/choice = options[WWinput(H, "[jointext(lines, ". ")]. Rooms are paid for with what is in your room. Stash capacity: [S.capacity()].", "Safe house rooms", "Cancel", options + list("Cancel"))]
	if (!islist(choice) || !supply_access(H)) return
	switch (choice[1])
		if ("upgrade") room_upgrade(H, choice[2])
		if ("start") room_start(H, choice[2])
		if ("collect") room_collect(H)

