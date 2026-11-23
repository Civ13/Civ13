var/global/list/cable_colors = list(
	"yellow" = "#ffff00",
	"green" = "#00aa00",
	"blue" = "#1919c8",
	"pink" = "#ff3cc8",
	"orange" = "#ff8000",
	"cyan" = "#00ffff",
	"white" = "#ffffff",
	"red" = "#ff0000"
	)

///////////////////////////////
//CABLE STRUCTURE
///////////////////////////////


////////////////////////////////
// Definitions
////////////////////////////////

/* Cable directions (d1 and d2)


  9   1   5
	\ | /
  8 - 0 - 4
	/ | \
  10  2   6

If d1 = 0 and d2 = 0, there's no cable
If d1 = 0 and d2 = dir, it's a O-X cable, getting from the center of the tile to dir (knot cable)
If d1 = dir1 and d2 = dir2, it's a full X-X cable, getting from dir1 to dir2
By design, d1 is the smallest direction and d2 is the highest
*/

/obj/structure/cable
	name = "power cable"
	desc = "A flexible, superconducting insulated cable for power transfer."
	icon = 'icons/obj/machines/cables.dmi'
	icon_state = "horizontal" // or "vertical", or a corner such as "1-4" (cable_shapes.dm)
	layer = 1.95
	anchored = TRUE
	var/d1 = 0   // cable direction 1 (see above); a corner's first end
	var/d2 = 1   // cable direction 2 (see above); a corner's second end
	var/list/connections = list()
	not_movable = FALSE
	not_disassemblable = FALSE
	crushable = FALSE
	var/cable_color = "red"
	color = "#ff0000"
	var/usesound = 'sound/items/Wirecutter.ogg'
	var/powerflow = 0 //maximum powerflow in the network (total maxpower of all engines connected)
	var/list/power_consumers = list() // consumer => reserved demand
	var/currentflow = 0 //reserved demand in this connected component
	var/tilepos = "under"
	var/tiledir = "horizontal" // "horizontal", "vertical" or "corner" (cable_shapes.dm)

/obj/structure/cable/verb/hiding()
	set category = null
	set name = "Under/Over tiles"
	set src in range(1)

	if (!istype(usr, /mob/living/human))
		return
	if (tilepos == "over")
		tilepos = "under"
		layer = 1.95
		return

	else if (tilepos == "under")
		tilepos = "over"
		layer = MOB_LAYER - 0.1
		return

/obj/structure/cable/yellow
	cable_color = "yellow"
	color = "#ffff00"

/obj/structure/cable/green
	cable_color = "green"
	color = "#00aa00"

/obj/structure/cable/blue
	cable_color = "blue"
	color = "#1919c8"

/obj/structure/cable/pink
	cable_color = "pink"
	color = "#ff3cc8"

/obj/structure/cable/orange
	cable_color = "orange"
	color = "#ff8000"

/obj/structure/cable/cyan
	cable_color = "cyan"
	color = "#00ffff"

/obj/structure/cable/white
	cable_color = "white"
	color = "#ffffff"

// the power cable object
/obj/structure/cable/New()
	..()

	if (!cable_color)
		cable_color = pick(cable_colors)

	update_icon()

/obj/structure/cable/Destroy()					// called when a cable is deleted
	if (!isemptylist(connections))
		disconnect()
	return ..()									// then go ahead and delete the cable

/obj/structure/cable/Del()
	disconnect()
	..()

/obj/structure/cable/examine(mob/user)
	. = ..()
	rebuild_supply()
	to_chat(user, "Supply capacity: [power_text(powerflow)]. Reserved demand: [power_text(currentflow)]. Connected cables: [component_size].")


///////////////////////////////////
// General procedures
///////////////////////////////////

/obj/structure/cable/update_icon()
	icon_state = tiledir == "corner" ? "[d1]-[d2]" : tiledir

// Items usable on a cable :
//   - knife : cut it duh !
//   - Cable coil : merge cables
//   - Multitool : get the power currently passing through the cable
//
/obj/structure/cable/attackby(obj/item/W, mob/user, params)
	if(is_tool(W, TOOL_WIRECUTTER))
		var/mob/living/human/H = user
		if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || !H.item_is_in_hands(W) || H.z != z || get_dist(H, src) > 1 || !isturf(loc))
			return
		user.visible_message("[user] cuts the cable.", "<span class='notice'>You cut the cable.</span>")
		playsound(loc, usesound, 100, FALSE)
		var/coil_type = cable_coil_type(cable_color)
		var/obj/item/stack/cable_coil/salvage = new coil_type(loc)
		salvage.amount = 1
		salvage.cable_color = cable_color
		salvage.color = color
		salvage.update_icon()
		qdel(src)
		return
/*
	else if(W.tool_behaviour == TOOL_MULTITOOL)
		if(powernet && (powernet.avail > 0))		// is it powered?
			to_chat(user, "<span class='danger'>Total power: [DisplayPower(powernet.avail)]\nLoad: [DisplayPower(powernet.load)]\nExcess power: [DisplayPower(surplus())]</span>")
		else
			to_chat(user, "<span class='danger'>The cable is not powered.</span>")
		shock(user, 5, 0.2)
*/
	else
/*		if (connections.len >= 2)
			var/count = 0
			for(var/obj/structure/cable/CBL in connections)
				count+=1
			if (count >= 2)
				to_chat(user, "Too many connections! Use a connector.")
				return
*/
//		handlecable(W, user, params)
		return

//////////////////////////////////////////////
// Network handling helpers
//////////////////////////////////////////////

/obj/structure/cable/proc/get_connections()

	if (!isturf(loc))
		return
	var/turf/T
	//get matching cables nearby
	if(d1) //if not a node cable
		T = get_step(src, d1)
		if(T)
			for (var/obj/structure/cable/CB in range(1, src))
				if (cable_color == CB.cable_color)
					if (!(CB in connections))
						connections += CB
	return connections

// A consumer reaches its cable when it stands on or next to it, or when a
// power point on that cable serves it from further away (power_points.dm).
/obj/var/tmp/obj/power_point = null
// Renewed by a connected, live draw, never by component meters or rebuilds.
/obj/var/tmp/grid_power_request_until = 0

/obj/proc/power_point_serves(obj/O)
	return FALSE

/obj/proc/cable_reach(obj/structure/cable/C)
	if (!C || !isturf(loc) || z != C.z)
		return FALSE
	if (power_point && power_point.powersource == C)
		return power_point.power_point_serves(src)
	return get_dist(src, C) <= 1

// Scalar identities contain no cable references. Refresh from the live graph,
// rather than retaining cached topology across disconnects or imports.
var/global/cable_identity_sequence = 0
/obj/structure/cable/var/tmp/grid_serial = 0
/obj/structure/cable/var/tmp/component_id = 0
/obj/structure/cable/var/tmp/component_size = 0
/obj/structure/cable/var/tmp/rebuild_visits = 0
// world.time of the last full traversal that published this cable's totals.
/obj/structure/cable/var/tmp/rebuild_time = -1
// Engines that powered the last traversal, shared by every cable it reached.
/obj/structure/cable/var/tmp/list/rebuild_engines = null
// Local refusals and the shared component snapshot. Neither reserves power.
/obj/structure/cable/var/tmp/list/grid_denials = null
/obj/structure/cable/var/tmp/list/component_denials = null
// Cables on the level above or below joined through a pair of cable risers
// (cable_risers.dm). Runtime only: risers rebuild it from their positions.
/obj/structure/cable/var/tmp/list/riser_links = null

/obj/structure/cable/proc/grid_identity()
	if (!grid_serial)
		grid_serial = ++cable_identity_sequence
	return grid_serial

/obj/structure/cable/persistence_runtime_var(key)
	if (key in list("grid_serial", "component_id", "component_size", "rebuild_visits", "rebuild_time", "rebuild_engines", "riser_links", "grid_wire_loss", "grid_denials", "component_denials"))
		return TRUE
	return ..()

// Track only recent renewals from real consumers, including reservations shed
// by the allocator. The caller removes the reservation independently.
/obj/structure/cable/proc/record_grid_denial(obj/consumer, amount)
	if (amount <= 0 || consumer.grid_power_request_until <= world.time)
		return
	if (!grid_denials)
		grid_denials = list()
	grid_denials[consumer] = amount

// Reads the published set without walking the grid or touching allocations.
// Expired, disabled, disconnected or newly served requests stop counting even
// when no generator next causes a rebuild.
/obj/structure/cable/proc/grid_shortage(now, list/failed)
	var/shed = 0
	for (var/obj/consumer in component_denials)
		var/obj/structure/cable/C = consumer.powersource
		if (!C || !component_id || C.component_id != component_id || consumer.grid_power_request_until <= now)
			continue
		if (!(consumer in C.connections) || !consumer.cable_reach(C) || consumer.smart_power_cut() || C.power_consumers[consumer])
			continue
		var/amount = C.grid_denials ? C.grid_denials[consumer] : 0
		if (amount <= 0)
			continue
		shed += amount
		if (failed && failed.len < 6)
			failed[consumer] = amount
	return shed

//needed as this can, unlike other placements, disconnect cables
/obj/structure/cable/proc/disconnect()
	var/list/previous = connections.Copy()
	var/list/auto_retry = null
	if (riser_links)
		for (var/obj/structure/cable/linked in riser_links)
			if (linked.riser_links)
				linked.riser_links -= src
			previous |= linked
		riser_links = null
	connections.Cut()
	power_consumers.Cut()
	grid_denials = null
	component_denials = null
	powered = FALSE
	powerflow = 0
	currentflow = 0
	component_id = 0
	component_size = 0
	for (var/obj/OB in previous)
		if (istype(OB, /obj/structure/cable))
			var/obj/structure/cable/CB = OB
			CB.connections -= src
		else
			if (istype(OB, /obj/item/connector))
				var/obj/item/connector/J = OB
				J.forget_cable(src)
			if (OB.powersource == src)
				OB.grid_power_request_until = 0
				if (OB.power_point)
					if (!auto_retry)
						auto_retry = list()
					auto_retry += OB
				if (istype(OB, /obj/structure/civ_generator))
					var/obj/structure/civ_generator/G = OB
					G.stop_generation()
				OB.powersource = null
				OB.powered = FALSE
			if (istype(OB, /obj/structure/engine))
				var/obj/structure/engine/EN = OB
				EN.connections -= src
	for (var/obj/structure/cable/CB in previous)
		CB.rebuild_supply()
	for (var/obj/OB in auto_retry)
		OB.power_point_moved()

// One graph for delivery and storage. Ordinary cable links require local
// contact. Risers and overhead spans use reciprocal runtime links.
/obj/structure/cable/proc/enqueue_grid_neighbors(list/pending, list/discovered)
	for (var/obj/structure/cable/N in connections)
		if (discovered[N] || !isturf(N.loc) || N.z != z || get_dist(src, N) > 1 || !(src in N.connections))
			continue
		discovered[N] = TRUE
		pending += N
	for (var/obj/structure/cable/N in riser_links)
		if (discovered[N] || !isturf(N.loc) || !N.riser_links || !(src in N.riser_links))
			continue
		discovered[N] = TRUE
		pending += N

// Emergency machines can voluntarily be designated priority at a meter.
// This is an operator setting, not part of saved machine or cable state.
/obj/var/tmp/grid_power_priority = FALSE

// Keep all-or-nothing machine loads; never round an indivisible load to a
// fractional grant. Under normal capacity this never walks allocations again.
/obj/structure/cable/proc/shed_grid_reservations(list/cables, shortage, priority, obj/protected_load = null)
	var/removed = 0
	for (var/obj/structure/cable/C in cables)
		for (var/obj/load in C.power_consumers.Copy())
			if (load == protected_load || load.grid_power_priority != priority)
				continue
			var/amount = C.power_consumers[load]
			C.power_consumers -= load
			C.record_grid_denial(load, amount)
			load.powered = FALSE
			removed += amount
			if (removed >= shortage)
				return removed
	return removed

// Only preempt ordinary reservations when the priority load can really fit.
// A failed oversized request must not needlessly shut down other machines.
/obj/structure/cable/proc/can_preempt_ordinary_loads(list/cables, needed)
	var/available = 0
	for (var/obj/structure/cable/C in cables)
		for (var/obj/load in C.power_consumers)
			if (load.grid_power_priority)
				continue
			available += C.power_consumers[load]
			if (available >= needed)
				return TRUE
	return FALSE

// Capacity is instantaneous engine output, not accumulated energy. Visit each
// cable and engine once, including when a network contains loops or branches.
/obj/structure/cable/proc/rebuild_supply(obj/requester, request = 0)
	if (requester && (request <= 0 || requester.powersource != src || !(requester in connections) || !requester.cable_reach(src)))
		return FALSE
	if (requester)
		requester.grid_power_request_until = world.time + 50 // five seconds of retry grace
	var/list/pending = list(src)
	var/list/cables = list()
	var/list/discovered = list()
	discovered[src] = TRUE
	var/list/engines = list()
	var/list/running_engines = list()
	var/list/batteries = list()
	var/list/generators = list()
	var/capacity = 0
	var/demand = 0
	var/wire_loss = 0 // wire_materials.dm: cable that is not copper wastes supply
	var/index = 1
	var/identity = grid_identity()
	while (index <= pending.len)
		var/obj/structure/cable/CB = pending[index++]
		cables[CB] = TRUE
		if (cable_wire_materials[CB.cable_color])
			wire_loss += cable_wire_loss(CB.cable_color)
		identity = min(identity, CB.grid_identity())
		if (!isturf(CB.loc))
			continue
		for (var/obj/consumer in CB.power_consumers.Copy())
			if (consumer.powersource != CB || !(consumer in CB.connections) || !consumer.cable_reach(CB))
				CB.power_consumers -= consumer
			else
				demand += CB.power_consumers[consumer]
		for (var/obj/OB in CB.connections)
			if (!isturf(OB.loc) || get_dist(CB, OB) > 1 || CB.z != OB.z)
				continue
			if (istype(OB, /obj/structure/cable))
				continue
			else if (istype(OB, /obj/structure/engine))
				var/obj/structure/engine/EN = OB
				if (!(EN in engines) && (CB in EN.connections))
					engines += EN
					if (EN.on && !EN.broken && EN.maxpower > 0)
						var/charging = EN.battery_charge_epoch == round(world.time / 10) ? EN.battery_charge_power : 0
						capacity += max(0, EN.maxpower - charging)
						running_engines += EN
			else if (istype(OB, /obj/structure/civ_generator))
				var/obj/structure/civ_generator/G = OB
				if (!(G in generators) && G.powersource == CB)
					generators += G
					capacity += G.available_output()
			else if (istype(OB, /obj/structure/battery))
				var/obj/structure/battery/B = OB
				if (!(B in batteries) && B.powersource == CB)
					batteries += B
					capacity += B.available_output()
		CB.enqueue_grid_neighbors(pending, discovered)
	if (wire_loss > 0)
		capacity = cable_delivered(capacity, wire_loss)
	grid_wire_loss = wire_loss
	// A source or connection can go away between draws. Reconcile the live
	// reservations immediately: standard loads go before priority loads.
	if (demand > capacity)
		demand -= shed_grid_reservations(cables, demand - capacity, FALSE)
		if (demand > capacity)
			demand -= shed_grid_reservations(cables, demand - capacity, TRUE)
	var/accepted = FALSE
	if (requester)
		var/reserved = power_consumers[requester]
		var/shortage = request - (capacity - demand + reserved)
		if (shortage > 0 && requester.grid_power_priority && request <= capacity && can_preempt_ordinary_loads(cables, shortage))
			demand -= shed_grid_reservations(cables, shortage, FALSE, requester)
		if (capacity > 0 && capacity - demand + reserved >= request)
			power_consumers[requester] = request
			if (grid_denials)
				grid_denials -= requester
			demand += request - reserved
			accepted = TRUE
		else
			power_consumers -= requester
			demand -= reserved
			record_grid_denial(requester, request)
	var/list/denials = null
	for (var/obj/structure/cable/CB in cables)
		if (!CB.grid_denials)
			continue
		for (var/obj/consumer in CB.grid_denials.Copy())
			if (consumer.powersource != CB || !(consumer in CB.connections) || !consumer.cable_reach(CB) || consumer.grid_power_request_until <= world.time || CB.power_consumers[consumer])
				CB.grid_denials -= consumer
				continue
			if (!denials)
				denials = list()
			denials[consumer] = TRUE
		if (!CB.grid_denials.len)
			CB.grid_denials = null
	for (var/obj/structure/cable/CB in cables)
		CB.component_denials = denials
		CB.currentflow = demand
		CB.powerflow = capacity
		CB.powered = capacity > 0
		CB.component_id = identity
		CB.component_size = cables.len
		CB.rebuild_visits = cables.len
		CB.rebuild_time = world.time
		CB.rebuild_engines = running_engines
	return requester ? accepted : capacity

// Reservations are keyed by the consumer, so repeated checks are idempotent.
/obj/structure/cable/proc/update_power(var/powerval = 0, var/recheck = 0, obj/consumer)
	if (consumer)
		if (powerval > 0 && consumer.powersource == src && (consumer in connections))
			power_consumers[consumer] = powerval
		else
			power_consumers -= consumer
			if (grid_denials)
				grid_denials -= consumer
			if (consumer.powersource == src)
				consumer.grid_power_request_until = 0
	return rebuild_supply()

/obj/proc/draw_cable_power()
	if (!powersource)
		return FALSE
	// A smart hub switched this device off (smart_home.dm).
	if (smart_power_cut())
		powersource.update_power(-powerneeded, 1, src)
		return FALSE
	if (powerneeded <= 0)
		powersource.update_power(0, 1, src)
		return FALSE
	if (!(src in powersource.connections) || !cable_reach(powersource))
		powersource.update_power(-powerneeded, 1, src)
		return FALSE
	// A reservation that the last traversal, under a second ago, left within
	// capacity is still honoured. Sources and topology changes already
	// traverse at least once a second, so many consumers on one grid no longer
	// each walk the whole component every check. Anything else, including an
	// overloaded or unpowered component, takes the full traversal.
	if (powersource.power_consumers[src] == powerneeded && powersource.rebuild_time >= 0 && world.time - powersource.rebuild_time < 10 && powersource.powerflow > 0 && powersource.currentflow <= powersource.powerflow && powersource.reservation_engines_running())
		grid_power_request_until = world.time + 50 // renew recent-demand telemetry on the fast path, too
		return TRUE
	// Validate capacity and publish the reservation atomically in one traversal.
	return powersource.rebuild_supply(src, powerneeded)

// Engines can be switched off by code that never notifies the grid, so the
// fast path still sees a cut engine at once instead of up to a second late.
/obj/structure/cable/proc/reservation_engines_running()
	for (var/obj/structure/engine/EN in rebuild_engines)
		if (!EN.on || EN.broken || !EN.loc)
			return FALSE
	return TRUE

/obj/structure/cable/proc/power_on(var/maxpower = 0)
	return rebuild_supply()

/obj/structure/cable/proc/power_off(var/maxpower = 0)
	return rebuild_supply()



/obj/structure/cable/Move()
	var/atom/previous_location = loc
	. = ..()
	if (. && loc != previous_location)
		disconnect()

/obj/structure/cable/forceMove(atom/destination, var/special_event)
	var/atom/previous_location = loc
	. = ..()
	// A craft carries its wiring whole (craft/rigid_move.dm).
	if (. && loc != previous_location && !craft_carrying())
		disconnect()

// Plastic insulation and copper are both paid before cable is created.
/obj/item/stack/material/plastic/proc/make_insulated_cable(obj/item/stack/material/copper/conductor)
	var/turf/site = get_turf(src)
	if(gcDestroyed || gc_destroyed || !site || !can_use(1) || !conductor || conductor.gcDestroyed || conductor.gc_destroyed || !conductor.can_use(1))
		return FALSE
	conductor.use(1)
	use(1)
	new /obj/item/stack/cable_coil(site, 1)
	return TRUE

/obj/item/stack/material/plastic/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/stack/material/copper))
		if(!user || user.stat)
			return
		if(make_insulated_cable(W))
			to_chat(user, SPAN_NOTICE("You make insulated cable from the plastic and copper."))
		else
			to_chat(user, SPAN_WARNING("You need one plastic sheet and one copper ingot."))
		return
	..()
