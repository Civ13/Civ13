
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
	if (!H.driver_vehicle.engine.on && H.driver_vehicle.fueltank.reagents.total_volume > 0)
		H.driver_vehicle.engine.turn_on(H)
		H.driver_vehicle.set_light(3)
		playsound(loc, 'sound/machines/diesel_starting.ogg', 65, FALSE, 2)
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
	var/resistance = 150
	var/list/connections = list()
/obj/structure/vehicleparts/frame/wood
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "frame_wood"
	powerneeded = 0
	flammable = TRUE
	resistance = 90

///////////////////////EXTRA STUFF//////////////////////

/obj/item/sail
	name = "small sail"
	desc = "a small sail. Will fit a minor boat."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "sailing0"
	anchored = FALSE
	flammable = TRUE
	w_class = 4.0