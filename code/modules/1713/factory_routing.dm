// Belt drives and routing belts (phase 2 of docs/factory-automation-design.md).
//
// A belt drive powers every factory belt within its range from one cable
// connection, so a line needs one powered machine instead of a cable under each
// tile. Sorting gates, splitters and tunnels are belts that only change where
// their exit item goes; they carry and save like any other belt.

#define FACTORY_TUNNEL_LENGTH 6 // tiles a tunnel entrance looks ahead for its exit

var/global/list/factory_active_drives = list()
var/global/list/factory_powered_drives = list()

/obj/structure/factory_drive
	name = "belt drive"
	desc = "A motor and gearbox that runs every factory belt within seven tiles. Cable it, then switch it on. Belts out of range of a running drive stand still."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "circuit0"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	powerneeded = 4
	var/on = FALSE
	var/drive_range = 7

/obj/structure/factory_drive/New()
	..()
	if (on)
		drive_wake()
	update_icon()

/obj/structure/factory_drive/Destroy()
	drive_stop()
	return ..()

/obj/structure/factory_drive/persistence_runtime_var(key)
	if (key == "powered")
		return TRUE
	return ..()

// A saved running drive resumes; its belts wake once it has power again.
/obj/structure/factory_drive/after_load()
	. = ..()
	powered = FALSE
	factory_powered_drives -= src
	if (on)
		drive_wake()
	update_icon()

/obj/structure/factory_drive/update_icon()
	icon_state = "circuit[(on && powered) ? 1 : 0]"

/obj/structure/factory_drive/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It is [on ? "on" : "off"][on && !powered ? ", without power" : ""] and runs belts within [drive_range] tiles."))

/obj/structure/factory_drive/attack_hand(mob/user)
	on = !on
	if (on)
		drive_wake()
	else
		drive_stop()
	update_icon()
	to_chat(user, SPAN_NOTICE("You switch \the [src] [on ? "on" : "off"]."))

/obj/structure/factory_drive/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	return ..()

/obj/structure/factory_drive/proc/drive_covers(obj/structure/factory_belt/B)
	return on && powered && !QDELETED(src) && isturf(loc) && B.z == z && get_dist(src, B) <= drive_range

/obj/structure/factory_drive/proc/drive_wake()
	if (!QDELETED(src))
		factory_active_drives |= src

/obj/structure/factory_drive/proc/drive_stop()
	factory_active_drives -= src
	factory_powered_drives -= src
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

/obj/structure/factory_drive/proc/drive_step()
	if (!on || !isturf(loc))
		drive_stop()
		update_icon()
		return
	var/was_powered = powered
	powered = draw_cable_power() ? TRUE : FALSE
	if (powered == was_powered)
		return
	if (powered)
		factory_powered_drives |= src
		// Belts that stopped for lack of power start again.
		for (var/obj/structure/factory_belt/B in range(drive_range, src))
			B.belt_wake()
	else
		factory_powered_drives -= src
	update_icon()

/proc/factory_drives_step()
	for (var/obj/structure/factory_drive/D in factory_active_drives.Copy())
		if (QDELETED(D))
			factory_active_drives -= D
			factory_powered_drives -= D
			continue
		D.drive_step()

//////////////////////////////////////////////////////////////////////////////
// Routing belts. Each one sends its exit item straight on or to one side; a
// screwdriver swaps which side.

/obj/structure/factory_belt/routing
	var/side_left = FALSE

/obj/structure/factory_belt/routing/proc/side_dir()
	return turn(dir, side_left ? 90 : -90)

/obj/structure/factory_belt/routing/update_icon()
	overlays.Cut()
	overlays += image(icon = 'icons/minimap_effects.dmi', icon_state = "map_arrow", dir = side_dir())

/obj/structure/factory_belt/routing/New()
	..()
	update_icon()

/obj/structure/factory_belt/routing/set_dir(new_dir)
	. = ..()
	update_icon()

/obj/structure/factory_belt/routing/after_load()
	. = ..()
	update_icon()

/obj/structure/factory_belt/routing/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Its side output points [dir2text(side_dir())]."))

/obj/structure/factory_belt/routing/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/screwdriver))
		side_left = !side_left
		update_icon()
		to_chat(user, SPAN_NOTICE("You set \the [src]'s side output to [dir2text(side_dir())]."))
		return
	return ..()

// Sorting gate: items matching its filter leave by the side, everything else
// goes straight on. With no filter everything goes straight on.
/obj/structure/factory_belt/routing/gate
	name = "sorting gate"
	desc = "A belt section with a swing gate. Items matching its filter leave by the side, everything else goes straight on. Use the Set Gate Filter verb holding an item to choose the filter, and a screwdriver to swap the side."
	icon_state = "conveyor1"
	assembly_type = /obj/item/factory_belt_assembly/gate
	var/filter_type = null

/obj/structure/factory_belt/routing/gate/update_icon()
	..()
	overlays += image(icon = 'icons/obj/recycling.dmi', icon_state = "diverter1", dir = side_dir())

/obj/structure/factory_belt/routing/gate/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE(filter_type ? "It sends [factory_filter_name(filter_type)] to the side." : "It has no filter set and sends everything straight on."))

/obj/structure/factory_belt/routing/gate/export_dirs(obj/item/I)
	if (filter_type && istype(I, filter_type))
		return list(side_dir())
	return list(dir)

/obj/structure/factory_belt/routing/gate/verb/set_gate_filter()
	set name = "Set Gate Filter"
	set category = null
	set src in oview(1)
	var/mob/living/L = usr
	if (!istype(L) || L.incapacitated())
		return
	var/obj/item/held = L.get_active_hand()
	if (!held)
		to_chat(L, SPAN_WARNING("Hold the kind of item the gate should sort out."))
		return
	filter_type = held.type
	to_chat(L, SPAN_NOTICE("\The [src] will now send [factory_filter_name(filter_type)] to the side."))

/obj/structure/factory_belt/routing/gate/verb/clear_gate_filter()
	set name = "Clear Gate Filter"
	set category = null
	set src in oview(1)
	filter_type = null
	to_chat(usr, SPAN_NOTICE("You clear \the [src]'s filter."))

// Splitter: alternates straight and side. When one output is blocked it uses
// the other, so a full branch never stops the line.
/obj/structure/factory_belt/routing/splitter
	name = "belt splitter"
	desc = "A belt section that sends items alternately straight on and to the side. Use a screwdriver to swap the side."
	icon_state = "conveyor1"
	assembly_type = /obj/item/factory_belt_assembly/splitter
	var/tmp/side_next = FALSE

/obj/structure/factory_belt/routing/splitter/persistence_runtime_var(key)
	if (key == "side_next")
		return TRUE
	return ..()

/obj/structure/factory_belt/routing/splitter/update_icon()
	..()
	overlays += image(icon = 'icons/obj/recycling.dmi', icon_state = "diverter0", dir = side_dir())

/obj/structure/factory_belt/routing/splitter/export_dirs(obj/item/I)
	return side_next ? list(side_dir(), dir) : list(dir, side_dir())

/obj/structure/factory_belt/routing/splitter/exported(obj/item/I, d)
	side_next = (d == dir)

//////////////////////////////////////////////////////////////////////////////
// Belt tunnel: an entrance hands its exit item to the first tunnel exit facing
// the same way up to FACTORY_TUNNEL_LENGTH tiles ahead, under whatever lies
// between.

/obj/structure/factory_belt/tunnel
	name = "belt tunnel entrance"
	desc = "A covered belt that carries items underground to a tunnel exit facing the same way, up to six tiles ahead."
	color = "#8a8a8a"
	assembly_type = /obj/item/factory_belt_assembly/tunnel

/obj/structure/factory_belt/tunnel_exit
	name = "belt tunnel exit"
	desc = "A covered belt where items carried by a tunnel entrance up to six tiles behind it come back up."
	color = "#b0b0b0"
	assembly_type = /obj/item/factory_belt_assembly/tunnel_exit

/obj/structure/factory_belt/tunnel/proc/tunnel_exit()
	var/turf/T = get_turf(src)
	for (var/i in 1 to FACTORY_TUNNEL_LENGTH)
		T = get_step(T, dir)
		if (!T)
			return null
		var/obj/structure/factory_belt/tunnel_exit/E = locate() in T
		if (E && E.dir == dir)
			return E
	return null

/obj/structure/factory_belt/tunnel/export_to(obj/item/I, d)
	var/obj/structure/factory_belt/tunnel_exit/E = tunnel_exit()
	if (!E)
		return FALSE
	return hand_to_belt(I, E, turn(dir, 180))

/obj/structure/factory_belt/tunnel/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, tunnel_exit() ? SPAN_NOTICE("It is connected to a tunnel exit.") : SPAN_WARNING("No tunnel exit faces the same way within [FACTORY_TUNNEL_LENGTH] tiles ahead."))

// A tunnel exit that frees space wakes its entrance as well as adjacent feeders.
/obj/structure/factory_belt/tunnel_exit/wake_upstream()
	..()
	var/turf/T = get_turf(src)
	for (var/i in 1 to FACTORY_TUNNEL_LENGTH)
		T = get_step(T, turn(dir, 180))
		if (!T)
			return
		var/obj/structure/factory_belt/tunnel/entrance = locate() in T
		if (entrance && entrance.dir == dir)
			if (entrance.belt_active)
				entrance.next_poll = 0
			return

//////////////////////////////////////////////////////////////////////////////
// Folded assemblies for the routing belts; laid like a plain belt.

/obj/item/factory_belt_assembly/gate
	name = "sorting gate assembly"
	desc = "A folded sorting gate. Use it on an adjacent floor tile to lay it running away from you."
	belt_type = /obj/structure/factory_belt/routing/gate
	color = "#d08a8a"

/obj/item/factory_belt_assembly/splitter
	name = "belt splitter assembly"
	desc = "A folded belt splitter. Use it on an adjacent floor tile to lay it running away from you."
	belt_type = /obj/structure/factory_belt/routing/splitter
	color = "#8aa8d0"

/obj/item/factory_belt_assembly/tunnel
	name = "belt tunnel entrance assembly"
	desc = "A folded tunnel entrance. Lay it running toward its exit, up to six tiles ahead."
	belt_type = /obj/structure/factory_belt/tunnel
	color = "#8a8a8a"

/obj/item/factory_belt_assembly/tunnel_exit
	name = "belt tunnel exit assembly"
	desc = "A folded tunnel exit. Lay it running the same way as its entrance."
	belt_type = /obj/structure/factory_belt/tunnel_exit
	color = "#b0b0b0"

#undef FACTORY_TUNNEL_LENGTH
