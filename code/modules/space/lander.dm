// ============================================================
// Crewed flight (space settlement phase 2)
// ------------------------------------------------------------
// A launch pad is a player-built trail marker that only leads to worlds with
// a survey map (config/space/survey/<region>.json), and like any trail it
// opens only once an admin approves it. A crewed lander built beside the pad
// is filled with rocket propellant; crew strap in on its tile and one of them
// launches. Each crew member then travels as an ordinary region traveller
// (region_travel.dm) with what they wear and carry, and the payload also says
// which lander they rode in and where it set down. The lander itself does not
// travel: the first arrival of a flight builds a landed lander at the chosen
// survey cell, and the rest of the crew join it there.
//
// A landed lander is a 3x3 deck of sealed floor around a small life-support
// core. The deck turfs ask the core for air through the outside-air hooks in
// barren_world.dm, so the cabin is one habitat ledger: no per-tile gas. Its
// oxygen, scrubber and power reserves last a few hours, enough to set up the
// first habitat module (phase 3), and one bunk on the deck can be claimed so
// the crew can make the new world home at once.
//
// Rules from docs/space-settlement-roadmap.md: no saved world.time (the
// reserves are plain amounts), the cabin ticks only while the world has
// players, and a late tick never replays a backlog.
// ============================================================

#define LANDER_PROPELLANT 300
#define LANDER_SEATS 4
// Item entries the cargo hold carries on one flight.
#define LANDER_CARGO_MAX 20
#define LANDER_CONSOLE_RANGE 7
#define LANDER_DECK_RADIUS 1
#define LANDER_TICK_SECONDS 2
// Seconds of power for lights, heat and air at the start.
#define LANDER_POWER_SECONDS 10800
#define LANDER_OXYGEN_KPA 21
#define LANDER_INERT_KPA 79
#define LANDER_CO2_TARGET_KPA 0.4
#define LANDER_CABIN_C 20
// Chance in percent of a rough landing on a surveyed or an unsurveyed site.
#define LANDER_ROUGH_SURVEYED 5
#define LANDER_ROUGH_UNSURVEYED 50
#define LANDER_ROUGH_BRUTE 15
// One survey cell covers this many tiles each way (tools/procedural_maps/survey.py).
#define LANDER_CELL_TILES 5

// ---------------------------------------------------------------- propellant

/datum/reagent/rocket_propellant
	name = "Rocket propellant"
	id = "rocket_propellant"
	description = "A volatile two-part rocket fuel. Keep it away from flame and skin."
	taste_description = "burning metal"
	reagent_state = LIQUID
	color = "#c9d6a3"

/datum/reagent/rocket_propellant/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(6 * removed)

/datum/reagent/rocket_propellant/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		L.adjust_fire_stacks(amount / 2)

/datum/chemical_reaction/rocket_propellant
	name = "Rocket propellant"
	id = "rocket_propellant"
	result = "rocket_propellant"
	required_reagents = list("hydrazine" = 2, "nitric_acid" = 1)
	result_amount = 3

// ---------------------------------------------------------------- launch pad

/obj/structure/region_gate/trail_marker/launch_pad
	name = "launch pad"
	desc = "A blast-scarred steel apron for a crewed lander. It can only lead to a world a probe has mapped, or home to the mainland from one, and an admin must approve it."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"
	layer = TURF_LAYER + 0.1
	// The flight being sent, while its crew depart (see travel_extra()).
	var/tmp/list/pending_flight = null
	// The lander's hold, sent with the next crew member to depart.
	var/tmp/list/pending_cargo = null

// TRUE when a survey map of region id ships with the game and the epoch has
// reached that world (survey_region_open: the Moon from 1969, Mars from
// 2026), when id is an orbit region a rocket can reach (orbital_flight.dm),
// or when id is the mainland and this world is one a lander can reach
// (a flight home, never closed by the epoch).
/proc/space_flight_destination_ok(id)
	return (survey_region_ok(id) && !!get_space_survey_map(id) && survey_region_open(id)) || space_flight_return_ok(id) || space_flight_orbit_ok(id)

// TRUE when a pad here may fly back to region id: the mainland, from a
// mapped world or an orbit world that is not the mainland itself.
/proc/space_flight_return_ok(id)
	return istext(id) && istext(shard_group.mainland) && id == shard_group.mainland && istext(shard_group.region) && shard_group.region != id && (!!get_space_survey_map(shard_group.region) || orbit_world())

// Unlike a trail, a pad may lead to orbit.
/obj/structure/region_gate/trail_marker/launch_pad/peer_choices()
	var/list/choices = list()
	if (!shard_group.enabled)
		return choices
	for (var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		if (peer["kind"] == "RAILYARD" || !space_flight_destination_ok(id))
			continue
		choices["[peer["name"]] ([id])"] = id
	return choices

/obj/structure/region_gate/trail_marker/launch_pad/approve(id, by)
	if (!space_flight_destination_ok(id))
		return FALSE
	return ..()

/obj/structure/region_gate/trail_marker/launch_pad/closed_reason()
	if (!approved)
		if (requested_destination)
			return "The pad is waiting for an admin to approve flights to [region_trail_name(requested_destination)]."
		return "Use the pad to choose which mapped world it should fly to; an admin must approve it before anyone can launch."
	return ..()

// Crew arrive in their landed lander, never on the pad.
/obj/structure/region_gate/trail_marker/launch_pad/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/trail_marker/launch_pad/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	if (!approved)
		request(user)
		return
	to_chat(user, SPAN_NOTICE("Build a crewed lander beside the pad, fill it with propellant and strap in to fly to [destination_name()]."))

/obj/structure/region_gate/trail_marker/launch_pad/travel_extra(mob/living/human/H)
	if (!pending_flight || !length(pending_cargo))
		return pending_flight
	var/list/flight = pending_flight.Copy()
	flight["cargo"] = pending_cargo
	return flight

// ---------------------------------------------------------------- crewed lander

/obj/structure/crewed_lander
	name = "crewed lander"
	desc = "A squat craft with seats for four and a small sealed cabin. Fill it with rocket propellant beside an approved launch pad, strap in on its tile and launch."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "rocket"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	flammable = FALSE
	var/propellant = 0
	var/propellant_needed = LANDER_PROPELLANT
	// Propellant kept for one ascent home on a sortie to a surface world.
	var/ascent_propellant = LANDER_PROPELLANT / 2
	var/seats = LANDER_SEATS
	var/cargo_max = LANDER_CARGO_MAX
	// Reagent ids the tank takes. One kind fills it at a time; fuel_kind is
	// the kind in it while it holds any (methalox.dm adds methane-oxygen).
	var/list/fuels = list("rocket_propellant")
	var/fuel_kind = null
	// ckeys of the crew who strapped in; they must stay on the lander's tile.
	var/tmp/list/strapped = list()

/obj/structure/crewed_lander/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("[fuel_kind == "methalox" ? "Methalox" : "Propellant"]: [propellant]/[propellant_needed].[seats ? " Crew strapped in: [length(crew())]/[seats]." : ""] Cargo hold: [length(hold())]/[cargo_max]."))
	if (ascent_propellant)
		to_chat(user, SPAN_NOTICE("Fill it to [propellant_needed + ascent_propellant] for a sortie: it keeps enough for the ascent home after landing."))

/obj/structure/crewed_lander/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents && fuel_offered(W.reagents))
		var/took = add_propellant(W.reagents)
		if (took > 0)
			to_chat(user, SPAN_NOTICE("You fill \the [src] ([propellant]/[propellant_needed])."))
		else if (propellant >= propellant_needed + ascent_propellant)
			to_chat(user, SPAN_WARNING("\The [src] is already full."))
		else if (fuel_kind && propellant > 0)
			to_chat(user, SPAN_WARNING("\The [src]'s tank already holds [fuel_kind == "methalox" ? "methalox" : "rocket propellant"]. Fly it before you change fuel."))
		else
			to_chat(user, SPAN_WARNING("\The [src] burns only rocket propellant."))
		return
	if (istype(W))
		var/reason = stow_refusal(W)
		if (reason)
			to_chat(user, SPAN_WARNING(reason))
			return
		if (!user.drop_from_inventory(W, src))
			return
		to_chat(user, SPAN_NOTICE("You stow \the [W] in the cargo hold ([length(hold())]/[cargo_max])."))
		return
	return ..()

// ---------------------------------------------------------------- lunar kit

// Everything two people need for a short sortie on the surface, packed to fly
// in the hold. Use it to unpack it where you stand.
/obj/item/lunar_kit
	name = "lunar surface kit"
	desc = "A packed crate for a short surface sortie: two pressure suits, four air tanks, a suit patch, a rover battery and food and water for two people for three days. Use it to unpack it."
	icon = 'icons/obj/storage.dmi'
	icon_state = "densecrate"
	w_class = ITEM_SIZE_HUGE

var/global/list/lunar_kit_contents = list(
	/obj/item/clothing/suit/pressure_suit = 2,
	/obj/item/clothing/head/pressure_helmet = 2,
	/obj/item/pressure_tank = 4,
	/obj/item/pressure_suit_patch = 1,
	/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery = 1,
	/obj/item/weapon/reagent_containers/food/snacks/MRE/generic = 6,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen = 4)

/obj/item/lunar_kit/attack_self(mob/user)
	var/turf/T = get_turf(user)
	if (!T)
		return
	for (var/path in lunar_kit_contents)
		for (var/i in 1 to lunar_kit_contents[path])
			new path(T)
	to_chat(user, SPAN_NOTICE("You unpack \the [src]."))
	qdel(src)

// ---------------------------------------------------------------- cargo hold

// Space gear the hold carries besides what any traveller may (region_travel.dm).
var/global/list/space_cargo_types = list(
	/obj/item/habitat_kit,
	/obj/item/lunar_kit,
	/obj/item/habitat_sealant,
	/obj/item/pressure_tank,
	/obj/item/pressure_suit_patch,
	/obj/item/space_probe,
	/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery)

// Building stacks the hold carries by kind and amount. Exact types only.
var/global/list/space_cargo_stacks = list(
	"glass" = /obj/item/stack/material/glass,
	"plastic" = /obj/item/stack/material/plastic,
	"electronics" = /obj/item/stack/material/electronics,
	"water_ice" = /obj/item/stack/ore/ice)

// How an item flies in the hold, as region_travel_item_kind(), or null.
/proc/space_cargo_kind(obj/item/I)
	if (!istype(I))
		return null
	var/kind = region_travel_item_kind(I)
	if (kind)
		return kind
	if (istype(I, /obj/item/stack))
		for (var/good in space_cargo_stacks)
			if (I.type == space_cargo_stacks[good])
				return "stack:[good]"
		return null
	if (!length(I.contents) && space_cargo_type_allowed(I.type))
		return "type"
	return null

/proc/space_cargo_type_allowed(path)
	for (var/family in space_cargo_types)
		if (ispath(path, family))
			return TRUE
	return FALSE

// The path a cargo entry rebuilds, or null when it is not allowed.
/proc/space_cargo_path(kind, amount)
	if (!istext(kind) || !isnum(amount))
		return null
	var/path = region_travel_item_path(kind, amount)
	if (path)
		return path
	if (copytext(kind, 1, 7) == "stack:")
		var/obj/item/stack/S = space_cargo_stacks[copytext(kind, 7)]
		if (!S || amount < 1 || amount != round(amount) || amount > initial(S.max_amount))
			return null
		return S
	path = text2path(kind)
	if (!path || amount != 1 || !space_cargo_type_allowed(path))
		return null
	return path

// One cargo entry, list(kind, amount), for an item, or null.
/proc/space_cargo_entry(obj/item/I)
	var/kind = space_cargo_kind(I)
	if (!kind)
		return null
	if (kind == "type")
		return list("[I.type]", 1)
	if (copytext(kind, 1, 6) == "ammo:")
		return list(kind, region_travel_ammo_count(I))
	var/obj/item/stack/S = I
	return list(kind, S.amount)

// Rebuilds cargo entries in a crate at T. Returns the crate, or null.
/proc/space_cargo_unpack(list/cargo, turf/T)
	if (!length(cargo) || !isturf(T))
		return null
	var/obj/structure/closet/crate/C = new /obj/structure/closet/crate(T)
	C.name = "lander cargo"
	for (var/list/entry in cargo)
		var/path = space_cargo_path(entry[1], entry[2])
		if (!path)
			continue
		var/obj/item/I = ispath(path, /obj/item/stack) ? new path(C, entry[2]) : new path(C)
		if (istype(I, /obj/item/ammo_magazine))
			region_travel_fill_magazine(I, entry[2])
		else if (istype(I, /obj/item/weapon/gun/projectile))
			region_travel_unload_gun(I)
	return C

/obj/structure/crewed_lander/proc/hold()
	var/list/found = list()
	for (var/obj/item/I in contents)
		found += I
	return found

// Null when W can go in the hold, otherwise why not.
/obj/structure/crewed_lander/proc/stow_refusal(obj/item/W)
	if (length(hold()) >= cargo_max)
		return "The cargo hold is full."
	if (!space_cargo_kind(W))
		return "\The [W] will not survive the flight. The hold takes building materials, space gear, tools, packaged food and medicine, and empty containers."
	return null

/obj/structure/crewed_lander/proc/unload(mob/user)
	var/turf/T = get_turf(src)
	var/count = 0
	for (var/obj/item/I in hold())
		I.forceMove(T)
		count++
	if (user)
		to_chat(user, SPAN_NOTICE(count ? "You unload [count] item\s from the cargo hold." : "The cargo hold is empty."))
	return count

// The hold as cargo entries; anything that can no longer fly is set down.
/obj/structure/crewed_lander/proc/pack_cargo()
	var/list/cargo = list()
	for (var/obj/item/I in hold())
		var/list/entry = space_cargo_entry(I)
		if (entry && space_cargo_path(entry[1], entry[2]))
			cargo += list(entry)
		else
			I.forceMove(get_turf(src))
	return cargo

// TRUE when the tank holds the flight and an ascent home.
/obj/structure/crewed_lander/proc/sortie_ready()
	return ascent_propellant > 0 && propellant >= propellant_needed + ascent_propellant

// TRUE when R holds any fuel this craft burns.
/obj/structure/crewed_lander/proc/fuel_offered(datum/reagents/R)
	for (var/id in fuels)
		if (R && R.get_reagent_amount(id) > 0)
			return TRUE
	return FALSE

// The fuel id in R this tank can take now, or null: the kind already in the
// tank, or the first of fuels that R holds.
/obj/structure/crewed_lander/proc/fuel_in(datum/reagents/R)
	if (!R)
		return null
	if (propellant > 0 && fuel_kind)
		return R.get_reagent_amount(fuel_kind) > 0 ? fuel_kind : null
	for (var/id in fuels)
		if (R.get_reagent_amount(id) > 0)
			return id
	return null

/obj/structure/crewed_lander/proc/add_propellant(datum/reagents/R)
	var/id = fuel_in(R)
	if (!id)
		return 0
	var/amount = min(propellant_needed + ascent_propellant - propellant, R.get_reagent_amount(id))
	if (amount <= 0)
		return 0
	R.remove_reagent(id, amount)
	propellant += amount
	fuel_kind = id
	return amount

// Strapped-in crew still on the lander's tile, conscious and connected.
/obj/structure/crewed_lander/proc/crew()
	var/list/found = list()
	for (var/mob/living/human/H in get_turf(src))
		if (H.client && H.stat == CONSCIOUS && (H.client.ckey in strapped))
			found += H
	return found

/obj/structure/crewed_lander/proc/find_pad()
	for (var/obj/structure/region_gate/trail_marker/launch_pad/P in range(1, src))
		if (!QDELETED(P))
			return P
	return null

/obj/structure/crewed_lander/attack_hand(mob/user as mob)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client)
		return
	var/strapped_in = (H.client.ckey in strapped) && get_turf(H) == get_turf(src)
	var/list/options = list(strapped_in ? "Unstrap" : "Strap in", "Launch")
	if (length(hold()))
		options += "Unload hold"
	options += "Cancel"
	var/choice = WWinput(H, "Propellant [propellant]/[propellant_needed], crew [length(crew())]/[seats], cargo [length(hold())]/[cargo_max]. Use an item on it to stow it in the hold.", capitalize(name), "Cancel", options)
	if (QDELETED(src) || !H.client || !in_range(src, H) || H.incapacitated())
		return
	switch (choice)
		if ("Strap in")
			strap_in(H)
		if ("Unstrap")
			strapped -= H.client.ckey
			to_chat(H, SPAN_NOTICE("You unstrap from \the [src]."))
		if ("Launch")
			launch_prompt(H)
		if ("Unload hold")
			unload(H)

/obj/structure/crewed_lander/proc/strap_in(mob/living/human/H)
	if (get_turf(H) != get_turf(src))
		to_chat(H, SPAN_WARNING("Stand on \the [src] to strap in."))
		return FALSE
	if (length(crew()) >= seats)
		to_chat(H, SPAN_WARNING("Every seat is taken."))
		return FALSE
	strapped |= H.client.ckey
	to_chat(H, SPAN_NOTICE("You strap into \the [src]. Stay on its tile: you fly when a crewmate launches."))
	return TRUE

// Null when the lander may fly now, otherwise why not.
/obj/structure/crewed_lander/proc/launch_refusal(mob/living/human/H)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	if (!pad)
		return "\The [src] must stand beside a launch pad."
	var/reason = pad.closed_reason()
	if (reason)
		return reason
	if (propellant < propellant_needed)
		return "\The [src] needs [propellant_needed] units of rocket propellant ([propellant] loaded)."
	if (!(H in crew()))
		return "Strap in before you launch."
	reason = vehicle_refusal(pad.destination)
	if (reason)
		return reason
	// Orbit needs no survey map (orbital_flight.dm).
	if (space_flight_orbit_ok(pad.destination))
		return null
	if (!space_flight_return_ok(pad.destination) && !get_space_survey_map(pad.destination))
		return "There is no survey map of [pad.destination_name()] to land by."
	if (!space_flight_return_ok(pad.destination))
		var/closed = survey_region_closed_reason(pad.destination)
		if (closed)
			return closed
	return null

// Extra fields a craft adds to its flight to orbit (orbit_reusable.dm).
/obj/structure/crewed_lander/proc/flight_extras(list/flight)
	return

// Null when this craft can fly to destination, otherwise why not. A lander
// cannot reach orbit; a two-stage rocket flies nowhere else.
/obj/structure/crewed_lander/proc/vehicle_refusal(destination)
	if (space_flight_orbit_ok(destination))
		return "\The [src] cannot reach orbit. Build a two-stage rocket for that."
	return null

// Surveyed landing sites a nearby mission console holds for region, as
// list(label = list(x, y)).
/obj/structure/crewed_lander/proc/surveyed_sites(region)
	var/list/sites = list()
	var/datum/survey_map/M = get_space_survey_map(region)
	if (!M)
		return sites
	for (var/obj/structure/survey_console/C in range(LANDER_CONSOLE_RANGE, src))
		for (var/site in C.landing_sites_for(region))
			var/list/parts = splittext(site, ",")
			if (parts.len != 2)
				continue
			var/sx = text2num(parts[1])
			var/sy = text2num(parts[2])
			if (survey_landing_cell(M, sx, sy, 0))
				sites["Surveyed site [sx],[sy]"] = list(sx, sy)
	return sites

/obj/structure/crewed_lander/proc/launch_prompt(mob/living/human/H)
	var/reason = launch_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	var/region = pad.destination
	// A flight home lands at the mainland's usual arrival point, and a flight
	// to orbit at its capsule (orbital_flight.dm).
	var/orbital = space_flight_orbit_ok(region)
	if (space_flight_return_ok(region) || orbital)
		var/question = orbital ? "Launch everyone strapped in into orbit at [pad.destination_name()], with what they wear and carry? The capsule shelters you there for a few hours." : "Fly everyone strapped in home to [pad.destination_name()], with what they wear and carry?"
		var/home = WWinput(H, question, "Launch", "Cancel", list("Launch", "Cancel"))
		if (home != "Launch" || QDELETED(src) || !H.client || !in_range(src, H))
			return
		reason = launch_refusal(H)
		if (!reason && (find_pad() != pad || pad.destination != region))
			reason = "The launch pad changed."
		if (!reason)
			reason = launch(pad, null, null, H)
		if (reason)
			to_chat(H, SPAN_WARNING(reason))
		return
	var/list/sites = surveyed_sites(region)
	var/unsurveyed = "Anywhere flat (unsurveyed, rough landings likely)"
	var/list/options = list()
	for (var/label in sites)
		options += label
	options += unsurveyed
	var/choice = input(H, "Where should the lander set down on [pad.destination_name()]? Everyone strapped in flies, with what they wear and carry. [sortie_ready() ? "It keeps propellant for the ascent home." : "It cannot fly home again: fill it to [propellant_needed + ascent_propellant] for a sortie."]", "Launch") as null|anything in options
	if (!choice || QDELETED(src) || !H.client || !in_range(src, H))
		return
	// The prompt slept: check everything again.
	reason = launch_refusal(H)
	if (!reason && (find_pad() != pad || pad.destination != region))
		reason = "The launch pad changed."
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/list/site = sites[choice]
	var/result = launch(pad, site ? site[1] : null, site ? site[2] : null, H)
	if (result)
		to_chat(H, SPAN_WARNING(result))

// Sends every strapped-in crew member to the pad's world, landing at survey
// cell lx,ly (or any flat cell when null). Returns null once anyone left, or
// the reason nobody did.
/obj/structure/crewed_lander/proc/launch(obj/structure/region_gate/trail_marker/launch_pad/pad, lx = null, ly = null, mob/living/human/notify = null)
	var/destination = pad.destination
	var/homeward = space_flight_return_ok(destination)
	var/orbital = space_flight_orbit_ok(destination)
	var/surveyed = !isnull(lx)
	var/list/cell = null
	if (!homeward && !orbital)
		var/datum/survey_map/M = get_space_survey_map(pad.destination)
		if (!M)
			return "There is no survey map of [pad.destination_name()] to land by."
		cell = surveyed ? survey_landing_cell(M, lx, ly, 0) : survey_landing_cell(M, null, null, 0)
		if (!cell)
			return "There is no flat ground to land on there."
	// A sleeping world is woken first; that can take a while.
	if (shard_group.enabled && shard_group.peers[pad.destination] && shard_group.peers[pad.destination]["state"] != "UP")
		var/woke = shard_group.wake_peer(pad.destination, notify)
		if (woke)
			return woke
		if (QDELETED(src) || QDELETED(pad) || pad.destination != destination || !pad.approved)
			return "The launch was called off."
	var/lander_id = "[shard_group.region || "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]"
	var/list/flight
	if (homeward)
		flight = list("lander" = lander_id, "return" = 1)
	else if (orbital)
		flight = list("lander" = lander_id, "orbit" = 1)
		flight_extras(flight)
	else
		flight = list(
			"lander" = lander_id,
			"landing" = list(cell[1], cell[2]),
			"surveyed" = surveyed ? 1 : 0,
			"rough" = prob(surveyed ? LANDER_ROUGH_SURVEYED : LANDER_ROUGH_UNSURVEYED) ? 1 : 0)
		// A sortie keeps one ascent's propellant to fly the crew home again.
		if (sortie_ready())
			flight["sortie"] = 1
	var/departed = 0
	var/list/refusals = list()
	pad.pending_flight = flight
	// The hold flies with the first crew member who departs.
	var/list/cargo = pack_cargo()
	var/cargo_sent = 0
	for (var/mob/living/human/H in crew())
		pad.pending_cargo = (length(cargo) && !cargo_sent) ? cargo : null
		// Departures can wait on escrow, so the pad is checked for each one.
		var/reason = (QDELETED(pad) || pad.destination != destination || !pad.approved) ? "The launch pad changed." : pad.travel_refusal(H)
		if (!reason)
			var/list/items = H.region_travel_items()
			if (istext(items))
				reason = items
		if (!reason)
			H.record_persistence_owner()
			reason = pad.depart(H)
		if (reason == "departed")
			departed++
			if (pad.pending_cargo)
				cargo_sent = length(cargo)
				for (var/obj/item/I in hold())
					qdel(I)
		else
			refusals += "[H.real_name]: [reason]"
			to_chat(H, SPAN_WARNING("You stay behind: [reason]"))
	pad.pending_flight = null
	pad.pending_cargo = null
	if (!departed)
		return refusals.len ? "Nobody could fly. [jointext(refusals, " ")]" : "Nobody is strapped in."
	if (homeward)
		log_game("Crewed flight: [departed] crew left [x],[y],[z] for home at [pad.destination] (lander [flight["lander"]]).")
	else if (orbital)
		log_game("Crewed flight: [departed] crew left [x],[y],[z] for orbit at [pad.destination] (capsule [flight["lander"]]).")
	else
		log_game("Crewed flight: [departed] crew left [x],[y],[z] for [pad.destination] (lander [flight["lander"]], cell [cell[1]],[cell[2]], [surveyed ? "surveyed" : "unsurveyed"][flight["rough"] ? ", rough" : ""]).")
	if (cargo_sent)
		log_game("Crewed flight: lander [flight["lander"]] carried [cargo_sent] cargo item\s.")
	// Whatever did not fly stays on the pad.
	unload()
	visible_message(SPAN_DANGER("\The [src] roars off the pad on a column of fire!"))
	qdel(src)
	return null

// ---------------------------------------------------------------- payload

// TRUE when a travel payload's flight fields are absent or well formed.
/proc/space_flight_payload_ok(list/P)
	if (isnull(P["lander"]))
		return isnull(P["landing"]) && isnull(P["surveyed"]) && isnull(P["rough"]) && isnull(P["return"]) && isnull(P["orbit"]) && isnull(P["cargo"]) && isnull(P["sortie"]) && isnull(P["seats"])
	var/id = P["lander"]
	if (!istext(id) || !length(id) || length(id) > 64)
		return FALSE
	if (!isnull(P["cargo"]))
		var/list/cargo = P["cargo"]
		if (!islist(cargo) || !cargo.len || cargo.len > LANDER_CARGO_MAX)
			return FALSE
		for (var/list/entry in cargo)
			if (entry.len != 2 || !space_cargo_path(entry[1], entry[2]))
				return FALSE
		for (var/entry in cargo)
			if (!islist(entry))
				return FALSE
	// A flight home carries no landing: the crew arrive like any traveller.
	if (!isnull(P["return"]))
		return P["return"] == 1 && isnull(P["orbit"]) && isnull(P["landing"]) && isnull(P["surveyed"]) && isnull(P["rough"]) && isnull(P["sortie"]) && isnull(P["seats"])
	// A flight to orbit arrives in its capsule (orbital_flight.dm).
	if (!isnull(P["orbit"]))
		return P["orbit"] == 1 && isnull(P["landing"]) && isnull(P["surveyed"]) && isnull(P["rough"]) && isnull(P["sortie"]) && (isnull(P["seats"]) || space_flight_seats_ok(P["seats"]))
	var/list/cell = P["landing"]
	if (!islist(cell) || cell.len != 2)
		return FALSE
	for (var/v in cell)
		if (!isnum(v) || v < 1 || v > 1000 || v != round(v))
			return FALSE
	for (var/flag in list("surveyed", "rough"))
		if (!(P[flag] in list(0, 1)))
			return FALSE
	if (!isnull(P["sortie"]) && P["sortie"] != 1)
		return FALSE
	return TRUE

// ---------------------------------------------------------------- landed lander

var/global/list/landed_landers = list()

/turf/floor/lander_deck
	name = "lander deck"
	desc = "The sealed floor of a landed craft's cabin."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"

/turf/floor/lander_deck/proc/lander()
	for (var/obj/structure/landed_lander/L in range(LANDER_DECK_RADIUS, src))
		if (!QDELETED(L))
			return L
	return null

/turf/floor/lander_deck/outside_air_breathable()
	var/obj/structure/landed_lander/L = lander()
	return L ? L.cabin().breathable() : FALSE

/turf/floor/lander_deck/outside_ambient_c()
	var/obj/structure/landed_lander/L = lander()
	return L ? L.cabin().temperature : (orbit_world() ? orbit_ambient_c() : barren_ambient_c())

/obj/structure/bed/lander_bunk
	name = "lander bunk"
	desc = "A fold-down bunk in the lander's cabin. Sleep here to make this world your home."
	icon = 'icons/obj/bed_chair.dmi'
	icon_state = "bunk_bed"
	material = "steel"
	applies_material_colour = FALSE

/obj/structure/landed_lander
	name = "landed lander"
	desc = "A crewed lander resting on its legs. Its core keeps the cabin around it sealed, warm and breathable for a few hours."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "rocket"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	var/lander_id = null
	// Cabin air as plain numbers (habitat_ledger.dm), and what is left of the
	// reserves. Nothing here is a world.time stamp.
	var/cabin_oxygen = 0
	var/cabin_co2 = 0
	var/cabin_inert = 0
	var/cabin_temperature = LANDER_CABIN_C
	var/oxygen_reserve = 0
	var/scrubber_reserve = 0
	var/power_seconds = LANDER_POWER_SECONDS
	// A sortie lander kept enough propellant for one ascent home (1 or 0).
	var/ascent_ready = 0
	var/lift_seats = LANDER_SEATS
	var/lift_word = "lift off"
	// ckeys of the crew strapped in for the flight home. Runtime only.
	var/tmp/list/strapped = list()
	var/tmp/datum/habitat_ledger/air = null

/obj/structure/landed_lander/New()
	..()
	landed_landers |= src
	processing_objects |= src

/obj/structure/landed_lander/Destroy()
	landed_landers -= src
	processing_objects -= src
	air = null
	return ..()

// Reserves for a full crew over the power time.
/obj/structure/landed_lander/proc/fill_reserves()
	var/volume = deck_volume()
	cabin_oxygen = LANDER_OXYGEN_KPA * volume
	cabin_co2 = 0
	cabin_inert = LANDER_INERT_KPA * volume
	cabin_temperature = LANDER_CABIN_C
	oxygen_reserve = LANDER_SEATS * HABITAT_BREATH_PER_SECOND * LANDER_POWER_SECONDS
	scrubber_reserve = oxygen_reserve
	power_seconds = LANDER_POWER_SECONDS
	air = null

/obj/structure/landed_lander/proc/deck_volume()
	return (LANDER_DECK_RADIUS * 2 + 1) ** 2

/obj/structure/landed_lander/proc/cabin()
	if (!air)
		air = new /datum/habitat_ledger(deck_volume())
		if (!air.from_list(list("volume" = deck_volume(), "oxygen" = cabin_oxygen, "co2" = cabin_co2, "inert" = cabin_inert, "temperature" = cabin_temperature)))
			air.temperature = BARREN_AMBIENT_C
	return air

/obj/structure/landed_lander/proc/store_cabin()
	cabin_oxygen = air.oxygen
	cabin_co2 = air.co2
	cabin_inert = air.inert
	cabin_temperature = air.temperature

// Living people on the deck.
/obj/structure/landed_lander/proc/breathers()
	. = 0
	for (var/mob/living/human/H in range(LANDER_DECK_RADIUS, src))
		if (H.stat != DEAD && istype(get_turf(H), /turf/floor/lander_deck))
			.++

// Like every habitat ledger, the cabin runs only while someone is connected.
/obj/structure/landed_lander/process()
	if (!clients.len)
		return
	hazards_pulse()
	life_support(LANDER_TICK_SECONDS, breathers())

/obj/structure/landed_lander/proc/hazards_pulse()
	barren_hazards_pulse()

// The cold outside the cabin.
/obj/structure/landed_lander/proc/ambient_c()
	return barren_ambient_c()

// One bounded step: the crew breathe and the cabin cools, then, while there
// is power, the core tops the oxygen back up, scrubs CO2 and heats the cabin.
/obj/structure/landed_lander/proc/life_support(seconds, occupants)
	var/datum/habitat_ledger/L = cabin()
	if (!L.advance(seconds, occupants, 0, ambient_c()))
		return FALSE
	if (power_seconds > 0)
		power_seconds = max(0, power_seconds - habitat_clamp(seconds, 0, HABITAT_MAX_STEP_SECONDS))
		var/give = min(max(0, LANDER_OXYGEN_KPA * L.volume - L.oxygen), oxygen_reserve)
		if (give > 0)
			oxygen_reserve -= give
			L.add_gas(give)
		var/excess = min(max(0, L.co2 - LANDER_CO2_TARGET_KPA * L.volume), scrubber_reserve)
		if (excess > 0)
			scrubber_reserve -= L.scrub_co2(excess)
		L.temperature = LANDER_CABIN_C
	store_cabin()
	return TRUE

/obj/structure/landed_lander/examine(mob/user)
	..()
	var/datum/habitat_ledger/L = cabin()
	var/hours = round(power_seconds / 3600, 0.1)
	to_chat(user, SPAN_NOTICE("Cabin: [round(L.pressure_kpa())] kPa, [round(L.oxygen_kpa(), 0.1)] kPa oxygen, [round(L.temperature)] C. Power for about [hours] hour\s."))
	if (power_seconds <= 0)
		to_chat(user, SPAN_WARNING("The core is out of power: the cabin is no longer refreshed or heated."))

// Lays the deck and bunk around the core and fills the cabin.
/obj/structure/landed_lander/proc/deploy()
	var/turf/center = get_turf(src)
	if (!center)
		return FALSE
	for (var/turf/T in block(locate(max(1, center.x - LANDER_DECK_RADIUS), max(1, center.y - LANDER_DECK_RADIUS), center.z), locate(min(world.maxx, center.x + LANDER_DECK_RADIUS), min(world.maxy, center.y + LANDER_DECK_RADIUS), center.z)))
		if (!istype(T, /turf/floor/lander_deck))
			T.ChangeTurf(/turf/floor/lander_deck, FALSE, FALSE)
	var/turf/bunk = locate(max(1, center.x - LANDER_DECK_RADIUS), center.y, center.z)
	if (bunk && bunk != center)
		var/obj/structure/bed/lander_bunk/B = new(bunk)
		B.anchored = TRUE
	fill_reserves()
	return TRUE

// ---------------------------------------------------------------- lift-off

// TRUE when this lander can fly its crew home: a sortie lander keeps one
// ascent's propellant (orbital capsules always can, orbital_flight.dm).
/obj/structure/landed_lander/proc/can_lift_off()
	return ascent_ready == 1

/obj/structure/landed_lander/proc/lift_off_message()
	return "\The [src] lifts off on a column of fire, bound for home!"

// What the deck becomes once the lander is spent.
/obj/structure/landed_lander/proc/spent_turf()
	return moon_world() ? /turf/floor/dirt/dust/regolith/lunar : /turf/floor/dirt/dust/regolith

/obj/structure/landed_lander/proc/crew()
	var/list/found = list()
	for (var/mob/living/human/H in get_turf(src))
		if (H.client && H.stat == CONSCIOUS && (H.client.ckey in strapped))
			found += H
	return found

/obj/structure/landed_lander/attack_hand(mob/user as mob)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client)
		return
	if (!can_lift_off())
		to_chat(H, SPAN_NOTICE("\The [src] has no propellant left for the flight home. Build a launch pad and a lander here to leave."))
		return
	var/strapped_in = (H.client.ckey in strapped) && get_turf(H) == get_turf(src)
	var/word = capitalize(lift_word)
	var/choice = WWinput(H, "Crew strapped in for home: [length(crew())]/[lift_seats]. [word] spends \the [src].", capitalize(name), "Cancel", list(strapped_in ? "Unstrap" : "Strap in", word, "Cancel"))
	if (QDELETED(src) || !H.client || !in_range(src, H) || H.incapacitated())
		return
	if (choice == "Strap in")
		if (get_turf(H) != get_turf(src))
			to_chat(H, SPAN_WARNING("Stand on \the [src] to strap in."))
		else if (length(crew()) >= lift_seats)
			to_chat(H, SPAN_WARNING("Every seat is taken."))
		else
			strapped |= H.client.ckey
			to_chat(H, SPAN_NOTICE("You strap into \the [src]. Stay on its tile: you fly home when a crewmate gives the word."))
	else if (choice == "Unstrap")
		strapped -= H.client.ckey
		to_chat(H, SPAN_NOTICE("You unstrap from \the [src]."))
	else if (choice == word)
		deorbit_prompt(H)

// Null when the crew may fly home now, otherwise why not.
/obj/structure/landed_lander/proc/deorbit_refusal(mob/living/human/H)
	if (!can_lift_off())
		return "\The [src] has no propellant left for the flight home."
	if (!istext(shard_group.mainland) || !space_flight_return_ok(shard_group.mainland))
		return "There is no way home from here."
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	if (H && !(H in crew()))
		return "Strap in first."
	var/list/aboard = crew()
	var/list/crew_keys = list()
	for (var/mob/living/human/C in aboard)
		crew_keys += C.client.ckey
	for (var/mob/living/human/other in range(LANDER_DECK_RADIUS, src))
		if (other.stat != DEAD && !(other in aboard) && istype(get_turf(other), /turf/floor/lander_deck))
			return "Everyone in the cabin must strap in or leave it first."
	for (var/obj/structure/bed/lander_bunk/B in range(LANDER_DECK_RADIUS, src))
		if (B.persistence_bed_owner_ckey && !(B.persistence_bed_owner_ckey in crew_keys))
			return "Someone who is not strapped in keeps the bunk here as their home."
	return null

/obj/structure/landed_lander/proc/deorbit_prompt(mob/living/human/H)
	var/reason = deorbit_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/home = shard_group.mainland
	if (WWinput(H, "[capitalize(lift_word)] and fly everyone strapped in home to [region_trail_name(home)], with what they wear and carry? \The [src] is spent.", capitalize(lift_word), "Cancel", list("Go", "Cancel")) != "Go")
		return
	if (QDELETED(src) || !H.client || !in_range(src, H))
		return
	// The prompt slept: check everything again.
	reason = deorbit_refusal(H) || deorbit(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))

// Sends every strapped-in crew member home. Returns null once anyone left (the
// lander is then spent), or the reason nobody did.
/obj/structure/landed_lander/proc/deorbit(mob/living/human/notify = null)
	var/home = shard_group.mainland
	if (shard_group.enabled && shard_group.peers[home] && shard_group.peers[home]["state"] != "UP")
		var/woke = shard_group.wake_peer(home, notify)
		if (woke)
			return woke
		if (QDELETED(src))
			return "The flight home was called off."
	var/obj/structure/region_gate/capsule_hatch/hatch = new(get_turf(src))
	hatch.destination = home
	hatch.pending_flight = list("lander" = lander_id, "return" = 1)
	var/departed = 0
	var/list/refusals = list()
	for (var/mob/living/human/H in crew())
		var/reason = QDELETED(hatch) ? "The hatch jammed." : hatch.travel_refusal(H)
		if (!reason)
			var/list/items = H.region_travel_items()
			if (istext(items))
				reason = items
		if (!reason)
			H.record_persistence_owner()
			reason = hatch.depart(H)
		if (reason == "departed")
			departed++
		else
			refusals += "[H.real_name]: [reason]"
			to_chat(H, SPAN_WARNING("You stay behind: [reason]"))
	if (!QDELETED(hatch))
		qdel(hatch)
	if (!departed)
		return refusals.len ? "Nobody could leave. [jointext(refusals, " ")]" : "Nobody is strapped in."
	log_game("Crewed flight: [departed] crew left in [lander_id] from [x],[y],[z] for home at [home].")
	visible_message(SPAN_DANGER(lift_off_message()))
	spend()
	return null

// The lander is gone: its deck turns back to the ground and its bunk goes.
/obj/structure/landed_lander/proc/spend()
	var/turf/center = get_turf(src)
	if (center)
		for (var/obj/structure/bed/lander_bunk/B in range(LANDER_DECK_RADIUS, center))
			qdel(B)
		var/ground = spent_turf()
		for (var/turf/floor/lander_deck/T in range(LANDER_DECK_RADIUS, center))
			T.ChangeTurf(ground, FALSE, FALSE)
	qdel(src)

/proc/space_landed_lander(id)
	for (var/obj/structure/landed_lander/L in landed_landers)
		if (L.lander_id == id && !QDELETED(L))
			return L
	return null

// The level a lander sets down on: the top level whose ground there is
// barren (a generated barren region keeps its surface on top), else the top.
/proc/space_landing_z(x, y)
	for (var/z = world.maxz, z >= 1, z--)
		var/turf/T = locate(x, y, z)
		if (T && istype(T.loc, /area/caribbean/nomads/barren))
			return z
	return multiz_top_z()

// The centre tile for survey cell cx,cy: the first spot in the cell whose
// whole deck is clear, else the cell's middle.
/proc/space_landing_turf(cx, cy)
	var/x0 = (cx - 1) * LANDER_CELL_TILES + 1
	var/y0 = (cy - 1) * LANDER_CELL_TILES + 1
	var/mid_x = clamp(x0 + round(LANDER_CELL_TILES / 2), 1 + LANDER_DECK_RADIUS, world.maxx - LANDER_DECK_RADIUS)
	var/mid_y = clamp(y0 + round(LANDER_CELL_TILES / 2), 1 + LANDER_DECK_RADIUS, world.maxy - LANDER_DECK_RADIUS)
	if (mid_x < 1 || mid_y < 1)
		return null
	var/z = space_landing_z(mid_x, mid_y)
	for (var/y = y0 + LANDER_DECK_RADIUS, y <= y0 + LANDER_CELL_TILES - 1 - LANDER_DECK_RADIUS, y++)
		for (var/x = x0 + LANDER_DECK_RADIUS, x <= x0 + LANDER_CELL_TILES - 1 - LANDER_DECK_RADIUS, x++)
			if (space_deck_clear(x, y, z))
				return locate(x, y, z)
	return locate(mid_x, mid_y, z)

/proc/space_deck_clear(x, y, z)
	if (x - LANDER_DECK_RADIUS < 1 || y - LANDER_DECK_RADIUS < 1 || x + LANDER_DECK_RADIUS > world.maxx || y + LANDER_DECK_RADIUS > world.maxy)
		return FALSE
	for (var/turf/T in block(locate(x - LANDER_DECK_RADIUS, y - LANDER_DECK_RADIUS, z), locate(x + LANDER_DECK_RADIUS, y + LANDER_DECK_RADIUS, z)))
		if (T.density)
			return FALSE
		for (var/atom/movable/A in T)
			if (A.density)
				return FALSE
	return TRUE

// Where an arriving crew member of a flight appears: their flight's lander,
// built by the first arrival. Null for any other traveller, and for a flight
// refused back at its source (it comes back at the pad).
/proc/space_flight_arrival_turf(list/P, incoming)
	if (!incoming || !islist(P) || !istext(P["lander"]) || P["return"])
		return null
	if (P["orbit"])
		return orbit_capsule_arrival_turf(P)
	var/obj/structure/landed_lander/L = space_landed_lander(P["lander"])
	if (!L)
		var/list/cell = P["landing"]
		var/turf/T = space_landing_turf(cell[1], cell[2])
		if (!T)
			return null
		L = new /obj/structure/landed_lander(T)
		L.lander_id = P["lander"]
		L.ascent_ready = P["sortie"] == 1 ? 1 : 0
		L.deploy()
		log_game("Crewed flight: lander [L.lander_id] set down at [T.x],[T.y],[T.z] (survey cell [cell[1]],[cell[2]]).")
	return get_turf(L)

// The hold is unpacked beside whoever carried it (in the landed lander, at
// the mainland's arrival point, or back at the pad for a refused flight),
// and a rough landing shakes up the crew.
/proc/space_flight_arrived(mob/living/human/H, list/P, incoming)
	if (!istype(H) || !islist(P) || !istext(P["lander"]))
		return
	if (length(P["cargo"]))
		space_cargo_unpack(P["cargo"], get_turf(H))
	if (incoming && P["rough"])
		H.take_overall_damage(LANDER_ROUGH_BRUTE, 0, "rough landing")

// A departure replayed after a reload: the save still holds the lander with
// the hold that flew, so the carrier's lander goes too.
/proc/space_flight_replayed(mob/living/human/H, list/P)
	if (!istype(H) || !islist(P) || !length(P["cargo"]))
		return
	for (var/obj/structure/crewed_lander/L in get_turf(H))
		for (var/obj/item/I in L.hold())
			qdel(I)
		qdel(L)
