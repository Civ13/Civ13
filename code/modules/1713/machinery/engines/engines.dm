//two main types of engines: external combustion and internal combustion.
//
//fossil fuels:
//petroleum - unrefined crude oil
//gasoline - refined from petroleum
//diesel - refined from petroleum
//
//biofuels:
// ethanol - from fermentation and destilation
//biodiesel - using a special machine to process various farming products
//olive oil - from olives
//
//from the heavyest to the lightest: petroleum > olive oil > biodiesel > diesel > gasoline > ethanol


/obj/structure/engine
	name = "engine"
	desc = "A basic engine."
	icon = 'icons/obj/engines.dmi'
	icon_state = "steam_static"
	var/engineclass = "steam"
	flammable = FALSE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

	var/weight = 20 //how much the engine weights (duh). For ICEs, this value is per liter (1000 cc)

	var/maxpower = 0 //how powerful (in kw/hp) the engine is. Both for vehicles and static engines. For internal combustion engines, this value is per liter (1000 cc)
	var/torque = 0 //a modifier for power and max weight. Engines like diesel have a positive modifier, meaning they can carry heavier loads with less power

	var/currentweight = 0 //weight being dragged. Only used for vehicles. For ICEs, this value is per liter (1000 cc)
	var/currentpower = 0 //power being used

	var/currentspeed = 0 //current speed. Mostly used for vehicles

	var/enginetype = "external" //internal or external. External requires a separate combustion source.
	var/list/connections = list() // what this engine is connected to. cam be an axis, oil well, etc.
	var/on = FALSE

/obj/structure/engine/proc/turn_on()
	return

/obj/structure/engine/proc/running()
	return

/obj/structure/engine/proc/process_power_output()
	var/powerused = 0
	currentspeed = 0
	if (!isemptylist(connections))
		for (var/obj/C in connections)
			if (C.powerneeded <= (maxpower - powerused))
				if (!istype(C, /obj/structure/vehicle/axis))
					powerused += C.powerneeded
					C.powered = TRUE
				else
					powerused += process_load(C)
					C.powered = TRUE
			else
				C.powered = FALSE
	return min(powerused, maxpower)
	//TODO: diferentiating between "movement" connections and "static" connections, so speed and weight can be calculated.


/obj/structure/engine/proc/process_current_weight()
	currentweight = 0
	if (!isemptylist(connections))
		for (var/obj/C in connections)
			if (weight)
				currentweight += weight
			else
				currentweight += w_class
	return currentweight

//processes the engine load taking into account power, weight and torque


/obj/structure/engine/proc/process_load(var/obj/structure/vehicle/axis/source = null)
	var/pullweight = process_current_weight()
	pullweight /= torque
	currentspeed += source.get_speed()*(pullweight/maxpower) //movement delay, in deciseconds per tile (higher = slower)
	return pullweight


/obj/structure/engine/proc/running_sound()
	if (on)
		playsound(loc, 'sound/machines/diesel_loop.ogg', 100, FALSE, 2)
	spawn(27)
		running_sound()


/obj/structure/engine/attack_hand(mob/user as mob)
	if (on)
		on = FALSE
		visible_message("[user] turns the [src] off.","You turn the [src] off.")
		playsound(loc, 'sound/machines/diesel_ending.ogg', 100, FALSE, 3)
		power_off_connections()
		currentspeed = 0
		currentpower = 0
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		update_icon()
		return
	else
		turn_on(user)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		return


/obj/structure/engine/update_icon()
	..()
	if (on)
		icon_state = "[engineclass]_on"
	else
		icon_state = "[engineclass]_static"

/obj/structure/engine/proc/power_off_connections()
	for (var/obj/C in connections)
		if (C.powerneeded > 0 && C.powersource == src)
			C.powered = 0
		if (istype(C, /obj/structure/cable))
			var/obj/structure/cable/CBL = C
			CBL.powered = FALSE
			CBL.power_off(maxpower)
	return

/obj/structure/engine/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		for(var/obj/structure/cable/EXC in connections)
			user << "There's already a cable connected here! Split it further from the engine."
			return
		var/obj/item/stack/cable_coil/CC = W
		var/obj/structure/cable/NCC = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		NCC.connections += src
		NCC.powerflow += maxpower
		connections += NCC
		user << "You connect the cable to the [src]."
	else
		..()