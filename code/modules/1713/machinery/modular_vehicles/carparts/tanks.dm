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

/obj/structure/vehicleparts/frame/t34/front
	w_front = list("c_wall",TRUE,TRUE,50,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/back
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/left
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/right
	w_right = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/left/door
	w_left = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t34/right/door
	w_right = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t34/rb
	w_right = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/lb
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/rf
	w_right = list("c_wall",TRUE,TRUE,40,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,50,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/lf
	w_left = list("c_wall",TRUE,TRUE,40,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,50,50,FALSE,FALSE)

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
/obj/structure/vehicleparts/frame/omw22_2/rb/door
	w_right = list("c_door",TRUE,TRUE,50,28,TRUE,TRUE)
	w_back = list("c_wall",TRUE,TRUE,50,40,FALSE,FALSE)
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



