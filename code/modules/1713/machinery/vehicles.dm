
/obj/structure/vehicleparts
	name = "vehicle part"
	desc = "a basic vehicle part."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "part"
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	flammable = FALSE

/obj/structure/vehicleparts/axis
	name = "vehicle axis"
	desc = "supports wheels."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "axis"
	var/list/wheels = list()
	var/currentspeed = 0
	var/speeds = 5
	var/maxpower = 50
	var/list/speedlist = list(1=6,2=5,3=4,4=3,5=2)
	powerneeded = 0

/obj/structure/vehicleparts/axis/bike
	name = "motorcycle axis"
	currentspeed = 0
	speeds = 3
	maxpower = 10
	speedlist = list(1=3,2=2,3=1)

/obj/structure/vehicleparts/axis/proc/get_speed()
	if (currentspeed <= 0)
		currentspeed = 0
		powerneeded = 0
		return 0
	else
		var/spd = (currentspeed/speeds)*maxpower
		powerneeded = spd
		return speedlist[currentspeed]


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

/obj/item/vehicleparts/wheel/attack_self(mob/living/carbon/human/H)
	if(!H.driver_vehicle)
		return
	if(!H.driver_vehicle.engine)
		return
	if (!H.driver_vehicle.engine.on && H.driver_vehicle.fueltank.reagents.total_volume > 0)
		H.driver_vehicle.engine.turn_on(H)
		H.driver_vehicle.set_light(3)
		playsound(loc, 'sound/machines/diesel_starting.ogg', 65, FALSE, 2)
		spawn(40)
			if (H.driver_vehicle.engine.on)
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
			H.driver_vehicle.moving = TRUE
			H.driver_vehicle.startmovementloop()
			H << "You put on the first gear."
		return
	else if (H.driver_vehicle.axis.currentspeed<H.driver_vehicle.axis.speedlist.len)
		H.driver_vehicle.axis.currentspeed++
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

/obj/item/vehicleparts/frame
	name = "vehicle frame"
	desc = "a vehicle frame."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "motorcycle_frame0"
	var/customcolor = "#FFFFFF"
	var/maxengine = 500
	var/maxfueltank = 100
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

/obj/item/vehicleparts/frame/proc/do_color()
	if (customcolor)
		colorv = image("icon" = icon, "icon_state" = "[icon_state]_mask")
		colorv.color = customcolor
		overlays += colorv
	update_icon()

/obj/item/vehicleparts/frame/bike/update_icon()
	..()
	icon_state = "[base_icon][step]"

/obj/item/vehicleparts/frame/attackby(obj/item/W as obj, mob/user as mob)
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
		if (NE.enginesize <= maxengine)
			user << "<span class = 'notice'>You start placing the [O].</span>"
			if (do_after(user,130,src))
				if (engine == null)
					user << "<span class = 'notice'>You attach the [O] to the [src].</span>"
					engine = O
					O.forceMove(src)
					step = 2
					check_step()
					return
		else
			user << "<span class = 'notice'>This fuel tank is too big for the [src]!</span>"
			return

/obj/item/vehicleparts/frame/proc/check_step()
	if (step >= maxstep)
		var/obj/structure/vehicle/NEWBIKE = new/obj/structure/vehicle/motorcycle(get_turf(src))
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
				qdel(src)
				return
	else
		update_icon()
		if (colorv)
			colorv = image("icon" = icon, "icon_state" = "[icon_state]_mask")
			colorv.color = customcolor
		update_icon()
		return