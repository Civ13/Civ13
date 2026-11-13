// Power points: distribution equipment that hands cable power to machines
// around it, so each machine no longer needs its own cable.
//
// A power point stands on a cable (wrench it down on one, or use a coil on it).
// Every machine that draws power within its reach, with no wall, closed door
// or window on the straight line between them, joins that cable as if it
// stood next to it. Machines join when the point is secured or a machine is
// built or moved in reach, and leave when they move out or the point goes.
// Nothing scans per tick: draw checks only compare distances.

#define POWER_POINT_LIMIT 256

var/global/list/power_points = list()

/obj/structure/power_point
	name = "power point"
	desc = "Hands cable power to machines around it."
	anchored = FALSE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	flammable = FALSE
	var/reach = 3 // tiles in every direction
	var/base_state = ""
	var/tmp/list/served = list()
	var/tmp/registered = FALSE

/obj/structure/power_point/New()
	..()
	if (power_points.len < POWER_POINT_LIMIT)
		power_points |= src
		registered = TRUE
	update_icon()

/obj/structure/power_point/on_runtime_spawn()
	..()
	if (cable_autolink_holds)
		cable_autolink_queue += src

/obj/structure/power_point/Destroy()
	release_all()
	detach_cable()
	power_points -= src
	registered = FALSE
	return ..()

/obj/structure/power_point/update_icon()
	if (base_state)
		icon_state = live_power() ? "[base_state]_live" : base_state

/obj/structure/power_point/proc/live_power()
	return anchored && powersource && isturf(powersource.loc) && powersource.powerflow > 0

/obj/structure/power_point/proc/in_service()
	return registered && anchored && isturf(loc) && powersource && isturf(powersource.loc) && powersource.loc == loc && (src in powersource.connections)

// True when nothing solid lies on the straight line from here to O: a wall,
// a closed door or other opaque structure, or a window.
/obj/structure/power_point/proc/line_clear(atom/O)
	var/turf/start = get_turf(src)
	var/turf/finish = get_turf(O)
	if (!start || !finish || start.z != finish.z)
		return FALSE
	if (start == finish)
		return TRUE
	for (var/turf/T in getline(start, finish))
		if (T == start)
			continue
		if (T.density)
			return FALSE
		for (var/obj/B in T)
			if (B == O || !B.density)
				continue
			if (B.opacity || istype(B, /obj/structure/window))
				return FALSE
	return TRUE

/obj/structure/power_point/proc/can_serve(obj/O)
	return O && O != src && !istype(O, /obj/structure/power_point) && O.powerneeded > 0 && isturf(O.loc) && O.z == z && get_dist(src, O) <= reach && line_clear(O)

// The cable hook: a served machine reaches this point's cable from its reach.
/obj/structure/power_point/power_point_serves(obj/O)
	return in_service() && O.power_point == src && O.z == z && get_dist(src, O) <= reach

/obj/structure/power_point/proc/attach(obj/O)
	if (!in_service() || !can_serve(O))
		return FALSE
	if (O.powersource && O.powersource != powersource)
		return FALSE
	O.powersource = powersource
	powersource.connections |= O
	O.power_point = src
	served |= O
	return TRUE

/obj/structure/power_point/proc/release(obj/O)
	served -= O
	if (!O)
		return
	if (O.power_point == src)
		O.power_point = null
	// A machine on or next to the cable keeps it, as if cabled by hand.
	if (powersource && O.powersource == powersource && (!isturf(O.loc) || get_dist(O, powersource) > 1 || O.z != powersource.z))
		powersource.update_power(-O.powerneeded, 1, O)
		powersource.connections -= O
		O.powersource = null
		O.powered = FALSE

/obj/structure/power_point/proc/release_all()
	for (var/obj/O in served.Copy())
		release(O)
	served.Cut()

// Joins every machine in reach that has no cable of its own. A machine
// already on this cable (restored from a save) is adopted again.
/obj/structure/power_point/proc/serve_nearby()
	if (!in_service())
		return 0
	var/count = 0
	for (var/obj/O in range(reach, src))
		if (O.powerneeded <= 0 || (O.powersource && O.powersource != powersource) || (O in served))
			continue
		if (attach(O))
			count++
	if (count)
		powersource.rebuild_supply()
	return count

/obj/structure/power_point/proc/attach_cable()
	if (!anchored || !isturf(loc))
		return FALSE
	if (!powersource)
		var/obj/structure/cable/C = locate(/obj/structure/cable) in loc
		if (!C)
			return FALSE
		powersource = C
	powersource.connections |= src
	update_icon()
	return TRUE

/obj/structure/power_point/proc/detach_cable()
	release_all()
	if (powersource)
		powersource.connections -= src
		powersource = null
	update_icon()

/obj/structure/power_point/after_load()
	..()
	served = list()
	if (anchored && isturf(loc))
		powersource = restored_port_cable(src)
		if (powersource)
			serve_nearby()
	update_icon()

/obj/structure/power_point/persistence_runtime_var(key)
	return (key in list("served", "registered")) || ..()

/obj/structure/power_point/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		detach_cable()
		anchored = FALSE

/obj/structure/power_point/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		detach_cable()
		anchored = FALSE

/obj/structure/power_point/attackby(obj/item/W, mob/user)
	var/mob/living/human/H = user
	if (istype(W, /obj/item/weapon/wrench))
		if (!istype(H) || H.stat != CONSCIOUS || get_dist(H, src) > 1)
			return
		if (anchored)
			detach_cable()
			anchored = FALSE
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			to_chat(user, "<span class='notice'>You unfasten \the [src]; the machines around it lose its power.</span>")
			return
		if (!isturf(loc) || !(locate(/obj/structure/cable) in loc))
			to_chat(user, "<span class='warning'>Lay a cable under \the [src] first.</span>")
			return
		anchored = TRUE
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		attach_cable()
		var/count = serve_nearby()
		to_chat(user, "<span class='notice'>You secure \the [src] on the cable. [count ? "It now feeds [count] machine\s nearby." : "No machine nearby needs it yet."]</span>")
		return
	if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored)
			to_chat(user, "<span class='warning'>Secure \the [src] with a wrench first.</span>")
			return
		if (in_service())
			to_chat(user, "There's already a cable connected here.")
			return
		var/obj/item/stack/cable_coil/CC = W
		var/obj/structure/cable/C = CC.place_turf(get_turf(src), user, turn(get_dir(user, src), 180))
		if (!C)
			return
		powersource = C
		attach_cable()
		var/count = serve_nearby()
		C.rebuild_supply()
		to_chat(user, "<span class='notice'>You connect the cable to \the [src][count ? "; it feeds [count] machine\s nearby" : ""].</span>")
		return
	..()

/obj/structure/power_point/attack_hand(mob/user)
	if (in_service())
		var/count = serve_nearby()
		to_chat(user, "<span class='notice'>You check \the [src]'s connections[count ? "; [count] more machine\s join it" : ""].</span>")
		return
	..()

/obj/structure/power_point/examine(mob/user)
	. = ..()
	if (!in_service())
		to_chat(user, "It is not connected. Secure it on a cable with a wrench.")
		return
	var/live = 0
	for (var/obj/O in served)
		if (O.power_point == src && O.powersource == powersource)
			live++
	to_chat(user, "It feeds machines up to [reach] tiles away with nothing solid between: [live] connected. Grid supply [powersource.powerflow], demand [powersource.currentflow].")

// ---------------------------------------------------------------- machines

// A machine looks for a power point when it is built or moved, and lets go
// of one that it has moved out of reach of.
/obj/proc/power_point_moved()
	if (power_point)
		var/obj/structure/power_point/P = power_point
		if (!istype(P) || !P.in_service() || !P.can_serve(src))
			if (istype(P))
				P.release(src)
			else
				power_point = null
	if (!powersource && powerneeded > 0 && isturf(loc))
		seek_power_point()

/obj/proc/seek_power_point()
	for (var/obj/structure/power_point/P in power_points)
		if (P.z == z && get_dist(P, src) <= P.reach && P.attach(src))
			P.powersource.rebuild_supply()
			return TRUE
	return FALSE

/obj/structure/on_runtime_spawn()
	..()
	if (powerneeded > 0 && power_points.len && !cable_autolink_holds && isturf(loc))
		seek_power_point()

/obj/structure/Move()
	. = ..()
	if (. && (power_point || (powerneeded > 0 && power_points.len)))
		power_point_moved()

// ---------------------------------------------------------------- types

/obj/structure/power_point/transformer
	name = "distribution transformer"
	desc = "Steps grid power down for the machines around it. Secure it on a cable with a wrench: every machine within five tiles, with no wall, closed door or window in between, draws from that cable."
	icon = 'icons/obj/powertransformer.dmi'
	icon_state = "powertransformer"
	reach = 5
	opacity = TRUE
	crushable = FALSE

// Placed in a map already secured; it joins the cable under it on load.
/obj/structure/power_point/transformer/secured
	anchored = TRUE
