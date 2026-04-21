////////////////////////FRAMES//////////////////////
/obj/structure/vehicleparts/frame
	name = "steel frame"
	desc = "A steel vehicle frame."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "frame_steel"
	powerneeded = 0
	flammable = FALSE
	layer = 2.98
	density = TRUE

	var/resistance = 150
	var/obj/structure/vehicleparts/axis/axis = null
	//format: type of wall, opacity, density, armor, current health, can open/close, is open, is ambrasure
	var/list/w_front = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
	var/list/w_back = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
	var/list/w_left = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
	var/list/w_right = list("",FALSE,FALSE,0,0,FALSE,FALSE,FALSE)
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
	crushable = FALSE
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
			tmpsum += O.w_class*2
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
	if (mover)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
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
						playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
						w_right[7] = TRUE
						if (removesroof)
							for(var/obj/structure/vehicleparts/frame/VP in range(1,loc))
								if (VP.axis == axis && VP.removesroof && VP.w_right[6])
									VP.w_right[7] = TRUE
									VP.noroof = TRUE
									VP.update_icon()
							noroof = TRUE
					H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
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
				if (src.w_front[6] || src.w_back[6] || src.w_left[6] || src.w_right[6])
					doorcode = K.code		//Leave it as before if its not a boat
					H << "You assign this key to the lock."
				return
	else
		..()

/obj/structure/vehicleparts/frame/proc/is_ambrasure(var/w_name)
	if (w_name == "front" && w_front.len >= 8)
		return w_front[8]
	else if (w_name == "back" && w_back.len >= 8)
		return w_back[8]
	else if (w_name == "left" && w_left.len >= 8)
		return w_left[8]
	else if (w_name == "right" && w_right.len >= 8)
		return w_right[8]

	if (w_name == "frontleft")
		if(w_front.len >= 8 && w_front[8])
			return TRUE
		if(w_left.len >= 8 && w_left[8])
			return TRUE
	else if (w_name == "backleft")
		if(w_back.len >= 8 && w_back[8])
			return TRUE
		if(w_left.len >= 8 && w_left[8])
			return TRUE
	else if (w_name == "frontright")
		if(w_front.len >= 8 && w_front[8])
			return TRUE
		if(w_right.len >= 8 && w_right[8])
			return TRUE
	else if (w_name == "backright")
		if(w_back.len >= 8 && w_back[8])
			return TRUE
		if(w_right.len >= 8 && w_right[8])
			return TRUE
	return FALSE

/obj/structure/vehicleparts/frame/proc/get_wall_name(var/w_dir)
	var/w_dirs = list(NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST)
	var/w_names = list("back", "backleft", "left", "frontleft", "front", "frontright", "right", "backright")
	while (dir != w_dirs[1])
		var/i = 8
		var/buf = w_dirs[i];
		for (, i > 1, i--)
			w_dirs[i] = w_dirs[i - 1]
		w_dirs[1] = buf
	var/i
	for (i = 1, i <= 8, i++)
		if (w_dir == w_dirs[i])
			return w_names[i]

/obj/structure/vehicleparts/frame/proc/wall_hp(var/w_name)
	var/walls_hp_list = list (
		"front" = w_front[5],
		"back" = w_back[5],
		"left" = w_left[5],
		"right" = w_right[5],
		"frontleft" = w_front[5] + w_left[5],
		"backleft" = w_back[5] + w_left[5],
		"frontright" = w_front[5] + w_right[5],
		"backright" = w_back[5] + w_right[5]
	)
	return walls_hp_list[w_name]

/obj/structure/vehicleparts/frame/proc/wall_armor(var/w_name)
	var/walls_armor_list = list (
		"front" = w_front[4],
		"back" = w_back[4],
		"left" = w_left[4],
		"right" = w_right[4],
		"frontleft" = w_front[4] + w_left[4],
		"backleft" = w_back[4] + w_left[4],
		"frontright" = w_front[4] + w_right[4],
		"backright" = w_back[4] + w_right[4]
	)
	return walls_armor_list[w_name]

/obj/structure/vehicleparts/frame/proc/CheckPenLoc(var/obj/item/proj)
	var/turf/startingturf = null

	if (istype(proj, /obj/item/projectile))
		var/obj/item/projectile/pj = proj
		pj.throw_source = pj.starting
		startingturf = pj.starting

	else if (istype(proj, /obj/item/weapon/grenade/suicide_vest))
		startingturf = get_turf(proj.loc)

	else if (istype(proj, /obj/item/weapon/grenade))
		startingturf = get_turf(proj)
	
	else if (istype(proj, /obj/structure/drone))
		startingturf = get_turf(proj)

	if (!startingturf)
		return "none"

	var/incdir = get_dir(startingturf, get_turf(src))

	return get_wall_name(incdir)

/obj/structure/vehicleparts/frame/proc/CheckPen(var/obj/item/projectile/proj, var/penloc = "front")
	if (!penloc)
		return FALSE
	proj.throw_source = proj.starting
	var/firing_dist = get_dist(src.loc,proj.starting)
	var/heavy_ap = proj.heavy_armor_penetration
	if (wall_armor(penloc) > 0)
		if (istype(proj, /obj/item/projectile/shell))
			var/obj/item/projectile/shell/S = proj
			S.initiated = TRUE
	if (max(0,heavy_ap - firing_dist) >= wall_armor(penloc))
		return TRUE

	if (istype(proj, /obj/item/projectile/shell))
		playsound(loc, pick('sound/machines/tank/tank_ricochet1.ogg','sound/machines/tank/tank_ricochet2.ogg','sound/machines/tank/tank_ricochet3.ogg'),100, TRUE)
	else
		playsound(loc, "ric_sound", 50, TRUE)
	return FALSE

/obj/structure/vehicleparts/frame/bullet_act(var/obj/item/projectile/proj, var/penloc = "front")
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
							for (var/mob/M in loc)
								shake_camera(M, 3, 3)
							if (!mwheel.broken && prob(80))
								mwheel.broken = TRUE
								visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
								new/obj/effect/effect/smoke/small(loc)
								update_icon()
						if ("APCR")
							if (!mwheel.broken && prob(60))
								mwheel.broken = TRUE
								visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
								new/obj/effect/effect/smoke/small(loc)
								update_icon()
						if ("AP")
							if (!mwheel.broken && prob(70))
								mwheel.broken = TRUE
								visible_message("<span class='danger'>\The [mwheel.name] breaks down!</span>")
								new/obj/effect/effect/smoke/small(loc)
								update_icon()
			else
				var/damage_modifier = proj.heavy_armor_penetration
				if(wall_armor(penloc) > heavy_armor_penetration)
					damage_modifier /= 2
				switch(penloc)
					if ("left")
						w_left[5] -= damage_modifier
						visible_message("<span class = 'danger'><big>The left hull is damaged!</big></span>")
					if ("right")
						w_right[5] -= damage_modifier
						visible_message("<span class = 'danger'><big>The right hull is damaged!</big></span>")
					if ("front")
						w_front[5] -= damage_modifier
						visible_message("<span class = 'danger'><big>The front hull is damaged!</big></span>")
					if ("back")
						w_back[5] -= damage_modifier
						visible_message("<span class = 'danger'><big>The rear hull is damaged!</big></span>")
					if ("frontleft")
						if (w_left[4] > w_front[4] && w_left[5]>0 && w_front[5]>0)
							w_left[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The left hull is damaged!</big></span>")
						else
							w_front[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The front hull is damaged!</big></span>")
					if ("frontright")
						if (w_right[4] > w_front[4] && w_right[5]>0 && w_front[5]>0)
							w_right[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The right hull is damaged!</big></span>")
						else
							w_front[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The front hull is damaged!</big></span>")
					if ("backleft")
						if (w_left[4] > w_back[4] && w_left[5]>0 && w_back[5]>0)
							w_left[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The left hull is damaged!</big></span>")
						else
							w_back[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The rear hull is damaged!</big></span>")
					if ("backright")
						if (w_right[4] > w_back[4] && w_right[5]>0 && w_back[5]>0)
							w_right[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The right hull is damaged!</big></span>")
						else
							w_back[5] -= damage_modifier
							visible_message("<span class = 'danger'><big>The rear hull is damaged!</big></span>")
		else
			var/damage_modifier = proj.heavy_armor_penetration
			if(wall_armor(penloc) > heavy_armor_penetration)
				damage_modifier /= 2
			switch(penloc)
				if ("left")
					w_left[5] -= damage_modifier
				if ("right")
					w_right[5] -= damage_modifier
				if ("front")
					w_front[5] -= damage_modifier
				if ("back")
					w_back[5] -= damage_modifier
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
		if (w_left[6] || findtext(w_left[1], "door"))
			isnowopen = TRUE
		else
			isnowopen = FALSE
		w_left = list(w_left[1],FALSE,FALSE,0,0,FALSE,isnowopen)
	if (w_right[5] < 0)
		if (w_right[6] || findtext(w_right[1], "door"))
			isnowopen = TRUE
		else
			isnowopen = FALSE
		w_right = list(w_right[1],FALSE,FALSE,0,0,FALSE,isnowopen)
	if (w_front[5] < 0)
		if (w_front[6] || findtext(w_front[1], "door"))
			isnowopen = TRUE
		else
			isnowopen = FALSE
		w_front = list(w_front[1],FALSE,FALSE,0,0,FALSE,isnowopen)
	if (w_back[5] < 0)
		if (w_back[6] || findtext(w_back[1], "door"))
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
	else if (!(axis in contents))
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