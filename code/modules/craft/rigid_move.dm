// Carrying wiring with a craft (docs/craft-core.md).
//
// Cables, engines, generators, batteries and connectors drop their links
// when they are moved, because a thing dragged away from its grid is no
// longer on it. A craft is different: it moves everything aboard at once, so
// the wiring aboard keeps its shape. While a body carries its cargo the
// things in craft_rigid_cargo keep their links; when the move is done
// craft_rigid_settle() cuts only the links to whatever stayed behind (a shore
// cable, a machine on the quay).

// Everything being carried by a craft right now: atom = TRUE. Null otherwise.
var/global/list/craft_rigid_cargo = null

// TRUE while this thing is being carried by a craft and must keep its links.
/atom/movable/proc/craft_carrying()
	return craft_rigid_cargo && craft_rigid_cargo[src]

// Starts a carry of these things. Returns what to hand craft_rigid_settle().
/proc/craft_rigid_begin(list/things)
	var/list/carry = list("was" = craft_rigid_cargo, "set" = list())
	var/list/aboard = carry["set"]
	if (craft_rigid_cargo)
		for (var/atom/movable/M in craft_rigid_cargo)
			aboard[M] = TRUE
	for (var/atom/movable/M in things)
		aboard[M] = TRUE
	craft_rigid_cargo = aboard
	return carry

// Ends the carry and lets everything carried cut what it left behind.
/proc/craft_rigid_settle(list/carry)
	if (!islist(carry))
		return
	var/list/aboard = carry["set"]
	craft_rigid_cargo = carry["was"]
	for (var/atom/movable/M in aboard)
		if (!QDELETED(M))
			M.craft_carried(aboard)

// Called on everything a craft carried once it has arrived. aboard holds
// every thing that came along: atom = TRUE.
/atom/movable/proc/craft_carried(list/aboard)
	return

// One link of a cable cut, the way disconnect() cuts them all.
/obj/structure/cable/proc/cut_link(obj/OB)
	connections -= OB
	power_consumers -= OB
	if (istype(OB, /obj/structure/cable))
		var/obj/structure/cable/CB = OB
		CB.connections -= src
		return
	if (istype(OB, /obj/item/connector))
		var/obj/item/connector/J = OB
		J.forget_cable(src)
	if (OB.powersource == src)
		if (istype(OB, /obj/structure/civ_generator))
			var/obj/structure/civ_generator/G = OB
			G.stop_generation()
		OB.powersource = null
		OB.powered = FALSE
	if (istype(OB, /obj/structure/engine))
		var/obj/structure/engine/EN = OB
		EN.connections -= src

/obj/structure/cable/craft_carried(list/aboard)
	var/list/left = list()
	for (var/obj/OB in connections)
		if (!aboard[OB])
			left += OB
	var/cut = left.len
	if (riser_links)
		for (var/obj/structure/cable/linked in riser_links.Copy())
			if (aboard[linked])
				continue
			riser_links -= linked
			if (linked.riser_links)
				linked.riser_links -= src
			left += linked
			cut++
	if (!cut)
		return
	for (var/obj/OB in left)
		if (OB in connections)
			cut_link(OB)
	rebuild_supply()
	for (var/obj/structure/cable/CB in left)
		CB.rebuild_supply()

// A cable laid east to west lies north to south after a quarter turn.
/obj/structure/cable/craft_turned(datum/craft/C, angle)
	..()
	if (abs(angle) == 90)
		if (tiledir == "horizontal")
			tiledir = "vertical"
		else if (tiledir == "vertical")
			tiledir = "horizontal"
		update_icon()

/obj/structure/engine/craft_carried(list/aboard)
	for (var/obj/OB in connections.Copy())
		if (aboard[OB])
			continue
		connections -= OB
		if (istype(OB, /obj/structure/cable))
			var/obj/structure/cable/CB = OB
			CB.connections -= src
			CB.rebuild_supply()
		else if (OB.powersource == src)
			OB.powersource = null
			OB.powered = FALSE

/obj/structure/civ_generator/craft_carried(list/aboard)
	if (powersource && !aboard[powersource])
		disconnect_generation()

/obj/structure/battery/craft_carried(list/aboard)
	if (powersource && !aboard[powersource])
		disconnect_battery()

/obj/item/connector/craft_carried(list/aboard)
	for (var/obj/structure/cable/CB in turflist)
		if (!aboard[CB])
			disconnect_cables()
			anchored = FALSE
			return
