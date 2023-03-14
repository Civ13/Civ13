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
/obj/structure/bed/chair/carseat/left/type95
	icon_state = "carseat_left_type95"
	applies_material_colour = FALSE
	material = null
/obj/structure/bed/chair/carseat/right/type95
	icon_state = "carseat_right_type95"
	applies_material_colour = FALSE
	material = null
/obj/structure/bed/chair/drivers/car/lion
	material = "lionpelt"
/obj/structure/bed/chair/carseat/left/lion
	material = "lionpelt"
/obj/structure/bed/chair/carseat/right/lion
	material = "lionpelt"
/obj/structure/bed/chair/carseat/lion
	material = "lionpelt"
/obj/structure/bed/chair/drivers/car/type95
	icon_state = "carseat_driver_right_type95"
/obj/structure/bed/chair/drivers/car/dark
	material = "darkleather"
/obj/structure/bed/chair/carseat/left/dark
	material = "darkleather"
/obj/structure/bed/chair/carseat/right/dark
	material = "darkleather"
/obj/structure/bed/chair/carseat/dark
	material = "darkleather"
//volle van
/obj/structure/vehicleparts/frame/car/van/lf
	w_front = list("vanfront_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanfront_left"
	icon_state = "frame_steel_corner_lf"
/obj/structure/vehicleparts/frame/car/van/cf
	w_front = list("vanfront_centerU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanfront_center"
	icon_state = "frame_steel_corner_cf"
/obj/structure/vehicleparts/frame/car/van/rf
	w_front = list("vanfront_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanfront_right"
	icon_state = "frame_steel_corner_rf"
/obj/structure/vehicleparts/frame/car/van/lfc
	w_front = list("vanwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "vanwindshield2door_left"
/obj/structure/vehicleparts/frame/car/van/rfc
	w_front = list("vanwindshield2door_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "vanwindshield2door_right"
/obj/structure/vehicleparts/frame/car/van/cfc
	w_front = list("truckwindshield_center",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/van/lb
	w_back = list("vanback_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanback_left"
	icon_state = "frame_steel_corner_lb"
/obj/structure/vehicleparts/frame/car/van/cb
	w_back = list("vanback_centerU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "vanback_center"
	icon_state = "frame_steel_corner_cb"
/obj/structure/vehicleparts/frame/car/van/rb
	w_back = list("vanback_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanback_right"
	icon_state = "frame_steel_corner_rb"
//piccolino
/obj/structure/vehicleparts/frame/car/piccolino/lf
	w_front = list("as_piccolino_front_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_piccolino_front_left"
	removesroof = TRUE
	icon_state = "frame_steel_corner_lf"
/obj/structure/vehicleparts/frame/car/piccolino/rf
	w_front = list("as_piccolino_front_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_piccolino_front_right"
	removesroof = TRUE
	icon_state = "frame_steel_corner_rf"
/obj/structure/vehicleparts/frame/car/piccolino/lb
	w_back = list("as_piccolino_back_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_front = list("c_thin",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_piccolino_back_left"
	icon_state = "frame_steel_corner_lb"
/obj/structure/vehicleparts/frame/car/piccolino/rb
	w_back = list("as_piccolino_back_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_front = list("c_thin",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_piccolino_back_right"
	icon_state = "frame_steel_corner_rb"
/obj/structure/vehicleparts/frame/car/piccolino/lc
	w_front = list("vanwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "vanwindshield2door_left"
/obj/structure/vehicleparts/frame/car/piccolino/rc
	w_front = list("vanwindshield2door_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "vanwindshield2door_right"
//quattroporte
/obj/structure/vehicleparts/frame/car/quattroporte/lf
	w_front = list("as_quattroporte_front_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_quattroporte_front_left"
	removesroof = TRUE
	icon_state = "frame_steel_corner_lf"
/obj/structure/vehicleparts/frame/car/quattroporte/rf
	w_front = list("as_quattroporte_front_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "as_quattroporte_front_right"
	removesroof = TRUE
	icon_state = "frame_steel_corner_rf"
/obj/structure/vehicleparts/frame/car/quattroporte/lb
	w_back = list("as_quattroporte_back_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "as_quattroporte_back_left"
	icon_state = "frame_steel_corner_lb"
/obj/structure/vehicleparts/frame/car/quattroporte/rb
	w_back = list("as_quattroporte_back_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "as_quattroporte_back_right"
	icon_state = "frame_steel_corner_rb"
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
	icon_state = "frame_steel_corner_lf"
/obj/structure/vehicleparts/frame/car/umek/rf
	w_front = list("um_erstenklasse_front_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	removesroof = TRUE
	icon_state = "frame_steel_corner_rf"
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
	icon_state = "frame_steel_corner_lb"
	w_back = list("um_erstenklasse_back_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "um_erstenklasse_back_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/umek/rb
	icon_state = "frame_steel_corner_rb"
	w_back = list("um_erstenklasse_back_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "um_erstenklasse_back_right"
	removesroof = TRUE
/obj/structure/table/carboot
	name = "boot"
	desc = "A compartment of the car used to store stuff."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "boot"
	fixedsprite = TRUE
	layer = 2.99
//falcon
/obj/structure/vehicleparts/frame/car/falcon/lf
	icon_state = "frame_steel_corner_lf"
	w_front = list("smc_falcon_front_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE,TRUE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "smc_falcon_front_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/falcon/rf
	icon_state = "frame_steel_corner_rf"
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
	icon_state = "frame_steel_corner_lb"
	w_back = list("smc_falcon_back_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "smc_falcon_back_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/falcon/rb
	icon_state = "frame_steel_corner_rb"
	w_back = list("smc_falcon_back_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "smc_falcon_back_right"
	removesroof = TRUE
//wyoming
/obj/structure/vehicleparts/frame/car/wyoming/lf
	icon_state = "frame_steel_corner_lf"
	w_front = list("truckfront2_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "truckfront2_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/wyoming/rf
	icon_state = "frame_steel_corner_rf"
	w_front = list("truckfront2_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "truckfront2_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/wyoming/lfc
	w_left = list("none",TRUE,TRUE,0,4,TRUE,FALSE)
	w_front = list("vanwindshield2door_leftU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanwindshield2door_left"
/obj/structure/vehicleparts/frame/car/wyoming/rfc
	w_right = list("none",TRUE,TRUE,0,4,TRUE,FALSE)
	w_front = list("vanwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "vanwindshield2door_right"

/obj/structure/vehicleparts/frame/car/wyoming/rbc
	w_right = list("c_wall",TRUE,TRUE,5,0.1,FALSE,FALSE)
	w_front = list("c_thin",TRUE,TRUE,1,0.1,FALSE,FALSE)
	noroof = TRUE
/obj/structure/vehicleparts/frame/car/wyoming/lbc
	w_left = list("c_wall",TRUE,TRUE,5,0.1,FALSE,FALSE)
	w_front = list("c_thin",TRUE,TRUE,1,0.1,FALSE,FALSE)
	noroof = TRUE
/obj/structure/vehicleparts/frame/car/wyoming/lb
	icon_state = "frame_steel_corner_lb"
	w_back = list("truckback_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback2_left"
	removesroof = TRUE
	override_roof_icon = "truckback_left_closed"
/obj/structure/vehicleparts/frame/car/wyoming/rb
	icon_state = "frame_steel_corner_rb"
	w_back = list("truckback_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carback2_right"
	removesroof = TRUE
	override_roof_icon = "truckback_right_closed"
//shinobu
/obj/structure/vehicleparts/frame/car/shinobu/lf
	w_front = list("carfront5_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	icon_state = "frame_steel_corner_lf"
	hasoverlay = "carfront5_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/rf
	w_front = list("carfront5_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	icon_state = "frame_steel_corner_rf"
	hasoverlay = "carfront5_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/lb
	w_back = list("carback1_leftU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	icon_state = "frame_steel_corner_lb"
	hasoverlay = "carback1_left"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/rb
	w_back = list("carback1_rightU",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	icon_state = "frame_steel_corner_rb"
	hasoverlay = "carback1_right"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/shinobu/lcf
	w_front = list("carwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_left"
/obj/structure/vehicleparts/frame/car/shinobu/rcf
	w_front = list("carwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_right"
/obj/structure/vehicleparts/frame/car/shinobu/rbc
	w_right = list("c_windoweddoor",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/shinobu/lbc
	w_left = list("c_windoweddoor",TRUE,TRUE,0,0.1,TRUE,FALSE)
	w_back = list("c_thin",TRUE,TRUE,0,0.1,FALSE,FALSE)
//kazoku
/obj/structure/vehicleparts/frame/car/kazoku/lf
	w_front = list("carfront3_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront3_left"
	icon_state = "frame_steel_corner_lf"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/kazoku/rf
	w_front = list("carfront3_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "carfront3_right"
	icon_state = "frame_steel_corner_rf"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/kazoku/lb
	w_back = list("ys_back_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "ys_back_left"
	icon_state = "frame_steel_corner_lb"
/obj/structure/vehicleparts/frame/car/kazoku/rb
	w_back = list("ys_back_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "ys_back_right"
	icon_state = "frame_steel_corner_rb"
/obj/structure/vehicleparts/frame/car/kazoku/lc
	w_front = list("carwindshield2door_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_left"
/obj/structure/vehicleparts/frame/car/kazoku/rc
	w_front = list("carwindshield2door_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "carwindshield2door_right"
/////////////////////TYPE95 Kurogane////////////
/obj/structure/vehicleparts/frame/car/type95/lf
	w_front = list("type95front_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "type95front_left"
	icon_state = "frame_steel_corner_lf_type95"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/type95/rf
	w_front = list("type95front_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "type95front_right"
	icon_state = "frame_steel_corner_rf_type95"
	removesroof = TRUE
/obj/structure/vehicleparts/frame/car/type95/lb
	w_back = list("type95_back_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "type95_back_left"
	icon_state = "frame_steel_corner_lb_type95"
/obj/structure/vehicleparts/frame/car/type95/rb
	w_back = list("type95_back_rightU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,FALSE,FALSE)
	hasoverlay = "type95_back_right"
	icon_state = "frame_steel_corner_rb_type95"
/obj/structure/vehicleparts/frame/car/type95/lc
	w_front = list("type95windshielddoor_leftU",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "type95windshielddoor_left"
	icon_state = "frame_steel_corner_clf_type95"
/obj/structure/vehicleparts/frame/car/type95/rc
	w_front = list("type95windshielddoor_rightU",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,0,0.1,TRUE,FALSE)
	hasoverlay = "type95windshielddoor_right"
	icon_state = "frame_steel_corner_crf_type95"
///////////////axis///////////////
/obj/structure/vehicleparts/axis/car/piccolino
	name = "ASNO Piccolino"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 700
	speedlist = list(1=8,2=6,3=4.5,4=3)
	turntimer = 5

/obj/structure/vehicleparts/axis/car/quattroporte
	name = "ASNO Quattroporte"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 800
	speedlist = list(1=7,2=5,3=3.5,4=2.5)
	turntimer = 7

/obj/structure/vehicleparts/axis/car/erstenklasse
	name = "Ubermacht Erstenklasse"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 1100
	speedlist = list(1=7,2=6,3=5,4=4,5=3)
	turntimer = 6

/obj/structure/vehicleparts/axis/car/falcon
	name = "SMC Falcon"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 1000
	speedlist = list(1=7,2=6,3=5,4=2)
	turntimer = 5

/obj/structure/vehicleparts/axis/car/falcon/police
	speeds = 5
	maxpower = 1000
	speedlist = list(1=7,2=6,3=5,4=3,5=2.5)
	turntimer = 4
	New()
		..()
		spawn(40)
		if (map.ID == MAP_THE_ART_OF_THE_DEAL)
			map.vehicle_registations += list(list("[reg_number]","Sheriff Office", "Unmarked SMC Falcon", ""))
			doorcode = 13443
		else
			map.vehicle_registations += list(list("[reg_number]","Police", "Unmarked SMC Falcon", ""))

/obj/structure/vehicleparts/axis/car/shinobu
	name = "Yamasaki Shinobu"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=5,2=4,3=3,4=2,5=1.2)
	turntimer = 4

/obj/structure/vehicleparts/axis/car/shinobu/police
	name = "Yamasaki Shinobu Police Interceptor"
	color = "#383838"
	New()
		..()
		spawn(40)
		if (map.ID == MAP_THE_ART_OF_THE_DEAL)
			map.vehicle_registations += list(list("[reg_number]","Sheriff Office", "Yamasaki Shinobu Police Interceptor", ""))
			doorcode = 13443
		else
			map.vehicle_registations += list(list("[reg_number]","Police", "Yamasaki Shinobu Police Interceptor", ""))

/obj/structure/vehicleparts/axis/car/kazoku
	name = "Yamasaki Kazoku"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 800
	speedlist = list(1=6,2=5,3=4,4=2.5)
	turntimer = 5
/obj/structure/vehicleparts/axis/car/type95
	name = "Kurogane Type 95"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=5,2=4,3=2.5,4=1.5,5=1)
	turntimer = 4

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
	speedlist = list(1=8,2=6.5,3=4.5,4=2.5)
	turntimer = 9

/obj/structure/vehicleparts/axis/car/wyoming
	name = "SMC Wyoming"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 1300
	speedlist = list(1=7,2=5.5,3=4.5,4=3)
	turntimer = 9

/obj/structure/vehicleparts/axis/car/daf
	name = "DAF YA-4442 Truck"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=10,2=6,3=4,4=3)
	turntimer = 8

/obj/structure/vehicleparts/axis/car/mercedes
	name = "Mercedes-Benz G280"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=10,2=5,3=4,4=3,5=2)
	turntimer = 8

/obj/structure/vehicleparts/axis/car/ba64
	name = "Ba-64 armored car"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=10,2=6,3=4,4=3)
	turntimer = 7
	reg_number = ""
	color = "#3d5931"
	turret_type = "none"
	vehicle_size = "2x3"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/car/t20komsomoletstractor
	name = "T-20 Komsomolets tractor"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=10,2=6,3=4,4=3,5=2)
	turntimer = 6
	reg_number = ""
	color = "#3d5931"
	turret_type = "none"
	vehicle_size = "2x4"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/car/unattr
	name = "UN Attack Vehicle"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 7
	maxpower = 1000
	speedlist = list(1=10,2=6,3=4,4=3)
	turntimer = 6
	reg_number = ""
	color = "#ffffff"
	turret_type = "none"
	vehicle_size = "2x4"
	New()
		..()
		var/pickedname = pick(tank_names_soviet)
		tank_names_soviet -= pickedname
		name = "[name] \'[pickedname]\'"

/obj/structure/vehicleparts/axis/car/kamaz
	name = "KamAZ-4350 Truck"
	desc = "A powered axis from a car."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 5
	maxpower = 800
	speedlist = list(1=10,2=6,3=4,4=3)
	turntimer = 8

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

/obj/structure/engine/internal/gasoline/premade/v6
	name = "V6 gasoline engine"
	enginesize = 7000

/obj/structure/engine/internal/gasoline/premade/mik
	name = "V12 Mikulin M-17T gasoline engine"
	enginesize = 15000

/obj/structure/engine/internal/diesel/premade/erstenklasse
	enginesize = 5500

/obj/structure/engine/internal/diesel/premade/wyoming
	enginesize = 8000

/obj/structure/engine/internal/diesel/premade/van
	enginesize = 7000

/obj/structure/engine/internal/diesel/premade/chiha
	enginesize = 25000

/obj/structure/engine/internal/gasoline/premade/falcon
	enginesize = 6500

/obj/structure/engine/internal/gasoline/wankel/premade/shinobu
	enginesize = 7000

/obj/structure/engine/internal/gasoline/premade/kazoku
	enginesize = 3800
/obj/structure/engine/internal/gasoline/premade/type95
	enginesize = 3800

/obj/structure/engine/internal/gasoline/premade/panzeriv
	enginesize = 12000

/obj/structure/engine/internal/gasoline/premade/panzervi
	enginesize = 25000

/obj/structure/engine/internal/diesel/premade/omw22_2
	name = "OMW 15 liter diesel engine"
	enginesize = 15000

/obj/structure/engine/internal/gasoline/premade/baf1_a
	name = "BAF 12 gasoline engine"
	enginesize = 12000

/obj/structure/engine/internal/diesel/premade/v12
	name = "V12 diesel engine"
	enginesize = 15000

/obj/structure/engine/internal/diesel/premade/v6
	name = "V6 diesel engine"
	enginesize = 8000

/obj/structure/engine/internal/diesel/premade/mtlb
	name = "YaMZ 238 diesel engine"
	enginesize = 15000

/obj/structure/engine/internal/diesel/premade/m113
	name = "Detroit 6V53T diesel engine"
	enginesize = 15000

/obj/structure/engine/internal/diesel/premade/bmd2
	name = "5D-20 15 diesel engine"
	enginesize = 15000

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
	var/obj/structure/vehicleparts/frame/control = null
	var/centered = FALSE
	layer = 6
/obj/structure/emergency_lights/New()
	..()
	spawn(20)
		for(var/obj/structure/vehicleparts/frame/F in loc)
			control = F
			break
		if (control)
			control.lights = src
			update_icon()
			control.update_icon()
/obj/structure/emergency_lights/attack_hand(mob/living/human/H)
	if (!ishuman(H))
		return
	if (map.ID == MAP_THE_ART_OF_THE_DEAL && (H.civilization != "Sheriff Office" && H.civilization != "Paramedics"))
		usr << "<span class ='warning'>You're not part of the emergency services.</span>"
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
			if (map.ID == MAP_DRUG_BUST || map.ID == MAP_BANK_ROBBERY)
				playsound(loc,'sound/machines/police_siren.ogg',100,FALSE,15)
				lastsoundcheck = world.realtime+55
				spawn(55)
					check_sound()
/obj/structure/emergency_lights/proc/check_color()
	if (on)
		set_light(7,1,pol_color)
		spawn(5)
			if (pol_color == "#FF0000")
				pol_color = "#0000FF"
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
			lastsoundcheck = world.realtime+11
			spawn(11)
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

/obj/structure/emergency_lights/police2
	atype = "police2"
	pol_color = "#0000FF"

/obj/structure/emergency_lights/police2/check_color()
	if (on)
		set_light(7,1,pol_color)
		spawn(5)
			if (pol_color == "#0000FF")
				pol_color = "#D3D3D3"
			else
				pol_color = "#0000FF"
			check_color()
	else
		set_light(0)