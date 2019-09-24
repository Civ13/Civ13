////////////////////////FRAMES//////////////////////
/obj/structure/vehicleparts/frame
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "frame_steel"
	powerneeded = 0
	flammable = FALSE
	layer = 2.98
	density = TRUE
	var/resistance = 150
	var/obj/structure/vehicleparts/axis/axis = null
	//format: type of wall, opacity, density, armor, current health, can open/close, is open?
	var/list/w_front = list("",FALSE,FALSE,0,40,FALSE,FALSE)
	var/list/w_back = list("",FALSE,FALSE,0,40,FALSE,FALSE)
	var/list/w_left = list("",FALSE,FALSE,0,40,FALSE,FALSE)
	var/list/w_right = list("",FALSE,FALSE,0,40,FALSE,FALSE)
	var/obj/structure/vehicleparts/movement/mwheel = null

	var/doorcode = 0 //if it has a door on it, what the key code is
	var/image/roof
	var/image/roof_turret
	var/image/movemento
	var/noroof = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/broken = FALSE
	var/color_code = ""
	New()
		..()
		roof = image(icon=icon, loc=src, icon_state="roof_steel[rand(1,4)][color_code]", layer=8)
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
		tmpsum+=O.w_class*2
	for(var/mob/living/L in loc)
		tmpsum += L.mob_size*2
	return tmpsum

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
				color_code = VP.color_code
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
		E.icon = 'icons/obj/vehicleparts.dmi'
		E.engineclass = "engine"
		E.update_icon()
		return
	else if (istype(VP, /obj/structure/bed/chair/drivers) && axis && !VP.anchored && !axis.wheel)
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You place \the [VP] in \the [axis]."
		VP.forceMove(loc)
		VP.anchored = TRUE
		VP.dir = dir
		var/obj/structure/bed/chair/drivers/VPP = VP
		axis.wheel = VPP.wheel
		axis.wheel.control = src
		return
	else if (istype(VP, /obj/structure/lamp/lamp_small/tank) && !VP.anchored)
		var/obj/structure/lamp/lamp_small/tank/TL = VP
		TL.connection = src
		usr << "You place \the [VP] in \the [axis]."

/obj/structure/vehicleparts/frame/wood
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 90

/obj/structure/vehicleparts/frame/lwall
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rwall
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/fwall
	w_front = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bwall
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ldoor
	w_left = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/rdoor
	w_right = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/fdoor
	w_front = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/bdoor
	w_back = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/lwall/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rwall/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/fwall/armored
	w_front = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bwall/armored
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rb
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lb
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rf
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_front = list("c_armoredfront",FALSE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lf
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_front = list("c_armoredfront",FALSE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rb/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lb/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rf/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lf/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,55,90,FALSE,FALSE)

/obj/structure/vehicleparts/frame/lf/truck
	w_left = list("c_windoweddoor",TRUE,TRUE,5,10,TRUE,TRUE)
	w_front = list("c_windshield",FALSE,TRUE,6,15,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rf/truck
	w_right = list("c_windoweddoor",TRUE,TRUE,5,10,TRUE,TRUE)
	w_front = list("c_windshield",FALSE,TRUE,6,15,FALSE,FALSE)

/obj/structure/vehicleparts/frame/ifv

/obj/structure/vehicleparts/frame/ifv/front
	w_right = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
	w_front = list("c_armoredfront",FALSE,TRUE,12,30,FALSE,FALSE)

/obj/structure/vehicleparts/frame/ifv/back
	w_right = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ifv/rb
	w_right = list("c_windoweddoor",TRUE,TRUE,5,10,TRUE,TRUE)
	w_back = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ifv/lb
	w_left = list("c_windoweddoor",TRUE,TRUE,5,10,TRUE,TRUE)
	w_back = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ifv/rf
	w_right = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
	w_front = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ifv/lf
	w_left = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
	w_front = list("c_wall",TRUE,TRUE,12,30,FALSE,FALSE)
/*
/obj/structure/vehicleparts/frame/verb/add_walls()
	set category = null
	set name = "Add walls"
	set src in range(1, usr)

	var/ndir = WWinput(usr, "Which dir to set first?", "Wall Placer", "Cancel", list("North","South","East","West", "Cancel"))
	if (ndir == "Cancel")
		return
	else
		dir = text2dir(ndir)
		var/position = WWinput(usr, "Which position?", "Wall Placer", "Cancel", list("left","right","front","back", "Cancel"))
		if (position == "Cancel")
			return
		else
			position = "w_[position]"
			var/ntype = WWinput(usr, "Which type?", "Wall Placer", "Cancel", list("wall","windshield","window", "armored front", "armoredwall", "door", "windowed door", "Cancel"))
			if (ntype == "Cancel")
				return
			else
				ntype = "c_[type]"
				ntype = replacetext(ntype, " ", "")
				switch(position)
					if ("w_left")
						w_left = vehicle_walls[ntype]
					if ("w_right")
						w_right = vehicle_walls[ntype]
					if ("w_front")
						w_front = vehicle_walls[ntype]
					if ("w_back")
						w_back = vehicle_walls[ntype]
	update_icon()

*/
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
	else
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
/obj/structure/vehicleparts/frame/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (mwheel && mwheel.broken && istype(I, /obj/item/weapon/weldingtool))
		var/cantdo = FALSE
		for (var/obj/structure/vehicleparts/frame/FM in H.loc)
			cantdo = TRUE
		if (!cantdo)
			visible_message("[H] starts repairing \the [mwheel.ntype]...")
			if (do_after(H, 200, src))
				visible_message("[H] sucessfully repairs \the [mwheel.ntype].")
				mwheel.broken = FALSE
				return
	else if (istype(I,/obj/item/weapon/key))
		var/obj/item/weapon/key/K = I
		if (K.code == doorcode)
			if (w_front[6])
				if (w_front[7])
					visible_message("[H] locks the door.")
					w_front[7] = FALSE
				else
					visible_message("[H] unlocks the door.")
					w_front[7] = TRUE
				H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			if (w_back[6])
				if (w_back[7])
					visible_message("[H] locks the door.")
					w_back[7] = FALSE
				else
					visible_message("[H] unlocks the door.")
					w_back[7] = TRUE
				H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			if (w_left[6])
				if (w_left[7])
					visible_message("[H] locks the door.")
					w_left[7] = FALSE
				else
					visible_message("[H] unlocks the door.")
					w_left[7] = TRUE
				H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			if (w_right[6])
				if (w_right[7])
					visible_message("[H] locks the door.")
					w_right[7] = FALSE
				else
					visible_message("[H] unlocks the door.")
					w_right[7] = TRUE
				H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			playsound(src.loc, 'sound/effects/door_lock_unlock.ogg', 100)
		else
			H << "This key does not match this lock!"
			return
	else
		..()
/obj/structure/vehicleparts/frame/proc/CheckPenLoc(var/obj/item/proj)
	var/turf/startingturf = null
	if (istype(proj, /obj/item/projectile))
		var/obj/item/projectile/pj = proj
		pj.throw_source = pj.starting
	else if (istype(proj, /obj/item/missile))
		var/obj/item/missile/miss = proj
		startingturf = miss.startingturf
	if (!startingturf)
		return "front"
	switch(get_dir(startingturf, get_turf(src)))
		if (NORTH)
			switch(dir)
				if (NORTH)
					return "back"
				if (SOUTH)
					return "front"
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
		if (SOUTH)
			switch(dir)
				if (NORTH)
					return "front"
				if (SOUTH)
					return "back"
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
		if (WEST)
			switch(dir)
				if (NORTH)
					return "right"
				if (SOUTH)
					return "left"
				if (WEST)
					return "back"
				if (EAST)
					return "front"
				if (NORTHWEST)
					return "frontright"
				if (SOUTHWEST)
					return "frontleft"
				if (NORTHEAST)
					return "backright"
				if (SOUTHEAST)
					return "backleft"
		if (EAST)
			switch(dir)
				if (NORTH)
					return "left"
				if (SOUTH)
					return "right"
				if (WEST)
					return "front"
				if (EAST)
					return "back"
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
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_front[4])
				return TRUE
		if ("back")
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_back[4])
				return TRUE
		if ("left")
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_left[4])
				return TRUE
		if ("right")
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_right[4])
				return TRUE
		if ("frontleft")
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_front[4] || proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_left[4])
				return TRUE
		if ("backleft")
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_back[4] || proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_left[4])
				return TRUE
		if ("frontright")
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_front[4] || proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_right[4])
				return TRUE
		if ("backright")
			if (proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_back[4] || proj.heavy_armor_penetration-get_dist(src.loc,proj.starting) > w_right[4])
				return TRUE
	if (istype(proj, /obj/item/projectile/shell))
		playsound(loc, pick('sound/machines/tank/tank_ricochet1.ogg','sound/machines/tank/tank_ricochet2.ogg','sound/machines/tank/tank_ricochet3.ogg'),100, TRUE)
	else
		playsound(loc, "ric_sound", 50, TRUE)
	return FALSE

/obj/structure/vehicleparts/frame/bullet_act(var/obj/item/projectile/proj, var/penloc = "front")
	for (var/obj/structure/vehicleparts/frame/F in proj.firer.loc)
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
				var/adjdam = 0
				switch (PS.atype)
					if ("HE")
						for (var/mob/M in axis.transporting)
							shake_camera(M, 3, 3)
						adjdam = proj.damage * 0.08
					if ("APCR")
						adjdam = proj.damage * 0.35
					if ("AP")
						adjdam = proj.damage * 0.3
				switch(penloc)
					if ("left")
						w_left[5] -= adjdam
					if ("right")
						w_right[5] -= adjdam
					if ("front")
						w_front[5] -= adjdam
					if ("back")
						w_back[5] -= adjdam
					if ("frontleft")
						if (w_left[4] > w_front[4] && w_left[5]>0)
							w_left[5] -= adjdam
						else
							w_front[5] -= adjdam
					if ("frontright")
						if (w_right[4] > w_front[4] && w_right[5]>0)
							w_right[5] -= adjdam
						else
							w_front[5] -= adjdam
					if ("backleft")
						if (w_left[4] > w_back[4] && w_left[5]>0)
							w_left[5] -= adjdam
						else
							w_back[5] -= adjdam
					if ("backright")
						if (w_right[4] > w_back[4] && w_right[5]>0)
							w_right[5] -= adjdam
						else
							w_back[5] -= adjdam
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
	if (w_left[5] <= 0)
		w_left = list(w_left[1],FALSE,FALSE,0,0,FALSE,TRUE)
		visible_message("<span class='danger'>The wall gets wrecked!</span>")
	if (w_right[5] <= 0)
		w_right = list(w_right[1],FALSE,FALSE,0,0,FALSE,TRUE)
		visible_message("<span class='danger'>The wall gets wrecked!</span>")
	if (w_front[5] <= 0)
		w_front = list(w_front[1],FALSE,FALSE,0,0,FALSE,TRUE)
		visible_message("<span class='danger'>The wall gets wrecked!</span>")
	if (w_back[5] <= 0)
		w_back = list(w_back[1],FALSE,FALSE,0,0,FALSE,TRUE)
		visible_message("<span class='danger'>The wall gets wrecked!</span>")
	if (w_left[5]+w_right[5]+w_back[5]+w_front[5] <= 0)
		broken = TRUE
		if (prob(10))
			Destroy()
	update_icon()
/obj/structure/vehicleparts/frame/Destroy()
	visible_message("<span class='danger'>The frame gets wrecked!</span>")
	update_icon()
	if (axis)
		axis.Destroy()
	qdel(src)
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

//types of walls/borders
//format: type of wall, opacity, density, armor, current health, can open/close, is open?
var/global/list/vehicle_walls = list( \
	"" = list("",FALSE,FALSE,0,40,FALSE,FALSE), \
	"c_wall" = list("c_window",FALSE,TRUE,20,50,FALSE,FALSE), \
	"c_window" = list("c_wall",TRUE,TRUE,10,40,FALSE,FALSE), \
	"c_windshield" = list("c_windshield",FALSE,TRUE,6,35,FALSE,FALSE), \
	"c_armoredfront" = list("c_armoredfront",FALSE,TRUE,45,80,FALSE,FALSE), \
	"c_armoredwall" = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE), \
	"c_door" = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE), \
	"c_windowdoor" = list("c_windowdoor",FALSE,TRUE,28,60,TRUE,TRUE), \
	 \
)