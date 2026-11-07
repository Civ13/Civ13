// Who holds a legacy vehicle's controls when its driver passes out, wakes or dies.
// Kept apart from transports.dm, whose appearance-only tail is pinned by tests/carriage_glide.
// Vehicle and crew controls held by a mob that passes out or dies go back to
// the vehicle or seat they belong to, so the hands empty like any other item.
// The mob keeps its place; clicking the vehicle or seat again picks them up.
/mob/living/human/proc/return_vehicle_control(var/obj/item/W)
	if (!W || W.loc != src)
		return FALSE
	if (istype(W, /obj/item/vehicleparts/wheel/modular))
		return FALSE // drop_from_inventory already returns these to their driver's seat
	if (istype(W, /obj/item/vehicleparts/wheel))
		var/obj/structure/vehicle/V = driver_vehicle
		if (!V || V.dwheel != W)
			var/obj/item/vehicleparts/wheel/VW = W
			V = VW.origin
		if (!istype(V) || V.dwheel != W)
			return FALSE
		remove_from_mob(W)
		W.forceMove(V)
		V.controls_released(src)
		update_icons()
		return TRUE
	if (istype(buckled, /obj/structure/bed/chair/gunner))
		var/obj/structure/bed/chair/gunner/G = buckled
		if (G.controls != W)
			return FALSE
		G.controls.stop_firing()
		G.controls.stop_rotation()
		remove_from_mob(W)
		W.forceMove(G)
		update_icons()
		return TRUE
	if (istype(buckled, /obj/structure/bed/chair/mgunner))
		var/obj/structure/bed/chair/mgunner/MG = buckled
		if (MG.mg != W)
			return FALSE
		remove_from_mob(W)
		W.forceMove(MG)
		update_icons()
		return TRUE
	if (istype(buckled, /obj/structure/bed/chair/commander))
		var/obj/structure/bed/chair/commander/C = buckled
		if (C.periscope != W)
			return FALSE
		remove_from_mob(W)
		W.forceMove(C)
		update_icons()
		return TRUE
	return FALSE

// The driver let go of the controls without leaving: stop the vehicle.
/obj/structure/vehicle/proc/controls_released(var/mob/living/human/H)
	if (engine && engine.on)
		engine.on = FALSE
		engine.power_off_connections()
		engine.currentspeed = 0
		engine.currentpower = 0
		set_light(0)
		playsound(loc, engine.ending_snd, 65, FALSE, 2)
	if (axis)
		stopmovementloop()
	else
		moving = FALSE

// A seated driver who is not holding the controls (for example after waking
// up) takes them back by clicking the vehicle. Returns TRUE when handled.
/obj/structure/vehicle/proc/retake_controls(var/mob/living/human/user)
	if (!wheeled || !dwheel || !istype(user) || dwheel.loc != src)
		return FALSE
	// With nobody driving (say the driver died), a passenger can take over.
	if (user != driver && (driver || user.driver || !(user in ontop)))
		return FALSE
	if (user.stat != CONSCIOUS || user.incapacitated(INCAPACITATION_DISABLED|INCAPACITATION_RESTRAINED))
		return FALSE
	// Full hands fall through to the normal click, which gets off the vehicle.
	if (!user.put_in_active_hand(dwheel))
		return FALSE
	if (user != driver)
		take_driver_seat(user)
		to_chat(user, SPAN_NOTICE("You take over \the [src]."))
		return TRUE
	to_chat(user, SPAN_NOTICE("You take hold of \the [dwheel] again."))
	return TRUE

/obj/structure/vehicle/proc/take_driver_seat(var/mob/living/human/user)
	user.driver = TRUE
	user.driver_vehicle = src
	driver = user
	if (user.buckled != src)
		buckle_mob(user)
	updatepassdir()
	update_overlay()
	update_icon()

/obj/structure/vehicle/boat/take_driver_seat(var/mob/living/human/user)
	if (currentcap == user)
		currentcap = null
	..()

// A driver who dies gives up the driver's place: the controls go back to the
// vehicle, it stops, and the body is left lying where the vehicle is, so the
// next person to board can drive it.
/obj/structure/vehicle/proc/driver_died(var/mob/living/human/H)
	if (!istype(H) || H != driver)
		return FALSE
	if (dwheel && dwheel.loc == H)
		H.remove_from_mob(dwheel)
		dwheel.forceMove(src)
	controls_released(H)
	H.release_carriage_glide()
	ontop -= H
	H.driver = FALSE
	H.driver_vehicle = null
	driver = null
	if (H.buckled == src)
		H.buckled = null
		H.anchored = initial(H.anchored)
		H.update_canmove()
	if (buckled_mob == H)
		buckled_mob = null
	H.pixel_x = 0
	H.pixel_y = 0
	H.update_icons()
	updatepassdir()
	update_overlay()
	update_icon()
	return TRUE

/obj/structure/vehicle/carriage/driver_died(var/mob/living/human/H)
	if (H != driver)
		return FALSE
	if (bucklepoint1 == H)
		bucklepoint1 = null
	if (bucklepoint2 == H)
		bucklepoint2 = null
	if (bucklepoint3 == H)
		bucklepoint3 = null
	if (bucklepoint4 == H)
		bucklepoint4 = null
	if (bucklepoint5 == H)
		bucklepoint5 = null
	return ..()
