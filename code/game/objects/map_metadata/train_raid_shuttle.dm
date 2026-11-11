// Train Raid saved shuttles: fuel, boarding passes and a hold that stays the
// party's between rounds. See docs/train-raid-mode.md.
//
// - The first raider of a crew in a round is its captain. The shuttle is the
//   captain's party's ("ckey:<key>", the same party ids as party trains), and
//   its saved hold is unloaded into the stores when the captain joins.
// - At the line collapse, everything aboard (floor, crates, lockers and what
//   the crew aboard carry) is packed with the party freight codec
//   (party_freight.dm) into a two-slot record under data/train_raid_shuttles/.
//   Fuel cells aboard top up the tank; boarding passes and lift balloons are
//   kept as counts. Anything the codec cannot rebuild stays behind and is lost.
// - Fuel: each beacon recall burns mode.recall_fuel. Fuel is checked and spent
//   in one step (recall), so a trip is never free or paid twice. Load fuel
//   cells or coal at the helm.
// - Boarding passes: rear sections (tier TRAIN_RAID_OPEN_TIER and below) are
//   open. A pass loaded at the helm clears its section and every section behind
//   it for lift balloons until the round ends; loading spends the pass. Doors
//   stay breachable without one: a pass gates lifting cargo, not walking in.

#define TRAIN_RAID_SHUTTLE_SCHEMA 1
#define TRAIN_RAID_SHUTTLE_LOADS 40 // shipments a saved hold keeps
#define TRAIN_RAID_SHUTTLE_TEXT 4000000 // characters in one saved record
#define TRAIN_RAID_FUEL_MAX 20
#define TRAIN_RAID_START_FUEL 6
#define TRAIN_RAID_CELL_FUEL 2
#define TRAIN_RAID_OPEN_TIER 2
#define TRAIN_RAID_TOP_TIER 5
#define TRAIN_RAID_PASSES_MAX 12
#define TRAIN_RAID_BALLOONS_MAX 12

var/global/train_raid_shuttle_root = "data/train_raid_shuttles/"

/proc/train_raid_section_name(tier)
	switch (tier)
		if (3) return "crew coaches"
		if (4) return "vault car"
		if (5) return "locomotive"
	return "rear cars"

/proc/train_raid_shuttle_owner(party)
	if (!party_train_valid_party(party) || findtext(party, "ckey:") != 1) return null
	var/owner = copytext(party, 6)
	if (!length(owner) || length(owner) > 64 || findtext(owner, "guest") == 1) return null
	return owner

/proc/train_raid_shuttle_path(owner, slot)
	return "[train_raid_shuttle_root][owner].[slot].json"

/proc/train_raid_new_shuttle(party)
	return list("schema" = TRAIN_RAID_SHUTTLE_SCHEMA, "party" = party, "generation" = 0, "fuel" = TRAIN_RAID_START_FUEL, "passes" = list(3), "balloons" = 0, "shipments" = list(), "rounds" = 0)

/proc/train_raid_shuttle_valid(list/R, party)
	if (!islist(R) || R["schema"] != TRAIN_RAID_SHUTTLE_SCHEMA || R["party"] != party) return FALSE
	var/generation = R["generation"]
	var/fuel = R["fuel"]
	var/balloons = R["balloons"]
	var/rounds = R["rounds"]
	if (!isnum(generation) || generation < 0 || generation != round(generation)) return FALSE
	if (!isnum(fuel) || fuel < 0 || fuel > TRAIN_RAID_FUEL_MAX || fuel != round(fuel)) return FALSE
	if (!isnum(balloons) || balloons < 0 || balloons > TRAIN_RAID_BALLOONS_MAX || balloons != round(balloons)) return FALSE
	if (!isnum(rounds) || rounds < 0) return FALSE
	var/list/passes = R["passes"]
	if (!islist(passes) || passes.len > TRAIN_RAID_PASSES_MAX) return FALSE
	for (var/tier in passes)
		if (!isnum(tier) || tier <= TRAIN_RAID_OPEN_TIER || tier > TRAIN_RAID_TOP_TIER || tier != round(tier)) return FALSE
	var/list/shipments = R["shipments"]
	if (!islist(shipments) || shipments.len > TRAIN_RAID_SHUTTLE_LOADS) return FALSE
	for (var/text in shipments)
		var/list/shipment = party_freight_shipment(text)
		if (!shipment || shipment["party"] != party) return FALSE
	return TRUE

// One slot's record, FALSE when the slot is missing, or null when it is unreadable.
/proc/train_raid_shuttle_read_slot(owner, slot, party)
	var/path = train_raid_shuttle_path(owner, slot)
	if (!fexists(path)) return FALSE
	var/text = file2text(path)
	if (!istext(text) || length(text) > TRAIN_RAID_SHUTTLE_TEXT) return null
	var/list/R
	try
		R = json_decode(text)
	catch
		return null
	return train_raid_shuttle_valid(R, party) ? R : null

// The party's newest valid record, a new shuttle when it has none, or null when
// it has saves but none of them can be read (the crew then sails a stand-in
// shuttle that is never written over the damaged save).
/proc/train_raid_shuttle_load(party)
	var/owner = train_raid_shuttle_owner(party)
	if (!owner) return null
	var/list/best = null
	var/damaged = FALSE
	for (var/slot in 0 to 1)
		var/list/R = train_raid_shuttle_read_slot(owner, slot, party)
		if (isnull(R))
			damaged = TRUE
		else if (islist(R) && (!best || R["generation"] > best["generation"]))
			best = R
	if (best) return best
	return damaged ? null : train_raid_new_shuttle(party)

// Writes R as the next generation into the older slot and reads it back, so a
// failed or torn write leaves the newer slot as the save that loads.
/proc/train_raid_shuttle_commit(party, list/R)
	var/owner = train_raid_shuttle_owner(party)
	if (!owner || !train_raid_shuttle_valid(R, party)) return FALSE
	var/list/A = train_raid_shuttle_read_slot(owner, 0, party)
	var/list/B = train_raid_shuttle_read_slot(owner, 1, party)
	var/gen_a = islist(A) ? A["generation"] : -1
	var/gen_b = islist(B) ? B["generation"] : -1
	var/slot = gen_a <= gen_b ? 0 : 1
	var/list/candidate = R.Copy()
	candidate["generation"] = max(gen_a, gen_b, R["generation"]) + 1
	var/payload = json_encode(candidate)
	if (length(payload) > TRAIN_RAID_SHUTTLE_TEXT) return FALSE
	var/path = train_raid_shuttle_path(owner, slot)
	if (fexists(path) && !fdel(path)) return FALSE
	text2file(payload, path)
	// text2file appends a newline.
	if (file2text(path) != "[payload]\n") return FALSE
	R["generation"] = candidate["generation"]
	return TRUE

///////////////////////////////Crew shuttle//////////////////////////////////////////////

/datum/train_raid_crew/proc/shuttle_text()
	if (!party) return "Nobody has taken command of this shuttle yet."
	return "Captain: [captain]. Fuel: [fuel]/[TRAIN_RAID_FUEL_MAX] (a recall burns [mode.recall_fuel]). Cargo cleared up to the [train_raid_section_name(clearance)]."

/datum/train_raid_crew/proc/cleared_for(atom/A)
	var/area/train_raid/AR = get_area(A)
	return !istype(AR) || AR.raid_tier <= max(clearance, TRAIN_RAID_OPEN_TIER)

// The crew's first raider takes command and brings their saved shuttle.
/datum/train_raid_crew/proc/take_command(mob/living/human/H, key)
	if (party || !istext(key)) return FALSE
	var/candidate = "ckey:[key]"
	if (!train_raid_shuttle_owner(candidate)) return FALSE
	for (var/other_id in mode.crews)
		var/datum/train_raid_crew/other = mode.crews[other_id]
		if (other != src && other.party == candidate) return FALSE
	party = candidate
	captain = H.real_name
	var/list/R = train_raid_shuttle_load(party)
	if (!R)
		save_blocked = TRUE
		R = train_raid_new_shuttle(party)
		log_game("Train Raid: [party]'s saved shuttle could not be read; the [title] crew sails a stand-in that will not be saved.")
		announce("[captain]'s saved shuttle could not be read, so the crew sails a stand-in shuttle this round. It will not be saved.")
	generation = R["generation"]
	fuel = R["fuel"]
	var/list/stores = store_turfs()
	if (!stores.len)
		stores = list(get_turf(H))
	var/index = 0
	var/loads = 0
	for (var/text in R["shipments"])
		var/list/shipment = party_freight_shipment(text)
		if (!shipment) continue
		index++
		party_freight_unpack(shipment, stores[(index - 1) % stores.len + 1])
		loads++
	var/list/passes = R["passes"]
	for (var/tier in passes)
		index++
		new /obj/item/train_raid_pass(stores[(index - 1) % stores.len + 1], tier)
	for (var/i in 1 to R["balloons"])
		index++
		new /obj/item/train_raid_balloon(stores[(index - 1) % stores.len + 1])
	var/fresh = !generation && !loads
	announce("[captain] takes command of the [title] shuttle. [fresh ? "It is a new shuttle" : "It has come back from [R["rounds"]] round\s"] with [loads] load\s in the stores, [passes.len] boarding pass[passes.len == 1 ? "" : "es"] and [fuel] fuel.")
	return TRUE

// Fuel cells or coal top up the tank; a boarding pass clears its section.
/datum/train_raid_crew/proc/load_at_helm(mob/living/human/H, obj/item/W)
	if (mode.game_over) return FALSE
	if (!party)
		to_chat(H, "Nobody has taken command of this shuttle.")
		return FALSE
	if (istype(W, /obj/item/train_raid_pass))
		var/obj/item/train_raid_pass/P = W
		if (P.tier <= clearance)
			to_chat(H, "The [train_raid_section_name(clearance)] are already cleared; this pass adds nothing.")
			return FALSE
		clearance = P.tier
		H.remove_from_mob(P)
		qdel(P)
		announce("[H.real_name] loaded a boarding pass. Lift balloons now work up to the [train_raid_section_name(clearance)] until the line collapses.")
		return TRUE
	var/per_unit = 0
	var/units = 0
	if (istype(W, /obj/item/train_raid_fuel))
		per_unit = TRAIN_RAID_CELL_FUEL
		units = 1
	else if (istype(W, /obj/item/stack/ore/coal))
		var/obj/item/stack/S = W
		per_unit = 1
		units = S.amount
	if (!per_unit)
		to_chat(H, "The helm takes fuel cells, coal and boarding passes.")
		return FALSE
	var/room = TRAIN_RAID_FUEL_MAX - fuel
	var/used = min(units, round(room / per_unit))
	if (used < 1)
		to_chat(H, "The tank is full ([fuel]/[TRAIN_RAID_FUEL_MAX]).")
		return FALSE
	fuel += used * per_unit
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		S.use(used)
	else
		H.remove_from_mob(W)
		qdel(W)
	to_chat(H, SPAN_NOTICE("You load the shuttle's tank. Fuel: [fuel]/[TRAIN_RAID_FUEL_MAX]."))
	return TRUE

// Everything aboard that the crew keeps: loose items, crates and lockers, and
// what living crew aboard carry. Returns roots, most valuable first.
/datum/train_raid_crew/proc/hold_roots()
	var/list/values = list()
	for (var/area/A in area_list)
		if (!aboard(A)) continue
		for (var/turf/T in A)
			for (var/atom/movable/AM in T)
				if (istype(AM, /obj/structure/closet/crate))
					var/obj/structure/closet/crate/C = AM
					if (C.anchored) continue
					values[C] = mode.value_of(C)
				else if (istype(AM, /obj/structure/closet))
					for (var/obj/item/I in AM.contents)
						values[I] = mode.value_of(I)
				else if (istype(AM, /obj/item))
					values[AM] = mode.value_of(AM)
				else if (ishuman(AM))
					var/mob/living/human/H = AM
					if (H.train_raid_crew != id || H.stat == DEAD) continue
					for (var/obj/item/I in H.contents)
						if (istype(I, /obj/item/organ) || istype(I, /obj/item/weapon/grab)) continue
						values[I] = mode.value_of(I)
	return sortTim(values, /proc/cmp_numeric_dsc, TRUE)

// Packs one thing aboard into tally: the mode's own items as counts, anything
// else as a shipment. A container holding something that cannot be kept is
// emptied into its own shipments first, then packed again.
/datum/train_raid_crew/proc/pack_aboard(atom/movable/root, list/tally, depth = 0)
	if (!root || QDELETED(root)) return
	if (istype(root, /obj/item/train_raid_fuel))
		if (tally["fuel"] + TRAIN_RAID_CELL_FUEL <= TRAIN_RAID_FUEL_MAX)
			tally["fuel"] += TRAIN_RAID_CELL_FUEL
		else
			tally["left"]++
		qdel(root)
		return
	if (istype(root, /obj/item/train_raid_pass))
		var/obj/item/train_raid_pass/P = root
		var/list/passes = tally["passes"]
		if (passes.len < TRAIN_RAID_PASSES_MAX) passes += P.tier
		else tally["left"]++
		qdel(root)
		return
	if (istype(root, /obj/item/train_raid_balloon))
		if (tally["balloons"] < TRAIN_RAID_BALLOONS_MAX) tally["balloons"]++
		else tally["left"]++
		qdel(root)
		return
	if (istype(root, /obj/item/train_raid_beacon))
		qdel(root)
		return
	var/list/shipments = tally["shipments"]
	if (shipments.len >= TRAIN_RAID_SHUTTLE_LOADS)
		tally["left"]++
		return
	// Carried items come out of the raider's hands first.
	if (ismob(root.loc))
		var/mob/holder = root.loc
		holder.remove_from_mob(root)
	var/text = party_freight_pack(root, party, null)
	if (copytext(text, 1, 2) != "!")
		shipments += text
		return
	var/list/inside = list()
	for (var/obj/item/I in root.contents)
		inside += I
	if (!inside.len || depth >= 3)
		tally["left"]++
		return
	for (var/obj/item/I in inside)
		pack_aboard(I, tally, depth + 1)
	// An emptied crate is not worth a load; an emptied bag or case is.
	if (istype(root, /obj/structure/closet)) return
	if (shipments.len >= TRAIN_RAID_SHUTTLE_LOADS)
		tally["left"]++
		return
	text = party_freight_pack(root, party, null)
	if (copytext(text, 1, 2) != "!") shipments += text
	else tally["left"]++

// Packs the hold into the saved record at the line collapse. Returns a line
// for the round summary, or null when this crew has no shuttle to save.
/datum/train_raid_crew/proc/save_shuttle()
	if (!party) return null
	if (save_blocked) return "[title] shuttle: not saved (its earlier save could not be read)."
	var/list/tally = list("shipments" = list(), "passes" = list(), "balloons" = 0, "left" = 0, "fuel" = fuel)
	for (var/atom/movable/root in hold_roots())
		pack_aboard(root, tally)
	var/list/shipments = tally["shipments"]
	var/list/passes = tally["passes"]
	var/left_behind = tally["left"]
	var/list/R = list("schema" = TRAIN_RAID_SHUTTLE_SCHEMA, "party" = party, "generation" = generation, "fuel" = tally["fuel"], "passes" = passes, "balloons" = tally["balloons"], "shipments" = shipments, "rounds" = 0)
	var/list/old = train_raid_shuttle_load(party)
	R["rounds"] = (islist(old) ? old["rounds"] : 0) + 1
	if (!train_raid_shuttle_commit(party, R))
		log_game("Train Raid: saving [party]'s shuttle failed.")
		return "[title] shuttle: saving the hold failed."
	return "[title] shuttle: [captain]'s hold saved for the next round with [shipments.len] load\s, [passes.len] boarding pass[passes.len == 1 ? "" : "es"] and [tally["fuel"]] fuel[left_behind ? "; [left_behind] thing\s could not be kept" : ""]."

///////////////////////////////Items//////////////////////////////////////////////

// A boarding pass clears one forward section of the Hauler for lift balloons.
/obj/item/train_raid_pass
	name = "boarding pass"
	desc = "A stamped cargo manifest for a forward section of the Hauler. Load it at your shuttle's helm to lift that section's cargo with balloons this round."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	w_class = ITEM_SIZE_TINY
	value = 20
	var/tier = 3

/obj/item/train_raid_pass/New(newloc, pass_tier)
	..(newloc)
	if (isnum(pass_tier) && pass_tier > TRAIN_RAID_OPEN_TIER && pass_tier <= TRAIN_RAID_TOP_TIER)
		tier = pass_tier
	name = "boarding pass ([train_raid_section_name(tier)])"
	value = 20 * (tier - TRAIN_RAID_OPEN_TIER)

/obj/item/train_raid_pass/coaches
	tier = 3

/obj/item/train_raid_pass/vault
	tier = 4

/obj/item/train_raid_pass/locomotive
	tier = 5

/obj/item/train_raid_fuel
	name = "shuttle fuel cell"
	desc = "A sealed fuel cell for a raiding shuttle. Load it at the helm; it is worth one trip back."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "jerrycan"
	w_class = ITEM_SIZE_NORMAL
	value = 10

#undef TRAIN_RAID_SHUTTLE_SCHEMA
#undef TRAIN_RAID_SHUTTLE_LOADS
#undef TRAIN_RAID_SHUTTLE_TEXT
#undef TRAIN_RAID_FUEL_MAX
#undef TRAIN_RAID_START_FUEL
#undef TRAIN_RAID_CELL_FUEL
#undef TRAIN_RAID_OPEN_TIER
#undef TRAIN_RAID_TOP_TIER
#undef TRAIN_RAID_PASSES_MAX
#undef TRAIN_RAID_BALLOONS_MAX
