// ============================================================
// Degaussing (docs/naval-mines.md): the counters to magnetic mines
// ------------------------------------------------------------
// Two ways to take a steel hull's magnetic signature
// (magnetic_signature.dm) down below what a magnetic mine feels:
//
//   - A degaussing coil: a fitting set on her deck and switched on. While it
//     runs it takes DEGAUSS_COIL_CUT percent off her signature. It needs power
//     as she moves: battery on a submarine, fuel oil on a turf-built ship, a
//     running engine on a built hull or modular boat. Without it the coil
//     trips out and the crew is told.
//   - A wiping (deperming): a wiping station on a quay, wired to a powered
//     cable grid and fed cable, wraps a hull lying alongside and takes
//     DEGAUSS_WIPE percent off. It wears off as she sails: DEGAUSS_WIPE_DECAY
//     percent a tile, as a steel hull picks the Earth's field back up.
//
// Nothing ticks: the wear and the coil's power are paid from the same move
// hooks that look for mines. The wipe is saved by whatever saves the craft
// (the ship's wheel, the tiller, the modular boat's axis); world.time is not.
// ============================================================

#define DEGAUSS_COIL_CUT 80
#define DEGAUSS_WIPE 70
#define DEGAUSS_WIPE_DECAY 0.1
#define DEGAUSS_WIPE_RANGE 2
#define DEGAUSS_WIPE_CABLE 20
#define DEGAUSS_WIPE_POWER 30
#define DEGAUSS_WIPE_TIME (2 MINUTES)
// What the coil costs: battery units a tile on a submarine, and the share of
// a hop's fuel oil on a turf-built ship.
#define DEGAUSS_COIL_BATTERY_PER_TILE 1
#define DEGAUSS_COIL_FUEL_SHARE 0.25

var/global/list/degaussing_coils = list()

/datum/craft
	// Percent of her signature a wiping still takes off (saved by her owner).
	var/magnetic_wipe = 0

// ---- The craft's side ----

// The coil switched on aboard her, or null.
/datum/craft/proc/running_coil()
	if (!body || !body.placed())
		return null
	for (var/obj/structure/degaussing_coil/D in degaussing_coils)
		if (D.on && !QDELETED(D) && isturf(D.loc) && body.contains(D.loc))
			return D
	return null

/datum/craft/magnetic_factor()
	. = clamp(1 - magnetic_wipe / 100, 0, 1)
	if (running_coil())
		. *= (100 - DEGAUSS_COIL_CUT) / 100

/datum/craft/magnetic_text()
	var/list/notes = list()
	if (magnetic_wipe >= 1)
		notes += "wiped, [round(magnetic_wipe)]% off"
	if (running_coil())
		notes += "degaussing coil on"
	return "Magnetic signature: [magnetic_reading(magnetic_signature())][notes.len ? " ([jointext(notes, ", ")])" : ""]."

// After every move: the wiping wears off and the coil is paid for.
/datum/craft/proc/magnetic_moved(tiles)
	if (tiles <= 0)
		return
	if (magnetic_wipe > 0)
		magnetic_wipe = max(0, magnetic_wipe - tiles * DEGAUSS_WIPE_DECAY)
	var/obj/structure/degaussing_coil/D = running_coil()
	if (D && body && !body.power_coil(tiles))
		D.trip(src)
	// Minesweeping gear streamed from her (naval/minesweeping.dm).
	if (mine_sweeps.len)
		sweep_moved(tiles)

// TRUE when the body could power a running coil over these tiles (and paid).
/datum/craft_body/proc/power_coil(tiles)
	return FALSE

// A turf-built ship burns a share of a hop's fuel oil; under sail she has
// no dynamo for it.
/datum/craft_body/template/power_coil(tiles)
	if (!vessel)
		return FALSE
	var/burn = vessel.fuel_burn(VESSEL_SPEED_SLOW)
	if (burn <= 0)
		return FALSE
	var/cost = max(1, round(burn * DEGAUSS_COIL_FUEL_SHARE))
	if (vessel.fuel < cost)
		return FALSE
	vessel.fuel -= cost
	return TRUE

// A built hull needs an engine running aboard.
/datum/craft_body/built/power_coil(tiles)
	if (!craft)
		return FALSE
	for (var/datum/craft_drive/fitted/engine/E in craft.drives)
		if (E.ready())
			return TRUE
	return FALSE

// A submarine draws on her battery; any other boat needs her engine running.
/datum/craft_body/axis/power_coil(tiles)
	if (!axis)
		return FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/S = axis
	if (istype(S))
		return S.battery_draw(tiles * DEGAUSS_COIL_BATTERY_PER_TILE)
	return axis.engine && axis.engine.on

// ---- The coil ----

/obj/structure/degaussing_coil
	name = "degaussing coil"
	desc = "Heavy copper cable wound on a steel frame, with a switch box. Set it on a steel ship's deck and switch it on to hide most of her magnetic field from magnetic mines. It needs power while she moves: her engine, or her battery on a submarine."
	icon = 'icons/obj/naval_gear.dmi'
	icon_state = "coil"
	anchored = FALSE
	density = TRUE
	flags = CONDUCT
	var/on = FALSE

/obj/structure/degaussing_coil/New()
	..()
	degaussing_coils += src
	update_icon()

/obj/structure/degaussing_coil/Destroy()
	degaussing_coils -= src
	return ..()

/obj/structure/degaussing_coil/update_icon()
	icon_state = on ? "coil_on" : "coil"

/obj/structure/degaussing_coil/proc/aboard()
	if (!isturf(loc))
		return null
	// A modular boat's craft is made the first time it is asked for.
	for (var/obj/structure/vehicleparts/frame/F in loc)
		if (F.axis)
			return craft_of_axis(F.axis)
	return craft_at(loc)

// Switched off because the power failed.
/obj/structure/degaussing_coil/proc/trip(datum/craft/C)
	if (!on)
		return
	on = FALSE
	update_icon()
	if (C)
		C.crew_message(SPAN_WARNING("The degaussing coil trips out: there is no power for it."))

/obj/structure/degaussing_coil/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (on)
		on = FALSE
		update_icon()
		H.visible_message(SPAN_NOTICE("[H] switches \the [src] off."))
		return
	var/datum/craft/C = aboard()
	if (!C)
		to_chat(H, SPAN_WARNING("\The [src] has to stand on a ship's deck to do anything."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Bolt \the [src] to the deck with a wrench first."))
		return
	on = TRUE
	update_icon()
	H.visible_message(SPAN_NOTICE("[H] switches \the [src] on. The copper hums."))
	to_chat(H, SPAN_NOTICE(C.magnetic_text()))

/obj/structure/degaussing_coil/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		if (on)
			to_chat(user, SPAN_WARNING("Switch it off first."))
			return
		anchored = !anchored
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		user.visible_message(SPAN_NOTICE("[user] [anchored ? "bolts \the [src] to" : "unbolts \the [src] from"] the deck."))
		return
	return ..()

/obj/structure/degaussing_coil/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("It is [on ? "on" : "off"][anchored ? "" : " and not bolted down"]."))

// ---- The wiping station ----

/obj/structure/wiping_station
	name = "wiping station"
	desc = "A cabinet of switchgear and a drum of heavy cable for wiping (deperming) a steel hull. Wire it to a powered cable, feed it cable coil, and use it while a ship lies alongside. A wiped hull shows much less of a magnetic field, until she has sailed it back."
	icon = 'icons/obj/naval_gear.dmi'
	icon_state = "wiping_station"
	anchored = TRUE
	density = TRUE
	flags = CONDUCT
	powerneeded = 0
	var/cable = 0
	var/tmp/busy = FALSE

/obj/structure/wiping_station/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("It holds [cable] length\s of cable; a wiping uses [DEGAUSS_WIPE_CABLE] and draws [DEGAUSS_WIPE_POWER] power."))

/obj/structure/wiping_station/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		var/obj/item/stack/cable_coil/S = W
		var/take = min(S.amount, DEGAUSS_WIPE_CABLE * 2 - cable)
		if (take <= 0)
			to_chat(user, SPAN_WARNING("\The [src] is full of cable."))
			return
		S.use(take)
		cable += take
		to_chat(user, SPAN_NOTICE("You feed [take] length\s of cable into \the [src]. It holds [cable]."))
		return
	return ..()

// The steel craft lying alongside, or null.
/obj/structure/wiping_station/proc/alongside()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	for (var/turf/N in range(DEGAUSS_WIPE_RANGE, T))
		if (N == T)
			continue
		var/datum/craft/C = craft_at(N)
		if (C)
			return C
	return null

// Why this craft cannot be wiped now, or null.
/obj/structure/wiping_station/proc/wipe_problem(datum/craft/C)
	if (!C)
		return "No ship lies alongside: she must be within [DEGAUSS_WIPE_RANGE] tiles of the station."
	if (C.speed > 0 && !C.anchored)
		return "\The [C.name] must stop alongside first."
	if (C.body && C.body.magnetic_base() <= 0)
		return "\The [C.name] has no steel in her to wipe."
	if (cable < DEGAUSS_WIPE_CABLE)
		return "The station needs [DEGAUSS_WIPE_CABLE] lengths of cable; it holds [cable]."
	return null

// Wipes her: TRUE when it took. Draws power and cable.
/obj/structure/wiping_station/proc/wipe(datum/craft/C)
	if (wipe_problem(C))
		return FALSE
	powerneeded = DEGAUSS_WIPE_POWER
	var/powered = draw_cable_power()
	powerneeded = 0
	draw_cable_power()
	if (!powered)
		return FALSE
	cable -= DEGAUSS_WIPE_CABLE
	C.magnetic_wipe = DEGAUSS_WIPE
	C.crew_message(SPAN_NOTICE("The wiping cables come off: [C.magnetic_text()]"))
	return TRUE

/obj/structure/wiping_station/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (busy)
		to_chat(H, SPAN_WARNING("A wiping is already under way."))
		return
	var/datum/craft/C = alongside()
	var/problem = wipe_problem(C)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return
	powerneeded = DEGAUSS_WIPE_POWER
	var/powered = draw_cable_power()
	powerneeded = 0
	draw_cable_power()
	if (!powered)
		to_chat(H, SPAN_WARNING("Wire the station to a cable with [DEGAUSS_WIPE_POWER] power to spare."))
		return
	busy = TRUE
	icon_state = "wiping_station_on"
	H.visible_message(SPAN_NOTICE("[H] runs the wiping cables round \the [C.name] and throws the switches."), SPAN_NOTICE("You run the wiping cables round \the [C.name]. Stay by the station for two minutes."))
	C.crew_message(SPAN_NOTICE("Wiping cables are run round the hull; she must lie still."))
	var/done = do_after(H, DEGAUSS_WIPE_TIME, src) && !QDELETED(C) && alongside() == C
	busy = FALSE
	icon_state = "wiping_station"
	if (!done || !wipe(C))
		to_chat(H, SPAN_WARNING("The wiping is broken off; nothing took."))
		return
	H.visible_message(SPAN_NOTICE("[H] winds the cables in. \The [C.name] has been wiped."))

// ---- Keeping the wipe across a save ----

/obj/structure/vessel_helm
	var/magnetic_wipe = 0

/obj/structure/vessel_helm/before_save()
	..()
	var/datum/craft/C = vessel ? craft_of_vessel(vessel, FALSE) : null
	magnetic_wipe = C ? C.magnetic_wipe : 0

/obj/structure/vessel_helm/after_load()
	..()
	if (magnetic_wipe > 0 && vessel)
		var/datum/craft/C = craft_of_vessel(vessel)
		if (C)
			C.magnetic_wipe = magnetic_wipe

/obj/structure/hull_tiller
	var/magnetic_wipe = 0

/obj/structure/hull_tiller/before_save()
	..()
	magnetic_wipe = craft ? craft.magnetic_wipe : 0

/obj/structure/hull_tiller/after_load()
	..()
	if (craft && magnetic_wipe > 0)
		craft.magnetic_wipe = magnetic_wipe

/obj/structure/vehicleparts/axis
	var/magnetic_wipe = 0

/obj/structure/vehicleparts/axis/before_save()
	..()
	magnetic_wipe = craft ? craft.magnetic_wipe : 0

/obj/structure/vehicleparts/axis/after_load()
	..()
	if (magnetic_wipe > 0)
		var/datum/craft/C = craft_of_axis(src)
		if (C)
			C.magnetic_wipe = magnetic_wipe
