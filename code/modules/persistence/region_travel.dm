// Region travel: moves a player's character, with simple belongings, to a peer
// region of the same group (shard_group.dm) through the transfer agent
// (transfer_bridge.dm). Inert unless the bridge is on and the gate's
// destination is one of its peers.
//
// The character travels as a payload: identity, looks, skills, hunger and
// thirst, and a list of items that can be rebuilt exactly (allowlisted material
// stacks by kind and amount, empty clothing by type). Anything else must be
// left behind first, so nothing is lost or copied on the way. While the agent
// records the escrow the body and its items wait inside the gate; once it is
// recorded they are removed and the player is sent to the destination server.
// The destination builds the body at a gate or a late-join point, owned by the
// player's key, and hands it over when that key logs in. A refused transfer
// comes back the same way at the source.

#define REGION_TRAVEL_PAYLOAD_MAX 8192
#define REGION_TRAVEL_ITEMS_MAX 40

var/global/list/region_gates = list()

// Saved: a body that arrived and has not been claimed yet.
/mob/living/human/var/region_arrival_pending = FALSE

var/global/list/region_travel_slots = list(
	"back" = slot_back, "mask" = slot_wear_mask, "belt" = slot_belt, "id" = slot_wear_id,
	"l_ear" = slot_l_ear, "r_ear" = slot_r_ear, "eyes" = slot_eyes, "gloves" = slot_gloves,
	"head" = slot_head, "shoes" = slot_shoes, "suit" = slot_wear_suit, "uniform" = slot_w_uniform,
	"l_store" = slot_l_store, "r_store" = slot_r_store, "s_store" = slot_s_store,
	"l_hand" = slot_l_hand, "r_hand" = slot_r_hand, "shoulder" = slot_shoulder)

// Coins travel by kind and amount; preset-amount subtypes rebuild as the base.
var/global/list/region_travel_coins = list(
	"copper_coin" = /obj/item/stack/money/coppercoin,
	"silver_coin" = /obj/item/stack/money/silvercoin,
	"gold_coin" = /obj/item/stack/money/goldcoin)

var/global/list/region_travel_look_vars = list("r_hair", "g_hair", "b_hair", "h_style", "r_facial", "g_facial", "b_facial", "f_style", "r_eyes", "g_eyes", "b_eyes", "s_tone", "r_skin", "g_skin", "b_skin")

// How an item travels: "stack:<kind>" for an allowlisted material stack,
// "type" for empty clothing, or null when it cannot travel.
/proc/region_travel_item_kind(obj/item/I)
	if(!istype(I)) return null
	if(istype(I, /obj/item/stack))
		var/kind = transfer_trade_kind(I)
		if(kind) return "stack:[kind]"
		for(var/coin in region_travel_coins)
			if(istype(I, region_travel_coins[coin])) return "stack:[coin]"
		return null
	if(region_travel_type_allowed(I.type) && !length(I.contents))
		return "type"
	return null

/proc/region_travel_type_allowed(path)
	if(!ispath(path, /obj/item/clothing)) return FALSE
	// Clothing that stores things carries state that does not travel.
	if(ispath(path, /obj/item/clothing/accessory/storage)) return FALSE
	return TRUE

// Every item the character wears or holds, as list(slot name = item), or a
// text reason when something cannot travel.
/mob/living/human/proc/region_travel_items()
	var/list/items = list()
	var/list/refused = list()
	for(var/slot_name in region_travel_slots)
		var/obj/item/I = get_equipped_item(region_travel_slots[slot_name])
		if(!I) continue
		if(!region_travel_item_kind(I))
			refused += I.name
			continue
		items[slot_name] = I
	// Anything else on the body (cuffs, grabs, items in odd slots) blocks travel.
	var/list/known = list()
	for(var/slot_name in items)
		known += items[slot_name]
	for(var/obj/item/I in src)
		if(istype(I, /obj/item/organ) || istype(I, /obj/item/weapon/grab)) continue
		if(!(I in known) && !(I.name in refused))
			refused += I.name
	if(refused.len)
		return "Leave these behind first: [english_list(refused)]."
	if(items.len > REGION_TRAVEL_ITEMS_MAX)
		return "You carry too much to travel."
	return items

/mob/living/human/proc/region_travel_payload(list/items)
	var/list/look = list()
	for(var/name in region_travel_look_vars)
		look[name] = vars[name]
	// A style the destination cannot name is left out; the body keeps its default.
	if(!(look["h_style"] in hair_styles_list)) look -= "h_style"
	if(!(look["f_style"] in facial_hair_styles_list)) look -= "f_style"
	var/list/skills = list()
	for(var/stat in stats)
		var/list/pair = stats[stat]
		if(islist(pair) && pair.len == 2) skills[stat] = pair.Copy()
	var/list/carried = list()
	for(var/slot_name in items)
		var/obj/item/I = items[slot_name]
		var/kind = region_travel_item_kind(I)
		if(kind == "type")
			carried += list(list(slot_name, "[I.type]", 1))
		else
			var/obj/item/stack/S = I
			carried += list(list(slot_name, kind, S.amount))
	return json_encode(list("v" = 1, "kind" = "character", "owner" = persistence_owner_ckey, "name" = real_name,
		"gender" = gender, "age" = age, "look" = look, "skills" = skills,
		"nutrition" = clamp(round(nutrition), 0, 1000), "water" = clamp(round(water), 0, 1000), "items" = carried))

// Returns the decoded payload, or null when any field is out of bounds.
/proc/region_travel_decode(payload)
	if(!istext(payload) || length(payload) > REGION_TRAVEL_PAYLOAD_MAX) return null
	var/list/P
	try
		P = json_decode(payload)
	catch
		return null
	if(!islist(P) || P["v"] != 1 || P["kind"] != "character") return null
	var/owner = P["owner"]
	if(!istext(owner) || !length(owner) || length(owner) > 32 || ckey(owner) != owner || persistence_guest_account(owner)) return null
	if(!istext(P["name"]) || !length(P["name"]) || length(P["name"]) > MAX_NAME_LEN) return null
	if(!(P["gender"] in list(MALE, FEMALE, PLURAL, NEUTER))) return null
	if(!isnum(P["age"]) || P["age"] < 1 || P["age"] > 200) return null
	for(var/field in list("nutrition", "water"))
		if(!isnum(P[field]) || P[field] < 0 || P[field] > 1000) return null
	if(!islist(P["look"]) || !islist(P["skills"]) || !islist(P["items"]) || length(P["items"]) > REGION_TRAVEL_ITEMS_MAX) return null
	for(var/name in P["look"])
		if(!(name in region_travel_look_vars)) return null
		var/value = P["look"][name]
		if(name == "h_style")
			if(!istext(value) || !(value in hair_styles_list)) return null
		else if(name == "f_style")
			if(!istext(value) || !(value in facial_hair_styles_list)) return null
		else if(!isnum(value) || value < -255 || value > 255)
			return null
	for(var/stat in P["skills"])
		var/list/pair = P["skills"][stat]
		if(!istext(stat) || length(stat) > 32 || !islist(pair) || pair.len != 2 || !isnum(pair[1]) || !isnum(pair[2]) || pair[1] < 0 || pair[2] < 0 || pair[1] > 1000 || pair[2] > 1000) return null
	for(var/list/entry in P["items"])
		if(!islist(entry) || entry.len != 3 || !(entry[1] in region_travel_slots) || !istext(entry[2]) || !isnum(entry[3])) return null
		if(!region_travel_item_path(entry[2], entry[3])) return null
	return P

// The path an item entry rebuilds, or null when it is not allowed.
/proc/region_travel_item_path(kind, amount)
	if(copytext(kind, 1, 7) == "stack:")
		var/good = copytext(kind, 7)
		var/obj/item/stack/path = transfer_trade_goods[good] || region_travel_coins[good]
		if(!path || amount < 1 || amount != round(amount) || amount > min(2000, initial(path.max_amount))) return null
		return path
	var/path = text2path(kind)
	if(!path || amount != 1 || !region_travel_type_allowed(path)) return null
	return path

/proc/region_travel_arrival_turf()
	for(var/obj/structure/region_gate/gate in region_gates)
		if(!QDELETED(gate) && isturf(gate.loc)) return gate.loc
	var/list/starts = latejoin_turfs ? latejoin_turfs["JoinLateCiv"] : null
	if(length(starts)) return pick(starts)
	return null

// Builds recorded characters at T: arrivals at the destination, or travellers
// a peer refused back at the source. Callers have already recorded the effect,
// so this never refuses; an unreadable payload is reported and dropped.
/proc/region_travel_arrive(list/payloads, incoming, turf/T)
	if(!islist(payloads)) return
	if(!isturf(T) || QDELETED(T)) T = region_travel_arrival_turf()
	if(!isturf(T)) T = locate(1, 1, 1)
	for(var/payload in payloads)
		var/list/P = region_travel_decode(payload)
		if(!P)
			message_admins("Region travel: an unreadable [incoming ? "arriving" : "returned"] character was dropped.")
			continue
		var/mob/living/human/H = region_travel_build(P, T)
		log_game("Region travel: [P["owner"]]'s character [H.real_name] [incoming ? "arrived" : "came back"] at [T.x],[T.y],[T.z].")
		region_travel_offer(H)

/proc/region_travel_build(list/P, turf/T)
	var/mob/living/human/H = new /mob/living/human(T)
	// Keeps nomads_spawn from rolling a new identity half a second from now.
	H.persistence_restored = TRUE
	H.gender = P["gender"]
	H.age = P["age"]
	H.fully_replace_character_name(H.real_name, P["name"])
	for(var/name in P["look"])
		H.vars[name] = P["look"][name]
	for(var/stat in P["skills"])
		var/list/pair = P["skills"][stat]
		if(stat in H.stats)
			H.stats[stat] = pair.Copy()
	H.nutrition = P["nutrition"]
	H.water = P["water"]
	for(var/list/entry in P["items"])
		var/path = region_travel_item_path(entry[2], entry[3])
		var/obj/item/I = ispath(path, /obj/item/stack) ? new path(T, entry[3]) : new path(T)
		if(!H.equip_to_slot_if_possible(I, region_travel_slots[entry[1]], FALSE, TRUE))
			I.forceMove(T)
	// One durable body per account: an older clientless body here gives up its
	// claim, as record_persistence_owner() does, or every save would refuse.
	for(var/mob/living/human/other in human_mob_list)
		if(other != H && !other.client && other.persistence_owner_ckey == P["owner"])
			other.persistence_owner_ckey = null
			log_game("Region travel: [P["owner"]]'s earlier body [other.real_name] gave up its claim to the arrival.")
	H.persistence_owner_ckey = P["owner"]
	H.region_arrival_pending = TRUE
	H.update_hair(FALSE)
	H.update_body(FALSE)
	H.regenerate_icons()
	return H

// The account's arrived body, if exactly one is waiting.
/proc/region_travel_waiting_body(account)
	var/mob/living/human/found = null
	for(var/mob/living/human/H in human_mob_list)
		if(!H.region_arrival_pending || H.persistence_owner_ckey != account) continue
		if(found) return null
		found = H
	if(!found || found.client || found.key || found.stat == DEAD || !get_turf(found)) return null
	return found

// Hands a waiting body to its player if they are already in the lobby.
/proc/region_travel_offer(mob/living/human/H)
	for(var/client/C in clients)
		if(C.ckey == H.persistence_owner_ckey && istype(C.mob, /mob/new_player))
			region_travel_claim(C.mob)
			return

/proc/region_travel_claim(mob/new_player/lobby)
	if(!lobby || !lobby.client || lobby.client.mob != lobby || IsGuestKey(lobby.client.key)) return FALSE
	var/client/C = lobby.client
	if(C.quickBan_isbanned("Playing") || C.quickBan_isbanned("Server")) return FALSE
	var/mob/living/human/H = region_travel_waiting_body(C.ckey)
	if(!H) return FALSE
	lobby.spawning = TRUE
	lobby.close_spawn_windows()
	H.region_arrival_pending = FALSE
	H.key = C.key
	if(C.mob != H)
		H.region_arrival_pending = TRUE
		lobby.spawning = FALSE
		return FALSE
	H.record_persistence_owner()
	to_chat(H, SPAN_NOTICE("You arrive in [shard_group.enabled ? shard_group.name : "a new land"]."))
	qdel(lobby)
	return TRUE

/mob/new_player/Login()
	. = ..()
	if(!QDELETED(src) && client && client.mob == src)
		region_travel_claim(src)

// A world that starts with no save at all never runs the load hook, so the
// bridge reconciles it as an empty, unsaved world here. A world with any save
// waits for that save's load (or an operator) instead.
/hook/roundstart/proc/region_travel_fresh_world()
	if(transfer_bridge.enabled() && isnull(transfer_bridge.loaded_capture) && !fexists("map_saves/map.txt"))
		transfer_bridge.loaded(null)
	return TRUE

// -- the gate -------------------------------------------------------------

/obj/structure/region_gate
	name = "trail to distant lands"
	desc = "A worn trail leading beyond the edge of the known world."
	icon = 'icons/obj/structures.dmi'
	icon_state = "propstall1"
	density = FALSE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	map_storage_saved_vars = "icon_state;dir;name;pixel_x;pixel_y;destination"
	// Region id of the peer this trail leads to (shard_region.json).
	var/destination = null
	var/busy = FALSE

/obj/structure/region_gate/New()
	..()
	region_gates |= src

/obj/structure/region_gate/Destroy()
	region_gates -= src
	return ..()

/obj/structure/region_gate/proc/destination_name()
	var/list/peer = shard_group.enabled ? shard_group.peers[destination] : null
	return peer ? peer["name"] : destination

// Null when the trail can be used now, otherwise why not.
/obj/structure/region_gate/proc/closed_reason()
	if(!destination || !transfer_bridge.ready() || !(destination in transfer_bridge.peers) || !shard_group.enabled)
		return "The trail is overgrown. It leads nowhere for now."
	var/list/peer = shard_group.peers[destination]
	if(!peer || peer["state"] != "UP")
		return "Nobody seems to be coming back from [destination_name()] right now."
	if(busy || persistence_save_active())
		return "The trail is busy. Try again in a moment."
	return null

/obj/structure/region_gate/examine(mob/user)
	..()
	var/reason = closed_reason()
	to_chat(user, SPAN_NOTICE(reason ? reason : "It leads to [destination_name()]. Use it to travel there with what you wear and carry."))

/obj/structure/region_gate/attack_hand(mob/living/human/user)
	if(!istype(user) || !user.client) return ..()
	travel(user)

/obj/structure/region_gate/proc/travel_refusal(mob/living/human/H)
	var/reason = closed_reason()
	if(reason) return reason
	if(!H.client || IsGuestKey(H.client.key)) return "Only players with a BYOND account can travel."
	if(H.stat != CONSCIOUS || H.restrained() || H.buckled || H.pulling || !Adjacent(H)) return "You can't set off right now."
	if(H.health < H.maxHealth) return "You are too hurt to make the journey."
	return null

/obj/structure/region_gate/proc/travel(mob/living/human/H)
	var/reason = travel_refusal(H)
	if(reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/list/items = H.region_travel_items()
	if(istext(items))
		to_chat(H, SPAN_WARNING(items))
		return
	if(alert(H, "Travel to [destination_name()]? You leave this land with what you wear and carry, and continue there.", "Travel", "Travel", "Stay") != "Travel")
		return
	// The prompt slept: check everything again.
	reason = travel_refusal(H)
	if(!reason)
		items = H.region_travel_items()
		if(istext(items)) reason = items
	if(reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	H.record_persistence_owner()
	var/result = depart(H)
	if(result != "departed")
		to_chat(H, SPAN_WARNING(result))

// Sends a character whose owner is recorded. Returns "departed" or a reason.
// Players reach this through travel(); a host agent can call it for a test
// character that has persistence_owner_ckey set.
/obj/structure/region_gate/proc/depart(mob/living/human/H)
	var/reason = closed_reason()
	if(reason) return reason
	if(!istype(H) || QDELETED(H) || H.loc != loc && !Adjacent(H)) return "You are too far from the trail."
	if(!H.persistence_owner_ckey) return "Only players with a BYOND account can travel."
	var/list/items = H.region_travel_items()
	if(istext(items)) return items
	var/client/C = H.client
	var/payload = H.region_travel_payload(items)
	if(length(payload) > REGION_TRAVEL_PAYLOAD_MAX) return "You carry too much to travel."
	// The destination decodes with the same rules; never escrow what it would drop.
	if(!region_travel_decode(payload)) return "Something about you cannot make the journey. Ask an admin."
	var/address = shard_group.peers[destination]["address"]
	// Hold the body and its items while the agent records the escrow, so
	// neither can change.
	busy = TRUE
	var/turf/start = get_turf(src)
	H.forceMove(src)
	var/list/result = transfer_bridge.begin_escrow(destination, list(payload))
	busy = FALSE
	if(!result)
		H.forceMove(start)
		return "The trail is busy. Try again in a moment."
	// Recorded: remove the traveller now, without sleeping.
	log_game("Region travel: [H.persistence_owner_ckey]'s character [H.real_name] left for [destination].")
	// Delete everything the traveller holds now, not only what was listed: the
	// payload carries the full amounts, so a stack split during the request
	// must not survive.
	for(var/slot_name in items)
		qdel(items[slot_name])
	for(var/obj/item/I in H.GetAllContents())
		if(!istype(I, /obj/item/organ) && !QDELETED(I)) qdel(I)
	for(var/obj/item/I in contents)
		qdel(I)
	if(C)
		var/mob/new_player/lobby = new
		lobby.key = C.key
		to_chat(C, SPAN_NOTICE("You set off for [destination_name()]. Join it to continue; if your character cannot be taken in there, you will find them back here."))
		C << link("byond://[address]")
	qdel(H)
	shard_group.request_save_soon()
	return "departed"

/obj/structure/region_gate/attack_ghost(mob/user)
	return

#undef REGION_TRAVEL_PAYLOAD_MAX
#undef REGION_TRAVEL_ITEMS_MAX
