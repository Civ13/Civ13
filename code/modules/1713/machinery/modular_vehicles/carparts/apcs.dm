//wall format (w_type var): type of wall, opacity, density, armor, current health, can open/close, is open?, doesnt get colored

/obj/structure/vehicleparts/frame/mtlb
	icon = 'icons/obj/vehicles/apcparts.dmi'
	normal_icon = 'icons/obj/vehicles/apcparts.dmi'

/obj/structure/vehicleparts/frame/mtlb/lf
	icon_state = "mtlb_frame_steel_front_left"
	w_front = list("mtlb_front_left_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "mtlb_front_left_roof"
	removesroof = TRUE
	override_frame_icon = "mtlb_front_left_frame"

/obj/structure/vehicleparts/frame/mtlb/rf
	icon_state = "mtlb_frame_steel_front_right"
	w_front = list("mtlb_front_right_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "mtlb_front_right_roof"
	removesroof = TRUE
	override_frame_icon = "mtlb_front_right_frame"

/obj/structure/vehicleparts/frame/mtlb/lfc
	icon_state = "mtlb_frame_steel_middle_left"
	w_left = list("mtlb_middle_front_left_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_frame_icon = "mtlb_middle_front_left_frame"
	override_roof_icon = "mtlb_middle_front_left_roof"
	removesroof = TRUE

/obj/structure/vehicleparts/frame/mtlb/rfc
	normal_icon = 'icons/obj/vehicles/apcparts.dmi'
	w_right = list("mtlb_middle_front_right_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_frame_icon = "mtlb_middle_front_right_frame"
	override_roof_icon = "mtlb_middle_front_right_roof"
	removesroof = TRUE

/obj/structure/vehicleparts/frame/mtlb/lbc
	icon_state = "mtlb_frame_steel_middle_left"
	w_left = list("mtlb_middle_back_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_frame_icon = "mtlb_middle_back_frame"
	override_roof_icon = "mtlb_middle_back_left_roof"
	removesroof = TRUE

/obj/structure/vehicleparts/frame/mtlb/rbc
	icon_state = "mtlb_frame_steel_middle_right"
	w_right = list("mtlb_middle_back_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_frame_icon = "mtlb_middle_back_frame"
	override_roof_icon = "mtlb_middle_back_right_roof"
	removesroof = TRUE

/obj/structure/vehicleparts/frame/mtlb/lb
	icon_state = "mtlb_frame_steel_back_left"
	w_back = list("mtlb_back_left_frame",TRUE,TRUE,50,50,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,50,50,FALSE,FALSE)
	override_frame_icon = "mtlb_back_left_frame"
	override_roof_icon = "mtlb_back_left_roof"
	removesroof = TRUE

/obj/structure/vehicleparts/frame/mtlb/rb
	icon_state = "mtlb_frame_steel_back_right"
	w_back = list("mtlb_back_right_frame",TRUE,TRUE,50,50,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,50,50,FALSE,FALSE)
	override_frame_icon = "mtlb_back_right_frame"
	override_roof_icon = "mtlb_back_right_roof"
	removesroof = TRUE
