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
	var/obj/item/stack/cable_coil/stored
	not_movable = FALSE
	not_disassemblable = FALSE
	var/lastupdate = 0 //to prevent loops. Can only update once per decisecond. For turning on/off.
	var/lastupdate2 = 0 //to prevent loops. Can only update once per decisecond. For power calculations.
	var/cable_color = "red"
	color = "#ff0000"
	var/usesound = 'sound/items/deconstruct.ogg'
	var/powerflow = 0 //maximum powerflow in the network (total maxpower of all engines connected)
	var/currentflow = 0 //corrent power used by all the nodes in the network (cant be > powerflow)
	var/tilepos = "under"
	var/tiledir = "horizontal"

/obj/structure/cable/verb/hiding()
	set category = null
	set name = "Under/Over tiles"
	set src in range(1, usr)

	if (!istype(usr, /mob/living/carbon/human))
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

	// ensure d1 & d2 reflect the icon_state for entering and exiting cable
	var/dash = findtext(icon_state, "-")
	d1 = text2num( copytext( icon_state, 1, dash ) )
	d2 = text2num( copytext( icon_state, dash+1 ) )

	cable_list += src //add it to the global cable list

	if(d1)
		stored = new/obj/item/stack/cable_coil(null,2,cable_color)
	else
		stored = new/obj/item/stack/cable_coil(null,1,cable_color)

	if (!cable_color)
		cable_color = pick(cable_colors)

	update_icon()

/obj/structure/cable/Destroy()					// called when a cable is deleted
	if (!isemptylist(connections))
		disconnect()
	cable_list -= src							//remove it from global cable list
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
	if(istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		user.visible_message("[user] cuts the cable.", "<span class='notice'>You cut the cable.</span>")
		playsound(loc, usesound, 100, FALSE)
		stored.add_fingerprint(user)
		Destroy()
		return
/*
	else if(W.tool_behaviour == TOOL_MULTITOOL)
		if(powernet && (powernet.avail > 0))		// is it powered?
			user <<"<span class='danger'>Total power: [DisplayPower(powernet.avail)]\nLoad: [DisplayPower(powernet.load)]\nExcess power: [DisplayPower(surplus())]</span>"
		else
			user <<"<span class='danger'>The cable is not powered.</span>"
		shock(user, 5, 0.2)
*/
	else
/*		if (connections.len >= 2)
			var/count = 0
			for(var/obj/structure/cable/CBL in connections)
				count+=1
			if (count >= 2)
				user << "Too many connections! Use a connector."
				return
*/
//		handlecable(W, user, params)
		return

/obj/structure/cable/proc/update_stored(length = 1, colorC = "red")
	stored.amount = length
	stored.cable_color = colorC
	stored.update_icon()

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
					if (!CB in connections)
						connections += CB
	return connections

//needed as this can, unlike other placements, disconnect cables
/obj/structure/cable/proc/disconnect()
	for (var/obj/structure/cable/CB in connections)
		CB.connections -= src
		connections -= CB
	for (var/obj/OB in connections)
		OB.powersource = null
		connections -= OB
		if (istype(OB, /obj/structure/engine))
			var/obj/structure/engine/EN = OB
			EN.connections -= src
/obj/structure/cable/proc/update_power(var/powerval = 0, var/recheck = 0)
	if (!isturf(loc))
		return
	var/connectioncount = 0 //to prevent loops. maximum 4 connections per tile
	for (var/obj/structure/cable/CB in connections)
		if ((CB.lastupdate2 <= world.time-25) && CB != src && connectioncount <= 4)
			connectioncount +=1
			CB.lastupdate2 = world.time
			if (powered)
				CB.currentflow += powerval
			else
				CB.currentflow = 0
			CB.update_power(powerval,0)
		if (recheck)
			recheck_update_power(powerval)
	return
/obj/structure/cable/proc/recheck_update_power(var/powerval = 0)
	if (!isturf(loc))
		return
	spawn(30)
		var/connectioncount = 0 //to prevent loops. maximum 4 connections per tile
		for (var/obj/structure/cable/CB in connections)
			if ((CB.lastupdate2 <= world.time-25) && CB != src && connectioncount <= 4)
				connectioncount +=1
				CB.lastupdate2 = world.time
				if (powered && CB.currentflow < currentflow)
					CB.currentflow = currentflow
					CB.recheck_update_power(powerval)
/obj/structure/cable/proc/power_on(var/maxpower = 0)
	if (!isturf(loc))
		return
	if (maxpower > 0)
		powered = TRUE
		powerflow += maxpower
		lastupdate = world.time

	for (var/obj/structure/cable/CB in connections)
		if (CB.lastupdate <= world.time-25 && CB != src)
			CB.powered = TRUE
			CB.powerflow += powerflow
			CB.lastupdate = world.time
			CB.power_on(0)
	return

/obj/structure/cable/proc/power_off(var/maxpower = 0)
	if (!isturf(loc))
		return
	if (maxpower > 0)
		powered = FALSE
		powerflow = 0
		lastupdate = world.time
		if (powerflow < 0)
			powerflow = 0
	for (var/obj/structure/cable/CB in connections)
		if (CB.lastupdate <= world.time-25 && CB != src && CB.powered)
			CB.powered = FALSE
			CB.powerflow = 0
			if (CB.powerflow < 0)
				CB.powerflow = 0
			CB.lastupdate = world.time
			CB.power_off(0)
	return
