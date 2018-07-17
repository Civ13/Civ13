// the light switch
// can have multiple per area
// can also operate on non-loc area through "otherarea" var
/obj/structure/light_switch
	name = "light switch"
	desc = "It turns lights on and off. What are you, simple?"
	icon = 'icons/obj/power.dmi'
	icon_state = "light1"
	anchored = 1.0
	var/on = TRUE
	var/area/area = null
	var/otherarea = null
	var/stat = 0

/obj/structure/light_switch/New()
	..()
	spawn(5)
		area = get_area(src)

		if(otherarea)
			area = locate(text2path("/area/[otherarea]"))

		if(!name)
			name = "light switch ([area.name])"

		on = area.lightswitch
		updateicon()

/obj/structure/light_switch/proc/updateicon()
	if(stat & NOPOWER)
		icon_state = "light-p"
		set_light(0)
		layer = OBJ_LAYER
	else
		icon_state = "light[on]"
		set_light(2, 1.5, on ? "#82FF4C" : "#F86060")
		layer = LIGHTING_LAYER+0.1

/obj/structure/light_switch/examine(mob/user)
	if(..(user, TRUE))
		user << "A light switch. It is [on? "on" : "off"]."

/obj/structure/light_switch/attack_hand(mob/user)

	on = !on

	area.lightswitch = on
	area.updateicon()
	playsound(src, 'sound/machines/button.ogg', 100, TRUE, FALSE)

	for(var/obj/structure/light_switch/L in area)
		L.on = on
		L.updateicon()

	area.power_change()

/obj/structure/light_switch/proc/power_change()

	if(!otherarea)
		if(TRUE)
			stat &= ~NOPOWER
		else
			stat |= NOPOWER

		updateicon()

/obj/structure/light_switch/emp_act(severity)
	if(stat & (BROKEN|NOPOWER))
		..(severity)
		return
	power_change()
	..(severity)
