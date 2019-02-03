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
	layer = MOB_LAYER - 0.1
	anchored = TRUE
	var/d1 = 0   // cable direction 1 (see above)
	var/d2 = 1   // cable direction 2 (see above)
	var/list/connections = list()
	var/obj/item/stack/cable_coil/stored
	not_movable = FALSE
	not_disassemblable = FALSE
	var/lastupdate = 0 //to prevent loops. Can only update once per decisecond.
	var/cable_color = "red"
	color = "#ff0000"
	var/usesound = 'sound/items/deconstruct.ogg'
	var/powerflow = 0 //maximum powerflow in the network (total maxpower of all engines connected)
	var/currentflow = 0 //corrent power used by all the nodes in the network (cant be > powerflow)
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
	icon_state = "[d1]-[d2]"

/obj/structure/cable/proc/handlecable(obj/item/W, mob/user, params)

	if(istype(W, /obj/item/weapon/material/knife))
		user.visible_message("[user] cuts the cable.", "<span class='notice'>You cut the cable.</span>")
		playsound(loc, usesound, 100, FALSE)
		stored.add_fingerprint(user)
		Destroy()
		return

	else if(istype(W, /obj/item/stack/cable_coil))
		var/obj/item/stack/cable_coil/coil = W
		if (coil.get_amount() < 1)
			user <<"<span class='warning'>Not enough cable!</span>"
			return
		coil.cable_join(src, user)
/*
	else if(W.tool_behaviour == TOOL_MULTITOOL)
		if(powernet && (powernet.avail > 0))		// is it powered?
			user <<"<span class='danger'>Total power: [DisplayPower(powernet.avail)]\nLoad: [DisplayPower(powernet.load)]\nExcess power: [DisplayPower(surplus())]</span>"
		else
			user <<"<span class='danger'>The cable is not powered.</span>"
		shock(user, 5, 0.2)
*/
	add_fingerprint(user)

// Items usable on a cable :
//   - Wirecutters : cut it duh !
//   - Cable coil : merge cables
//   - Multitool : get the power currently passing through the cable
//
/obj/structure/cable/attackby(obj/item/W, mob/user, params)
	handlecable(W, user, params)

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
	connections = list()

/obj/structure/cable/proc/update_power()
	if (!isturf(loc))
		return
	for (var/obj/structure/cable/CB in connections)
		if (CB.lastupdate <= world.time-2)
			if (powered)
				CB.currentflow += currentflow
				lastupdate = world.time
				CB.update_power()
	return

/obj/structure/cable/proc/power_on(var/maxpower = 0)
	if (!isturf(loc))
		return
	if (maxpower > 0)
		powered = TRUE
		powerflow += maxpower

	for (var/obj/structure/cable/CB in connections)
		if (CB.lastupdate <= world.time-30)
			CB.powered = TRUE
			CB.powerflow += powerflow
			lastupdate = world.time
			CB.power_on(0)
	return

/obj/structure/cable/proc/power_off(var/maxpower = 0)
	if (!isturf(loc))
		return
	if (maxpower > 0)
		powered = FALSE
		powerflow -= maxpower
	for (var/obj/structure/cable/CB in connections)
		if (CB.lastupdate <= world.time-30)
			CB.powered = FALSE
			CB.powerflow -= powerflow
			if (CB.powerflow < 0)
				CB.powerflow = 0
			lastupdate = world.time
			CB.power_off(0)
	return
