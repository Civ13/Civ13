/obj/item/assembly
	name = "assembly"
	desc = "A small electronic device that should never exist."
	icon = 'icons/obj/assemblies/new_assemblies.dmi'
	icon_state = ""
	flags = CONDUCT
	w_class = 2.0
	matter = list(DEFAULT_WALL_MATERIAL = 100)
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 3
	throw_range = 10
//	origin_tech = list(TECH_MAGNET = TRUE)

	var/secured = TRUE
	var/list/attached_overlays = null
	var/obj/item/assembly_holder/holder = null
	var/cooldown = FALSE//To prevent spam
	var/wires = WIRE_RECEIVE | WIRE_PULSE

	var/const/WIRE_RECEIVE = TRUE			//Allows Pulsed(0) to call Activate()
	var/const/WIRE_PULSE = 2				//Allows Pulse(0) to act on the holder
	var/const/WIRE_PULSE_SPECIAL = 4		//Allows Pulse(0) to act on the holders special assembly
	var/const/WIRE_RADIO_RECEIVE = 8		//Allows Pulsed(1) to call Activate()
	var/const/WIRE_RADIO_PULSE = 16		//Allows Pulse(1) to send a radio message

	proc/activate()									//What the device does when turned on
		return

	proc/pulsed(var/radio = FALSE)						//Called when another assembly acts on this one, var/radio will determine where it came from for wire calcs
		return

	proc/pulse(var/radio = FALSE)						//Called when this device attempts to act on another device, var/radio determines if it was sent via radio or direct
		return

	proc/toggle_secure()								//Code that has to happen when the assembly is un\secured goes here
		return

	proc/attach_assembly(var/obj/A, var/mob/user)	//Called when an assembly is attacked by another
		return

	proc/process_cooldown()							//Called via spawn(10) to have it count down the cooldown var
		return

	proc/holder_movement()							//Called when the holder is moved
		return

	interact(mob/user as mob)					//Called when attack_self is called
		return


	process_cooldown()
		cooldown--
		if (cooldown <= 0)	return FALSE
		spawn(10)
			process_cooldown()
		return TRUE


	pulsed(var/radio = FALSE)
		if (holder && (wires & WIRE_RECEIVE))
			activate()
		if (radio && (wires & WIRE_RADIO_RECEIVE))
			activate()
		return TRUE


	pulse(var/radio = FALSE)
		if (holder && (wires & WIRE_PULSE))
			holder.process_activation(src, TRUE, FALSE)
		if (holder && (wires & WIRE_PULSE_SPECIAL))
			holder.process_activation(src, FALSE, TRUE)
//		if (radio && (wires & WIRE_RADIO_PULSE))
			//Not sure what goes here quite yet send signal?
		return TRUE


	activate()
		if (!secured || (cooldown > 0))	return FALSE
		cooldown = 2
		spawn(10)
			process_cooldown()
		return TRUE


	toggle_secure()
		secured = !secured
		update_icon()
		return secured


	attach_assembly(var/obj/item/assembly/A, var/mob/user)
		holder = new/obj/item/assembly_holder(get_turf(src))
		if (holder.attach(A,src,user))
			user << "<span class = 'notice'>You attach \the [A] to \the [src]!</span>"
			return TRUE
		return FALSE


	attackby(obj/item/weapon/W as obj, mob/user as mob)
		if (isassembly(W))
			var/obj/item/assembly/A = W
			if ((!A.secured) && (!secured))
				attach_assembly(A,user)
				return
		if (isscrewdriver(W))
			if (toggle_secure())
				user << "<span class = 'notice'>\The [src] is ready!</span>"
			else
				user << "<span class = 'notice'>\The [src] can now be attached!</span>"
			return
		..()
		return


	process()
		processing_objects.Remove(src)
		return


	examine(mob/user)
		..(user)
		if ((in_range(src, user) || loc == user))
			if (secured)
				user << "\The [src] is ready!"
			else
				user << "\The [src] can be attached!"
		return


	attack_self(mob/user as mob)
		if (!user)	return FALSE
		user.set_using_object(src)
		interact(user)
		return TRUE


	interact(mob/user as mob)
		return //HTML MENU FOR WIRES GOES HERE

/obj/item/assembly/nano_host()
    if (istype(loc, /obj/item/assembly_holder))
        return loc.nano_host()
    return ..()

/*
	var/small_icon_state = null//If this obj will go inside the assembly use this for icons
	var/list/small_icon_state_overlays = null//Same here
	var/obj/holder = null
	var/cooldown = FALSE//To prevent spam

	proc
		Activate()//Called when this assembly is pulsed by another one
		Process_cooldown()//Call this via spawn(10) to have it count down the cooldown var
		Attach_Holder(var/obj/H, var/mob/user)//Called when an assembly holder attempts to attach, sets src's loc in here


	Activate()
		if (cooldown > 0)
			return FALSE
		cooldown = 2
		spawn(10)
			Process_cooldown()
		//Rest of code here
		return FALSE


	Process_cooldown()
		cooldown--
		if (cooldown <= 0)	return FALSE
		spawn(10)
			Process_cooldown()
		return TRUE


	Attach_Holder(var/obj/H, var/mob/user)
		if (!H)	return FALSE
		if (!H.IsAssemblyHolder())	return FALSE
		//Remember to have it set its loc somewhere in here


*/
