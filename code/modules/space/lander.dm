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
	desc = "A blast-scarred steel apron for a crewed lander. It can only lead to a world a probe has mapped, and an admin must approve it."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"
	layer = TURF_LAYER + 0.1
	// The flight being sent, while its crew depart (see travel_extra()).
	var/tmp/list/pending_flight = null

// TRUE when a survey map of region id ships with the game.
/proc/space_flight_destination_ok(id)
	return survey_region_ok(id) && !!get_space_survey_map(id)

/obj/structure/region_gate/trail_marker/launch_pad/peer_choices()
	var/list/choices = ..()
	for (var/label in choices.Copy())
		if (!space_flight_destination_ok(choices[label]))
			choices -= label
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
	return pending_flight

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
	// ckeys of the crew who strapped in; they must stay on the lander's tile.
	var/tmp/list/strapped = list()

/obj/structure/crewed_lander/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Propellant: [propellant]/[LANDER_PROPELLANT]. Crew strapped in: [length(crew())]/[LANDER_SEATS]."))

/obj/structure/crewed_lander/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents)
		var/took = add_propellant(W.reagents)
		if (took > 0)
			to_chat(user, SPAN_NOTICE("You fill \the [src] ([propellant]/[LANDER_PROPELLANT])."))
		else if (propellant >= LANDER_PROPELLANT)
			to_chat(user, SPAN_WARNING("\The [src] is already full."))
		else
			to_chat(user, SPAN_WARNING("\The [src] burns only rocket propellant."))
		return
	return ..()

/obj/structure/crewed_lander/proc/add_propellant(datum/reagents/R)
	var/amount = min(LANDER_PROPELLANT - propellant, R.get_reagent_amount("rocket_propellant"))
	if (amount <= 0)
		return 0
	R.remove_reagent("rocket_propellant", amount)
	propellant += amount
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
	var/choice = WWinput(H, "Propellant [propellant]/[LANDER_PROPELLANT], crew [length(crew())]/[LANDER_SEATS].", "Crewed lander", "Cancel", list(strapped_in ? "Unstrap" : "Strap in", "Launch", "Cancel"))
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

/obj/structure/crewed_lander/proc/strap_in(mob/living/human/H)
	if (get_turf(H) != get_turf(src))
		to_chat(H, SPAN_WARNING("Stand on \the [src] to strap in."))
		return FALSE
	if (length(crew()) >= LANDER_SEATS)
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
	if (propellant < LANDER_PROPELLANT)
		return "\The [src] needs [LANDER_PROPELLANT] units of rocket propellant ([propellant] loaded)."
	if (!(H in crew()))
		return "Strap in before you launch."
	if (!get_space_survey_map(pad.destination))
		return "There is no survey map of [pad.destination_name()] to land by."
	return null

// Surveyed landing sites a nearby mission console holds for region, as
// list(label = list(x, y)).
/obj/structure/crewed_lander/proc/surveyed_sites(region)
	var/list/sites = list()
	var/datum/survey_map/M = get_space_survey_map(region)
	if (!M)
		return sites
	for (var/obj/structure/survey_console/C in range(LANDER_CONSOLE_RANGE, src))
		if (C.map_region != region)
			continue
		for (var/site in C.landing_sites)
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
	var/list/sites = surveyed_sites(region)
	var/unsurveyed = "Anywhere flat (unsurveyed, rough landings likely)"
	var/list/options = list()
	for (var/label in sites)
		options += label
	options += unsurveyed
	var/choice = input(H, "Where should the lander set down on [pad.destination_name()]? Everyone strapped in flies, with what they wear and carry.", "Launch") as null|anything in options
	if (!choice || QDELETED(src) || !H.client || !in_range(src, H))
		return
	// The prompt slept: check everything again.
	reason = launch_refusal(H)
	if (!reason && find_pad() != pad)
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
	var/datum/survey_map/M = get_space_survey_map(pad.destination)
	if (!M)
		return "There is no survey map of [pad.destination_name()] to land by."
	var/surveyed = !isnull(lx)
	var/list/cell = surveyed ? survey_landing_cell(M, lx, ly, 0) : survey_landing_cell(M, null, null, 0)
	if (!cell)
		return "There is no flat ground to land on there."
	// A sleeping world is woken first; that can take a while.
	if (shard_group.enabled && shard_group.peers[pad.destination] && shard_group.peers[pad.destination]["state"] != "UP")
		var/woke = shard_group.wake_peer(pad.destination, notify)
		if (woke)
			return woke
		if (QDELETED(src) || QDELETED(pad))
			return "The launch was called off."
	var/list/flight = list(
		"lander" = "[shard_group.region || "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]",
		"landing" = list(cell[1], cell[2]),
		"surveyed" = surveyed ? 1 : 0,
		"rough" = prob(surveyed ? LANDER_ROUGH_SURVEYED : LANDER_ROUGH_UNSURVEYED) ? 1 : 0)
	var/departed = 0
	var/list/refusals = list()
	pad.pending_flight = flight
	for (var/mob/living/human/H in crew())
		var/reason = pad.travel_refusal(H)
		if (!reason)
			var/list/items = H.region_travel_items()
			if (istext(items))
				reason = items
		if (!reason)
			H.record_persistence_owner()
			reason = pad.depart(H)
		if (reason == "departed")
			departed++
		else
			refusals += "[H.real_name]: [reason]"
			to_chat(H, SPAN_WARNING("You stay behind: [reason]"))
	pad.pending_flight = null
	if (!departed)
		return refusals.len ? "Nobody could fly. [jointext(refusals, " ")]" : "Nobody is strapped in."
	log_game("Crewed flight: [departed] crew left [x],[y],[z] for [pad.destination] (lander [flight["lander"]], cell [cell[1]],[cell[2]], [surveyed ? "surveyed" : "unsurveyed"][flight["rough"] ? ", rough" : ""]).")
	visible_message(SPAN_DANGER("\The [src] roars off the pad on a column of fire!"))
	qdel(src)
	return null

// ---------------------------------------------------------------- payload

// TRUE when a travel payload's flight fields are absent or well formed.
/proc/space_flight_payload_ok(list/P)
	if (isnull(P["lander"]))
		return isnull(P["landing"]) && isnull(P["surveyed"]) && isnull(P["rough"])
	var/id = P["lander"]
	if (!istext(id) || !length(id) || length(id) > 64)
		return FALSE
	var/list/cell = P["landing"]
	if (!islist(cell) || cell.len != 2)
		return FALSE
	for (var/v in cell)
		if (!isnum(v) || v < 1 || v > 1000 || v != round(v))
			return FALSE
	for (var/flag in list("surveyed", "rough"))
		if (!(P[flag] in list(0, 1)))
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
	return L ? L.cabin().temperature : barren_ambient_c()

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
	barren_hazards_pulse()
	life_support(LANDER_TICK_SECONDS, breathers())

// One bounded step: the crew breathe and the cabin cools, then, while there
// is power, the core tops the oxygen back up, scrubs CO2 and heats the cabin.
/obj/structure/landed_lander/proc/life_support(seconds, occupants)
	var/datum/habitat_ledger/L = cabin()
	if (!L.advance(seconds, occupants, 0, barren_ambient_c()))
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
	return world.maxz

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
	if (!incoming || !islist(P) || !istext(P["lander"]))
		return null
	var/obj/structure/landed_lander/L = space_landed_lander(P["lander"])
	if (!L)
		var/list/cell = P["landing"]
		var/turf/T = space_landing_turf(cell[1], cell[2])
		if (!T)
			return null
		L = new /obj/structure/landed_lander(T)
		L.lander_id = P["lander"]
		L.deploy()
		log_game("Crewed flight: lander [L.lander_id] set down at [T.x],[T.y],[T.z] (survey cell [cell[1]],[cell[2]]).")
	return get_turf(L)

// A rough landing shakes up the crew.
/proc/space_flight_arrived(mob/living/human/H, list/P, incoming)
	if (!incoming || !istype(H) || !islist(P) || !istext(P["lander"]) || !P["rough"])
		return
	H.take_overall_damage(LANDER_ROUGH_BRUTE, 0, "rough landing")
