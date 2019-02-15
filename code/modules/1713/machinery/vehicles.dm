
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
	if (currentspeed == 0)
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

/obj/item/vehicleparts/wheel/handle
	name = "motorcycle handles"
	desc = "Used to steer a motorcycle."
	icon_state = "bike_handles"

/obj/item/vehicleparts/wheel/attack_self(mob/living/carbon/human/H)
	if(!H.driver_vehicle)
		return
	if (!H.driver_vehicle.engine.on && H.driver_vehicle.fueltank.reagents.total_volume > 0)
		H.driver_vehicle.engine.turn_on(H)
		playsound(loc, 'sound/machines/diesel_starting.ogg', 65, FALSE, 2)
		spawn(40)
			if (H.driver_vehicle.engine.on)
				H.driver_vehicle.running_sound()
		return
	else if (H.driver_vehicle.fueltank.reagents.total_volume <= 0)
		H << "There is not enough fuel!"
		return

	if (H.driver_vehicle.moving == FALSE || H.driver_vehicle.axis.currentspeed == 0)
		H.driver_vehicle.moving = TRUE
		H.driver_vehicle.axis.currentspeed = 1
		var/spd = H.driver_vehicle.axis.get_speed()
		if (spd <= 0)
			return
		else
			H.driver_vehicle.vehicle_m_delay = spd
		H.driver_vehicle.startmovementloop()
		H << "You accelerate."
		return
	else if (H.driver_vehicle.axis.currentspeed<=H.driver_vehicle.axis.speeds)
		H.driver_vehicle.axis.currentspeed++
		var/spd = H.driver_vehicle.axis.get_speed()
		if (spd <= 0)
			return
		else
			H.driver_vehicle.vehicle_m_delay = spd
			H << "You increace the speed."
			return
/*
	else if (H.driver_vehicle.moving == TRUE)
		H.driver_vehicle.moving = FALSE
		H.driver_vehicle.stopmovementloop()
		H << "You brake."
		return
*/
/obj/item/vehicleparts/wheel/attack_hand(mob/living/carbon/human/user)
	if (!user.driver_vehicle.moving || user.driver_vehicle.axis.currentspeed <= 0 || !user.driver_vehicle.engine.on || user.driver_vehicle.fueltank.reagents.total_volume <= 0)
		return
	else
		user.driver_vehicle.axis.currentspeed--
		var/spd = user.driver_vehicle.axis.get_speed()
		if (spd <= 0)
			return
		else
			user.driver_vehicle.vehicle_m_delay = spd
			user << "You reduce the speed."
			return