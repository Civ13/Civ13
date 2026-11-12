// ============================================================
// Minesweeping (docs/naval-mines.md)
// ------------------------------------------------------------
// Two fittings a ship streams astern to clear mines ahead of the fleet. Both
// are bolted to a deck and streamed or recovered by hand, and both act after
// every move the ship makes (from craft.magnetic_moved(), before the mines
// near her feel her):
//
//   - A magnetic sweep: a reel of buoyant electric cable. While streamed and
//     powered (the same power as a degaussing coil: battery on a submarine,
//     fuel oil on a turf-built ship, a running engine otherwise) its pulses set
//     off every magnetic mine within SWEEP_MAGNETIC_REACH tiles of the reel,
//     where they lie. A mine close aboard still hurts her, so sweep in a wooden
//     or wiped ship and keep the sweep well out ahead of the steel ships.
//   - An Oropesa sweep: a wire towed out to the side by a float and an otter
//     board, with cutters. While streamed and the ship is under way it cuts the
//     moorings of contact mines 1 to SWEEP_OROPESA_REACH tiles off her hull
//     (never one right under her). A cut mine bobs to the surface where anyone
//     can see it: shoot it, or take it out of the water with a wrench.
// ============================================================

#define SWEEP_MAGNETIC_REACH 6
#define SWEEP_OROPESA_REACH 3

var/global/list/mine_sweeps = list()

/obj/structure/mine_sweep
	name = "minesweeping gear"
	icon = 'icons/obj/naval_gear.dmi'
	anchored = FALSE
	density = TRUE
	flags = CONDUCT
	var/streamed = FALSE
	var/base_state = "sweep_reel"

/obj/structure/mine_sweep/New()
	..()
	mine_sweeps += src
	update_icon()

/obj/structure/mine_sweep/Destroy()
	mine_sweeps -= src
	return ..()

/obj/structure/mine_sweep/update_icon()
	icon_state = streamed ? "[base_state]_on" : base_state

/obj/structure/mine_sweep/proc/aboard()
	if (!isturf(loc))
		return null
	for (var/obj/structure/vehicleparts/frame/F in loc)
		if (F.axis)
			return craft_of_axis(F.axis)
	return craft_at(loc)

// Sweeps once after the ship moved. Returns how many mines it dealt with.
/obj/structure/mine_sweep/proc/sweep(datum/craft/C, tiles)
	return 0

/obj/structure/mine_sweep/proc/recover(datum/craft/C, reason)
	if (!streamed)
		return
	streamed = FALSE
	update_icon()
	if (C && reason)
		C.crew_message(SPAN_WARNING(reason))

/obj/structure/mine_sweep/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (streamed)
		recover(null)
		H.visible_message(SPAN_NOTICE("[H] winds \the [src] back in."))
		return
	var/datum/craft/C = aboard()
	if (!C)
		to_chat(H, SPAN_WARNING("\The [src] has to stand on a ship's deck to be streamed."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Bolt \the [src] to the deck with a wrench first."))
		return
	streamed = TRUE
	update_icon()
	H.visible_message(SPAN_NOTICE("[H] streams \the [src] over the side."))

/obj/structure/mine_sweep/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		if (streamed)
			to_chat(user, SPAN_WARNING("Wind it in first."))
			return
		anchored = !anchored
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		user.visible_message(SPAN_NOTICE("[user] [anchored ? "bolts \the [src] to" : "unbolts \the [src] from"] the deck."))
		return
	return ..()

/obj/structure/mine_sweep/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("It is [streamed ? "streamed" : "wound in"][anchored ? "" : " and not bolted down"]."))

// ---- The magnetic sweep ----

/obj/structure/mine_sweep/magnetic
	name = "magnetic sweep reel"
	desc = "A drum of thick, buoyant electric cable. Streamed astern and powered, it pulses a magnetic field through the water that sets off magnetic mines around it. It needs power while the ship moves: her engine, or her battery on a submarine."
	icon_state = "sweep_reel"
	base_state = "sweep_reel"

/obj/structure/mine_sweep/magnetic/sweep(datum/craft/C, tiles)
	. = 0
	if (!streamed || !C || !C.body)
		return
	if (!C.body.power_coil(tiles))
		recover(C, "The magnetic sweep goes dead: there is no power for it. It is wound in.")
		return
	for (var/obj/structure/naval_mine/M in naval_mines.Copy())
		if (QDELETED(M) || M.fired || !M.magnetic || M.z != z)
			continue
		if (get_dist(M, src) <= SWEEP_MAGNETIC_REACH)
			M.detonate(null)
			.++

// ---- The Oropesa sweep ----

/obj/structure/mine_sweep/oropesa
	name = "Oropesa sweep"
	desc = "A drum of cutting wire with an orange float and a steel otter board. Streamed while the ship is under way, it cuts the moorings of contact mines off to her sides, and they bob up to be shot."
	icon_state = "oropesa"
	base_state = "oropesa"

/obj/structure/mine_sweep/oropesa/sweep(datum/craft/C, tiles)
	. = 0
	if (!streamed || !C || !C.body || tiles <= 0)
		return
	var/list/B = C.body.mine_box()
	if (!B)
		return
	for (var/obj/structure/naval_mine/M in naval_mines)
		if (QDELETED(M) || M.fired || M.magnetic || M.z != B[5] || M.surfaced)
			continue
		var/dx = max(B[1] - M.x, 0, M.x - B[3])
		var/dy = max(B[2] - M.y, 0, M.y - B[4])
		var/d = max(dx, dy)
		if (d >= 1 && d <= SWEEP_OROPESA_REACH)
			M.surface()
			.++
	if (.)
		C.crew_message(SPAN_NOTICE("The Oropesa sweep's cutters bite: [.] mine\s bob up to the surface."))

// A mine whose mooring was cut floats up in plain sight. It still goes off on
// a hull, a bullet or a blast.
/obj/structure/naval_mine
	var/surfaced = FALSE

/obj/structure/naval_mine/proc/surface()
	if (surfaced)
		return
	surfaced = TRUE
	icon_state = "contact_surfaced"
	alpha = 255
	name = "floating [initial(name)]"
	desc = "A mine cut from its mooring, bobbing on the surface. Shoot it from a safe distance."
	visible_message(SPAN_WARNING("A horned mine bobs up to the surface!"))

// ---- After every move ----

/datum/craft/proc/sweep_moved(tiles)
	if (!mine_sweeps.len || !body || !body.placed())
		return 0
	. = 0
	for (var/obj/structure/mine_sweep/S in mine_sweeps)
		if (!S.streamed || QDELETED(S) || !isturf(S.loc) || !body.contains(S.loc))
			continue
		. += S.sweep(src, tiles)
