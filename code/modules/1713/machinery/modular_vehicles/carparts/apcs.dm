//wall format (w_type var): type of wall, opacity, density, armor, current health, can open/close, is open?, doesnt get colored

//MT-LB

/obj/structure/vehicleparts/frame/mtlb
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	pixel_x = -32
	pixel_y = -32

/obj/structure/vehicleparts/frame/mtlb/lf
	icon_state = "mtlb_frame_steel_front_left"
	w_front = list("mtlb_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/mtlb/rf
	icon_state = "mtlb_frame_steel_front_right"
	w_front = list("mtlb_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/mtlb/lfc
	icon_state = "mtlb_frame_steel_middle_front_left"
	w_left = list("mtlb_middle_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/mtlb/rfc
	icon_state = "mtlb_frame_steel_middle_front_right"
	w_right = list("mtlb_middle_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/mtlb/lbc
	icon_state = "mtlb_frame_steel_middle_back_left"
	w_left = list("mtlb_middle_back_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/mtlb/rbc
	icon_state = "mtlb_frame_steel_middle_back_right"
	w_right = list("mtlb_middle_back_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/mtlb/lb
	icon_state = "mtlb_frame_steel_back_left"
	w_back = list("mtlb_back_left_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/mtlb/rb
	icon_state = "mtlb_frame_steel_back_right"
	w_back = list("mtlb_back_right_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

//M113

/obj/structure/vehicleparts/frame/m113
	icon = 'icons/obj/vehicles/apcparts.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts.dmi'

/obj/structure/vehicleparts/frame/m113/lf
	icon_state = "m113_frame_steel_front_left"
	w_front = list("m113_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/rf
	icon_state = "m113_frame_steel_front_right"
	w_front = list("m113_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/lfc
	icon_state = "m113_frame_steel_middle_front_left"
	w_left = list("m113_middle_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/rfc
	icon_state = "m113_frame_steel_middle_front_right"
	w_right = list("m113_middle_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/lbc
	icon_state = "m113_frame_steel_middle_back_left"
	w_left = list("m113_middle_back_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/rbc
	icon_state = "m113_frame_steel_middle_back_right"
	w_right = list("m113_middle_back_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/lb
	icon_state = "m113_frame_steel_back_left"
	w_back = list("m113_back_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/rb
	icon_state = "m113_frame_steel_back_right"
	w_back = list("m113_back_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/front
	icon_state = "m113_frame_steel_front_middle"
	w_front = list("m113_front_middle_frame",TRUE,TRUE,40,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m113/fc
	icon_state = "m113_frame_steel_middle_front"

/obj/structure/vehicleparts/frame/m113/bc
	icon_state = "m113_frame_steel_middle_back"

/obj/structure/vehicleparts/frame/m113/back
	icon_state = "m113_frame_steel_back"
	w_back = list("m113_front_middle_frame",TRUE,TRUE,40,50,TRUE,TRUE)

//BMD-2 96x96

/obj/structure/vehicleparts/frame/bmd2
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	// broken_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	pixel_x = -32
	pixel_y = -32

/obj/structure/vehicleparts/frame/bmd2/lf
	icon_state = "bmd2new_frame_steel_front_left"
	w_front = list("bmd2new_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/rf
	icon_state = "bmd2new_frame_steel_front_right"
	w_front = list("bmd2new_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/lc
	icon_state = "bmd2new_frame_steel_middle_left"
	w_left = list("bmd2new_middle_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/rc
	icon_state = "bmd2new_frame_steel_middle_right"
	w_right = list("bmd2new_middle_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/lb
	icon_state = "bmd2new_frame_steel_back_left"
	w_back = list("bmd2new_back_left_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/rb
	icon_state = "bmd2new_frame_steel_back_right"
	w_back = list("bmd2new_back_right_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

//Campaign 96x96

/obj/structure/vehicleparts/frame/adrian
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	broken_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	pixel_x = -32
	pixel_y = -32

/obj/structure/vehicleparts/frame/adrian/lf
	icon_state = "bmd2new_frame_steel_front_left"
	w_front = list("bmd2new_front_left_frame",TRUE,TRUE,40,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/adrian/rf
	icon_state = "bmd2new_frame_steel_front_right"
	w_front = list("bmd2new_front_right_frame",TRUE,TRUE,40,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/adrian/lc
	icon_state = "bmd2new_frame_steel_middle_left"
	w_left = list("bmd2new_middle_left_frame",TRUE,TRUE,30,40,FALSE,FALSE)

/obj/structure/vehicleparts/frame/adrian/rc
	icon_state = "bmd2new_frame_steel_middle_right"
	w_right = list("bmd2new_middle_right_frame",TRUE,TRUE,30,40,FALSE,FALSE)

/obj/structure/vehicleparts/frame/adrian/lb
	icon_state = "bmd2new_frame_steel_back_left"
	w_back = list("bmd2new_back_left_frame",TRUE,TRUE,25,30,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,30,40,FALSE,FALSE)

/obj/structure/vehicleparts/frame/adrian/rb
	icon_state = "bmd2new_frame_steel_back_right"
	w_back = list("bmd2new_back_right_frame",TRUE,TRUE,25,30,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,30,40,FALSE,FALSE)


//BTR-80 96x96

/obj/structure/vehicleparts/frame/btr80
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	// broken_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	pixel_x = -32
	pixel_y = -32

/obj/structure/vehicleparts/frame/btr80/lf
	icon_state = "btr80_frame_steel_front_left"
	w_front = list("btr80_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/btr80/rf
	icon_state = "btr80_frame_steel_front_right"
	w_front = list("btr80_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/btr80/lfc
	icon_state = "btr80_frame_steel_middle_front_left"
	w_left = list("btr80_middle_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/btr80/rfc
	icon_state = "btr80_frame_steel_middle_front_right"
	w_right = list("btr80_middle_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/btr80/lbc
	icon_state = "btr80_frame_steel_middle_back_left"
	w_left = list("btr80_middle_back_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/btr80/rbc
	icon_state = "btr80_frame_steel_middle_back_right"
	w_right = list("btr80_middle_back_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/btr80/lb
	icon_state = "btr80_frame_steel_back_left"
	w_back = list("btr80_back_left_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/btr80/rb
	icon_state = "btr80_frame_steel_back_right"
	w_back = list("btr80_back_right_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)



/obj/structure/vehicleparts/frame/cv90
	icon = 'icons/obj/vehicles/tankparts.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts.dmi'

/obj/structure/vehicleparts/frame/cv90/lf
	w_front = list("mt_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_front_left_roof"
	override_frame_icon = "mt_front_left_frame"

/obj/structure/vehicleparts/frame/cv90/rf
	w_front = list("mt_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_front_right_roof"
	override_frame_icon = "mt_front_right_frame"

/obj/structure/vehicleparts/frame/cv90/lfc
	w_left = list("mt_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_left_roof"
	override_frame_icon = "mt_left_frame"

/obj/structure/vehicleparts/frame/cv90/rfc
	w_right = list("mt_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_right_roof"
	override_frame_icon = "mt_right_frame"

/obj/structure/vehicleparts/frame/cv90/lbc
	w_left = list("mt_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_front_left_roof"
	override_frame_icon = "mt_front_left_frame"

/obj/structure/vehicleparts/frame/cv90/rbc
	w_right = list("mt_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_front_right_roof"
	override_frame_icon = "mt_front_right_frame"

/obj/structure/vehicleparts/frame/cv90/lb
	w_back = list("mt_back_left_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_left = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_back_left_roof"
	override_frame_icon = "mt_back_left_frame"

/obj/structure/vehicleparts/frame/cv90/rb
	w_back = list("mt_right_back_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_right = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	override_roof_icon = "mt_back_right_roof"
	override_frame_icon = "mt_back_right_frame"