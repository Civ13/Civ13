//wall format (w_type var): type of wall, opacity, density, armor, current health, can open/close, is open?, doesnt get colored

//tanks

/obj/structure/vehicleparts/frame/panzervi

/obj/structure/vehicleparts/frame/panzervi/front
	w_front = list("c_armoredwall",FALSE,TRUE,102,130,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/back
	w_back = list("c_wall",TRUE,TRUE,50,70,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/left
	w_left = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/right
	w_right = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/back/door
	w_back = list("c_door",TRUE,TRUE,45,50,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/panzervi/rb
	w_right = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,50,70,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/lb
	w_left = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,50,70,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/rf
	w_right = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_front = list("c_armoredfront2",FALSE,TRUE,102,130,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/lf
	w_left = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_front = list("c_armoredfront2",FALSE,TRUE,102,130,FALSE,FALSE)

/obj/structure/vehicleparts/frame/panzeriv

/obj/structure/vehicleparts/frame/panzeriv/front
	w_front = list("c_wall",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/back
	w_back = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/left
	w_left = list("c_wall",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/right
	w_right = list("c_wall",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/left/door
	w_left = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/panzeriv/right/door
	w_right = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/panzeriv/rb
	w_right = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/lb
	w_left = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/rf
	w_right = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/lf
	w_left = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,45,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/t34
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	pixel_x = -32
	pixel_y = -32
/obj/structure/vehicleparts/frame/t34/front
	icon_state = "t34_frame_steel_front_middle"
	w_front = list("t34_front_middle_frame",TRUE,TRUE,50,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/back
	icon_state = "t34_frame_steel_back"
	w_back = list("t34_back_middle_frame",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/left
	icon_state = "t34_frame_steel_middle_front_left"
	w_left = list("t34_middle_front_left_frame",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/fc
	icon_state = "t34_frame_steel_middle_front"
/obj/structure/vehicleparts/frame/t34/right
	icon_state = "t34_frame_steel_middle_front_right"
	w_right = list("t34_middle_front_right_frame",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/left/door
	icon_state = "t34_frame_steel_middle_back_left"
	w_left = list("t34_middle_back_left_frame",TRUE,TRUE,45,50,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t34/bc
	icon_state = "t34_frame_steel_middle_back"
/obj/structure/vehicleparts/frame/t34/right/door
	icon_state = "t34_frame_steel_middle_back_right"
	w_right = list("t34_middle_back_right_frame",TRUE,TRUE,45,50,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t34/rb
	icon_state = "t34_frame_steel_back_right"
	w_back = list("t34_back_right_frame",TRUE,TRUE,45,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/lb
	icon_state = "t34_frame_steel_back_left"
	w_back = list("t34_back_left_frame",TRUE,TRUE,45,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/rf
	icon_state = "t34_frame_steel_front_right"
	w_front = list("t34_front_right_frame",TRUE,TRUE,120,120,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/lf
	icon_state = "t34_frame_steel_front_left"
	w_front = list("t34_front_left_frame",TRUE,TRUE,120,120,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,45,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/su85

/obj/structure/vehicleparts/frame/su85/front
	w_front = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su85/back
	w_back = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su85/left
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su85/right
	w_right = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su85/right/door
	w_right = list("c_door",TRUE,TRUE,30,30,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/su85/rb
	w_right = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su85/lb
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su85/rf
	w_right = list("c_wall",TRUE,TRUE,40,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su85/lf
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,40,40,FALSE,FALSE)

/obj/structure/vehicleparts/frame/sdfkzfront

/obj/structure/vehicleparts/frame/sdfkzfront/lf
	w_left = list("c_wall",TRUE,TRUE,15,15,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,15,15,FALSE,FALSE)
/obj/structure/vehicleparts/frame/sdfkzfront/rf
	w_right = list("c_wall",TRUE,TRUE,15,15,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,15,15,FALSE,FALSE)
/obj/structure/vehicleparts/frame/sdfkzfront/right
	w_right = list("c_wall",TRUE,TRUE,15,15,FALSE,FALSE)
/obj/structure/vehicleparts/frame/sdfkzfront/right/door
	w_right = list("c_door",TRUE,TRUE,15,15,TRUE,TRUE)
	doorcode = 11940

/obj/structure/vehicleparts/frame/t20

/obj/structure/vehicleparts/frame/t20/lf
	w_left = list("c_wall",TRUE,TRUE,20,20,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t20/rf
	w_right = list("c_wall",TRUE,TRUE,20,20,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,20,20,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t20/leftm
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon_state = "frame_steel"
	flammable = TRUE
	resistance = 150
	noroof = FALSE
	w_left = list("c_wall",TRUE,TRUE,15,15,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t20/rightm
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon_state = "frame_steel"
	flammable = TRUE
	resistance = 150
	noroof = FALSE
	w_right = list("c_door",TRUE,TRUE,30,30,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t20/frontlback
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 120
	noroof = TRUE
	w_front = list("c_wall",TRUE,TRUE,20,20,FALSE,FALSE)
	w_right = list("c_door",TRUE,TRUE,15,15,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t20/frontrback
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 120
	noroof = TRUE
	w_front = list("c_wall",TRUE,TRUE,20,20,FALSE,FALSE)
	w_left = list("c_door",TRUE,TRUE,15,15,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t20/backl
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 120
	noroof = TRUE
	w_back = list("c_wall",TRUE,TRUE,15,15,FALSE,FALSE)
	w_right = list("c_door",TRUE,TRUE,15,15,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t20/backr
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 120
	noroof = TRUE
	w_back = list("c_wall",TRUE,TRUE,15,15,FALSE,FALSE)
	w_left = list("c_door",TRUE,TRUE,15,15,TRUE,TRUE)
	doorcode = 4975

/obj/structure/vehicleparts/frame/bt7

/obj/structure/vehicleparts/frame/bt7/front
	w_front = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bt7/back
	w_back = list("c_wall",TRUE,TRUE,25,25,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bt7/left
	w_left = list("c_wall",TRUE,TRUE,25,25,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bt7/right
	w_right = list("c_wall",TRUE,TRUE,25,25,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bt7/left/door
	w_left = list("c_door",TRUE,TRUE,15,15,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/bt7/right/door
	w_right = list("c_door",TRUE,TRUE,15,15,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/bt7/rb
	w_right = list("c_wall",TRUE,TRUE,25,25,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,25,25,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bt7/lb
	w_left = list("c_wall",TRUE,TRUE,25,25,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,25,25,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bt7/rf
	w_right = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bt7/lf
	w_left = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,30,30,FALSE,FALSE)

/obj/structure/vehicleparts/frame/unattr

/obj/structure/vehicleparts/frame/unattr/lf
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/unattr/rf
	w_right = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/unattr/leftm
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon_state = "frame_steel"
	flammable = TRUE
	resistance = 150
	noroof = FALSE
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/unattr/rightm
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon_state = "frame_steel"
	flammable = TRUE
	resistance = 150
	noroof = FALSE
	w_right = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/unattr/frontlback
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = FALSE
	resistance = 140
	noroof = TRUE
	w_front = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_right = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	w_left = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/unattr/frontrback
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = FALSE
	resistance = 140
	noroof = TRUE
	w_front = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_left = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	w_right = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/unattr/backl
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 140
	noroof = TRUE
	w_back = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_right = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	w_left = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/unattr/backr
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 140
	noroof = TRUE
	w_back = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_right = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	w_left = list("c_door",TRUE,TRUE,40,40,TRUE,TRUE)
	doorcode = 4975

/obj/structure/vehicleparts/frame/kv1

/obj/structure/vehicleparts/frame/kv1/front
	w_front = list("c_wall",TRUE,TRUE,75,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/kv1/back
	w_back = list("c_wall",TRUE,TRUE,25,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/kv1/left
	w_left = list("c_wall",TRUE,TRUE,45,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/kv1/right
	w_right = list("c_wall",TRUE,TRUE,45,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/kv1/left/door
	w_left = list("c_door",TRUE,TRUE,35,28,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/kv1/right/door
	w_right = list("c_door",TRUE,TRUE,35,28,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/kv1/rb
	w_right = list("c_wall",TRUE,TRUE,30,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,25,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/kv1/lb
	w_left = list("c_wall",TRUE,TRUE,30,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,25,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/kv1/rf
	w_right = list("c_wall",TRUE,TRUE,60,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,75,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/kv1/lf
	w_left = list("c_wall",TRUE,TRUE,60,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,75,50,FALSE,FALSE)


/obj/structure/vehicleparts/frame/i_go

/obj/structure/vehicleparts/frame/i_go/front
	w_front = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/back
	w_back = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/left
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/right
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/left/door
	w_left = list("c_door",TRUE,TRUE,17,50,TRUE,FALSE)
	doorcode = 5970
/obj/structure/vehicleparts/frame/i_go/right/door
	w_right = list("c_door",TRUE,TRUE,17,50,TRUE,FALSE)
	doorcode = 5970
/obj/structure/vehicleparts/frame/i_go/rb
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/lb
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/rf
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/lf
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,17,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/chi_ha

/obj/structure/vehicleparts/frame/chi_ha/front
	w_front = list("c_wall",TRUE,TRUE,25,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/chi_ha/back
	w_back = list("c_wall",TRUE,TRUE,10,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/chi_ha/left
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/chi_ha/right
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/chi_ha/left/door
	w_left = list("c_door",TRUE,TRUE,17,50,TRUE,FALSE)
	doorcode = 5970
/obj/structure/vehicleparts/frame/chi_ha/right/door
	w_right = list("c_door",TRUE,TRUE,17,50,TRUE,FALSE)
	doorcode = 5970
/obj/structure/vehicleparts/frame/chi_ha/rb
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,10,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/chi_ha/lb
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,10,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/chi_ha/rf
	w_right = list("c_wall",TRUE,TRUE,25,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,25,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/chi_ha/lf
	w_left = list("c_wall",TRUE,TRUE,25,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,25,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/m4
/obj/structure/vehicleparts/frame/m4/front
	w_front = list("c_wall",TRUE,TRUE,30,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/m4/back
	w_back = list("c_wall",TRUE,TRUE,15,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/m4/left

	w_left = list("c_wall",TRUE,TRUE,20,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/m4/right
	w_right = list("c_wall",TRUE,TRUE,20,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/m4/left/door
	w_left = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 9950
/obj/structure/vehicleparts/frame/m4/right/door
	w_right = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 9950
/obj/structure/vehicleparts/frame/m4/rb
	w_right = list("c_wall",TRUE,TRUE,20,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,15,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/m4/lb
	w_left = list("c_wall",TRUE,TRUE,20,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,15,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/m4/rf
	w_right = list("c_wall",TRUE,TRUE,30,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,30,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/m4/lf
	w_left = list("c_wall",TRUE,TRUE,30,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,30,50,FALSE,FALSE)


// T-90A

/obj/structure/vehicleparts/frame/t90a
	icon = 'icons/obj/vehicles/tankparts.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts.dmi'

/obj/structure/vehicleparts/frame/t90a/front
	w_front = list("mt_front_frame",TRUE,TRUE,100,100,FALSE,FALSE)
	override_roof_icon = "mt_front_roof"
	override_frame_icon = "mt_front_frame"
/obj/structure/vehicleparts/frame/t90a/back
	w_back = list("mt_back_frame",TRUE,TRUE,40,40,FALSE,FALSE)
	override_roof_icon = "mt_back_roof"
	override_frame_icon = "mt_back_frame"

/obj/structure/vehicleparts/frame/t90a/left
	w_left = list("mt_left_frame",TRUE,TRUE,80,80,FALSE,FALSE)
	override_roof_icon = "mt_left_roof"
	override_frame_icon = "mt_left_frame"
/obj/structure/vehicleparts/frame/t90a/left/door
	w_left = list("mt_left_door_frame",TRUE,TRUE,80,30,TRUE,TRUE)
	// doorcode = 668643
	override_roof_icon = "mt_left_door_roof"
	override_frame_icon = "mt_left_door_frame"
/obj/structure/vehicleparts/frame/t90a/right
	w_right = list("mt_right_frame",TRUE,TRUE,80,80,FALSE,FALSE)
	override_roof_icon = "mt_right_roof"
	override_frame_icon = "mt_right_frame"
/obj/structure/vehicleparts/frame/t90a/right/door
	w_right = list("mt_right_door_frame",TRUE,TRUE,80,30,TRUE,TRUE)
	// doorcode = 668643
	override_roof_icon = "mt_right_door_roof"
	override_frame_icon = "mt_right_door_frame"

/obj/structure/vehicleparts/frame/t90a/rb
	w_right = list("c_wall",TRUE,TRUE,80,80,FALSE,FALSE)
	w_back = list("mt_right_back_frame",TRUE,TRUE,40,40,FALSE,FALSE)
	override_roof_icon = "mt_back_right_roof"
	override_frame_icon = "mt_back_right_frame"
/obj/structure/vehicleparts/frame/t90a/lb
	w_left = list("c_wall",TRUE,TRUE,80,80,FALSE,FALSE)
	w_back = list("mt_back_left_frame",TRUE,TRUE,40,40,FALSE,FALSE)
	override_roof_icon = "mt_back_left_roof"
	override_frame_icon = "mt_back_left_frame"

/obj/structure/vehicleparts/frame/t90a/rf
	w_right = list("c_wall",TRUE,TRUE,80,80,FALSE,FALSE)
	w_front = list("mt_front_right_frame",TRUE,TRUE,100,100,FALSE,FALSE)
	override_roof_icon = "mt_front_right_roof"
	override_frame_icon = "mt_front_right_frame"
/obj/structure/vehicleparts/frame/t90a/lf
	w_left = list("c_wall",TRUE,TRUE,80,80,FALSE,FALSE)
	w_front = list("mt_front_left_frame",TRUE,TRUE,100,100,FALSE,FALSE)
	override_roof_icon = "mt_front_left_roof"
	override_frame_icon = "mt_front_left_frame"


// T-72 (technically the T-72A)

/obj/structure/vehicleparts/frame/t72
	icon = 'icons/obj/vehicles/tankparts.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts.dmi'

/obj/structure/vehicleparts/frame/t72/front
	w_front = list("mt_front_frame",TRUE,TRUE,120,120,FALSE,FALSE)
	override_roof_icon = "mt_front_roof"
	override_frame_icon = "mt_front_frame"
/obj/structure/vehicleparts/frame/t72/back
	w_back = list("mt_back_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "mt_back_roof"
	override_frame_icon = "mt_back_frame"
	
/obj/structure/vehicleparts/frame/t72/left
	w_left = list("mt_left_frame",TRUE,TRUE,90,90,FALSE,FALSE)
	override_roof_icon = "mt_left_roof"
	override_frame_icon = "mt_left_frame"
/obj/structure/vehicleparts/frame/t72/left/door
	w_left = list("mt_left_door_frame",TRUE,TRUE,90,30,TRUE,TRUE)
	// doorcode = 668643
	override_roof_icon = "mt_left_door_roof"
	override_frame_icon = "mt_left_door_frame"
/obj/structure/vehicleparts/frame/t72/right
	w_right = list("mt_right_frame",TRUE,TRUE,90,90,FALSE,FALSE)
	override_roof_icon = "mt_right_roof"
	override_frame_icon = "mt_right_frame"
/obj/structure/vehicleparts/frame/t72/right/door
	w_right = list("mt_right_door_frame",TRUE,TRUE,90,30,TRUE,TRUE)
	// doorcode = 668643
	override_roof_icon = "mt_right_door_roof"
	override_frame_icon = "mt_right_door_frame"

/obj/structure/vehicleparts/frame/t72/rb
	w_right = list("c_wall",TRUE,TRUE,90,90,FALSE,FALSE)
	w_back = list("mt_right_back_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "mt_back_right_roof"
	override_frame_icon = "mt_back_right_frame"
/obj/structure/vehicleparts/frame/t72/lb
	w_left = list("c_wall",TRUE,TRUE,90,90,FALSE,FALSE)
	w_back = list("mt_back_left_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "mt_back_left_roof"
	override_frame_icon = "mt_back_left_frame"

/obj/structure/vehicleparts/frame/t72/rf
	w_right = list("c_wall",TRUE,TRUE,90,90,FALSE,FALSE)
	w_front = list("mt_front_right_frame",TRUE,TRUE,120,120,FALSE,FALSE)
	override_roof_icon = "mt_front_right_roof"
	override_frame_icon = "mt_front_right_frame"
/obj/structure/vehicleparts/frame/t72/lf
	w_left = list("c_wall",TRUE,TRUE,120,120,FALSE,FALSE)
	w_front = list("mt_front_left_frame",TRUE,TRUE,120,120,FALSE,FALSE)
	override_roof_icon = "mt_front_left_roof"
	override_frame_icon = "mt_front_left_frame"


// Leopard 2a6

/obj/structure/vehicleparts/frame/leopard
	icon = 'icons/obj/vehicles/tankparts.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts.dmi'

/obj/structure/vehicleparts/frame/leopard/front
	w_front = list("mt_front_frame",TRUE,TRUE,250,250,FALSE,FALSE)
	override_roof_icon = "mt_front_roof"
	override_frame_icon = "mt_front_frame"
/obj/structure/vehicleparts/frame/leopard/back
	w_back = list("mt_back_frame",TRUE,TRUE,20,20,FALSE,FALSE)
	override_roof_icon = "mt_back_roof"
	override_frame_icon = "mt_back_frame"

/obj/structure/vehicleparts/frame/leopard/left
	w_left = list("mt_left_frame",TRUE,TRUE,35,35,FALSE,FALSE)
	override_roof_icon = "mt_left_roof"
	override_frame_icon = "mt_left_frame"
/obj/structure/vehicleparts/frame/leopard/left/door
	w_left = list("mt_left_door_frame",TRUE,TRUE,35,30,TRUE,TRUE)
	// doorcode = 668643
	override_roof_icon = "mt_left_door_roof"
	override_frame_icon = "mt_left_door_frame"
/obj/structure/vehicleparts/frame/leopard/right
	w_right = list("mt_right_frame",TRUE,TRUE,35,35,FALSE,FALSE)
	override_roof_icon = "mt_right_roof"
	override_frame_icon = "mt_right_frame"
/obj/structure/vehicleparts/frame/leopard/right/door
	w_right = list("mt_right_door_frame",TRUE,TRUE,35,30,TRUE,TRUE)
	// doorcode = 668643
	override_roof_icon = "mt_right_door_roof"
	override_frame_icon = "mt_right_door_frame"

/obj/structure/vehicleparts/frame/leopard/rb
	w_right = list("c_wall",TRUE,TRUE,35,35,FALSE,FALSE)
	w_back = list("mt_right_back_frame",TRUE,TRUE,20,20,FALSE,FALSE)
	override_roof_icon = "mt_back_right_roof"
	override_frame_icon = "mt_back_right_frame"
/obj/structure/vehicleparts/frame/leopard/lb
	w_left = list("c_wall",TRUE,TRUE,35,35,FALSE,FALSE)
	w_back = list("mt_back_left_frame",TRUE,TRUE,20,20,FALSE,FALSE)
	override_roof_icon = "mt_back_left_roof"
	override_frame_icon = "mt_back_left_frame"

/obj/structure/vehicleparts/frame/leopard/rf
	w_right = list("c_wall",TRUE,TRUE,120,100,FALSE,FALSE)
	w_front = list("mt_front_right_frame",TRUE,TRUE,250,250,FALSE,FALSE)
	override_roof_icon = "mt_front_right_roof"
	override_frame_icon = "mt_front_right_frame"
/obj/structure/vehicleparts/frame/leopard/lf
	w_left = list("c_wall",TRUE,TRUE,120,100,FALSE,FALSE)
	w_front = list("mt_front_left_frame",TRUE,TRUE,250,250,FALSE,FALSE)
	override_roof_icon = "mt_front_left_roof"
	override_frame_icon = "mt_front_left_frame"


//Campaign

/obj/structure/vehicleparts/frame/omw22_2
	icon = 'icons/obj/vehicles/tankparts.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts.dmi'

/obj/structure/vehicleparts/frame/omw22_2/front
	w_front = list("mt_front_frame",TRUE,TRUE,90,90,FALSE,FALSE)
	override_roof_icon = "mt_front_roof"
	override_frame_icon = "mt_front_frame"
/obj/structure/vehicleparts/frame/omw22_2/back
	w_back = list("mt_back_frame",TRUE,TRUE,50,40,FALSE,FALSE)
	override_roof_icon = "mt_back_roof"
	override_frame_icon = "mt_back_frame"
/obj/structure/vehicleparts/frame/omw22_2/left
	w_left = list("mt_left_frame",TRUE,TRUE,50,40,FALSE,FALSE)
	override_roof_icon = "mt_left_roof"
	override_frame_icon = "mt_left_frame"
/obj/structure/vehicleparts/frame/omw22_2/right
	w_right = list("mt_right_frame",TRUE,TRUE,50,40,FALSE,FALSE)
	override_roof_icon = "mt_right_roof"
	override_frame_icon = "mt_right_frame"
	
/obj/structure/vehicleparts/frame/omw22_2/left/door
	w_left = list("mt_left_door_frame",TRUE,TRUE,50,28,TRUE,TRUE)
	doorcode = 668643
	override_roof_icon = "mt_left_door_roof"
	override_frame_icon = "mt_left_door_frame"
/obj/structure/vehicleparts/frame/omw22_2/right/door
	w_right = list("mt_right_door_frame",TRUE,TRUE,50,28,TRUE,TRUE)
	doorcode = 668643
	override_roof_icon = "mt_right_door_roof"
	override_frame_icon = "mt_right_door_frame"
/obj/structure/vehicleparts/frame/omw22_2/rb
	w_right = list("c_wall",TRUE,TRUE,50,40,FALSE,FALSE)
	w_back = list("mt_right_back_frame",TRUE,TRUE,50,40,FALSE,FALSE)
	override_roof_icon = "mt_back_right_roof"
	override_frame_icon = "mt_back_right_frame"

/obj/structure/vehicleparts/frame/omw22_2/lb
	w_left = list("c_wall",TRUE,TRUE,50,40,FALSE,FALSE)
	w_back = list("mt_back_left_frame",TRUE,TRUE,50,40,FALSE,FALSE)
	override_roof_icon = "mt_back_left_roof"
	override_frame_icon = "mt_back_left_frame"
/obj/structure/vehicleparts/frame/omw22_2/rf
	w_right = list("c_wall",TRUE,TRUE,50,40,FALSE,FALSE)
	w_front = list("mt_front_right_frame",TRUE,TRUE,90,90,FALSE,FALSE)
	override_roof_icon = "mt_front_right_roof"
	override_frame_icon = "mt_front_right_frame"
/obj/structure/vehicleparts/frame/omw22_2/lf
	w_left = list("c_wall",TRUE,TRUE,50,40,FALSE,FALSE)
	w_front = list("mt_front_left_frame",TRUE,TRUE,90,90,FALSE,FALSE)
	override_roof_icon = "mt_front_left_roof"
	override_frame_icon = "mt_front_left_frame"

///BAF-I A

/obj/structure/vehicleparts/frame/baf1_a
	icon = 'icons/obj/vehicles/tankparts.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts.dmi'
	override_roof_icon = "baf1_fc"
/obj/structure/vehicleparts/frame/baf1_a/center_back
	override_roof_icon = "baf1_bc"
/obj/structure/vehicleparts/frame/baf1_a/front
	w_front = list("mt_front_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "baf1_f"
	override_frame_icon = "mt_front_frame"
/obj/structure/vehicleparts/frame/baf1_a/back
	w_back = list("mt_back_frame",TRUE,TRUE,40,35,FALSE,FALSE)
	override_roof_icon = "baf1_b"
	override_frame_icon = "mt_back_frame"
/obj/structure/vehicleparts/frame/baf1_a/left
	w_left = list("mt_left_frame",TRUE,TRUE,40,35,FALSE,FALSE)
	override_roof_icon = "baf1_fcl"
	override_frame_icon = "mt_left_frame"
/obj/structure/vehicleparts/frame/baf1_a/left/back
	override_roof_icon = "baf1_bcl"
/obj/structure/vehicleparts/frame/baf1_a/right
	w_right = list("mt_right_frame",TRUE,TRUE,40,35,FALSE,FALSE)
	override_roof_icon = "baf1_fcr"
	override_frame_icon = "mt_right_frame"
/obj/structure/vehicleparts/frame/baf1_a/right/back
	override_roof_icon = "baf1_bcr"

/obj/structure/vehicleparts/frame/baf1_a/left/door
	w_left = list("mt_right_door_frame",TRUE,TRUE,40,24,TRUE,TRUE)
	doorcode = 932145
	override_roof_icon = "baf1_bcl"
	override_frame_icon = "mt_left_door_frame"
/obj/structure/vehicleparts/frame/baf1_a/right/door
	w_right = list("mt_right_door_frame",TRUE,TRUE,40,24,TRUE,TRUE)
	doorcode = 932145
	override_roof_icon = "baf1_bcr"
	override_frame_icon = "mt_right_door_frame"
/obj/structure/vehicleparts/frame/baf1_a/rb
	w_right = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
	w_back = list("mt_right_back_frame",TRUE,TRUE,40,35,FALSE,FALSE)
	override_roof_icon = "baf1_br"
	override_frame_icon = "mt_back_right_frame"
/obj/structure/vehicleparts/frame/baf1_a/rb/door
	w_right = list("c_door",TRUE,TRUE,40,24,TRUE,TRUE)
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/baf1_a/lb
	w_left = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
	w_back = list("mt_back_left_frame",TRUE,TRUE,40,35,FALSE,FALSE)
	override_roof_icon = "baf1_bl"
	override_frame_icon = "mt_back_left_frame"
/obj/structure/vehicleparts/frame/baf1_a/rf
	w_right = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
	w_front = list("mt_front_right_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "baf1_fr"
	override_frame_icon = "mt_front_right_frame"
/obj/structure/vehicleparts/frame/baf1_a/lf
	w_left = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
	w_front = list("mt_front_left_frame",TRUE,TRUE,50,50,FALSE,FALSE)
	override_roof_icon = "baf1_fl"
	override_frame_icon = "mt_front_left_frame"

///IS-3

/obj/structure/vehicleparts/frame/is3
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	pixel_x = -32
	pixel_y = -32

/// front

/obj/structure/vehicleparts/frame/is3/lf
	icon_state = "is3_frame_steel_front_left"
	w_front = list("is3_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/is3/front
	icon_state = "is3_frame_steel_front_middle"
	w_front = list("is3_front_middle_frame",TRUE,TRUE,40,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/is3/rf
	icon_state = "is3_frame_steel_front_right"
	w_front = list("is3_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/// middle-front

/obj/structure/vehicleparts/frame/is3/lfc
	icon_state = "is3_frame_steel_middle_front_left"
	w_left = list("is3_middle_front_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/is3/fc
	icon_state = "is3_frame_steel_middle_front"

/obj/structure/vehicleparts/frame/is3/rfc
	icon_state = "is3_frame_steel_middle_front_right"
	w_right = list("is3_middle_front_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/// middle

/obj/structure/vehicleparts/frame/is3/lc
	icon_state = "is3_frame_steel_middle_left"
	w_left = list("is3_middle_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/is3/c
	icon_state = "is3_frame_steel_middle"

/obj/structure/vehicleparts/frame/is3/rc
	icon_state = "is3_frame_steel_middle_right"
	w_right = list("is3_middle_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/// middle-back

/obj/structure/vehicleparts/frame/is3/lbc
	icon_state = "is3_frame_steel_middle_back_left"
	w_left = list("is3_middle_back_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/is3/bc
	icon_state = "is3_frame_steel_middle_back"

/obj/structure/vehicleparts/frame/is3/rbc
	icon_state = "is3_frame_steel_middle_back_right"
	w_right = list("is3_middle_back_right_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/// back

/obj/structure/vehicleparts/frame/is3/lb
	icon_state = "is3_frame_steel_back_left"
	w_back = list("is3_back_left_frame",TRUE,TRUE,35,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/is3/back
	icon_state = "is3_frame_steel_back"
	w_back = list("is3_back_middle_frame",TRUE,TRUE,35,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/is3/rb
	icon_state = "is3_frame_steel_back_right"
	w_back = list("is3_back_right_frame",TRUE,TRUE,35,50,TRUE,TRUE)
	w_right = list("none",TRUE,TRUE,35,50,FALSE,FALSE)

/// SU-100

/obj/structure/vehicleparts/frame/su100
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	normal_icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	pixel_x = -32
	pixel_y = -32
/// front
/obj/structure/vehicleparts/frame/su100/lf
	icon_state = "su100_frame_steel_front_left"
	w_front = list("su100_front_left_frame",TRUE,TRUE,120,120,TRUE,TRUE)
	w_left = list("none",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su100/front
	icon_state = "su100_frame_steel_front_middle"
	w_front = list("su100_front_middle_frame",TRUE,TRUE,120,120,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su100/rf
	icon_state = "su100_frame_steel_front_right"
	w_front = list("su100_front_right_frame",TRUE,TRUE,120,120,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,45,50,FALSE,FALSE)
/// middle-front
/obj/structure/vehicleparts/frame/su100/lfc
	icon_state = "su100_frame_steel_middle_front_left"
	w_left = list("su100_middle_front_left_frame",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su100/fc
	icon_state = "su100_frame_steel_middle_front"
/obj/structure/vehicleparts/frame/su100/rfc
	icon_state = "su100_frame_steel_middle_front_right"
	w_right = list("su100_middle_front_right_frame",TRUE,TRUE,45,50,TRUE,TRUE)
/// middle-back
/obj/structure/vehicleparts/frame/su100/lbc
	icon_state = "su100_frame_steel_middle_back_left"
	w_left = list("su100_middle_back_left_frame",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su100/bc
	icon_state = "su100_frame_steel_middle_back"
/obj/structure/vehicleparts/frame/su100/rbc
	icon_state = "su100_frame_steel_middle_back_right"
	w_right = list("su100_middle_back_right_frame",TRUE,TRUE,45,50,FALSE,FALSE)
/// back
/obj/structure/vehicleparts/frame/su100/lb
	icon_state = "su100_frame_steel_back_left"
	w_back = list("su100_back_left_frame",TRUE,TRUE,45,50,FALSE,FALSE)
	w_left = list("none",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su100/back
	icon_state = "su100_frame_steel_back"
	w_back = list("su100_back_middle_frame",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/su100/rb
	icon_state = "su100_frame_steel_back_right"
	w_back = list("su100_back_right_frame",TRUE,TRUE,45,50,FALSE,FALSE)
	w_right = list("none",TRUE,TRUE,45,50,FALSE,FALSE)


