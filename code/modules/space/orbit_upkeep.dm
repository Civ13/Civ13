// ============================================================
// Station upkeep: orbit decay and reboost (orbital stations, stage C)
// ------------------------------------------------------------
// Every station sinks slowly as thin air drags on it. The registry keeps each
// station's altitude in kilometres, keyed by party (plain numbers, never a
// world.time). It falls only while the world has players, with the space
// hazard clock (surface_hazards.dm), from 400 km towards 150 km.
//
// - Below 300 km the drag is noticeable and the station is warned.
// - Below 250 km the drag heats every module a little, and loose debris
//   strikes the station more often.
// - Below 200 km the station skims the top of the atmosphere: strong heating
//   and frequent hull breaches. Nothing is ever deleted; crews can always
//   reboost or patch.
//
// A reboost thruster on the station's plane burns rocket propellant to climb
// back up, to at most 420 km. Only the station's party can fire it.
// ============================================================

#define ORBIT_ALTITUDE_START 400
#define ORBIT_ALTITUDE_MAX 420
#define ORBIT_ALTITUDE_MIN 150
#define ORBIT_ALTITUDE_LOW 300
#define ORBIT_ALTITUDE_DRAG 250
#define ORBIT_ALTITUDE_SKIM 200
// Kilometres lost per second of play (about 30 km an hour).
#define ORBIT_DECAY_PER_SECOND 0.0083
// Heating of every module, degrees per second, by band.
#define ORBIT_DRAG_HEAT_PER_SECOND 0.05
#define ORBIT_SKIM_HEAT_PER_SECOND 0.2
// Chance per hazard minute of an extra debris strike, by band.
#define ORBIT_DRAG_STRIKE_CHANCE 20
#define ORBIT_SKIM_STRIKE_CHANCE 50
// Reboost thruster: propellant per burn, kilometres gained, tank size.
#define ORBIT_REBOOST_COST 20
#define ORBIT_REBOOST_KM 20
#define ORBIT_THRUSTER_TANK 200
#define ORBIT_REBOOST_DELAY 30

// ---------------------------------------------------------------- altitude

/obj/structure/orbit_registry/var/list/altitudes = list()

/proc/orbit_station_altitude(party)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !istext(party))
		return 0
	if (!islist(R.altitudes))
		R.altitudes = list()
	var/km = R.altitudes[party]
	if (!isnum(km) || km < ORBIT_ALTITUDE_MIN || km > ORBIT_ALTITUDE_MAX)
		km = isnum(km) ? clamp(km, ORBIT_ALTITUDE_MIN, ORBIT_ALTITUDE_MAX) : ORBIT_ALTITUDE_START
		R.altitudes[party] = km
	return km

/proc/orbit_set_station_altitude(party, km)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !istext(party) || !isnum(km))
		return FALSE
	if (!islist(R.altitudes))
		R.altitudes = list()
	R.altitudes[party] = clamp(km, ORBIT_ALTITUDE_MIN, ORBIT_ALTITUDE_MAX)
	return TRUE

// "high", "low", "drag" or "skim".
/proc/orbit_altitude_band(km)
	if (km < ORBIT_ALTITUDE_SKIM)
		return "skim"
	if (km < ORBIT_ALTITUDE_DRAG)
		return "drag"
	if (km < ORBIT_ALTITUDE_LOW)
		return "low"
	return "high"

// Parties with a station in this orbit.
/proc/orbit_station_parties()
	var/list/parties = list()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R)
		return parties
	for (var/key in R.owners)
		var/party = orbit_station_party(text2num(key))
		if (party && !(party in parties))
			parties += party
	return parties

/proc/orbit_station_announce(party, message)
	var/list/planes = orbit_station_planes(party)
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (istype(H) && (H.z in planes))
			to_chat(H, message)

// ---------------------------------------------------------------- upkeep

// One hazard step for every station. roll FALSE skips the random strikes.
/proc/orbit_upkeep_step(seconds, roll = TRUE)
	if (!orbit_world() || !isnum(seconds) || seconds <= 0)
		return FALSE
	orbit_wear_step(seconds)
	for (var/party in orbit_station_parties())
		var/before = orbit_station_altitude(party)
		var/after = max(ORBIT_ALTITUDE_MIN, before - ORBIT_DECAY_PER_SECOND * seconds)
		orbit_set_station_altitude(party, after)
		var/band = orbit_altitude_band(after)
		if (band != orbit_altitude_band(before))
			orbit_station_announce(party, orbit_band_warning(band))
		orbit_drag_station(party, band, seconds, roll)
	return TRUE

/proc/orbit_band_warning(band)
	switch (band)
		if ("low")
			return SPAN_WARNING("The station's orbit is sinking. Fire the reboost thruster before the drag gets worse.")
		if ("drag")
			return SPAN_DANGER("Thin air drags on the station: the hull warms and loose debris strikes more often.")
		if ("skim")
			return SPAN_DANGER("The station is skimming the top of the atmosphere! The hull is heating fast. Reboost now.")
	return SPAN_NOTICE("The station climbs back into a stable orbit.")

// Heats the modules of a dragging station and, on a roll, breaches one.
/proc/orbit_drag_station(party, band, seconds, roll)
	var/heat = band == "skim" ? ORBIT_SKIM_HEAT_PER_SECOND : (band == "drag" ? ORBIT_DRAG_HEAT_PER_SECOND : 0)
	if (!heat)
		return FALSE
	var/list/modules = list()
	for (var/level in orbit_station_planes(party))
		modules += orbit_station_modules(level)
	for (var/obj/structure/habitat_core/C in modules)
		var/datum/habitat_ledger/L = C.air()
		L.temperature += heat * seconds
		L.clamp_contents()
		C.store_air()
	if (roll && modules.len && prob(band == "skim" ? ORBIT_SKIM_STRIKE_CHANCE : ORBIT_DRAG_STRIKE_CHANCE))
		barren_meteor_strike(pick(modules))
	return TRUE

// ---------------------------------------------------------------- thruster

/obj/structure/orbit_thruster
	name = "reboost thruster"
	desc = "A rocket engine on a short truss, pointed along the orbit. Fill it with rocket propellant and fire it to lift the station back into a higher orbit."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "rocket"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	var/propellant = 0

/obj/structure/orbit_thruster/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Propellant: [round(propellant)]/[ORBIT_THRUSTER_TANK]. Each burn takes [ORBIT_REBOOST_COST] and climbs [ORBIT_REBOOST_KM] km."))
	var/party = orbit_station_party(z)
	if (party)
		to_chat(user, SPAN_NOTICE("The station is at [round(orbit_station_altitude(party))] km."))

/obj/structure/orbit_thruster/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents)
		var/amount = min(ORBIT_THRUSTER_TANK - propellant, W.reagents.get_reagent_amount("rocket_propellant"))
		if (amount <= 0)
			to_chat(user, SPAN_WARNING(propellant >= ORBIT_THRUSTER_TANK ? "\The [src] is full." : "\The [src] takes only rocket propellant."))
			return
		W.reagents.remove_reagent("rocket_propellant", amount)
		propellant += amount
		to_chat(user, SPAN_NOTICE("You fill \the [src] ([round(propellant)]/[ORBIT_THRUSTER_TANK])."))
		return
	return ..()

// Null when user may fire it now, otherwise why not.
/obj/structure/orbit_thruster/proc/reboost_refusal(mob/user)
	var/party = orbit_station_party(z)
	if (!orbit_world() || !party)
		return "\The [src] can only lift a station in orbit."
	if (user && !party_train_may_board(user, party))
		return "\The [src] belongs to [party_train_party_name(party)]."
	if (propellant < ORBIT_REBOOST_COST)
		return "\The [src] needs [ORBIT_REBOOST_COST] units of rocket propellant for a burn."
	if (orbit_station_altitude(party) >= ORBIT_ALTITUDE_MAX)
		return "The station is already as high as it can go."
	return null

// Burns once. Returns the new altitude, or 0.
/obj/structure/orbit_thruster/proc/reboost()
	var/party = orbit_station_party(z)
	if (!party || propellant < ORBIT_REBOOST_COST)
		return 0
	var/before = orbit_station_altitude(party)
	propellant -= ORBIT_REBOOST_COST
	orbit_set_station_altitude(party, before + ORBIT_REBOOST_KM)
	var/after = orbit_station_altitude(party)
	if (orbit_altitude_band(after) != orbit_altitude_band(before))
		orbit_station_announce(party, orbit_band_warning(orbit_altitude_band(after)))
	log_game("Orbit station: [party] reboosted from [round(before)] to [round(after)] km.")
	return after

/obj/structure/orbit_thruster/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	var/reason = reboost_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	if (WWinput(user, "Fire \the [src]? It burns [ORBIT_REBOOST_COST] units of propellant to climb [ORBIT_REBOOST_KM] km.", "Reboost", "Cancel", list("Fire", "Cancel")) != "Fire")
		return
	to_chat(user, SPAN_NOTICE("You run the burn sequence..."))
	if (!do_after(user, ORBIT_REBOOST_DELAY, src))
		return
	reason = reboost_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/km = reboost()
	visible_message(SPAN_NOTICE("\The [src] roars, and the station climbs to [round(km)] km."))
