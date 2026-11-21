// Region travel: moves a player's character, with simple belongings, to a peer
// region of the same group (shard_group.dm) through the transfer agent
// (transfer_bridge.dm). Inert unless the bridge is on and the gate's
// destination is one of its peers.
//
// The character travels as a payload: identity, looks, skills, hunger and
// thirst, and a list of items that can be rebuilt exactly (allowlisted stacks
// by kind and amount, untouched items of the carry families by type, magazines
// by round count; see region_travel_item_kind; worn material tools and
// weapons and filled bags: region_travel_gear.dm). Anything else must be
// left behind first, so nothing is lost or copied on the way. While the agent
// records the escrow the body and its items wait inside the gate; once it is
// recorded they are removed and the player is sent to the destination server.
// The destination builds the body at a gate or a late-join point, owned by the
// player's key, and hands it over when that key logs in. A refused transfer
// comes back the same way at the source. Trips are journaled by the agent, so
// they complete in seconds; a world that reloads an older save replays them.

#define REGION_TRAVEL_PAYLOAD_MAX 131072
// A crossing ship's record rides with one crew member (naval/ship_crossing.dm).
#define REGION_TRAVEL_SHIP_PAYLOAD_MAX 393216
#define REGION_TRAVEL_ITEMS_MAX 40

var/global/list/region_gates = list()

// Saved: a body that arrived and has not been claimed yet.
/mob/living/human/var/region_arrival_pending = FALSE

var/global/list/region_travel_slots = list(
	"back" = slot_back, "mask" = slot_wear_mask, "belt" = slot_belt, "id" = slot_wear_id,
	"l_ear" = slot_l_ear, "r_ear" = slot_r_ear, "eyes" = slot_eyes, "gloves" = slot_gloves,
	"head" = slot_head, "shoes" = slot_shoes, "suit" = slot_wear_suit, "uniform" = slot_w_uniform,
	"l_store" = slot_l_store, "r_store" = slot_r_store,
	"l_hand" = slot_l_hand, "r_hand" = slot_r_hand, "shoulder" = slot_shoulder)

// Coins travel by kind and amount; preset-amount subtypes rebuild as the base.
var/global/list/region_travel_coins = list(
	"copper_coin" = /obj/item/stack/money/coppercoin,
	"silver_coin" = /obj/item/stack/money/silvercoin,
	"gold_coin" = /obj/item/stack/money/goldcoin)

var/global/list/region_travel_look_vars = list("r_hair", "g_hair", "b_hair", "h_style", "r_facial", "g_facial", "b_facial", "f_style", "h_growth", "f_growth", "r_eyes", "g_eyes", "b_eyes", "s_tone", "r_skin", "g_skin", "b_skin")

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
	if(istype(I, /obj/item/weapon/book/node_compendium))
		var/obj/item/weapon/book/node_compendium/C = I
		var/kind = "compendium:[json_encode(C.node_ids)]"
		// Only the subjects travel, so a manual with notes written in it stays.
		return !length(C.contents) && !C.dat && recipe_compendium_wire_ids(kind) ? kind : null
	if(istype(I, /obj/item/weapon/book/node_book))
		var/obj/item/weapon/book/node_book/B = I
		return valid_recipe_node_id(B.node_id) && !length(B.contents) && !B.dat ? "node:[B.node_id]" : null
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
	var/list/known = list()
	for(var/slot_name in region_travel_slots)
		var/obj/item/I = get_equipped_item(region_travel_slots[slot_name])
		if(!I) continue
		if(!region_travel_worn_kind(I))
			// A bag is named with what in it has to come out first.
			var/list/inside = istype(I, /obj/item/weapon/storage) ? region_travel_bag_blockers(I) : null
			refused += length(inside) ? "[I.name] (take out [english_list(inside)])" : I.name
			known += I
			continue
		items[slot_name] = I
	// Anything else on the body (cuffs, grabs, items in odd slots) blocks travel.
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
		var/kind = region_travel_worn_kind(I)
		if(kind == "type")
			carried += list(list(slot_name, "[I.type]", 1))
		else if(copytext(kind, 1, 6) == "node:" || copytext(kind, 1, 12) == "compendium:" || copytext(kind, 1, 6) == "gear:" || copytext(kind, 1, 7) == "round:" || copytext(kind, 1, 5) == "bag:" || copytext(kind, 1, 6) == "item:")
			carried += list(list(slot_name, kind, 1))
		else if(copytext(kind, 1, 6) == "ammo:")
			carried += list(list(slot_name, kind, region_travel_ammo_count(I)))
		else
			var/obj/item/stack/S = I
			carried += list(list(slot_name, kind, S.amount))
	var/list/P = list("v" = 1, "kind" = "character", "owner" = persistence_owner_ckey, "name" = real_name,
		"gender" = gender, "age" = age, "look" = look, "skills" = skills,
		"nutrition" = clamp(round(nutrition), 0, 1000), "water" = clamp(round(water), 0, 1000), "items" = carried)
	// Version 2 requires knowledge-aware peers. A legacy decoder rejects it
	// rather than accepting a body while silently dropping its knowledge.
	if(recipe_knowledge_initialized || length(known_recipe_nodes) || (map && map.recipe_knowledge_enabled()))
		P["v"] = 2
		P["known_recipe_nodes"] = clean_recipe_node_ids(known_recipe_nodes)
		P["recipe_knowledge_initialized"] = !!recipe_knowledge_initialized
	for(var/list/entry in carried)
		if(copytext(entry[2], 1, 6) == "node:" || copytext(entry[2], 1, 12) == "compendium:")
			P["v"] = max(P["v"], 2)
	// Version 3 adds scholarship (scholarship.dm). A peer without it refuses
	// the trip rather than taking the body and dropping the skill.
	var/list/learned = clean_scholarship(scholarship)
	if(learned.len)
		P["v"] = 3
		P["scholarship"] = learned
	// Chapters read part-way (study_progress.dm) travel too, so a reader
	// continues them in the next region. Optional: absent means none.
	var/list/reading = clean_study_progress(study_progress)
	if(reading.len)
		P["v"] = max(P["v"], 2)
		P["reading"] = reading
	if(P["v"] >= 2 && !("known_recipe_nodes" in P))
		P["known_recipe_nodes"] = list()
		P["recipe_knowledge_initialized"] = !!recipe_knowledge_initialized
	// Chosen traits and the field-of-study state travel too (study_fields.dm).
	var/list/carried_traits = region_travel_traits(traits)
	if(carried_traits.len)
		P["traits"] = carried_traits
	if(study_field_lock > world.realtime)
		P["study_field_lock"] = study_field_lock
	if(trade_lock > world.realtime)
		P["trade_lock"] = trade_lock
	if(study_interest in scholar_disciplines)
		P["study_interest"] = study_interest
	// Former names and the wait for the next change travel too (name_change.dm).
	if(name_history_valid(former_names) && former_names.len)
		P["former_names"] = former_names.Copy()
	if(name_history_valid(name_history) && name_history.len)
		P["name_history"] = name_history.Copy()
	if(name_change_lock > world.realtime)
		P["name_change_lock"] = name_change_lock
	// People and languages travel whole (region_travel_tongues.dm).
	var/list/tongues = region_travel_tongues()
	if(tongues)
		P["tongues"] = tongues
	// The sign they were born under travels too (birth_charts.dm).
	if(birth_chart_valid(birth_chart))
		P["chart"] = birth_chart
	// The martial school, its ranks and hardened hands travel too (martial_schools.dm).
	var/list/martial = martial_travel_record()
	if(martial)
		P["martial"] = martial
	// Accolade progress (accolades.dm): time played, seasons, time in the faction.
	var/list/progress = accolade_progress_clean(accolade_progress)
	if(progress.len)
		P["accolades"] = progress
	// Wounds travel as overall damage, so a trip never heals (raid exits let
	// hurt raiders leave; other gates still ask for full health).
	var/brute = clamp(round(getBruteLoss()), 0, 200)
	var/burn = clamp(round(getBurnLoss()), 0, 200)
	if(brute) P["brute"] = brute
	if(burn) P["burn"] = burn
	// Each limb's wounds, fractures and lost limbs travel as they are, so the
	// body arrives hurt exactly where it was; the totals above stay for older readers.
	var/list/limbs = region_travel_limbs()
	if(limbs.len) P["limbs"] = limbs
	var/tox = clamp(round(getToxLoss()), 0, 200)
	if(tox) P["tox"] = tox
	// Every trip says where it left from: a raid trip (region_raid.dm) goes
	// home there, a party train (party_train.dm) records its way back, and an
	// ordinary traveller arrives at the trail leading back there.
	P["from"] = shard_group.region
	// A party train trip says whose train it is.
	if(party)
		P["party"] = party
	// The traveller's faction, named with the land it was founded in, so its
	// members rejoin it or its colony on arrival (colony_charter.dm).
	var/faction_id = colony_faction_id(src)
	if(faction_id)
		P["faction"] = faction_id
		if(map.is_faction_leader(src, civilization))
			P["faction_leader"] = 1
	// A crewed flight (space/lander.dm) says which lander and where it lands.
	for(var/key in extra)
		if(key in list("lander", "landing", "surveyed", "rough", "return", "orbit", "cargo", "sortie", "seats", "voyage", "ship", "edge", "mount", "led", "cart", "bike", "wagon"))
			P[key] = extra[key]
		// Where an admin chose to land them (region_admin_send.dm).
		else if(key == "admin_send")
			P[key] = extra[key]
		// A plane flying on to another continent (aircraft_crossing.dm).
		else if(key in list("flight", "pilot", "plane"))
			P[key] = extra[key]
	return json_encode(P)

// Returns the decoded payload, or null when any field is out of bounds.
/proc/region_travel_decode(payload)
	if(!istext(payload) || length(payload) > REGION_TRAVEL_SHIP_PAYLOAD_MAX) return null
	var/list/P
	try
		P = json_decode(payload)
	catch
		return null
	if(!islist(P) || !(P["v"] in list(1, 2, 3)) || P["kind"] != "character") return null
	// Only a crossing ship's record makes a payload longer than a character's.
	if(length(payload) > REGION_TRAVEL_PAYLOAD_MAX && !islist(P["ship"]) && !islist(P["plane"])) return null
	if(P["v"] >= 2)
		if(!region_travel_knowledge_valid(P["known_recipe_nodes"]) || !(P["recipe_knowledge_initialized"] in list(FALSE, TRUE))) return null
	else if(("known_recipe_nodes" in P) || ("recipe_knowledge_initialized" in P))
		return null
	if("reading" in P)
		if(P["v"] < 2 || !region_travel_reading_valid(P["reading"])) return null
	if(P["v"] == 3)
		if(!region_travel_scholarship_valid(P["scholarship"])) return null
	else if("scholarship" in P)
		return null
	if(("tongues" in P) && !region_travel_tongues_valid(P["tongues"])) return null
	if(("traits" in P) && !region_travel_traits_valid(P["traits"])) return null
	if(("chart" in P) && !birth_chart_valid(P["chart"])) return null
	if(("martial" in P) && !martial_travel_valid(P["martial"])) return null
	if(("study_field_lock" in P) && !isnum(P["study_field_lock"])) return null
	if(("trade_lock" in P) && !isnum(P["trade_lock"])) return null
	if(("study_interest" in P) && !(P["study_interest"] in scholar_disciplines)) return null
	for(var/field in list("former_names", "name_history"))
		if((field in P) && !name_history_valid(P[field])) return null
	if(("name_change_lock" in P) && !isnum(P["name_change_lock"])) return null
	var/owner = P["owner"]
	if(!persistence_owner_valid(owner) || length(owner) > 32) return null
	if(!istext(P["name"]) || !length(P["name"]) || length(P["name"]) > MAX_NAME_LEN) return null
	if(!(P["gender"] in list(MALE, FEMALE, PLURAL, NEUTER))) return null
	if(!isnum(P["age"]) || P["age"] < 1 || P["age"] > 200) return null
	for(var/field in list("brute", "burn", "tox"))
		if(!isnull(P[field]) && (!isnum(P[field]) || P[field] < 0 || P[field] > 200)) return null
	if(!isnull(P["limbs"]) && !region_travel_limbs_valid(P["limbs"])) return null
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
		if(P["v"] == 1 && (copytext(entry[2], 1, 6) == "node:" || copytext(entry[2], 1, 12) == "compendium:")) return null
		if(!region_travel_worn_valid(entry[2], entry[3])) return null
	if(!isnull(P["party"]) && !party_train_valid_party(P["party"])) return null
	// A solo party is only ever its own player's.
	if(istext(P["party"]) && findtext(P["party"], "ckey:") == 1 && P["party"] != "ckey:[owner]") return null
	if(!isnull(P["from"]) && (!istext(P["from"]) || length(P["from"]) > 32)) return null
	if(!isnull(P["faction"]) && !colony_parent_valid(P["faction"])) return null
	if(!isnull(P["faction_leader"]) && P["faction_leader"] != 1) return null
	if(!space_flight_payload_ok(P)) return null
	if(!sea_crossing_payload_ok(P)) return null
	if(!air_crossing_payload_ok(P)) return null
	if(!region_edge_payload_ok(P)) return null
	if(!region_admin_send_payload_ok(P)) return null
	return P

// Strict travel admission never silently drops IDs that a destination cannot
// understand. The existing payload byte bound also limits total wire size.
/proc/region_travel_knowledge_valid(value)
	if(!islist(value) || length(value) > length(research_nodes)) return FALSE
	var/list/seen = list()
	for(var/id in value)
		if(!valid_recipe_node_id(id) || (id in seen) || !isnull(value[id])) return FALSE
		seen += id
	return TRUE

// Scholarship travels exactly: known disciplines with levels in 0-100 only.
/proc/region_travel_scholarship_valid(value)
	if(!islist(value) || !length(value)) return FALSE
	var/list/clean = clean_scholarship(value)
	if(clean.len != length(value)) return FALSE
	for(var/discipline in value)
		if(value[discipline] != clean[discipline]) return FALSE
	return TRUE

// Traits travel when every entry is a known trait, once each.
/proc/region_travel_traits(list/value)
	. = list()
	if(!islist(value)) return
	for(var/name in value)
		if(istext(name) && (name in trait_list) && !(name in .))
			. += name

/proc/region_travel_traits_valid(value)
	if(!islist(value) || !length(value) || length(value) > length(trait_list)) return FALSE
	var/list/clean = region_travel_traits(value)
	return clean.len == length(value)

// Partial reading travels exactly: valid node ids with fractions in (0, 1).
/proc/region_travel_reading_valid(value)
	if(!islist(value) || !length(value) || length(value) > length(research_nodes)) return FALSE
	var/list/clean = clean_study_progress(value)
	if(clean.len != length(value)) return FALSE
	for(var/id in value)
		if(abs(value[id] - clean[id]) > 0.001) return FALSE
	return TRUE

// The path an item entry rebuilds, or null when it is not allowed.
/proc/region_travel_item_path(kind, amount)
	if(copytext(kind, 1, 12) == "compendium:")
		return amount == 1 && recipe_compendium_wire_ids(kind) ? /obj/item/weapon/book/node_compendium : null
	if(copytext(kind, 1, 6) == "node:")
		return amount == 1 && valid_recipe_node_id(copytext(kind, 6)) ? /obj/item/weapon/book/node_book : null
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

// The trail here leading back to the land a traveller came from, so a trail
// placed on each side connects the two. Null when there is none.
/proc/region_travel_return_trail_turf(list/P)
	var/from = islist(P) ? P["from"] : null
	if(!istext(from) || !shard_group.enabled || from == shard_group.region) return null
	for(var/obj/structure/region_gate/gate in region_gates)
		if(gate.destination == from && gate.accepts_arrivals() && !QDELETED(gate) && isturf(gate.loc)) return gate.loc
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
		// Otherwise a traveller comes out at the trail here that leads back home.
		// A ship's crew arrive aboard her (naval/ship_crossing.dm).
		// A walker over a shared map edge comes out on the facing edge (region_edge.dm).
		// Someone an admin sent lands where the admin chose (region_admin_send.dm).
		var/turf/at = space_flight_arrival_turf(P, incoming) || sea_crossing_arrival_turf(P, incoming) || air_crossing_arrival_turf(P, incoming) || region_admin_send_arrival_turf(P, incoming) || party_train_arrival_turf(P) || region_edge_arrival_turf(P, incoming) || (incoming ? region_travel_return_trail_turf(P) : null) || T
		var/mob/living/human/H = region_travel_build(P, at)
		space_flight_arrived(H, P, incoming)
		sea_crossing_arrived(H, P, incoming)
		air_crossing_arrived(H, P, incoming)
		region_edge_arrived(H, P, incoming)
		region_admin_send_arrived(H, P, incoming, get_turf(H) || at)
		// A recorded trip (or a refused one coming back) makes this land the home.
		// A journal replay after a reload already told the coordinator once;
		// saying it again could pull the home back from a later trip.
		if(!replayed)
			spawn(0)
				region_home_note(P["owner"], "arrive")
		log_game("Region travel: [P["owner"]]'s character [H.real_name] [incoming ? "arrived" : "came back"] at [at.x],[at.y],[at.z].")
		if(!replayed)
			player_activity.arrive(P, incoming)
			accolade_note_land(accolade_account_ckey(P["owner"]))
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
				if(I && !(I in took) && region_travel_worn_matches(I, entry[2]))
					took += I
			var/turf/T = get_turf(H)
			for(var/obj/item/I in H.contents)
				if(istype(I, /obj/item/organ) || QDELETED(I)) continue
				if(I in took)
					qdel(I)
				else if(T)
					H.drop_from_inventory(I, T)
			space_flight_replayed(H, P)
			sea_crossing_replayed(H, P)
			region_edge_replayed(H, P)
			qdel(H)

/proc/region_travel_build(list/P, turf/T)
	var/mob/living/human/H = new /mob/living/human(T)
	// Keeps nomads_spawn from rolling a new identity half a second from now.
	H.persistence_restored = TRUE
	// Do not relearn through the destination research ceiling: ownership of
	// knowledge survives travel, while crafting still checks that ceiling.
	H.known_recipe_nodes = P["v"] >= 2 ? P["known_recipe_nodes"].Copy() : list()
	H.recipe_knowledge_initialized = P["v"] >= 2 ? P["recipe_knowledge_initialized"] : FALSE
	H.scholarship = P["v"] == 3 ? clean_scholarship(P["scholarship"]) : list()
	H.study_progress = clean_study_progress(P["reading"])
	H.region_travel_restore_tongues(P["tongues"])
	if(islist(P["traits"]))
		H.traits = P["traits"].Copy()
		H.traits_dirty = TRUE
	if(birth_chart_valid(P["chart"]))
		H.birth_chart = P["chart"]
	if(islist(P["martial"]))
		H.martial_travel_restore(P["martial"])
	var/list/progress = accolade_progress_clean(P["accolades"])
	if(progress.len)
		H.accolade_progress = progress
	if(isnum(P["study_field_lock"]))
		H.study_field_lock = P["study_field_lock"]
	if(isnum(P["trade_lock"]))
		H.trade_lock = P["trade_lock"]
	if(P["study_interest"] in scholar_disciplines)
		H.study_interest = P["study_interest"]
	if(islist(P["former_names"]))
		H.former_names = P["former_names"].Copy()
	if(islist(P["name_history"]))
		H.name_history = P["name_history"].Copy()
	if(isnum(P["name_change_lock"]))
		H.name_change_lock = P["name_change_lock"]
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
	if(islist(P["limbs"]))
		H.region_travel_restore_limbs(P["limbs"])
	else
		var/brute = P["brute"] || 0
		var/burn = P["burn"] || 0
		// Spread over the body differently than before, so never let it kill.
		if(brute + burn > 90)
			var/scale = 90 / (brute + burn)
			brute = round(brute * scale)
			burn = round(burn * scale)
		if(brute || burn)
			H.take_overall_damage(brute, burn, FALSE, FALSE, "travel")
	if(P["tox"])
		H.setToxLoss(P["tox"])
	// Dressed from the skin out: a uniform goes on before a suit over it, and
	// what still does not fit (an ID or belt needs the uniform) is tried again
	// once everything else is on.
	var/list/dressing = list()
	for(var/list/entry in P["items"])
		if(entry[1] == "uniform")
			dressing.Insert(1, list(entry))
		else
			dressing += list(entry)
	var/list/later = list()
	for(var/list/entry in dressing)
		var/obj/item/I = region_travel_make_worn(entry[2], entry[3], T)
		if(!I) continue
		if(!H.equip_to_slot_if_possible(I, region_travel_slots[entry[1]], FALSE, TRUE))
			later[I] = region_travel_slots[entry[1]]
	for(var/obj/item/I in later)
		if(!H.equip_to_slot_if_possible(I, later[I], FALSE, TRUE))
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
	colony_arrival(H, P)
	// The arrival is a bare body that never ran a job's equip(), so it would
	// lack the Faction verbs (Create/Abandon Faction, Create Religion, ...)
	// until its next save and load. Grant them now, as after_load() does.
	H.restore_role_verbs()
	region_raid_note_origin(H, P)
	H.region_arrival_pending = TRUE
	H.update_hair(FALSE)
	H.update_body(FALSE)
	H.regenerate_icons()
	// Legacy arrivals snapshot once after destination faction restoration, not
	// on a later login or after the research clock has advanced.
	H.finish_character_knowledge_restoration()
	return H

// Makes one item of a travel entry (kind, amount) at T, as it left, the way
// region_travel_build() does for what a traveller wears. Null when the entry
// is not allowed. Used for a crossing ship's hold (naval/ship_crossing.dm).
/proc/region_travel_make_item(kind, amount, turf/T)
	var/path = region_travel_item_path(kind, amount)
	if(!path) return null
	var/obj/item/I = ispath(path, /obj/item/stack) ? new path(T, amount) : new path(T)
	if(istype(I, /obj/item/weapon/book/node_compendium))
		var/obj/item/weapon/book/node_compendium/C = I
		C.node_ids = recipe_compendium_wire_ids(kind)
	else if(istype(I, /obj/item/weapon/book/node_book))
		var/obj/item/weapon/book/node_book/B = I
		B.node_id = copytext(kind, 6)
		B.refresh_node_title()
	else if(istype(I, /obj/item/ammo_magazine))
		region_travel_fill_magazine(I, amount)
	else if(istype(I, /obj/item/weapon/gun/projectile))
		region_travel_unload_gun(I)
	return I

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
	// An account that already has a living character here keeps playing it: a
	// second body (an admin send) waits for an admin and never takes the client
	// when a restart or reconnect passes it through the lobby.
	for(var/mob/living/human/other in human_mob_list)
		if(other != found && other.persistence_owner_ckey == account && other.stat != DEAD && !QDELETED(other) && !other.region_arrival_pending) return null
	return found

// Hands a waiting body to its player if they are already in the lobby.
/proc/region_travel_offer(mob/living/human/H)
	for(var/client/C in clients)
		if(C.owner_key() == H.persistence_owner_ckey && istype(C.mob, /mob/new_player))
			var/mob/new_player/lobby = C.mob
			spawn(0) // the claim may wait for the home world decision
				region_travel_claim(lobby)
			return

/proc/region_travel_claim(mob/new_player/lobby, wait = TRUE)
	if(!lobby || !lobby.client || lobby.client.mob != lobby || IsGuestKey(lobby.client.key)) return FALSE
	var/client/C = lobby.client
	if(C.quickBan_isbanned("Playing") || C.quickBan_isbanned("Server")) return FALSE
	var/mob/living/human/H = region_travel_waiting_body(C.owner_key())
	if(!H) return FALSE
	// The arrival was recorded as this land becoming the home; wait for the
	// coordinator's next pass to decide it.
	if(!region_home_admit(lobby, wait) || lobby.client != C || C.mob != lobby || H != region_travel_waiting_body(C.owner_key())) return FALSE
	lobby.spawning = TRUE
	lobby.close_spawn_windows()
	H.region_arrival_pending = FALSE
	H.key = C.key
	if(C.mob != H)
		H.region_arrival_pending = TRUE
		lobby.spawning = FALSE
		return FALSE
	H.record_persistence_owner()
	H.region_travel_tongue_notes()
	H.note_birth_chart()
	region_admin_send_claimed(H)
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

// TRUE for the hidden gate a crossing ship's crew leave by (naval/ship_crossing.dm).
/obj/structure/region_gate/proc/ship_crossing()
	return FALSE

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
	// Event regions are reached only by an admin's event transfer (region_event.dm).
	if(peer && peer["kind"] == "EVENT")
		return "The trail is overgrown. It leads nowhere for now."
	// Lands across the sea are reached only by ship (expedition_land.dm).
	if(peer && peer["kind"] == "EXPEDITION" && !ship_crossing())
		return "That land lies across the sea. Only a ship can reach it."
	// A sleeping region is woken when someone sets off (travel()). A stopped
	// one stays down until the host starts it again, so the traveller is told
	// so plainly and the admins hear someone is waiting at the trail.
	if(peer && peer["state"] == "STOPPED")
		return "[destination_name()] is closed for now: its land is not running, so the trail cannot take anyone there. It opens again once the land is back."
	// A land whose transfer agent is on hold would refuse the traveller.
	if(shard_group.peer_transfers_held(destination))
		return "[destination_name()] is closed for now: nobody can arrive there until its keepers reopen the way. Ask an admin."
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
	if(!istype(user) || !user.client && !agent_travel_account(user)) return ..()
	travel(user)

/obj/structure/region_gate/proc/travel_refusal(mob/living/human/H)
	var/reason = closed_reason()
	if(reason) return reason
	// An agent's own character travels under its agent account (agent_travel.dm).
	if(H.client ? IsGuestKey(H.client.key) : !agent_travel_account(H)) return "Only players with a BYOND account can travel."
	if(H.stat != CONSCIOUS || H.restrained() || H.buckled || H.pulling || !Adjacent(H)) return "You can't set off right now."
	if(H.health < H.maxHealth) return "You are too hurt to make the journey."
	return null

/obj/structure/region_gate/proc/travel(mob/living/human/H)
	var/reason = travel_refusal(H)
	if(reason)
		to_chat(H, SPAN_WARNING(reason))
		alert_stopped_destination(H)
		return
	var/list/items = H.region_travel_items()
	if(istext(items))
		to_chat(H, SPAN_WARNING(items))
		return
	if(player_alert(H, "Travel to [destination_name()]? You leave this land with what you wear and carry, and continue there.", "Travel", list("Travel", "Stay")) != "Travel")
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
	if(H.client)
		H.record_persistence_owner()
	else
		H.persistence_owner_ckey = agent_travel_account(H)
	var/result = depart(H)
	if(result != "departed")
		to_chat(H, SPAN_WARNING(result))
		player_activity.travel_refused(H, destination, result)

// A player turned back because the destination's server is stopped: tell the
// admins once per land every REGION_STOPPED_ALERT_COOLDOWN, since only the host
// can start it again (a trail never starts a stopped land).
#define REGION_STOPPED_ALERT_COOLDOWN 6000
var/global/list/region_stopped_alerted = list()

/obj/structure/region_gate/proc/alert_stopped_destination(mob/living/human/H)
	if(!destination || !shard_group.enabled) return FALSE
	var/list/peer = shard_group.peers[destination]
	if(!peer || peer["state"] != "STOPPED") return FALSE
	if(world.time < region_stopped_alerted[destination]) return FALSE
	region_stopped_alerted[destination] = world.time + REGION_STOPPED_ALERT_COOLDOWN
	log_game("Region travel: [key_name(H)] was turned back at [x],[y],[z]: [destination] is stopped.")
	message_admins("[key_name_admin(H)] tried the trail at [x],[y],[z] to [html_encode(destination_name())], but that land is stopped. Start it from the host or launcher if players should reach it.")
	return TRUE

#undef REGION_STOPPED_ALERT_COOLDOWN

// Sends a character whose owner is recorded. Returns "departed" or a reason.
// Players reach this through travel(); a host agent can call it for a test
// character that has persistence_owner_ckey set.
/obj/structure/region_gate/proc/depart(mob/living/human/H)
	var/reason = closed_reason()
	if(reason) return reason
	if(!istype(H) || QDELETED(H) || H.loc != loc && H.loc != src && !Adjacent(H)) return "You are too far from the trail."
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
	if(length(payload) > ((findtext(payload, "\"ship\":") || findtext(payload, "\"plane\":")) ? REGION_TRAVEL_SHIP_PAYLOAD_MAX : REGION_TRAVEL_PAYLOAD_MAX)) return "You carry too much to travel."
	// The destination decodes with the same rules; never escrow what it would drop.
	if(!region_travel_decode(payload)) return "Something about you cannot make the journey. Ask an admin."
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
	player_activity.depart(H, destination, payload)
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
		shard_group.send_player_soon(C, destination)
	var/account = H.persistence_owner_ckey
	// Tells the agent where its character went, so it can follow (agent_travel.dm).
	if(!C)
		agent_note_departure(H, destination, destination_name())
	qdel(H)
	shard_group.request_save_soon()
	spawn(0)
		region_home_note(account, "depart", destination)
	return "departed"

// An admin ghost can follow a trail: their client goes to that land's server,
// nothing travels with them. Others' ghosts do nothing here.
/obj/structure/region_gate/attack_ghost(mob/user)
	if(!user || !user.client || !check_rights(R_ADMIN, FALSE, user)) return
	var/id = ghost_passage_destination()
	if(!shard_group.enabled || !istext(id) || !shard_group.peers[id]) return
	var/name = region_trail_name(id)
	if(WWinput(user, "Follow this trail to [name] as an admin? You join that land's server in its lobby; nothing here travels with you.", "Trail", "Stay", list("Go", "Stay")) != "Go") return
	if(!user.client || !check_rights(R_ADMIN, FALSE, user)) return
	log_admin("[key_name(user)] followed the trail at [x],[y],[z] to [id] as a ghost.")
	shard_group.send_player(user.client, id)

// Where an admin ghost following this gate goes.
/obj/structure/region_gate/proc/ghost_passage_destination()
	return destination

#undef REGION_TRAVEL_PAYLOAD_MAX
#undef REGION_TRAVEL_SHIP_PAYLOAD_MAX
#undef REGION_TRAVEL_ITEMS_MAX

// ---------------------------------------------------------------- wounds

// Limbs a trip never takes off a body: losing one is death, not a wound.
var/global/list/region_travel_vital_limbs = list("head", "chest", "groin")

// Each hurt, broken or lost limb, as organ tag = list(brute, burn, broken)
// or "missing". Unhurt limbs are left out.
/mob/living/human/proc/region_travel_limbs()
	. = list()
	if(!species) return
	for(var/tag in species.has_limbs)
		var/obj/item/organ/external/E = organs_by_name[tag]
		if(!E || E.is_stump())
			if(!(tag in region_travel_vital_limbs)) .[tag] = "missing"
			continue
		var/brute = clamp(round(E.brute_dam), 0, 200)
		var/burn = clamp(round(E.burn_dam), 0, 200)
		var/broken = (E.status & ORGAN_BROKEN) ? 1 : 0
		if(brute || burn || broken) .[tag] = list(brute, burn, broken)

/proc/region_travel_limbs_valid(list/L)
	if(!islist(L) || L.len > 20) return FALSE
	for(var/tag in L)
		if(!istext(tag) || length(tag) > 16) return FALSE
		var/value = L[tag]
		if(value == "missing")
			if(tag in region_travel_vital_limbs) return FALSE
			continue
		var/list/V = value
		if(!islist(V) || V.len != 3) return FALSE
		for(var/i = 1 to 2)
			if(!isnum(V[i]) || V[i] < 0 || V[i] > 200 || V[i] != round(V[i])) return FALSE
		if(!(V[3] in list(0, 1))) return FALSE
	return TRUE

// Puts back what region_travel_limbs() recorded on a fresh body: lost limbs
// come off cleanly, and each wound is laid on its own limb as a bruise or a
// burn of the same size, never as a blow that could break, cut or sever more.
/mob/living/human/proc/region_travel_restore_limbs(list/limbs)
	for(var/tag in limbs)
		if(limbs[tag] != "missing") continue
		var/obj/item/organ/external/E = organs_by_name[tag]
		if(!E || E.is_stump() || (tag in region_travel_vital_limbs)) continue
		E.removed(null)
		qdel(E)
	for(var/tag in limbs)
		var/list/V = limbs[tag]
		if(!islist(V)) continue
		var/obj/item/organ/external/E = organs_by_name[tag]
		if(!E || E.is_stump()) continue
		if(V[1]) E.createwound(BRUISE, V[1])
		if(V[2]) E.createwound(BURN, V[2])
		E.update_damages()
		if(V[3])
			E.status |= ORGAN_BROKEN
			E.broken_description = "broken"
			E.perma_injury = E.brute_dam
	updatehealth()
