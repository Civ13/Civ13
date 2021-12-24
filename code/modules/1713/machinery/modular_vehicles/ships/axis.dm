////////AXIS: MOVEMENT LOOP/////////
/obj/structure/vehicleparts/axis
	var/list/masts = list()
	var/anchor = TRUE
	var/ship = FALSE
/obj/structure/vehicleparts/axis/ship
	name = "ship rudder control"
	desc = "An axis connecting the rudder to the ship's wheel."
	currentspeed = 0
	speeds = 3
	maxpower = 1200
	speedlist = list(1=15,2=11,3=7)
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	ship = TRUE

/obj/structure/vehicleparts/axis/ship/heavy
	name = "heavy rudder control"
	speeds = 3
	maxpower = 2500
	speedlist = list(1=18,2=14,3=10)

/obj/structure/vehicleparts/axis/ship/movementsound()
	if (!moving)
		return
	playsound(loc, 'sound/machines/wood_boat.ogg',100, TRUE)
	spawn(100)
		movementsound()

/obj/structure/vehicleparts/axis/ship/movementloop()
	if (moving == TRUE)
		get_weight()
		if (masts.len)
			check_sails()
		if (do_vehicle_check() && currentspeed > 0)
			for (var/obj/structure/vehicleparts/movement/sails/S in masts)
				if (!S.sails || S.broken)
					moving = FALSE
					stopmovementloop()
					return FALSE
				else
					S.update_icon()
			do_move()
		else
			currentspeed = 0
			moving = FALSE
			stopmovementloop()
			return FALSE
		spawn(vehicle_m_delay+1)
			movementloop()
			return FALSE
	else
		return TRUE

/obj/structure/vehicleparts/axis/ship/stopmovementloop()
	moving = FALSE
	currentspeed = 0
	for (var/obj/structure/vehicleparts/movement/sails/S in masts)
		S.update_icon()
	return


/obj/structure/vehicleparts/axis/ship/do_vehicle_check()
	if (anchor)
		visible_message("<span class = 'warning'>\The [name] can't move, the anchor is down!</span>")
		moving = FALSE
		stopmovementloop()
		return FALSE
	var/enginestate = check_engine()
	if (enginestate)
		if (enginestate == 1) //sails
			for(var/obj/structure/vehicleparts/movement/sails/MV in masts)
				if (!engine || (engine && !engine.on))
					if (MV.broken)
						visible_message("<span class = 'warning'>\The [name] can't move, a [MV.ntype] is broken!</span>")
						moving = FALSE
						stopmovementloop()
						return FALSE
					else if (!MV.sails)
						visible_message("<span class = 'warning'>\The [name] can't move, a [MV.ntype] has no sail!</span>")
						moving = FALSE
						stopmovementloop()
						return FALSE
					else if (!MV.sails_on)
						visible_message("<span class = 'warning'>\The [name] can't move, the sails are down!</span>")
						moving = FALSE
						stopmovementloop()
						return FALSE
					else if (anchor)
						visible_message("<span class = 'warning'>\The [name] can't move, the anchor is down!</span>")
						moving = FALSE
						stopmovementloop()
						return FALSE
		else //engine
			if (!engine || !engine.on)
				return FALSE
			else if (anchor)
				visible_message("<span class = 'warning'>\The [name] can't move, the anchor is down!</span>")
				moving = FALSE
				stopmovementloop()
				return FALSE
		for(var/obj/structure/vehicleparts/frame/FR in components)
			var/turf/T = get_turf(get_step(FR.loc,dir))
			var/area/A = get_area(T)
			if (map && A && map.caribbean_blocking_area_types.Find(A.type))
				if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
					visible_message("<span class = 'danger'>You cannot cross the grace wall yet!</span>")
					moving = FALSE
					stopmovementloop()
					return FALSE
			if (reverse)
				T = get_turf(get_step(FR.loc,OPPOSITE_DIR(dir)))
			if (!T)
				moving = FALSE
				stopmovementloop()
				return FALSE
			for (var/obj/item/mine/at/MAT in T)
				if (MAT.anchored)
					MAT.trigger(FR)
			var/turf/TT = get_turf(get_step(T, dir))
			if (reverse)
				TT = get_turf(get_step(T,OPPOSITE_DIR(dir)))
			if (!TT)
				moving = FALSE
				stopmovementloop()
			for(var/mob/living/L in TT)
				var/protec = FALSE
				for (var/obj/structure/vehicleparts/frame/FRR in L.loc)
					protec = TRUE
				if (!protec)
					if (current_weight >= 800)
						visible_message("<span class='warning'>\the [src] goes over \the [L]!</span>","<span class='warning'>You go over \the [L]!</span>")
						L.crush()
						if (L)
							qdel(L)
					else
						if (ishuman(L))
							var/mob/living/human/HH = L
							HH.adjustBruteLoss(rand(7,16)*abs(currentspeed))
							HH.Weaken(rand(2,5))
							visible_message("<span class='warning'>\the [src] hits \the [L]!</span>","<span class='warning'>You hit \the [L]!</span>")
							L.forceMove(get_turf(get_step(TT,dir)))
						else if (istype(L,/mob/living/simple_animal))
							var/mob/living/simple_animal/SA = L
							SA.adjustBruteLoss(rand(7,16)*abs(currentspeed))
							if (SA.mob_size >= 30)
								visible_message("<span class='warning'>\the [src] hits \the [SA]!</span>","<span class='warning'>You hit \the [SA]!</span>")
								L.forceMove(get_turf(get_step(TT,dir)))
							else
								visible_message("<span class='warning'>\the [src] runs over \the [SA]!</span>","<span class='warning'>You run over \the [SA]!</span>")
								SA.crush()
			for(var/obj/structure/O in T)
				var/done = FALSE
				for (var/obj/structure/vehicleparts/frame/FM in O.loc)
					done = TRUE
					if (FM.axis != src)
						visible_message("<span class='warning'>\the [src] hits \the [O]!</span>","<span class='warning'>You hit \the [O]!</span>")
						moving = FALSE
						stopmovementloop()
						return FALSE
				if (!done)
					if (O.density == TRUE && !(O in transporting))
						if (current_weight >= 400 && !istype(O, /obj/structure/mailbox) && !istype(O, /obj/structure/barricade/antitank) && !istype(O, /obj/structure/vehicleparts/frame)&& !istype(O, /obj/structure/vehicleparts/movement))
							visible_message("<span class='warning'>\the [src] crushes \the [O]!</span>","<span class='warning'>You crush \the [O]!</span>")
							qdel(O)
						else
							visible_message("<span class='warning'>\the [src] hits \the [O]!</span>","<span class='warning'>You hit \the [O]!</span>")
							return FALSE
					else if (O.density == FALSE && !(O in transporting))
						if (!istype(O, /obj/structure/sign/traffic/zebracrossing) && !istype(O, /obj/structure/sign/traffic/side) && !istype(O, /obj/structure/sign/traffic/central) && !istype(O, /obj/structure/rails))
	//						visible_message("<span class='warning'>\the [src] crushes \the [O]!</span>","<span class='warning'>You crush \the [O]!</span>")
							qdel(O)
			if (T.density == TRUE)
				visible_message("<span class='warning'>\the [src] hits \the [T]!</span>","<span class='warning'>You hit \the [T]!</span>")
				moving = FALSE
				stopmovementloop()
				return FALSE
			for(var/obj/covers/CV in TT)
				if  (!(CV in transporting))
					visible_message("<span class='warning'>\the [src] hits \the [CV]!</span>","<span class='warning'>You hit \the [CV]!</span>")
					moving = FALSE
					stopmovementloop()
					return FALSE
			for(var/obj/item/I in TT)
				if (!(I in transporting) || istype(I, /obj/item/ammo_casing))
					qdel(I)

			if ((!istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/beach/water/ice)) && !istype(T, /turf/floor/trench/flooded))
				moving = FALSE
				stopmovementloop()
				return FALSE
		return TRUE
	else if (enginestate == 0)
		moving = FALSE
		stopmovementloop()
		return FALSE
	else
		moving = FALSE
		stopmovementloop()
		return FALSE

/obj/structure/vehicleparts/axis/ship/check_engine()
	if (!engine)
		if (masts.len <= 0)
			return FALSE
		else if (masts.len >= 1)
			if (get_weight() > maxpower)
				visible_message("<span class='warning'>\The [src] is too overloaded!</span>")
				return FALSE
			return 1

	else if (engine && engine.on)
		if (istype(engine, /obj/structure/engine/internal) && !engine.fueltank)
			engine.on = FALSE
			return FALSE
		else if (engine && istype(engine, /obj/structure/engine/internal) && engine.fueltank && engine.fueltank.reagents && engine.fueltank.reagents.total_volume <= 0)
			engine.fueltank.reagents.total_volume = 0
			engine.on = FALSE
			return FALSE
		else
			if (istype(engine, /obj/structure/engine/external))
				if (get_weight() > engine.maxpower*20 || get_weight() > maxpower)
					visible_message("<span class='warning'>\The [engine] struggles and stalls!</span>")
					return FALSE
			else
				if (get_weight() > engine.maxpower*2 || get_weight() > maxpower)
					visible_message("<span class='warning'>\The [engine] struggles and stalls!</span>")
					return FALSE
			if (engine && engine.on)
				return 2
			else if (engine && !engine.on)
				return FALSE
			return FALSE
	else
		if (masts.len <= 0)
			return FALSE
		else if (masts.len >= 1)
			if (get_weight() > maxpower)
				visible_message("<span class='warning'>\The [src] is too overloaded!</span>")
				return FALSE
			return 1

	return 1

/obj/structure/vehicleparts/axis/ship/add_transporting()
	transporting = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (!F || !(F in range(7,loc)))
			components -= F
		var/turf/T = get_turf(F)
		for (var/atom/movable/M in T)
		 /* TODO: Naval Mines
			if (istype(M, /obj/item/mine/at))
				var/obj/item/mine/at/MAT = M
				if (MAT.anchored)
					MAT.trigger(F)
		*/
			if ((istype(M, /mob/living) || istype(M, /obj/structure) || istype(M, /obj/item)) && !(M in transporting))
				transporting += M
	return transporting.len


//basically, a matrix works like this:
//matrix_l gives the horizontal length, matrix_h gives the vertical height, assuming its facing NORTH.
//so if we have a 3x4 vehicle, the matrix will look like this:
//
//|	1,1	|	1,2	|	1,3	|	1,4	|
//|	2,1	|	2,2	|	2,3	|	2,4	|
//|	3,1	|	3,2	|	3,3	|	3,4	|
//|	4,1	|	4,2	|	4,3	|	4,4	|
//
//the matrix always has to be a square with the sides being the value of largest between the length and height.
//in this case, 1,1 is the FL, 1,3 is the FR, 4,1 is the BL, 4,3 is the BR.
//so if we turn LEFT: we will be facing EAST, and it will change to:

/obj/structure/vehicleparts/axis/ship/attack_hand(var/mob/living/human/H)
	if (!ishuman(H))
		return
	for(var/obj/structure/vehicleparts/frame/F1 in get_turf(get_step(src, WEST)))
		H << "<span class='notice'>The axis needs to be placed at the <b>TOP LEFT</b> corner!</span>"
		return
	for(var/obj/structure/vehicleparts/frame/F2 in get_turf(get_step(src, NORTH)))
		H << "<span class='notice'>The axis needs to be placed at the <b>TOP LEFT</b> corner!</span>"
		return
	var/inp = WWinput(H, "Are you sure you wan't to assemble a ship here? This has to be the top left corner.", "Vehicle Assembly", "No", list("No", "Yes"))
	if (inp == "No")
		return
	var/found_base=FALSE
	for(var/obj/structure/vehicleparts/frame/F in loc)
		if (F.axis && F.axis != src)
			return
		found_base=TRUE
		var/customname = input(H, "What do you want to name this ship?") as text
		if (!customname || customname == "")
			name = "[H]'s ship"
		else
			name = customname
		dir = 1
		new/obj/effect/autoassembler(locate(x+2,y-2,z))
		H << "<span class='warning'>Vehicle assembled.</span>"
		for (var/obj/O in components)
			O.update_icon()
		return
	if (!found_base)

		for(var/obj/structure/vehicleparts/frame/F in locate(x+1,y-1,z))
			if (F.axis && F.axis != src)
				return
			var/customname = input(H, "What do you want to name this ship?") as text
			if (!customname || customname == "")
				name = "[H]'s ship"
			else
				name = customname
			dir = 1
			forceMove(F.loc)
			new/obj/effect/autoassembler(locate(x+2,y-2,z))
			H << "<span class='warning'>Vehicle assembled.</span>"
			for (var/obj/O in components)
				O.update_icon()
			return

/obj/structure/vehicleparts/axis/ship/proc/check_sails()
	var/timer = 15
	if (!masts.len || !moving)
		return
	if(reverse)
		if (!istype(get_turf(get_step(src,OPPOSITE_DIR(dir))), /turf/floor/beach/water) && !istype(get_turf(get_step(src,OPPOSITE_DIR(dir))), /turf/floor/trench/flooded))
			visible_message("<span class='notice'>\The [src] crashes into \the [get_turf(get_step(src,dir))]!</span>")
			moving = FALSE
			stopmovementloop()
			return
	else
		if (!istype(get_turf(get_step(src,dir)), /turf/floor/beach/water) && !istype(get_turf(get_step(src,dir)), /turf/floor/trench/flooded))
			visible_message("<span class='notice'>\The [src] crashes into \the [get_turf(get_step(src,dir))]!</span>")
			moving = FALSE
			stopmovementloop()
			return
	var/found = FALSE
	for(var/obj/structure/vehicleparts/movement/sails/SL in masts)
		found = TRUE
		break
	if (found)
		switch(map.windspeedvar)
			if (0)
				timer = 40
			if (1)
				timer = 15
			if (2)
				timer = 11
			if (3)
				timer = 7
			if (4)
				timer = 4
		switch(map.winddirection)
			if ("North")
				if (dir == SOUTH)
					timer /= 1
				if  (dir == WEST || dir == EAST)
					timer /= 0.4
				if (dir == NORTH)
					timer /= 0.1
			if ("South")
				if (dir == NORTH)
					timer /= 1
				if  (dir == WEST || dir == EAST)
					timer /= 0.4
				if (dir == SOUTH)
					timer /= 0.1
			if ("East")
				if (dir == WEST)
					timer /= 1
				if  (dir == NORTH || dir == SOUTH)
					timer /= 0.4
				if (dir == EAST)
					timer /= 0.1
			if ("West")
				if (dir == EAST)
					timer /= 1
				if  (dir == NORTH || dir == SOUTH)
					timer /= 0.4
				if (dir == WEST)
					timer /= 0.1
	currentspeed = timer
	vehicle_m_delay = currentspeed
	speedlist[1] = timer