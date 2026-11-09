/obj/machinery/washing_machine
	name = "washing machine"
	desc = "A washing machine."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "washing_machine_2"
	density = 1
	anchored = 1
	var/state = 2
	//1 = empty, open door
	//2 = empty, closed door
	//3 = full, open door
	//4 = full, closed door
	//5 = running
	var/list/washing = list()
	var/list/disallowed_types = list() //For future use, when something can't be washed in the machine.
	var/water_stored = 0
	// Mapped machines keep their own mains supply; the crafted piped model draws pumped water.
	var/needs_pipe_water = FALSE

#define WASHING_MACHINE_WATER 20

/obj/machinery/washing_machine/piped
	name = "piped washing machine"
	desc = "A washing machine that needs a pumped pipe network with water."
	needs_pipe_water = TRUE

/obj/machinery/washing_machine/New()
	..()
	fluid_mark_dirty()

/obj/machinery/washing_machine/Destroy()
	fluid_mark_dirty()
	return ..()

/obj/machinery/washing_machine/after_load()
	. = ..()
	fluid_mark_dirty()

/obj/machinery/washing_machine/fluid_demand_tier()
	return (anchored && needs_pipe_water) ? FLUID_TIER_SINK : 0

/obj/machinery/washing_machine/fluid_demand(id)
	if (!needs_pipe_water || !anchored || id != "water")
		return 0
	return max(0, WASHING_MACHINE_WATER - water_stored)

/obj/machinery/washing_machine/fluid_receive(id, amount, data)
	var/taken = min(amount, fluid_demand(id))
	if (taken <= 0)
		return 0
	water_stored += taken
	return taken

/obj/machinery/washing_machine/examine(mob/user, distance)
	..(user, distance)
	if (needs_pipe_water)
		to_chat(user, SPAN_NOTICE("Water in the machine: [round(water_stored)]/[WASHING_MACHINE_WATER] units."))

/obj/machinery/washing_machine/proc/wash_water_available()
	if (fluid_networks_dirty)
		fluid_rebuild_networks()
	return anchored && fluid_network_of(src) && water_stored >= WASHING_MACHINE_WATER

/obj/machinery/washing_machine/proc/reserve_wash_water()
	if (!needs_pipe_water)
		return TRUE
	if (!wash_water_available())
		return FALSE
	water_stored -= WASHING_MACHINE_WATER
	return TRUE

/obj/machinery/washing_machine/verb/start()
	set name = "Start Washing"
	set category = null
	set src in oview(1)

	if(!istype(usr, /mob/living/human))
		return

	if(state != 4)
		if (state == 5)
			to_chat(usr, "The washing machine is already running.")
		else if (state == 3)
			to_chat(usr, "You need to close the door first.")
		else
			to_chat(usr, "You need to fill the washing machine with something.")
		return
	if (!reserve_wash_water())
		to_chat(usr, SPAN_WARNING("\The [src] needs a connected pipe network and [WASHING_MACHINE_WATER] units of water to wash."))
		return
	state = 5
	update_icon()
	sleep(200)
	for(var/atom/A in washing)
		A.clean_blood()
	for(var/obj/item/clothing/C in washing)
		C.dirtyness = -100
	state = 4
	update_icon()

#undef WASHING_MACHINE_WATER

/obj/machinery/washing_machine/update_icon()
	icon_state = "washing_machine_[state]"

/obj/machinery/washing_machine/attackby(obj/item/weapon/W as obj, mob/user as mob)

	if(is_type_in_list(W, disallowed_types))
		to_chat(user, SPAN_WARNING("You can't fit \the [W] inside."))
		return

	else if(istype(W, /obj/item/clothing) || istype(W, /obj/item/weapon/bedsheet))
		if(washing.len < 5)
			if(state in list(1, 3))
				user.drop_item()
				W.loc = src
				washing += W
				state = 3
			else
				to_chat(user, SPAN_NOTICE("You can't put the item in right now."))
		else
			to_chat(user, SPAN_NOTICE("The washing machine is full!"))
	else
		..()
	update_icon()

/obj/machinery/washing_machine/attack_hand(mob/user as mob)
	switch(state)
		if(1)
			state = 2
		if(2)
			state = 1
			for(var/atom/movable/O in washing)
				O.loc = src.loc
			washing.Cut()
		if(3)
			state = 4
		if(4)
			state = 3
			for(var/atom/movable/O in washing)
				O.loc = src.loc
			washing.Cut()
			state = 1
		if(5)
			to_chat(user, SPAN_WARNING("The [src] is busy."))
	update_icon()

