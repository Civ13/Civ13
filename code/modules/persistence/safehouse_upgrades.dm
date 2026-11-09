// Safe house upgrades and safe house work. A party's safe house (party_freight.dm)
// has rooms that the party builds up, three levels each, by handing supplies in
// at any depot of the land: from the hand, or from a closed crate pushed next
// to the depot. The rooms:
//
// - the stash keeps 10 more shipments a level;
// - the workshop, infirmary, kitchen and still take on timed work: the party
//   hands in the inputs, and the goods wait at the safe house once the time
//   (real time, so it runs while everyone is away) has passed;
// - the contacts desk gets the party better terms with the specialist traders
//   (specialist_traders.dm).
//
// Each party's rooms and work are one JSON record in a depot's saved `rooms`
// field, like its shipments; any depot of the land finds it.

#define SAFEHOUSE_MAX_LEVEL 3
#define SAFEHOUSE_JOBS_PER_ROOM 1
#define SAFEHOUSE_RECORD_TEXT 4000

var/global/list/safehouse_room_types = null
var/global/list/safehouse_recipe_types = null

/proc/safehouse_rooms_list()
	if (!safehouse_room_types)
		safehouse_room_types = list()
		for (var/path in subtypesof(/datum/safehouse_room))
			var/datum/safehouse_room/R = new path
			safehouse_room_types[R.id] = R
	return safehouse_room_types

/proc/safehouse_room(id)
	return safehouse_rooms_list()[id]

/proc/safehouse_recipes_list()
	if (!safehouse_recipe_types)
		safehouse_recipe_types = list()
		for (var/path in subtypesof(/datum/safehouse_recipe))
			var/datum/safehouse_recipe/R = new path
			safehouse_recipe_types[R.id] = R
	return safehouse_recipe_types

/proc/safehouse_recipe(id)
	return safehouse_recipes_list()[id]

// -- records ----------------------------------------------------------------------

// Real time in whole minutes since 2000. Jobs keep it as text: a JSON number
// this large loses its last digits.
/proc/safehouse_now()
	return round(world.realtime / 600)

/proc/safehouse_job_done(list/job)
	return text2num(job["done"])

// A party's record as a list: party, rooms (id = level) and jobs.
/proc/safehouse_record_decode(text)
	if (!istext(text) || length(text) > SAFEHOUSE_RECORD_TEXT)
		return null
	var/list/record
	try
		record = json_decode(text)
	catch
		return null
	if (!islist(record) || !party_train_valid_party(record["party"]) || !islist(record["rooms"]) || !islist(record["jobs"]))
		return null
	var/list/rooms = record["rooms"]
	for (var/id in rooms)
		var/level = rooms[id]
		if (!safehouse_room(id) || !isnum(level) || level < 0 || level > SAFEHOUSE_MAX_LEVEL || level != round(level))
			return null
	for (var/list/job in record["jobs"])
		if (!islist(job) || !safehouse_recipe(job["recipe"]) || !istext(job["done"]) || !isnum(text2num(job["done"])))
			return null
	return record

/proc/safehouse_blank_record(party)
	return list("party" = party, "rooms" = list(), "jobs" = list())

// The depot and index holding party's record, or null.
/proc/safehouse_record_holder(party)
	for (var/obj/structure/safehouse_depot/D in safehouse_depots)
		if (QDELETED(D))
			continue
		for (var/i in 1 to D.rooms.len)
			var/list/record = safehouse_record_decode(D.rooms[i])
			if (record && record["party"] == party)
				return list(D, i)
	return null

/proc/safehouse_record(party)
	var/list/holder = safehouse_record_holder(party)
	if (!holder)
		return safehouse_blank_record(party)
	var/obj/structure/safehouse_depot/D = holder[1]
	return safehouse_record_decode(D.rooms[holder[2]])

// Writes party's record back where it lives, or into `fallback` for a new one.
/proc/safehouse_record_store(list/record, obj/structure/safehouse_depot/fallback)
	var/text = json_encode(record)
	if (length(text) > SAFEHOUSE_RECORD_TEXT || !safehouse_record_decode(text))
		return FALSE
	var/list/holder = safehouse_record_holder(record["party"])
	if (holder)
		var/obj/structure/safehouse_depot/D = holder[1]
		D.rooms[holder[2]] = text
	else if (fallback)
		fallback.rooms += text
	else
		return FALSE
	return TRUE

// A depot is going: its rooms records move to another depot of the land.
/proc/safehouse_rehome(obj/structure/safehouse_depot/gone)
	for (var/obj/structure/safehouse_depot/D in safehouse_depots)
		if (D != gone && !QDELETED(D))
			D.rooms += gone.rooms
			gone.rooms = list()
			return TRUE
	for (var/text in gone.rooms)
		log_game("Safe house: rooms lost with the last depot at [gone.x],[gone.y],[gone.z]: [text]")
	return FALSE

/proc/safehouse_level(party, id)
	var/list/record = safehouse_record(party)
	var/list/rooms = record["rooms"]
	return rooms[id] || 0

// Shipments the party's safe house keeps.
/proc/safehouse_capacity(party)
	return 20 + 10 * safehouse_level(party, "stash")

/proc/safehouse_rename(old_party, new_party)
	for (var/obj/structure/safehouse_depot/D in safehouse_depots)
		for (var/i in 1 to D.rooms.len)
			var/list/record = safehouse_record_decode(D.rooms[i])
			if (record && record["party"] == old_party)
				record["party"] = new_party
				D.rooms[i] = json_encode(record)

// -- supplies ----------------------------------------------------------------------

// What the player hands in: the held item and closed crates next to the depot.
/proc/safehouse_supplies(obj/structure/safehouse_depot/D, mob/living/human/H)
	. = list()
	var/obj/item/held = H.get_active_hand()
	if (held)
		. += held
	for (var/obj/structure/closet/crate/C in party_freight_crates(D))
		for (var/obj/item/I in C.contents)
			. += I

/proc/safehouse_count(list/supplies, path)
	. = 0
	for (var/obj/item/I in supplies)
		if (istype(I, path))
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				. += S.amount
			else
				.++

// The first missing need, as text, or null when all are there.
/proc/safehouse_missing(list/supplies, list/needs)
	for (var/path in needs)
		var/have = safehouse_count(supplies, path)
		if (have < needs[path])
			return "[needs[path] - have] more [safehouse_need_name(path)]"
	return null

/proc/safehouse_need_name(path)
	var/atom/proto = path
	return initial(proto.name)

/proc/safehouse_needs_text(list/needs)
	var/list/parts = list()
	for (var/path in needs)
		parts += "[needs[path]] [safehouse_need_name(path)]"
	return english_list(parts)

// Takes the needs out of the supplies. Check safehouse_missing() first.
/proc/safehouse_consume(list/supplies, list/needs, mob/living/human/H)
	for (var/path in needs)
		var/left = needs[path]
		for (var/obj/item/I in supplies)
			if (left <= 0)
				break
			if (QDELETED(I) || !istype(I, path))
				continue
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				var/take = min(left, S.amount)
				left -= take
				if (take >= S.amount)
					if (H && S.loc == H)
						H.remove_from_mob(S)
					qdel(S)
				else
					S.amount -= take
					S.update_icon()
			else
				left--
				if (H && I.loc == H)
					H.remove_from_mob(I)
				qdel(I)

// -- rooms ------------------------------------------------------------------------

/datum/safehouse_room
	var/id = null
	var/name = "room"
	var/desc = ""
	// One list(path = amount) per level, 1 to SAFEHOUSE_MAX_LEVEL.
	var/list/costs = list()

/datum/safehouse_room/proc/level_text(level)
	return "level [level]"

/datum/safehouse_room/stash
	id = "stash"
	name = "stash"
	desc = "Shelving and lockers: each level keeps 10 more shipments."
	costs = list(
		list(/obj/item/stack/material/wood = 30),
		list(/obj/item/stack/material/wood = 30, /obj/item/stack/material/iron = 20),
		list(/obj/item/stack/material/iron = 10, /obj/item/stack/material/steel = 20),
	)

/datum/safehouse_room/stash/level_text(level)
	return "keeps [20 + 10 * level] shipments"

/datum/safehouse_room/workshop
	id = "workshop"
	name = "workshop"
	desc = "Forge and benches: smelts ore, makes steel and casts rounds."
	costs = list(
		list(/obj/item/stack/material/wood = 20, /obj/item/stack/material/stone = 20),
		list(/obj/item/stack/material/iron = 20, /obj/item/weapon/hammer = 1),
		list(/obj/item/stack/material/steel = 20, /obj/item/weapon/wrench = 1),
	)

/datum/safehouse_room/infirmary
	id = "infirmary"
	name = "infirmary"
	desc = "Clean cots and a dispensary: makes bandages, splints and trauma kits."
	costs = list(
		list(/obj/item/stack/material/wood = 20, /obj/item/stack/material/cloth = 10),
		list(/obj/item/stack/material/cloth = 20, /obj/item/stack/material/glass = 10),
		list(/obj/item/stack/material/steel = 10, /obj/item/stack/material/glass = 20),
	)

/datum/safehouse_room/kitchen
	id = "kitchen"
	name = "kitchen"
	desc = "Smokehouse and ovens: dries meat, bakes hardtack and cures hams."
	costs = list(
		list(/obj/item/stack/material/wood = 20, /obj/item/stack/material/stone = 20),
		list(/obj/item/stack/material/iron = 10, /obj/item/stack/material/stone = 20),
		list(/obj/item/stack/material/steel = 10, /obj/item/stack/material/glass = 10),
	)

/datum/safehouse_room/still
	id = "still"
	name = "still"
	desc = "Mash tubs and copper stills: brews beer and distils spirits."
	costs = list(
		list(/obj/item/stack/material/wood = 20, /obj/item/stack/material/copper = 10),
		list(/obj/item/stack/material/copper = 20, /obj/item/stack/material/glass = 10),
		list(/obj/item/stack/material/steel = 10, /obj/item/stack/material/glass = 20),
	)

/datum/safehouse_room/contacts
	id = "contacts"
	name = "contacts desk"
	desc = "Ledgers and letters of introduction: each level gets the party 5% better prices from the specialist traders, both ways."
	costs = list(
		list(/obj/item/stack/material/wood = 10, /obj/item/stack/money/silvercoin = 100),
		list(/obj/item/stack/money/goldcoin = 50),
		list(/obj/item/stack/money/goldcoin = 150),
	)

/datum/safehouse_room/contacts/level_text(level)
	return "[level * 5]% better trader prices"

// -- work --------------------------------------------------------------------------

/datum/safehouse_recipe
	var/id = null
	var/name = "work"
	var/room = null
	var/level = 1
	var/list/inputs = list()
	var/output = null
	var/amount = 1
	var/minutes = 30
	var/first_age = 0
	var/last_age = 9

/datum/safehouse_recipe/proc/available(party, mob/living/human/H)
	var/age = map ? map.ordinal_age : 0
	if (age < first_age || age > last_age)
		return FALSE
	if (safehouse_level(party, room) < level)
		return FALSE
	if (map && H)
		var/node = get_recipe_node_req("[output]")
		if (node && !map.is_node_done(H.civilization, node))
			return FALSE
	return TRUE

/datum/safehouse_recipe/proc/output_text()
	return amount > 1 ? "[amount] [safehouse_need_name(output)]" : safehouse_need_name(output)

// Builds the finished goods at T.
/datum/safehouse_recipe/proc/build(turf/T)
	. = list()
	if (ispath(output, /obj/item/stack))
		var/obj/item/stack/S = new output(T, amount, FALSE)
		S.update_icon()
		. += S
	else
		for (var/n in 1 to amount)
			. += new output(T)

/datum/safehouse_recipe/iron
	id = "iron"
	name = "smelt iron"
	room = "workshop"
	level = 1
	inputs = list(/obj/item/stack/ore/iron = 10, /obj/item/stack/ore/coal = 5)
	output = /obj/item/stack/material/iron
	amount = 8
	minutes = 20
	first_age = 2

/datum/safehouse_recipe/steel
	id = "steel"
	name = "make steel"
	room = "workshop"
	level = 2
	inputs = list(/obj/item/stack/material/iron = 5, /obj/item/stack/ore/coal = 5)
	output = /obj/item/stack/material/steel
	amount = 5
	minutes = 40
	first_age = 4

/datum/safehouse_recipe/bullets
	id = "bullets"
	name = "cast bullets"
	room = "workshop"
	level = 3
	inputs = list(/obj/item/stack/material/lead = 5)
	output = /obj/item/stack/ammopart/bullet
	amount = 30
	minutes = 30
	first_age = 4

/datum/safehouse_recipe/casings
	id = "casings"
	name = "draw rifle casings"
	room = "workshop"
	level = 3
	inputs = list(/obj/item/stack/material/copper = 5)
	output = /obj/item/stack/ammopart/casing/rifle
	amount = 30
	minutes = 30
	first_age = 4

/datum/safehouse_recipe/bandages
	id = "bandages"
	name = "roll bandages"
	room = "infirmary"
	level = 1
	inputs = list(/obj/item/stack/material/cloth = 4)
	output = /obj/item/stack/medical/bruise_pack/bint
	amount = 10
	minutes = 20
	last_age = 4

/datum/safehouse_recipe/gauze
	id = "gauze"
	name = "cut gauze"
	room = "infirmary"
	level = 1
	inputs = list(/obj/item/stack/material/cloth = 4)
	output = /obj/item/stack/medical/bruise_pack/gauze
	amount = 10
	minutes = 20
	first_age = 5

/datum/safehouse_recipe/splints
	id = "splints"
	name = "carve splints"
	room = "infirmary"
	level = 2
	inputs = list(/obj/item/stack/material/wood = 5, /obj/item/stack/material/cloth = 2)
	output = /obj/item/stack/medical/splint
	amount = 4
	minutes = 20
	first_age = 3

/datum/safehouse_recipe/trauma_kit
	id = "trauma_kit"
	name = "pack trauma kits"
	room = "infirmary"
	level = 3
	inputs = list(/obj/item/stack/medical/bruise_pack/gauze = 10, /obj/item/stack/material/cloth = 5)
	output = /obj/item/stack/medical/advanced/bruise_pack
	amount = 2
	minutes = 60
	first_age = 7

/datum/safehouse_recipe/dried_meat
	id = "dried_meat"
	name = "smoke and dry meat"
	room = "kitchen"
	level = 1
	inputs = list(/obj/item/weapon/reagent_containers/food/snacks/meat = 3)
	output = /obj/item/weapon/reagent_containers/food/snacks/driedmeat
	amount = 3
	minutes = 30

/datum/safehouse_recipe/hardtack
	id = "hardtack"
	name = "bake hardtack"
	room = "kitchen"
	level = 2
	inputs = list(/obj/item/weapon/reagent_containers/food/snacks/grown/wheat = 4)
	output = /obj/item/weapon/reagent_containers/food/snacks/hardtack
	amount = 4
	minutes = 30

/datum/safehouse_recipe/cured_ham
	id = "cured_ham"
	name = "cure a ham"
	room = "kitchen"
	level = 3
	inputs = list(/obj/item/weapon/reagent_containers/food/snacks/meat = 5)
	output = /obj/item/weapon/reagent_containers/food/snacks/curedham
	amount = 1
	minutes = 120

/datum/safehouse_recipe/beer
	id = "beer"
	name = "brew beer"
	room = "still"
	level = 1
	inputs = list(/obj/item/weapon/reagent_containers/food/snacks/grown/wheat = 4)
	output = /obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer
	amount = 2
	minutes = 60
	first_age = 1

/datum/safehouse_recipe/vodka
	id = "vodka"
	name = "distil vodka"
	room = "still"
	level = 2
	inputs = list(/obj/item/weapon/reagent_containers/food/snacks/grown/potato = 6)
	output = /obj/item/weapon/reagent_containers/food/drinks/bottle/vodka
	amount = 1
	minutes = 90
	first_age = 3

/datum/safehouse_recipe/whiskey
	id = "whiskey"
	name = "distil whiskey"
	room = "still"
	level = 3
	inputs = list(/obj/item/weapon/reagent_containers/food/snacks/grown/wheat = 6)
	output = /obj/item/weapon/reagent_containers/food/drinks/bottle/whiskey
	amount = 1
	minutes = 120
	first_age = 3

// -- the depot menu --------------------------------------------------------------------

/proc/safehouse_jobs_text(list/record)
	var/list/lines = list()
	for (var/list/job in record["jobs"])
		var/datum/safehouse_recipe/R = safehouse_recipe(job["recipe"])
		var/left = safehouse_job_done(job) - safehouse_now()
		lines += left > 0 ? "[R.output_text()] ([R.room], ready in [left] min)" : "[R.output_text()] ([R.room], ready)"
	return lines.len ? english_list(lines) : "none"

/proc/safehouse_room_busy(list/record, room)
	. = 0
	for (var/list/job in record["jobs"])
		var/datum/safehouse_recipe/R = safehouse_recipe(job["recipe"])
		if (R.room == room)
			.++

/obj/structure/safehouse_depot/proc/rooms_menu(mob/living/human/H, party)
	var/list/record = safehouse_record(party)
	var/list/rooms = record["rooms"]
	var/list/options = list()
	for (var/id in safehouse_rooms_list())
		var/datum/safehouse_room/R = safehouse_room(id)
		var/level = rooms[id] || 0
		if (level < SAFEHOUSE_MAX_LEVEL)
			options["Build the [R.name] to level [level + 1] ([safehouse_needs_text(R.costs[level + 1])])"] = "room:[id]"
	for (var/id in safehouse_recipes_list())
		var/datum/safehouse_recipe/W = safehouse_recipe(id)
		if (W.available(party, H) && safehouse_room_busy(record, W.room) < SAFEHOUSE_JOBS_PER_ROOM)
			options["[capitalize(W.name)]: [safehouse_needs_text(W.inputs)] into [W.output_text()] ([W.minutes] min)"] = "work:[id]"
	var/ready = 0
	for (var/list/job in record["jobs"])
		if (safehouse_job_done(job) <= safehouse_now())
			ready++
	if (ready)
		options["Collect finished work ([ready])"] = "collect"
	var/list/levels = list()
	for (var/id in safehouse_rooms_list())
		var/datum/safehouse_room/R = safehouse_room(id)
		var/level = rooms[id] || 0
		levels += level ? "[R.name] [level] ([R.level_text(level)])" : "no [R.name]"
	var/choice = WWinput(H, "[party_train_party_name(party)]'s safe house: [english_list(levels)]. Work under way: [safehouse_jobs_text(record)]. Supplies come from your hand and closed crates next to the depot.", "Safe house rooms", "Cancel", options + list("Cancel"))
	if (!(choice in options))
		return
	var/action = options[choice]
	if (busy || QDELETED(src) || !Adjacent(H) || H.stat != CONSCIOUS || party_train_party_of(H) != party || party_freight_busy())
		return
	busy = TRUE
	if (action == "collect")
		safehouse_collect(src, party, H)
	else if (findtext(action, "room:") == 1)
		safehouse_upgrade(src, party, copytext(action, 6), H)
	else if (findtext(action, "work:") == 1)
		safehouse_start_work(src, party, copytext(action, 6), H)
	busy = FALSE

/proc/safehouse_upgrade(obj/structure/safehouse_depot/D, party, id, mob/living/human/H)
	var/datum/safehouse_room/R = safehouse_room(id)
	var/list/record = safehouse_record(party)
	var/list/rooms = record["rooms"]
	var/level = rooms[id] || 0
	if (!R || level >= SAFEHOUSE_MAX_LEVEL)
		return FALSE
	var/list/needs = R.costs[level + 1]
	var/list/supplies = safehouse_supplies(D, H)
	var/missing = safehouse_missing(supplies, needs)
	if (missing)
		to_chat(H, SPAN_WARNING("The [R.name] needs [missing]. Hold the supplies, or push a closed crate of them next to \the [D]."))
		return FALSE
	rooms[id] = level + 1
	record["rooms"] = rooms
	if (!safehouse_record_store(record, D))
		return FALSE
	safehouse_consume(supplies, needs, H)
	log_game("Safe house: [key_name(H)] built the [R.name] of [party] to level [level + 1] at [D.x],[D.y],[D.z].")
	to_chat(H, SPAN_NOTICE("The supplies go off to the safe house: the [R.name] is now level [level + 1] ([R.level_text(level + 1)])."))
	return TRUE

/proc/safehouse_start_work(obj/structure/safehouse_depot/D, party, id, mob/living/human/H)
	var/datum/safehouse_recipe/W = safehouse_recipe(id)
	var/list/record = safehouse_record(party)
	if (!W || !W.available(party, H) || safehouse_room_busy(record, W.room) >= SAFEHOUSE_JOBS_PER_ROOM)
		return FALSE
	var/list/supplies = safehouse_supplies(D, H)
	var/missing = safehouse_missing(supplies, W.inputs)
	if (missing)
		to_chat(H, SPAN_WARNING("That needs [missing]. Hold the supplies, or push a closed crate of them next to \the [D]."))
		return FALSE
	var/list/jobs = record["jobs"]
	jobs += list(list("recipe" = id, "done" = num2text(safehouse_now() + W.minutes, 12), "by" = H.ckey))
	record["jobs"] = jobs
	if (!safehouse_record_store(record, D))
		return FALSE
	safehouse_consume(supplies, W.inputs, H)
	log_game("Safe house: [key_name(H)] started [id] in the [W.room] of [party] at [D.x],[D.y],[D.z].")
	to_chat(H, SPAN_NOTICE("The [W.room] sets to work: [W.output_text()] in [W.minutes] minutes. Collect it at any depot in this land."))
	return TRUE

// Brings every finished job of the party out at H's feet.
/proc/safehouse_collect(obj/structure/safehouse_depot/D, party, mob/living/human/H)
	var/list/record = safehouse_record(party)
	var/list/kept = list()
	var/list/done = list()
	for (var/list/job in record["jobs"])
		if (safehouse_job_done(job) <= safehouse_now())
			done += list(job)
		else
			kept += list(job)
	if (!done.len)
		return list()
	record["jobs"] = kept
	if (!safehouse_record_store(record, D))
		return list()
	. = list()
	var/turf/T = get_turf(H)
	for (var/list/job in done)
		var/datum/safehouse_recipe/W = safehouse_recipe(job["recipe"])
		var/list/goods = W.build(T)
		. += goods
		log_game("Safe house: [key_name(H)] collected [W.output_text()] for [party] at [D.x],[D.y],[D.z].")
		to_chat(H, SPAN_NOTICE("[capitalize(W.output_text())] [W.amount > 1 ? "are" : "is"] brought out from the [W.room]."))

#undef SAFEHOUSE_MAX_LEVEL
#undef SAFEHOUSE_JOBS_PER_ROOM
#undef SAFEHOUSE_RECORD_TEXT
