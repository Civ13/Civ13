/obj/machinery/washing_machine
	name = "washing machine"
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

/obj/machinery/washing_machine/verb/start()
	set name = "Start Washing"
	set category = null
	set src in oview(1)

	if(!istype(usr, /mob/living/human))
		return

	if(state != 4)
		if (state == 5)
			usr << "The washing machine is already running."
		else if (state == 3)
			usr << "You need to close the door first."
		else
			usr << "You need to fill the washing machine with something."
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

/obj/machinery/washing_machine/update_icon()
	icon_state = "washing_machine_[state]"

/obj/machinery/washing_machine/attackby(obj/item/weapon/W as obj, mob/user as mob)

	if(is_type_in_list(W, disallowed_types))
		user << "<span class='warning'>You can't fit \the [W] inside.</span>"
		return

	else if(istype(W, /obj/item/clothing) || istype(W, /obj/item/weapon/bedsheet))
		if(washing.len < 5)
			if(state in list(1, 3))
				user.drop_item()
				W.loc = src
				washing += W
				state = 3
			else
				user << "<span class='notice'>You can't put the item in right now.</span>"
		else
			user << "<span class='notice'>The washing machine is full!</span>"
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
			user << "<span class='warning'>The [src] is busy.</span>"
	update_icon()

