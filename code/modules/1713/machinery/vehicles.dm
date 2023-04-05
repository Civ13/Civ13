
/obj/structure/vehicleparts
	name = "vehicle part"
	desc = "a basic vehicle part."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "part"
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	flammable = FALSE
	var/broken_icon = 'icons/obj/vehicles/vehicleparts_damaged.dmi'
	var/normal_icon = 'icons/obj/vehicles/vehicleparts.dmi'
/////////////////////////////////AXIS/////////////////////////////////////
/obj/structure/vehicleparts/axis
	name = "vehicle axis"
	desc = "supports wheels."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	var/vehicle_size = "3x4"
	var/vehicle_type = "car"
	var/list/wheels = list()
	var/currentspeed = 0
	var/speeds = 5
	var/maxpower = 50
	var/list/speedlist = list(1=6,2=5,3=4,4=3,5=2)
	powerneeded = 0
	var/obj/structure/engine/engine = null
	var/moving = FALSE
	var/vehicle_m_delay = 1
	var/obj/item/vehicleparts/wheel/modular/wheel = null
	var/reverse = FALSE
	var/list/transporting = list()
	var/list/components = list()
	var/current_weight = 5
	var/lastmovementloop = 0
	var/mob/living/human/driver = null

	//matrix/turning stuff
	var/list/corners = list()
	var/list/matrix = list()
	var/matrix_l = 0
	var/matrix_h = 0
	var/list/matrix_current_locs = list()
	var/turret_type = "tank_turret"
/obj/structure/vehicleparts/axis/bike
	name = "motorcycle axis"
	currentspeed = 0
	speeds = 3
	maxpower = 10
	speedlist = list(1=3,2=2,3=1)
	reg_number = ""
	turntimer = 5
	vehicle_type = "bike"

/obj/structure/vehicleparts/axis/carriage
	name = "carriage axis"
	currentspeed = 0
	speeds = 3
	maxpower = 10
	speedlist = null
	reg_number = ""
	turntimer = 5
	vehicle_type = "carriage"

/obj/structure/vehicleparts/axis/boat
	name = "boat rudder control"
	currentspeed = 0
	speeds = 3
	maxpower = 40
	speedlist = list(1=8,2=6,3=4)
	reg_number = ""
	vehicle_type = "boat"

/obj/structure/vehicleparts/axis/heavy
	name = "heavy vehicle axis"
	desc = "A heavy and slow vehicle axis."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 3
	maxpower = 2500
	speedlist = list(1=12,2=8,3=6)
	vehicle_type = "tank"

/obj/structure/vehicleparts/axis/heavy/is3
	name = "IS-3"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#5C5C4C"
	turret_type = "is3_turret"
	vehicle_size = "3x5"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t34
	name = "T-34"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#3d5931"
	turret_type = "t34_turret"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/bt7
	name = "BT-7"
	speeds = 7
	speedlist = list(1=12,2=8,3=6,4=5,5=4,6=3,7=2)
	reg_number = ""
	color = "#5c784f"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/su85
	name = "SU-85"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#506945"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/kv1a
	name = "KV-1A"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#3d5931"
	turret_type = "kv_turret"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"


/obj/structure/vehicleparts/axis/heavy/mtlb
	name = "MT-LB"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#4a5243"
	turret_type = "none"
	vehicle_size = "2x4"
	vehicle_type = "apc"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/m113
	name = "M113 APC"
	speeds = 4
	speedlist = list(1=14,2=10,3=8)
	reg_number = ""
	turret_type = "none"
	vehicle_size = "3x4"
	color = "#939276"
	vehicle_type = "apc"
	New()
		..()
		var/pickedname = pick(tank_names_usa)
		tank_names_usa -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/bmd2
	name = "BMD-2"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#787859"
	turret_type = "bmd2_turret"
	vehicle_size = "2x4"
	vehicle_type = "apc"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/bmd2new
	name = "BMD-2"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#787859"
	turret_type = "bmd2_turret"
	vehicle_size = "2x3"
	vehicle_type = "apc"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t3485
	name = "T-34-85"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	turret_type = "t3485_turret"
	reg_number = ""
	color = "#3d5931"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t72
	name = "T-72"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	turret_type = "t72_turret"
	reg_number = ""
	color = "#5C5C4C"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t64bm
	name = "T-64BM"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	turret_type = "t64bm_turret"
	reg_number = ""
	color = "#5C5C4C"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t64bv
	name = "T-64BV"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	turret_type = "t64bv_turret"
	reg_number = ""
	color = "#5C5C4C"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t62a
	name = "T-62A"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	turret_type = "t62a_turret"
	reg_number = ""
	color = "#5C5C4C"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t62m
	name = "T-62M"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	turret_type = "t62m_turret"
	reg_number = ""
	color = "#5C5C4C"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t62mv
	name = "T-62MV"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	turret_type = "t62mv_turret"
	reg_number = ""
	color = "#5C5C4C"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/t55
	name = "T-55"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	turret_type = "t55_turret"
	reg_number = ""
	color = "#5C5C4C"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/panzeriv
	name = "Panzer IV"
	speeds = 3
	speedlist = list(1=12,2=8,3=6)
	reg_number = ""
	color = "#585A5C"
	turret_type = "pziv_turret"
	New()
		..()
		var/pickedname = pick(tank_names_german)
		tank_names_german -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/panzervi
	name = "Panzer VI Tiger"
	speeds = 4
	speedlist = list(1=14,2=11,3=9,4=7)
	turret_type = "tiger_tank"
	reg_number = ""
	color = "#3B3F41"
	New()
		..()
		var/pickedname = pick(tank_names_german)
		tank_names_german -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/omw22_2
	name = "OMW-22 mk. II"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	reg_number = ""
	color = "#774D4C"
	turret_type = "t55_turret"

/obj/structure/vehicleparts/axis/heavy/baf1_a
	name = "BAF I mod. A"
	speeds = 4
	speedlist = list(1=9,2=6,3=4,4=3)
	reg_number = ""
	color = "#8383C2"
	turret_type = "pt76_turret"

/obj/structure/vehicleparts/axis/heavy/adrian
	name = "Type-9 Adrian"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	reg_number = ""
	color = "#555346"
	turret_type = "bmd2_turret"
	vehicle_size = "2x3"
	vehicle_type = "apc"

/obj/structure/vehicleparts/axis/heavy/t90a
	name = "T-90A"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	reg_number = ""
	color = "#5C5C4C"
	turret_type = "t90a_turret"

/obj/structure/vehicleparts/axis/heavy/leopard
	name = "Leopard 2A6"
	speeds = 4
	speedlist = list(1=9,2=6,3=4,4=3)
	reg_number = ""
	color = "#5C5C4C"
	turret_type = "2a6_turret"

/obj/structure/vehicleparts/axis/heavy/challenger2
	name = "FV4034 Challenger 2"
	speeds = 4
	speedlist = list(1=9,2=6,3=4,4=3)
	reg_number = ""
	color = "#CCC0A6"
	turret_type = "challenger2_turret"

/obj/structure/vehicleparts/axis/heavy/i_go
	name = "Type 89 I-Go"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	color = "#6a5a3d"
	turret_type = "jap_turret"
	reg_number = ""
	New()
		..()
		var/pickedname = pick(tank_names_japanese)
		tank_names_japanese -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/chi_ha
	name = "Type 97 Chi-Ha"
	speeds = 4
	speedlist = list(1=10,2=7,3=5,4=4)
	color = "#6a5a3d"
	turret_type = "jap_turret"
	reg_number = ""
	New()
		..()
		var/pickedname = pick(tank_names_japanese)
		tank_names_japanese -= pickedname
		name = "[name] \'[pickedname]\'"
/obj/structure/vehicleparts/axis/heavy/m4
	name = "M-4 Sherman"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	color = "#293822"
	reg_number = ""
	New()
		..()
		var/pickedname = pick(tank_names_usa)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/heavy/m48a1
	name = "M-48A1 Patton"
	speeds = 4
	speedlist = list(1=12,2=8,3=6,4=5)
	color = "#293822"
	turret_type = "m48a1_turret"
	reg_number = ""
	New()
		..()
		var/pickedname = pick(tank_names_usa)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/car
	name = "car axis"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=8,2=6,3=4,4=3,5=2)
	turntimer = 8
	vehicle_type = "car"

/obj/structure/vehicleparts/axis/proc/get_speed()
	if (currentspeed <= 0)
		currentspeed = 0
		powerneeded = 0
		return 0
	else
		var/spd = (currentspeed/speeds)*maxpower
		powerneeded = spd
		if (currentspeed > speedlist.len)
			currentspeed = speedlist.len
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
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "wheel"
	anchored = FALSE
	flammable = FALSE
	nothrow = TRUE
	nodrop = TRUE
	w_class = ITEM_SIZE_HUGE
	flags = CONDUCT
	secondary_action = TRUE
	var/obj/structure/vehicle/origin = null

/obj/item/vehicleparts/wheel/rope
	name = "Reins"
	desc = "Used to control animal propulsion vehicles."
	icon = 'icons/obj/items.dmi'
	icon_state = "leash"

/obj/item/vehicleparts/wheel/rope/attack_self(mob/living/human/H)
	if(istype(H.driver_vehicle, /obj/structure/vehicle/carriage))
		var/obj/structure/vehicle/carriage/M = H.driver_vehicle
		if(M.buckled_animal_propulsion <= 0)
			H << "You need animals to move the [H.driver_vehicle.name]."
			return
		else if(M.buckled_animal_propulsion == 1)
			H.driver_vehicle.axis.speedlist = list(1=25,2=20)
		else if(M.buckled_animal_propulsion == 2)
			H.driver_vehicle.axis.speedlist = list(1=20,2=15,3=10)
		else if(M.buckled_animal_propulsion == 4)
			H.driver_vehicle.axis.speedlist = list(1=10,2=4,3=1.6)
		else if(M.buckled_animal_propulsion == 6)
			H.driver_vehicle.axis.speedlist = list(1=9,2=3,3=1.4)
		else if(M.buckled_animal_propulsion == 8)
			H.driver_vehicle.axis.speedlist = list(1=8,2=2.8,3=1.2)
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
				H << "You hit the animal to move."
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
			H << "You hit the animal harder."
			return
	else
		return

/obj/item/vehicleparts/wheel/rope/secondary_attack_self(mob/living/human/user)
	if (user && user.driver_vehicle && user.driver_vehicle.axis && user.driver_vehicle.axis.currentspeed <= 0)
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
			user << "You pull the rope to reduce the speed."
			return

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
/obj/item/vehicleparts/wheel/rudder_sails/attack_self(mob/living/human/H)
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
/obj/item/vehicleparts/wheel/attack_self(mob/living/human/H)
	if(!H.driver_vehicle)
		return
	if(!H.driver_vehicle.engine)
		return
	if (!(H.driver_vehicle in range(3,loc)))
		return
	if (!H.driver_vehicle.engine.on && H.driver_vehicle.fueltank.reagents.total_volume > 0)
		H.driver_vehicle.engine.turn_on(H)
		H.driver_vehicle.set_light(3)
		playsound(loc, H.driver_vehicle.engine.starting_snd, 35, FALSE, 2)
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

/obj/item/vehicleparts/wheel/secondary_attack_self(mob/living/human/user)
	if (user && user.driver_vehicle && user.driver_vehicle.axis && user.driver_vehicle.axis.currentspeed <= 0 || !user.driver_vehicle.engine.on || user.driver_vehicle.fueltank.reagents.total_volume <= 0)
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
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
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
	var/obj/structure/engine/engine = null
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
	w_class = ITEM_SIZE_GARGANTUAN
	step = 1
	maxstep = 3
	targettype = /obj/structure/vehicle/motorcycle

/obj/item/vehicleparts/frame/boat
	name = "outrigger boat frame"
	desc = "a simple outrigger boat frame, with no engine or propulsion mode. Supports engines up to 400cc and fueltanks up to 150u"
	icon = 'icons/obj/vehicles/vehicleparts64x64.dmi'
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
			var/obj/structure/vehicle/boat/sailboat/N = new/obj/structure/vehicle/boat/sailboat(get_turf(user))
			N.name = name
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

///////////////////////EXTRA STUFF//////////////////////

/obj/item/sail
	name = "small sail"
	desc = "a small sail. Will fit a minor boat."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "sailing0"
	anchored = FALSE
	flammable = TRUE
	w_class = ITEM_SIZE_LARGE

/obj/item/tank_systems
	name = "Tank System"
	desc = "Base parent object, DO NOT USE."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "none"
	anchored = TRUE
	flammable = FALSE
	w_class = ITEM_SIZE_LARGE
	opacity = FALSE
	density = FALSE

/obj/item/tank_systems/ecms
	name = "ECMS"
	desc = "An Electromagnetic Counter-Mine System."
	New()
		..()
		spawn(5)
		explode_mines()

/obj/item/tank_systems/ecms/proc/explode_mines()
	if (src)
		for (var/obj/item/mine/M in range(5, src))
			if (M.anchored)
				M.trigger(src)
				for (var/mob/O in viewers(7, loc))
					O << "<font color='red'>\The [src] explodes the [M]!</font>"
		sleep(6 SECONDS)
		explode_mines()
	else return

/obj/item/tank_systems/iars
	name = "IARS"
	desc = "An Infrared Anti-Rocket System."
	New()
		..()
		spawn(5)
		explode_missiles()

/obj/item/tank_systems/iars/proc/explode_missiles()
	if (src)
		for (var/obj/item/missile/M in range(6, src))
			if (M)
				M.throw_impact(get_turf(M))
				for (var/mob/O in viewers(7, loc))
					O << "<font color='red'>\The [src] explodes the rocket!</font>"
		sleep(1 SECONDS)
		explode_missiles()
	else return
