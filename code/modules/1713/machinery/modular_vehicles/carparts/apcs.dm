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

//BMD-2

/obj/structure/vehicleparts/frame/bmd2
	icon = 'icons/obj/vehicles/apcparts.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts.dmi'

/obj/structure/vehicleparts/frame/bmd2/lf
	icon_state = "bmd2_frame_steel_front_left"
	w_front = list("bmd2_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/rf
	icon_state = "bmd2_frame_steel_front_right"
	w_front = list("bmd2_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/lfc
	icon_state = "bmd2_frame_steel_middle_front_left"
	w_left = list("bmd2_middle_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/rfc
	icon_state = "bmd2_frame_steel_middle_front_right"
	w_right = list("bmd2_middle_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/lbc
	icon_state = "bmd2_frame_steel_middle_back_left"
	w_left = list("bmd2_middle_back_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/rbc
	icon_state = "bmd2_frame_steel_middle_back_right"
	w_right = list("bmd2_middle_back_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/lb
	icon_state = "bmd2_frame_steel_back_left"
	w_back = list("bmd2_back_left_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2/rb
	icon_state = "bmd2_frame_steel_back_right"
	w_back = list("bmd2_back_right_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

//BMD-2 96x96

/obj/structure/vehicleparts/frame/bmd2new
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	broken_icon = 'icons/obj/vehicles/apcparts_damaged96x96.dmi'
	pixel_x = -32
	pixel_y = -32

/obj/structure/vehicleparts/frame/bmd2new/lf
	icon_state = "bmd2new_frame_steel_front_left"
	w_front = list("bmd2new_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2new/rf
	icon_state = "bmd2new_frame_steel_front_right"
	w_front = list("bmd2new_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2new/lc
	icon_state = "bmd2new_frame_steel_middle_left"
	w_left = list("bmd2new_middle_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2new/rc
	icon_state = "bmd2new_frame_steel_middle_right"
	w_right = list("bmd2new_middle_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2new/lb
	icon_state = "bmd2new_frame_steel_back_left"
	w_back = list("bmd2new_back_left_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/bmd2new/rb
	icon_state = "bmd2new_frame_steel_back_right"
	w_back = list("bmd2new_back_right_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

//BMD-2 96x96

/obj/structure/vehicleparts/frame/adrian
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	broken_icon = 'icons/obj/vehicles/apcparts_damaged96x96.dmi'
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