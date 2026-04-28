//////////////////////// MOVEMENT COMPATIBILITY TYPES ////////////////////////
/// These are legacy movement paths used by premade vehicles and older
/// vehicle definitions. They map onto the new config-driven movement system.

/obj/structure/vehicleparts/movement/tracks
	name = "armored tracks"
	icon_state = "tracks_end"
	base_icon = "tracks_end"
	movement_icon = "tracks_end_m"
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	ntype = "track"
	var/left = FALSE

/obj/structure/vehicleparts/movement/tracks/middle
	icon_state = "tracks_cover"
	base_icon = "tracks_cover"
	movement_icon = "tracks_m_cover"

/obj/structure/vehicleparts/movement/tracks/reversed
	reversed = TRUE

/obj/structure/vehicleparts/movement/tracks/left
	icon = 'icons/obj/vehicles/tankparts.dmi'
	icon_state = "tracks_end_left"
	base_icon = "tracks_end_left"
	movement_icon = "tracks_end_left_m"
/obj/structure/vehicleparts/movement/tracks/right
	icon = 'icons/obj/vehicles/tankparts.dmi'
	icon_state = "tracks_end_right"
	base_icon = "tracks_end_right"
	movement_icon = "tracks_end_right_m"
/obj/structure/vehicleparts/movement/tracks/left/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/right/reversed
	reversed = TRUE

/obj/structure/vehicleparts/movement/tracks/mtlb/left
	icon = 'icons/obj/vehicles/apcparts.dmi'
	icon_state = "mtlb_tracks_end_left"
	base_icon = "mtlb_tracks_end_left"
	movement_icon = "mtlb_tracks_end_left_m"
/obj/structure/vehicleparts/movement/tracks/mtlb/right
	icon = 'icons/obj/vehicles/apcparts.dmi'
	icon_state = "mtlb_tracks_end_right"
	base_icon = "mtlb_tracks_end_right"
	movement_icon = "mtlb_tracks_end_right_m"
/obj/structure/vehicleparts/movement/tracks/mtlb/left/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/mtlb/right/reversed
	reversed = TRUE

/obj/structure/vehicleparts/movement/tracks/bmd2/left
	icon = 'icons/obj/vehicles/apcparts.dmi'
	icon_state = "bmd2_tracks_end_left"
	base_icon = "bmd2_tracks_end_left"
	movement_icon = "bmd2_tracks_end_left_m"
/obj/structure/vehicleparts/movement/tracks/bmd2/right
	icon = 'icons/obj/vehicles/apcparts.dmi'
	icon_state = "bmd2_tracks_end_right"
	base_icon = "bmd2_tracks_end_right"
	movement_icon = "bmd2_tracks_end_right_m"

/obj/structure/vehicleparts/movement/tracks/bmd2new/left_front
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bmd2new_tracks_left_front"
	base_icon = "bmd2new_tracks_left_front"
	movement_icon = "bmd2new_tracks_left_front_m"
/obj/structure/vehicleparts/movement/tracks/bmd2new/right_front
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bmd2new_tracks_right_front"
	base_icon = "bmd2new_tracks_right_front"
	movement_icon = "bmd2new_tracks_right_front_m"
/obj/structure/vehicleparts/movement/tracks/bmd2new/left_back
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bmd2new_tracks_left_back"
	base_icon = "bmd2new_tracks_left_back"
	movement_icon = "bmd2new_tracks_left_back_m"
/obj/structure/vehicleparts/movement/tracks/bmd2new/right_back
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bmd2new_tracks_right_back"
	base_icon = "bmd2new_tracks_right_back"
	movement_icon = "bmd2new_tracks_right_back_m"

/obj/structure/vehicleparts/movement/tracks/bradley/left_front
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bradley_tracks_left_front"
	base_icon = "bradley_tracks_left_front"
	movement_icon = "bradley_tracks_left_front_m"
/obj/structure/vehicleparts/movement/tracks/bradley/right_front
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bradley_tracks_right_front"
	base_icon = "bradley_tracks_right_front"
	movement_icon = "bradley_tracks_right_front_m"
/obj/structure/vehicleparts/movement/tracks/bradley/left_back
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bradley_tracks_left_back"
	base_icon = "bradley_tracks_left_back"
	movement_icon = "bradley_tracks_left_back_m"
/obj/structure/vehicleparts/movement/tracks/bradley/right_back
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "bradley_tracks_right_back"
	base_icon = "bradley_tracks_right_back"
	movement_icon = "bradley_tracks_right_back_m"

/obj/structure/vehicleparts/movement/tracks/is3/left_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is3_tracks_left_front"
	base_icon = "is3_tracks_left_front"
	movement_icon = "is3_tracks_left_front_m"
/obj/structure/vehicleparts/movement/tracks/is3/right_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is3_tracks_right_front"
	base_icon = "is3_tracks_right_front"
	movement_icon = "is3_tracks_right_front_m"
/obj/structure/vehicleparts/movement/tracks/is3/left_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is3_tracks_left_back"
	base_icon = "is3_tracks_left_back"
	movement_icon = "is3_tracks_left_back_m"
/obj/structure/vehicleparts/movement/tracks/is3/right_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is3_tracks_right_back"
	base_icon = "is3_tracks_right_back"
	movement_icon = "is3_tracks_right_back_m"

/obj/structure/vehicleparts/movement/tracks/is2/left_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is2_tracks_left_front"
	base_icon = "is2_tracks_left_front"
	movement_icon = "is2_tracks_left_front_m"
/obj/structure/vehicleparts/movement/tracks/is2/right_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is2_tracks_right_front"
	base_icon = "is2_tracks_right_front"
	movement_icon = "is2_tracks_right_front_m"
/obj/structure/vehicleparts/movement/tracks/is2/left_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is2_tracks_left_back"
	base_icon = "is2_tracks_left_back"
	movement_icon = "is2_tracks_left_back_m"
/obj/structure/vehicleparts/movement/tracks/is2/right_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "is2_tracks_right_back"
	base_icon = "is2_tracks_right_back"
	movement_icon = "is2_tracks_right_back_m"

/obj/structure/vehicleparts/movement/tracks/t34/left_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "t34_tracks_left_front"
	base_icon = "t34_tracks_left_front"
	movement_icon = "t34_tracks_left_front_m"
/obj/structure/vehicleparts/movement/tracks/t34/right_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "t34_tracks_right_front"
	base_icon = "t34_tracks_right_front"
	movement_icon = "t34_tracks_right_front_m"
/obj/structure/vehicleparts/movement/tracks/t34/left_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "t34_tracks_left_back"
	base_icon = "t34_tracks_left_back"
	movement_icon = "t34_tracks_left_back_m"
/obj/structure/vehicleparts/movement/tracks/t34/right_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "t34_tracks_right_back"
	base_icon = "t34_tracks_right_back"
	movement_icon = "t34_tracks_right_back_m"

/obj/structure/vehicleparts/movement/tracks/char1/left_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "char1_tracks_left_front"
	base_icon = "char1_tracks_left_front"
	movement_icon = "char1_tracks_left_front_m"
/obj/structure/vehicleparts/movement/tracks/char1/right_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "char1_tracks_right_front"
	base_icon = "char1_tracks_right_front"
	movement_icon = "char1_tracks_right_front_m"
/obj/structure/vehicleparts/movement/tracks/char1/left_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "char1_tracks_left_back"
	base_icon = "char1_tracks_left_back"
	movement_icon = "char1_tracks_left_back_m"
/obj/structure/vehicleparts/movement/tracks/char1/right_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "char1_tracks_right_back"
	base_icon = "char1_tracks_right_back"
	movement_icon = "char1_tracks_right_back_m"

/obj/structure/vehicleparts/movement/tracks/m41/left_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "m41_tracks_left_front"
	base_icon = "m41_tracks_left_front"
	movement_icon = "m41_tracks_left_front_m"
/obj/structure/vehicleparts/movement/tracks/m41/right_front
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "m41_tracks_right_front"
	base_icon = "m41_tracks_right_front"
	movement_icon = "m41_tracks_right_front_m"
/obj/structure/vehicleparts/movement/tracks/m41/left_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "m41_tracks_left_back"
	base_icon = "m41_tracks_left_back"
	movement_icon = "m41_tracks_left_back_m"
/obj/structure/vehicleparts/movement/tracks/m41/right_back
	icon = 'icons/obj/vehicles/tankparts96x96.dmi'
	icon_state = "m41_tracks_right_back"
	base_icon = "m41_tracks_right_back"
	movement_icon = "m41_tracks_right_back_m"

/obj/structure/vehicleparts/movement/tracks/hago/left
	icon = 'icons/obj/vehicles/tankparts.dmi'
	icon_state = "hago_tracks_l"
	base_icon = "hago_tracks_l"
	movement_icon = "hago_tracks_l_m"
/obj/structure/vehicleparts/movement/tracks/hago/right
	icon = 'icons/obj/vehicles/tankparts.dmi'
	icon_state = "hago_tracks_r"
	base_icon = "hago_tracks_r"
	movement_icon = "hago_tracks_r_m"
/obj/structure/vehicleparts/movement/tracks/hago/left/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/hago/right/reversed
	reversed = TRUE

/obj/structure/vehicleparts/movement/tracks/apc/left
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "tracks_end_left"
	base_icon = "tracks_end_left"
	movement_icon = "tracks_end_left_m"
/obj/structure/vehicleparts/movement/tracks/apc/right
	icon = 'icons/obj/vehicles/apcparts96x96.dmi'
	icon_state = "tracks_end_right"
	base_icon = "tracks_end_right"
	movement_icon = "tracks_end_right_m"
/obj/structure/vehicleparts/movement/tracks/apc/left/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/apc/right/reversed
	reversed = TRUE


/obj/structure/vehicleparts/movement/tracks/m113/left
	icon = 'icons/obj/vehicles/apcparts.dmi'
	icon_state = "m113_tracks_end_left"
	base_icon = "m113_tracks_end_left"
	movement_icon = "m113_tracks_end_left_m"
/obj/structure/vehicleparts/movement/tracks/m113/right
	icon = 'icons/obj/vehicles/apcparts.dmi'
	icon_state = "m113_tracks_end_right"
	base_icon = "m113_tracks_end_right"
	movement_icon = "m113_tracks_end_right_m"
/obj/structure/vehicleparts/movement/tracks/m113/left/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/m113/right/reversed
	reversed = TRUE
