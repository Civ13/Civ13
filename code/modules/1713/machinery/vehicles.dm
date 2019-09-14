
/obj/structure/vehicleparts
	name = "vehicle part"
	desc = "a basic vehicle part."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "part"
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	flammable = FALSE
/////////////////////////////////AXIS/////////////////////////////////////
/obj/structure/vehicleparts/axis
	name = "vehicle axis"
	desc = "supports wheels."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "axis_powered"
	var/list/wheels = list()
	var/currentspeed = 0
	var/speeds = 5
	var/maxpower = 50
	var/list/speedlist = list(1=6,2=5,3=4,4=3,5=2)
	powerneeded = 0
	var/obj/structure/engine/internal/engine = null
	var/moving = FALSE
	var/vehicle_m_delay = 1
	var/obj/item/vehicleparts/wheel/modular/wheel = null
	var/reverse = FALSE
	var/list/transporting = list()
	var/list/components = list()
	var/current_weight = 5
////////MOVEMENT LOOP/////////
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
			if (!istype(M, /obj/structure/cannon))
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
/obj/structure/vehicleparts/axis/bike
	name = "motorcycle axis"
	currentspeed = 0
	speeds = 3
	maxpower = 10
	speedlist = list(1=3,2=2,3=1)

/obj/structure/vehicleparts/axis/boat
	name = "boat rudder control"
	currentspeed = 0
	speeds = 3
	maxpower = 40
	speedlist = list(1=8,2=6,3=4)

/obj/structure/vehicleparts/axis/heavy
	name = "heavy vehicle axis"
	desc = "A heavy and slow vehicle axis."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 3
	maxpower = 250
	speedlist = list(1=12,2=10,3=8)

/obj/structure/vehicleparts/axis/car
	name = "car axis"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 70
	speedlist = list(1=8,2=6,3=4,4=3,5=2)

/obj/structure/vehicleparts/axis/proc/get_speed()
	if (currentspeed <= 0)
		currentspeed = 0
		powerneeded = 0
		return 0
	else
		var/spd = (currentspeed/speeds)*maxpower
		powerneeded = spd
		return speedlist[currentspeed]

/obj/structure/vehicleparts/axis/proc/check_enginepower(var/esize = 0)
	return

/obj/structure/vehicleparts/axis/bike/check_enginepower(var/esize = 0)
	if (esize == 0)
		return
	if (esize >= 120)
		speedlist = list(1=3,2=2,3=1)
	else if (esize >= 95)
		speedlist = list(1=4,2=3,3=2)
	else
		speedlist = list(1=5,2=4,3=3)
		return

/obj/structure/vehicleparts/axis/boat/check_enginepower(var/esize = 0)
	if (esize == 0)
		return
	if (esize >= 300)
		speedlist = list(1=8,2=6,3=4)
	else if (esize >= 200)
		speedlist = list(1=9,2=7,3=5)
	else
		speedlist = list(1=10,2=8,3=6)
		return
///////////////////////////////////DRIVING WHEEL/////////////////////
/obj/item/vehicleparts/wheel
	name = "vehicle wheel"
	desc = "Used to steer a vehicle."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "wheel"
	anchored = FALSE
	flammable = FALSE
	nothrow = TRUE
	nodrop = TRUE
	w_class = 5
	secondary_action = TRUE

/obj/item/vehicleparts/wheel/handle
	name = "motorcycle handles"
	desc = "Used to steer a motorcycle."
	icon_state = "bike_handles"

/obj/item/vehicleparts/wheel/rudder
	name = "boat rudder"
	desc = "Used to steer a boat."
	icon_state = "rudder"

/obj/item/vehicleparts/wheel/rudder_sails
	name = "boat rudder and sail control"
	desc = "Used to steer a boat and control the sails."
	icon_state = "rudder"
	var/spamtimer = 0
/obj/item/vehicleparts/wheel/rudder_sails/attack_self(mob/living/carbon/human/H)
	if(!H.driver_vehicle)
		return
	if (!H.driver_vehicle.sails)
		return
	if (!(H.driver_vehicle in range(3,loc)))
		return
	if (H.driver_vehicle.sails)
		if (!H.driver_vehicle.sails_on)
			if (world.time > spamtimer)
				H << "You hoist the sails."
				H.driver_vehicle.sails_on = TRUE
				H.driver_vehicle.check_sails()
				spamtimer = world.time + 20
				H.driver_vehicle.update_overlay()
				return
		else
			H << "You retract the sails."
			H.driver_vehicle.sails_on = FALSE
			H.driver_vehicle.update_overlay()
			return
/obj/item/vehicleparts/wheel/attack_self(mob/living/carbon/human/H)
	if(!H.driver_vehicle)
		return
	if(!H.driver_vehicle.engine)
		return
	if (!(H.driver_vehicle in range(3,loc)))
		return
	if (!H.driver_vehicle.engine.on && H.driver_vehicle.fueltank.reagents.total_volume > 0)
		H.driver_vehicle.engine.turn_on(H)
		H.driver_vehicle.set_light(3)
		playsound(loc, 'sound/machines/diesel_starting.ogg', 35, FALSE, 2)
		spawn(40)
			if (H.driver_vehicle && H.driver_vehicle.engine && H.driver_vehicle.engine.on)
				H.driver_vehicle.running_sound()
		return
	else if (H.driver_vehicle.fueltank.reagents.total_volume <= 0)
		H << "There is not enough fuel!"
		return

	if (H.driver_vehicle.axis.currentspeed <= 0)
		H.driver_vehicle.axis.currentspeed = 1
		var/spd = H.driver_vehicle.axis.get_speed()
		if (spd <= 0)
			return
		else
			H.driver_vehicle.vehicle_m_delay = spd
		spawn(1)
			if (H.driver_vehicle.axis.currentspeed == 1)
				H.driver_vehicle.moving = TRUE
				H.driver_vehicle.startmovementloop()
				H << "You put on the first gear."
		return
	else if (H.driver_vehicle.axis.currentspeed<H.driver_vehicle.axis.speedlist.len)
		H.driver_vehicle.axis.currentspeed++
		if (H.driver_vehicle.axis.currentspeed>H.driver_vehicle.axis.speedlist.len)
			H.driver_vehicle.axis.currentspeed = H.driver_vehicle.axis.speedlist.len
		var/spd = H.driver_vehicle.axis.get_speed()
		if (spd <= 0)
			return
		else
			H.driver_vehicle.vehicle_m_delay = spd
			H << "You increase the speed."
			return
	else
		return
/*
	else if (H.driver_vehicle.moving == TRUE)
		H.driver_vehicle.moving = FALSE
		H.driver_vehicle.stopmovementloop()
		H << "You brake."
		return
*/

/obj/item/vehicleparts/wheel/secondary_attack_self(mob/living/carbon/human/user)
	if (user.driver_vehicle.axis.currentspeed <= 0 || !user.driver_vehicle.engine.on || user.driver_vehicle.fueltank.reagents.total_volume <= 0)
		return
	else
		user.driver_vehicle.axis.currentspeed--
		var/spd = user.driver_vehicle.axis.get_speed()
		if (spd <= 0 || user.driver_vehicle.axis.currentspeed == 0)
			user.driver_vehicle.moving = FALSE
			user << "You stop \the [user.driver_vehicle]."
			return
		else
			user.driver_vehicle.vehicle_m_delay = spd
			user << "You reduce the speed."
			return
///////////////////FRAME///////////////////////////////
/obj/item/vehicleparts/frame
	name = "vehicle frame"
	desc = "a vehicle frame."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "motorcycle_frame0"
	var/customcolor = "#FFFFFF"
	var/maxengine = 500
	var/maxfueltank = 100
	density = TRUE
	weight = 100
	w_class = 10
	nothrow = TRUE
	throw_speed = 1
	throw_range = 1
	var/obj/structure/engine/internal/engine = null
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/fueltank = null
	var/step = 0
	var/maxstep = 3
	var/targettype = /obj/structure/vehicle
	var/image/colorv = null

/obj/item/vehicleparts/frame/bike
	name = "motorcycle frame"
	desc = "a motorcycle frame. Will fit engines up to 125cc and fueltanks up to 75u."
	icon_state = "motorcycle_frame1"
	var/base_icon = "motorcycle_frame"
	customcolor = "#FFFFFF"
	maxengine = 125
	maxfueltank = 75
	weight = 20
	w_class = 6
	step = 1
	maxstep = 3
	targettype = /obj/structure/vehicle/motorcycle

/obj/item/vehicleparts/frame/boat
	name = "outrigger boat frame"
	desc = "a simple outrigger boat frame, with no engine or propulsion mode. Supports engines up to 400cc and fueltanks up to 150u"
	icon = 'icons/obj/vehicleparts64x64.dmi'
	icon_state = "outrigger_frame1"
	var/base_icon = "outrigger_frame"
	maxengine = 400
	maxfueltank = 150
	weight = 60
	w_class = 7
	step = 1
	maxstep = 3
	targettype = /obj/structure/vehicle/boat

/obj/item/vehicleparts/frame/proc/do_color()
	colorv = image("icon" = icon, "icon_state" = "[icon_state]_mask")
	colorv.color = customcolor
	overlays += colorv
	update_icon()

/obj/item/vehicleparts/frame/bike/update_icon()
	..()
	icon_state = "[base_icon][step]"

/obj/item/vehicleparts/frame/boat/update_icon()
	..()
	icon_state = "[base_icon][step]"
/obj/item/vehicleparts/frame/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/sail) && step == 1 && istype(src, /obj/item/vehicleparts/frame/boat))
		if (do_after(user,130,src) && src && W)
			user << "<span class = 'notice'>You attach the [W] to the [src].</span>"
			user.drop_from_inventory(W)
			qdel(W)
			new/obj/structure/vehicle/boat/sailboat(get_turf(user))
			qdel(src)
			return

	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel/fueltank) && step == 2)
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/NF = W
		if (NF.reagents.maximum_volume <= maxfueltank)
			if (do_after(user,100,src))
				if (fueltank == null)
					user << "<span class = 'notice'>You attach the [W] to the [src].</span>"
					user.drop_from_inventory(W)
					fueltank = W
					W.forceMove(src)
					step = 3
					check_step()
					return
		else
			user << "<span class = 'notice'>This fuel tank is too big for the [src]!</span>"
			return
	else
		..()
/obj/item/vehicleparts/frame/MouseDrop_T(obj/structure/O as obj, mob/user as mob)
	if (istype(O, /obj/structure/engine/internal) && step == 1)
		var/obj/structure/engine/internal/NE = O
		if (NE.enginesize <= maxengine && NE.enginesize >= maxengine/4)
			user << "<span class = 'notice'>You start placing the [O].</span>"
			if (do_after(user,130,src))
				if (engine == null)
					user << "<span class = 'notice'>You attach the [O] to the [src].</span>"
					engine = O
					O.forceMove(src)
					step = 2
					check_step()
					update_icon()
					return
		else if (NE.enginesize > maxengine)
			user << "<span class = 'notice'>This engine is too big for the [src]!</span>"
			return
		else if (NE.enginesize <= maxengine && NE.enginesize < maxengine/4)
			user << "<span class = 'notice'>This engine is too small for the [src]!</span>"
			return

/obj/item/vehicleparts/frame/proc/check_step()
	if (step >= maxstep)
		var/obj/structure/vehicle/NEWBIKE = new/obj/structure/vehicle/motorcycle(get_turf(src))
		NEWBIKE.dir = dir
		NEWBIKE.customcolor = customcolor
		NEWBIKE.do_color()
		NEWBIKE.engine = engine
		NEWBIKE.fueltank = fueltank
		NEWBIKE.name = name
		spawn(1)
			NEWBIKE.engine.fueltank = NEWBIKE.fueltank
			NEWBIKE.engine.connections += NEWBIKE.axis
			NEWBIKE.dwheel.forceMove(NEWBIKE)
			spawn(1)
				engine.forceMove(NEWBIKE)
				fueltank.forceMove(NEWBIKE)
				NEWBIKE.axis.check_enginepower(NEWBIKE.engine.enginesize)
				qdel(src)
				return
	else
		update_icon()
		if (colorv)
			colorv = image("icon" = icon, "icon_state" = "[icon_state]_mask")
			colorv.color = customcolor
		update_icon()
		return

/obj/item/vehicleparts/frame/attack_hand(mob/user as mob)
	return

/obj/item/vehicleparts/frame/boat/check_step()
	if (step >= maxstep)
		var/obj/structure/vehicle/NEWBOAT = new/obj/structure/vehicle/boat(get_turf(src))
		NEWBOAT.dir = dir
		NEWBOAT.engine = engine
		NEWBOAT.fueltank = fueltank
		NEWBOAT.name = name
		spawn(1)
			NEWBOAT.engine.fueltank = NEWBOAT.fueltank
			NEWBOAT.engine.connections += NEWBOAT.axis
			NEWBOAT.dwheel.forceMove(NEWBOAT)
			spawn(1)
				engine.forceMove(NEWBOAT)
				fueltank.forceMove(NEWBOAT)
				NEWBOAT.axis.check_enginepower(NEWBOAT.engine.enginesize)
				qdel(src)
				return
		return
////////////////////////FRAMES//////////////////////
/obj/structure/vehicleparts/frame
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "frame_steel"
	powerneeded = 0
	flammable = FALSE
	layer = 2.98
	var/resistance = 150
	var/obj/structure/vehicleparts/axis/axis = null
	var/w_front = null
	var/w_back = null
	var/w_left = null
	var/w_right = null
	var/image/roof
	not_movable = TRUE
	not_disassemblable = TRUE
	var/total_weight = 10

	New()
		..()
		update_icon()
		roof = image(icon=icon, loc=src.loc, icon_state="roof_steel", layer=8)
	relaymove(var/mob/mob, direction)
		..()
		update_icon()
	Move(newloc, direct)
		..()
		update_icon()

/obj/structure/vehicleparts/frame/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis && !axis)
		for(var/obj/structure/vehicleparts/frame/FR in range(1,src))
			if (VP.axis.components.len > 25)
				usr << "<span class='notice'>The vehicle is too big already!</span>"
				return
			if (FR != src && FR.axis == VP.axis)
				playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
				usr << "You connect \the [src] to \the [VP.axis]."
				axis = VP.axis
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
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You connect \the [VP] to \the [axis]."
		axis.engine = VP
		VP.forceMove(loc)
		VP.anchored = TRUE
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

/obj/structure/vehicleparts/frame/wood
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 90

/obj/structure/vehicleparts/frame/update_icon()
	..()
	overlays.Cut()
	switch (dir)
		if (NORTH)
			if (w_left)
				var/image/tmpimg3 = image(icon=icon, icon_state=w_left, layer=4.5, dir=WEST)
				overlays += tmpimg3
			if (w_right)
				var/image/tmpimg4 = image(icon=icon, icon_state=w_right, layer=4.5, dir=EAST)
				overlays += tmpimg4
			if (w_front)
				var/image/tmpimg1 = image(icon=icon, icon_state=w_front, layer=4.5, dir=NORTH)
				overlays += tmpimg1
			if (w_back)
				var/image/tmpimg2 = image(icon=icon, icon_state=w_back, layer=4.5, dir=SOUTH)
				overlays += tmpimg2
		if (SOUTH)
			if (w_left)
				var/image/tmpimg3 = image(icon=icon, icon_state=w_left, layer=4.5, dir=EAST)
				overlays += tmpimg3
			if (w_right)
				var/image/tmpimg4 = image(icon=icon, icon_state=w_right, layer=4.5, dir=WEST)
				overlays += tmpimg4
			if (w_front)
				var/image/tmpimg1 = image(icon=icon, icon_state=w_front, layer=4.5, dir=SOUTH)
				overlays += tmpimg1
			if (w_back)
				var/image/tmpimg2 = image(icon=icon, icon_state=w_back, layer=4.5, dir=NORTH)
				overlays += tmpimg2
		if (EAST)
			if (w_left)
				var/image/tmpimg3 = image(icon=icon, icon_state=w_left, layer=4.5, dir=NORTH)
				overlays += tmpimg3
			if (w_right)
				var/image/tmpimg4 = image(icon=icon, icon_state=w_right, layer=4.5, dir=SOUTH)
				overlays += tmpimg4
			if (w_front)
				var/image/tmpimg1 = image(icon=icon, icon_state=w_front, layer=4.5, dir=EAST)
				overlays += tmpimg1
			if (w_back)
				var/image/tmpimg2 = image(icon=icon, icon_state=w_back, layer=4.5, dir=WEST)
				overlays += tmpimg2
		if (WEST)
			if (w_left)
				var/image/tmpimg3 = image(icon=icon, icon_state=w_left, layer=4.5, dir=SOUTH)
				overlays += tmpimg3
			if (w_right)
				var/image/tmpimg4 = image(icon=icon, icon_state=w_right, layer=4.5, dir=NORTH)
				overlays += tmpimg4
			if (w_front)
				var/image/tmpimg1 = image(icon=icon, icon_state=w_front, layer=4.5, dir=WEST)
				overlays += tmpimg1
			if (w_back)
				var/image/tmpimg2 = image(icon=icon, icon_state=w_back, layer=4.5, dir=EAST)
				overlays += tmpimg2
/obj/structure/vehicleparts/frame/basicsmall
	w_front = "c_windshield"
	w_back = "c_wall"
	w_left = "c_wall"
	w_right = "c_wall"
/obj/structure/vehicleparts/frame/lwall
	w_left = "c_window"
/obj/structure/vehicleparts/frame/rwall
	w_right = "c_window"
/obj/structure/vehicleparts/frame/rb
	w_right = "c_wall"
	w_back = "c_wall"
/obj/structure/vehicleparts/frame/lb
	w_left = "c_wall"
	w_back = "c_wall"
/obj/structure/vehicleparts/frame/rf
	w_right = "c_wall"
	w_front = "c_windshield"
/obj/structure/vehicleparts/frame/lf
	w_left = "c_wall"
	w_front = "c_windshield"

////////////////////////WHEELS AND TRACKS///////////////////
/obj/structure/vehicleparts/movement
	name = "wheel"
	icon_state = "wheel"
	var/base_icon = "wheel"
	var/movement_icon = "wheel_m"
	layer = 4
	var/reversed = FALSE
/obj/structure/vehicleparts/movement/tracks
	name = "armored tracks"
	icon_state = "tracks_end"
	base_icon = "tracks_end"
	movement_icon = "tracks_end_m"
/obj/structure/vehicleparts/movement/tracks/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis)
		VP.axis.wheels += src
		playsound(loc, 'sound/effects/lever.ogg',80, TRUE)
///////////////////////EXTRA STUFF//////////////////////

/obj/item/sail
	name = "small sail"
	desc = "a small sail. Will fit a minor boat."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "sailing0"
	anchored = FALSE
	flammable = TRUE
	w_class = 4.0

/obj/item/vehicleparts/wheel/modular
	name = "vehicle wheel"
	desc = "Used to steer a vehicle."
	icon_state = "wheel_b"
	var/obj/structure/bed/chair/drivers/drivingchair = null
	var/obj/structure/vehicleparts/frame/control = null
/obj/item/vehicleparts/wheel/modular/attack_self(mob/living/carbon/human/H)
	if(!control)
		return
	if(!control.axis)
		return
	if (!(control.loc in range(1,loc)))
		H.remove_from_mob(src)
		src.forceMove(drivingchair)
		return
	if (!control.axis.engine.on && control.axis.engine.fueltank && control.axis.engine.fueltank.reagents.total_volume > 0)
		control.axis.engine.turn_on(H)
		playsound(loc, 'sound/machines/diesel_starting.ogg', 35, FALSE, 2)
		spawn(40)
			if (control.axis.engine && control.axis.engine.on)
				control.axis.engine.running_sound()
		return
	else if (control.axis.engine.fueltank.reagents.total_volume <= 0)
		H << "There is not enough fuel!"
		return
	if (control.axis.currentspeed < 0)
		control.axis.currentspeed = 0
		var/spd = control.axis.get_speed()
		control.axis.vehicle_m_delay = spd
	if (control.axis.currentspeed<control.axis.speeds)
		if (control.axis.currentspeed == 0 && control.axis.reverse)
			control.axis.moving = FALSE
			H << "You stop \the [control.axis.engine]."
			playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
			control.axis.reverse = FALSE
			return
		control.axis.currentspeed++
		if (control.axis.currentspeed>control.axis.speeds)
			control.axis.currentspeed = control.axis.speeds
		var/spd = control.axis.get_speed()
		control.axis.vehicle_m_delay = spd
		if (control.axis.currentspeed == 1)
			control.axis.moving = TRUE
			control.axis.reverse = FALSE
			H << "You put on the first gear."
			playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
			control.axis.add_transporting()
			control.axis.startmovementloop()
		else
			H << "You increase the speed."
			control.axis.reverse = FALSE
			playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
		return
	else
		return

/obj/item/vehicleparts/wheel/modular/secondary_attack_self(mob/living/carbon/human/user)
	if (!control || !control.axis)
		return
	if (control.axis.currentspeed <= 0 || !control.axis.engine.on || control.axis.engine.fueltank.reagents.total_volume <= 0)
		return
	else
		var/spd = control.axis.get_speed()
		if ((spd <= 0 || control.axis.currentspeed == 0) && !control.axis.reverse)
			user << "You switch into reverse."
			control.axis.reverse = TRUE
			control.axis.add_transporting()
			control.axis.moving = TRUE
			control.axis.startmovementloop()
			playsound(loc, 'sound/effects/lever.ogg',65, TRUE)
		else
			control.axis.currentspeed--
			spd = control.axis.get_speed()
			if (spd <= 0 || control.axis.currentspeed == 0)
				control.axis.moving = FALSE
				user << "You stop \the [control.axis.engine]."
				control.axis.reverse = FALSE
				return

			else
				control.axis.vehicle_m_delay = spd
				control.axis.reverse = FALSE
				user << "You reduce the speed."
				playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
				return

/obj/structure/bed/chair/drivers
	name = "driver's seat"
	desc = "Where you drive the vehicle."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "driver_car"
	anchored = FALSE
	var/obj/item/vehicleparts/wheel/modular/wheel = null
	New()
		..()
		wheel = new/obj/item/vehicleparts/wheel/modular(src)
		wheel.drivingchair = src

/obj/structure/bed/chair/drivers/update_icon()
	return

/obj/structure/bed/chair/drivers/post_buckle_mob()
	if (buckled_mob && istype(buckled_mob, /mob/living/carbon/human) && buckled_mob.put_in_active_hand(wheel) == FALSE)
		buckled_mob << "Your hands are full!"
		return

/obj/structure/bed/chair/drivers/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (buckled_mob && H == buckled_mob && istype(I, /obj/item/vehicleparts/wheel/modular))
		H.remove_from_mob(I)
		I.forceMove(src)
		return
	else
		..()
/obj/structure/bed/chair/drivers/attack_hand( var/mob/living/carbon/human/H)
	if (buckled_mob && H == buckled_mob && wheel.loc != H)
		if (buckled_mob.put_in_active_hand(wheel))
			H << "You grab the wheel."
			return
	else
		..()