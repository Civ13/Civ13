var/global/list/tank_names_german = list("Lute", "Greta", "Erika", "Sieg", "Teufel", "Charlotte")
var/global/list/tank_names_soviet = list("Slavianka", "Katya", "Rodina", "Vernyi", "Krasavets", "Grom")
var/global/list/tank_names_japanese = list("Banzai", "Satsu-Jin", "Koroshite", "Sakura", "Chibi Chi-to", "I-Go")
var/global/list/tank_names_usa = list("Charlie", "Alpha", "Foxtrot", "Tango", "Echo", "Zipper-maker", "Uncle Sam", "Steel Coffin")

////////AXIS: MOVEMENT LOOP/////////
/obj/structure/vehicleparts/axis
	var/maxdist = 5 //the highest of length and width
	var/turntimer = 15
	var/doorcode = 0
/obj/structure/vehicleparts/axis/ex_act(severity)
	switch(severity)
		if (1.0)
			return
		if (2.0)
			return
		if (3.0)
			return
/*
/obj/structure/vehicleparts/axis/Destroy()
	for(var/obj/structure/vehicleparts/frame/F in components)
		F.axis = null
	wheel = null
	visible_message("<span class='danger'>The [name] axis gets wrecked!</span>")
	qdel(src)
*/
/obj/structure/vehicleparts/axis/proc/startmovementloop()
	if (world.time <= lastmovementloop)
		return FALSE
	lastmovementloop = world.time+15
	if (isemptylist(corners))
		check_corners()
	if (isemptylist(matrix))
		check_matrix()
	moving = TRUE
	movementloop()
	movementsound()

/obj/structure/vehicleparts/axis/proc/movementsound()
	if (!moving)
		return
	if (istype(wheels[1],/obj/structure/vehicleparts/movement/tracks))
		playsound(loc, 'sound/machines/tank_moving.ogg',100, TRUE)
		spawn(30)
			movementsound()

/obj/structure/vehicleparts/axis/proc/movementloop()
	if (moving == TRUE)
		get_weight()
		if (do_vehicle_check() && currentspeed > 0)
			for (var/obj/structure/vehicleparts/movement/W in wheels)
				if (W.broken)
					moving = FALSE
					stopmovementloop()
					return
				else
					W.update_icon()
			do_move()
		else
			currentspeed = 0
			moving = FALSE
			stopmovementloop()
			return
		spawn(vehicle_m_delay+1)
			movementloop()
			return
	else
		return

/obj/structure/vehicleparts/axis/proc/stopmovementloop()
	moving = FALSE
	currentspeed = 0
	for (var/obj/structure/vehicleparts/movement/W in wheels)
		W.update_icon()
	return

/obj/structure/vehicleparts/axis/proc/get_weight()
	current_weight = 5
	for(var/obj/structure/vehicleparts/frame/FR in components)
		current_weight += FR.total_weight()
	return current_weight

/obj/structure/vehicleparts/axis/proc/do_vehicle_check()
	if (check_engine())
		if (wheels.len < 4)
			moving = FALSE
			stopmovementloop()
			return FALSE
		for(var/obj/structure/vehicleparts/movement/MV in wheels)
			if (MV.broken)
				visible_message("<span class = 'warning'>\The [name] can't move, a [MV.ntype] is broken!</span>")
				moving = FALSE
				stopmovementloop()
				return FALSE
			if (MV.ntype == "track")
				var/turf/TF = get_turf(MV)
				if (istype(TF, /turf/floor/grass/jungle))
					TF.ChangeTurf (/turf/floor/dirt/jungledirt)
				else if (istype(TF, /turf/floor/grass))
					TF.ChangeTurf (/turf/floor/dirt)
				else if (istype(TF, /turf/floor/dirt/ploughed/flooded))
					TF.ChangeTurf (/turf/floor/dirt/flooded)
				else if (istype(TF, /turf/floor/dirt/ploughed))
					TF.ChangeTurf (/turf/floor/dirt)
		for(var/obj/structure/vehicleparts/frame/FR in components)
			var/turf/T = get_turf(get_step(FR.loc,dir))
			var/area/A = get_area(T)
			if (map && A && map.caribbean_blocking_area_types.Find(A.type))
				if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
					visible_message("<span class = 'danger'>You cannot cross the grace wall yet!</span>")
					moving = FALSE
					stopmovementloop()
					return FALSE
			if (map && map.check_caribbean_block(driver,T))
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
				else
					qdel(MAT)
					visible_message("<span class='warning'>\the [src] crushes \the [MAT]!</span>","<span class='warning'>You crush \the [MAT]!</span>")
			for (var/obj/item/mine/boobytrap/MAT in T)
				if (MAT.anchored)
					qdel(MAT)
			for (var/obj/item/mine/ap/MAT in T)
				if (MAT.anchored)
					qdel(MAT)
			for (var/obj/item/mine/ap/MAT in T)
				if (MAT.anchored)
					qdel(MAT)
			var/turf/TT = get_turf(get_step(T, dir))
			if (reverse)
				TT = get_turf(get_step(T,OPPOSITE_DIR(dir)))
			if (!TT)
				moving = FALSE
				stopmovementloop()
			for (var/obj/item/weapon/grenade/G in TT)
				if (G.active)
					G.prime()
			for (var/obj/item/weapon/grenade/GG in T)
				if (GG.active)
					GG.prime()
			for(var/mob/living/L in TT)
				var/protec = FALSE
				for (var/obj/structure/vehicleparts/frame/FRR in L.loc)
					protec = TRUE
				if (!protec)
					if (current_weight >= 800)
						visible_message("<span class='warning'>\the [src] runs over \the [L]!</span>","<span class='warning'>You run over \the [L]!</span>")
						for(var/obj/item/I in L)
							qdel(I)
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
								for(var/obj/item/I in SA)
									qdel(I)
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
						if (current_weight >= 400 && !istype(O, /obj/structure/redmailbox) && !istype(O, /obj/structure/barricade/antitank) && !istype(O, /obj/structure/vehicleparts/frame)&& !istype(O, /obj/structure/vehicleparts/movement)&& !istype(O, /obj/structure/barricade/stone_h)&& !istype(O, /obj/structure/barricade/stone_v)&& !istype(O, /obj/structure/barricade/jap_h) && !istype(O, /obj/structure/barricade/jap_v)&& !istype(O, /obj/structure/barricade/jap_h_l)&& !istype(O, /obj/structure/barricade/jap_h_r)&& !istype(O, /obj/structure/barricade/jap_v_b)&& !istype(O, /obj/structure/barricade/jap_v_t)&& !istype(O, /obj/structure/barricade/sandstone_h)&& !istype(O, /obj/structure/barricade/sandstone_v)&& !istype(O, /obj/structure/barricade/sandstone_v/crenelated)&& !istype(O, /obj/structure/barricade/sandstone_h/crenelated)&& !istype(O, /obj/structure/barricade/stone_v/crenelated) && !istype(O, /obj/structure/gate) && !istype(O, /obj/structure/billboard))
							visible_message("<span class='warning'>\the [src] crushes \the [O]!</span>","<span class='warning'>You crush \the [O]!</span>")
							qdel(O)
						else
							visible_message("<span class='warning'>\the [src] hits \the [O]!</span>","<span class='warning'>You hit \the [O]!</span>")
							return FALSE
					else if (O.density == FALSE && !(O in transporting))
						if (!istype(O, /obj/structure/sign/traffic/zebracrossing) && !istype(O, /obj/structure/sign/traffic/central) && !istype(O, /obj/structure/sign/traffic/side) && !istype(O, /obj/structure/sign/traffic/side) && !istype(O, /obj/structure/rails) && !istype(O, /obj/structure/cable) && !istype(O, /obj/structure/gate) && !istype(O, /obj/structure/lamp/lamppost_small/) && !istype(O, /obj/structure/lamp/lamp_big/alwayson) && !istype(O, /obj/structure/lamp/lamp_small/alwayson))
	//						visible_message("<span class='warning'>\the [src] crushes \the [O]!</span>","<span class='warning'>You crush \the [O]!</span>")
							qdel(O)

			if (T.density == TRUE)
				visible_message("<span class='warning'>\the [src] hits \the [T]!</span>","<span class='warning'>You hit \the [T]!</span>")
				moving = FALSE
				stopmovementloop()
				return FALSE
			for(var/obj/covers/CV in TT && !(CV in transporting))
				if (current_weight < 600)
					if (CV.density || CV.wall)
						visible_message("<span class='warning'>\the [src] hits \the [CV]!</span>","<span class='warning'>You hit \the [CV]!</span>")
						moving = FALSE
						stopmovementloop()
						return FALSE
			for(var/obj/item/ammo_casing/AC in T)
				if(!AC.BB)
					qdel(AC) //to prevent the "empty empty empty empty"... spam
			for(var/obj/item/I in TT && !(I in transporting))
				qdel(I)
			for(var/obj/effect/fire/BO in T && !(BO in transporting))
				qdel(BO)
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
	if (!engine)
		return FALSE
	if (engine && !engine.fueltank)
		engine.on = FALSE
		return FALSE
	else if (get_weight() > engine.maxpower*2 || get_weight() > maxpower)
		visible_message("<span class='warning'>\The [engine] struggles and stalls!</span>")
		return FALSE
	else
		if (engine && engine.fueltank && engine.fueltank.reagents && engine.fueltank.reagents.total_volume <= 0)
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
		if ((istype(M, /obj/structure) || istype(M, /obj/item)) && !istype(M, /obj/structure/vehicleparts/frame) && (!istype(M, /obj/structure/vehicleparts/movement) || istype(M, /obj/structure/vehicleparts/movement/sails)) && !istype(M, /obj/structure/wild))
			var/obj/MO = M
			MO.forceMove(get_step(MO.loc, m_dir))
			if (!istype(M, /obj/structure/cannon) && !istype(M, /obj/structure/catapult))
				MO.dir = dir
				MO.update_icon()
		if (istype(M, /obj/structure/vehicleparts/movement) && !istype(M, /obj/structure/vehicleparts/movement/sails))
			var/obj/structure/vehicleparts/movement/MV = M
			if (MV.reversed)
				MV.dir = OPPOSITE_DIR(dir)
			else
				MV.dir = dir
			MV.forceMove(get_step(MV.loc, MV.dir))
			MV.update_icon()
		if (istype(M, /mob/living))
			var/mob/living/ML = M
			ML.forceMove(get_step(ML.loc, m_dir))
	for (var/obj/F in components)
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
			if (istype(M, /obj/item/mine/at))
				var/obj/item/mine/at/MAT = M
				if (MAT.anchored)
					MAT.trigger(F)
				else
					qdel(MAT)
					visible_message("<span class='warning'>\the [src] crushes \the [MAT]!</span>","<span class='warning'>You crush \the [MAT]!</span>")
			if (istype(M, /obj/item/mine/boobytrap))
				var/obj/item/mine/boobytrap/BAT = M
				if (BAT.anchored)
					qdel(BAT)
					visible_message("<span class='warning'>\the [src] crushes \the [BAT]!</span>","<span class='warning'>You crush \the [BAT]!</span>")
			if (istype(M, /obj/item/mine/ap))
				var/obj/item/mine/ap/BAT = M
				if (BAT.anchored)
					qdel(BAT)
					visible_message("<span class='warning'>\the [src] crushes \the [BAT]!</span>","<span class='warning'>You crush \the [BAT]!</span>")
			if ((istype(M, /mob/living) || istype(M, /obj/structure) || istype(M, /obj/item)) && !(M in transporting))
				if (!istype(M, /obj/structure/sign/traffic/zebracrossing) && !istype(M, /obj/structure/sign/traffic/side) && !istype(M, /obj/structure/sign/traffic/central) && !istype(M, /obj/structure/rails) && !istype(M, /obj/structure/cable) && !istype(M, /obj/structure/redmailbox) && !istype(M, /obj/structure/gate) && !istype(M, /obj/structure/lamp/lamppost_small/) && !istype(M, /obj/structure/lamp/lamp_big/alwayson) && !istype(M, /obj/structure/lamp/lamp_small/alwayson) && !istype(M, /obj/structure/billboard))
					transporting += M
	return transporting.len

/obj/structure/vehicleparts/axis/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && !VP.axis)
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You connect \the [src] to \the [VP]."
		VP.axis = src
		VP.anchored = TRUE
		components += VP
		VP.name = "[name] axis"
		loc = VP
		return

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

/obj/structure/vehicleparts/axis/proc/check_matrix()
	if (corners[1] == null || corners[2] == null || corners[3] == null || corners[4] == null)
		world.log << "ERROR BUILDING MATRIX! (Incomplete Corner List)"
		return FALSE
	if (dir == NORTH || dir == SOUTH)
		matrix_l = abs(corners[2].x-corners[1].x)+1
		matrix_h = abs(corners[4].y-corners[2].y)+1
	else if (dir == WEST || dir == EAST)
		matrix_l = abs(corners[2].y-corners[1].y)+1
		matrix_h = abs(corners[4].x-corners[2].x)+1
	var/mside = max(matrix_l, matrix_h)
	if (mside == 0)
		world.log << "ERROR BUILDING MATRIX! (No Size)"
		return FALSE
	else if (mside < 0)
		mside = abs(mside)
	var/locx = 1
	var/locy = 1
	for (locx in 1 to maxdist)
		for (locy in 1 to maxdist)
			matrix += list("[locx],[locy]" = list(null,locx,locy, "[locx],[locy]"))
			locy++
		locx++
	var/obj/FFL = corners[2]
	if (!istype(corners[2], /obj/structure/vehicleparts/frame) && !istype(corners[2], /obj/effect/pseudovehicle))

		world.log << "ERROR BUILDING MATRIX! (Front-Left doesnt exist)"
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FM in components)
		var/disx = abs(FM.y-FFL.y)
		var/disy = abs(FM.x-FFL.x)
		switch(FFL.dir)
			if (SOUTH)
				matrix["[disx+1],[disy+1]"] = list(FM, disx+1, disy+1,"[disx+1],[disy+1]")
			if (NORTH)
				matrix["[disx+1],[disy+1]"] = list(FM, disx+1, disy+1,"[disx+1],[disy+1]")
			if (EAST)
				matrix["[disx+1],[disy+1]"] = list(FM, disy+1, disx+1,"[disy+1],[disx+1]")
			if (WEST)
				matrix["[disx+1],[disy+1]"] = list(FM, disy+1, disx+1,"[disy+1],[disx+1]")
	for (var/obj/effect/pseudovehicle/PV in components)
		var/disx = abs(PV.y-FFL.y)
		var/disy = abs(PV.x-FFL.x)
		switch(FFL.dir)
			if (SOUTH)
				matrix["[disx+1],[disy+1]"] = list(PV, disx+1, disy+1,"[disx+1],[disy+1]")
			if (NORTH)
				matrix["[disx+1],[disy+1]"] = list(PV, disx+1, disy+1,"[disx+1],[disy+1]")
			if (EAST)
				matrix["[disx+1],[disy+1]"] = list(PV, disy+1, disx+1,"[disy+1],[disx+1]")
			if (WEST)
				matrix["[disx+1],[disy+1]"] = list(PV, disy+1, disx+1,"[disy+1],[disx+1]")

	return TRUE
/obj/structure/vehicleparts/axis/proc/check_corners()
	corners = list(null, null, null, null) //Front-Right, Front-Left, Back-Right,Back-Left; FR, FL, BR, BL
	for (var/obj/structure/vehicleparts/frame/F in components)
		var/sides = ""
		var/turf/T1 = get_turf(get_step(F,NORTH))
		for (var/i in list(NORTH,SOUTH,EAST,WEST))
			T1 =  get_turf(get_step(F,i))
			for (var/obj/structure/vehicleparts/frame/FF in T1)
				if (FF.axis == F.axis)
					sides = "[sides][i]"
		if (length(sides) == 2)
			if (findtext(sides,"1") && findtext(sides,"4")) //SW corner
				if (dir == SOUTH) //FR
					corners[1] = F
				else if (dir == NORTH) //BL
					corners[4] = F
				else if  (dir == WEST) //FL
					corners[2] = F
				else if (dir == EAST) // BR
					corners[3] = F
			if (findtext(sides,"1") && findtext(sides,"8")) //SE corner
				if (dir == SOUTH) //FL
					corners[2] = F
				else if (dir == NORTH) //BR
					corners[3] = F
				else if  (dir == WEST) //BL
					corners[4] = F
				else if (dir == EAST) // FR
					corners[1] = F
			if (findtext(sides,"2") && findtext(sides,"4")) //NW corner
				if (dir == SOUTH) //BR
					corners[3] = F
				else if (dir == NORTH) //FL
					corners[2] = F
				else if  (dir == WEST) //FR
					corners[1] = F
				else if (dir == EAST) // BL
					corners[4] = F
			if (findtext(sides,"2") && findtext(sides,"8")) //NE corner
				if (dir == SOUTH) //BL
					corners[4] = F
				else if (dir == NORTH) //FR
					corners[1] = F
				else if  (dir == WEST) //BR
					corners[3] = F
				else if (dir == EAST) // FL
					corners[2] = F
	maxdist=1+max(abs(corners[1].x-corners[2].x),abs(corners[1].y-corners[3].y),abs(corners[1].y-corners[2].y),abs(corners[1].x-corners[3].x))
	for(var/obj/structure/vehicleparts/frame/FM in components)
		for(var/obj/structure/vehicleparts/movement/MV in wheels)
			if (!MV.axis && MV.x == FM.x && MV.y == FM.y && MV.z == FM.z)
				MV.axis = src
				MV.connected = FM
				FM.mwheel = MV
	for(var/obj/structure/vehicleparts/movement/MV in wheels)
		//Front-Right, Front-Left, Back-Right,Back-Left; FR, FL, BR, BL
		if (MV.connected == corners[1])
			MV.reversed = FALSE
		else if (MV.connected == corners[2])
			if (MV.ntype == "wheel")
				MV.reversed = TRUE
			else
				MV.reversed = FALSE
		else if (MV.connected == corners[3])
			if (MV.ntype == "wheel")
				MV.reversed = TRUE
			else
				MV.reversed = FALSE
		else if (MV.connected == corners[4])
			if (MV.ntype == "wheel")
				MV.reversed = TRUE
			else
				MV.reversed = TRUE
		else
			return

		if (MV.reversed)
			MV.dir = OPPOSITE_DIR(dir)
		else
			MV.dir = dir
	if (corners[1] != null && corners[2] != null && corners[3] != null && corners[4] != null)
		return TRUE
	else
		if (!istype(src,/obj/structure/vehicleparts/axis/ship))
			world.log << "ERROR BUILDING CORNER LIST!"
		else
			if (!corners[1])
				for(var/obj/effect/pseudovehicle/PVV in locate(loc.x-1,loc.y+1))
					corners[1] = PVV
			if (!corners[2])
				for(var/obj/effect/pseudovehicle/PVV in locate(loc.x+3,loc.y+1))
					corners[1] = PVV
			if (!corners[3])
				for(var/obj/effect/pseudovehicle/PVV in locate(loc.x+3,loc.y-3))
					corners[1] = PVV
			if (!corners[4])
				for(var/obj/effect/pseudovehicle/PVV in locate(loc.x-1,loc.y-3))
					corners[1] = PVV
		return FALSE

/obj/structure/vehicleparts/axis/proc/do_matrix(var/olddir = 0, var/newdir = 0, var/tdir = "none", var/mob/user = null)
	if (olddir == 0 || newdir == 0 || tdir == "none")
		return FALSE
	if (isemptylist(corners))
		check_corners()
	if (isemptylist(matrix))
		check_matrix()
	matrix_current_locs = list()

	//first we need to generate the matrix of the current locations, based on our frame matrix, so we dont teleport stuff on top of other stuff.
	for (var/locx=1; locx<=maxdist; locx++)
		for (var/locy=1; locy<=maxdist; locy++)
			var/loc2textv = "[locx],[locy]"
			if (matrix[loc2textv][1])
				var/turf/currloc = get_turf(matrix[loc2textv][1])
				var/list/tmplist = list()
				for (var/atom/movable/MV in currloc)
					if ((istype(MV, /mob/living) || istype(MV, /obj/structure) || istype(MV, /obj/item) || istype(MV, /obj/effect/pseudovehicle)))
						tmplist += MV
				matrix_current_locs += list(matrix[loc2textv][4] = list(currloc,tmplist, matrix[loc2textv][4]))

	//check if there are no other vehicles/obstacles in the destination areas
	for (var/locx=1; locx<=maxdist; locx++)
		for (var/locy=1; locy<=maxdist; locy++)
			var/loc2textv = "[locx],[locy]"
			if (!matrix_current_locs[loc2textv] || !matrix_current_locs[loc2textv].len)
				continue
			var/dlocfinding
			switch(maxdist)
				if (1)
					dlocfinding = rotation_matrixes1[tdir][loc2textv][1]
				if (2)
					dlocfinding = rotation_matrixes2[tdir][loc2textv][1]
				if (3)
					dlocfinding = rotation_matrixes3[tdir][loc2textv][1]
				if (4)
					dlocfinding = rotation_matrixes4[tdir][loc2textv][1]
				if (5)
					dlocfinding = rotation_matrixes5[tdir][loc2textv][1]
			if (!dlocfinding)
				continue
			var/turf/T = matrix_current_locs[dlocfinding][1]
			var/list/todestroy = list()
			if (!matrix_current_locs[loc2textv][1] || !matrix_current_locs[dlocfinding][1])
				if (user)
					user << "<span class = 'warning'>You can't turn in that direction, the way is blocked!</span>"
				return FALSE
				if (!T || T.density)
					if (user)
						user << "<span class = 'warning'>You can't turn in that direction, the way is blocked!</span>"
					return FALSE
			for (var/obj/O in T)
				if ((!locate(O) in transporting) && (!locate(O) in components) && (!locate(O) in wheels))
					if (istype(O, /obj/structure/vehicleparts/frame))
						var/obj/structure/vehicleparts/frame/FRM = O
						if (FRM.axis != src)
							if (user)
								user << "<span class = 'warning'>You can't turn in that direction, the way is blocked!</span>"
							return FALSE
					else
						todestroy += O
			for(var/obj/OM in todestroy)
				if (!istype(OM, /obj/structure/sign/traffic/zebracrossing) && !istype(OM, /obj/structure/sign/traffic/side) && !istype(OM, /obj/structure/sign/traffic/central) && !istype(OM, /obj/structure/rails) && !istype(OM, /obj/covers) && !istype(OM, /obj/structure/gate) && !istype(OM, /obj/structure/lamp/lamppost_small/) && !istype(OM, /obj/structure/lamp/lamp_big/alwayson) && !istype(OM, /obj/structure/lamp/lamp_small/alwayson) && !istype(OM, /obj/structure/redmailbox) && !istype(OM, /obj/structure/billboard))
					qdel(OM)
	dir = newdir
	for (var/obj/structure/vehicleparts/movement/OBB in wheels)
		if (OBB.reversed)
			OBB.dir = OPPOSITE_DIR(dir)
		else
			OBB.dir = dir
	for (var/locx=1; locx<=maxdist; locx++)
		for (var/locy=1; locy<=maxdist; locy++)
			var/loc2textv = "[locx],[locy]"
			var/dlocfind
			switch(maxdist)
				if (1)
					dlocfind = rotation_matrixes1[tdir][loc2textv][1]
				if (2)
					dlocfind = rotation_matrixes2[tdir][loc2textv][1]
				if (3)
					dlocfind = rotation_matrixes3[tdir][loc2textv][1]
				if (4)
					dlocfind = rotation_matrixes4[tdir][loc2textv][1]
				if (5)
					dlocfind = rotation_matrixes5[tdir][loc2textv][1]
			if (!matrix_current_locs[loc2textv][1] || !matrix_current_locs[dlocfind][1])
				return FALSE
//			world.log << "LOG: currloc: [loc2textv] ([matrix_current_locs[loc2textv][1].x],[matrix_current_locs[loc2textv][1].y]), moving to: [rotation_matrixes5[tdir][loc2textv][1]] ([matrix_current_locs[dlocfind][1].x],[matrix_current_locs[dlocfind][1].y])"
			if (islist(matrix_current_locs[loc2textv][2]))
				for (var/obj/effect/pseudovehicle/PV in matrix_current_locs[dlocfind][1])
					var/turf/toget = matrix_current_locs[dlocfind][1]
					for (var/mob/living/ML in toget)
						if (!locate(ML) in transporting)
							for(var/obj/item/I in ML)
								qdel(I)
							ML.crush()
					for (var/obj/structure/ST in toget)
						if (!ST.density)
							ST.Destroy()
				for (var/atom/movable/M in matrix_current_locs[loc2textv][2])
					if (!istype(M, /obj/structure/sign/traffic/zebracrossing) && !istype(M, /obj/structure/sign/traffic/side) && !istype(M, /obj/structure/sign/traffic/central) && !istype(M, /obj/structure/rails) && !istype(M,/obj/covers) && !istype(M,/obj/structure/cable) && !istype(M,/obj/structure/gate) && !istype(M, /obj/structure/lamp/lamppost_small/) && !istype(M, /obj/structure/lamp/lamp_big/alwayson) && !istype(M, /obj/structure/lamp/lamp_small/alwayson) && !istype(M, /obj/structure/billboard))
						M.forceMove(matrix_current_locs[dlocfind][1])
						if (istype(M, /obj))
							var/obj/O = M
							if (!istype(O, /obj/structure/cannon))
								O.dir = dir
							if (istype(O, /obj/structure/vehicleparts/frame))
								var/obj/structure/vehicleparts/frame/FR = O
								if (FR.mwheel)
									FR.mwheel.update_icon()
							O.update_icon()

	for(var/obj/structure/vehicleparts/VP in components)
		VP.dir = dir
		VP.update_icon()
	return TRUE

/obj/effect/pseudovehicle
	name = ""
	desc = ""
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "black"
	invisibility = 101
	layer = 2
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/obj/structure/vehicleparts/axis/link = null

	New()
		..()
		spawn(1200)
			if (!link)
				qdel(src)


/obj/structure/vehicleparts/axis/attack_hand(var/mob/living/human/H)
	if (!ishuman(H))
		return
	for(var/obj/structure/vehicleparts/frame/F1 in get_turf(get_step(src, WEST)))
		H << "<span class='notice'>The axis needs to be placed at the <b>TOP LEFT</b> corner!</span>"
		return
	for(var/obj/structure/vehicleparts/frame/F2 in get_turf(get_step(src, NORTH)))
		H << "<span class='notice'>The axis needs to be placed at the <b>TOP LEFT</b> corner!</span>"
		return
	for(var/obj/structure/vehicleparts/frame/ship/SH in range(4,src))
		var/turf/TT = get_turf(SH)
		if (!istype(TT, /turf/floor/beach/water) && !istype(TT, /turf/floor/trench/flooded))
			H << "<span class='notice'>All ship parts must be in a water tile.</span>"
			return
	var/inp = WWinput(H, "Are you sure you wan't to assemble a vehicle here? This has to be the top left corner.", "Vehicle Assembly", "No", list("No", "Yes"))
	if (inp == "No")
		return
	for(var/obj/structure/vehicleparts/frame/F in loc)
		if (F.axis && F.axis != src)
			return
		var/customname = input(H, "What do you want to name this vehicle?") as text
		if (!customname || customname == "")
			name = "[H]'s vehicle"
		else
			name = customname
		var/list/vehiclecolors = list(
			list("light gray","#A9A9A9"),
			list("medium gray","#585A5C"),
			list("dark gray","#3B3F41"),
			list("green","#3d5931"),
			list("pale green","#636351"),
			list("Feldgrau (WW1)","#5D5D3D"),
			list("Feldgrau (WW2)","#4D5D53"),
			list("light khaki","#F0E68C"),
			list("dark khaki","#BDB76B"),
			list("olive drab","#555346"),)
		var/choosecolor1 = WWinput(H, "Choose this vehicle's color:", "Vehicle Color", "medium gray", list("light gray", "medium gray", "dark gray", "green", "pale green", "Feldgrau (WW1)", "Feldgrau (WW2)", "light khaki", "dark khaki", "olive drab"))
		for (var/i in vehiclecolors)
			if (i[1] == choosecolor1)
				color = i[2]
		dir = 1
		new/obj/effect/autoassembler(locate(x+2,y-2,z))
		H << "<span class='warning'>Vehicle assembled.</span>"
		for (var/obj/O in components)
			O.update_icon()
		return
