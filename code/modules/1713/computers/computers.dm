
/////////////////////////////////////////
////////////////COMPUTERS////////////////
/////////////////////////////////////////

//BASE ELECTRONIC FOR COPY AND PASTING LMAO
/*/obj/structure/base_powered_object
	name = "Powered Object"
	desc = "This is meant to be copy-pasted to make more cool stuff with the power system."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "off"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/active = FALSE
	powerneeded = 1

/obj/structure/base_powered_object/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored)
			H << "<span class='notice'>Fix the [src] in place with a wrench first.</span>"
			return
		if (powersource)
			H << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), H, turn(get_dir(H,src),180))
		powersource.connections += src

		var/opdir1 = 0
		var/opdir2 = 0
		if (powersource.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (powersource.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		powersource.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
				if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
					if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
						NCOO.connections += powersource
					if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
						powersource.connections += NCOO
					H << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
				if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
					if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
						NCOC.connections += powersource
					if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
						powersource.connections += NCOC
					H << "You connect the two cables."
		H << "You connect the cable to the [src]."

	else
		..()


/obj/structure/base_powered_object/attack_hand(var/mob/living/human/H)
	if (active)
		active = FALSE
		powered = FALSE
		powersource.update_power(powerneeded,1)
		powersource.currentflow -= powerneeded
		powersource.lastupdate2 = world.time
		H << "You power off the [src]."
		update_icon()
		return

	else if (!active && !powersource.powered)
		H << "<span class = 'notice'>There is not enough power to start the [src].</span>"
		update_icon()
		return
	else if (!active && powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
		active = TRUE
		powered = TRUE
		powersource.update_power(powerneeded,1)
		powersource.currentflow += powerneeded
		powersource.lastupdate2 = world.time
		power_on()
		H << "You power the [src]."
		update_icon()
		return
	else
		H << "<span class = 'notice'>There is not enough power to start the [src].</span>"
		return

/obj/structure/base_powered_object/proc/power_on()
	if (powered && active)
		update_icon()
		//do something here.
	else
		update_icon()
		return

/obj/structure/base_powered_object/update_icon()
	if (active)
		icon_state = "on"
	else
		icon_state = "off"*/

/obj/structure/computer/
	name = "Parent Computer"
	desc = "A simplistic computer. This is the parent object."
	icon = 'icons/obj/computers.dmi'
	icon_state = "1980_computer_off"
	var/peripherals = list()
	var/internals = list()
	var/operatingsystem = "unga OS"
	var/memory = list()
	var/display = "Unga OS V 0.0.1"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/active = FALSE
	powered = FALSE
	powerneeded = 1
	var/mainbody = ""
	var/mainmenu = ""
	var/mob/user

	var/list/programs = list()
/obj/structure/computer/New()
	..()
	boot(operatingsystem)
	program_checker()

/obj/structure/computer/nopower
	name = "desktop computer"
	desc = "A desktop computer running the latest version of Unga OS."
	icon_state = "1980_computer_on"
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE

/obj/structure/computer/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored)
			H << "<span class='notice'>Fix the [src] in place with a wrench first.</span>"
			return
		if (powersource)
			H << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), H, turn(get_dir(H,src),180))
		powersource.connections += src

		var/opdir1 = 0
		var/opdir2 = 0
		if (powersource.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (powersource.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		powersource.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
				if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
					if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
						NCOO.connections += powersource
					if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
						powersource.connections += NCOO
					H << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
				if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
					if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
						NCOC.connections += powersource
					if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
						powersource.connections += NCOC
					H << "You connect the two cables."
		H << "You connect the cable to the [src]."

	else
		if (istype(W, /obj/item/weapon/disk/os))
			var/obj/item/weapon/disk/os/OSD = W
			if (OSD.operatingsystem != src.operatingsystem)
				src.operatingsystem = OSD.operatingsystem
				src.programs = list()
				src.boot(OSD.operatingsystem)
				playsound(get_turf(src), 'sound/machines/computer/floppydisk.ogg', 100, TRUE)
				H << "You sucessfully install \the [src.operatingsystem] on this machine."
			else
				H << "You already have this operating system installed."
				return
		else if (istype(W, /obj/item/weapon/disk/program))
			var/obj/item/weapon/disk/program/PD = W
			if (!(operatingsystem in PD.compatible_os))
				H << "This operating system is not supported."
				return
			if (PD.included)
				var/datum/program/NP = new PD.included
				for(var/datum/program/EP in programs)
					if (istype(EP,NP))
						H << "This program is already installed on this machine."
						return
				programs += NP
				NP.origin = src
				playsound(get_turf(src), 'sound/machines/computer/floppydisk.ogg', 100, TRUE)
				H << "You load \the [NP.name] into this machine."
				return
		else
			..()

/obj/structure/computer/verb/toggle_power(var/mob/living/human/H)
	set category = null
	set name = "Turn On"
	set src in range(1, usr)
	if(src.active)
		name = "Turn Off"
	if(!powersource)
		H << "<span class = 'notice'>You need to plug in the [src].</span>"
		return
	if (active)
		active = FALSE
		powered = FALSE
		powersource.update_power(powerneeded,1)
		powersource.currentflow -= powerneeded
		powersource.lastupdate2 = world.time
		H << "You power off the [src]."
		update_icon()
		return
	else if (!active && !powersource.powered)
		H << "<span class = 'notice'>There is not enough power to start the [src].</span>"
		update_icon()
		return
	else if (!active && powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
		active = TRUE
		powered = TRUE
		powersource.update_power(powerneeded,1)
		powersource.currentflow += powerneeded
		powersource.lastupdate2 = world.time
		power_on()
		H << "You power the [src]."
		update_icon()
		return
	else
		H << "<span class = 'notice'>There is not enough power to start the [src].</span>"
		return
/obj/structure/computer/attack_hand(var/mob/living/human/H)
	if(!src.active)
		boot(operatingsystem)
		do_html(user)
	else
		H << "<span class = 'notice'>You need to turn the [src] on first!</span>"
/obj/structure/computer/proc/power_on()
	if (powered && active)
		update_icon()
		//do somethin
	else
		update_icon()
		return

/obj/structure/computer/update_icon()
	if (active)
		icon_state = "1980_computer_on"
	else
		icon_state = "1980_computer_off"

/obj/structure/computer/proc/program_checker()
	for(var/datum/program/P in programs)
		P.origin = src
		if (P.does_checks)
			P.does_checks_proc()
	spawn(600)
		if (src)
			program_checker()
			return