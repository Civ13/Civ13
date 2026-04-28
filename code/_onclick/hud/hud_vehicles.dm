/obj/screen/vehicle
	icon = 'icons/mob/screen/vehicle.dmi'
	layer = 20
	process_flag = TRUE

/obj/screen/vehicle/direction
	name = "direction"
	icon_state = "forward"
	screen_loc = "14,15"
	process_flag = TRUE

/obj/screen/vehicle/direction/process()
	update_icon()

/obj/screen/vehicle/direction/update_icon()
	..()
	if (parentmob && parentmob.buckled)
		if (istype(parentmob.buckled, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/this_chair = parentmob.buckled
			if (this_chair.axis && istype(this_chair.axis, /obj/structure/vehicleparts/axis))
				var/obj/structure/vehicleparts/axis/this_axis = this_chair.axis
				if (this_axis.reverse)
					icon_state = "reverse"
				else
					icon_state = "forward"

/obj/screen/vehicle/direction/Click()
	if (parentmob && parentmob.buckled)
		if (istype(parentmob.buckled, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/this_chair = parentmob.buckled
			if (this_chair.axis && istype(this_chair.axis, /obj/structure/vehicleparts/axis))
				var/obj/structure/vehicleparts/axis/this_axis = this_chair.axis
				if (!this_axis.reverse)
					parentmob << "You switch into reverse."
					playsound(parentmob.loc, 'sound/effects/lever.ogg',65, TRUE)
					this_axis.reverse = TRUE
					icon_state = "reverse"
					update_icon()
				else
					parentmob << "You switch into forward."
					playsound(parentmob.loc, 'sound/effects/lever.ogg',65, TRUE)
					this_axis.reverse = FALSE
					icon_state = "forward"
					update_icon()

/obj/screen/vehicle/turn_left
	name = "turn left"
	icon_state = "turn_left"
	screen_loc = "13,15"
	process_flag = FALSE

/obj/screen/vehicle/turn_left/Click()
	if (parentmob && ishuman(parentmob))
		var/mob/living/human/H = parentmob
		if (H.buckled && istype(H.buckled, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/D = H.buckled
			if (D.wheel)
				D.wheel.turndir(H, "left")

/obj/screen/vehicle/turn_right
	name = "turn right"
	icon_state = "turn_right"
	screen_loc = "15,15"
	process_flag = FALSE

/obj/screen/vehicle/turn_right/Click()
	if (parentmob && ishuman(parentmob))
		var/mob/living/human/H = parentmob
		if (H.buckled && istype(H.buckled, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/D = H.buckled
			if (D.wheel)
				D.wheel.turndir(H, "right")

/obj/screen/vehicle/gear_down
	name = "gear down"
	icon_state = "gear_down"
	screen_loc = "15,14"
	process_flag = FALSE

/obj/screen/vehicle/gear_down/Click()
	if (parentmob && ishuman(parentmob))
		var/mob/living/human/H = parentmob
		if (H.buckled && istype(H.buckled, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/D = H.buckled
			if (D.wheel)
				D.wheel.secondary_attack_self(H)

/obj/screen/vehicle/current_gear
	name = "current gear"
	icon_state = "speed_off"
	screen_loc = "14,14"
	process_flag = TRUE

/obj/screen/vehicle/current_gear/process()
	update_icon()

/obj/screen/vehicle/current_gear/update_icon()
	..()
	if (parentmob && parentmob.buckled)
		if (istype(parentmob.buckled, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/this_chair = parentmob.buckled
			if (this_chair.axis && istype(this_chair.axis, /obj/structure/vehicleparts/axis))
				var/obj/structure/vehicleparts/axis/this_axis = this_chair.axis
				if (this_axis.engine && !this_axis.engine.on)
					icon_state = "speed_off"
				else
					if (this_axis.currentspeed == 0)
						icon_state = "speed_n"
					else if (this_axis.reverse)
						icon_state = "speed_r"
					else
						icon_state = "speed_[this_axis.currentspeed]"

/obj/screen/vehicle/gear_up
	name = "gear up"
	icon_state = "gear_up"
	screen_loc = "15,14"
	process_flag = FALSE

/obj/screen/vehicle/gear_up/Click()
	if (parentmob && ishuman(parentmob))
		var/mob/living/human/H = parentmob
		if (H.buckled && istype(H.buckled, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/D = H.buckled
			if (D.wheel)
				D.wheel.attack_self(H)