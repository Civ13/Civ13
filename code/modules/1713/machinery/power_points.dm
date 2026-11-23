// Power points: distribution equipment that hands cable power to machines
// around it, so each machine no longer needs its own cable.
//
// A power point stands on a cable (wrench it down on one, or use a coil on it).
// Every machine that draws power within its reach, with no wall, closed door
// or window on the straight line between them, joins that cable as if it
// stood next to it. Machines join when the point is secured or a machine is
// built or moved in reach, and leave when they move out or the point goes.
// Movement and barrier edits refresh membership; nothing scans per tick.

#define POWER_POINT_LIMIT 256

var/global/list/power_points = list()
var/global/list/power_point_dirty_turfs

// Coalesce topology edits through construction/destruction and door animation.
/proc/power_point_barrier_changed(turf/T)
	if (!T || !power_points.len || cable_autolink_holds)
		return
	if (!power_point_dirty_turfs)
		power_point_dirty_turfs = list()
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(power_point_flush_barriers)), 1)
	power_point_dirty_turfs |= T

/proc/power_point_flush_barriers()
	var/list/changed = power_point_dirty_turfs
	power_point_dirty_turfs = null
	if (!length(changed))
		return
	var/list/candidates = list()
	// The registry is capped. Only scan local ranges of affected points.
	for (var/obj/structure/power_point/P in power_points)
		if (!P.in_service())
			continue
		for (var/turf/T in changed)
			if (P.z != T.z || get_dist(P, T) > P.reach)
				continue
			for (var/obj/O in range(P.reach, P))
				if (O.powerneeded > 0 && !istype(O, /obj/structure/power_point))
					candidates |= O
			break
	for (var/obj/O in candidates)
		O.power_point_moved()

/proc/power_point_barrier(obj/B)
	return B.density && (B.opacity || B.takes_wall_slot() || istype(B, /obj/structure/window))


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
	return !QDELETED(src) && registered && anchored && isturf(loc) && powersource && !QDELETED(powersource) && isturf(powersource.loc) && powersource.loc == loc && (src in powersource.connections)

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
			if (B != O && !QDELETED(B) && power_point_barrier(B))
				return FALSE
	return TRUE

/obj/structure/power_point/proc/can_serve(obj/O)
	return O && O != src && !istype(O, /obj/structure/power_point) && O.powerneeded > 0 && isturf(O.loc) && O.z == z && get_dist(src, O) <= reach && line_clear(O)

// The cable hook: a served machine reaches this point's cable from its reach.
/obj/structure/power_point/power_point_serves(obj/O)
	return in_service() && O.power_point == src && O.z == z && get_dist(src, O) <= reach

/obj/proc/power_point_has_direct_cable()
	var/obj/structure/cable/C = powersource
	return (!power_point || power_point.powersource != C) && C && !QDELETED(C) && isturf(loc) && isturf(C.loc) && z == C.z && get_dist(src, C) <= 1 && (src in C.connections)

/obj/proc/power_point_forget_owner()
	var/obj/structure/power_point/P = power_point
	if (istype(P))
		P.served -= src
	power_point = null

/obj/proc/power_point_unlink_source()
	var/obj/structure/cable/C = powersource
	if (C)
		if (!QDELETED(C))
			C.update_power(-powerneeded, 1, src)
		C.connections -= src
	powersource = null
	powered = FALSE

/obj/structure/power_point/proc/attach(obj/O)
	if (!in_service() || !can_serve(O) || O.power_point_has_direct_cable())
		return FALSE
	O.power_point_forget_owner()
	if (O.powersource && O.powersource != powersource)
		O.power_point_unlink_source()
	O.powersource = powersource
	powersource.connections |= O
	O.power_point = src
	served |= O
	return TRUE

/obj/structure/power_point/proc/release(obj/O)
	served -= O
	if (!O || O.power_point != src)
		return
	O.power_point = null
	// Never detach a foreign cable or a newer automatic owner through a stale entry.
	if (O.powersource && O.powersource == powersource)
		O.power_point_unlink_source()
	else if (!O.powersource)
		O.powered = FALSE

/obj/structure/power_point/proc/release_all()
	for (var/obj/O in served.Copy())
		release(O)
	served.Cut()

// Run the shared nearest-point selection even when a machine already has a
// point. A newly secured closer point can take over without stealing direct wiring.
/obj/structure/power_point/proc/serve_nearby()
	if (!in_service())
		return 0
	var/count = 0
	for (var/obj/O in range(reach, src))
		if (!can_serve(O))
			continue
		var/old_point = O.power_point
		O.power_point_moved()
		if (O.power_point == src && old_point != src)
			count++
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
	var/list/previous = served.Copy()
	release_all()
	if (powersource)
		powersource.connections -= src
		powersource = null
	update_icon()
	for (var/obj/O in previous)
		if (!QDELETED(O) && !O.power_point && !O.powersource)
			O.power_point_moved()

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
	if (is_tool(W, TOOL_WRENCH))
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
	to_chat(user, "It feeds machines up to [reach] tiles away with nothing solid between: [live] connected. Grid supply [power_text(powersource.powerflow)], demand [power_text(powersource.currentflow)].")

// ---------------------------------------------------------------- machines

// Re-evaluate on construction, movement and local geometry edits.
/obj/proc/power_point_moved()
	if (QDELETED(src) || istype(src, /obj/structure/power_point))
		return
	if (power_point_has_direct_cable())
		power_point_forget_owner()
		return
	if (seek_power_point())
		return
	var/obj/structure/power_point/P = power_point
	if (istype(P))
		P.release(src)
	else
		power_point = null
	if (powersource && !power_point_has_direct_cable())
		power_point_unlink_source()

/obj/proc/seek_power_point()
	if (power_point_has_direct_cable() || powerneeded <= 0 || !isturf(loc))
		return FALSE
	var/obj/structure/power_point/best = null
	var/best_dist = 0
	for (var/obj/structure/power_point/P in power_points)
		if (P.z != z || !P.in_service())
			continue
		var/distance = get_dist(P, src)
		if (distance > P.reach || (best && distance > best_dist))
			continue
		// Equal distance favors x, then y, then stable registry order for
		// map-authored points stacked on the exact same tile.
		if (best && distance == best_dist && (P.x > best.x || (P.x == best.x && P.y >= best.y)))
			continue
		if (!P.can_serve(src))
			continue
		best = P
		best_dist = distance
	if (!best)
		return FALSE
	if (power_point == best && powersource == best.powersource && (src in best.served) && (src in powersource.connections))
		return TRUE
	if (!best.attach(src))
		return FALSE
	best.powersource.rebuild_supply()
	return TRUE

/obj/structure/on_runtime_spawn()
	..()
	if (cable_autolink_holds || !isturf(loc))
		return
	if (power_point_barrier(src))
		power_point_barrier_changed(loc)
	if (powerneeded > 0 && power_points.len)
		power_point_moved()

/obj/covers/on_runtime_spawn()
	..()
	if (power_point_barrier(src))
		power_point_barrier_changed(get_turf(src))

/obj/covers/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous && power_point_barrier(src))
		power_point_barrier_changed(get_turf(previous))
		power_point_barrier_changed(get_turf(src))

/obj/covers/forceMove(atom/destination, special_event, list/throw_hop_token = null)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous && power_point_barrier(src))
		power_point_barrier_changed(get_turf(previous))
		power_point_barrier_changed(get_turf(src))

/obj/structure/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		power_point_structure_moved(previous)

/obj/structure/forceMove(atom/destination, special_event, list/throw_hop_token = null)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		power_point_structure_moved(previous)

/obj/structure/proc/power_point_structure_moved(atom/previous)
	if (power_point_barrier(src))
		power_point_barrier_changed(get_turf(previous))
		power_point_barrier_changed(get_turf(src))
	// Carrying deck fittings is atomic; don't detach a consumer before the
	// cable and its point have both arrived. The craft owns shore-link cuts.
	if (craft_carrying())
		return
	if (power_point || (powerneeded > 0 && power_points.len))
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

// ---------------------------------------------------------------- outlets

// A small outlet box fixed against a wall. It does not block movement.
/obj/structure/power_point/outlet
	name = "wall outlet"
	desc = "A wall-mounted outlet box. Secure it on a cable with a wrench: every machine within three tiles, with no wall, closed door or window in between, draws from that cable."
	icon = 'icons/obj/power_distribution.dmi'
	icon_state = "wall_outlet"
	base_state = "wall_outlet"
	density = FALSE
	reach = 3
	layer = 3.1

// Turn the box toward the nearest wall so it is drawn against it.
/obj/structure/power_point/outlet/proc/face_wall()
	if (!isturf(loc))
		return
	for (var/d in list(NORTH, EAST, WEST, SOUTH))
		var/turf/T = get_step(src, d)
		if (T && T.density)
			dir = d
			return

/obj/structure/power_point/outlet/on_runtime_spawn()
	..()
	face_wall()

/obj/structure/power_point/outlet/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_WRENCH) && !anchored)
		face_wall()
	..()

/obj/structure/power_point/outlet/secured
	anchored = TRUE

// ---------------------------------------------------------------- poles

#define POWER_POLE_SPAN 8 // longest overhead wire, in tiles
#define POWER_POLE_SPANS 4 // wires on one pole

// The pole a person has started an overhead wire from, by person.
var/global/list/power_pole_span_start = list()

// A wooden utility pole. Besides feeding machines around it, it carries
// overhead wires to other poles up to eight tiles away, so one grid can
// cross roads, fields and rivers without cable on the ground. A wire joins
// the cables under the two poles through the same runtime link the cable
// risers use, so the grid code walks it without a distance check.
/obj/structure/power_point/pole
	name = "utility pole"
	desc = "A wooden pole with a crossarm for overhead power lines. Secure it on a cable with a wrench; it feeds machines within three tiles, and a cable coil runs an overhead wire to another pole up to eight tiles away."
	icon = 'icons/obj/power_distribution.dmi'
	icon_state = "utility_pole"
	base_state = "utility_pole"
	reach = 3
	layer = 4.1
	var/list/span_poles = list() // poles this one has a wire to; saved
	var/tmp/list/span_images = null

/obj/structure/power_point/pole/secured
	anchored = TRUE

/obj/structure/power_point/pole/persistence_runtime_var(key)
	return key == "span_images" || ..()

/obj/structure/power_point/pole/proc/span_ok(obj/structure/power_point/pole/P)
	return istype(P) && P != src && !QDELETED(P) && P.z == z && get_dist(src, P) <= POWER_POLE_SPAN

// Joins this pole's cable to each partner's while both are in service.
/obj/structure/power_point/pole/proc/relink_spans()
	for (var/obj/structure/power_point/pole/P in span_poles.Copy())
		if (!span_ok(P))
			span_poles -= P
			continue
		// A partner restored later in the same load links back from its own after_load.
		if (!(src in P.span_poles) || !in_service() || !P.in_service())
			continue
		var/obj/structure/cable/A = powersource
		var/obj/structure/cable/B = P.powersource
		if (!A.riser_links)
			A.riser_links = list()
		if (!B.riser_links)
			B.riser_links = list()
		A.riser_links |= B
		B.riser_links |= A
	if (in_service())
		powersource.rebuild_supply()
	update_icon()
	update_span_overlays()

// Drops the links between this pole's cable and its partners' cables only.
/obj/structure/power_point/pole/proc/unlink_spans()
	var/obj/structure/cable/A = powersource
	if (!A || !A.riser_links)
		return
	for (var/obj/structure/power_point/pole/P in span_poles)
		var/obj/structure/cable/B = P.powersource
		if (!B)
			continue
		A.riser_links -= B
		if (B.riser_links)
			B.riser_links -= A
			if (!B.riser_links.len)
				B.riser_links = null
		if (!QDELETED(B))
			B.rebuild_supply()
	if (!A.riser_links.len)
		A.riser_links = null

// Takes down every wire on this pole, dropping the cable they used.
/obj/structure/power_point/pole/proc/cut_spans(refund = TRUE)
	if (!span_poles.len)
		return 0
	unlink_spans()
	var/pieces = 0
	for (var/obj/structure/power_point/pole/P in span_poles.Copy())
		pieces += max(1, get_dist(src, P))
		P.span_poles -= src
		P.update_icon()
		P.update_span_overlays()
	span_poles.Cut()
	if (refund && pieces && isturf(loc))
		var/obj/item/stack/cable_coil/C = new(loc)
		C.amount = min(pieces, C.max_amount)
		C.update_icon()
	if (powersource)
		powersource.rebuild_supply()
	update_icon()
	update_span_overlays()
	return pieces

/obj/structure/power_point/pole/proc/link_span(obj/structure/power_point/pole/P, mob/user)
	if (!span_ok(P))
		to_chat(user, "<span class='warning'>That pole is too far: an overhead wire spans at most [POWER_POLE_SPAN] tiles.</span>")
		return FALSE
	if (P in span_poles)
		to_chat(user, "<span class='warning'>These poles are already wired together.</span>")
		return FALSE
	if (span_poles.len >= POWER_POLE_SPANS || P.span_poles.len >= POWER_POLE_SPANS)
		to_chat(user, "<span class='warning'>A crossarm holds at most [POWER_POLE_SPANS] wires.</span>")
		return FALSE
	span_poles |= P
	P.span_poles |= src
	relink_spans()
	P.relink_spans()
	return TRUE

/obj/structure/power_point/pole/attach_cable()
	. = ..()
	if (.)
		relink_spans()

/obj/structure/power_point/pole/detach_cable()
	unlink_spans()
	..()
	update_span_overlays()

/obj/structure/power_point/pole/after_load()
	..()
	relink_spans()

/obj/structure/power_point/pole/Destroy()
	cut_spans(FALSE)
	power_pole_span_start -= src
	for (var/key in power_pole_span_start.Copy())
		if (power_pole_span_start[key] == src)
			power_pole_span_start -= key
	return ..()

/obj/structure/power_point/pole/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		cut_spans()

/obj/structure/power_point/pole/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		cut_spans()

/obj/structure/power_point/pole/attackby(obj/item/W, mob/user)
	var/mob/living/human/H = user
	if (is_tool(W, TOOL_WIRECUTTER))
		if (!istype(H) || H.stat != CONSCIOUS || get_dist(H, src) > 1)
			return
		if (!span_poles.len)
			to_chat(user, "There are no overhead wires on \the [src].")
			return
		cut_spans()
		playsound(loc, 'sound/items/Wirecutter.ogg', 100, TRUE)
		to_chat(user, "<span class='notice'>You take down the overhead wires on \the [src].</span>")
		return
	if (is_tool(W, TOOL_WRENCH) && anchored && span_poles.len)
		cut_spans()
		to_chat(user, "<span class='notice'>You take down its overhead wires first.</span>")
	if (istype(W, /obj/item/stack/cable_coil) && in_service())
		if (!istype(H) || H.stat != CONSCIOUS || get_dist(H, src) > 1)
			return
		var/obj/item/stack/cable_coil/CC = W
		var/obj/structure/power_point/pole/start = power_pole_span_start[H]
		if (!start || start == src || QDELETED(start) || !start.in_service())
			power_pole_span_start[H] = src
			to_chat(user, "<span class='notice'>You tie a wire to \the [src]. Use the coil on another secured pole within [POWER_POLE_SPAN] tiles to string it.</span>")
			return
		var/length = max(1, get_dist(start, src))
		if (!start.span_ok(src))
			to_chat(user, "<span class='warning'>The other pole is too far: an overhead wire spans at most [POWER_POLE_SPAN] tiles.</span>")
			power_pole_span_start -= H
			return
		if (CC.amount < length)
			to_chat(user, "<span class='warning'>You need [length] pieces of cable for this span.</span>")
			return
		if (start.link_span(src, user))
			CC.use(length)
			power_pole_span_start -= H
			playsound(loc, 'sound/items/deconstruct.ogg', 50, TRUE)
			to_chat(user, "<span class='notice'>You string an overhead wire between the poles.</span>")
		return
	..()

/obj/structure/power_point/pole/examine(mob/user)
	. = ..()
	if (span_poles.len)
		to_chat(user, "It carries [span_poles.len] overhead wire\s.")
