////////////////////////FRAMES//////////////////////
/obj/structure/vehicleparts/frame
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "frame_steel"
	powerneeded = 0
	flammable = FALSE
	layer = 2.98
	density = TRUE

	var/resistance = 150
	var/obj/structure/vehicleparts/axis/axis = null
	//format: type of wall, opacity, density, armor, current health, can open/close, is open?
	var/list/w_front = list("",FALSE,FALSE,0,0,FALSE,FALSE)
	var/list/w_back = list("",FALSE,FALSE,0,0,FALSE,FALSE)
	var/list/w_left = list("",FALSE,FALSE,0,0,FALSE,FALSE)
	var/list/w_right = list("",FALSE,FALSE,0,0,FALSE,FALSE)
	var/obj/structure/vehicleparts/movement/mwheel = null

	var/doorcode = 0 //if it has a door on it, what the key code is
	var/image/roof
	var/image/roof_turret
	var/image/movemento
	var/noroof = FALSE
	var/removesroof = FALSE
	var/override_roof_icon = null
	var/override_frame_icon = null
	not_movable = TRUE
	not_disassemblable = TRUE
	var/broken = FALSE
	var/override_color = null
	var/hasoverlay = null
	var/obj/structure/emergency_lights/lights = null

	New()
		..()
		roof = image(icon=icon, loc=src, icon_state="roof_steel[rand(1,4)]", layer=8)
		roof_turret = image(icon=icon, loc=src, icon_state="", layer=1)
		roof.override = TRUE
		spawn(1)
			update_icon()
	relaymove(var/mob/mob, direction)
		..()
		update_icon()
	Move(newloc, direct)
		..()
		update_icon()

/obj/structure/vehicleparts/frame/proc/total_weight()
	var/tmpsum = 10
	for (var/obj/O in loc)
		if (!(istype(O, /obj/structure/rails)))
			tmpsum+=O.w_class*2
	for(var/mob/living/L in loc)
		tmpsum += L.mob_size*2
	return tmpsum

/obj/structure/vehicleparts/frame/examine(mob/user)
	..()
	if (axis)
		if (user in range(1,src))
			user << "<span class='notice'>Current Weight: <b>[axis.get_weight()]</b>.</span>"

/obj/structure/vehicleparts/frame/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis && !axis)
		if (abs(VP.y-y) > 5 || abs(VP.x-x) > 5)
			usr << "<span class='notice'>Vehicles can't be more than 5 tiles long or wide!</span>"
			return
			if (VP.axis.components.len > 25)
				usr << "<span class='notice'>The vehicle is too big already!</span>"
				return
		for(var/obj/structure/vehicleparts/frame/FR in range(1,src))
			if (FR != src && FR.axis == VP.axis)
				playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
				usr << "You connect \the [src] to \the [VP.axis]."
				axis = VP.axis
				name = VP.axis.name
				var/found = FALSE
				for (var/obj/structure/vehicleparts/frame/F in axis.components)
					if (F == src)
						found = TRUE
				if (!found)
					axis.components += src
				anchored = TRUE
				VP.dir = dir
				return
/obj/structure/vehicleparts/frame/MouseDrop_T(var/obj/structure/VP, var/mob/living/user)
	if (istype(VP, /obj/structure/engine/internal) && axis && !axis.engine && !VP.anchored)
		var/obj/structure/engine/internal/E = VP
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You connect \the [VP] to \the [axis]."
		axis.engine = VP
		VP.forceMove(loc)
		VP.anchored = TRUE
		E.icon = 'icons/obj/vehicles/vehicleparts.dmi'
		E.engineclass = "engine"
		E.update_icon()
		return
	else if (istype(VP, /obj/structure/bed/chair/drivers) && axis && !VP.anchored && !axis.wheel)
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You place \the [VP] in \the [axis]."
		VP.forceMove(loc)
		VP.anchored = TRUE
		var/obj/structure/bed/chair/drivers/VPP = VP
		axis.wheel = VPP.wheel
		axis.wheel.control = src
		return
	else if (istype(VP, /obj/structure/lamp/lamp_small/tank) && !VP.anchored)
		var/obj/structure/lamp/lamp_small/tank/TL = VP
		TL.connection = src
		usr << "You place \the [VP] in \the [axis]."

/obj/structure/vehicleparts/frame/CheckExit(atom/movable/O as mob|obj, target as turf)
	var/chdir = get_dir(O.loc, target)
	switch(chdir)
		if (NORTH,NORTHEAST,NORTHWEST)
			switch(dir)
				if (NORTH)
					if (w_front[1] == "" || w_front[7] == TRUE)
						return TRUE
				if (SOUTH)
					if (w_back[1] == "" || w_back[7] == TRUE)
						return TRUE
				if (WEST)
					if (w_right[1] == "" || w_right[7] == TRUE)
						return TRUE
				if (EAST)
					if (w_left[1] == "" || w_left[7] == TRUE)
						return TRUE
		if (SOUTH,SOUTHEAST,SOUTHWEST)
			switch(dir)
				if (NORTH)
					if (w_back[1] == "" || w_back[7] == TRUE)
						return TRUE
				if (SOUTH)
					if (w_front[1] == "" || w_front[7] == TRUE)
						return TRUE
				if (WEST)
					if (w_left[1] == "" || w_left[7] == TRUE)
						return TRUE
				if (EAST)
					if (w_right[1] == "" || w_right[7] == TRUE)
						return TRUE
		if (WEST,NORTHWEST,SOUTHWEST)
			switch(dir)
				if (NORTH)
					if (w_left[1] == "" || w_left[7] == TRUE)
						return TRUE
				if (SOUTH)
					if (w_right[1] == "" || w_right[7] == TRUE)
						return TRUE
				if (WEST)
					if (w_front[1] == "" || w_front[7] == TRUE)
						return TRUE
				if (EAST)
					if (w_back[1] == "" || w_back[7] == TRUE)
						return TRUE
		if (EAST,NORTHEAST,SOUTHEAST)
			switch(dir)
				if (NORTH)
					if (w_right[1] == "" || w_right[7] == TRUE)
						return TRUE
				if (SOUTH)
					if (w_left[1] == "" || w_left[7] == TRUE)
						return TRUE
				if (WEST)
					if (w_back[1] == "" || w_back[7] == TRUE)
						return TRUE
				if (EAST)
					if (w_front[1] == "" || w_front[7] == TRUE)
						return TRUE
	return FALSE

/obj/structure/vehicleparts/frame/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/effect/effect/smoke))
		return FALSE
	else if (mover)
		switch(mover.dir)
			if (NORTH)
				switch(dir)
					if (NORTH)
						if (w_back[1] == "" || w_back[7] == TRUE)
							return TRUE
					if (SOUTH)
						if (w_front[1] == "" || w_front[7] == TRUE)
							return TRUE
					if (WEST)
						if (w_left[1] == "" || w_left[7] == TRUE)
							return TRUE
					if (EAST)
						if (w_right[1] == "" || w_right[7] == TRUE)
							return TRUE
			if (SOUTH)
				switch(dir)
					if (NORTH)
						if (w_front[1] == "" || w_front[7] == TRUE)
							return TRUE
					if (SOUTH)
						if (w_back[1] == "" || w_back[7] == TRUE)
							return TRUE
					if (WEST)
						if (w_right[1] == "" || w_right[7] == TRUE)
							return TRUE
					if (EAST)
						if (w_left[1] == "" || w_left[7] == TRUE)
							return TRUE
			if (WEST)
				switch(dir)
					if (NORTH)
						if (w_right[1] == "" || w_right[7] == TRUE)
							return TRUE
					if (SOUTH)
						if (w_left[1] == "" || w_left[7] == TRUE)
							return TRUE
					if (WEST)
						if (w_back[1] == "" || w_back[7] == TRUE)
							return TRUE
					if (EAST)
						if (w_front[1] == "" || w_front[7] == TRUE)
							return TRUE
			if (EAST)
				switch(dir)
					if (NORTH)
						if (w_left[1] == "" || w_left[7] == TRUE)
							return TRUE
					if (SOUTH)
						if (w_right[1] == "" || w_right[7] == TRUE)
							return TRUE
					if (WEST)
						if (w_front[1] == "" || w_front[7] == TRUE)
							return TRUE
					if (EAST)
						if (w_back[1] == "" || w_back[7] == TRUE)
							return TRUE
	return FALSE
/obj/structure/vehicleparts/frame/attackby(var/obj/item/I, var/mob/living/human/H)

	if (mwheel && mwheel.broken && istype(I, /obj/item/weapon/weldingtool))
		var/cantdo = FALSE
		for (var/obj/structure/vehicleparts/frame/FM in H.loc)
			cantdo = TRUE
		if (!cantdo)
			visible_message("[H] starts repairing \the [mwheel.ntype]...")
			if (do_after(H, 200, src))
				visible_message("[H] sucessfully repairs \the [mwheel.ntype].")
				mwheel.broken = FALSE
				mwheel.update_icon()
				update_icon()
				return
	else if (istype(I,/obj/item/weapon/wrench) && !axis)
		anchored = !anchored
		if (anchored)
			H << "You fix the frame in place."
			return
		else
			H << "You release the frame."
			return
	else if (istype(I,/obj/item/weapon/key))
		var/obj/item/weapon/key/K = I
		if (doorcode)
			if (K.code == doorcode)
				if (w_front[6])
					if (w_front[7])
						visible_message("[H] locks the door.")
						w_front[7] = FALSE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_front[6])
									VP.w_front[7] = FALSE
									VP.noroof = FALSE
									VP.update_icon()
							noroof = FALSE
					else
						visible_message("[H] unlocks the door.")
						w_front[7] = TRUE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_front[6])
									VP.w_front[7] = TRUE
									VP.noroof = TRUE
									VP.update_icon()
							noroof = TRUE
					H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				if (w_back[6])
					if (w_back[7])
						visible_message("[H] locks the door.")
						w_back[7] = FALSE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_back[6])
									VP.w_back[7] = FALSE
									VP.noroof = FALSE
									VP.update_icon()
							noroof = FALSE
					else
						visible_message("[H] unlocks the door.")
						w_back[7] = TRUE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_back[6])
									VP.w_back[7] = TRUE
									VP.noroof = TRUE
									VP.update_icon()
							noroof = TRUE
					H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				if (w_left[6])
					if (w_left[7])
						visible_message("[H] locks the door.")
						w_left[7] = FALSE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_left[6])
									VP.w_left[7] = FALSE
									VP.noroof = FALSE
									VP.update_icon()
							noroof = FALSE
					else
						visible_message("[H] unlocks the door.")
						w_left[7] = TRUE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_left[6])
									VP.w_left[7] = TRUE
									VP.noroof = TRUE
									VP.update_icon()
							noroof = TRUE
					H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				if (w_right[6])
					if (w_right[7])
						visible_message("[H] locks the door.")
						w_right[7] = FALSE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_right[6])
									VP.w_right[7] = FALSE
									VP.noroof = FALSE
									VP.update_icon()
							noroof = FALSE
					else
						visible_message("[H] unlocks the door.")
						w_right[7] = TRUE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_right[6])
									VP.w_right[7] = TRUE
									VP.noroof = TRUE
									VP.update_icon()
							noroof = TRUE
					H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
				update_icon()
			else
				H << "This key does not match this lock!"
				return
		else
			if(istype(src, /obj/structure/vehicleparts/frame/ship )) //adds routines to lock the boat
				if(src.w_right[1] == "boat_port2")
					src.w_right[6] = TRUE
				else if(src.w_left[1] == "boat_port2")
					src.w_left[6] = TRUE
				else if(src.w_back[1] == "boat_port2")
					src.w_back[6] = TRUE
				else if(src.w_front[1] == "boat_port2")
					src.w_front[6] = TRUE
				else
					H << "This is not a door."
					return
				doorcode = K.code
				H << "You assign this key to the lock."
				return
			else
				doorcode = K.code		//Leave it as before if its not a boat
				H << "You assign this key to the lock."
				return
	else
		..()
/obj/structure/vehicleparts/frame/proc/CheckPenLoc(var/obj/item/proj)
	var/turf/startingturf = null

	if (istype(proj, /obj/item/projectile))
		var/obj/item/projectile/pj = proj
		pj.throw_source = pj.starting
		startingturf = pj.starting
	else if (istype(proj, /obj/item/missile))
		var/obj/item/missile/miss = proj
		startingturf = miss.startingturf
	else if (istype(proj, /obj/item/weapon/grenade/suicide_vest))
		startingturf = get_turf(proj.loc)
	else if (istype(proj, /obj/item/weapon/grenade))
		startingturf = get_turf(proj)
	if (!startingturf)
		return "front"
	var/incdir = get_dir(startingturf, get_turf(src))
	switch(dir)
		if (NORTH)
			switch(incdir)
				if (NORTH)
					return "back"
				if (SOUTH)
					return "front"
				if (WEST)
					return "right"
				if (EAST)
					return "left"
				if (NORTHWEST)
					return "backright"
				if (SOUTHWEST)
					return "frontright"
				if (NORTHEAST)
					return "backleft"
				if (SOUTHEAST)
					return "frontleft"
		if (SOUTH)
			switch(incdir)
				if (NORTH)
					return "front"
				if (SOUTH)
					return "back"
				if (WEST)
					return "left"
				if (EAST)
					return "right"
				if (NORTHWEST)
					return "frontleft"
				if (SOUTHWEST)
					return "backleft"
				if (NORTHEAST)
					return "frontright"
				if (SOUTHEAST)
					return "backright"
		if (EAST)
			switch(incdir)
				if (NORTH)
					return "right"
				if (SOUTH)
					return "left"
				if (WEST)
					return "front"
				if (EAST)
					return "back"
				if (NORTHWEST)
					return "frontright"
				if (SOUTHWEST)
					return "frontleft"
				if (NORTHEAST)
					return "backright"
				if (SOUTHEAST)
					return "backleft"
		if (WEST)
			switch(incdir)
				if (NORTH)
					return "left"
				if (SOUTH)
					return "right"
				if (WEST)
					return "back"
				if (EAST)
					return "front"
				if (NORTHWEST)
					return "backleft"
				if (SOUTHWEST)
					return "backright"
				if (NORTHEAST)
					return "frontleft"
				if (SOUTHEAST)
					return "frontright"

	return "front"

/obj/structure/vehicleparts/frame/proc/CheckPen(var/obj/item/projectile/proj, var/penloc = "front")
	if (!penloc)
		return FALSE
	proj.throw_source = proj.starting
	switch(penloc)
		if ("front")
			if (w_front[5] <= 0 && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_front[4])
				return TRUE
		if ("back")
			if (w_back[5] <= 0 && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_back[4])
				return TRUE
		if ("left")
			if (w_left[5] <= 0 && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_left[4])
				return TRUE
		if ("right")
			if (w_right[5] <= 0 && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_right[4])
				return TRUE
		if ("frontleft")
			if ((w_front[5] <= 0 && w_left[5] <= 0) && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_front[4] && max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_left[4])
				return TRUE
		if ("backleft")
			if ((w_back[5] <= 0 && w_left[5] <= 0) && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_back[4] && max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_left[4])
				return TRUE
		if ("frontright")
			if ((w_front[5] <= 0 && w_right[5] <= 0) && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_front[4] && max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_right[4])
				return TRUE
		if ("backright")
			if ((w_back[5] <= 0 && w_right[5] <= 0) && prob(75))
				return TRUE
			if (max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_back[4] && max(0,proj.heavy_armor_penetration-get_dist(src.loc,proj.starting)) >= w_right[4])
				return TRUE
	if (istype(proj, /obj/item/projectile/shell))
		playsound(loc, pick('sound/machines/tank/tank_ricochet1.ogg','sound/machines/tank/tank_ricochet2.ogg','sound/machines/tank/tank_ricochet3.ogg'),100, TRUE)
		//playsound(loc, "ric_voice", 100, TRUE)
	else
		playsound(loc, "ric_sound", 50, TRUE)
	return FALSE

/obj/structure/vehicleparts/frame/bullet_act(var/obj/item/projectile/proj, var/penloc = "front")
	var/turf/tloc = null
	if (proj.firer)
		tloc = proj.firer.loc
	else if (proj.firer_loc)
		tloc = proj.firer_loc
	else
		tloc = get_turf(src)
	for (var/obj/structure/vehicleparts/frame/F in tloc)
		if (F.axis == axis)
			return
	if (mwheel && prob(30))
		if (mwheel.ntype == "wheel")
			mwheel.broken = TRUE
			visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
			new/obj/effect/effect/smoke/small(loc)
			update_icon()
	if (penloc)
		if (istype(proj, /obj/item/projectile/shell))
			var/obj/item/projectile/shell/PS = proj
			if (mwheel && prob(60))
				if (mwheel.ntype == "wheel")
					mwheel.broken = TRUE
					visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
					new/obj/effect/effect/smoke/small(loc)
					update_icon()
				else if (mwheel.ntype == "track")
					switch (PS.atype)
						if ("HE")
							for (var/mob/M in axis.transporting)
								shake_camera(M, 3, 3)
							if (!mwheel.broken && prob(80))
								mwheel.broken = TRUE
								visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
								//playsound(loc, "track_voice", 100, TRUE)
								new/obj/effect/effect/smoke/small(loc)
								update_icon()
						if ("APCR")
							if (!mwheel.broken && prob(60))
								mwheel.broken = TRUE
								visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
								//playsound(loc, "track_voice", 100, TRUE)
								new/obj/effect/effect/smoke/small(loc)
								update_icon()
						if ("AP")
							if (!mwheel.broken && prob(70))
								mwheel.broken = TRUE
								visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
								//playsound(loc, "track_voice", 100, TRUE)
								new/obj/effect/effect/smoke/small(loc)
								update_icon()
			else
				var/adjdam = 0
				switch (PS.atype)
					if ("HE")
						for (var/mob/living/M in axis.transporting)
							shake_camera(M, 3, 3)
							if (M.loc == loc)
								var/tprob = 80
								if (M.lying || M.prone)
									tprob = 35
								if (prob(tprob))
									M.adjustBruteLoss(PS.damage)
									visible_message("<span class='danger'>[M] is hit by the [PS]!</span>")
									//playsound(loc, "pen_voice", 100, TRUE)
						adjdam = proj.damage * 0.08
					else if ("APCR")
						for (var/mob/living/M in axis.transporting)
							shake_camera(M, 1, 1)
							if (M.loc == loc)
								var/tprob = 80
								if (M.lying || M.prone)
									tprob = 35
								if (prob(tprob))
									M.adjustBruteLoss(PS.damage)
									visible_message("<span class='danger'>[M] is hit by the [PS]!</span>")
									//playsound(loc, "pen_voice", 100, TRUE)
						adjdam = proj.damage * 0.5
					else if ("AP")
						for (var/mob/living/M in axis.transporting)
							shake_camera(M, 1, 1)
							if (M.loc == loc)
								var/tprob = 80
								if (M.lying || M.prone)
									tprob = 35
								if (prob(tprob))
									M.adjustBruteLoss(PS.damage)
									visible_message("<span class='danger'>[M] is hit by the [PS]!</span>")
									//playsound(loc, "pen_voice", 100, TRUE)
						adjdam = proj.damage * 0.3
					else
						for (var/mob/living/M in axis.transporting)
							if (M.loc == loc)
								var/tprob = 50
								if (M.lying || M.prone)
									tprob = 25
								if (prob(tprob))
									M.adjustBruteLoss(PS.damage)
									visible_message("<span class='danger'>[M] is hit by the [PS]!</span>")
						adjdam = proj.damage * 0.05
				switch(penloc)
					if ("left")
						w_left[5] -= adjdam
						visible_message("<span class = 'danger'><big>The left hull is damaged!</big></span>")
						//playsound(loc, "pen_voice", 100, TRUE)
					if ("right")
						w_right[5] -= adjdam
						visible_message("<span class = 'danger'><big>The right hull is damaged!</big></span>")
						//playsound(loc, "pen_voice", 100, TRUE)
					if ("front")
						w_front[5] -= adjdam
						visible_message("<span class = 'danger'><big>The front hull is damaged!</big></span>")
						//playsound(loc, "pen_voice", 100, TRUE)
					if ("back")
						w_back[5] -= adjdam
						visible_message("<span class = 'danger'><big>The rear hull is damaged!</big></span>")
						//playsound(loc, "pen_voice", 100, TRUE)
					if ("frontleft")
						if (w_left[4] > w_front[4] && w_left[5]>0 && w_front[5]>0)
							w_left[5] -= adjdam
							visible_message("<span class = 'danger'><big>The left hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
						else
							w_front[5] -= adjdam
							visible_message("<span class = 'danger'><big>The front hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
					if ("frontright")
						if (w_right[4] > w_front[4] && w_right[5]>0 && w_front[5]>0)
							w_right[5] -= adjdam
							visible_message("<span class = 'danger'><big>The right hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
						else
							w_front[5] -= adjdam
							visible_message("<span class = 'danger'><big>The front hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
					if ("backleft")
						if (w_left[4] > w_back[4] && w_left[5]>0 && w_back[5]>0)
							w_left[5] -= adjdam
							visible_message("<span class = 'danger'><big>The left hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
						else
							w_back[5] -= adjdam
							visible_message("<span class = 'danger'><big>The rear hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
					if ("backright")
						if (w_right[4] > w_back[4] && w_right[5]>0 && w_back[5]>0)
							w_right[5] -= adjdam
							visible_message("<span class = 'danger'><big>The right hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
						else
							w_back[5] -= adjdam
							visible_message("<span class = 'danger'><big>The rear hull is damaged!</big></span>")
							//playsound(loc, "pen_voice", 100, TRUE)
		else
			switch(penloc)
				if ("left")
					w_left[5] -= proj.damage * 0.01
				if ("right")
					w_right[5] -= proj.damage * 0.01
				if ("front")
					w_front[5] -= proj.damage * 0.01
				if ("back")
					w_back[5] -= proj.damage * 0.01
		visible_message("<span class = 'warning'>\The [proj] hits \the [src]!</span>")
		if (istype(proj, /obj/item/projectile/shell))
			playsound(loc, pick('sound/effects/explosion1.ogg','sound/effects/explosion1.ogg'),100, TRUE)
			new/obj/effect/effect/smoke/small/fast(loc)
		try_destroy()
		return
	else
		..()

/obj/structure/vehicleparts/frame/proc/try_destroy()
	//format: type of wall, opacity, density, armor, current health, can open/close, is open?
	var/isnowopen = FALSE

	if (w_left[5] < 0)
		if (w_left[6] || w_left[1] == "c_door" || w_left[1] == "c_windoweddoor")
			isnowopen = TRUE
		else
			isnowopen = FALSE
		w_left = list(w_left[1],FALSE,FALSE,0,0,FALSE,isnowopen)
	if (w_right[5] < 0)
		if (w_right[6] || w_right[1] == "c_door" || w_right[1] == "c_windoweddoor")
			isnowopen = TRUE
		else
			isnowopen = FALSE
		w_right = list(w_right[1],FALSE,FALSE,0,0,FALSE,isnowopen)
	if (w_front[5] < 0)
		if (w_front[6] || w_front[1] == "c_door" || w_front[1] == "c_windoweddoor")
			isnowopen = TRUE
		else
			isnowopen = FALSE
		w_front = list(w_front[1],FALSE,FALSE,0,0,FALSE,isnowopen)
	if (w_back[5] < 0)
		if (w_back[6] || w_back[1] == "c_door" || w_back[1] == "c_windoweddoor")
			isnowopen = TRUE
		else
			isnowopen = FALSE
		w_back = list(w_back[1],FALSE,FALSE,0,0,FALSE,isnowopen)
	if (w_left[5]+w_right[5]+w_back[5]+w_front[5] <= 0)
		broken = TRUE
		if (prob(10))
			Destroy()
	update_icon()
/obj/structure/vehicleparts/frame/Destroy()
	if (!broken)
		visible_message("<span class='danger'>The frame gets wrecked!</span>")
		update_icon()
		broken = TRUE
	else if (!axis in contents)
		axis = null
		mwheel = null
		..()
/obj/structure/vehicleparts/frame/ex_act(severity)
	switch(severity)
		if (1.0)
			w_left[5]-=rand(17,22)
			w_right[5]-=rand(17,22)
			w_front[5]-=rand(17,22)
			w_back[5]-=rand(17,22)
			try_destroy()
			return
		if (2.0)
			w_left[5]-=rand(7,12)
			w_right[5]-=rand(7,12)
			w_front[5]-=rand(7,12)
			w_back[5]-=rand(7,12)
			try_destroy()
			return
		if (3.0)
			return