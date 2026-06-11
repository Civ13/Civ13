// Submarine-specific light fixtures
// Respond to submarine battery power instead of cable network

/obj/structure/lamp/lamp_small/alwayson/sub
	var/datum/submarine/my_sub

/obj/structure/lamp/lamp_small/alwayson/sub/New()
	..()
	if(global.all_submarines && global.all_submarines.len)
		my_sub = global.all_submarines[1]

/obj/structure/lamp/lamp_small/alwayson/sub/do_light()
	if(!my_sub)
		..()
		return
	if(!lamp_broken && lamp_inside)
		if(my_sub.battery_current > 0)
			if(brightness_color)
				set_light(light_amt, 1, brightness_color)
			else
				set_light(light_amt)
			update_icon()
			powered = TRUE
			on = TRUE
		else
			set_light(0)
			update_icon()
			powered = FALSE
			on = FALSE
	else
		set_light(0)
		update_icon()
		powered = FALSE
		on = FALSE
	spawn(10)
		do_light()

// Emergency red light - blinks and brighter
/obj/structure/lamp/lamp_small/alwayson/red/emergency
	light_amt = 6
	var/blink_state = FALSE

/obj/structure/lamp/lamp_small/alwayson/red/emergency/do_light()
	if(!lamp_broken && lamp_inside)
		blink_state = !blink_state
		if(blink_state)
			if(brightness_color)
				set_light(light_amt, 1, brightness_color)
			else
				set_light(light_amt)
			update_icon()
			on = TRUE
		else
			set_light(0)
			update_icon()
			on = FALSE
	spawn(6)
		do_light()
