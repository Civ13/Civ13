/obj/item/vehicleparts/wheel/ship
	icon_state = "rudder"
	name = "boat rudder and sail control"
	desc = "Used to steer a boat and control the sails."
	var/spamtimer = 0
	var/obj/structure/vehicleparts/axis/axis_control = null
/obj/item/vehicleparts/wheel/ship/attack_self(mob/living/carbon/human/H)
	if (!axis_control)
		var/found = FALSE
		for (var/obj/structure/vehicleparts/frame/ship/S in H.loc)
			if (S.axis && S.axis.masts)
				found = TRUE
				axis_control = S.axis
		if (!found || !axis_control || !(axis_control.loc in range(5,H)))
			axis_control = null
			return
	else
		for (var/obj/structure/vehicleparts/movement/sails/M in axis_control.masts)
			if (world.time > spamtimer)
				H << "You hoist the sails."
				M.sails_on = TRUE
				spamtimer = world.time + 20
				return
			else
				H << "You retract the sails."
				M.sails_on = FALSE
				return