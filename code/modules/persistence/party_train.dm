// Party trains (docs/party-train.md). A party builds its first train as a
// project at a railway station in Persistence: a railway works office placed
// beside a straight run of track takes the materials, and once they are all in
// the office opens boarding. The train itself lives in the region group's rail
// yard world (shard_group kind RAILYARD); boarding travels there like a trail
// (region_travel.dm), and only members of the party that built it may board.
// A party is a player's faction, or the player alone when they have none.

#define PARTY_TRAIN_TRACK_MIN 8 // straight rails needed beside the office
#define PARTY_TRAIN_TRACK_RANGE 2 // tiles from the office to that track

// Material kind = list(stack type, amount needed, label).
var/global/list/party_train_requirements = list(
	"iron" = list(/obj/item/stack/material/iron, 200, "iron"),
	"steel" = list(/obj/item/stack/material/steel, 60, "steel"),
	"wood" = list(/obj/item/stack/material/wood, 150, "wood"),
	"glass" = list(/obj/item/stack/material/glass, 30, "glass"),
	"cloth" = list(/obj/item/stack/material/cloth, 40, "cloth"))

/proc/party_train_party_of(mob/living/human/H)
	if(!istype(H)) return null
	if(H.civilization && H.civilization != "none") return "civ:[H.civilization]"
	var/key = H.persistence_owner_ckey || (H.client && H.client.ckey)
	return key ? "ckey:[key]" : null

/proc/party_train_party_name(party)
	if(!istext(party)) return "nobody"
	if(findtext(party, "civ:") == 1) return copytext(party, 5)
	return "[copytext(party, 6)]'s party"

/proc/party_train_rail_at(turf/T)
	return T && (locate(/obj/structure/rails) in T)

// The longest straight run of rails through T, horizontally or vertically.
/proc/party_train_run_through(turf/T)
	var/best = 0
	for(var/list/axis in list(list(EAST, WEST), list(NORTH, SOUTH)))
		var/count = 1
		for(var/d in axis)
			var/turf/step = get_step(T, d)
			while(step && party_train_rail_at(step) && count < 64)
				count++
				step = get_step(step, d)
		best = max(best, count)
	return best

/obj/structure/region_gate/railway_station
	name = "railway works office"
	desc = "A railway office and workshop. A party can build its first train here."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "cabinroof"
	density = TRUE
	map_storage_saved_vars = "icon_state;dir;name;pixel_x;pixel_y;party;delivered;completed;completed_at"
	// The party building (and then owning) the train here.
	var/party = null
	// Material kind = amount delivered so far.
	var/list/delivered = list()
	var/completed = FALSE
	var/completed_at = null // realtime text, for players and logs

/obj/structure/region_gate/railway_station/New()
	..()
	if(!islist(delivered)) delivered = list()

/obj/structure/region_gate/railway_station/accepts_arrivals()
	return FALSE

// Null when this office stands at a usable station, otherwise why not.
/obj/structure/region_gate/railway_station/proc/station_problem()
	if(!isturf(loc)) return "The office must stand on the ground."
	for(var/turf/T in range(PARTY_TRAIN_TRACK_RANGE, src))
		if(party_train_rail_at(T) && party_train_run_through(T) >= PARTY_TRAIN_TRACK_MIN)
			return null
	return "A station needs a straight run of at least [PARTY_TRAIN_TRACK_MIN] rails within [PARTY_TRAIN_TRACK_RANGE] tiles of the office."

/obj/structure/region_gate/railway_station/proc/rail_yard()
	if(!shard_group.enabled) return null
	for(var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		if(peer["kind"] == "RAILYARD") return id
	return null

/obj/structure/region_gate/railway_station/proc/remaining()
	var/list/left = list()
	for(var/kind in party_train_requirements)
		var/list/need = party_train_requirements[kind]
		var/missing = need[2] - (delivered[kind] || 0)
		if(missing > 0) left[kind] = missing
	return left

/obj/structure/region_gate/railway_station/proc/progress_text()
	var/list/parts = list()
	for(var/kind in party_train_requirements)
		var/list/need = party_train_requirements[kind]
		parts += "[need[3]] [delivered[kind] || 0]/[need[2]]"
	return jointext(parts, ", ")

/obj/structure/region_gate/railway_station/closed_reason()
	if(!completed)
		return party ? "[party_train_party_name(party)] is building a train here: [progress_text()]." : "No train is being built here yet."
	destination = rail_yard()
	if(!destination) return "No rail yard serves this land yet."
	return ..()

/obj/structure/region_gate/railway_station/travel_refusal(mob/living/human/H)
	. = ..()
	if(.) return
	if(party_train_party_of(H) != party)
		return "This train belongs to [party_train_party_name(party)]."

/obj/structure/region_gate/railway_station/attack_hand(mob/living/human/user)
	if(!istype(user) || !user.client) return
	if(completed)
		return ..()
	if(!party)
		start(user)
		return
	to_chat(user, SPAN_NOTICE(closed_reason()))

// Another office already serving this party, if any.
/proc/party_train_office_of(party, exclude = null)
	for(var/obj/structure/region_gate/railway_station/S in region_gates)
		if(S != exclude && S.party == party && !QDELETED(S)) return S
	return null

/obj/structure/region_gate/railway_station/proc/start(mob/living/human/user)
	var/problem = station_problem()
	if(problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	if(IsGuestKey(user.client.key))
		to_chat(user, SPAN_WARNING("Only players with a BYOND account can build a party train."))
		return
	var/new_party = party_train_party_of(user)
	if(!new_party) return
	var/obj/structure/region_gate/railway_station/other = party_train_office_of(new_party, src)
	if(other)
		to_chat(user, SPAN_WARNING("[party_train_party_name(new_party)] already has a train project at [other.x],[other.y]."))
		return
	if(alert(user, "Start building [party_train_party_name(new_party)]'s train here? Bring [progress_text()] to finish it.", "Party train", "Start", "Cancel") != "Start")
		return
	if(QDELETED(src) || party || !user.client || !Adjacent(user)) return
	if(party_train_office_of(new_party, src)) return
	party = new_party
	log_game("Party train: [key_name(user)] started a train for [party] at [x],[y],[z].")
	visible_message(SPAN_NOTICE("[user] starts a train project for [party_train_party_name(party)]."))

/obj/structure/region_gate/railway_station/attackby(obj/item/W, mob/user)
	if(!istype(W, /obj/item/stack) || completed || !party)
		return ..()
	var/obj/item/stack/S = W
	for(var/kind in party_train_requirements)
		var/list/need = party_train_requirements[kind]
		if(!istype(S, need[1])) continue
		var/missing = need[2] - (delivered[kind] || 0)
		if(missing <= 0)
			to_chat(user, SPAN_NOTICE("The train needs no more [need[3]]."))
			return TRUE
		var/amount = min(missing, S.amount)
		if(amount < 1 || !S.use(amount)) return TRUE
		delivered[kind] = (delivered[kind] || 0) + amount
		to_chat(user, SPAN_NOTICE("You hand over [amount] [need[3]]. [progress_text()]."))
		if(!length(remaining()))
			complete(user)
		return TRUE
	return ..()

/obj/structure/region_gate/railway_station/proc/complete(mob/user)
	if(completed) return
	completed = TRUE
	completed_at = time2text(world.realtime, "YYYY-MM-DD hh:mm")
	log_game("Party train: [party] finished its train at [x],[y],[z][user ? " ([key_name(user)])" : ""].")
	visible_message(SPAN_NOTICE("The train for [party_train_party_name(party)] is finished. Its members can board it here."))

/obj/structure/region_gate/railway_station/examine(mob/user)
	..()
	if(completed && party)
		to_chat(user, SPAN_NOTICE("It holds the finished train of [party_train_party_name(party)] (since [completed_at])."))

#undef PARTY_TRAIN_TRACK_MIN
#undef PARTY_TRAIN_TRACK_RANGE
