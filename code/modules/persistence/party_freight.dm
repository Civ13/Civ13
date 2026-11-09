// Party freight: a player or a faction ships goods off the map to its safe
// house or to its party train, and recalls them later. A party is the same as
// for party trains (party_train.dm): the player's faction, or the player alone.
//
// A shipment is what one hand holds or one closed crate with what is inside
// it. Each item becomes a bounded record, the way vehicle storage keeps cars
// (vehicle_storage.dm): the extraction equipment codec when it can rebuild the
// item exactly (clothing, guns with their rounds, bags and their contents,
// tools, some stacks), otherwise the region travel kinds (allowlisted stacks
// and coins, untouched food and medicine, plain tools, magazines) or a plain
// material or ore stack. The items are deleted, so nothing of a shipment is
// simulated, rendered or walked by world saves. The record is JSON text in an
// ordinary saved field of the structure that holds it, so world saves (Gaia,
// Persistence rounds) carry it like the rest of the structure.
//
// - A safe house depot (/obj/structure/safehouse_depot) is built in a base.
//   Every depot in a land opens onto the same safe house per party: a party
//   recalls its goods at any of them, and nobody else sees or takes them.
// - A finished railway works office (party_train.dm) loads goods into the
//   party's train and unloads them again. Only the train's party may use it.

#define PARTY_FREIGHT_ITEMS 60 // top-level items in one shipment
#define PARTY_FREIGHT_TEXT 300000 // characters in one shipment record
#define PARTY_FREIGHT_TRAIN 30 // shipments a party's train carries
#define PARTY_FREIGHT_TIME 30

// Stacks the travel kinds do not cover but that rebuild from type and amount:
// material sheets of their own material and plain ore.
/proc/party_freight_plain_stack(obj/item/stack/S)
	if(!istype(S) || S.amount < 1 || S.amount > S.max_amount || length(S.contents)) return FALSE
	if(istype(S, /obj/item/stack/material))
		var/obj/item/stack/material/M = S
		return M.material && M.material.name == initial(M.default_type)
	if(istype(S, /obj/item/stack/ore))
		var/obj/item/stack/ore/O = S
		return O.radioactive == initial(O.radioactive) && O.radioactive_amt == initial(O.radioactive_amt)
	return FALSE

/proc/party_freight_plain_path(path, amount)
	if(!ispath(path, /obj/item/stack/material) && !ispath(path, /obj/item/stack/ore)) return FALSE
	var/obj/item/stack/prototype = path
	return isnum(amount) && amount >= 1 && amount == round(amount) && amount <= initial(prototype.max_amount)

// One item and what is inside it as a record entry, or null.
/proc/party_freight_encode_item(obj/item/I)
	if(!istype(I) || QDELETED(I)) return null
	var/datum/extraction_equipment_codec/codec = new
	var/list/record = codec.encode(I, TRUE, FALSE)
	if(record)
		return list("record" = record)
	var/kind = region_travel_item_kind(I)
	// An untouched item of a travelling family is rebuilt from its type.
	if(kind == "type")
		kind = "[I.type]"
	if(kind)
		var/amount = 1
		if(istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			amount = S.amount
		else if(istype(I, /obj/item/ammo_magazine))
			amount = region_travel_ammo_count(I)
		if(region_travel_item_path(kind, amount))
			return list("kind" = kind, "amount" = amount)
	if(party_freight_plain_stack(I))
		var/obj/item/stack/S = I
		return list("kind" = "plain:[I.type]", "amount" = S.amount)
	return null

// Whether an entry read back from a saved field can be rebuilt.
/proc/party_freight_entry_valid(list/entry)
	if(!islist(entry)) return FALSE
	if(islist(entry["record"]))
		var/datum/extraction_equipment_codec/codec = new
		return codec.validate(entry["record"])
	var/kind = entry["kind"]
	var/amount = entry["amount"]
	if(!istext(kind) || !isnum(amount)) return FALSE
	if(findtext(kind, "plain:") == 1)
		return party_freight_plain_path(text2path(copytext(kind, 7)), amount)
	return !!region_travel_item_path(kind, amount)

// Rebuilds one entry inside destination and returns the item.
/proc/party_freight_build_item(list/entry, atom/destination)
	var/obj/item/I
	if(islist(entry["record"]))
		var/datum/extraction_equipment_codec/codec = new
		I = codec.decode(entry["record"], destination)
		// Decode builds account-owned items; goods back in the world are saved with it.
		if(I)
			for(var/obj/O in vehicle_storage_objects(list(I)))
				O.should_save = initial(O.should_save)
		return I
	var/kind = entry["kind"]
	var/amount = entry["amount"]
	var/path = findtext(kind, "plain:") == 1 ? text2path(copytext(kind, 7)) : region_travel_item_path(kind, amount)
	if(!path) return null
	if(ispath(path, /obj/item/stack))
		// Built away from other stacks, so it cannot merge before it is placed.
		var/obj/item/stack/S = new path(null, amount)
		S.amount = amount
		S.update_icon()
		I = S
	else
		I = new path(null)
	if(istype(I, /obj/item/ammo_magazine))
		region_travel_fill_magazine(I, amount)
	else if(istype(I, /obj/item/weapon/gun/projectile))
		region_travel_unload_gun(I)
	var/was_throwing = I.throwing
	if(istype(I, /obj/item/stack)) I.throwing = TRUE
	I.forceMove(destination)
	I.throwing = was_throwing
	return I

// Decoded shipment or null; every entry is validated before anything is built.
/proc/party_freight_shipment(text)
	if(!istext(text) || length(text) > PARTY_FREIGHT_TEXT) return null
	var/list/shipment
	try
		shipment = json_decode(text)
	catch
		return null
	if(!islist(shipment) || !istext(shipment["name"]) || !istext(shipment["id"]) || !party_train_valid_party(shipment["party"])) return null
	var/list/items = shipment["items"]
	if(!islist(items) || !items.len || items.len > PARTY_FREIGHT_ITEMS) return null
	if(!isnull(shipment["crate"]) && !ispath(text2path(shipment["crate"]), /obj/structure/closet/crate)) return null
	for(var/list/entry in items)
		if(!party_freight_entry_valid(entry)) return null
	return shipment

/proc/party_freight_busy()
	return persistence_save_in_progress || persistence_save_active()

// Closed crates standing next to S that a shipment can take.
/proc/party_freight_crates(obj/structure/S)
	. = list()
	for(var/obj/structure/closet/crate/C in orange(1, S))
		if(!C.opened && !C.anchored && !QDELETED(C) && isturf(C.loc))
			. += C

// Encodes goods (one held item, or a closed crate with its contents) as a
// shipment of party and deletes them. Returns the shipment text, or a reason
// starting with "!" when nothing was shipped.
/proc/party_freight_pack(atom/movable/goods, party, mob/living/human/H)
	var/list/roots = list()
	var/crate_path = null
	var/label
	if(istype(goods, /obj/structure/closet/crate))
		var/obj/structure/closet/crate/C = goods
		if(C.opened) return "!Close \the [C] first."
		for(var/atom/movable/A in C.contents)
			if(!istype(A, /obj/item)) return "!Something that is not an item is inside \the [C]."
			roots += A
		crate_path = "[C.type]"
		label = roots.len ? "[C.name] ([roots.len] item\s)" : "[C.name] (empty)"
	else if(istype(goods, /obj/item))
		roots += goods
		label = goods.name
		if(istype(goods, /obj/item/stack))
			var/obj/item/stack/S = goods
			label = "[S.amount] [S.name]"
	else
		return "!That can't be shipped."
	if(roots.len > PARTY_FREIGHT_ITEMS)
		return "!A shipment holds at most [PARTY_FREIGHT_ITEMS] items; split it up."
	if(!roots.len && !crate_path)
		return "!There is nothing to ship."
	var/list/entries = list()
	var/list/refused = list()
	for(var/obj/item/I in roots)
		var/list/entry = party_freight_encode_item(I)
		if(entry)
			entries += list(entry)
		else
			refused |= I.name
	if(refused.len)
		return "!These can't be shipped: [english_list(refused)]. Take them out, or empty the containers holding them."
	if(!entries.len)
		return "!There is nothing to ship."
	var/text = json_encode(list("name" = label, "party" = party, "crate" = crate_path, "items" = entries, "id" = new_extraction_item_id(), "by" = H ? H.ckey : null, "at" = time2text(world.realtime, "YYYY-MM-DD hh:mm")))
	if(length(text) > PARTY_FREIGHT_TEXT || !party_freight_shipment(text))
		return "!That is too much to ship at once; split it up."
	for(var/obj/item/I in roots)
		if(H && I.loc == H)
			H.remove_from_mob(I)
		qdel(I)
	if(crate_path)
		qdel(goods)
	return text

// Rebuilds a shipment at T: in a new crate of its own kind, or loose.
/proc/party_freight_unpack(list/shipment, turf/T)
	var/atom/destination = T
	if(shipment["crate"])
		var/crate_path = text2path(shipment["crate"])
		var/obj/structure/closet/crate/C = new crate_path(T)
		// Stocked crate kinds fill themselves; only the shipped goods come back.
		for(var/atom/movable/A in C.contents.Copy())
			qdel(A)
		if(C.opened)
			C.close()
		destination = C
	. = list()
	for(var/list/entry in shipment["items"])
		var/obj/item/I = party_freight_build_item(entry, destination)
		if(I) . += I
	if(istype(destination, /obj/structure/closet))
		var/obj/structure/closet/C = destination
		C.update_capacity(C.contents.len)

// Shipment texts of party among stored, by index in stored.
/proc/party_freight_indexes(list/stored, party)
	. = list()
	for(var/i in 1 to stored.len)
		var/list/shipment = party_freight_shipment(stored[i])
		if(shipment && shipment["party"] == party)
			. += i

/proc/party_freight_names(list/stored, party)
	. = list()
	for(var/i in party_freight_indexes(stored, party))
		var/list/shipment = party_freight_shipment(stored[i])
		. += shipment["name"]

// Asks what to ship and packs it for party. Returns the shipment text, or
// null when nothing went. held is how many shipments party already keeps there.
/proc/party_freight_ship(obj/structure/S, party, held, capacity, place, mob/living/human/H, from_crate)
	if(held >= capacity)
		to_chat(H, SPAN_WARNING("[place] is full: it keeps [capacity] shipments."))
		return null
	var/atom/movable/goods
	if(from_crate)
		var/list/crates = party_freight_crates(S)
		if(!crates.len)
			to_chat(H, SPAN_WARNING("Push a closed crate next to \the [S] first."))
			return null
		goods = crates[1]
		if(crates.len > 1)
			var/list/picks = list()
			for(var/obj/structure/closet/crate/C in crates)
				picks["[C.name] ([dir2text(get_dir(S, C))])"] = C
			var/pick = WWinput(H, "Which crate goes?", S.name, "Cancel", picks + list("Cancel"))
			goods = picks[pick]
			// The prompt slept: check the crate and the post again.
			if(!goods || QDELETED(goods) || QDELETED(S) || !S.Adjacent(H) || party_freight_busy() || !(goods in party_freight_crates(S)))
				return null
	else
		goods = H.get_active_hand()
		if(!goods)
			to_chat(H, SPAN_WARNING("Hold what you want to ship, or push a closed crate next to \the [S]."))
			return null
	var/text = party_freight_pack(goods, party, H)
	if(copytext(text, 1, 2) == "!")
		to_chat(H, SPAN_WARNING(copytext(text, 2)))
		return null
	var/list/shipment = json_decode(text)
	log_game("Party freight: [key_name(H)] shipped [shipment["name"]] for [party] to [S] at [S.x],[S.y],[S.z].")
	to_chat(H, SPAN_NOTICE("[shipment["name"]] is packed off to [lowertext(place)]."))
	return text

// Asks which of the shipment texts to bring back. Returns the chosen text.
/proc/party_freight_pick(obj/structure/S, list/texts, mob/living/human/H)
	if(!texts.len)
		to_chat(H, SPAN_WARNING("Nothing of yours is stored here."))
		return null
	var/list/picks = list()
	for(var/n in 1 to texts.len)
		var/list/shipment = party_freight_shipment(texts[n])
		picks["[n]. [shipment["name"]]"] = texts[n]
	var/pick = picks.len == 1 ? picks[1] : WWinput(H, "Which shipment should come back?", S.name, "Cancel", picks + list("Cancel"))
	return picks[pick]

// Takes one copy of text out of stored and rebuilds it at H's feet.
/proc/party_freight_recall(obj/structure/S, list/stored, text, party, mob/living/human/H)
	var/list/shipment = party_freight_shipment(text)
	var/index = stored.Find(text)
	var/turf/T = get_turf(H)
	if(!index || !shipment || shipment["party"] != party || !T)
		return null
	stored.Cut(index, index + 1)
	. = party_freight_unpack(shipment, T)
	log_game("Party freight: [key_name(H)] recalled [shipment["name"]] for [party] from [S] at [S.x],[S.y],[S.z].")
	to_chat(H, SPAN_NOTICE("[shipment["name"]] is brought out to you."))

// -- safe houses ---------------------------------------------------------------

var/global/list/safehouse_depots = list()

// A depot ships a party's goods to its safe house, off the map. Every depot in
// a land opens onto the same safe houses.
/obj/structure/safehouse_depot
	name = "safe house depot"
	desc = "A locked freight post. Ship what you hold, or a closed crate pushed next to it, off to your safe house; your faction (or you alone) can recall it at any depot in this land."
	icon = 'icons/obj/storage.dmi'
	icon_state = "securecrate"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	crushable = FALSE
	// One JSON shipment per entry, each naming its party; saved with the depot.
	var/list/freight = list()
	// One JSON record per party of its safe house rooms and work (safehouse_upgrades.dm).
	var/list/rooms = list()
	var/tmp/busy = FALSE

/obj/structure/safehouse_depot/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/safehouse_depot/New()
	..()
	safehouse_depots |= src
	if(!islist(freight))
		freight = list()
	if(!islist(rooms))
		rooms = list()

/obj/structure/safehouse_depot/Destroy()
	safehouse_depots -= src
	// Only an admin can delete a depot; say what went with it. A load swapping
	// the map out is not a loss.
	if(freight.len && !persistence_active_operation)
		message_admins("The safe house depot at [x],[y],[z] was deleted with [freight.len] shipment\s; they are in the game log.")
		for(var/text in freight)
			log_game("Party freight: deleted with the depot at [x],[y],[z]: [text]")
	// Rooms and work are the party's, not this depot's: another depot keeps them.
	if(rooms.len && !persistence_active_operation)
		safehouse_rehome(src)
	return ..()

/obj/structure/safehouse_depot/after_load()
	..()
	busy = FALSE
	if(!islist(freight))
		freight = list()
	if(!islist(rooms))
		rooms = list()
	safehouse_depots |= src

/obj/structure/safehouse_depot/ex_act(severity)
	return

// The depot holding shipment text of this land's safe houses, if any.
/proc/safehouse_depot_holding(text)
	for(var/obj/structure/safehouse_depot/D in safehouse_depots)
		if(!QDELETED(D) && (text in D.freight))
			return D
	return null

// Every safe house shipment of party in this land, as text = depot.
/proc/safehouse_shipments(party)
	. = list()
	for(var/obj/structure/safehouse_depot/D in safehouse_depots)
		if(QDELETED(D)) continue
		for(var/i in party_freight_indexes(D.freight, party))
			.[D.freight[i]] = D

/obj/structure/safehouse_depot/examine(mob/user)
	..()
	var/party = party_train_party_of(user)
	if(!party) return
	var/list/held = safehouse_shipments(party)
	var/list/names = list()
	for(var/text in held)
		var/list/shipment = party_freight_shipment(text)
		names += shipment["name"]
	to_chat(user, SPAN_NOTICE(names.len ? "[party_train_party_name(party)]'s safe house holds ([names.len]/[safehouse_capacity(party)]): [english_list(names)]." : "[party_train_party_name(party)]'s safe house is empty ([safehouse_capacity(party)] spaces)."))

/obj/structure/safehouse_depot/attack_hand(mob/living/human/H)
	if(busy || !istype(H) || !Adjacent(H) || H.stat != CONSCIOUS)
		return
	var/party = party_train_party_of(H)
	if(!party)
		return
	if(party_freight_busy())
		to_chat(H, SPAN_WARNING("The depot is busy. Try again in a moment."))
		return
	var/list/held = safehouse_shipments(party)
	var/list/options = list("Ship what you hold" = "hand", "Ship a crate next to the depot" = "crate")
	if(held.len)
		options["Recall a shipment"] = "recall"
	options["Safe house rooms and work"] = "rooms"
	var/choice = WWinput(H, "[party_train_party_name(party)]'s safe house holds [held.len]/[safehouse_capacity(party)] shipments.", name, "Cancel", options + list("Cancel"))
	if(!(choice in options))
		return
	if(options[choice] == "rooms")
		rooms_menu(H, party)
		return
	use_depot(H, party, options[choice])

/obj/structure/safehouse_depot/proc/use_depot(mob/living/human/H, party, action)
	if(busy || QDELETED(src) || !Adjacent(H) || party_train_party_of(H) != party)
		return
	busy = TRUE
	if(do_after(H, PARTY_FREIGHT_TIME, src) && !QDELETED(src) && Adjacent(H) && !party_freight_busy() && party_train_party_of(H) == party)
		var/list/held = safehouse_shipments(party)
		if(action == "recall")
			// The party's shipments may lie in any depot of this land.
			var/list/texts = list()
			for(var/text in held)
				texts += text
			var/text = party_freight_pick(src, texts, H)
			var/obj/structure/safehouse_depot/D = text ? safehouse_depot_holding(text) : null
			// The prompt slept: the shipment may have gone already.
			if(D && Adjacent(H) && !party_freight_busy() && party_train_party_of(H) == party)
				party_freight_recall(src, D.freight, text, party, H)
		else
			var/text = party_freight_ship(src, party, held.len, safehouse_capacity(party), "Your safe house", H, action == "crate")
			if(text)
				freight += text
	busy = FALSE

// -- party trains ------------------------------------------------------------------

/obj/structure/region_gate/railway_station/var/list/freight = list()
/obj/structure/region_gate/railway_station/var/tmp/freight_busy = FALSE

// Boarding stays the default answer, so an agent-driven character still boards.
/obj/structure/region_gate/railway_station/proc/freight_menu(mob/living/human/H)
	var/list/names = party_freight_names(freight, party)
	var/list/options = list("Board the train" = "board", "Load what you hold" = "hand", "Load a crate next to the office" = "crate")
	if(names.len)
		options["Unload a shipment"] = "recall"
	var/choice = WWinput(H, "The train carries [names.len]/[PARTY_FREIGHT_TRAIN] shipments[names.len ? ": [english_list(names)]" : ""].", name, "Board the train", options + list("Cancel"))
	if(!(choice in options))
		return
	var/action = options[choice]
	if(action == "board")
		travel(H)
		return
	if(freight_busy || QDELETED(src) || !Adjacent(H) || !party_train_may_board(H, party))
		return
	if(party_freight_busy())
		to_chat(H, SPAN_WARNING("The office is busy. Try again in a moment."))
		return
	freight_busy = TRUE
	if(do_after(H, PARTY_FREIGHT_TIME, src) && !QDELETED(src) && Adjacent(H) && !party_freight_busy() && party_train_may_board(H, party))
		if(action == "recall")
			var/text = party_freight_pick(src, party_freight_texts(freight, party), H)
			if(text && Adjacent(H) && !party_freight_busy() && party_train_may_board(H, party))
				party_freight_recall(src, freight, text, party, H)
		else
			var/text = party_freight_ship(src, party, party_freight_indexes(freight, party).len, PARTY_FREIGHT_TRAIN, "The train", H, action == "crate")
			if(text)
				freight += text
	freight_busy = FALSE

/proc/party_freight_texts(list/stored, party)
	. = list()
	for(var/i in party_freight_indexes(stored, party))
		. += stored[i]


// A renamed faction keeps its safe house and its train's freight.
/proc/party_freight_rename(old_party, new_party)
	for(var/obj/structure/safehouse_depot/D in safehouse_depots)
		D.freight = party_freight_reparty(D.freight, old_party, new_party)
	for(var/obj/structure/region_gate/railway_station/S in region_gates)
		S.freight = party_freight_reparty(S.freight, old_party, new_party)
	safehouse_rename(old_party, new_party)

/proc/party_freight_reparty(list/stored, old_party, new_party)
	. = list()
	for(var/text in stored)
		var/list/shipment = party_freight_shipment(text)
		if(shipment && shipment["party"] == old_party)
			shipment["party"] = new_party
			. += json_encode(shipment)
		else
			. += text

#undef PARTY_FREIGHT_ITEMS
#undef PARTY_FREIGHT_TEXT
#undef PARTY_FREIGHT_TRAIN
#undef PARTY_FREIGHT_TIME
