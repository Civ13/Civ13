////////AXIS: MOVEMENT LOOP/////////

/obj/structure/vehicleparts/axis/proc/startmovementloop()
	moving = TRUE
	movementloop()
	movementsound()

/obj/structure/vehicleparts/axis/proc/movementsound()
	if (!moving)
		return
	playsound(loc, 'sound/machines/tank_moving.ogg',100, TRUE)
	spawn(30)
		movementsound()

/obj/structure/vehicleparts/axis/proc/movementloop()
	if (moving == TRUE)
		current_weight = 5
		for(var/obj/structure/vehicleparts/frame/FR in components)
			current_weight += FR.total_weight
		if (do_vehicle_check() && currentspeed > 0)
			for (var/obj/structure/vehicleparts/movement/W in wheels)
				W.icon_state = W.movement_icon
				W.update_icon()
			do_move()
		else
			for (var/obj/structure/vehicleparts/movement/W in wheels)
				W.icon_state = W.base_icon
				W.update_icon()
			currentspeed = 0
			moving = FALSE
			stopmovementloop()
		spawn(vehicle_m_delay+1)
			movementloop()
			return
	else
		return

/obj/structure/vehicleparts/axis/proc/stopmovementloop()
	moving = FALSE
	for (var/obj/structure/vehicleparts/movement/W in wheels)
		W.icon_state = W.base_icon
		W.update_icon()
	return

/obj/structure/vehicleparts/axis/proc/do_vehicle_check()
	if (check_engine())
		for(var/obj/structure/vehicleparts/frame/FR in components)
			var/turf/T = get_turf(get_step(FR.loc,dir))
			if (!T)
				moving = FALSE
				stopmovementloop()
				return FALSE
			for(var/obj/structure/O in T)
				if (O.density == TRUE && !(O in transporting))
					if (current_weight >= 55)
						visible_message("<span class='warning'>\the [src] crushes \the [O]!</span>","<span class='warning'>You crush \the [O]!</span>")
						O.Destroy()
					else
						visible_message("<span class='warning'>\the [src] hits \the [O]!</span>","<span class='warning'>You hit \the [O]!</span>")
						return FALSE
				else if (O.density == FALSE && !(O in transporting))
					visible_message("<span class='warning'>\the [src] crushes \the [O]!</span>","<span class='warning'>You crush \the [O]!</span>")
					O.Destroy()
			if (T.density == TRUE)
				visible_message("<span class='warning'>\the [src] hits \the [T]!</span>","<span class='warning'>You hit \the [T]!</span>")
				return FALSE
			for(var/obj/covers/CV in T && !(CV in transporting))
				if (CV.density == TRUE)
					visible_message("<span class='warning'>\the [src] hits \the [CV]!</span>","<span class='warning'>You hit \the [CV]!</span>")
					return FALSE
			for(var/mob/living/L in T && !(L in transporting))
				if (current_weight >= 45)
					visible_message("<span class='warning'>\the [src] runs over \the [L]!</span>","<span class='warning'>You run over \the [L]!</span>")
					L.crush()
				else
					if (ishuman(L))
						var/mob/living/carbon/human/HH = L
						HH.adjustBruteLoss(rand(7,16)*abs(currentspeed))
						HH.Weaken(rand(2,5))
						visible_message("<span class='warning'>\the [src] hits \the [L]!</span>","<span class='warning'>You hit \the [L]!</span>")
						L.forceMove(get_turf(get_step(T,dir)))
					else if (istype(L,/mob/living/simple_animal))
						var/mob/living/simple_animal/SA = L
						SA.adjustBruteLoss(rand(7,16)*abs(currentspeed))
						if (SA.mob_size >= 30)
							visible_message("<span class='warning'>\the [src] hits \the [SA]!</span>","<span class='warning'>You hit \the [SA]!</span>")
							L.forceMove(get_turf(get_step(T,dir)))
						else
							visible_message("<span class='warning'>\the [src] runs over \the [SA]!</span>","<span class='warning'>You run over \the [SA]!</span>")
							SA.crush()
			var/canpass = FALSE
			for(var/obj/covers/CVV in T)
				if (CVV.density == FALSE)
					canpass = TRUE
			if ((!istype(T, /turf/floor/beach/water/deep) ||  istype(T, /turf/floor/beach/water/deep) && canpass == TRUE) && T.density == FALSE  || istype(T, /turf/floor/trench/flooded))
				canpass = TRUE
			else
				moving = FALSE
				stopmovementloop()
				return FALSE
		return TRUE
	else
		moving = FALSE
		stopmovementloop()
		return FALSE
/obj/structure/vehicleparts/axis/proc/check_engine()

	if (!engine || !engine.fueltank)
		engine.on = FALSE
		return FALSE
	else
		if (engine.fueltank.reagents.total_volume <= 0)
			engine.fueltank.reagents.total_volume = 0
			engine.on = FALSE
			return FALSE
		else
			if (engine.on)
				return TRUE
			else
				return FALSE
		return FALSE

	return TRUE

/obj/structure/vehicleparts/axis/proc/do_move()
	add_transporting()
	var/m_dir = loc.dir
	if (reverse)
		m_dir = OPPOSITE_DIR(dir)
	for (var/atom/movable/M in transporting)
		if ((istype(M, /obj/structure) || istype(M, /obj/item)) && !istype(M, /obj/structure/vehicleparts/frame) && !istype(M, /obj/structure/wild))
			var/obj/MO = M
			MO.forceMove(get_step(MO.loc, m_dir))
			if (!istype(M, /obj/structure/cannon) && !istype(M, /obj/structure/bed/chair))
				MO.dir = dir
				MO.update_icon()
			if (istype(M, /obj/structure/bed/chair/drivers))
				MO.dir = dir
				MO.update_icon()
			if (istype(M, /obj/structure/vehicleparts/movement))
				var/obj/structure/vehicleparts/movement/MV = M
				if (MV.reversed)
					MV.dir = OPPOSITE_DIR(dir)
		if (istype(M, /mob/living))
			var/mob/living/ML = M
			ML.forceMove(get_step(ML.loc, m_dir))
	for (var/obj/structure/vehicleparts/frame/F in components)
		F.dir = dir
		F.forceMove(get_step(F.loc, m_dir))
		F.update_icon()

	return

/obj/structure/vehicleparts/axis/proc/add_transporting()
	transporting = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (!F || !(F in range(7,loc)))
			components -= F
		var/turf/T = get_turf(F)
		for (var/atom/movable/M in T)
			if ((istype(M, /mob/living) || istype(M, /obj/structure) || istype(M, /obj/item)) && !(M in transporting))
				transporting += M
	for (var/obj/structure/vehicleparts/movement/MV in wheels)
		transporting += MV
	return transporting.len

/obj/structure/vehicleparts/axis/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && !VP.axis)
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You connect \the [src] to \the [VP]."
		VP.axis = src
		VP.anchored = TRUE
		components += VP
		VP.name = "central [VP.name]"
		loc = VP
		return