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
	icon_state = "0-1"
	layer = 1.95
	anchored = TRUE
	var/d1 = 0   // cable direction 1 (see above)
	var/d2 = 1   // cable direction 2 (see above)
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
	var/tiledir = "horizontal"

/obj/structure/cable/verb/hiding()
	set category = null
	set name = "Under/Over tiles"
	set src in range(1, usr)

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


///////////////////////////////////
// General procedures
///////////////////////////////////

/obj/structure/cable/update_icon()
//	icon_state = "[d1]-[d2]"
	icon_state = tiledir

// Items usable on a cable :
//   - knife : cut it duh !
//   - Cable coil : merge cables
//   - Multitool : get the power currently passing through the cable
//
/obj/structure/cable/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/weapon/wirecutters))
		user.visible_message("[user] cuts the cable.", "<span class='notice'>You cut the cable.</span>")
		playsound(loc, usesound, 100, FALSE)
		Destroy()
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

//needed as this can, unlike other placements, disconnect cables
/obj/structure/cable/proc/disconnect()
	var/list/previous = connections.Copy()
	connections.Cut()
	power_consumers.Cut()
	powered = FALSE
	powerflow = 0
	currentflow = 0
	for (var/obj/OB in previous)
		if (istype(OB, /obj/structure/cable))
			var/obj/structure/cable/CB = OB
			CB.connections -= src
		else
			if (OB.powersource == src)
				OB.powersource = null
				OB.powered = FALSE
			if (istype(OB, /obj/structure/engine))
				var/obj/structure/engine/EN = OB
				EN.connections -= src
	for (var/obj/structure/cable/CB in previous)
		CB.rebuild_supply()

// Capacity is instantaneous engine output, not accumulated energy. Visit each
// cable and engine once, including when a network contains loops or branches.
/obj/structure/cable/proc/rebuild_supply()
	var/list/pending = list(src)
	var/list/cables = list()
	var/list/engines = list()
	var/list/batteries = list()
	var/capacity = 0
	var/demand = 0
	while (pending.len)
		var/obj/structure/cable/CB = pending[pending.len]
		pending.len--
		if (CB in cables)
			continue
		cables += CB
		if (!isturf(CB.loc))
			continue
		for (var/obj/consumer in CB.power_consumers.Copy())
			if (consumer.powersource != CB || !(consumer in CB.connections) || !isturf(consumer.loc) || get_dist(CB, consumer) > 1 || consumer.z != CB.z)
				CB.power_consumers -= consumer
			else
				demand += CB.power_consumers[consumer]
		for (var/obj/OB in CB.connections)
			if (!isturf(OB.loc) || get_dist(CB, OB) > 1 || CB.z != OB.z)
				continue
			if (istype(OB, /obj/structure/cable))
				var/obj/structure/cable/neighbor = OB
				if (CB in neighbor.connections)
					pending |= neighbor
			else if (istype(OB, /obj/structure/engine))
				var/obj/structure/engine/EN = OB
				if (!(EN in engines) && (CB in EN.connections))
					engines += EN
					if (EN.on && !EN.broken && EN.maxpower > 0)
						var/charging = EN.battery_charge_epoch == round(world.time / 10) ? EN.battery_charge_power : 0
						capacity += max(0, EN.maxpower - charging)
			else if (istype(OB, /obj/structure/battery))
				var/obj/structure/battery/B = OB
				if (!(B in batteries) && B.powersource == CB)
					batteries += B
					capacity += B.available_output()
	for (var/obj/structure/cable/CB in cables)
		CB.currentflow = demand
		CB.powerflow = capacity
		CB.powered = capacity > 0
	return capacity

// Reservations are keyed by the consumer, so repeated checks are idempotent.
/obj/structure/cable/proc/update_power(var/powerval = 0, var/recheck = 0, obj/consumer)
	if (consumer)
		if (powerval > 0 && consumer.powersource == src && (consumer in connections))
			power_consumers[consumer] = powerval
		else
			power_consumers -= consumer
	return rebuild_supply()

/obj/proc/draw_cable_power()
	if (!powersource)
		return FALSE
	if (powerneeded <= 0)
		powersource.update_power(0, 1, src)
		return FALSE
	if (!isturf(loc) || !(src in powersource.connections) || get_dist(src, powersource) > 1 || z != powersource.z)
		powersource.update_power(-powerneeded, 1, src)
		return FALSE
	powersource.rebuild_supply()
	var/reserved = powersource.power_consumers[src]
	if (powersource.powered && powersource.powerflow - powersource.currentflow + reserved >= powerneeded)
		powersource.update_power(powerneeded, 1, src)
		return TRUE
	powersource.update_power(-powerneeded, 1, src)
	return FALSE

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
	if (. && loc != previous_location)
		disconnect()
