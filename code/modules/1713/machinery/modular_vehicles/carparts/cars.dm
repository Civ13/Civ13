//format: type of wall, opacity, density, armor, current health, can open/close, is open?, doesnt get colored
/obj/structure/bed/chair/drivers/car
	icon_state = "carseat_driver_left"
	material = "leather"
	New()
		..()
		material = get_material_by_name(material)
	update_icon()
		if (material)
			name = "[material] driver's seat"
			color = material.icon_colour
/obj/structure/bed/chair/carseat
	name = "car seat"
	desc = "a leather car seat."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "carseat_middle"
	material = "leather"
	New()
		..()
		material = get_material_by_name(material)
	update_icon()
		if (material)
			name = "[material.use_name] car seat"
			color = material.icon_colour

/obj/structure/bed/chair/carseat/left
	icon_state = "carseat_left"
/obj/structure/bed/chair/carseat/right
	icon_state = "carseat_right"

/obj/structure/bed/chair/drivers/car/lion
	material = "lionpelt"
/obj/structure/bed/chair/carseat/left/lion
	material = "lionpelt"
/obj/structure/bed/chair/carseat/right/lion
	material = "lionpelt"
/obj/structure/bed/chair/carseat/lion
	material = "lionpelt"

/obj/structure/bed/chair/drivers/car/dark
	material = "darkleather"
/obj/structure/bed/chair/carseat/left/dark
	material = "darkleather"
/obj/structure/bed/chair/carseat/right/dark
	material = "darkleather"
/obj/structure/bed/chair/carseat/dark
	material = "darkleather"
//truck
/obj/structure/vehicleparts/frame/car/newtruck/lf
	w_front = list("truckfront2_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newtruck/rf
	w_front = list("truckfront2_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newtruck/lwindshield
	w_left = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("truckwindshield_left",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newtruck/rwindshield
	w_right = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("truckwindshield_right",FALSE,TRUE,0,0.1,FALSE,FALSE)
//van
/obj/structure/vehicleparts/frame/car/van/lf
	w_front = list("vanfront_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanfront_left"
/obj/structure/vehicleparts/frame/car/van/cf
	w_front = list("vanfront_centerU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanfront_center"
/obj/structure/vehicleparts/frame/car/van/rf
	w_front = list("vanfront_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanfront_right"
/obj/structure/vehicleparts/frame/car/van/lfc
	w_front = list("vanwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,TRUE)
	hasoverlay = "vanwindshield2door_left"
/obj/structure/vehicleparts/frame/car/van/rfc
	w_front = list("vanwindshield2door_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,TRUE)
	hasoverlay = "vanwindshield2door_right"
/obj/structure/vehicleparts/frame/car/van/cfc
	w_front = list("truckwindshield_center",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/van/lb
	w_back = list("vanback_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanback_left"
/obj/structure/vehicleparts/frame/car/van/cb
	w_back = list("vanback_centerU",TRUE,TRUE,0,0.1,TRUE,TRUE)
	hasoverlay = "vanback_center"
/obj/structure/vehicleparts/frame/car/van/rb
	w_back = list("vanback_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanback_right"
//piccolino
/obj/structure/vehicleparts/frame/car/piccolino/lf
	w_front = list("as_piccolino_front_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/piccolino/rf
	w_front = list("as_piccolino_front_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/piccolino/lb
	w_back = list("carback3_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_front = list("carwindshield2_left",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback3_leftL"
/obj/structure/vehicleparts/frame/car/piccolino/rb
	w_back = list("carback3_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_front = list("carwindshield2_right",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback3_rightL"
//quattroporte
/obj/structure/vehicleparts/frame/car/quattroporte/lf
	w_front = list("as_quattroporte_front_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_quattroporte_front_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/quattroporte/rf
	w_front = list("as_quattroporte_front_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_quattroporte_front_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/quattroporte/lb
	w_back = list("as_quattroporte_back_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "as_quattroporte_back_left"
/obj/structure/vehicleparts/frame/car/quattroporte/rb
	w_back = list("as_quattroporte_back_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "as_quattroporte_back_right"
/obj/structure/vehicleparts/frame/car/quattroporte/lc
	w_front = list("carwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_left"
/obj/structure/vehicleparts/frame/car/quattroporte/rc
	w_front = list("carwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_right"
//erstenklasse
/obj/structure/vehicleparts/frame/car/umek/lf
	w_front = list("um_erstenklasse_front_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	removesroof = TRUE
	hasoverlay = "um_erstenklasse_front_left"
/obj/structure/vehicleparts/frame/car/umek/rf
	w_front = list("um_erstenklasse_front_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	removesroof = TRUE
	hasoverlay = "um_erstenklasse_front_right"
/obj/structure/vehicleparts/frame/car/umek/lfc
	w_front = list("carwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_left"
/obj/structure/vehicleparts/frame/car/umek/rfc
	w_front = list("carwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_right"
/obj/structure/vehicleparts/frame/car/umek/rbc
	w_right = list("c_windoweddoor",TRUE,TRUE,5,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/umek/lbc
	w_left = list("c_windoweddoor",TRUE,TRUE,5,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/umek/lb
	w_back = list("um_erstenklasse_back_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "um_erstenklasse_back_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/umek/rb
	w_back = list("um_erstenklasse_back_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "um_erstenklasse_back_right"
	removesroof = TRUE
/obj/structure/table/carboot
	name = "boot"
	desc = "A compartment of the car used to store stuff."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "frame_wood"
	fixedsprite = TRUE
	layer = 2.99
//falcon
/obj/structure/vehicleparts/frame/car/falcon/lf
	w_front = list("smc_falcon_front_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE,TRUE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "smc_falcon_front_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/falcon/rf
	w_front = list("smc_falcon_front_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE,TRUE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "smc_falcon_front_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/falcon/lfc
	w_front = list("carwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_left"
/obj/structure/vehicleparts/frame/car/falcon/rfc
	w_front = list("carwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_right"
/obj/structure/vehicleparts/frame/car/falcon/rbc
	w_right = list("c_windoweddoor",TRUE,TRUE,5,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/falcon/lbc
	w_left = list("c_windoweddoor",TRUE,TRUE,5,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/falcon/lb
	w_back = list("smc_falcon_back_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "smc_falcon_back_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/falcon/rb
	w_back = list("smc_falcon_back_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "smc_falcon_back_right"
	removesroof = TRUE
//shinobu
/obj/structure/vehicleparts/frame/car/shinobu/lf
	w_front = list("carfront5_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront5_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/rf
	w_front = list("carfront5_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront5_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/lb
	w_back = list("carback1_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback1_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/rb
	w_back = list("carback1_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback1_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/lc
	w_front = list("carwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carwindshield2door_left"
	noroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/rc
	w_front = list("carwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carwindshield2door_right"
	noroof = TRUE
//kazoku
/obj/structure/vehicleparts/frame/car/kazoku/lf
	w_front = list("carfront3_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront3_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/kazoku/rf
	w_front = list("carfront3_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront3_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/kazoku/lb
	w_back = list("ys_back_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "ys_back_left"
/obj/structure/vehicleparts/frame/car/kazoku/rb
	w_back = list("ys_back_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "ys_back_right"
/obj/structure/vehicleparts/frame/car/kazoku/lc
	w_front = list("carwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_left"
/obj/structure/vehicleparts/frame/car/kazoku/rc
	w_front = list("carwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_right"
///////////////axis///////////////
/obj/structure/vehicleparts/axis/car/piccolino
	name = "ASNO Piccolino"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 600
	speedlist = list(1=8,2=6,4=4.5,5=3.5)
	turntimer = 5

/obj/structure/vehicleparts/axis/car/quattroporte
	name = "ASNO Quattroporte"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 800
	speedlist = list(1=8,2=6,4=4.5,5=3.5)
	turntimer = 7

/obj/structure/vehicleparts/axis/car/erstenklasse
	name = "Ubermacht Erstenklasse"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 1100
	speedlist = list(1=7,2=6,3=5,4=4,5=3)
	turntimer = 8

/obj/structure/vehicleparts/axis/car/falcon
	name = "SMC Falcon"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 1000
	speedlist = list(1=7,2=6,3=5,4=2.5)
	turntimer = 7

/obj/structure/vehicleparts/axis/car/shinobu
	name = "Yamasaki Shinobu"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=6,2=5,3=4,4=3,5=2)
	turntimer = 7

/obj/structure/vehicleparts/axis/car/kazoku
	name = "Yamasaki Kazoku"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 800
	speedlist = list(1=6,2=5,3=4,4=3.5)
	turntimer = 8

/obj/structure/vehicleparts/axis/car/falcon/police
	name = "SMC Falcon Police Interceptor"
	color = "#383838"
	New()
		..()
		spawn(40)
			map.vehicle_registations += list(list("[reg_number]","Police", "SMC Falcon Police Interceptor", ""))


/obj/structure/vehicleparts/axis/car/volle
	name = "Ubermacht Volle"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 1200
	speedlist = list(1=8,2=6,3=5,4=4)
	turntimer = 9

/obj/structure/vehicleparts/axis/car/volle/ambulance
	name = "Ubermacht Volle KW Ambulance"
	color = "#FFFFFF"
	New()
		..()
		spawn(40)
			map.vehicle_registations += list(list("[reg_number]","Paramedics", "Ubermacht Volle KW Ambulance", ""))

/obj/structure/engine/internal/gasoline/ethanol/premade/piccolino
	enginesize = 2800

/obj/structure/engine/internal/gasoline/premade/quattroporte
	enginesize = 3000

/obj/structure/engine/internal/diesel/premade/erstenklasse
	enginesize = 5500

/obj/structure/engine/internal/diesel/premade/van
	enginesize = 7000

/obj/structure/engine/internal/gasoline/premade/falcon
	enginesize = 6500

/obj/structure/engine/internal/wankel/premade/shinobu
	enginesize = 5000

/obj/structure/engine/internal/gasoline/premade/kazoku
	enginesize = 3800

/obj/structure/emergency_lights
	name = "emergency lights control"
	desc = "controls the emergency lights and the wailing siren."
	icon = 'icons/obj/device.dmi'
	icon_state = "modern_intercom"
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	var/atype = "police"
	var/on = FALSE
	var/pol_color = "#FF0000"
	var/lastsoundcheck = 0
	layer = 6

/obj/structure/emergency_lights/attack_hand(mob/living/human/H)
	if (!ishuman(H))
		return
	on = !on
	if (on)
		check_color()
		check_sound()
	else
		set_light(0)
/obj/structure/emergency_lights/update_icon()
	switch(dir)
		if (EAST)
			pixel_x = 0
			pixel_y = -16

		if (WEST)
			pixel_x = 0
			pixel_y = 16

		if (NORTH)
			pixel_x = 16
			pixel_y = 0

		if (SOUTH)
			pixel_x = -16
			pixel_y = 0
/obj/structure/emergency_lights/proc/check_sound()
	if (world.realtime >= lastsoundcheck)
		if (on)
			playsound(loc,'sound/machines/police_siren.ogg',100,FALSE,15)
			lastsoundcheck = world.realtime+48
			spawn(50)
				check_sound()
/obj/structure/emergency_lights/proc/check_color()
	if (on)
		set_light(7,1,pol_color)
		spawn(5)
			if (pol_color == "#FF0000")
				pol_color = "#00FF00"
			else
				pol_color = "#FF0000"
			check_color()
	else
		set_light(0)

/obj/structure/emergency_lights/ambulance
	atype = "ambulance"
/obj/structure/emergency_lights/ambulance/check_sound()
	if (world.realtime >= lastsoundcheck)
		if (on)
			playsound(loc,'sound/machines/ambulance_siren.ogg',100,FALSE,15)
			lastsoundcheck = world.realtime+25
			spawn(27)
				check_sound()
/obj/structure/emergency_lights/ambulance/check_color()
	if (on)
		set_light(7,1,pol_color)
		spawn(5)
			if (pol_color == "#FF0000")
				pol_color = "#D3D3D3"
			else
				pol_color = "#FF0000"
			check_color()
	else
		set_light(0)
