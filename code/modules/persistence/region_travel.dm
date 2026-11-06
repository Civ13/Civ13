// Region travel: moves a player's character, with simple belongings, to a peer
// region of the same group (shard_group.dm) through the transfer agent
// (transfer_bridge.dm). Inert unless the bridge is on and the gate's
// destination is one of its peers.
//
// The character travels as a payload: identity, looks, skills, hunger and
// thirst, and a list of items that can be rebuilt exactly (allowlisted stacks
// by kind and amount, untouched items of the carry families by type, magazines
// by round count; see region_travel_item_kind). Anything else must be
// left behind first, so nothing is lost or copied on the way. While the agent
// records the escrow the body and its items wait inside the gate; once it is
// recorded they are removed and the player is sent to the destination server.
// The destination builds the body at a gate or a late-join point, owned by the
// player's key, and hands it over when that key logs in. A refused transfer
// comes back the same way at the source. Trips are journaled by the agent, so
// they complete in seconds; a world that reloads an older save replays them.

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

// Medical stacks travel by kind and amount, like materials. Exact types only.
var/global/list/region_travel_stack_goods = list(
	"bruise_pack" = /obj/item/stack/medical/bruise_pack,
	"gauze" = /obj/item/stack/medical/bruise_pack/gauze,
	"advanced_bruise_pack" = /obj/item/stack/medical/advanced/bruise_pack,
	"advanced_ointment" = /obj/item/stack/medical/advanced/ointment,
	"splint" = /obj/item/stack/medical/splint)

// Item families that travel by type besides clothing: packaged food and
// medicine (only untouched, see region_travel_item_pristine), common tools and
// unloaded projectile guns. Magazines travel as "ammo:<type>" with a round count.
var/global/list/region_travel_carry_types = list(
	/obj/item/weapon/reagent_containers/food/snacks,
	/obj/item/weapon/reagent_containers/food/drinks/can,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/plastic,
	/obj/item/weapon/reagent_containers/syringe,
	/obj/item/weapon/reagent_containers/pill,
	/obj/item/weapon/crowbar,
	/obj/item/weapon/wrench,
	/obj/item/weapon/screwdriver,
	/obj/item/weapon/wirecutters,
	/obj/item/weapon/weldingtool,
	/obj/item/weapon/hammer,
	/obj/item/weapon/gun/projectile)

// How an item travels: "stack:<kind>" for an allowlisted stack, "ammo:<type>"
// for a magazine of its own rounds, "type" for an empty item of an allowed
// family, or null when it cannot travel.
/proc/region_travel_item_kind(obj/item/I)
	if(!istype(I)) return null
	if(istype(I, /obj/item/stack))
		var/kind = transfer_trade_kind(I)
		if(kind) return "stack:[kind]"
		for(var/coin in region_travel_coins)
			if(istype(I, region_travel_coins[coin])) return "stack:[coin]"
		for(var/good in region_travel_stack_goods)
			if(I.type == region_travel_stack_goods[good]) return "stack:[good]"
		return null
	if(istype(I, /obj/item/ammo_magazine))
		return isnull(region_travel_ammo_count(I)) ? null : "ammo:[I.type]"
	if(region_travel_type_allowed(I.type) && !length(I.contents) && region_travel_item_pristine(I))
		return "type"
	return null

/proc/region_travel_type_allowed(path)
	if(ispath(path, /obj/item/clothing))
		// Clothing that stores things carries state that does not travel.
		return !ispath(path, /obj/item/clothing/accessory/storage)
	for(var/family in region_travel_carry_types)
		if(ispath(path, family)) return TRUE
	return FALSE

// An item rebuilds from its type alone, so it must be as a new one would be:
// food not bitten, and no reagent container holding more or less (or other
// reagents) than a fresh one. Anything else of an allowed family keeps no
// travelling state.
/proc/region_travel_item_pristine(obj/item/I)
	if(!istype(I, /obj/item/weapon/reagent_containers))
		return TRUE
	if(istype(I, /obj/item/weapon/reagent_containers/food/snacks))
		var/obj/item/weapon/reagent_containers/food/snacks/F = I
		if(F.bitecount) return FALSE
	var/obj/item/fresh = new I.type(null)
	. = region_travel_same_reagents(I.reagents, fresh.reagents)
	qdel(fresh)

/proc/region_travel_same_reagents(datum/reagents/A, datum/reagents/B)
	if(!A || !B) return !A && !B
	if(A.reagent_list.len != B.reagent_list.len) return FALSE
	for(var/datum/reagent/R in A.reagent_list)
		if(abs(R.volume - B.get_reagent_amount(R.id)) > 0.01) return FALSE
	return TRUE

// Rounds a magazine holds, or null when it holds anything but live rounds of
// its own ammo type.
/proc/region_travel_ammo_count(obj/item/ammo_magazine/M)
	if(!istype(M) || !M.ammo_type) return null
	. = 0
	for(var/atom/movable/A in M.contents)
		var/obj/item/ammo_casing/C = A
		if(!istype(C) || C.type != M.ammo_type || !C.BB || length(C.contents) > 1) return null
		.++
	if(. != length(M.stored_ammo) || . > M.max_ammo) return null

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

/mob/living/human/proc/region_travel_payload(list/items, party = null, raid = FALSE, list/extra = null)
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
		else if(copytext(kind, 1, 6) == "ammo:")
			carried += list(list(slot_name, kind, region_travel_ammo_count(I)))
		else
			var/obj/item/stack/S = I
			carried += list(list(slot_name, kind, S.amount))
	var/list/P = list("v" = 1, "kind" = "character", "owner" = persistence_owner_ckey, "name" = real_name,
		"gender" = gender, "age" = age, "look" = look, "skills" = skills,
		"nutrition" = clamp(round(nutrition), 0, 1000), "water" = clamp(round(water), 0, 1000), "items" = carried)
	// Wounds travel as overall damage, so a trip never heals (raid exits let
	// hurt raiders leave; other gates still ask for full health).
	var/brute = clamp(round(getBruteLoss()), 0, 200)
	var/burn = clamp(round(getBurnLoss()), 0, 200)
	if(brute) P["brute"] = brute
	if(burn) P["burn"] = burn
	// A party train trip (party_train.dm) says whose train it is and where it left from.
	if(party)
		P["party"] = party
		P["from"] = shard_group.region
	// A raid trip (region_raid.dm) says where the raider goes home to.
	else if(raid)
		P["from"] = shard_group.region
	// A crewed flight (space/lander.dm) says which lander and where it lands.
	for(var/key in extra)
		if(key in list("lander", "landing", "surveyed", "rough", "return", "cargo"))
			P[key] = extra[key]
	return json_encode(P)

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
	for(var/field in list("brute", "burn"))
		if(!isnull(P[field]) && (!isnum(P[field]) || P[field] < 0 || P[field] > 200)) return null
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
	if(!isnull(P["party"]) && !party_train_valid_party(P["party"])) return null
	// A solo party is only ever its own player's.
	if(istext(P["party"]) && findtext(P["party"], "ckey:") == 1 && P["party"] != "ckey:[owner]") return null
	if(!isnull(P["from"]) && (!istext(P["from"]) || length(P["from"]) > 32)) return null
	if(!space_flight_payload_ok(P)) return null
	return P

// The path an item entry rebuilds, or null when it is not allowed.
/proc/region_travel_item_path(kind, amount)
	if(copytext(kind, 1, 7) == "stack:")
		var/good = copytext(kind, 7)
		var/obj/item/stack/path = transfer_trade_goods[good] || region_travel_coins[good] || region_travel_stack_goods[good]
		if(!path || amount < 1 || amount != round(amount) || amount > min(2000, initial(path.max_amount))) return null
		return path
	if(copytext(kind, 1, 6) == "ammo:")
		var/obj/item/ammo_magazine/magazine = text2path(copytext(kind, 6))
		if(!ispath(magazine, /obj/item/ammo_magazine) || !initial(magazine.ammo_type)) return null
		if(amount < 0 || amount != round(amount) || amount > initial(magazine.max_ammo)) return null
		return magazine
	var/path = text2path(kind)
	if(!path || amount != 1 || !region_travel_type_allowed(path)) return null
	return path

/proc/region_travel_arrival_turf()
	// A generated zombie city has its own entry points (zombie_city/world.dm).
	var/turf/city = zombie_city_arrival_turf()
	if(city) return city
	// Admin gates first, then other gates that take arrivals (approved trails).
	for(var/obj/structure/region_gate/gate in region_gates)
		if(gate.type == /obj/structure/region_gate && !QDELETED(gate) && isturf(gate.loc)) return gate.loc
	for(var/obj/structure/region_gate/gate in region_gates)
		if(gate.accepts_arrivals() && !QDELETED(gate) && isturf(gate.loc)) return gate.loc
	var/list/starts = latejoin_turfs ? latejoin_turfs["JoinLateCiv"] : null
	if(length(starts)) return pick(starts)
	return null

// Builds recorded characters at T: arrivals at the destination, or travellers
// a peer refused back at the source. Callers have already recorded the effect,
// so this never refuses; an unreadable payload is reported and dropped.
/proc/region_travel_arrive(list/payloads, incoming, turf/T, replayed = FALSE)
	if(!islist(payloads)) return
	if(!isturf(T) || QDELETED(T)) T = region_travel_arrival_turf()
	if(!isturf(T)) T = locate(1, 1, 1)
	for(var/payload in payloads)
		var/list/P = region_travel_decode(payload)
		if(!P)
			message_admins("Region travel: an unreadable [incoming ? "arriving" : "returned"] character was dropped.")
			continue
		// A party train trip arrives at the party's berth or station instead.
		// A crewed flight arrives in its landed lander (space/lander.dm).
		var/turf/at = space_flight_arrival_turf(P, incoming) || party_train_arrival_turf(P) || T
		var/mob/living/human/H = region_travel_build(P, at)
		space_flight_arrived(H, P, incoming)
		// A recorded trip (or a refused one coming back) makes this land the home.
		// A journal replay after a reload already told the coordinator once;
		// saying it again could pull the home back from a later trip.
		if(!replayed)
			spawn(0)
				region_home_note(P["owner"], "arrive")
		log_game("Region travel: [P["owner"]]'s character [H.real_name] [incoming ? "arrived" : "came back"] at [at.x],[at.y],[at.z].")
		region_travel_offer(H)

// Replays a departure the loaded save does not hold yet: the account's body
// here is the one that left (one durable body per account), so it goes again,
// with what it carries. A player already back in it is sent to the lobby.
/proc/region_travel_replay_departure(list/payloads)
	for(var/payload in payloads)
		var/list/P = region_travel_decode(payload)
		if(!P)
			message_admins("Region travel: an unreadable departure could not be replayed.")
			continue
		for(var/mob/living/human/H in human_mob_list.Copy())
			if(H.persistence_owner_ckey != P["owner"] || QDELETED(H)) continue
			log_game("Region travel: replayed [P["owner"]]'s departure; [H.real_name] leaves again.")
			if(H.client)
				var/client/C = H.client
				var/mob/new_player/lobby = new
				lobby.key = C.key
				to_chat(C, SPAN_NOTICE("Your character already left for another land. Join it there."))
			// Only what the traveller took goes with them again. Anything else
			// the reloaded body holds (picked up after the reload, before this
			// replay) existed in the save elsewhere, so it is dropped here.
			var/list/took = list()
			for(var/list/entry in P["items"])
				var/obj/item/I = H.get_equipped_item(region_travel_slots[entry[1]])
				if(I && !(I in took) && (region_travel_item_kind(I) == "type" ? "[I.type]" == entry[2] : region_travel_item_kind(I) == entry[2]))
					took += I
			var/turf/T = get_turf(H)
			for(var/obj/item/I in H.contents)
				if(istype(I, /obj/item/organ) || QDELETED(I)) continue
				if(I in took)
					qdel(I)
				else if(T)
					H.drop_from_inventory(I, T)
			space_flight_replayed(H, P)
			qdel(H)

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
	var/brute = P["brute"] || 0
	var/burn = P["burn"] || 0
	// Spread over the body differently than before, so never let it kill.
	if(brute + burn > 90)
		var/scale = 90 / (brute + burn)
		brute = round(brute * scale)
		burn = round(burn * scale)
	if(brute || burn)
		H.take_overall_damage(brute, burn, "travel")
	for(var/list/entry in P["items"])
		var/path = region_travel_item_path(entry[2], entry[3])
		var/obj/item/I = ispath(path, /obj/item/stack) ? new path(T, entry[3]) : new path(T)
		if(istype(I, /obj/item/ammo_magazine))
			region_travel_fill_magazine(I, entry[3])
		else if(istype(I, /obj/item/weapon/gun/projectile))
			region_travel_unload_gun(I)
		if(!H.equip_to_slot_if_possible(I, region_travel_slots[entry[1]], FALSE, TRUE))
			I.forceMove(T)
	// One durable body per account: an older clientless body here gives up its
	// claim, as record_persistence_owner() does, or every save would refuse.
	for(var/mob/living/human/other in human_mob_list)
		if(other != H && !other.client && other.persistence_owner_ckey == P["owner"])
			other.persistence_owner_ckey = null
			log_game("Region travel: [P["owner"]]'s earlier body [other.real_name] gave up its claim to the arrival.")
	H.persistence_owner_ckey = P["owner"]
	if(istext(P["party"]))
		H.party_train_party = P["party"]
		party_train_restore_faction(H, P["party"])
	region_raid_note_origin(H, P)
	H.region_arrival_pending = TRUE
	H.update_hair(FALSE)
	H.update_body(FALSE)
	H.regenerate_icons()
	return H

// A rebuilt magazine holds exactly the rounds that travelled.
/proc/region_travel_fill_magazine(obj/item/ammo_magazine/M, rounds)
	while(M.stored_ammo.len > rounds)
		var/obj/item/ammo_casing/C = M.stored_ammo[M.stored_ammo.len]
		M.stored_ammo.len--
		qdel(C)
	while(M.stored_ammo.len < rounds)
		M.stored_ammo += new M.ammo_type(M)
	M.update_icon()

// Guns travel unloaded; a new one comes preloaded, so empty it again.
/proc/region_travel_unload_gun(obj/item/weapon/gun/projectile/G)
	G.ammo_magazine = null
	G.chambered = null
	G.loaded.Cut()
	for(var/atom/movable/A in G.contents)
		qdel(A)
	G.update_icon()

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
			var/mob/new_player/lobby = C.mob
			spawn(0) // the claim may wait for the home world decision
				region_travel_claim(lobby)
			return

/proc/region_travel_claim(mob/new_player/lobby, wait = TRUE)
	if(!lobby || !lobby.client || lobby.client.mob != lobby || IsGuestKey(lobby.client.key)) return FALSE
	var/client/C = lobby.client
	if(C.quickBan_isbanned("Playing") || C.quickBan_isbanned("Server")) return FALSE
	var/mob/living/human/H = region_travel_waiting_body(C.ckey)
	if(!H) return FALSE
	// The arrival was recorded as this land becoming the home; wait for the
	// coordinator's next pass to decide it.
	if(!region_home_admit(lobby, wait) || lobby.client != C || C.mob != lobby || H != region_travel_waiting_body(C.ckey)) return FALSE
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
		spawn(0)
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
	// A traveller waiting inside during an escrow must not be deleted with it.
	var/turf/T = get_turf(src)
	for(var/mob/M in contents)
		M.forceMove(T)
	return ..()

/obj/structure/region_gate/proc/accepts_arrivals()
	return TRUE

// The party train a trip through this gate belongs to (party_train.dm), if any.
/obj/structure/region_gate/proc/travel_party(mob/living/human/H)
	return null

// Extra payload fields for a trip through this gate (a crewed flight), or null.
/obj/structure/region_gate/proc/travel_extra(mob/living/human/H)
	return null

/obj/structure/region_gate/proc/destination_name()
	var/list/peer = shard_group.enabled ? shard_group.peers[destination] : null
	return peer ? peer["name"] : destination

// Null when the trail can be used now, otherwise why not.
/obj/structure/region_gate/proc/closed_reason()
	if(!destination || !transfer_bridge.ready() || !(destination in transfer_bridge.peers) || !shard_group.enabled)
		return "The trail is overgrown. It leads nowhere for now."
	var/list/peer = shard_group.peers[destination]
	// A sleeping region is woken when someone sets off (travel()).
	if(!peer || peer["state"] != "UP" && !shard_group.peer_wakeable(destination))
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
	// A sleeping destination is woken first; the wait can be minutes, so check again after.
	if(shard_group.peers[destination]["state"] != "UP")
		reason = shard_group.wake_peer(destination, H)
		if(!reason)
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
	// The traveller is sent to the destination at once, so it must be awake (travel() wakes it).
	var/expected = destination
	if(shard_group.peers[destination]["state"] != "UP" && !shard_group.poll_peer(destination))
		return "[destination_name()] is asleep. Use the trail to wake it."
	// The poll can wait; an admin may have repointed or closed the trail meanwhile.
	if(QDELETED(src) || destination != expected || closed_reason())
		return "The trail changed. Try again."
	var/list/items = H.region_travel_items()
	if(istext(items)) return items
	var/client/C = H.client
	var/payload = H.region_travel_payload(items, travel_party(H), region_raid_peer(destination), travel_extra(H))
	if(length(payload) > REGION_TRAVEL_PAYLOAD_MAX) return "You carry too much to travel."
	// The destination decodes with the same rules; never escrow what it would drop.
	if(!region_travel_decode(payload)) return "Something about you cannot make the journey. Ask an admin."
	var/address = shard_group.peers[destination]["address"]
	// Hold the body and its items while the agent records the escrow, so
	// neither can change.
	busy = TRUE
	var/turf/start = get_turf(src)
	H.forceMove(src)
	var/list/result = transfer_bridge.begin_escrow(destination, list(payload), TRUE)
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
	var/account = H.persistence_owner_ckey
	qdel(H)
	shard_group.request_save_soon()
	spawn(0)
		region_home_note(account, "depart", destination)
	return "departed"

/obj/structure/region_gate/attack_ghost(mob/user)
	return

#undef REGION_TRAVEL_PAYLOAD_MAX
#undef REGION_TRAVEL_ITEMS_MAX
