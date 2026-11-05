// Party trains (docs/party-train.md). A party builds its first train as a
// project at a railway station in Persistence: a railway works office placed
// beside a straight run of track takes the materials, and once they are all in
// the office opens boarding. The train itself lives in the region group's rail
// yard world (shard_group kind RAILYARD); boarding travels there like a trail
// (region_travel.dm), and only members of the party that built it may board.
// A party is a player's faction, or the player alone when they have none.
// The yard gives each party a berth with a walk-in train (tools/rail_yard
// builds the yard map); a berth leads back to the land its party came from.

#define PARTY_TRAIN_TRACK_MIN 8 // straight rails needed beside the office
#define PARTY_TRAIN_TRACK_RANGE 2 // tiles from the office to that track

// Material kind = list(stack type, amount needed, label).
var/global/list/party_train_requirements = list(
	"iron" = list(/obj/item/stack/material/iron, 200, "iron"),
	"steel" = list(/obj/item/stack/material/steel, 60, "steel"),
	"wood" = list(/obj/item/stack/material/wood, 150, "wood"),
	"glass" = list(/obj/item/stack/material/glass, 30, "glass"),
	"cloth" = list(/obj/item/stack/material/cloth, 40, "cloth"))

// Saved: the party whose train brought this character here. Factions do not
// travel between lands, so a member keeps their party this way.
/mob/living/human/var/party_train_party = null

// A faction's party is named with the land it was founded in, so factions of
// the same name in different lands never share a train.
/proc/party_train_party_of(mob/living/human/H)
	if(!istype(H)) return null
	// In the yard, where factions do not travel, the party is the one whose
	// train brought this character. At home it is the character's faction.
	if(shard_group.enabled && shard_group.kind == "RAILYARD" && party_train_valid_party(H.party_train_party))
		return H.party_train_party
	if(H.civilization && H.civilization != "none")
		return party_train_faction_party(H.civilization)
	var/key = H.persistence_owner_ckey || (H.client && H.client.ckey)
	return key ? "ckey:[key]" : null

// A member coming home by train rejoins the faction that owns the train, if it
// still exists in this land.
/proc/party_train_restore_faction(mob/living/human/H, party)
	if(!istype(H) || !shard_group.enabled || shard_group.kind == "RAILYARD" || !party_train_valid_party(party) || !map) return
	var/prefix = "civ:[shard_group.region]:"
	if(findtext(party, prefix) != 1) return
	var/name = copytext(party, length(prefix) + 1)
	if(name in map.custom_civs)
		H.civilization = name

/proc/party_train_faction_party(name)
	return "civ:[shard_group.enabled ? shard_group.region : "local"]:[name]"

/proc/party_train_valid_party(party)
	if(!istext(party) || length(party) > 100) return FALSE
	if(findtext(party, "ckey:") == 1) return length(party) > 5 && ckey(copytext(party, 6)) == copytext(party, 6)
	return findtext(party, "civ:") == 1 && findtext(party, ":", 5) > 5 && findtext(party, ":", 5) < length(party)

/proc/party_train_party_name(party)
	if(!istext(party)) return "nobody"
	if(findtext(party, "civ:") == 1) return copytext(party, findtext(party, ":", 5) + 1)
	return "[copytext(party, 6)]'s party"

// A renamed faction keeps its train project or train, and members back from
// the yard keep their party. A berth in the yard keeps the old name until an
// admin edits it (docs/party-train.md).
/proc/party_train_rename_faction(old_name, new_name)
	var/old_party = party_train_faction_party(old_name)
	var/new_party = party_train_faction_party(new_name)
	for(var/obj/structure/region_gate/railway_station/S in region_gates)
		if(S.party == old_party)
			S.party = new_party
			log_game("Party train: the train at [S.x],[S.y],[S.z] follows its faction's rename from [old_name] to [new_name].")
	for(var/mob/living/human/H in human_mob_list)
		if(H.party_train_party == old_party)
			H.party_train_party = new_party

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
	// Delivered materials live only in the office, so vehicles and blasts must not delete it.
	crushable = FALSE
	map_storage_saved_vars = "icon_state;dir;name;pixel_x;pixel_y;party;delivered;completed;completed_at;boarded"
	// The party building (and then owning) the train here.
	var/party = null
	// Material kind = amount delivered so far.
	var/list/delivered = list()
	var/completed = FALSE
	var/completed_at = null // realtime text, for players and logs
	// Someone has ridden this train, so the party holds a berth in the yard.
	var/boarded = FALSE

/obj/structure/region_gate/railway_station/New()
	..()
	if(!islist(delivered)) delivered = list()

/obj/structure/region_gate/railway_station/ex_act(severity)
	return

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
	// A party without a berth must not be stranded in a full yard.
	if(!boarded && shard_group.peers[destination]["free_berths"] == 0)
		return "The rail yard has no free berth for another train. Ask an admin."
	return ..()

/obj/structure/region_gate/railway_station/depart(mob/living/human/H)
	. = ..()
	if(. == "departed")
		boarded = TRUE

/obj/structure/region_gate/railway_station/travel_party(mob/living/human/H)
	return party

/obj/structure/region_gate/railway_station/travel_refusal(mob/living/human/H)
	. = ..()
	if(.) return
	if(!party_train_may_board(H, party))
		return "This train belongs to [party_train_party_name(party)]."

/obj/structure/region_gate/railway_station/attack_hand(mob/living/human/user)
	if(!istype(user) || !user.client) return
	// Covers requirements lowered after materials were delivered.
	if(party && !completed && !length(remaining()))
		complete(user)
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
	// A party's name depends on its land, which needs the region group.
	if(!shard_group.enabled)
		to_chat(user, SPAN_WARNING("No rail yard serves this land."))
		return
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
	// The prompt slept: the player's party, the track and other offices may have changed.
	if(QDELETED(src) || party || !user.client || !Adjacent(user)) return
	if(party_train_party_of(user) != new_party || party_train_office_of(new_party, src)) return
	problem = station_problem()
	if(problem)
		to_chat(user, SPAN_WARNING(problem))
		return
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

// -- the rail yard -----------------------------------------------------------

/area/caribbean/nomads/rail_yard
	name = "Rail Yard"
	icon_state = "green1"
	climate = "temperate"

/area/caribbean/nomads/rail_yard/train
	name = "Party Train"
	location = AREA_INSIDE

// Carriage walls of the yard's trains: nobody breaks into another party's train.
/turf/wall/indestructable/party_train
	name = "carriage wall"
	desc = "The riveted steel side of a railway carriage."
	layer = TURF_LAYER + 0.02 // as other walls, not the black filler wall's 10

// A party's berth: the platform beside its walk-in train. Free until a
// party's first member arrives; from then on it belongs to that party and
// leads back to the land its station is in.
/obj/structure/region_gate/rail_berth
	name = "train berth"
	desc = "A numbered platform where a party keeps its train."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "cabinroof"
	map_storage_saved_vars = "icon_state;dir;name;pixel_x;pixel_y;destination;berth;party;home_region;assigned_at"
	var/berth = 0 // set by the yard map
	var/party = null
	var/home_region = null
	var/assigned_at = null // realtime text

/obj/structure/region_gate/rail_berth/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/rail_berth/travel_party(mob/living/human/H)
	return party

/obj/structure/region_gate/rail_berth/closed_reason()
	if(!party) return "Berth [berth] is free. A party's train is brought here when its first member arrives."
	if(!home_region || !shard_group.enabled || !(home_region in shard_group.peers))
		return "Nobody knows the way back from here."
	destination = home_region
	return ..()

/obj/structure/region_gate/rail_berth/travel_refusal(mob/living/human/H)
	. = ..()
	if(.) return
	if(!party_train_may_board(H, party))
		return "This train belongs to [party_train_party_name(party)]."

/obj/structure/region_gate/rail_berth/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE(party ? "Berth [berth] holds the train of [party_train_party_name(party)] (since [assigned_at])." : "Berth [berth] is free."))

/proc/party_train_free_berths()
	. = 0
	for(var/obj/structure/region_gate/rail_berth/B in region_gates)
		if(!B.party && B.berth > 0 && !QDELETED(B) && isturf(B.loc))
			.++

/proc/party_train_berth_of(party)
	for(var/obj/structure/region_gate/rail_berth/B in region_gates)
		if(B.party == party && !QDELETED(B)) return B
	return null

// The lowest free berth goes to party. Null when the yard is full.
/proc/party_train_assign_berth(party)
	var/obj/structure/region_gate/rail_berth/best = null
	for(var/obj/structure/region_gate/rail_berth/B in region_gates)
		if(!B.party && B.berth > 0 && !QDELETED(B) && isturf(B.loc) && (!best || B.berth < best.berth))
			best = B
	if(!best)
		message_admins("Party train: the rail yard is full; [html_encode(party_train_party_name(party))] arrived at the platform without a berth.")
		return null
	best.party = party
	best.assigned_at = time2text(world.realtime, "YYYY-MM-DD hh:mm")
	log_game("Party train: berth [best.berth] at [best.x],[best.y],[best.z] assigned to [party].")
	return best

// Where a party train trip arrives: the party's berth in the yard, or back
// home at the party's finished station. Null for any other trip. Never sleeps.
/proc/party_train_arrival_turf(list/P)
	var/party = P["party"]
	if(!party_train_valid_party(party)) return null
	if(shard_group.enabled && shard_group.kind == "RAILYARD")
		var/obj/structure/region_gate/rail_berth/B = party_train_berth_of(party) || party_train_assign_berth(party)
		if(!B) return null
		// The way back leads to the land the party last came from.
		var/from = P["from"]
		if(istext(from) && (from in shard_group.peers))
			B.home_region = from
		return isturf(B.loc) ? B.loc : null
	var/obj/structure/region_gate/railway_station/S = party_train_office_of(party)
	if(S && S.completed && isturf(S.loc)) return S.loc
	return null

// -- boarding another party's train ------------------------------------------

#define PARTY_TRAIN_DOOR_STRENGTH 300 // weapon force (or half bullet damage) to force a door

// Whether user may use party's train freely: its doors and its berth.
/proc/party_train_may_board(mob/user, party)
	return party && party_train_party_of(user) == party

// Whether any member of party is playing in this world now.
/proc/party_members_online(party)
	if(!party_train_valid_party(party)) return FALSE
	for(var/mob/living/human/H in human_mob_list)
		if(H.client && H.stat != DEAD && party_train_party_of(H) == party)
			return TRUE
	return FALSE

// Whether other factions may force their way into party's train now. Raids
// happen only while the owners are here to defend it.
/proc/party_train_breachable(party)
	return party_members_online(party)

// A door of a party's train. It opens for that party. Others can force it open
// while a member of the party is in this world; the party secures it again by
// hand. It is never destroyed, so the train always keeps its doors.
/obj/structure/simple_door/party_train
	name = "train door"
	desc = "A heavy carriage door. It opens for the party that owns this train; raiders can force it while the owners are aboard the yard."
	var/berth = 0 // the berth this train stands at
	var/forced = FALSE
	var/breach_left = PARTY_TRAIN_DOOR_STRENGTH

/obj/structure/simple_door/party_train/New(newloc, material_name)
	..(newloc, "steel")
	name = initial(name)

/obj/structure/simple_door/party_train/proc/owner_party()
	for(var/obj/structure/region_gate/rail_berth/B in region_gates)
		if(B.berth == berth)
			return B.party
	return null

/obj/structure/simple_door/party_train/proc/party_member(mob/user)
	return party_train_may_board(user, owner_party())

/obj/structure/simple_door/party_train/door_hand_locked(mob/user)
	return !canOpen(user)

/obj/structure/simple_door/party_train/canOpen(mob/user)
	return forced || party_member(user)

/obj/structure/simple_door/party_train/attack_hand(mob/user)
	if(forced && party_member(user))
		secure(user)
		return TRUE
	return ..()

/obj/structure/simple_door/party_train/proc/secure(mob/user)
	forced = FALSE
	breach_left = PARTY_TRAIN_DOOR_STRENGTH
	user.visible_message(SPAN_NOTICE("[user] secures the forced train door again."), SPAN_NOTICE("You secure the forced door again."))

// Damage from someone forcing the door. Returns TRUE when it took the damage.
/obj/structure/simple_door/party_train/proc/breach(amount, mob/user)
	if(forced || amount <= 0) return FALSE
	var/party = owner_party()
	if(!party || !party_train_breachable(party))
		if(user)
			to_chat(user, SPAN_WARNING("The door is sealed while its owners are away."))
		return FALSE
	breach_left -= amount
	if(breach_left > 0)
		visible_message(SPAN_DANGER("\The [src] buckles under the blow."))
		return TRUE
	forced = TRUE
	visible_message(SPAN_DANGER("\The [src] is forced open!"))
	log_game("Party train: the door of berth [berth] ([party]) at [x],[y],[z] was forced[user ? " by [key_name(user)]" : ""].")
	// Open() animates and sleeps; breach() is called from attacks and blasts.
	if(!state)
		addtimer(CALLBACK(src, PROC_REF(swing_open)), 1)
	return TRUE

/obj/structure/simple_door/party_train/proc/swing_open()
	if(!QDELETED(src) && forced && !state && !isSwitchingStates)
		Open()

/obj/structure/simple_door/party_train/door_kick(mob/user)
	if(party_member(user)) return ..()
	if(!door_noise_ready()) return FALSE
	user.visible_message(SPAN_DANGER("[user] kicks the train door!"), SPAN_DANGER("You kick the train door!"))
	playsound(get_turf(src), 'sound/effects/grillehit.ogg', 100)
	breach(10, user)
	return TRUE

/obj/structure/simple_door/party_train/attackby(obj/item/weapon/W, mob/user)
	if(party_member(user))
		if(forced)
			secure(user)
			return
		return door_intent_interact(user)
	if(istype(W) && W.force > 0)
		user.do_attack_animation(src)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if(!breach(W.force, user))
			door_rattle(user)
		return
	door_rattle(user)

/obj/structure/simple_door/party_train/bullet_act(obj/item/projectile/P)
	breach(P.damage / 2)

/obj/structure/simple_door/party_train/ex_act(severity)
	breach(severity == 1 ? PARTY_TRAIN_DOOR_STRENGTH : (severity == 2 ? 150 : 50))

/obj/structure/simple_door/party_train/fire_act(temperature)
	return

/obj/structure/simple_door/party_train/TemperatureAct(temperature)
	return

/obj/structure/simple_door/party_train/CheckHardness()
	return

/obj/structure/simple_door/party_train/Dismantle(devastated = FALSE)
	return

#undef PARTY_TRAIN_DOOR_STRENGTH
#undef PARTY_TRAIN_TRACK_MIN
#undef PARTY_TRAIN_TRACK_RANGE
