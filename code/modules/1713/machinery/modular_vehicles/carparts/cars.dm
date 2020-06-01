/obj/structure/bed/chair/drivers/car
	icon_state = "carseat_driver_left"
	material = "leather"
	New()
		..()
		material = get_material_by_name(material)
	update_icon()
		if (material)
			color = material.icon_colour
/obj/structure/bed/chair/carseat
	name = "car seat"
	desc = "a leather car seat."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "carseat_middle"
	material = "leather"
	New()
		..()
		material = get_material_by_name(material)
	update_icon()
		if (material)
			color = material.icon_colour

/obj/structure/bed/chair/carseat/left
	icon_state = "carseat_left"
/obj/structure/bed/chair/carseat/right
	icon_state = "carseat_right"

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

//jeep
/obj/structure/vehicleparts/frame/car/jeep/lf
	w_front = list("carfront_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/jeep/rf
	w_front = list("carfront_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/jeep/lwindshield
	w_left = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("carwindshield_left",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/jeep/rwindshield
	w_right = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("carwindshield_right",FALSE,TRUE,0,0.1,FALSE,FALSE)

//model 2 car
/obj/structure/vehicleparts/frame/car/newcar2/lf
	w_front = list("carfront2_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newcar2/rf
	w_front = list("carfront2_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newcar2/lwindshield
	w_left = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("carwindshield2_left",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newcar2/rwindshield
	w_right = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("carwindshield2_right",FALSE,TRUE,0,0.1,FALSE,FALSE)

//model 3 car
/obj/structure/vehicleparts/frame/car/newcar3/lf
	w_front = list("carfront3_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newcar3/rf
	w_front = list("carfront3_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

//model 5 car
/obj/structure/vehicleparts/frame/car/newcar5/lf
	w_front = list("carfront5_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront5_left"
/obj/structure/vehicleparts/frame/car/newcar5/rf
	w_front = list("carfront5_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront5_right"

//jeep 2
/obj/structure/vehicleparts/frame/car/newcar4/lf
	w_front = list("carfront4_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/newcar4/rf
	w_front = list("carfront4_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

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

//piccolino
/obj/structure/vehicleparts/frame/car/piccolino/lf
	w_front = list("as_piccolino_front_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/piccolino/rf
	w_front = list("as_piccolino_front_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/piccolino/lb
	w_back = list("carback3_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_front = list("carwindshield2_left",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback3_left"
/obj/structure/vehicleparts/frame/car/piccolino/rb
	w_back = list("carback3_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_front = list("carwindshield2_right",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback3_right"
//erstenklasse
/obj/structure/vehicleparts/frame/car/umek/lf
	w_front = list("um_erstenklasse_front_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/umek/rf
	w_front = list("um_erstenklasse_front_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
//falcon
/obj/structure/vehicleparts/frame/car/falcon/lf
	w_front = list("smc_falcon_front_left",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/falcon/rf
	w_front = list("smc_falcon_front_right",TRUE,TRUE,0,0.1,FALSE,FALSE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
////////////////backs////////////////
//car
/obj/structure/vehicleparts/frame/car/newcar1/lb
	w_back = list("carback1_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback1_left"

/obj/structure/vehicleparts/frame/car/newcar1/rb
	w_back = list("carback1_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback1_right"

//car 2
/obj/structure/vehicleparts/frame/car/newcar2/lb
	w_back = list("carback2_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback2_left"

/obj/structure/vehicleparts/frame/car/newcar2/rb
	w_back = list("carback2_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback2_right"

///////////////axis///////////////
/obj/structure/vehicleparts/axis/car/piccolino
	name = "ASNO Piccolino"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 800
	speedlist = list(1=8,2=6,3=4,4=3)
	turntimer = 7

/obj/structure/vehicleparts/axis/car/quattroporte
	name = "ASNO Quattroporte"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=8,2=6,3=4,4=3,5=2)
	turntimer = 8

/obj/structure/engine/internal/gasoline/premade/piccolino
	enginesize = 2800

/obj/structure/engine/internal/gasoline/premade/quattroporte
	enginesize = 4000