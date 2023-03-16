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
	layer = 3.98
	var/broken = FALSE

	var/weight = 20 //how much the engine weights (duh). For ICEs, this value is per liter (1000 cc)

	var/maxpower = 0 //how powerful (in kw/hp) the engine is. Both for vehicles and static engines. For internal combustion engines, this value is per liter (1000 cc)
	var/torque = 0 //a modifier for power and max weight. Engines like diesel have a positive modifier, meaning they can carry heavier loads with less power

	var/currentweight = 0 //weight being dragged. Only used for vehicles. For ICEs, this value is per liter (1000 cc)
	var/currentpower = 0 //power being used

	var/currentspeed = 0 //current speed. Mostly used for vehicles

	var/enginetype = "external" //internal or external. External requires a separate combustion source.
	var/list/connections = list() // what this engine is connected to. cam be an axis, oil well, etc.

	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank //only used for internal combustion, but needs to be here because its checked by vehicles
	var/on = FALSE

	var/starting_snd = 'sound/machines/diesel_starting.ogg'
	var/running_snd = 'sound/machines/diesel_loop.ogg'
	var/ending_snd = 'sound/machines/diesel_ending.ogg'

	var/starting_snd_len = 29 //Length in time of the starting_snd, used for time before the running_snd is played, default is 29
	var/running_snd_len = 27 //Length in time of the running_snd, used for repeating the sound, default is 27

/obj/structure/engine/examine(mob/user)
	..()
	if (user in range(1,src))
		if (istype(src, /obj/structure/engine/external))
			var/done = FALSE
			for(var/obj/structure/vehicleparts/frame/ship/S in loc)
				done = TRUE
			if (done == FALSE)
				user << "<span class='notice'>Max Power: <b>[maxpower*2]</b>.</span>"
			else
				user << "<span class='notice'>Max Power: <b>[maxpower*20]</b>.</span>"
		else
			user << "<span class='notice'>Max Power: <b>[maxpower*2]</b>.</span>"
/obj/structure/engine/proc/turn_on()
	return

/obj/structure/engine/proc/running()
	return

/obj/structure/engine/proc/process_power_output()
	var/powerused = 0
	currentspeed = 0
	if (!isemptylist(connections))
		for (var/obj/C in connections)
			if (istype(C, /obj/structure/cable))
				var/obj/structure/cable/CBL = C
				if (CBL.currentflow > 0)
					powerused += CBL.currentflow
					C.powered = TRUE
			if (C.powerneeded <= (maxpower - powerused))
//				if (!istype(C, /obj/structure/vehicleparts/axis))
				powerused += C.powerneeded
				C.powered = TRUE
/*				else
					powerused += process_load(C)
					C.powered = TRUE
*/
			else
				C.powered = FALSE
	return min(max(powerused,maxpower*0.1), maxpower) //minimum powerused is 10% of maxpower, maximum is the maxpower value
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


/obj/structure/engine/proc/process_load(var/obj/structure/vehicleparts/axis/source = null)
	var/pullweight = process_current_weight()
	pullweight /= torque
	currentspeed += source.get_speed()*(pullweight/maxpower) //movement delay, in deciseconds per tile (higher = slower)
	return pullweight


/obj/structure/engine/proc/running_sound()
	if (on)
		playsound(loc, running_snd, 35, FALSE, 2)
		spawn(running_snd_len)
			running_sound()
	return


/obj/structure/engine/attack_hand(mob/user as mob)
	if (on)
		on = FALSE
		visible_message("[user] turns the [src] off.","You turn the [src] off.")
		playsound(loc, ending_snd, 35, FALSE, 3)
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
	if (engineclass == "carengine")
		switch(dir)
			if (NORTH)
				pixel_x = 16
				pixel_y = 0
			if (SOUTH)
				pixel_x = -16
				pixel_y = 0
			if (WEST)
				pixel_x = 0
				pixel_y = 16
			if (EAST)
				pixel_x = 0
				pixel_y = -16
	if (broken)
		icon_state = "[engineclass]_broken"
		return
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
	if (broken && istype(W, /obj/item/weapon/weldingtool))
		visible_message("[user] starts repairing \the [src]...")
		if (do_after(user, 200, src))
			visible_message("[user] sucessfully repairs \the [src].")
			broken = FALSE
			return
	else if (istype(W,/obj/item/weapon/wrench) && !not_movable)
		if (powersource)
			user << "<span class='notice'>Remove the cables first.</span>"
			return
		if (!isemptylist(connections))
			user << "<span class='notice'>Remove the cables first.</span>"
			return
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
		for(var/obj/structure/vehicleparts/frame/F in src.loc)
			if (F.axis)
				if (anchored)
					if (!F.axis.engine)
						F.axis.engine = src
				else
					if (F.axis && F.axis.engine && F.axis.engine == src)
						F.axis.engine = null
		return
	else if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored)
			user << "<span class='notice'>Fix the engine in place with a wrench first.</span>"
			return
		for(var/obj/structure/cable/EXC in connections)
			user << "There's already a cable connected here! Split it further from the engine."
			return
		var/obj/item/stack/cable_coil/CC = W
		var/obj/structure/cable/NCC = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		if (!NCC) return
		NCC.connections += src
		connections += NCC
		user << "You connect the cable to \the [src]."
		var/opdir1 = 0
		var/opdir2 = 0
		if (NCC.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (NCC.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		NCC.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(NCC,opdir1)))
				if ((NCOO.tiledir == NCC.tiledir) && NCOO != NCC)
					if (!(NCC in NCOO.connections) && !list_cmp(NCC.connections, NCOO.connections))
						NCOO.connections += NCC
					if (!(NCOO in NCC.connections) && !list_cmp(NCC.connections, NCOO.connections))
						NCC.connections += NCOO
					user << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(NCC,opdir2)))
				if ((NCOC.tiledir == NCC.tiledir) && NCOC != NCC)
					if (!(NCC in NCOC.connections) && !list_cmp(NCC.connections, NCOC.connections))
						NCOC.connections += NCC
					if (!(NCOC in NCC.connections) && !list_cmp(NCC.connections, NCOC.connections))
						NCC.connections += NCOC
					user << "You connect the two cables."
	else
		..()

/////ENGINE MAKER/////////
/obj/item/weapon/enginemaker
	name = "engine maker"
	desc = "Use this to craft engines."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "tools"
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	var/done = FALSE
	var/steelamt = 0
	var/enginesize = 0


/obj/item/weapon/enginemaker/attack_self(mob/living/human/H)
	if (!istype(H.l_hand, /obj/item/stack/material/steel) && !istype(H.r_hand, /obj/item/stack/material/steel))
		H << "<span class = 'warning'>You need to have a steel stack in one of your hands in order to make this.</span>"
		return
	else
		steelamt = 0
		enginesize = 0
		if (istype(H.l_hand, /obj/item/stack/material/steel))
			steelamt = H.l_hand.amount
		else if (istype(H.r_hand, /obj/item/stack/material/steel))
			steelamt = H.r_hand.amount
		if (steelamt == 0)
			return

		var/display = list("Turbine Engine (73 sheets per 1000 cc)","Hot Bulb Engine (33 sheets per 1000 cc)","4-Stroke Gasoline Engine (50 sheets per 1000 cc)","4-Stroke Ethanol-Gasoline Engine (60 sheets per 1000 cc)","2-Stroke Gasoline Engine (40 sheets per 1000 cc)","Diesel Engine (40 sheets per 1000 cc)","Biodiesel Engine (45 sheets per 1000 cc)","Hesselman Engine (43 sheets per 1000 cc)", "Cancel")
		var/choice = WWinput(H, "What engine do you want to make?", "Engines", "Cancel", display)
		if (choice == "Cancel")
			return
		else if (choice == "Hot Bulb Engine (33 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 200, maximum 45000)") as num
			enginesize = Clamp(enginesize, 200, 45000)
			if ((enginesize/1000)*33 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*66] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,220,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*33
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*33
						var/obj/structure/engine/internal/hotbulb/NEN = new/obj/structure/engine/internal/hotbulb(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc hot bulb engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
		else if (choice == "Turbine Engine (73 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 250, maximum 18000)") as num
			enginesize = Clamp(enginesize, 250, 18000)
			if ((enginesize/1000)*73 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*136] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,220,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*73
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*73
						var/obj/structure/engine/internal/turbine/NEN = new/obj/structure/engine/internal/turbine(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc turbine engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
		else if (choice == "2-Stroke Gasoline Engine (40 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 49, maximum 1000)") as num
			enginesize = Clamp(enginesize, 49, 1000)
			if ((enginesize/1000)*40 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*90] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,200,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*40
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*40
						var/obj/structure/engine/internal/gasoline/twostroke/NEN = new/obj/structure/engine/internal/gasoline/twostroke(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc 2-S gasoline engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
		else if (choice == "4-Stroke Gasoline Engine (50 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 80, maximum 30000)") as num
			enginesize = Clamp(enginesize, 80, 30000)
			if ((enginesize/1000)*50 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*100] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,200,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*50
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*50
						var/obj/structure/engine/internal/gasoline/NEN = new/obj/structure/engine/internal/gasoline(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc 4-S gasoline engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
		else if (choice == "4-Stroke Ethanol-Gasoline Engine (60 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 80, maximum 30000)") as num
			enginesize = Clamp(enginesize, 80, 30000)
			if ((enginesize/1000)*60 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*120] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,200,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*60
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*60
						var/obj/structure/engine/internal/gasoline/ethanol/NEN = new/obj/structure/engine/internal/gasoline/ethanol(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc 4-S ethanol-gasoline engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
		else if (choice == "Diesel Engine (40 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 300, maximum 45000)") as num
			enginesize = Clamp(enginesize, 300, 45000)
			if ((enginesize/1000)*40 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*80] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,270,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*40
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*40
						var/obj/structure/engine/internal/diesel/NEN = new/obj/structure/engine/internal/diesel(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc diesel engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
		else if (choice == "Biodiesel Engine (45 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 300, maximum 45000)") as num
			enginesize = Clamp(enginesize, 300, 45000)
			if ((enginesize/1000)*45 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*90] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,270,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*45
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*45
						var/obj/structure/engine/internal/diesel/biodiesel/NEN = new/obj/structure/engine/internal/diesel/biodiesel(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc biodiesel engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
		else if (choice == "Hesselman Engine (43 sheets per 1000 cc)")
			enginesize = input(H, "Choose the engine size, in cc: (minimum 200, maximum 55000)") as num
			enginesize = Clamp(enginesize, 200, 55000)
			if ((enginesize/1000)*43 > steelamt)
				H << "You don't have enough steel. You need [(enginesize/1000)*86] and you have [steelamt]. Try building a smaller engine."
				return
			else
				H << "You start building the engine..."
				done = TRUE
				if (do_after(H,240,src))
					if (done)
						if (istype(H.l_hand, /obj/item/stack/material/steel))
							H.l_hand.amount -= (enginesize/1000)*43
						else if (istype(H.r_hand, /obj/item/stack/material/steel))
							H.r_hand.amount -= (enginesize/1000)*43
						var/obj/structure/engine/internal/hesselman/NEN = new/obj/structure/engine/internal/hesselman(get_turf(H))
						NEN.enginesize = enginesize
						NEN.weight = 20*(NEN.enginesize/1000)
						NEN.name = "[NEN.enginesize]cc hesselman engine"
						NEN.maxpower *= (NEN.enginesize/1000)
						NEN.fuelefficiency *= (NEN.enginesize/1000)
						H << "You finish building the engine."
						done = FALSE
						return
				else
					done = FALSE
					return
