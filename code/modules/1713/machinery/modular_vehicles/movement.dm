////////////////////////WHEELS AND TRACKS///////////////////

/obj/structure/vehicleparts/movement
	name = "wheel"
	icon_state = "wheel"
	var/base_icon = "wheel"
	var/movement_icon = "wheel_m"
	layer = 4
	var/reversed = FALSE
/obj/structure/vehicleparts/movement/tracks
	name = "armored tracks"
	icon_state = "tracks_end"
	base_icon = "tracks_end"
	movement_icon = "tracks_end_m"
/obj/structure/vehicleparts/movement/tracks/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis)
		VP.axis.wheels += src
		playsound(loc, 'sound/effects/lever.ogg',80, TRUE)